//
//  LogTab.swift
//  PolarBear
//

import SwiftUI

/// The raw output of a build — TeX's own transcript when there is one — exactly as written.
struct LogTab: View {
    let build: BuildModel
    @State private var selectedID: BuildRecord.ID?

    var body: some View {
        let record = selectedRecord

        VStack(spacing: 0) {
            HStack(spacing: AppTheme.Spacing.m) {
                Menu {
                    ForEach(build.records) { candidate in
                        Button {
                            selectedID = candidate.id
                        } label: {
                            Text("\(candidate.date.formatted(date: .omitted, time: .standard)) · \(candidate.errors) errors")
                        }
                    }
                } label: {
                    Label {
                        if let record {
                            Text(record.date, format: .dateTime.hour().minute().second())
                        } else {
                            Text("No builds yet")
                        }
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(AppTheme.Typography.rowDetail)
                    .foregroundStyle(AppTheme.textSecondary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(build.records.isEmpty)

                Spacer(minLength: 0)

                Button("Copy Log", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log(of: record), forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.iconTertiary)
                .accessibilityLabel("Copy Log")
                .help("Copy Log")
                .disabled(log(of: record).isEmpty)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .frame(height: AppTheme.Metrics.drawerRowHeight)

            let text = log(of: record)
            if text.isEmpty {
                ContentUnavailableView {
                    Label("Raw Logs", systemImage: "terminal")
                } description: {
                    Text("The output of the TeX engine appears here after a build.")
                }
                .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView {
                    Text(verbatim: text)
                        .font(AppTheme.Typography.codeSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Spacing.xl)
                }
            }
        }
    }

    private var selectedRecord: BuildRecord? {
        build.records.first { $0.id == selectedID } ?? build.records.first
    }

    private func log(of record: BuildRecord?) -> String {
        build.isRunning ? build.liveLog : (record?.rawLog ?? "")
    }
}
