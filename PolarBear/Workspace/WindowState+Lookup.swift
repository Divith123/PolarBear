//
//  WindowState+Lookup.swift
//  PolarBear
//

import SwiftUI

extension WindowState {
    /// Another visible window that shows the project in `folder` (found by its title, which
    /// ends in the project's name).
    func windowShowing(_ folder: URL) -> NSWindow? {
        let name = folder.lastPathComponent
        return NSApp.windows.first { candidate in
            candidate !== hostWindow && candidate.isVisible
                && (candidate.title.hasSuffix(" — \(name)") || candidate.title == "\(name) — PolarBear")
        }
    }
}
