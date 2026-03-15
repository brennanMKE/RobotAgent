// Nebius SF Robotics Hackathon 2026
// AssistantBubble.swift

import SwiftUI

struct AssistantBubble<Content: View>: View {
    var responseText: String? = nil
    @ViewBuilder let content: Content
    #if os(macOS)
    @State private var isHovering = false
    #endif
    @State private var copied = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.gradient)
                .clipShape(Circle())

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if let responseText {
                        Button {
                            copyToClipboard(responseText)
                            withAnimation(.easeInOut(duration: 0.1)) { copied = true }
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(copied ? Color.green : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        #if os(macOS)
                        .opacity(isHovering || copied ? 1 : 0)
                        #else
                        .opacity(copied ? 1 : 0.7)
                        #endif
                    }
                }

            Spacer(minLength: 56)
        }
        #if os(macOS)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
