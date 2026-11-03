//
//  MarkdownPage.swift
//  PolarBear
//

import Foundation

/// The complete HTML page around a rendered document: the style that gives the PDF its look,
/// or a lighter style for HTML that is pasted into other apps.
nonisolated enum MarkdownPage {
    enum Style {
        /// For the PDF preview: a clean document page.
        case document
        /// For rich text and HTML copied to the clipboard.
        case clipboard
    }

    static func html(body: String, title: String, style: Style) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>\(MarkdownHTMLWriter.escape(title))</title>
        <style>
        \(css(for: style))
        </style>
        </head>
        <body>
        \(body)</body>
        </html>
        """
    }

    private static func css(for style: Style) -> String {
        switch style {
        case .document: documentCSS
        case .clipboard: clipboardCSS
        }
    }

    private static let documentCSS = """
    :root { color-scheme: light; }
    html { -webkit-print-color-adjust: exact; }
    body { font: 15px/1.6 -apple-system, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif;
           color: #1d1d1f; margin: 0; overflow-wrap: break-word; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.5em 0 .55em; font-weight: 650;
                             break-after: avoid; page-break-after: avoid; break-inside: avoid; }
    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
    h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid #d8d8dc; }
    h2 { font-size: 1.5em; padding-bottom: .25em; border-bottom: 1px solid #e6e6ea; }
    h3 { font-size: 1.25em; } h4 { font-size: 1.05em; } h5, h6 { font-size: 1em; }
    p, ul, ol, pre, blockquote, table { margin: 0 0 1em; }
    p, li { orphans: 2; widows: 2; }
    a { color: #0a58ca; text-decoration: none; }
    ul, ol { padding-inline-start: 1.7em; }
    p, li, h1, h2, h3, h4, h5, h6, td, th, dt, dd, summary { unicode-bidi: plaintext; }
    li > p { margin: .35em 0; }
    li.task { list-style: none; margin-left: -1.3em; }
    li.task input { margin-right: .4em; }
    code { font: .88em ui-monospace, "SF Mono", Menlo, monospace; background: #f1f1f4; padding: .15em .35em; border-radius: 4px; }
    pre { background: #f6f6f8; border: 1px solid #e4e4e8; border-radius: 8px; padding: 12px 14px;
          white-space: pre-wrap; orphans: 3; widows: 3; }
    tr { break-inside: avoid; }
    .keep { break-inside: avoid; }
    pre code { background: none; padding: 0; font-size: .85em; }
    .tok-kw { color: #cf222e; } .tok-str { color: #0a3069; } .tok-com { color: #6e7781; font-style: italic; }
    .tok-num { color: #0550ae; } .tok-fn { color: #8250df; } .tok-type { color: #953800; }
    .tok-var { color: #953800; } .tok-attr { color: #116329; }
    .tok-add { color: #116329; background: #dafbe1; display: inline-block; width: 100%; }
    .tok-del { color: #82071e; background: #ffebe9; display: inline-block; width: 100%; }
    blockquote { padding: .1em 1em; border-left: 4px solid #cfcfd6; color: #55555c; break-inside: avoid; }
    blockquote > :last-child { margin-bottom: 0; }
    table { border-collapse: collapse; break-inside: avoid; max-width: 100%; }
    th, td { border: 1px solid #d0d0d6; padding: 6px 12px; vertical-align: top; }
    th { background: #f4f4f6; font-weight: 600; }
    img { max-width: 100%; break-inside: avoid; }
    hr { border: 0; border-top: 1px solid #d8d8dc; margin: 1.6em 0; }
    del { color: #76767e; }
    details { margin: 0 0 1em; } summary { font-weight: 600; margin-bottom: .4em; }
    dt { font-weight: 650; margin-top: .6em; } dd { margin: .15em 0 .15em 1.6em; }
    math { font-family: "STIX Two Math", "Latin Modern Math", "Cambria Math", math; font-size: 1.12em; }
    mtd { padding: 0.2em 0.4em; }
    mtable.aligned > mtr > mtd { padding-left: 0; padding-right: 0; }
    mtable.aligned > mtr > mtd:first-child { padding-right: 0.15em; }
    mtable.aligned > mtr > mtd + mtd { padding-left: 0.15em; }
    div.math { text-align: center; margin: 1em 0; overflow-x: auto; break-inside: avoid; }
    figure.diagram { margin: 1.2em 0; text-align: center; break-inside: avoid; }
    figure.diagram svg { max-width: 100%; height: auto; }
    .diagram-title { text-align: center; font-weight: 650; margin-bottom: .4em; }
    mark { background: #fff1a8; color: inherit; padding: 0 .15em; border-radius: 2px; }
    .alert { border-left: 4px solid #8a8a93; background: #f6f6f8; border-radius: 0 6px 6px 0; padding: .6em 1em; margin: 0 0 1em; break-inside: avoid; }
    .alert > :last-child { margin-bottom: 0; }
    .alert-title { font-weight: 650; margin: 0 0 .3em; }
    .alert-note { border-color: #0969da; } .alert-note .alert-title { color: #0969da; }
    .alert-tip { border-color: #1a7f37; } .alert-tip .alert-title { color: #1a7f37; }
    .alert-important { border-color: #8250df; } .alert-important .alert-title { color: #8250df; }
    .alert-warning { border-color: #9a6700; } .alert-warning .alert-title { color: #9a6700; }
    .alert-caution { border-color: #cf222e; } .alert-caution .alert-title { color: #cf222e; }
    .footnotes-rule { margin-top: 2em; }
    .footnotes { font-size: .9em; color: #3a3a3f; } .footnotes li > p { margin: .2em 0; }
    sup.footnote-ref a, .footnote-back { text-decoration: none; }
    .missing { border: 1px dashed #b0b0b8; color: #76767e; padding: 2px 8px; border-radius: 4px; font-size: .9em; }
    """

    private static let clipboardCSS = """
    body { font: 14px/1.5 Helvetica, Arial, sans-serif; color: #000000; }
    h1 { font-size: 26px; } h2 { font-size: 21px; } h3 { font-size: 17px; } h4, h5, h6 { font-size: 14px; }
    code, pre { font-family: Menlo, monospace; font-size: 12px; }
    pre { background: #f4f4f6; padding: 8px; }
    .tok-kw { color: #cf222e; } .tok-str { color: #0a3069; } .tok-com { color: #6e7781; }
    .tok-num { color: #0550ae; } .tok-fn { color: #8250df; } .tok-type { color: #953800; }
    .tok-var { color: #953800; } .tok-attr { color: #116329; }
    blockquote { color: #555555; margin-left: 16px; }
    table { border-collapse: collapse; } th, td { border: 1px solid #bbbbbb; padding: 4px 8px; }
    a { color: #0a58ca; }
    """
}
