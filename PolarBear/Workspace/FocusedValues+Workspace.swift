//
//  FocusedValues+Workspace.swift
//  PolarBear
//

import SwiftUI

extension FocusedValues {
    /// The frontmost window's state, so menu commands act on the right window.
    @Entry var window: WindowState?
    /// The frontmost window's workspace; `nil` while it shows the welcome screen.
    @Entry var workspace: WorkspaceModel?
}
