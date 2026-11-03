//
//  SVGMarkers.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// The arrowheads and line ends shared by the diagrams.
nonisolated enum SVGMarkers {
    /// `<defs>` with every marker, named `<prefix>-arrow` and so on.
    static func definitions(prefix: String, color: String = DiagramTheme.line) -> String {
        """
        <defs>
        <marker id="\(prefix)-arrow" viewBox="0 0 10 10" refX="9.5" refY="5" markerWidth="9" markerHeight="9" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="\(color)"/></marker>
        <marker id="\(prefix)-open" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="10" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M1,1 L9,5 L1,9" fill="none" stroke="\(color)" stroke-width="1.4"/></marker>
        <marker id="\(prefix)-circle" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><circle cx="5" cy="5" r="4" fill="#ffffff" stroke="\(color)" stroke-width="1.4"/></marker>
        <marker id="\(prefix)-cross" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="10" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M1,1 L9,9 M9,1 L1,9" stroke="\(color)" stroke-width="1.6"/></marker>
        <marker id="\(prefix)-triangle" viewBox="0 0 14 14" refX="13" refY="7" markerWidth="14" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M1,1 L13,7 L1,13 z" fill="#ffffff" stroke="\(color)" stroke-width="1.4"/></marker>
        <marker id="\(prefix)-diamond" viewBox="0 0 20 12" refX="19" refY="6" markerWidth="20" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M1,6 L10,1 L19,6 L10,11 z" fill="#ffffff" stroke="\(color)" stroke-width="1.4"/></marker>
        <marker id="\(prefix)-diamond-filled" viewBox="0 0 20 12" refX="19" refY="6" markerWidth="20" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M1,6 L10,1 L19,6 L10,11 z" fill="\(color)" stroke="\(color)" stroke-width="1.4"/></marker>
        </defs>
        """
    }
}
