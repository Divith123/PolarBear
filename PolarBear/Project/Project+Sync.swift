//
//  Project+Sync.swift
//  PolarBear
//

import Foundation
import os

/// Keeping memory and disk in step: autosave, the folder watcher and conflict handling.
extension Project {
    // MARK: Editing

    /// The editor calls this after the user changed `file`'s text.
    func noteEdit(in file: ProjectFile) {
        file.isDirty = true
        editRevision += 1
        history.noteEdit()
        saveDebouncer.schedule(after: AppTheme.Timing.autosaveDelay) { [weak self] in
            await self?.saveDirtyFiles(triggersBuild: true)
        }
    }

    // MARK: Saving

    /// Writes unsaved files synchronously. Only for the moments when waiting is not possible:
    /// the app is quitting or the project is being released.
    func saveNowBlocking() {
        for file in files where file.isDirty && file.conflict == nil {
            guard let data = file.serializedText.data(using: file.encoding) else { continue }
            let url = absoluteURL(for: file.path)
            do {
                try data.write(to: url, options: .atomic)
                file.markSaved(text: file.text, stamp: FileIO.stamp(of: url) ?? .none)
            } catch {
                Log.project.error("Could not save \(file.path, privacy: .public) on exit: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Writes every unsaved file (atomically). Returns whether anything was written.
    @discardableResult
    func saveDirtyFiles(triggersBuild: Bool) async -> Bool {
        if let current = savingTask { _ = await current.value }
        guard files.contains(where: { $0.isDirty && $0.conflict == nil }) else { return false }

        let task = Task { await writeDirtyFiles() }
        savingTask = task
        let wrote = await task.value
        if savingTask == task { savingTask = nil }

        if wrote.isEmpty == false, triggersBuild, settings.realtimeCompile, wrote.contains(where: { $0.isBuildInput(in: settings.mode) }) {
            build.requestBuild(after: .milliseconds(700))
        }
        if reconcileAfterSave {
            reconcileAfterSave = false
            await reconcileWithDisk()
        }
        return !wrote.isEmpty
    }

    /// The kinds of file that were written.
    private func writeDirtyFiles() async -> [FileKind] {
        var written: [FileKind] = []
        for file in files where file.isDirty && file.conflict == nil {
            let snapshot = file.text
            do {
                let stamp = try await FileIO.write(file.serializedText, encoding: file.encoding, to: absoluteURL(for: file.path))
                file.markSaved(text: snapshot, stamp: stamp)
                written.append(file.kind)
            } catch {
                file.saveError = error.localizedDescription
                Log.project.error("Could not save \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return written
    }

    // MARK: Watching

    func startWatching() {
        let watcher = FolderWatcher(root: root)
        folderWatcher = watcher
        watcherTask = Task { [weak self] in
            for await _ in watcher.changes {
                guard let self else { return }
                reconcileDebouncer.schedule(after: .milliseconds(150)) { [weak self] in
                    await self?.reconcileWithDisk()
                }
            }
        }
    }

    /// Re-reads the folder and merges what changed outside the app into the open files.
    func reconcileWithDisk() async {
        if savingTask != nil {
            reconcileAfterSave = true
            return
        }
        let known = Dictionary(files.map { ($0.path, $0.stamp) }, uniquingKeysWith: { first, _ in first })
        let scan = await ProjectScanner.scan(root: root, known: known)
        apply(scan)
    }

    private func apply(_ scan: ProjectScanner.Scan) {
        var existing = Dictionary(files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [ProjectFile] = []

        for scanned in scan.files {
            if let file = existing.removeValue(forKey: scanned.path) {
                if case .loaded(let decoded) = scanned.content {
                    mergeExternalChange(decoded, stamp: scanned.stamp, into: file)
                }
                result.append(file)
            } else if case .loaded(let decoded) = scanned.content {
                result.append(
                    ProjectFile(path: scanned.path, text: decoded.text, encoding: decoded.encoding, usesCRLF: decoded.usesCRLF, stamp: scanned.stamp)
                )
            }
        }
        // Gone from disk. Unsaved work is kept (the next save writes it again).
        result += existing.values.filter(\.isDirty)

        result.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let newAssets = scan.assets.map(ProjectAsset.init)
        let changed = result.map(\.path) != files.map(\.path) || newAssets != assets || scan.folders != folders
        files = result
        assets = newAssets
        folders = scan.folders
        isTruncated = scan.isTruncated
        if changed { structureRevision += 1 }
    }

    private func mergeExternalChange(_ decoded: FileIO.DecodedText, stamp: FileStamp, into file: ProjectFile) {
        // A scan that started before our own latest write must not undo it.
        if stamp.modified < file.stamp.modified { return }
        if decoded.text == file.lastDiskText {
            file.noteDiskStamp(stamp)
            return
        }
        if file.isDirty, file.text != decoded.text {
            file.conflict = decoded.text
            return
        }
        file.adoptDisk(text: decoded.text, stamp: stamp)
        editRevision += 1
        if settings.realtimeCompile, file.kind.isBuildInput(in: settings.mode) {
            build.requestBuild(after: .milliseconds(700))
        }
    }

    // MARK: Settings

    func scheduleSettingsSave() {
        let snapshot = settings
        let root = root
        settingsDebouncer.schedule(after: .milliseconds(400)) {
            await snapshot.save(to: root)
        }
    }

    /// Remembers which tabs are open, so the project reopens the way it was left.
    func rememberTabs(open paths: [String], active: String?) {
        guard settings.openTabs != paths || settings.activeTab != active else { return }
        settings.openTabs = paths
        settings.activeTab = active
    }
}
