// Nebius SF Robotics Hackathon 2026
// GeometryLoggingModifier.swift

import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "Geometry")

struct GeometryLoggingModifier: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(
                for: CGSize.self,
                of: { proxy in proxy.size },
                action: { oldSize, newSize in
                    logger.log("[\(self.label)] size: width=\(newSize.width, privacy: .public), height=\(newSize.height, privacy: .public)")
                }
            )
    }
}

extension View {
    func logGeometry(_ label: String) -> some View {
        modifier(GeometryLoggingModifier(label: label))
    }
}
