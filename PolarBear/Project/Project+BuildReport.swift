//
//  Project+BuildReport.swift
//  PolarBear
//

import Foundation

extension Project {
    /// The latest finished build, for an agent. `nil` before the first build.
    func buildReport() -> BuildReport? {
        guard let record = build.records.first(where: { $0.result != .cancelled }) else { return nil }
        let outcome: String
        switch record.result {
        case .succeeded: outcome = record.warnings > 0 ? "succeeded with warnings" : "succeeded"
        case .failed: outcome = "FAILED"
        case .cancelled: outcome = "cancelled"
        }
        return BuildReport(
            isMarkdown: settings.mode == .markdown,
            engineName: settings.mode == .markdown ? "PolarBear Markdown" : record.engine.displayName,
            rootFile: record.rootFile,
            outcome: outcome,
            isShowingOlderPDF: build.isStale,
            diagnostics: build.diagnostics,
            log: record.rawLog
        )
    }
}
