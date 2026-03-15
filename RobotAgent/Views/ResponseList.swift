// Nebius SF Robotics Hackathon 2026
// ResponseList.swift

import SwiftUI

struct ResponseList: View {
    @Environment(ChatViewModel.self) private var chatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(chatViewModel.prompts) { prompt in
                        PromptResponseRow(prompt: prompt)
                            .id(prompt.id)
                    }
                }
                #if os(macOS)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                #else
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                #endif
//                .debugLayout(color: .green)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: chatViewModel.prompts.count) {
                if let last = chatViewModel.prompts.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .top)
                    }
                }
            }
        }
    }
}

private struct PromptResponseRow: View {
    let prompt: PromptAndResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UserBubble(text: prompt.promptText)

            switch prompt.state {
            case .loading:
                AssistantBubble { LoadingDots() }
            case .cancelled:
                AssistantBubble {
                    Label("Generation stopped", systemImage: "stop.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(0.7)
            case .failure(let error):
                AssistantBubble {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .opacity(0.9)
            case .success(let response):
                if let thinking = response.thinkingText {
                    ThinkingBubble(text: thinking)
                }
                AssistantBubble(responseText: response.text) {
                    MarkdownView(text: response.text ?? "-")
                }
            }
        }
    }
}

#Preview {
    let appViewModel = AppViewModel()
    let chatViewModel = ChatViewModel()
    ResponseList()
        .environment(chatViewModel)
        .environment(appViewModel)
}
