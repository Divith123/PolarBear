//
//  AgentModel.swift
//  PolarBear
//

import Foundation
import Observation

/// A project's conversations with agents and the proposal waiting for review. Runs and reviews
/// are in `AgentModel+Run` and `AgentModel+Review`.
@Observable
final class AgentModel {
    enum Phase {
        case idle
        case running
    }

    @ObservationIgnored weak var project: Project?
    @ObservationIgnored var runTask: Task<Void, Never>?
    /// The assistant message the current run is appending lines to.
    @ObservationIgnored var streamingMessageID: ChatMessage.ID?

    private(set) var sessions: [ChatSession] = []
    var currentID: ChatSession.ID?
    var phase = Phase.idle
    /// What the agent is doing right now, from its latest activity event.
    var activity: String?
    var review: AgentReview?
    /// A run waiting for the user's first-time permission in this project.
    var consent: ConsentRequest?
    /// Whether the conversation panel above the composer is open. It only opens when the user
    /// asks for it — a run never opens it on its own.
    var isPanelVisible = false {
        didSet { if isPanelVisible { hasNews = false } }
    }
    /// A run finished while the panel was closed: the composer shows a slim "reply ready" strip.
    var hasNews = false

    var isRunning: Bool {
        phase == .running
    }

    var currentSession: ChatSession? {
        sessions.first { $0.id == currentID }
    }

    func load(root: URL) async {
        sessions = await ChatStore.load(root: root)
    }

    // MARK: Sessions

    func newChat() {
        guard !isRunning else { return }
        currentID = nil
        review = nil
        isPanelVisible = false
    }

    func select(_ id: ChatSession.ID) {
        guard !isRunning else { return }
        currentID = id
        isPanelVisible = true
    }

    func delete(_ session: ChatSession) {
        guard !isRunning, let root = project?.root else { return }
        sessions.removeAll { $0.id == session.id }
        if currentID == session.id { currentID = nil }
        Task { await ChatStore.delete(session, root: root) }
    }

    // MARK: Messages (used by the run)

    /// The index of the current session, creating one for `agent` if there is none.
    @discardableResult
    func ensureSession(agent: AgentKind, title: String) -> Int {
        if let index = sessions.firstIndex(where: { $0.id == currentID }) { return index }
        let session = ChatSession(title: title, agent: agent)
        sessions.insert(session, at: 0)
        currentID = session.id
        return 0
    }

    func append(_ role: ChatMessage.Role, _ text: String) {
        guard let index = sessions.firstIndex(where: { $0.id == currentID }) else { return }
        sessions[index].messages.append(ChatMessage(role: role, text: text))
    }

    /// Adds a line to the assistant's message, starting a new one after other kinds of message.
    func appendAssistantLine(_ line: String) {
        guard let index = sessions.firstIndex(where: { $0.id == currentID }) else { return }
        if let id = streamingMessageID,
           let messageIndex = sessions[index].messages.lastIndex(where: { $0.id == id }),
           messageIndex == sessions[index].messages.count - 1 {
            sessions[index].messages[messageIndex].text += "\n" + line
        } else {
            let message = ChatMessage(role: .assistant, text: line)
            streamingMessageID = message.id
            sessions[index].messages.append(message)
        }
    }

    func setResumeToken(_ token: String) {
        guard let index = sessions.firstIndex(where: { $0.id == currentID }) else { return }
        sessions[index].resumeToken = token
    }

    func persistCurrent() {
        guard let session = currentSession, let root = project?.root else { return }
        Task { await ChatStore.save(session, root: root) }
    }
}
