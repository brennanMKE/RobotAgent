// Nebius SF Robotics Hackathon 2026
// ChatViewModel.swift

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ChatViewModel")

enum ResponseState {
    case loading
    case cancelled
    case success(ChatCompletionResponse)
    case failure(Error)
}

nonisolated struct PromptAndResponse: Identifiable {
    let id: UUID
    let promptText: String
    var state: ResponseState = .loading

    init(id: UUID = UUID(), promptText: String) {
        self.id = id
        self.promptText = promptText
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
}

@Observable
class ChatViewModel {
    var prompts: [PromptAndResponse] = []
    var totalTokensUsed: Int = 0
    var suggestedName: String?

    var onSaveNeeded: (() -> Void)?
    private var currentTask: Task<Void, Never>?

    var isGenerating: Bool {
        currentTask != nil
    }

    var markdownExport: String? {
        let entries = prompts.compactMap { item -> String? in
            guard case .success(let response) = item.state, let text = response.text else { return nil }
            return "**You**\n\n\(item.promptText)\n\n**Assistant**\n\n\(text)"
        }
        guard !entries.isEmpty else { return nil }
        return entries.joined(separator: "\n\n---\n\n")
    }

    func createResponse(promptText: String, using client: RobotAgentClient) {
        currentTask = Task {
            await performCreateResponse(promptText: promptText, using: client)
            currentTask = nil
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        // Mark the last loading prompt as cancelled
        if let index = prompts.indices.last, case .loading = prompts[index].state {
            prompts[index].state = .cancelled
        }
        onSaveNeeded?()
    }

    func clearHistory() {
        prompts = []
        totalTokensUsed = 0
        suggestedName = nil
        onSaveNeeded?()
    }

    func clearSuggestedName() {
        suggestedName = nil
    }

    private func performCreateResponse(promptText: String, using client: RobotAgentClient) async {
        logger.log("Creating response in \(#function) at \(#line)")

        // Build history before adding current prompt
        var history: [ChatMessage] = []
        for prompt in prompts {
            history.append(ChatMessage(role: "user", content: prompt.promptText))
            if case .success(let response) = prompt.state, let text = response.text {
                history.append(ChatMessage(role: "assistant", content: text))
            }
        }
        history.append(ChatMessage(role: "user", content: promptText))

        prompts.append(PromptAndResponse(promptText: promptText))
        let index = prompts.count - 1

        do {
            if client.isTesting {
                try await Task.sleep(for: .seconds(0.75))
            }
            try Task.checkCancellation()
            let response = try await client.createResponse(messages: history)
            try Task.checkCancellation()
            prompts[index].state = .success(response)
            if let tokens = response.usage?.totalTokens {
                totalTokensUsed += tokens
            }
            logger.log("Set completed response \(#function) at \(#line)")

            // Auto-name after first successful response
            logger.log("Auto-name check: prompts.count=\(self.prompts.count), suggestedName=\(self.suggestedName ?? "nil", privacy: .public)")
            if prompts.count == 1, suggestedName == nil {
                let firstUserMsg = history.first(where: { $0.role == "user" })
                let firstAssistantMsg = response.text.map { ChatMessage(role: "assistant", content: $0) }
                var namingMessages: [ChatMessage] = []
                if let u = firstUserMsg { namingMessages.append(u) }
                if let a = firstAssistantMsg { namingMessages.append(a) }
                logger.log("Auto-name: built \(namingMessages.count) naming messages, triggering generateTabName")
                if !namingMessages.isEmpty {
                    do {
                        let name = try await client.generateTabName(messages: namingMessages)
                        logger.log("Auto-name: received name='\(name, privacy: .public)', setting suggestedName")
                        if !name.isEmpty {
                            suggestedName = name
                            logger.log("Auto-name: suggestedName set to '\(self.suggestedName ?? "nil", privacy: .public)'")
                        } else {
                            logger.error("Auto-name: name was empty, suggestedName not set")
                        }
                    } catch {
                        logger.error("Auto-name: generateTabName failed: \(error)")
                    }
                }
            } else {
                logger.log("Auto-name: skipping (prompts.count=\(self.prompts.count), suggestedName already set=\(self.suggestedName != nil))")
            }
        } catch is CancellationError {
            if case .loading = prompts[index].state {
                prompts[index].state = .cancelled
            }
            logger.log("Response cancelled")
        } catch {
            logger.error("Error: \(error)")
            prompts[index].state = .failure(error)
            logger.log("Set failed response \(#function) at \(#line)")
        }

        logger.log("There are now \(self.prompts.count) prompts")
        onSaveNeeded?()
    }
}
