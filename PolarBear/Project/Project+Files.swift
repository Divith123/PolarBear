//
//  Project+Files.swift
//  PolarBear
//

import Foundation

/// Creating, renaming, moving and deleting files and folders. Each operation changes the disk
/// first and then updates the model, so the two never disagree for long.
extension Project {
    func file(withID id: ProjectFile.ID) -> ProjectFile? {
        files.first { $0.id == id }
    }

    func file(atPath path: String) -> ProjectFile? {
        files.first { $0.path == path }
    }

    func absoluteURL(for path: String) -> URL {
        root.appending(path: path)
    }

    /// `desired`, or a numbered variant when something already has that name (case-insensitive,
    /// like the file system).
    func uniquePath(for desired: String, ignoring ignored: String? = nil) -> String {
        var taken = Set(files.map(\.path) + assets.map(\.path) + folders)
        if let ignored { taken.remove(ignored) }
        let lowered = Set(taken.map { $0.lowercased() })
        return ProjectPath.unique(desired) { lowered.contains($0.lowercased()) }
    }

    // MARK: Create

    @discardableResult
    func createFile(at desired: String, text: String = "") async throws -> ProjectFile {
        let path = uniquePath(for: desired)
        let stamp = try await FileIO.write(text, encoding: .utf8, to: absoluteURL(for: path))
        let file = ProjectFile(path: path, text: text, encoding: .utf8, usesCRLF: false, stamp: stamp)
        files.append(file)
        addFolders(containing: path)
        editRevision += 1
        noteStructureChange()
        return file
    }

    @discardableResult
    func createFolder(at desired: String) throws -> String {
        let path = uniquePath(for: desired)
        try FileManager.default.createDirectory(at: absoluteURL(for: path), withIntermediateDirectories: true)
        addFolders(containing: path + "/x")
        noteStructureChange()
        return path
    }

    @discardableResult
    func duplicate(_ file: ProjectFile) async throws -> ProjectFile {
        let stem = ProjectPath.stem(of: file.path)
        let fileExtension = ProjectPath.fileExtension(of: file.path)
        let copyName = fileExtension.isEmpty ? "\(stem) copy" : "\(stem) copy.\(fileExtension)"
        return try await createFile(at: ProjectPath.join(ProjectPath.parent(of: file.path), copyName), text: file.text)
    }

    /// Copies files from elsewhere into the project (images, bibliographies, …).
    func copyIn(_ urls: [URL], toFolder folder: String) async throws {
        for url in urls {
            let destination = uniquePath(for: ProjectPath.join(folder, url.lastPathComponent))
            try FileManager.default.createDirectory(at: absoluteURL(for: ProjectPath.parent(of: destination)), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: absoluteURL(for: destination))
        }
        await reconcileWithDisk()
    }

    private func addFolders(containing path: String) {
        for folder in ProjectPath.ancestors(of: path) where !folders.contains(folder) {
            folders.append(folder)
        }
    }

    // MARK: Rename and move

    /// Renames or moves a file or folder. Open tabs, the main-document choice and the model follow.
    @discardableResult
    func move(_ oldPath: String, to desired: String) throws -> String {
        let isCaseOnlyChange = oldPath.lowercased() == desired.lowercased()
        let newPath = isCaseOnlyChange ? desired : uniquePath(for: desired)
        guard newPath != oldPath else { return oldPath }

        try FileManager.default.createDirectory(at: absoluteURL(for: ProjectPath.parent(of: newPath)), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: absoluteURL(for: oldPath), to: absoluteURL(for: newPath))

        func remapped(_ path: String) -> String {
            if path == oldPath { return newPath }
            if path.hasPrefix(oldPath + "/") { return newPath + path.dropFirst(oldPath.count) }
            return path
        }
        for file in files where remapped(file.path) != file.path {
            file.moved(to: remapped(file.path))
        }
        assets = assets.map { ProjectAsset(path: remapped($0.path)) }
        folders = folders.map(remapped)
        addFolders(containing: newPath)

        var updated = settings
        updated.rootFile = updated.rootFile.map(remapped)
        updated.openTabs = updated.openTabs.map(remapped)
        updated.activeTab = updated.activeTab.map(remapped)
        settings = updated

        editRevision += 1
        noteStructureChange()
        return newPath
    }

    // MARK: Delete

    /// Moves a file or folder to the Trash, so deleting is always recoverable.
    func trash(_ path: String) throws {
        try FileManager.default.trashItem(at: absoluteURL(for: path), resultingItemURL: nil)

        func isAffected(_ other: String) -> Bool {
            other == path || other.hasPrefix(path + "/")
        }
        files.removeAll { isAffected($0.path) }
        assets.removeAll { isAffected($0.path) }
        folders.removeAll(where: isAffected)

        var updated = settings
        if let rootFile = updated.rootFile, isAffected(rootFile) { updated.rootFile = nil }
        updated.openTabs.removeAll(where: isAffected)
        if let active = updated.activeTab, isAffected(active) { updated.activeTab = updated.openTabs.last }
        settings = updated

        editRevision += 1
        noteStructureChange()
    }
}
