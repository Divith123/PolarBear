//
//  ChromeHostView.swift
//  PolarBear
//

import SwiftUI

/// An invisible view whose only job is to learn which window it ended up in.
final class ChromeHostView: NSView {
    var controller: WindowChromeController?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            controller?.attach(to: window)
        }
    }
}
