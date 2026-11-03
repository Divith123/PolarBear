//
//  ContentView.swift
//  PolarBear
//

import SwiftUI

/// The content of one window: the welcome screen until a project is open, then the workspace.
struct ContentView: View {
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @State private var window = WindowState()

    var body: some View {
        ZStack {
            if !library.profile.isSetUp {
                OnboardingView()
            } else if let workspace = window.workspace {
                WorkspaceRoot(workspace: workspace)
            } else {
                WelcomeView()
            }
        }
        .environment(window)
        .frame(minWidth: AppTheme.Metrics.minWindowWidth, minHeight: AppTheme.Metrics.minWindowHeight)
        .background(AppTheme.appBackground)
        .ignoresSafeArea(edges: .top)
        .appAppearance()
        .navigationTitle(windowTitle)
        .background { WindowConfigurator(window: window) }
        .focusedSceneValue(\.window, window)
        .focusedSceneValue(\.workspace, window.workspace)
        .alert(window.alert.map { String(localized: $0.title) } ?? "", item: $window.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .sheet(item: $window.sheet) { sheet in
            WindowSheetContent(sheet: sheet)
                .environment(window)
                .environment(library)
        }
        .overlay {
            if window.isOpening {
                ProgressView()
                    .controlSize(.large)
                    .padding(AppTheme.Spacing.xxl)
                    .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.pill))
            }
        }
        .task { await window.restoreLastProject(library: library) }
        .onOpenURL { url in
            Task { await window.openExternal(url, library: library) { openWindow(id: "main") } }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            window.workspace?.project.saveNowBlocking()
            ProcessRegistry.terminateAll()
        }
    }

    private var windowTitle: String {
        guard let workspace = window.workspace else { return "PolarBear" }
        let project = workspace.project.name
        guard let name = workspace.activeFile?.name else { return "\(project) — PolarBear" }
        return "\(name) — \(project)"
    }
}

#Preview {
    ContentView()
        .environment(ProjectLibrary())
        .frame(width: AppTheme.Metrics.defaultWindowWidth, height: AppTheme.Metrics.defaultWindowHeight)
}
