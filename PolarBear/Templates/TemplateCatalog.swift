//
//  TemplateCatalog.swift
//  PolarBear
//

import Foundation

/// The built-in project templates. Their sources live in the `TemplateCatalog+…` files.
enum TemplateCatalog {
    static let blank = ProjectTemplate(
        id: "blank",
        name: "Blank",
        summary: "An empty article, ready to write.",
        symbol: "doc",
        files: [TemplateFile(path: "main.tex", text: blankSource)]
    )

    static let article = ProjectTemplate(
        id: "article",
        name: "Article",
        summary: "Title, abstract, sections, an equation and a table.",
        symbol: "doc.text",
        files: [TemplateFile(path: "main.tex", text: articleSource)]
    )

    static let thesis = ProjectTemplate(
        id: "thesis",
        name: "Report with chapters",
        summary: "Several files plus a BibTeX bibliography.",
        symbol: "books.vertical",
        files: [
            TemplateFile(path: "main.tex", text: thesisMain),
            TemplateFile(path: "chapters/introduction.tex", text: thesisIntroduction),
            TemplateFile(path: "chapters/methods.tex", text: thesisMethods),
            TemplateFile(path: "references.bib", text: thesisReferences),
        ]
    )

    static let beamer = ProjectTemplate(
        id: "beamer",
        name: "Presentation",
        summary: "Slides with Beamer.",
        symbol: "rectangle.on.rectangle",
        files: [TemplateFile(path: "main.tex", text: beamerSource)]
    )

    static let example = ProjectTemplate(
        id: "example",
        name: "Example project",
        summary: "A tour: maths, a table, a drawing and a list.",
        symbol: "sparkles",
        files: [TemplateFile(path: "main.tex", text: exampleSource)]
    )

    static let all = [article, thesis, beamer, example, blank]
}
