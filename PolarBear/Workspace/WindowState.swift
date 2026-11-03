//
//  WindowState.swift
//  PolarBear
//

import SwiftUI
import Observation

/// State of one window: which project it shows (none → the welcome screen), full-screen
/// state, and the alert or sheet in front. The project's own state lives in `WorkspaceModel`.
@Observable
final class WindowState {
    private(set) var workspace: WorkspaceModel?
    var isFullScreen = false
    /// The AppKit window showing this state, set by the window chrome.
    @ObservationIgnored weak var hostWindow: NSWindow?
    var sheet: WindowSheet?
    var alert: WindowAlert?
    /// Set while a project is being opened.
    var isOpening = false

    func show(_ project: Project) {
        workspace = WorkspaceModel(project: project, window: self)
        // Opening a project builds it once per session, so the preview is never empty.
        if project.settings.realtimeCompile, project.build.records.isEmpty, !project.build.isRunning {
            project.build.requestBuild(after: .milliseconds(300))
        }
    }

    func closeProject() {
        workspace?.project.build.cancel()
        workspace = nil
    }

    func report(_ error: Error, title: LocalizedStringResource = "Something Went Wrong") {
        alert = WindowAlert(title: title, message: error.localizedDescription)
    }
}
