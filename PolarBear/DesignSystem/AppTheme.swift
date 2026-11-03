//
//  AppTheme.swift
//  PolarBear
//
//  The single source of truth for the look of the app: colours, spacing, radii,
//  metrics, fonts and timings. The UI is solid dark — no glass, no transparency.
//

import SwiftUI

enum AppTheme {
    // MARK: Colours
    //
    // Every colour is a solid pair — one value for the dark appearance, one for the light — that
    // follows the window's appearance (see `AppearanceSetting`). Nothing is translucent.

    static let appBackground = Color(light: 0xF5F5F7, dark: 0x0D0D0D)
    /// The editor and PDF panels: pure black, or white.
    static let panelBackground = Color(light: 0xFFFFFF, dark: 0x000000)
    static let controlFill = Color(light: 0xE9E9ED, dark: 0x1C1C1C)
    static let selectionFill = Color(light: 0xE0E0E6, dark: 0x1A1A1A)
    static let hoverFill = Color(light: 0xECECF0, dark: 0x131313)
    static let tabFill = Color(light: 0xF0F0F3, dark: 0x141414)
    static let tabHoverFill = Color(light: 0xF4F4F7, dark: 0x101010)
    static let composerFill = Color(light: 0xF0F0F3, dark: 0x171717)
    static let floatingBarFill = Color(light: 0xF0F0F3, dark: 0x181818)
    static let badgeFill = Color(light: 0xE3E3E8, dark: 0x232323)

    /// The profile picture colours: the same in both themes, with `onAvatarColor` drawn on top.
    static let avatarColors: [Color] = [0xE5736B, 0xD9A441, 0x4FAE7B, 0x3FA7B5, 0x5B8DEF, 0x9B7BE0].map { Color(light: $0, dark: $0) }
    static let onAvatarColor = Color(light: 0xFFFFFF, dark: 0xFFFFFF)

    static let divider = Color(light: 0xDCDCE1, dark: 0x1F1F1F)
    static let hairlineFaint = Color(light: 0xE4E4E9, dark: 0x1D1D1D)
    static let hairline = Color(light: 0xD3D3D9, dark: 0x2A2A2A)
    static let hairlineStrong = Color(light: 0xB4B4BD, dark: 0x4A4A4A)
    static let tabBorder = Color(light: 0x9A9AA4, dark: 0x6A6A6A)

    static let textPrimary = Color(light: 0x1C1C1E, dark: 0xF2F2F2)
    static let textSecondary = Color(light: 0x5C5C66, dark: 0x9B9B9B)
    static let textTertiary = Color(light: 0x8A8A94, dark: 0x6C6C6C)
    static let iconPrimary = Color(light: 0x3A3A40, dark: 0xD6D6D6)
    static let iconSecondary = Color(light: 0x55555C, dark: 0xB4B4B4)
    static let iconTertiary = Color(light: 0x7C7C86, dark: 0x9A9A9A)

    /// Fill of the strong buttons (send, share, "Open Folder"): white in the dark theme, near-black in the light one.
    static let accentInk = Color(light: 0x1C1C1E, dark: 0xFFFFFF)
    /// What is drawn on top of `accentInk`.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x000000)

    static let danger = Color(light: 0xC62828, dark: 0xFF7A7A)
    static let dangerFill = Color(light: 0xFDE8E8, dark: 0x2A1213)
    static let dangerStroke = Color(light: 0xEBB0B0, dark: 0x6E2226)

    static let success = Color(light: 0x1E8E4E, dark: 0x5BD08A)
    static let warning = Color(light: 0x946400, dark: 0xE5C07B)
    static let warningFill = Color(light: 0xFFF3D1, dark: 0x2A2412)
    static let warningStroke = Color(light: 0xE4C57A, dark: 0x6B5B22)
    static let link = Color(light: 0x1F5FBF, dark: 0x9DBDF5)

    /// Diff colours: solid tints, never translucent.
    static let addedFill = Color(light: 0xE2F4E9, dark: 0x0E2417)
    static let addedText = Color(light: 0x1B7A43, dark: 0x7EE2A3)
    static let removedFill = Color(light: 0xFCE9E9, dark: 0x2A1213)
    static let removedText = Color(light: 0xB3261E, dark: 0xFF8D8D)

    /// The same colours as `NSColor`, for AppKit (the window, the PDF view).
    enum NS {
        static let appBackground = NSColor(light: 0xF5F5F7, dark: 0x0D0D0D)
        /// Around the PDF pages: black in the dark theme, a soft grey in the light one so the white pages stand out.
        static let pdfBackground = NSColor(light: 0xE6E6EA, dark: 0x000000)
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs = 2.0
        static let xs = 4.0
        static let s = 6.0
        static let m = 8.0
        static let l = 12.0
        static let xl = 14.0
        static let xxl = 20.0
    }

    // MARK: Corner radii (always drawn with the smooth, continuous curve)

    enum Radius {
        static let badge = 5.0
        static let row = 9.0
        static let control = 10.0
        static let pill = 12.0
        static let artwork = 16.0
    }

    // MARK: Metrics

    enum Metrics {
        /// Shared height of the first row of every column, so they line up with the window buttons.
        static let barHeight = 48.0
        /// Width from the window's left edge reserved for the red / yellow / green buttons.
        static let trafficLightsReserve = 88.0
        static let iconButton = 26.0
        static let closeButton = 16.0
        static let controlHeight = 33.0
        static let avatar = 30.0
        static let accountAvatar = 26.0
        static let tabHeight = 32.0
        static let chipHeight = 31.0
        static let pillHeight = 34.0
        static let composerHeight = 53.0
        static let floatingBarHeight = 43.0
        static let brandLogo = 30.0
        static let emptyStateArtworkWidth = 380.0

        static let splashWidth = 560.0
        static let splashBarHeight = 52.0
        static let splashProgressHeight = 2.0
        static let onboardingCardWidth = 440.0
        static let profileAvatar = 96.0
        static let avatarChoice = 40.0
        static let avatarSwatch = 24.0

        static let sidebarTabHeight = 30.0
        static let rowHeight = 30.0
        static let filterFieldHeight = 30.0
        static let outlineHeaderHeight = 37.0
        static let outlineRowHeight = 22.0

        static let previewSheetWidth = 600.0
        static let previewSheetHeight = 700.0

        static let drawerWidth = 380.0
        static let drawerRowHeight = 34.0
        static let statusDot = 8.0
        static let welcomeContentWidth = 440.0
        static let templateTileWidth = 150.0
        static let sheetWidth = 560.0
        static let diffLineHeight = 20.0

        /// The file tree: a text column at 20 pt, with the chevrons of folders in the 20 pt before it.
        static let treeTextInset = 20.0
        static let treeIndent = 14.0
        static let treeGutter = 4.0

        static let sidebarMin = 220.0
        static let sidebarIdeal = 300.0
        static let sidebarMax = 320.0
        static let editorMin = 340.0
        static let editorIdeal = 640.0
        static let previewMin = 300.0
        static let previewIdeal = 560.0

        static let outlineMinHeight = 120.0
        static let outlineMaxHeight = 223.0
        static let collapsedOutlineHeight = 44.0

        static let minWindowWidth = 560.0
        static let minWindowHeight = 480.0
        static let defaultWindowWidth = 1512.0
        static let defaultWindowHeight = 940.0
    }

    // MARK: Typography (semantic text styles — they follow the system's text settings)

    enum Typography {
        static let row = Font.body
        static let rowDetail = Font.subheadline
        static let tab = Font.callout
        static let section = Font.headline
        static let badge = Font.caption2.bold()
        static let composer = Font.title3
        static let emptyTitle = Font.headline
        static let emptyDetail = Font.subheadline
        static let welcomeTitle = Font.largeTitle.bold()
        static let welcomeSubtitle = Font.title3
        static let caption = Font.caption
        static let code = Font.system(.callout, design: .monospaced)
        static let codeSmall = Font.system(.caption, design: .monospaced)
    }

    // MARK: Timings

    enum Timing {
        /// Pause after the last edit before the project is written to disk.
        static let autosaveDelay = Duration.milliseconds(600)
        static let scroll = Animation.snappy(duration: 0.25)
        static let disclosure = Animation.snappy(duration: 0.2)
        /// How long the launch splash stays up.
        static let splash = Duration.seconds(2)
    }
}
