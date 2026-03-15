// Nebius SF Robotics Hackathon 2026
// PersistenceStore.swift

import Foundation
import os.log

nonisolated private let persistenceLogger = Logger(subsystem: Logging.subsystem, category: "Persistence")

// MARK: - DTOs

struct PersistedStore: Codable {
    var sessions: [PersistedSession]
    var selectedSessionID: UUID

    // MARK: File location

    static var storeURL: URL {
        get throws {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent(
                Bundle.main.bundleIdentifier ?? "co.sstools.RobotAgent",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("sessions.json")
        }
    }

    // MARK: Load / Save

    static func load() -> PersistedStore? {
        do {
            let url = try storeURL
            let data = try Data(contentsOf: url)
            let store = try JSONDecoder().decode(PersistedStore.self, from: data)
            persistenceLogger.log("Loaded \(store.sessions.count) session(s) from \(url.path, privacy: .public)")
            return store
        } catch {
            persistenceLogger.log("No persisted store found, starting fresh: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save() {
        do {
            let url = try Self.storeURL
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
            persistenceLogger.log("Saved \(self.sessions.count) session(s)")
        } catch {
            persistenceLogger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct PersistedSession: Codable {
    var id: UUID
    var name: String
    var prompts: [PersistedPrompt]
    var totalTokensUsed: Int

    init(chatSession: ChatSession) {
        id = chatSession.id
        name = chatSession.name
        totalTokensUsed = chatSession.chatViewModel.totalTokensUsed
        prompts = chatSession.chatViewModel.prompts.compactMap { PersistedPrompt(promptAndResponse: $0) }
    }

    func toChatSession() -> ChatSession {
        let vm = ChatViewModel()
        vm.prompts = prompts.compactMap { $0.toPromptAndResponse() }
        vm.totalTokensUsed = totalTokensUsed
        return ChatSession(id: id, name: name, chatViewModel: vm)
    }
}

struct PersistedPrompt: Codable {
    var id: UUID
    var promptText: String
    var response: ChatCompletionResponse?
    var cancelled: Bool

    init?(promptAndResponse: PromptAndResponse) {
        id = promptAndResponse.id
        promptText = promptAndResponse.promptText
        switch promptAndResponse.state {
        case .success(let r):
            response = r
            cancelled = false
        case .cancelled:
            response = nil
            cancelled = true
        case .loading, .failure:
            return nil
        }
    }

    func toPromptAndResponse() -> PromptAndResponse? {
        if let r = response {
            var p = PromptAndResponse(id: id, promptText: promptText)
            p.state = .success(r)
            return p
        } else if cancelled {
            var p = PromptAndResponse(id: id, promptText: promptText)
            p.state = .cancelled
            return p
        }
        return nil
    }
}
