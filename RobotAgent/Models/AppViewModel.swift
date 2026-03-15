// Nebius SF Robotics Hackathon 2026
// AppViewModel.swift

import Foundation

@Observable
class AppViewModel {
    var sessions: [ChatSession]
    var selectedSessionID: UUID {
        didSet { save() }
    }

    init() {
        if let store = PersistedStore.load(), !store.sessions.isEmpty {
            sessions = store.sessions.map { $0.toChatSession() }
            let validID = store.sessions.contains(where: { $0.id == store.selectedSessionID })
            selectedSessionID = validID ? store.selectedSessionID : store.sessions[0].id
        } else {
            let first = ChatSession(name: "Chat 1")
            sessions = [first]
            selectedSessionID = first.id
        }
        wireSaveCallbacks()
    }

    var selectedSession: ChatSession {
        sessions.first(where: { $0.id == selectedSessionID }) ?? sessions[0]
    }

    func addSession() {
        let session = ChatSession(name: "Chat \(sessions.count + 1)")
        wire(session)
        sessions.append(session)
        selectedSessionID = session.id
        save()
    }

    func closeSession(id: UUID) {
        guard sessions.count > 1 else { return }
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index)
        let newIndex = min(index, sessions.count - 1)
        selectedSessionID = sessions[newIndex].id
        save()
    }

    // MARK: - Persistence

    private func wireSaveCallbacks() {
        for session in sessions { wire(session) }
    }

    private func wire(_ session: ChatSession) {
        session.onSaveNeeded = { [weak self] in self?.save() }
        session.chatViewModel.onSaveNeeded = { [weak self] in self?.save() }
    }

    func save() {
        let store = PersistedStore(
            sessions: sessions.map { PersistedSession(chatSession: $0) },
            selectedSessionID: selectedSessionID
        )
        store.save()
    }
}
