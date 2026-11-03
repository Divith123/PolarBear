//
//  AgentModel+Run.swift
//  PolarBear
//

import Foundation
import os

extension AgentModel {
    /// Starts a run, or asks for permission first if this agent has not been allowed in this project.
    func send(_ prompt: String, display: String? = nil, with kind: AgentKind, executable: URL, options: AgentOptions) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRunning, let project else { return }

        guard project.settings.consentedAgents.contains(kind.rawValue) else {
            consent = ConsentRequest(kind: kind, prompt: trimmed, display: display, executable: executable, options: options)
            return
        }
        start(trimmed, display: display, kind: kind, executable: executable, options: options)
    }

    func grantConsent() {
        guard let request = consent, let project else { return }
        consent = nil
        project.settings.consentedAgents.append(request.kind.rawValue)
        start(request.prompt, display: request.display, kind: request.kind, executable: request.executable, options: request.options)
    }

    func denyConsent() {
        consent = nil
    }

    func cancel() {
        runTask?.cancel()
    }

    // MARK: Running

    private func start(_ prompt: String, display: String?, kind: AgentKind, executable: URL, options: AgentOptions) {
        review = nil
        activity = nil
        streamingMessageID = nil
        hasNews = false
        phase = .running

        ensureSession(agent: kind, title: String((display ?? prompt).prefix(48)))
        append(.user, display ?? prompt)

        runTask = Task { [weak self] in
            await self?.run(prompt, kind: kind, executable: executable, options: options)
        }
    }

    private func run(_ prompt: String, kind: AgentKind, executable: URL, options: AgentOptions) async {
        defer {
            phase = .idle
            activity = nil
            streamingMessageID = nil
            hasNews = !isPanelVisible
            persistCurrent()
        }
        guard let project else { return }

        await project.saveDirtyFiles(triggersBuild: false)
        let adapter = kind.adapter
        // The agent works in a copy and cannot compile, so it gets the latest build's result as text and files.
        let report = project.buildReport()
        let command = adapter.command(prompt: Self.fullPrompt(for: prompt, project: project, report: report), resume: currentSession?.resumeToken, options: options)

        let staged: StagedProject
        do {
            staged = try await AgentStaging.create(from: project.historySources(), extras: command.files + (report?.files ?? []))
        } catch {
            append(.error, error.localizedDescription)
            return
        }
        defer { AgentStaging.remove(staged) }

        let outcome: AgentRunner.Outcome
        do {
            let receiver = self
            outcome = try await AgentRunner.run(adapter: adapter, executable: executable, command: command, directory: staged.root) { event in
                Task { @MainActor in receiver.handle(event) }
            }
        } catch is CancellationError {
            append(.error, String(localized: "Stopped."))
            return
        } catch let error as ProcessRunner.LaunchError {
            append(.error, error.message)
            return
        } catch {
            append(.error, error.localizedDescription)
            return
        }

        if outcome.wasCancelled {
            append(.error, String(localized: "Stopped."))
            return
        }
        if let failure = outcome.failure {
            append(.error, failure)
        } else if outcome.status != 0 {
            append(.error, String(localized: "\(kind.displayName) stopped with status \(outcome.status)."))
        }
        // Claude Code repeats its answer in the final result; show it only if nothing was streamed.
        if streamingMessageID == nil, let summary = outcome.summary, !summary.isEmpty {
            append(.assistant, summary)
        }

        let collected = await AgentStaging.collect(staged)
        let changes = FileChange.changes(old: staged.baseline, new: collected)
        if changes.isEmpty {
            append(.activity, String(localized: "No changes to the project."))
        } else {
            review = AgentReview(agent: kind, prompt: prompt, changes: changes)
        }
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .text(let line):
            appendAssistantLine(line)
        case .activity(let text):
            activity = text
            streamingMessageID = nil
            append(.activity, text)
        case .session(let token):
            setResumeToken(token)
        case .failure, .finished:
            break // Handled when the run ends.
        }
    }

    /// The request, framed so the agent edits files in place and stays inside the folder, followed
    /// by the latest build's result so the agent knows what is wrong without being told.
    private static func fullPrompt(for request: String, project: Project, report: BuildReport?) -> String {
        let main = project.resolvedRootFile.map { "The main document is \($0). " } ?? ""
        let kind = project.settings.mode == .markdown
            ? "a Markdown project in the current folder. \(main)Edit the project's .md files"
            : "a LaTeX project in the current folder. \(main)Edit the project's .tex and .bib files"
        var prompt = """
        You are helping with \(kind) directly when the request needs changes, keep changes small and limited to what \
        was asked, do not rename or delete files unless asked, and do not touch anything outside this folder. Answer briefly.

        Request: \(request)
        """
        if let report {
            prompt += "\n\n" + report.summary
        }
        return prompt
    }
}
