//
//  BuildStatusLabel.swift
//  PolarBear
//

import SwiftUI

/// The icon and words for a build status.
struct BuildStatusLabel: View {
    let status: BuildStatus
    let isOutOfDate: Bool

    var body: some View {
        Label {
            title
        } icon: {
            icon
        }
        .font(AppTheme.Typography.row)
        .foregroundStyle(tint)
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .compiling:
            ProgressView().controlSize(.small)
        case .compiled:
            Image(systemName: "checkmark")
        case .failed:
            Image(systemName: "xmark.octagon.fill")
        case .cancelled:
            Image(systemName: "stop.circle")
        case .neverBuilt:
            Image(systemName: "play.circle")
        case .unavailable:
            Image(systemName: "exclamationmark.triangle")
        }
    }

    private var title: Text {
        switch status {
        case .compiling:
            Text("Compiling…", comment: "Status of the PDF preview while a build runs.")
        case .compiled(let warnings):
            if isOutOfDate {
                Text("Out of date", comment: "Status of the PDF preview: edited since the last build.")
            } else if warnings > 0 {
                Text("Compiled · \(warnings)", comment: "Status of the PDF preview: compiled, with a number of warnings.")
            } else {
                Text("Compiled", comment: "Status of the PDF preview: the document compiled successfully.")
            }
        case .failed(let errors):
            Text("^[\(errors) error](inflect: true)", comment: "Status of the PDF preview: the build failed with a number of errors.")
        case .cancelled:
            Text("Stopped", comment: "Status of the PDF preview: the build was stopped.")
        case .neverBuilt:
            Text("Compile", comment: "Status of the PDF preview before the first build.")
        case .unavailable:
            Text("No TeX engine", comment: "Status of the PDF preview: nothing to compile with.")
        }
    }

    private var tint: Color {
        switch status {
        case .failed, .unavailable: AppTheme.danger
        case .compiled(let warnings): isOutOfDate ? AppTheme.warning : (warnings > 0 ? AppTheme.warning : AppTheme.textPrimary)
        default: AppTheme.textPrimary
        }
    }
}
