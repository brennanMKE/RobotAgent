// Nebius SF Robotics Hackathon 2026
// MarkdownView.swift

import SwiftUI
import Textual

// MARK: - Copy Store

// Bridges copy actions from inside StructuredText's view hierarchy to buttons rendered outside it.
// Necessary because Textual's NSTextInteractionView (AppKit overlay) intercepts all clicks on
// views inside StructuredText, making buttons there unresponsive.
@Observable
private class CodeBlockCopyStore {
    var actions: [UUID: () -> Void] = [:]
    var copiedID: UUID? = nil
}

// MARK: - Preference Key

// Published from inside CopyableCodeBlock; read in MarkdownView to position overlay buttons.
private struct CodeBlockHeaderFrame: Identifiable, Equatable {
    let id: UUID
    let frame: CGRect
}

private struct CodeBlockHeaderFrameKey: PreferenceKey {
    static let defaultValue: [CodeBlockHeaderFrame] = []
    static func reduce(value: inout [CodeBlockHeaderFrame], nextValue: () -> [CodeBlockHeaderFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - MarkdownView

struct MarkdownView: View {
    let text: String
    @State private var copyStore = CodeBlockCopyStore()
    @State private var headerFrames: [CodeBlockHeaderFrame] = []

    var body: some View {
        StructuredText(markdown: text)
            // codeBlockStyle must be INNER (first) to override structuredTextStyle below.
            .textual.codeBlockStyle(CopyableCodeBlockStyle())
            .textual.structuredTextStyle(.gitHub)
            .textual.textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(copyStore)
            // Named coordinate space so CopyableCodeBlock can report header frames relative
            // to MarkdownView, and the overlay can position buttons at those same coordinates.
            .coordinateSpace(.named("markdownContent"))
            .onPreferenceChange(CodeBlockHeaderFrameKey.self) { headerFrames = $0 }
            .overlay {
                // These buttons render OUTSIDE StructuredText's view subtree, so they are above
                // NSTextInteractionView in z-order and receive clicks correctly.
                // They are invisible — the visual button is drawn inside CopyableCodeBlock.
                ForEach(headerFrames) { header in
                    Button {
                        copyStore.actions[header.id]?()
                        copyStore.copiedID = header.id
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            if copyStore.copiedID == header.id { copyStore.copiedID = nil }
                        }
                    } label: {
                        Color.clear
                            .frame(width: header.frame.width, height: header.frame.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: header.frame.midX, y: header.frame.midY)
                }
            }
    }
}

// MARK: - Code Block Style

private struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        CopyableCodeBlock(configuration: configuration)
    }
}

private struct CopyableCodeBlock: View {
    let configuration: StructuredText.CodeBlockStyleConfiguration
    @Environment(CodeBlockCopyStore.self) private var copyStore
    @State private var blockID = UUID()

    var body: some View {
        let isCopied = copyStore.copiedID == blockID
        VStack(spacing: 0) {
            // Header: visual only. Clicks are handled by the invisible overlay button above.
            HStack(spacing: 6) {
                Text(configuration.languageHint?.lowercased() ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "Copied" : "Copy")
                }
                .font(.caption2)
                .foregroundStyle(isCopied ? Color.green : Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                // Publish the header frame so MarkdownView can position the overlay button.
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CodeBlockHeaderFrameKey.self,
                        value: [CodeBlockHeaderFrame(
                            id: blockID,
                            frame: geo.frame(in: .named("markdownContent"))
                        )]
                    )
                }
            )

            Divider().opacity(0.4)

            Overflow {
                configuration.label
                    .textual.lineSpacing(.fontScaled(0.225))
                    .textual.fontScale(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospaced()
                    .padding(16)
            }
        }
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .textual.blockSpacing(.init(top: 0, bottom: 16))
        .onAppear {
            copyStore.actions[blockID] = { configuration.codeBlock.copyToPasteboard() }
        }
        .onDisappear {
            copyStore.actions.removeValue(forKey: blockID)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        MarkdownView(text: """
        ## Hello World

        This is **bold** and *italic* text with `inline code`.

        ```python
        def greet(name):
            return f"Hello, {name}!"
        ```

        - Item one
        - Item two

        $E = mc^2$
        """)
        .padding()
    }
}
