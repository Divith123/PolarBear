//
//  FileRowActions.swift
//  PolarBear
//

import Foundation

/// What the rows of the file tree can do. The workspace builds one and the rows share it, so
/// each row depends only on its own data and this bundle of closures.
struct FileRowActions {
    var open: (ProjectFile) -> Void
    var rename: (String) -> Void
    var duplicate: (ProjectFile) -> Void
    var reveal: (String) -> Void
    var delete: (String) -> Void
    var toggleFolder: (String) -> Void
    var newFile: (String) -> Void
    var newFolder: (String) -> Void
    var addFiles: (String) -> Void
    var openExternally: (String) -> Void
}
