// Nebius SF Robotics Hackathon 2026
// ChatView.swift

import SwiftUI
import UniformTypeIdentifiers
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ChatView")

private struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ChatView: View {
    let session: ChatSession

    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    @Environment(\.robotAgentClient) private var client
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showExporter = false
    @State private var exportText = ""
    @State private var elapsedSeconds: Int = 0
    @State private var autopromptSent = false

    private var chatViewModel: ChatViewModel {
        session.chatViewModel
    }

    private var statusText: String {
        let tokens = chatViewModel.totalTokensUsed
        if elapsedSeconds > 0 {
            let tokenPart = tokens > 0 ? "\(tokens) tokens · " : ""
            return "\(tokenPart)\(elapsedSeconds)s"
        }
        return "\(tokens) tokens"
    }

    private func exportURL(markdown: String, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name.isEmpty ? "Chat" : name)
            .appendingPathExtension("md")
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack {
                    if chatViewModel.prompts.isEmpty {
                        EmptyStateView()
                    } else {
                        ResponseList()
                            .frame(maxHeight: .infinity)
                    }

                    if chatViewModel.totalTokensUsed > 0 || elapsedSeconds > 0 {
                        HStack {
                            Spacer()
                            Text(statusText)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    }
                }

                RobotArmView()
                    .padding()
            }

            Divider()

            PromptEntryView(
                promptText: $promptText,
                isFocused: $isPromptFocused,
                isGenerating: chatViewModel.isGenerating
            ) { text in
                chatViewModel.createResponse(promptText: text, using: client)
            } onStop: {
                chatViewModel.stopGeneration()
            }
        }
//        .logGeometry("ChatView-VStack")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(session.name)
//        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isPromptFocused = true

            // Check for -autoprompt command-line argument
            if !autopromptSent && CommandLine.arguments.contains("-autoprompt") {
                autopromptSent = true
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    logger.log("Sending autoprompt: 'lower the gripper'")
                    chatViewModel.createResponse(promptText: "lower the gripper", using: client)
                }
            }
        }
        .task(id: chatViewModel.isGenerating) {
            guard chatViewModel.isGenerating else { return }
            elapsedSeconds = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds += 1
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if let markdown = chatViewModel.markdownExport {
                    ShareLink(item: exportURL(markdown: markdown, name: session.name),
                              preview: SharePreview(session.name)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button { } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(true)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    exportText = chatViewModel.markdownExport ?? ""
                    showExporter = true
                } label: {
                    Label("Export", systemImage: "arrow.down.to.line")
                }
                .disabled(chatViewModel.markdownExport == nil)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: MarkdownFile(text: exportText),
            contentType: .plainText,
            defaultFilename: "\(session.name.isEmpty ? "Chat" : session.name).md"
        ) { _ in }
        .environment(chatViewModel)
        .onChange(of: chatViewModel.suggestedName) { _, newName in
            logger.log("onChange suggestedName fired: newName='\(newName ?? "nil", privacy: .public)', session.name='\(session.name, privacy: .public)'")
            guard let newName else {
                logger.log("onChange suggestedName: newName is nil, skipping")
                return
            }
            if session.name.hasPrefix("Chat ") {
                session.name = newName
                logger.log("onChange suggestedName: session.name updated to '\(session.name, privacy: .public)'")
            } else {
                logger.log("onChange suggestedName: session.name '\(session.name, privacy: .public)' does not start with 'Chat ', skipping rename")
            }
            chatViewModel.clearSuggestedName()
        }
    }
}

private struct EmptyStateView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Ask me anything")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("Type a message below to start a conversation.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        #if os(macOS)
        .padding(32)
        #else
        .padding(20)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let appViewModel = AppViewModel()
    ChatView(session: ChatSession(name: "Chat 1"))
        .environment(\.robotAgentClient, .mock)
        .environment(appViewModel)
}
