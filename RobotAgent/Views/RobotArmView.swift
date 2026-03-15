// Nebius SF Robotics Hackathon 2026
// RobotArmView.swift

import SwiftUI
import RealityKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "RobotArmView")

struct RobotArmView: View {
    @StateObject private var controller = RobotSimulatorController()
    @State private var controlsHidden = false

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            // Full-screen RealityView background
            RealityView { content in
                let sceneRoot = makeSceneRoot()
                sceneRoot.name = "SceneRoot"
                content.add(sceneRoot)
            } update: { content in
                guard let root = content.entities.first(where: { $0.name == "SceneRoot" }) else { return }
                updateScene(root: root, controller: controller)
            }
            .border(.red)
            .logGeometry("RealityView")
//            .onGeometryChange(for: CGSize.self) { geo in
//                geo.size
//            } action: { size in
//                logger.log("View size is \(size.width)x\(size.height)")
//            }

            if !controlsHidden {
                // Overlay control panel with 0.7 opacity
                VStack(spacing: 12) {
                    Text("Robot Simulator")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Button("Home") {
                            controller.resetScene()
                        }
                        .keyboardShortcut("h", modifiers: [])

                        Button("Open Gripper") {
                            controller.openGripper()
                        }
                        .keyboardShortcut("o", modifiers: [])

                        Button("Close Gripper") {
                            controller.closeGripper()
                        }
                        .keyboardShortcut("c", modifiers: [])
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joint State:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Base: \(controller.joints.baseYaw.formatted())")
                            .font(.caption2).monospaced()
                        Text("Shoulder: \(controller.joints.shoulderPitch.formatted())")
                            .font(.caption2).monospaced()
                        Text("Elbow: \(controller.joints.elbowPitch.formatted())")
                            .font(.caption2).monospaced()
                        Text("Wrist: \(controller.joints.wristPitch.formatted())")
                            .font(.caption2).monospaced()
                        Text("Gripper: \(controller.joints.gripperOpen.formatted())")
                            .font(.caption2).monospaced()
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding()
                .logGeometry("Arm State")
            }
        }
        .onAppear {
            controller.resetScene()
        }
        .onKeyPress(.init("t"), phases: .down) { _ in
            controlsHidden.toggle()
            return .handled
        }
    }
}

#Preview {
    RobotArmView()
}
