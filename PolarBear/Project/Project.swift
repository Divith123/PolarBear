//
//  Project.swift
//  PolarBear
//

import Foundation
import Observation

/// A LaTeX project: a real folder on disk. The files are the single source of truth — the
/// editor shows what is on disk, edits are written back atomically, and changes made by other
/// programs (an agent, Git, another editor) are picked up through a file-system watcher.
///
/// A project is shared by every window that shows it; window-specific state (open tabs, sidebar)
/// lives in `WorkspaceModel`. The behaviour is split over the `Project+…` extensions.
@Observable
final class Project: Identifiable {
    let root: URL
    var files: [ProjectFile]
    var assets: [ProjectAsset]
    var folders: [String]
    /// Bumped when a file or folder is added, removed or renamed.
    var structureRevision = 0
    /// The folder was bigger than the app reads (see `ProjectScanner`); part of it is not shown.
    var isTruncated = false
    /// Bumped on every edit; compared with `BuildModel.lastBuiltRevision`.
    var editRevision = 0
    var settings: ProjectSettings {
        didSet { if settings != oldValue { scheduleSettingsSave() } }
    }

    let build = BuildModel()
    let history: HistoryModel
    let sync: SyncTeXService
    let agent = AgentModel()

    @ObservationIgnored let toolchain: ToolchainModel
    @ObservationIgnored let scope: SecurityScope?
    @ObservationIgnored var folderWatcher: FolderWatcher?
    @ObservationIgnored var watcherTask: Task<Void, Never>?
    @ObservationIgnored let saveDebouncer = Debouncer()
    @ObservationIgnored let reconcileDebouncer = Debouncer()
    @ObservationIgnored let settingsDebouncer = Debouncer()
    @ObservationIgnored var savingTask: Task<[FileKind], Never>?
    @ObservationIgnored var reconcileAfterSave = false

    var id: String {
        root.projectKey
    }

    var name: String {
        root.lastPathComponent
    }

    /// Whether the PDF predates the latest edit.
    var isPDFOutOfDate: Bool {
        build.lastBuiltRevision < editRevision
    }

    init(root: URL, scope: SecurityScope?, settings: ProjectSettings, scan: ProjectScanner.Scan, toolchain: ToolchainModel) {
        self.root = root
        self.scope = scope
        self.settings = settings
        self.toolchain = toolchain
        self.history = HistoryModel(root: root)
        self.sync = SyncTeXService(root: root)

        files = scan.files.compactMap { scanned in
            guard case .loaded(let decoded) = scanned.content else { return nil }
            return ProjectFile(
                path: scanned.path,
                text: decoded.text,
                encoding: decoded.encoding,
                usesCRLF: decoded.usesCRLF,
                stamp: scanned.stamp
            )
        }
        assets = scan.assets.map(ProjectAsset.init)
        folders = scan.folders
        isTruncated = scan.isTruncated

        build.provider = { [weak self] in self?.makeBuildRequest() ?? .failure(.noRootFile) }
        build.revisionProvider = { [weak self] in self?.editRevision ?? 0 }
        build.prepare = { [weak self] in await self?.saveDirtyFiles(triggersBuild: false) }
        build.didFinish = { [weak self] outcome in self?.buildDidFinish(outcome) }
        history.sourceProvider = { [weak self] in self?.historySources() ?? [] }
        sync.source = { [weak self] in (self?.build.publishedSyncTeX, self?.build.publishedGeneration ?? 0) }
        agent.project = self
    }

    isolated deinit {
        saveNowBlocking()
        watcherTask?.cancel()
        build.cancel()
    }

    /// Keeps the lists sorted and tells observers the structure changed.
    func noteStructureChange() {
        files.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        assets.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        folders.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        structureRevision += 1
    }
}
