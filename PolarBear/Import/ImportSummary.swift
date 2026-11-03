//
//  ImportSummary.swift
//  PolarBear
//

import SwiftUI

/// The facts about an archive, plus the name and location the project will get.
struct ImportSummary: View {
    let preview: ImportPreview
    @Binding var name: String
    @Binding var location: URL

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            Text("^[\(preview.fileCount) file](inflect: true)\(preview.rootFile.map { " · main document: \($0)" } ?? "")")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)

            packageNote

            ForEach(preview.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(AppTheme.Typography.rowDetail)
                    .foregroundStyle(AppTheme.warning)
            }

            TextField("Project name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: AppTheme.Spacing.m) {
                Text(location.path(percentEncoded: false))
                    .font(AppTheme.Typography.rowDetail)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Button("Choose Location…") {
                    if let url = FilePanels.chooseFolder(
                        message: String(localized: "Choose where to create the project folder."),
                        prompt: String(localized: "Choose")
                    ) {
                        location = url
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var packageNote: some View {
        if let missing = preview.missingPackages, !missing.isEmpty {
            Label("Not installed: \(missing.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.warning)
        } else if preview.missingPackages != nil {
            Label("Every package the document uses is installed.", systemImage: "checkmark.circle")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.success)
        } else if !preview.packages.isEmpty {
            Label("Missing packages are downloaded when you compile.", systemImage: "arrow.down.circle")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
