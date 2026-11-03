//
//  DiffHunkView.swift
//  PolarBear
//

import SwiftUI

/// The lines of one hunk, in a box with a hairline.
struct DiffHunkView: View {
    let hunk: TextDiff.Hunk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                DiffLineRow(line: line)
            }
        }
        .clipShape(.rect(cornerRadius: AppTheme.Radius.badge))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.badge, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    /// The hunk's lines without empty context lines at its top and bottom (a file's final
    /// newline would otherwise show up as a stray blank row).
    private var visibleLines: [TextDiff.Line] {
        var lines = hunk.lines[...]
        while let first = lines.first, first.kind == .context, first.text.isEmpty { lines = lines.dropFirst() }
        while let last = lines.last, last.kind == .context, last.text.isEmpty { lines = lines.dropLast() }
        return Array(lines)
    }
}
