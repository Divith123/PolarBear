//
//  MarkdownHTMLWriter.swift
//  PolarBear
//

import Foundation

/// Writes a `MarkdownDocument` as HTML. Images are resolved against the folder of the Markdown
/// file; remote images are never loaded (a local-first app does not phone home because a
/// document asks it to), and raw `<script>`-like tags are dropped.
nonisolated struct MarkdownHTMLWriter {
    enum ImageMode: Sendable {
        /// `src` becomes an absolute `file://` URL, so the page can be rendered anywhere.
        case absoluteFiles
        /// `src` stays as written, for HTML that is pasted next to the Markdown file.
        case asWritten
    }

    struct Issue: Equatable, Sendable {
        var message: String
    }

    enum MathMode: Sendable {
        /// Typeset as MathML (the PDF, copied HTML).
        case mathML
        /// Kept as the source text in a maths font (rich text, which cannot hold MathML).
        case source
    }

    var baseDirectory: URL?
    var imageMode = ImageMode.absoluteFiles
    var mathMode = MathMode.mathML
    /// Mermaid blocks become drawings; off for rich text, which cannot hold SVG (they stay code).
    var rendersDiagrams = true
    /// Downloaded copies of remote images, by their address.
    var remoteImages: [String: URL] = [:]
    /// Why a remote image could not be downloaded, by address.
    var remoteFailures: [String: String] = [:]
    /// Images from the web stay as written (the reader's browser loads them) instead of a placeholder.
    var keepsRemoteImagesAsWritten = false

    private(set) var issues: [Issue] = []
    private var usedIdentifiers: [String: Int] = [:]
    private var diagramCount = 0
    private var footnotes: [String: [MarkdownBlock]] = [:]
    /// Footnote names in the order they are first referenced; their position is their number.
    private var referencedFootnotes: [String] = []

    init(baseDirectory: URL?, imageMode: ImageMode = .absoluteFiles) {
        self.baseDirectory = baseDirectory
        self.imageMode = imageMode
    }

    mutating func write(_ document: MarkdownDocument) -> String {
        usedIdentifiers = [:]
        issues = []
        footnotes = document.footnotes
        referencedFootnotes = []
        return blocks(document.blocks, isTight: false) + footnoteSection()
    }

    // MARK: Blocks

    private mutating func blocks(_ blocks: [MarkdownBlock], isTight: Bool) -> String {
        var output = ""
        var index = 0
        while index < blocks.count {
            let block = blocks[index]
            // A heading must not be the last thing on a page: keep it together with what follows,
            // unless that is too long to fit on one page anyway.
            if !isTight, case .heading = block, index + 1 < blocks.count, Self.canKeepTogether(blocks[index + 1]) {
                output += "<div class=\"keep\">\n" + self.block(block, isTight: false) + self.block(blocks[index + 1], isTight: false) + "</div>\n"
                index += 2
            } else {
                output += self.block(block, isTight: isTight)
                index += 1
            }
        }
        return output
    }

    /// Whether a block is short enough to be moved to the next page together with its heading.
    private static func canKeepTogether(_ block: MarkdownBlock) -> Bool {
        switch block {
        case .heading: false
        case .code(_, let text): text.count(where: { $0 == "\n" }) < 30
        case .list(let list): list.items.count <= 10
        case .table(let table): table.rows.count <= 12
        case .html: false
        default: true
        }
    }

    private mutating func block(_ block: MarkdownBlock, isTight: Bool) -> String {
        switch block {
        case .heading(let level, let content):
            let identifier = identifier(for: MarkdownInline.plainText(of: content))
            return "<h\(level) id=\"\(identifier)\">\(inlines(content))</h\(level)>\n"
        case .paragraph(let content):
            return isTight ? inlines(content) + "\n" : "<p>\(inlines(content))</p>\n"
        case .code(let language, let text):
            if rendersDiagrams, language?.lowercased() == "mermaid" {
                diagramCount += 1
                if let drawing = MermaidRenderer.svg(text, prefix: "d\(diagramCount)") {
                    return "<figure class=\"diagram\">\n\(drawing)\n</figure>\n"
                }
                issues.append(Issue(message: "This diagram type is not supported, so it is shown as code."))
            }
            let tag = language.map { " class=\"language-\(Self.escape($0))\"" } ?? ""
            let body = CodeHighlighter.html(text, language: language) ?? Self.escape(text)
            return "<pre><code\(tag)>\(body)\n</code></pre>\n"
        case .quote(let inner):
            return quote(inner)
        case .rule:
            return "<hr>\n"
        case .html(let raw):
            return Self.sanitised(raw) + "\n"
        case .math(let formula):
            return "<div class=\"math\">\(mathMarkup(formula, display: true))</div>\n"
        case .definitions(let definitions):
            return definitionList(definitions)
        case .list(let list):
            return self.list(list)
        case .table(let table):
            return self.table(table)
        }
    }

    /// A block quote; one that starts with `[!NOTE]` (or TIP, IMPORTANT, WARNING, CAUTION) is a callout.
    private mutating func quote(_ inner: [MarkdownBlock]) -> String {
        if case .paragraph(let content)? = inner.first,
           case .text(let first)? = content.first,
           let match = first.prefixMatch(of: /\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/.ignoresCase()) {
            let kind = match.1.lowercased()
            var rest = content
            let remaining = String(first.dropFirst(match.0.count))
            rest[0] = .text(remaining)
            if remaining.isEmpty { rest.removeFirst() }
            if case .softBreak? = rest.first { rest.removeFirst() }
            var blocks = inner
            blocks[0] = .paragraph(rest)
            let body = rest.isEmpty ? self.blocks(Array(blocks.dropFirst()), isTight: false) : self.blocks(blocks, isTight: false)
            return "<div class=\"alert alert-\(kind)\">\n<p class=\"alert-title\">\(kind.capitalized)</p>\n\(body)</div>\n"
        }
        return "<blockquote>\n\(blocks(inner, isTight: false))</blockquote>\n"
    }

    private mutating func definitionList(_ definitions: [MarkdownBlock.Definition]) -> String {
        var output = "<dl>\n"
        for definition in definitions {
            output += "<dt>\(inlines(definition.term))</dt>\n"
            for detail in definition.details {
                output += "<dd>\(inlines(detail))</dd>\n"
            }
        }
        return output + "</dl>\n"
    }

    /// The numbered notes at the end of the page, for the footnotes the text refers to.
    private mutating func footnoteSection() -> String {
        guard !referencedFootnotes.isEmpty else { return "" }
        var output = "<hr class=\"footnotes-rule\">\n<section class=\"footnotes\">\n<ol>\n"
        var position = 0
        // Notes can refer to other notes, which then join the list.
        while position < referencedFootnotes.count {
            let name = referencedFootnotes[position]
            position += 1
            var body = blocks(footnotes[name] ?? [], isTight: false)
            let back = "<a class=\"footnote-back\" href=\"#fnref-\(Self.anchor(name))\">↩︎</a>"
            if let end = body.range(of: "</p>\n", options: .backwards) {
                body.replaceSubrange(end, with: " \(back)</p>\n")
            } else {
                body += "<p>\(back)</p>\n"
            }
            output += "<li id=\"fn-\(Self.anchor(name))\">\n\(body)</li>\n"
        }
        return output + "</ol>\n</section>\n"
    }

    private static func anchor(_ name: String) -> String {
        String(name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "-" })
    }

    private mutating func list(_ list: MarkdownBlock.List) -> String {
        let tag = list.start == nil ? "ul" : "ol"
        let start = (list.start.map { $0 != 1 ? " start=\"\($0)\"" : "" }) ?? ""
        var output = "<\(tag)\(start)>\n"
        for item in list.items {
            var inner = blocks(item.blocks, isTight: list.isTight)
            var attribute = ""
            if let checked = item.isChecked {
                attribute = " class=\"task\""
                inner = "<input type=\"checkbox\" disabled\(checked ? " checked" : "")> " + inner
            }
            output += "<li\(attribute)>\(inner.hasSuffix("\n") && list.isTight ? String(inner.dropLast()) : inner)</li>\n"
        }
        return output + "</\(tag)>\n"
    }

    private mutating func table(_ table: MarkdownBlock.Table) -> String {
        func style(_ index: Int) -> String {
            switch table.alignments[index] {
            case .none: ""
            case .left: " style=\"text-align:left\""
            case .center: " style=\"text-align:center\""
            case .right: " style=\"text-align:right\""
            }
        }
        var output = "<table>\n<thead>\n<tr>"
        for (index, cell) in table.header.enumerated() {
            output += "<th\(style(index))>\(inlines(cell))</th>"
        }
        output += "</tr>\n</thead>\n"
        if !table.rows.isEmpty {
            output += "<tbody>\n"
            for row in table.rows {
                output += "<tr>"
                for (index, cell) in row.enumerated() {
                    output += "<td\(style(index))>\(inlines(cell))</td>"
                }
                output += "</tr>\n"
            }
            output += "</tbody>\n"
        }
        return output + "</table>\n"
    }

    // MARK: Inlines

    private mutating func inlines(_ inlines: [MarkdownInline]) -> String {
        var output = ""
        for inline in inlines {
            output += self.inline(inline)
        }
        return output
    }

    private mutating func inline(_ inline: MarkdownInline) -> String {
        switch inline {
        case .text(let text): return Self.escape(text)
        case .code(let text): return "<code>\(Self.escape(text))</code>"
        case .emphasis(let content): return "<em>\(inlines(content))</em>"
        case .strong(let content): return "<strong>\(inlines(content))</strong>"
        case .strikethrough(let content): return "<del>\(inlines(content))</del>"
        case .softBreak: return "\n"
        case .lineBreak: return "<br>\n"
        case .html(let raw): return Self.sanitised(raw)
        case .math(let formula): return "<span class=\"math\">\(mathMarkup(formula, display: false))</span>"
        case .highlight(let content): return "<mark>\(inlines(content))</mark>"
        case .footnote(let name):
            if !referencedFootnotes.contains(name) { referencedFootnotes.append(name) }
            let number = (referencedFootnotes.firstIndex(of: name) ?? 0) + 1
            let id = Self.anchor(name)
            return "<sup class=\"footnote-ref\"><a id=\"fnref-\(id)\" href=\"#fn-\(id)\">\(number)</a></sup>"
        case .link(let destination, let title, let content):
            let safe = Self.isSafeLink(destination) ? destination : "#"
            let titleAttribute = title.map { " title=\"\(Self.escape($0))\"" } ?? ""
            return "<a href=\"\(Self.escape(safe))\"\(titleAttribute)>\(inlines(content))</a>"
        case .image(let source, let title, let alt):
            return image(source: source, title: title, alt: alt)
        }
    }

    private mutating func image(source: String, title: String?, alt: String) -> String {
        let titleAttribute = title.map { " title=\"\(Self.escape($0))\"" } ?? ""
        let lowered = source.lowercased()

        if lowered.hasPrefix("data:image/") {
            return "<img src=\"\(Self.escape(source))\" alt=\"\(Self.escape(alt))\"\(titleAttribute)>"
        }
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") || lowered.hasPrefix("//") {
            if keepsRemoteImagesAsWritten {
                return "<img src=\"\(Self.escape(source))\" alt=\"\(Self.escape(alt))\"\(titleAttribute)>"
            }
            if let local = remoteImages[source] {
                return "<img src=\"\(Self.escape(local.absoluteString))\" alt=\"\(Self.escape(alt))\"\(titleAttribute)>"
            }
            let reason = remoteFailures[source] ?? "Loading remote images is turned off."
            issues.append(Issue(message: "Remote image not loaded (\(reason)): \(source)"))
            return "<span class=\"missing\">Image not loaded: \(Self.escape(alt.isEmpty ? source : alt))</span>"
        }

        let path = source.removingPercentEncoding ?? source
        guard let baseDirectory else {
            return "<img src=\"\(Self.escape(source))\" alt=\"\(Self.escape(alt))\"\(titleAttribute)>"
        }
        let file = (path.hasPrefix("/") ? URL(filePath: path) : baseDirectory.appending(path: path)).standardizedFileURL
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            issues.append(Issue(message: "Image not found: \(source)"))
            return "<span class=\"missing\">Image not found: \(Self.escape(source))</span>"
        }
        let reference = imageMode == .absoluteFiles ? file.absoluteString : source
        return "<img src=\"\(Self.escape(reference))\" alt=\"\(Self.escape(alt))\"\(titleAttribute)>"
    }

    // MARK: Maths

    private mutating func mathMarkup(_ formula: String, display: Bool) -> String {
        switch mathMode {
        case .source:
            return Self.escape(formula)
        case .mathML:
            let converted = LatexMath.mathML(formula, display: display)
            for command in converted.unknownCommands {
                issues.append(Issue(message: "Unsupported maths command \(command)"))
            }
            return converted.markup
        }
    }

    // MARK: Helpers

    private mutating func identifier(for text: String) -> String {
        var slug = ""
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
            } else if (character == " " || character == "-" || character == "_"), slug.last != "-" {
                slug.append("-")
            }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "section" }
        let seen = usedIdentifiers[slug, default: 0]
        usedIdentifiers[slug] = seen + 1
        return seen == 0 ? slug : "\(slug)-\(seen)"
    }

    static func escape(_ text: String) -> String {
        var output = ""
        output.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\"": output += "&quot;"
            default: output.append(character)
            }
        }
        return output
    }

    private static func isSafeLink(_ destination: String) -> Bool {
        let lowered = destination.lowercased().trimmingCharacters(in: .whitespaces)
        return !(lowered.hasPrefix("javascript:") || lowered.hasPrefix("vbscript:") || lowered.hasPrefix("data:"))
    }

    /// Raw HTML from the document, without tags that run code or load other pages.
    static func sanitised(_ html: String) -> String {
        var cleaned = html.replacing(/<(script|style|iframe|object|embed)\b[\s\S]*?<\/\1\s*>/.ignoresCase(), with: "")
        cleaned = cleaned.replacing(/<\/?(script|style|iframe|object|embed|link|meta|base|form)\b[^>]*>/.ignoresCase(), with: "")
        cleaned = cleaned.replacing(/\son[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/.ignoresCase(), with: "")
        // A printed page cannot be clicked open, so disclosure blocks are shown expanded.
        cleaned = cleaned.replacing(/<details(?![^>]*\sopen)/.ignoresCase(), with: "<details open")
        return cleaned
    }
}
