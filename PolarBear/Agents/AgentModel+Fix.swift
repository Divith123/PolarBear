//
//  AgentModel+Fix.swift
//  PolarBear
//

import Foundation

extension AgentModel {
    /// "Fix with AI": asks the agent, in the current conversation, to fix the errors and
    /// warnings of the latest build. The conversation shows a short line; the agent gets the full
    /// build report with its prompt (see `fullPrompt`).
    func fixBuildProblems(with kind: AgentKind, executable: URL, options: AgentOptions) {
        guard let project, !isRunning else { return }
        let errors = project.build.errorCount, warnings = project.build.warningCount
        guard errors + warnings > 0 else { return }

        func count(_ number: Int, _ word: String) -> String {
            "\(number) \(word)\(number == 1 ? "" : "s")"
        }
        let parts = [errors > 0 ? count(errors, "error") : nil, warnings > 0 ? count(warnings, "warning") : nil]
        let shown = "Fix build problems: " + parts.compactMap { $0 }.joined(separator: ", ")

        let sources = project.settings.mode == .markdown ? "Markdown files" : "LaTeX sources"
        let request = """
        Fix the errors and warnings from the latest build. They are listed in the build report below, \
        with the file and line of each, and the raw log is in \(BuildReport.logFile). Fix the errors first, \
        then the warnings that point at a real problem (leave a harmless layout warning alone unless the fix is trivial). \
        Edit the \(sources) directly with the smallest change that fixes each problem, and do not try to compile: \
        the app compiles again after the user keeps your changes. Finish with a short summary of what you changed.
        """
        isPanelVisible = true
        send(request, display: shown, with: kind, executable: executable, options: options)
    }
}
