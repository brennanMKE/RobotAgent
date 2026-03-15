// Nebius SF Robotics Hackathon 2026
// PromptEntryView.swift

import SwiftUI

struct PromptEntryView: View {
    @Binding var promptText: String
    var isFocused: FocusState<Bool>.Binding

    let isGenerating: Bool
    let onSubmit: (String) -> Void
    let onStop: () -> Void

    private var trimmed: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        let text = promptText
        promptText = ""
        onSubmit(text)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything...", text: $promptText, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .disableAutocorrection(true)
                .focused(isFocused)
                .onSubmit { submit() }
                .disabled(isGenerating)

            if isGenerating {
                Button(action: onStop) {
                    Image(systemName: "square.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(trimmed.isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
                .animation(.easeInOut(duration: 0.15), value: trimmed.isEmpty)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
//        .debugLayout(color: .blue)
    }
}

#Preview {
    @FocusState var focused: Bool
    Group {
        Spacer()

        PromptEntryView(promptText : .constant(""), isFocused: $focused, isGenerating: false) { _ in } onStop: {}
    }
}
