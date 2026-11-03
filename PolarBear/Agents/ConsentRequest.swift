//
//  ConsentRequest.swift
//  PolarBear
//

import Foundation

/// An agent run waiting for the user's first-time permission in this project.
struct ConsentRequest: Identifiable {
    let kind: AgentKind
    let prompt: String
    /// What the conversation shows for the request, when it is shorter than the prompt.
    var display: String?
    let executable: URL
    let options: AgentOptions

    var id: String { kind.rawValue }
}
