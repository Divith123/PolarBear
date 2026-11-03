//
//  WindowState+External.swift
//  PolarBear
//

import SwiftUI

/// Opening what the system hands over: a folder dropped on the Dock icon, "Open With" on a
/// `.tex` file, `open -a PolarBear <folder>`.
extension WindowState {
    /// - Parameter openInNewWindow: called when this window already shows a project.
    func openExternal(_ url: URL, library: ProjectLibrary, openInNewWindow: () -> Void) async {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) else { return }

        let folder = isDirectory.boolValue ? url : url.deletingLastPathComponent()
        let file = isDirectory.boolValue ? nil : ProjectPaths.relativePath(of: url, in: folder.resolvingSymlinksInPath())

        if let workspace, workspace.project.id == folder.projectKey {
            if let file { workspace.open(path: file, line: nil) }
            return
        }
        // Opening a folder that another window already shows brings that window forward.
        if workspace == nil, let existing = windowShowing(folder) {
            existing.makeKeyAndOrderFront(nil)
            hostWindow?.close()
            return
        }
        guard workspace == nil else {
            library.pendingOpen = url
            openInNewWindow()
            return
        }
        await open(folder, library: library)
        if let file { workspace?.open(path: file, line: nil) }
    }
}
