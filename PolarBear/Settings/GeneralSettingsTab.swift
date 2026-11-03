//
//  GeneralSettingsTab.swift
//  PolarBear
//

import SwiftUI

struct GeneralSettingsTab: View {
    var body: some View {
        Form {
            Section("Profile") {
                ProfileSettingsSection()
            }
            Section("Appearance") {
                AppearancePicker()
                    .pickerStyle(.segmented)
                    .labelsHidden()
            }
            Section("Privacy") {
                Label("No account, no telemetry, no tracking.", systemImage: "hand.raised")
                Label("Your projects are ordinary folders on your Mac.", systemImage: "folder")
                Label("AI is off until you pick an agent you already run yourself.", systemImage: "sparkles")
            }
            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
        }
        .formStyle(.grouped)
    }
}
