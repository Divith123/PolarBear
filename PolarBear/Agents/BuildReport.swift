//
//  BuildReport.swift
//  PolarBear
//

import Foundation

/// The result of the latest build, written for an agent: a short summary for the prompt and the
/// complete list and raw compiler log as files in the agent's working copy. The agent works in a
/// copy of the sources and cannot run the compiler, so this is how it sees what is wrong.
nonisolated struct BuildReport: Sendable {
    /// The folder, inside the agent's copy, that holds the report files.
    static let folder = "polarbear-report"
    static let problemsFile = folder + "/problems.txt"
    static let logFile = folder + "/compile.log"

    private static let maximumErrorsInPrompt = 40
    private static let maximumWarningsInPrompt = 25
    private static let maximumLogCharacters = 300_000

    var isMarkdown: Bool
    var engineName: String
    var rootFile: String
    var outcome: String
    var isShowingOlderPDF: Bool
    var diagnostics: [Diagnostic]
    var log: String

    var errors: [Diagnostic] { diagnostics.filter { $0.severity == .error } }
    var warnings: [Diagnostic] { diagnostics.filter { $0.severity == .warning } }

    var hasProblems: Bool {
        !errors.isEmpty || !warnings.isEmpty
    }

    // MARK: Text

    private func line(_ diagnostic: Diagnostic) -> String {
        let place = [diagnostic.file, diagnostic.line.map(String.init)].compactMap { $0 }.joined(separator: ":")
        var text = "- " + (place.isEmpty ? "" : place + "  ") + diagnostic.message.replacing("\n", with: " ")
        if let context = diagnostic.context, !context.isEmpty { text += "\n    source: " + context.replacing("\n", with: " ") }
        return text
    }

    /// Identical complaints on the same line are listed once.
    private func unique(_ items: [Diagnostic]) -> [Diagnostic] {
        var seen: Set<String> = []
        return items.filter { seen.insert("\($0.file ?? "")|\($0.line ?? 0)|\($0.message)").inserted }
    }

    private func section(_ title: String, _ items: [Diagnostic], limit: Int?) -> String {
        let items = unique(items)
        guard !items.isEmpty else { return "" }
        let shown = limit.map { Array(items.prefix($0)) } ?? items
        var text = "\(title) (\(items.count)):\n" + shown.map(line).joined(separator: "\n")
        if shown.count < items.count {
            text += "\n- … and \(items.count - shown.count) more, all listed in \(Self.problemsFile)"
        }
        return text + "\n"
    }

    /// For the prompt: the outcome, and the errors and warnings up to a sensible length.
    var summary: String {
        var text = "Build report (the result of the last compile, shown to the user in the Problems list):\n"
        text += "Main file: \(rootFile) · Engine: \(engineName) · Result: \(outcome)"
        if isShowingOlderPDF { text += " (the preview still shows the last good version)" }
        text += "\n"
        if hasProblems {
            text += "\n" + section("Errors", errors, limit: Self.maximumErrorsInPrompt)
            text += "\n" + section("Warnings", warnings, limit: Self.maximumWarningsInPrompt)
        } else {
            text += "No errors and no warnings.\n"
        }
        text += "\nFull list: \(Self.problemsFile). Raw \(isMarkdown ? "render" : "compiler") log: \(Self.logFile). "
        text += "These are read-only reports for you to read; fix the source files, not the reports."
        return text
    }

    /// Everything, for `problems.txt`.
    var fullList: String {
        "Main file: \(rootFile)\nEngine: \(engineName)\nResult: \(outcome)\n\n"
            + section("Errors", errors, limit: nil) + "\n" + section("Warnings", warnings, limit: nil)
    }

    /// The report files for the agent's working copy.
    var files: [TemplateFile] {
        var text = log
        if text.count > Self.maximumLogCharacters {
            // Keep the start (the setup) and the end (where a fatal error stops the run).
            let head = text.prefix(Self.maximumLogCharacters / 3)
            let tail = text.suffix(Self.maximumLogCharacters * 2 / 3)
            text = head + "\n\n… (the middle of the log was left out because it is long) …\n\n" + tail
        }
        return [
            TemplateFile(path: Self.problemsFile, text: fullList),
            TemplateFile(path: Self.logFile, text: text),
        ]
    }
}
