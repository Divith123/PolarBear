//
//  LayoutToggles.swift
//  PolarBear
//

import SwiftUI

/// Show or hide the panels of the workspace: code, PDF, sidebar and assistant.
struct LayoutToggles: View {
    let workspace: WorkspaceModel

    var body: some View {
        Toggle("Code", isOn: Bindable(workspace).showsEditor)
            .disabled(workspace.showsEditor && !workspace.showsPreview)
        Toggle("PDF", isOn: Bindable(workspace).showsPreview)
            .disabled(workspace.showsPreview && !workspace.showsEditor)
        Toggle("Sidebar", isOn: Bindable(workspace).sidebarVisible)
        Toggle("Assistant", isOn: Bindable(workspace).showsAssistant)
    }
}
