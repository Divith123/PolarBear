//
//  WindowState+ProjectActions.swift
//  PolarBear
//

import Foundation

/// Operations on the whole project folder: rename, duplicate, move to the Trash.
extension WindowState {
    func renameProject(to name: String, library: ProjectLibrary) async {
        guard let project = workspace?.project else { return }
        let clean = ProjectPath.sanitisedFileName(name, defaultExtension: nil)
        guard !clean.isEmpty, clean != project.name else { return }

        let destination = project.root.deletingLastPathComponent().appending(path: clean, directoryHint: .isDirectory)
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            report(CocoaError(.fileWriteFileExists))
            return
        }
        await project.saveDirtyFiles(triggersBuild: false)
        let previous = RecentProject(path: project.id, name: project.name, bookmark: Data(), lastOpened: .now)
        let oldRoot = project.root
        closeProject()
        do {
            try FileManager.default.moveItem(at: oldRoot, to: destination)
            library.forget(previous)
            await open(destination, library: library)
        } catch {
            report(error)
            await open(oldRoot, library: library)
        }
    }

    /// Copies the project folder next to the original and returns the copy.
    func duplicateProject() async -> URL? {
        guard let project = workspace?.project else { return nil }
        await project.saveDirtyFiles(triggersBuild: false)
        let parent = project.root.deletingLastPathComponent()
        var destination = parent.appending(path: "\(project.name) copy", directoryHint: .isDirectory)
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            destination = parent.appending(path: "\(project.name) copy \(counter)", directoryHint: .isDirectory)
            counter += 1
        }
        do {
            try FileManager.default.copyItem(at: project.root, to: destination)
            return destination
        } catch {
            report(error)
            return nil
        }
    }

    func trashProject(library: ProjectLibrary) async {
        guard let project = workspace?.project else { return }
        let previous = RecentProject(path: project.id, name: project.name, bookmark: Data(), lastOpened: .now)
        let root = project.root
        closeProject()
        do {
            try FileManager.default.trashItem(at: root, resultingItemURL: nil)
            library.forget(previous)
        } catch {
            report(error)
            await open(root, library: library)
        }
    }
}
