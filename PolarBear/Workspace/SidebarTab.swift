//
//  SidebarTab.swift
//  PolarBear
//

import Foundation

enum SidebarTab: CaseIterable {
    case files
    case chats

    var title: LocalizedStringResource {
        switch self {
        case .files: "Files"
        case .chats: "Chats"
        }
    }
}
