//
//  WorkspaceRoot.swift
//  PolarBear
//

import SwiftUI

/// The workspace of one project, with the dialogs that act on it.
struct WorkspaceRoot: View {
    @Bindable var workspace: WorkspaceModel

    var body: some View {
        WorkspaceView()
            .environment(workspace)
            .alert(Text(workspace.promptTitle), item: $workspace.prompt) { _ in
                TextField("Name", text: $workspace.promptText)
                Button(workspace.promptConfirmTitle, action: workspace.confirmPrompt)
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Move to Trash?", item: $workspace.deletionRequest) { request in
                Button("Move “\(request.name)” to Trash", role: .destructive, action: workspace.confirmDelete)
            } message: { _ in
                Text("You can restore it from the Trash.")
            }
            .sheet(isPresented: $workspace.isPreviewSheetPresented) {
                PDFPreviewSheet()
                    .environment(workspace)
            }
            .onChange(of: workspace.project.structureRevision) {
                workspace.prune()
            }
    }
}
