//
//  WorkspaceModel.swift
//  PolarBear
//

import Foundation
import Observation

/// State of one window's workspace: open tabs, the active file, sidebar, drawer and dialogs.
/// The files themselves belong to the shared `Project`.
@Observable
final class WorkspaceModel {
    let project: Project
    let preview: PreviewController
    @ObservationIgnored private weak var window: WindowState?
    @ObservationIgnored private let outlineDebouncer = Debouncer()

    private(set) var openTabIDs: [ProjectFile.ID] = []
    private(set) var activeID: ProjectFile.ID?
    private(set) var outline: [OutlineItem] = []

    var expandedFolders: Set<String>
    var sidebarVisible = true
    var sidebarTab: SidebarTab = .files
    /// The panels the layout menu can hide. At least one of the editor and the preview stays.
    var showsEditor = true
    var showsPreview = true
    var showsAssistant = true
    var revealRequest: RevealRequest?
    var prompt: FilePrompt?
    var promptText = ""
    var deletionRequest: DeletionRequest?
    var isPreviewSheetPresented = false
    var drawer: DrawerTab?
    /// Window facts reported by `WorkspaceView`.
    var isPreviewDocked = true

    /// The caret line of the active editor; read when jumping to the PDF, so it is not observed.
    @ObservationIgnored var caretLine = 1

    init(project: Project, window: WindowState) {
        self.project = project
        self.window = window
        self.expandedFolders = Set(project.folders)
        self.preview = PreviewController(zoom: PDFZoom(percent: project.settings.previewZoomPercent))

        preview.onZoomChange = { [weak project] zoom in
            project?.settings.previewZoomPercent = zoom.percent
        }

        openTabIDs = project.settings.openTabs.compactMap { project.file(atPath: $0)?.id }
        if openTabIDs.isEmpty, let root = project.resolvedRootFile, let file = project.file(atPath: root) {
            openTabIDs = [file.id]
        }
        if let path = project.settings.activeTab, let id = project.file(atPath: path)?.id, openTabIDs.contains(id) {
            activeID = id
        } else {
            activeID = openTabIDs.first
        }
        refreshOutline()
    }

    // MARK: Derived state

    var activeFile: ProjectFile? {
        activeID.flatMap { project.file(withID: $0) }
    }

    var openFiles: [ProjectFile] {
        openTabIDs.compactMap { project.file(withID: $0) }
    }

    // MARK: Tabs

    func open(_ file: ProjectFile) {
        if !openTabIDs.contains(file.id) {
            if let activeID, let index = openTabIDs.firstIndex(of: activeID) {
                openTabIDs.insert(file.id, at: index + 1)
            } else {
                openTabIDs.append(file.id)
            }
        }
        activate(file.id)
        tabsChanged()
    }

    /// Opens `path` and puts the caret on `line`.
    func open(path: String, line: Int?) {
        guard let file = project.file(atPath: path) else { return }
        open(file)
        if let line { revealRequest = RevealRequest(fileID: file.id, line: line) }
    }

    func activate(_ id: ProjectFile.ID) {
        guard openTabIDs.contains(id), activeID != id else { return }
        activeID = id
        activeFileChanged()
    }

    func close(_ id: ProjectFile.ID) {
        guard let index = openTabIDs.firstIndex(of: id) else { return }
        openTabIDs.remove(at: index)
        if activeID == id {
            activeID = openTabIDs.indices.contains(index) ? openTabIDs[index] : openTabIDs.last
        }
        activeFileChanged()
    }

    func closeActive() {
        if let activeID { close(activeID) }
    }

    func selectNextTab() {
        cycleTab(by: 1)
    }

    func selectPreviousTab() {
        cycleTab(by: -1)
    }

    private func cycleTab(by offset: Int) {
        guard !openTabIDs.isEmpty else { return }
        let current = activeID.flatMap { openTabIDs.firstIndex(of: $0) } ?? 0
        activate(openTabIDs[(current + offset + openTabIDs.count) % openTabIDs.count])
    }

    /// Drops tabs whose files no longer exist (deleted outside the app, for example).
    func prune() {
        let alive = Set(project.files.map(\.id))
        let kept = openTabIDs.filter(alive.contains)
        guard kept != openTabIDs else { return }
        openTabIDs = kept
        if let activeID, !alive.contains(activeID) { self.activeID = kept.last }
        activeFileChanged()
    }

    /// Called by the editor after the user changed `file`'s text.
    func textDidChange(in file: ProjectFile) {
        project.noteEdit(in: file)
        guard file.id == activeID else { return }
        // Typing restarts the timer, so a long document is parsed once typing pauses.
        outlineDebouncer.schedule(after: .milliseconds(250)) { [weak self] in
            self?.refreshOutline()
        }
    }

    func caretMoved(in file: ProjectFile, to line: Int) {
        if file.id == activeID { caretLine = line }
    }

    private func activeFileChanged() {
        refreshOutline()
        tabsChanged()
        // A Markdown project previews the file being edited, so switching files re-renders.
        if project.settings.mode == .markdown, activeFile?.kind == .markdown {
            project.build.requestBuild(after: .milliseconds(150))
        }
    }

    private func tabsChanged() {
        project.rememberTabs(open: openFiles.map(\.path), active: activeFile?.path)
    }

    func refreshOutline() {
        guard let file = activeFile else {
            outline = []
            return
        }
        outline = OutlineParser.items(in: file.text, language: file.language)
    }

    // MARK: Sidebar, outline, drawer

    func toggleSidebar() {
        sidebarVisible.toggle()
    }

    func selectSidebarTab(_ tab: SidebarTab) {
        sidebarTab = tab
    }

    func reveal(line: Int) {
        guard let activeID else { return }
        revealRequest = RevealRequest(fileID: activeID, line: line)
    }

    func presentPreview() {
        isPreviewSheetPresented = true
    }

    func toggleDrawer(_ tab: DrawerTab) {
        drawer = (drawer == tab) ? nil : tab
    }

    func toggleFolder(_ path: String) {
        if expandedFolders.contains(path) {
            expandedFolders.remove(path)
        } else {
            expandedFolders.insert(path)
        }
    }

    // MARK: Prompts: new file, new folder, rename

    func promptNewFile(in folder: String = "") {
        promptText = project.uniquePath(for: ProjectPath.join(folder, "untitled.tex")).split(separator: "/").last.map(String.init) ?? "untitled.tex"
        prompt = .newFile(folder: folder)
    }

    func promptNewFolder(in parent: String = "") {
        promptText = "New Folder"
        prompt = .newFolder(parent: parent)
    }

    func promptRename(_ path: String) {
        promptText = ProjectPath.name(of: path)
        prompt = .rename(path: path)
    }

    var promptTitle: LocalizedStringResource {
        switch prompt {
        case .newFile: "New File"
        case .newFolder: "New Folder"
        case .rename: "Rename"
        case nil: ""
        }
    }

    var promptConfirmTitle: LocalizedStringResource {
        switch prompt {
        case .newFile, .newFolder: "Create"
        case .rename: "Rename"
        case nil: "OK"
        }
    }

    func confirmPrompt() {
        guard let prompt else { return }
        let text = promptText
        Task {
            do {
                try await perform(prompt, with: text)
            } catch {
                window?.report(error)
            }
        }
    }

    private func perform(_ prompt: FilePrompt, with text: String) async throws {
        switch prompt {
        case .newFile(let folder):
            let name = ProjectPath.sanitisedFileName(text)
            guard !name.isEmpty else { return }
            let file = try await project.createFile(at: ProjectPath.join(folder, name))
            expandedFolders.insert(folder)
            open(file)
        case .newFolder(let parent):
            let name = ProjectPath.sanitisedFileName(text, defaultExtension: nil)
            guard !name.isEmpty else { return }
            let path = try project.createFolder(at: ProjectPath.join(parent, name))
            expandedFolders.formUnion(ProjectPath.ancestors(of: path + "/x"))
        case .rename(let path):
            let name = ProjectPath.sanitisedFileName(text, defaultExtension: nil)
            guard !name.isEmpty else { return }
            let newPath = try project.move(path, to: ProjectPath.join(ProjectPath.parent(of: path), name))
            if expandedFolders.contains(path) {
                expandedFolders.remove(path)
                expandedFolders.insert(newPath)
            }
            tabsChanged()
        }
    }

    // MARK: Files

    func requestDelete(_ path: String) {
        deletionRequest = DeletionRequest(path: path)
    }

    func confirmDelete() {
        guard let request = deletionRequest else { return }
        deletionRequest = nil
        do {
            try project.trash(request.path)
            prune()
        } catch {
            window?.report(error)
        }
    }

    func duplicate(_ file: ProjectFile) {
        Task {
            do {
                open(try await project.duplicate(file))
            } catch {
                window?.report(error)
            }
        }
    }

    func addFilesFromPanel(to folder: String = "") {
        let urls = FilePanels.chooseFiles(message: String(localized: "Choose files to copy into the project."))
        copyIn(urls, to: folder)
    }

    func copyIn(_ urls: [URL], to folder: String = "") {
        guard !urls.isEmpty else { return }
        Task {
            do {
                try await project.copyIn(urls, toFolder: folder)
            } catch {
                window?.report(error)
            }
        }
    }

    func report(_ error: Error) {
        window?.report(error)
    }
}

extension WorkspaceModel {
    private static let previewWindow = WindowState()

    /// A window model over a throw-away project, for previews.
    static var preview: WorkspaceModel {
        WorkspaceModel(project: .preview, window: previewWindow)
    }
}
