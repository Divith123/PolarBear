//
//  PDFEmptyState.swift
//  PolarBear
//

import SwiftUI

/// Shown where the PDF will appear while there is none.
struct PDFEmptyState: View {
    let project: Project
    @Binding var drawer: DrawerTab?

    var body: some View {
        let build = project.build

        ContentUnavailableView {
            switch build.status {
            case .compiling:
                Label {
                    Text("Compiling…")
                } icon: {
                    ProgressView().controlSize(.large)
                }
            case .failed:
                Label("The Build Failed", systemImage: "xmark.octagon")
            case .unavailable(let problem):
                Label {
                    Text(problem.message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            case .neverBuilt, .compiled, .cancelled:
                Label("No PDF Yet", systemImage: "doc.richtext")
            }
        } description: {
            switch build.status {
            case .failed:
                Text("Fix the errors to see a preview.")
            case .neverBuilt, .cancelled:
                Text("Compile to see your document here.")
            default:
                EmptyView()
            }
        } actions: {
            switch build.status {
            case .failed:
                Button("Show Problems") { drawer = .problems }
            case .neverBuilt, .cancelled, .compiled:
                Button("Compile") { project.compile() }
            case .unavailable(let problem):
                if problem == .noEngine {
                    ToolInstallControl(tool: .tectonic, isProminent: true)
                }
                SettingsLink {
                    Text("Open Settings")
                }
            case .compiling:
                EmptyView()
            }
        }
        .foregroundStyle(AppTheme.textSecondary)
    }
}
