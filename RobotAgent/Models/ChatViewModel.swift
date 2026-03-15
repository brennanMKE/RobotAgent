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

nonisolated struct ToolExecution: Identifiable {
    let id: UUID
    let toolName: String
    let arguments: String
    let result: String
    let timestamp: Date

    init(toolName: String, arguments: String, result: String) {
        self.id = UUID()
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.timestamp = Date()
    }
}

nonisolated struct PromptAndResponse: Identifiable {
    let id: UUID
    let promptText: String
    var state: ResponseState = .loading
    var toolExecutions: [ToolExecution] = []

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
    var robotToolHandler: RobotToolHandler?

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

            // Initial request
            var response = try await client.createResponse(messages: history)
            try Task.checkCancellation()

            // Handle tool calls if present (multi-turn loop) - supports both OpenAI and Kimi formats
            var toolIterations = 0
            let maxToolIterations = 5

            // Check for tool calls in both OpenAI format and Kimi format
            var toolCalls = response.toolCalls ?? parseKimiToolCalls(from: response.text ?? "")

            while !toolCalls.isEmpty && toolIterations < maxToolIterations {
                toolIterations += 1
                logger.log("Tool iteration \(toolIterations): executing \(toolCalls.count) tool call(s)")

                // Add assistant's response to history
                history.append(ChatMessage(role: "assistant", content: response.text ?? ""))

                // Execute tool calls and collect results
                var toolResults: [ChatMessage] = []
                for (idx, toolCall) in toolCalls.enumerated() {
                    guard let handler = robotToolHandler else {
                        logger.error("Tool \(idx): no handler available for \(toolCall.function.name, privacy: .public)")
                        continue
                    }

                    logger.log("Tool \(idx): executing '\(toolCall.function.name, privacy: .public)' with args: \(toolCall.function.arguments, privacy: .public)")
                    let resultJSON = handler.execute(toolCall: toolCall)
                    toolResults.append(ChatMessage(role: "tool", content: resultJSON, toolCallId: toolCall.id))

                    // Track tool execution for display
                    let execution = ToolExecution(
                        toolName: toolCall.function.name,
                        arguments: toolCall.function.arguments,
                        result: resultJSON
                    )
                    prompts[index].toolExecutions.append(execution)

                    logger.log("Tool \(idx): result=\(resultJSON, privacy: .public)")
                }

                // Add tool results to history
                history.append(contentsOf: toolResults)

                // Get next response from model
                try Task.checkCancellation()
                logger.log("Tool iteration \(toolIterations): sending results back to model for next response")
                response = try await client.createResponse(messages: history)
                try Task.checkCancellation()
                // Re-parse tool calls for next iteration (supports both OpenAI and Kimi formats)
                toolCalls = response.toolCalls ?? parseKimiToolCalls(from: response.text ?? "")
                logger.log("Tool iteration \(toolIterations): received response, hasMoreToolCalls=\(toolCalls.count > 0)")
            }

            if toolIterations >= maxToolIterations && response.hasToolCalls {
                logger.warning("Max tool iterations (\(maxToolIterations)) reached, stopping tool loop")
            }

            if toolIterations > 0 {
                logger.log("Tool calling loop completed after \(toolIterations) iteration(s)")
            }

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

    /// Parse Kimi's custom tool call format from response text
    /// Format: <|tool_calls_section_begin|> <|tool_call_begin|> functions.tool_name:id {json_args} <|tool_call_end|> <|tool_calls_section_end|>
    private func parseKimiToolCalls(from text: String) -> [ToolCall] {
        var toolCalls: [ToolCall] = []

        guard text.contains("<|tool_calls_section_begin|>") && text.contains("<|tool_calls_section_end|>") else {
            return toolCalls
        }

        // Extract the tool calls section
        guard let startRange = text.range(of: "<|tool_calls_section_begin|>"),
              let endRange = text.range(of: "<|tool_calls_section_end|>") else {
            return toolCalls
        }

        let toolSection = String(text[startRange.upperBound..<endRange.lowerBound])

        // Split by tool_call markers
        let toolCallPattern = "<|tool_call_begin|>(.*?)<|tool_call_end|>"
        guard let regex = try? NSRegularExpression(pattern: toolCallPattern, options: [.dotMatchesLineSeparators]) else {
            logger.error("Failed to create regex for Kimi tool call parsing")
            return toolCalls
        }

        let nsRange = NSRange(toolSection.startIndex..<toolSection.endIndex, in: toolSection)
        let matches = regex.matches(in: toolSection, range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: toolSection) else {
                continue
            }

            let toolContent = String(toolSection[range]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse format: functions.tool_name:id {json_args} or functions.tool_name:id {}
            // Find the function name/id part (before first { or space+{)
            let trimmed = toolContent.trimmingCharacters(in: .whitespacesAndNewlines)

            // Find where the function name/id ends (at first whitespace followed by {)
            guard let firstBraceIndex = trimmed.firstIndex(of: "{") else { continue }

            // Get everything before the brace as name:id, everything from brace onward as args
            let nameAndId = String(trimmed[..<firstBraceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let arguments = String(trimmed[firstBraceIndex...])

            // Extract tool name and ID from "functions.tool_name:id"
            let parts = nameAndId.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count >= 2 else { continue }

            let fullName = parts[1]
            let nameIdParts = fullName.split(separator: ":", maxSplits: 1).map(String.init)
            guard nameIdParts.count >= 1 else { continue }

            let toolName = nameIdParts[0]
            let toolId = nameIdParts.count > 1 ? nameIdParts[1] : String(toolCalls.count)

            let toolCall = ToolCall(
                id: toolId,
                type: "function",
                function: ToolCallFunction(name: toolName, arguments: arguments)
            )
            toolCalls.append(toolCall)
            logger.log("Parsed Kimi tool call: id=\(toolId) name=\(toolName) args=\(arguments)")
        }

        return toolCalls
    }
}
