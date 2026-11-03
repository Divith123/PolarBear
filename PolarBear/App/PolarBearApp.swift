//
//  PolarBearApp.swift
//  PolarBear
//

import SwiftUI

@main
struct PolarBearApp: App {
    @State private var library = ProjectLibrary()

    init() {
        // The app reopens the last project itself; macOS's own window restoration only gets in
        // the way (a stale record can stop the first window from opening at all).
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true, "NSQuitAlwaysKeepsWindows": false])
    }

    var body: some Scene {
        // Opens first, shows for two seconds, then opens the main window.
        Window("PolarBear", id: "splash") {
            SplashView()
                .environment(library)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
        .commandsRemoved()

        WindowGroup(id: "main") {
            ContentView()
                .environment(library)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: AppTheme.Metrics.defaultWindowWidth, height: AppTheme.Metrics.defaultWindowHeight)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            WorkspaceCommands(library: library)
        }

        WindowGroup("Preview", id: "preview", for: String.self) { $path in
            PreviewWindowView(projectPath: path)
                .environment(library)
        }
        .defaultSize(width: AppTheme.Metrics.previewIdeal, height: AppTheme.Metrics.defaultWindowHeight)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView()
                .environment(library)
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
