//
//  WindowState+Opening.swift
//  PolarBear
//

import Foundation

/// How a window gets its project: opening a folder, a recent project, a new one from a template.
extension WindowState {
    func openFolderFromPanel(library: ProjectLibrary) async {
        guard let url = FilePanels.chooseFolder(message: String(localized: "Choose a folder that contains your LaTeX project.")) else { return }
        await open(url, library: library)
    }

    func open(_ url: URL, library: ProjectLibrary) async {
        isOpening = true
        defer { isOpening = false }
        show(await library.project(at: url))
    }

    func open(_ recent: RecentProject, library: ProjectLibrary) async {
        isOpening = true
        defer { isOpening = false }
        do {
            show(try await library.project(for: recent))
        } catch {
            library.forget(recent)
            report(error, title: "Can’t Open Project")
        }
    }

    func createProject(
        name: String,
        template: ProjectTemplate,
        in parent: URL,
        library: ProjectLibrary
    ) async {
        isOpening = true
        defer { isOpening = false }
        do {
            let folder = try await ProjectCreator.create(name: name, from: template.files, in: parent)
            show(await library.project(at: folder))
            workspace?.project.compile()
        } catch {
            report(error, title: "Can’t Create Project")
        }
    }

    /// Reopens what the user had open last, once per launch, in the first window.
    func restoreLastProject(library: ProjectLibrary) async {
        if let url = library.pendingOpen {
            library.pendingOpen = nil
            await openExternal(url, library: library, openInNewWindow: {})
            return
        }
        guard library.restoresLastProject, workspace == nil else { return }
        library.restoresLastProject = false
        if let recent = library.lastRecent() {
            await open(recent, library: library)
        }
    }
}
