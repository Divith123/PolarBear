//
//  OutlineItem.swift
//  PolarBear
//

/// A section heading of the active `.tex` file.
struct OutlineItem: Identifiable, Equatable {
    /// 1-based source line; unique within a document, so it doubles as the identity.
    let line: Int
    let title: String
    /// 0 for `\section`, 1 for `\subsection`, 2 for `\subsubsection`.
    let level: Int

    var id: Int { line }
}
