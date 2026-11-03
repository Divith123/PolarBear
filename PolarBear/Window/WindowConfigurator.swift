//
//  WindowConfigurator.swift
//  PolarBear
//

import SwiftUI

/// Gives the hosting window its look: no title bar, a solid dark background, and the
/// red / yellow / green buttons centred on the first row of the UI (see `WindowChromeController`).
struct WindowConfigurator: NSViewRepresentable {
    let window: WindowState

    func makeNSView(context: Context) -> ChromeHostView {
        let view = ChromeHostView()
        view.controller = WindowChromeController(windowState: window)
        return view
    }

    func updateNSView(_ view: ChromeHostView, context: Context) {}
}
