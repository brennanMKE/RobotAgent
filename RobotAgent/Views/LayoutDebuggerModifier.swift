// Nebius SF Robotics Hackathon 2026
// LayoutDebuggerModifier.swift

import SwiftUI

private let layoutDebuggingEnabled = true

struct LayoutDebuggerModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if layoutDebuggingEnabled {
            content
                .background(color.opacity(0.75))
                .border(color, width: 1.0)
        } else {
            content
        }
    }
}
extension View {
    func debugLayout(color: Color) -> some View {
        modifier(LayoutDebuggerModifier(color: color))
    }
}
