//
//  StatsTab.swift
//  PolarBear
//

import SwiftUI

/// Project info: where the document stands (words, headers, figures, maths) and how it is built.
struct StatsTab: View {
    let project: Project
    let pageCount: Int

    @State private var stats: DocumentStats?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                if let stats {
                    StatRow(title: "Words", value: stats.words.formatted())
                    StatRow(title: "Words in Text", value: stats.wordsInText.formatted())
                    StatRow(title: "Words in Headers", value: stats.wordsInHeaders.formatted())
                    StatRow(title: "Words outside Text", value: stats.wordsOutsideText.formatted())
                    StatRow(title: "Number of Headers", value: stats.headers.formatted())
                    StatRow(title: "Number of Figures", value: stats.figures.formatted())
                    StatRow(title: "Number of Inline Math", value: stats.inlineMath.formatted())
                    StatRow(title: "Number of Displayed Math", value: stats.displayedMath.formatted())
                } else {
                    Label {
                        Text("Loading…")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }

                Divider()
                    .overlay(AppTheme.hairlineFaint)
                    .padding(.vertical, AppTheme.Spacing.m)

                StatRow(title: "Main Document", value: project.resolvedRootFile ?? "—")
                StatRow(title: "Engine", value: project.settings.mode == .markdown ? "PolarBear Markdown" : (project.effectiveEngine?.displayName ?? "—"))
                StatRow(title: "Pages", value: pageCount > 0 ? pageCount.formatted() : "—")
                StatRow(title: "Files", value: (project.files.count + project.assets.count).formatted())
                if let record = project.build.records.first {
                    StatRow(title: "Last Build", value: record.duration.formatted(.number.precision(.fractionLength(1))) + " s")
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .task(id: "\(project.editRevision)-\(project.structureRevision)-\(project.settings.mode.rawValue)") {
            await recount()
        }
    }

    /// Waits a moment (typing restarts the task), then counts off the main actor.
    private func recount() async {
        do {
            try await Task.sleep(for: .milliseconds(stats == nil ? 0 : 400))
        } catch {
            return
        }
        guard let root = project.resolvedRootFile else {
            stats = DocumentStats()
            return
        }
        if project.settings.mode == .markdown {
            stats = await MarkdownStats.compute(text: project.file(atPath: root)?.text ?? "")
            return
        }
        let sources = Dictionary(
            project.files.filter { $0.kind == .tex }.map { ($0.path, $0.text) },
            uniquingKeysWith: { first, _ in first }
        )
        stats = await DocumentStatsCounter.compute(root: root, sources: sources)
    }
}
