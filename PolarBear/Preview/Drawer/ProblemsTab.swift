//
//  ProblemsTab.swift
//  PolarBear
//

import SwiftUI

/// What the engine complained about, worst first. Clicking a row opens the file at that line.
struct ProblemsTab: View {
    let build: BuildModel
    let open: ((Diagnostic) -> Void)?
    let fix: FixWithAIAction?

    var body: some View {
        let diagnostics = build.diagnostics

        if diagnostics.isEmpty {
            ContentUnavailableView {
                switch build.status {
                case .neverBuilt, .cancelled, .unavailable:
                    Label("Not Compiled Yet", systemImage: "play.circle")
                case .compiling:
                    Label("Compiling…", systemImage: "hourglass")
                default:
                    Label("No Problems", systemImage: "checkmark.circle")
                }
            }
            .foregroundStyle(AppTheme.textSecondary)
        } else {
            VStack(spacing: 0) {
                if let fix {
                    HStack(spacing: AppTheme.Spacing.m) {
                        Text(summary)
                            .font(AppTheme.Typography.rowDetail)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: AppTheme.Spacing.m)
                        FixWithAIButton(action: fix)
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.m)
                    Rectangle().fill(AppTheme.divider).frame(height: 1)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        ForEach(diagnostics) { diagnostic in
                            DiagnosticRow(diagnostic: diagnostic, open: open)
                        }
                    }
                    .padding(AppTheme.Spacing.m)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var summary: String {
        let errors = build.errorCount, warnings = build.warningCount
        var parts: [String] = []
        if errors > 0 { parts.append("\(errors) \(errors == 1 ? "error" : "errors")") }
        if warnings > 0 { parts.append("\(warnings) \(warnings == 1 ? "warning" : "warnings")") }
        return parts.joined(separator: ", ")
    }
}
