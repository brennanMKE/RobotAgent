// Nebius SF Robotics Hackathon 2026
// ThinkingBubble.swift

import SwiftUI

struct ThinkingBubble: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.purple.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Thinking")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.purple)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(Color.purple.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    MarkdownView(text: text)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 56)
        }
    }
}
