//
//  SettingsView.swift
//  PolarBear
//

import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            CompileSettingsTab()
                .tabItem { Label("Compile", systemImage: "hammer") }
            AgentsSettingsTab()
                .tabItem { Label("Agents", systemImage: "sparkles") }
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 560, height: 560)
        .appAppearance()
    }
}
