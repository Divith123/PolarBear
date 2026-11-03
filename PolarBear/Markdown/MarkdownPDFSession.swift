//
//  MarkdownPDFSession.swift
//  PolarBear
//

import SwiftUI
import WebKit

/// Waits for a page to load and for a print operation to finish. WebKit and AppKit report both
/// through delegate callbacks; this turns them into `async` calls.
final class MarkdownPDFSession: NSObject, WKNavigationDelegate {
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var printContinuation: CheckedContinuation<Bool, Never>?

    func load(_ page: URL, readAccess: URL, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            webView.loadFileURL(page, allowingReadAccessTo: readAccess)
        }
    }

    func run(_ operation: NSPrintOperation, in window: NSWindow) async -> Bool {
        await withCheckedContinuation { continuation in
            printContinuation = continuation
            operation.runModal(
                for: window,
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }
    }

    /// Gives up on a load that never finishes.
    func abandonLoad(with error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    // MARK: Callbacks

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        abandonLoad(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        abandonLoad(with: error)
    }

    /// Only the page itself may load: no scripts, no links followed.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        preferences.allowsContentJavaScript = false
        let isPage = navigationAction.request.url?.isFileURL == true && navigationAction.navigationType == .other
        return (isPage ? .allow : .cancel, preferences)
    }

    @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        printContinuation?.resume(returning: success)
        printContinuation = nil
    }
}
