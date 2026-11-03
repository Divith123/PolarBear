//
//  ProjectFile.swift
//  PolarBear
//

import Foundation
import Observation

/// One text file of the project. Instances are shared by the project, the editor and the
/// sidebar, so edits show up everywhere without copying.
///
/// In memory the text always uses `\n`; the file's original line endings and encoding are
/// restored when it is written.
@Observable
final class ProjectFile: Identifiable {
    let id = UUID()
    private(set) var path: String
    var text: String
    var isDirty = false
    /// The text currently on disk when it differs from unsaved edits made here.
    var conflict: String?
    var saveError: String?
    /// Bumped whenever `text` is replaced from outside the editor, so the editor reloads it.
    private(set) var externalRevision = 0

    @ObservationIgnored let encoding: String.Encoding
    @ObservationIgnored let usesCRLF: Bool
    @ObservationIgnored private(set) var lastDiskText: String
    @ObservationIgnored private(set) var stamp: FileStamp
    @ObservationIgnored var viewState: EditorViewState?

    init(path: String, text: String, encoding: String.Encoding, usesCRLF: Bool, stamp: FileStamp) {
        self.path = path
        self.text = text
        self.encoding = encoding
        self.usesCRLF = usesCRLF
        self.lastDiskText = text
        self.stamp = stamp
    }

    var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    var kind: FileKind {
        FileKind(path: path)
    }

    /// LaTeX and Markdown sources get syntax highlighting and an outline.
    var language: SourceLanguage {
        SourceLanguage(kind: kind)
    }

    /// The bytes to write: the text with the file's own line endings.
    var serializedText: String {
        usesCRLF ? text.replacing("\n", with: "\r\n") : text
    }

    func moved(to newPath: String) {
        path = newPath
    }

    /// Replaces the text with what another program wrote to disk.
    func adoptDisk(text newText: String, stamp newStamp: FileStamp) {
        text = newText
        lastDiskText = newText
        stamp = newStamp
        isDirty = false
        conflict = nil
        externalRevision += 1
    }

    /// Replaces the text with something the app produced (an accepted agent edit, a restored
    /// version). It counts as an unsaved edit.
    func replaceText(_ newText: String) {
        guard newText != text else { return }
        text = newText
        isDirty = true
        externalRevision += 1
    }

    func markSaved(text savedText: String, stamp newStamp: FileStamp) {
        lastDiskText = savedText
        stamp = newStamp
        if text == savedText { isDirty = false }
        saveError = nil
    }

    /// The user chose to keep their edits over the version on disk.
    func resolveConflictKeepingMine() {
        if let conflict { lastDiskText = conflict }
        conflict = nil
        isDirty = true
    }

    func resolveConflictLoadingDisk(stamp newStamp: FileStamp) {
        if let conflict { adoptDisk(text: conflict, stamp: newStamp) }
    }

    func noteDiskStamp(_ newStamp: FileStamp) {
        stamp = newStamp
    }
}
