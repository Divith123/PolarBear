//
//  ChatSession.swift
//  PolarBear
//

import Foundation

/// One conversation with an agent, saved in the project's `.PolarBear/chats` folder.
nonisolated struct ChatSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var agent: AgentKind
    var created = Date()
    var messages: [ChatMessage] = []
    /// The agent's own session identifier, so a later message can continue the conversation.
    var resumeToken: String?
}
