//
//  OutlineParser.swift
//  PolarBear
//

/// Finds the headings of a document: `\section`, `\subsection` and `\subsubsection` in LaTeX,
/// `#`, `##` and `###` in Markdown.
enum OutlineParser {
    private static let heading = /^\s*\\((?:sub){0,2})section(\*?)\{([^}]*)\}/

    static func items(in text: String, language: SourceLanguage) -> [OutlineItem] {
        switch language {
        case .tex: texItems(in: text)
        case .markdown: markdownItems(in: text)
        case .plain: []
        }
    }

    private static func markdownItems(in text: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        var fence: MarkdownLines.Fence?
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(line)
            if let open = fence {
                if MarkdownLines.closes(line, fence: open) { fence = nil }
                continue
            }
            if let start = MarkdownLines.fenceStart(line) {
                fence = start
                continue
            }
            if let heading = MarkdownLines.atxHeading(line), !heading.text.isEmpty {
                items.append(OutlineItem(line: offset + 1, title: heading.text, level: min(heading.level - 1, 2)))
            }
        }
        return items
    }

    private static func texItems(in text: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard let match = line.firstMatch(of: heading) else { continue }
            items.append(
                OutlineItem(
                    line: offset + 1,
                    title: "\(match.2)\(match.3)",
                    level: match.1.count / 3
                )
            )
        }
        return items
    }
}
