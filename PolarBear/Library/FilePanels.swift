//
//  FilePanels.swift
//  PolarBear
//

import SwiftUI
import UniformTypeIdentifiers

/// The system open / save panels the app needs.
enum FilePanels {
    static func chooseFolder(message: String, prompt: String = String(localized: "Open")) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = prompt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseFiles(message: String) -> [URL] {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Add")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func chooseImage(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseArchive(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Import")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip, .gzip, .archive]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseSaveLocation(suggestedName: String, message: String) -> URL? {
        let panel = NSSavePanel()
        panel.message = message
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
