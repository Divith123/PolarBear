//
//  ChatMessage.swift
//  PolarBear
//

import Foundation

nonisolated struct ChatMessage: Codable, Identifiable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
        /// What the agent did ("Editing main.tex"): shown small, between the messages.
        case activity
        case error
    }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
}
