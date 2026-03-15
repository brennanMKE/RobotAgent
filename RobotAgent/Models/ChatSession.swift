// Nebius SF Robotics Hackathon 2026
// ChatSession.swift

import Foundation

@Observable
class ChatSession: Identifiable {
    let id: UUID
    var name: String {
        didSet { onSaveNeeded?() }
    }
    var chatViewModel: ChatViewModel
    var onSaveNeeded: (() -> Void)?

    init(id: UUID = UUID(), name: String, chatViewModel: ChatViewModel = ChatViewModel()) {
        self.id = id
        self.name = name
        self.chatViewModel = chatViewModel
    }
}
