// Nebius SF Robotics Hackathon 2026
// ChatGPTClient.swift

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "Client")

nonisolated struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String?
    let reasoningContent: String?

    // Convenience init for outgoing messages (content always present)
    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.reasoningContent = nil
    }
}

nonisolated struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
}

nonisolated struct ChatCompletionResponse: Codable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable, Sendable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
    }

    struct Usage: Codable, Sendable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }

    var thinkingText: String? {
        guard let message = choices.first?.message else { return nil }
        if let content = message.content {
            return extractThinkBlocks(content).thinking
        }
        return message.reasoningContent
    }

    var text: String? {
        guard let message = choices.first?.message else { return nil }
        if let content = message.content {
            let cleaned = extractThinkBlocks(content).content
            return cleaned.isEmpty ? nil : cleaned
        }
        return message.reasoningContent
    }
}

nonisolated func extractThinkBlocks(_ s: String) -> (thinking: String?, content: String) {
    var out = s.replacingOccurrences(of: "<|im_end|>", with: "")
    var thinking: [String] = []
    if let regex = try? NSRegularExpression(pattern: "<think>([\\s\\S]*?)</think>\\s*", options: []) {
        let range = NSRange(out.startIndex..., in: out)
        for match in regex.matches(in: out, range: range) {
            if let r = Range(match.range(at: 1), in: out) {
                thinking.append(String(out[r]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        out = regex.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
    }
    return (
        thinking.isEmpty ? nil : thinking.joined(separator: "\n\n"),
        out.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

/// HTTP methods for API requests
nonisolated enum HTTPMethod: String, CaseIterable, Sendable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

nonisolated enum Path: String, Sendable {
    case chatCompletions = "/chat/completions"
    case models = "/models"

    func url(for baseURL: URL) -> URL {
        baseURL.appending(path: self.rawValue)
    }
}

nonisolated enum RobotAgentClientError: Error, Sendable {
    case invalidURL(reason: String)
    case invalidResponse(reason: String)
    case unsupportedRequest
    case missingData
}

nonisolated struct ModelsResponse: Codable, Sendable {
    let object: String
    let data: [Model]

    struct Model: Codable, Sendable {
        let id: String
    }
}

class RobotAgentClient {
    let session: URLSession
    let isTesting: Bool

    var apiKey: String {
        UserDefaults.standard.string(forKey: "openai_api_key") ??
        (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? "")
    }

    var baseURL: URL {
        let savedURL = UserDefaults.standard.string(forKey: "openai_base_url") ?? "https://api.openai.com/v1"
        return URL(string: savedURL) ?? URL(string: "https://api.openai.com/v1")!
    }

    var selectedModel: String {
        let saved = UserDefaults.standard.string(forKey: "selected_model") ?? ""
        return saved.isEmpty ? "gpt-4o" : saved
    }

    var systemPrompt: String {
        UserDefaults.standard.string(forKey: "system_prompt") ?? ""
    }

    init(session: URLSession? = nil, isTesting: Bool = false) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300  // 5 min for thinking models
            config.timeoutIntervalForResource = 600 // 10 min total
            self.session = URLSession(configuration: config)
        }
        self.isTesting = isTesting
    }

    private static var mockSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        return mockSession
    }

    static var mock: RobotAgentClient {
        RobotAgentClient(session: mockSession, isTesting: true)
    }

    static var `default`: RobotAgentClient {
        RobotAgentClient(session: URLSession.shared, isTesting: false)
    }

    func createResponse(messages: [ChatMessage]) async throws -> ChatCompletionResponse {
        logger.log("createResponse: model='\(self.selectedModel, privacy: .public)' url='\(self.baseURL.absoluteString, privacy: .public)' messages=\(messages.count) apiKey=\(!self.apiKey.isEmpty) systemPrompt=\(!self.systemPrompt.isEmpty)")

        let url = Path.chatCompletions.url(for: baseURL)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var allMessages = messages
        if !systemPrompt.isEmpty {
            allMessages.insert(ChatMessage(role: "system", content: systemPrompt), at: 0)
        }
        let input = ChatCompletionRequest(model: selectedModel, messages: allMessages)
        let encoder = JSONEncoder()
        let data = try encoder.encode(input)
        request.httpBody = data

        logger.log("createResponse: POST \(url.absoluteString, privacy: .public) body=\(data.count)bytes messages=\(allMessages.count)")
        guard let data = try await execute(request: request) else {
            logger.error("createResponse: execute returned nil data")
            throw RobotAgentClientError.missingData
        }
        logger.log("createResponse: received \(data.count) bytes")

        let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
        logger.log("createResponse: raw response: \(rawJSON, privacy: .public)")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatCompletionResponse.self, from: data)

        let choice = response.choices.first
        logger.log("createResponse: choices=\(response.choices.count) finishReason='\(choice?.finishReason ?? "nil", privacy: .public)' content=\(choice?.message.content != nil) reasoningContent=\(choice?.message.reasoningContent != nil) tokens=\(response.usage?.totalTokens ?? -1)")

        return response
    }

    func generateTabName(messages: [ChatMessage]) async throws -> String {
        logger.log("generateTabName: model='\(self.selectedModel, privacy: .public)' apiKey=\(!self.apiKey.isEmpty) baseURL=\(self.baseURL.absoluteString, privacy: .public)")
        let url = Path.chatCompletions.url(for: baseURL)
        logger.log("generateTabName: resolved URL=\(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let userText = messages.map { "\($0.role): \($0.content ?? "")" }.joined(separator: "\n")
        let namingPrompt = ChatMessage(role: "user", content: "Based on the conversation below, reply with ONLY a short tab name (2-5 words, no punctuation, no quotes).\n\n\(userText)")
        let input = ChatCompletionRequest(model: selectedModel, messages: [namingPrompt])
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        logger.log("generateTabName: sending request with \(messages.count) source messages")
        guard let data = try await execute(request: request) else {
            logger.error("generateTabName: execute returned nil data")
            throw RobotAgentClientError.missingData
        }
        logger.log("generateTabName: received \(data.count) bytes")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatCompletionResponse.self, from: data)
        let name = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Chat"
        logger.log("generateTabName: decoded name='\(name, privacy: .public)'")
        return name
    }

    func fetchModels() async throws -> ModelsResponse {
        logger.log("fetchModels: baseURL='\(self.baseURL.absoluteString, privacy: .public)' apiKey=\(!self.apiKey.isEmpty)")

        let url = Path.models.url(for: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue

        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let data = try await execute(request: request) else {
            logger.error("fetchModels: execute returned nil data")
            throw RobotAgentClientError.missingData
        }
        logger.log("fetchModels: received \(data.count) bytes")
        logger.log("\(#function) at \(#line)")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ModelsResponse.self, from: data)
        let ids = response.data.map(\.id).joined(separator: ", ")
        logger.log("fetchModels: found \(response.data.count) models: \(ids, privacy: .public)")
        return response
    }

    private func execute(request: URLRequest) async throws -> Data? {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RobotAgentClientError.invalidResponse(reason: "Invalid HTTP response")
        }
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw RobotAgentClientError.invalidResponse(reason: "Invalid HTTP response: \(errorMessage)")
        }
        return data
    }
}

class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }

        let result = url.path().contains(Path.chatCompletions.rawValue)

        return result
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Task {
            await handleRequest()
        }
    }

    override func stopLoading() {
        // No-op for mock
    }

    private func handleRequest() async {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.path().contains(Path.chatCompletions.rawValue) {
            handleCreateResponseRequest(url: url)
        } else {
            client?.urlProtocol(self, didFailWithError: RobotAgentClientError.unsupportedRequest)
        }
    }

    private func handleCreateResponseRequest(url: URL) {
        guard let url = Bundle.main.url(forResource: "ChatCompletionResponse", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            client?.urlProtocol(self, didFailWithError: RobotAgentClientError.missingData)
            return
        }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
        logger.log("\(#function) at \(#line)")
    }

}
