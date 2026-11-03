//
//  ProjectSettings.swift
//  PolarBear
//

import Foundation
import os

/// Per-project choices, stored in `.PolarBear/project.json`. Every field has a default, so
/// files written by older versions (or by hand) keep loading.
nonisolated struct ProjectSettings: Codable, Equatable, Sendable {
    /// What the project is written in: TeX (compiled by an engine) or Markdown (rendered by PolarBear).
    var mode = DocumentMode.tex
    /// `nil` means "choose automatically": the magic comment, then the best installed engine.
    var engine: TeXEngine?
    /// Path of the main `.tex` file; `nil` means "find the file with `\documentclass`".
    var rootFile: String?
    var realtimeCompile = true
    /// Markdown projects download the web images a document uses (https only) before rendering.
    var loadsRemoteImages = true
    var shellEscape = false
    var openTabs: [String] = []
    var activeTab: String?
    var selectedAgent: String?
    /// Agents the user allowed to run in this project (asked once per project).
    var consentedAgents: [String] = []
    /// Fixed zoom of the preview in percent; `nil` fits the page to the panel.
    var previewZoomPercent: Int?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case mode, engine, rootFile, realtimeCompile, loadsRemoteImages, shellEscape, openTabs, activeTab
        case selectedAgent, consentedAgents, previewZoomPercent
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decodeIfPresent(DocumentMode.self, forKey: .mode) ?? .tex
        engine = try values.decodeIfPresent(TeXEngine.self, forKey: .engine)
        rootFile = try values.decodeIfPresent(String.self, forKey: .rootFile)
        realtimeCompile = try values.decodeIfPresent(Bool.self, forKey: .realtimeCompile) ?? true
        loadsRemoteImages = try values.decodeIfPresent(Bool.self, forKey: .loadsRemoteImages) ?? true
        shellEscape = try values.decodeIfPresent(Bool.self, forKey: .shellEscape) ?? false
        openTabs = try values.decodeIfPresent([String].self, forKey: .openTabs) ?? []
        activeTab = try values.decodeIfPresent(String.self, forKey: .activeTab)
        selectedAgent = try values.decodeIfPresent(String.self, forKey: .selectedAgent)
        consentedAgents = try values.decodeIfPresent([String].self, forKey: .consentedAgents) ?? []
        previewZoomPercent = try values.decodeIfPresent(Int.self, forKey: .previewZoomPercent)
    }
}

extension ProjectSettings {
    /// The saved settings of the project at `root`, or the defaults.
    @concurrent
    static func load(from root: URL) async -> ProjectSettings {
        let url = ProjectPaths.settingsFile(in: root)
        guard let data = try? Data(contentsOf: url) else { return ProjectSettings() }
        do {
            return try JSONDecoder().decode(ProjectSettings.self, from: data)
        } catch {
            Log.project.error("Unreadable project settings, using defaults: \(error.localizedDescription, privacy: .public)")
            return ProjectSettings()
        }
    }

    @concurrent
    func save(to root: URL) async {
        ProjectPaths.prepareMetadata(in: root)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(self).write(to: ProjectPaths.settingsFile(in: root), options: .atomic)
        } catch {
            Log.project.error("Could not save project settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
