//
//  ProcessRunner.swift
//  PolarBear
//

import Foundation
import os

/// Runs a command-line tool without a shell (arguments are passed as an array, so nothing a
/// document contains can be interpreted as a command), streams its output and stops the whole
/// process tree when the calling task is cancelled.
nonisolated enum ProcessRunner {
    struct Result: Sendable {
        var status: Int32
        var output: String
        var wasCancelled: Bool
    }

    struct LaunchError: Error, Sendable {
        var message: String
    }

    @concurrent
    static func run(
        executable: URL,
        arguments: [String],
        directory: URL,
        environment: [String: String],
        onOutput: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> Result {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let (chunks, continuation) = AsyncStream<Data>.makeStream()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }

        let processID = OSAllocatedUnfairLock<pid_t>(initialState: 0)

        return try await withTaskCancellationHandler {
            async let collected: Data = {
                var all = Data()
                for await chunk in chunks {
                    all.append(chunk)
                    onOutput(String(decoding: chunk, as: UTF8.self))
                }
                return all
            }()

            let status: Int32 = try await withCheckedThrowingContinuation { resume in
                process.terminationHandler = { finished in
                    resume.resume(returning: finished.terminationStatus)
                }
                do {
                    try process.run()
                    let pid = process.processIdentifier
                    processID.withLock { $0 = pid }
                    ProcessRegistry.add(pid)
                    if Task.isCancelled { ProcessTree.terminate(pid) }
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.finish()
                    resume.resume(throwing: LaunchError(message: error.localizedDescription))
                }
            }

            ProcessRegistry.remove(processID.withLock { $0 })
            let data = await collected
            return Result(
                status: status,
                output: String(decoding: data, as: UTF8.self),
                wasCancelled: Task.isCancelled
            )
        } onCancel: {
            let pid = processID.withLock { $0 }
            if pid > 0 { ProcessTree.terminate(pid) }
        }
    }
}
