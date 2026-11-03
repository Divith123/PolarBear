//
//  Log.swift
//  PolarBear
//

import os

/// One logger per feature, so Console.app can be filtered by category.
nonisolated enum Log {
    private static let subsystem = "com.hustleronduty.PolarBear"

    static let project = Logger(subsystem: subsystem, category: "Project")
    static let watcher = Logger(subsystem: subsystem, category: "Watcher")
    static let build = Logger(subsystem: subsystem, category: "Build")
    static let sync = Logger(subsystem: subsystem, category: "SyncTeX")
    static let history = Logger(subsystem: subsystem, category: "History")
    static let agents = Logger(subsystem: subsystem, category: "Agents")
    static let imports = Logger(subsystem: subsystem, category: "Import")
}
