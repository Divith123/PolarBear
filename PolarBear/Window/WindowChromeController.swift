//
//  WindowChromeController.swift
//  PolarBear
//

import SwiftUI

/// Removes the title bar strip while keeping the window buttons usable: they are centred on
/// the first row of the UI, and the controller reports full-screen changes (in full screen
/// the buttons disappear and the row needs no inset).
final class WindowChromeController {
    private static let leftInset: CGFloat = 20

    private let windowState: WindowState
    private weak var window: NSWindow?
    private var observers: [Task<Void, Never>] = []
    private var nativeSpacing: CGFloat?

    init(windowState: WindowState) {
        self.windowState = windowState
    }

    isolated deinit {
        for observer in observers {
            observer.cancel()
        }
    }

    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        windowState.hostWindow = window

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = true
        window.backgroundColor = AppTheme.NS.appBackground
        windowState.isFullScreen = window.styleMask.contains(.fullScreen)

        observers = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
        ].map { name in
            Task { [weak self] in
                for await notification in NotificationCenter.default.notifications(named: name) {
                    guard let self, notification.object as? NSWindow === self.window else { continue }
                    windowChanged(name)
                }
            }
        }
        positionTrafficLights()
    }

    private func windowChanged(_ name: Notification.Name) {
        if name == NSWindow.didEnterFullScreenNotification { windowState.isFullScreen = true }
        if name == NSWindow.didExitFullScreenNotification { windowState.isFullScreen = false }
        positionTrafficLights()
    }

    /// Centres the three buttons on the first row of the UI (`AppTheme.Metrics.barHeight` tall).
    private func positionTrafficLights() {
        guard let window,
              !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let miniaturize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview,
              let container = titlebar.superview,
              let frameView = container.superview
        else { return }

        let step = nativeSpacing ?? (miniaturize.frame.minX - close.frame.minX)
        nativeSpacing = step

        let height = AppTheme.Metrics.barHeight
        container.frame = NSRect(x: 0, y: frameView.bounds.height - height, width: frameView.bounds.width, height: height)
        titlebar.frame = container.bounds

        let y = (height - close.frame.height) / 2
        for (index, button) in [close, miniaturize, zoom].enumerated() {
            button.setFrameOrigin(NSPoint(x: Self.leftInset + CGFloat(index) * step, y: y))
        }
    }
}
