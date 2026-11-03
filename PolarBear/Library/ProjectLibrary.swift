//
//  ProjectLibrary.swift
//  PolarBear
//

import Foundation
import Observation

/// App-wide: the recently opened projects, the projects currently open (shared between
/// windows) and the TeX toolchain.
@Observable
final class ProjectLibrary {
    enum OpenError: LocalizedError {
        case folderMissing(String)

        var errorDescription: String? {
            switch self {
            case .folderMissing(let name):
                String(localized: "The folder “\(name)” can no longer be found.")
            }
        }
    }

    private static let recentsKey = "recentProjects"
    private static let maximumRecents = 30

    private(set) var recents: [RecentProject]
    let toolchain = ToolchainModel()
    let agents = AgentCatalog()
    let profile = ProfileModel()
    let installer = ToolInstaller()

    /// The first window of a launch reopens the last project; later windows start empty.
    @ObservationIgnored var restoresLastProject = true
    @ObservationIgnored private var openProjects: [String: WeakProject] = [:]
    /// A project another window asked this one to show.
    @ObservationIgnored var pendingOpen: URL?
    /// Set when the preview window about to open should go full screen.
    @ObservationIgnored var fullScreenPreviewPath: String?

    private struct WeakProject {
        weak var project: Project?
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.recentsKey),
           let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) {
            recents = decoded
        } else {
            recents = []
        }
    }

    // MARK: Installing tools

    /// Downloads and installs Tectonic or OpenCode, then looks for the new program.
    func install(_ tool: ManagedTool) {
        installer.install(tool) { [self] in
            await toolchain.refresh()
            await agents.refresh()
        }
    }

    /// Removes a program PolarBear installed.
    func uninstall(_ tool: ManagedTool) {
        installer.remove(tool) { [self] in
            await toolchain.refresh()
            await agents.refresh()
        }
    }

    // MARK: Opening

    /// The project for the folder at `url` — the one already open, or a newly opened one.
    func project(at url: URL) async -> Project {
        let key = url.projectKey
        if let existing = openProjects[key]?.project { return existing }

        if !toolchain.hasSearched { await toolchain.refresh() }
        if !agents.hasSearched { await agents.refresh() }
        let project = await Project.open(at: url, scope: SecurityScope(url: url), toolchain: toolchain)
        openProjects[key] = WeakProject(project: project)
        remember(project)
        return project
    }

    func project(for recent: RecentProject) async throws -> Project {
        guard let url = resolve(recent) else { throw OpenError.folderMissing(recent.name) }
        return await project(at: url)
    }

    /// The project already open for `path`, if any (used by secondary windows).
    func openProject(atPath path: String) -> Project? {
        openProjects[path]?.project
    }

    func lastRecent() -> RecentProject? {
        recents.first { resolve($0) != nil }
    }

    // MARK: Recents

    func forget(_ recent: RecentProject) {
        recents.removeAll { $0.id == recent.id }
        persist()
    }

    private func remember(_ project: Project) {
        let bookmark = (try? project.root.bookmarkData(options: .withSecurityScope)) ?? Data()
        recents.removeAll { $0.path == project.id }
        recents.insert(RecentProject(path: project.id, name: project.name, bookmark: bookmark, lastOpened: .now), at: 0)
        if recents.count > Self.maximumRecents { recents.removeLast(recents.count - Self.maximumRecents) }
        persist()
    }

    private func resolve(_ recent: RecentProject) -> URL? {
        if !recent.bookmark.isEmpty {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: recent.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                return url
            }
        }
        let url = URL(filePath: recent.path, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: recent.path) ? url : nil
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: Self.recentsKey)
        }
    }
}
