//
//  MarkdownBuild.swift
//  PolarBear
//

import Foundation
import os

/// The "compile" of a Markdown project: parse the file, write it as an HTML page and print the
/// page to a PDF. The result is a `BuildOutcome` like any other engine's, so the preview, the
/// Problems list and the stale-PDF handling work unchanged.
nonisolated enum MarkdownBuild {
    @concurrent
    static func run(_ request: BuildRequest) async -> BuildOutcome {
        let started = Date()
        let fileManager = FileManager.default
        let source = request.root.appending(path: request.rootFile)
        let build = request.buildDirectory
        let page = build.appending(path: request.jobName + ".html")
        let pdf = build.appending(path: request.jobName + ".pdf")

        func outcome(
            status: Int32 = 0,
            cancelled: Bool = false,
            console: String,
            diagnostics: [Diagnostic],
            producedPDF: Bool
        ) -> BuildOutcome {
            BuildOutcome(
                status: status,
                wasCancelled: cancelled,
                launchError: nil,
                console: console,
                texLog: "",
                diagnostics: diagnostics,
                pdf: producedPDF ? pdf : nil,
                synctex: nil,
                duration: Date().timeIntervalSince(started)
            )
        }

        do {
            ProjectPaths.prepareMetadata(in: request.root)
            try fileManager.createDirectory(at: build, withIntermediateDirectories: true)

            let data = try Data(contentsOf: source)
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let document = MarkdownDocument(source: text)

            var writer = MarkdownHTMLWriter(baseDirectory: source.deletingLastPathComponent())
            if request.loadsRemoteImages {
                let sources = document.remoteImageSources
                if !sources.isEmpty {
                    let fetched = await MarkdownImageStore.fetch(sources, into: ProjectPaths.imageCacheDirectory(in: request.root))
                    writer.remoteImages = fetched.files
                    writer.remoteFailures = fetched.failures
                }
            }
            let body = writer.write(document)
            let title = document.title ?? request.jobName
            try MarkdownPage.html(body: body, title: title, style: .document).write(to: page, atomically: true, encoding: .utf8)
            try Task.checkCancellation()

            try await MarkdownPDF.render(page: page, readAccess: request.root, to: pdf)

            let diagnostics = writer.issues.map { Diagnostic(severity: .warning, message: $0.message, file: request.rootFile) }
            return outcome(console: "Rendered \(request.rootFile) to \(request.jobName).pdf\n", diagnostics: diagnostics, producedPDF: true)
        } catch is CancellationError {
            return outcome(cancelled: true, console: "", diagnostics: [], producedPDF: false)
        } catch {
            Log.build.error("Markdown render failed: \(error.localizedDescription, privacy: .public)")
            let diagnostic = Diagnostic(severity: .error, message: error.localizedDescription, file: request.rootFile)
            return outcome(status: 1, console: error.localizedDescription + "\n", diagnostics: [diagnostic], producedPDF: false)
        }
    }
}
