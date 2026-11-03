//
//  WindowAlert.swift
//  PolarBear
//

import Foundation

/// An error message shown in an alert on the window.
struct WindowAlert: Identifiable {
    let id = UUID()
    var title: LocalizedStringResource
    var message: String
}
