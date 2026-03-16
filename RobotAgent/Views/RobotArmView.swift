// Nebius SF Robotics Hackathon 2026
// RobotArmView.swift

import SwiftUI
import RealityKit
import os.log
import Combine

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "RobotArmView")

struct RobotArmView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var controlsHidden = false
    @State private var sceneRoot: Entity?

    private var controller: RobotSimulatorController {
        appViewModel.robotController
    }

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            // Full-screen RealityView background
            RealityView { content in
                let root = makeSceneRoot()
                root.name = "SceneRoot"
                content.add(root)
                // Store reference for updates
                sceneRoot = root
                logger.log("RealityView initialized with scene root")
            } update: { content in
                guard let root = content.entities.first(where: { $0.name == "SceneRoot" }) else { return }
                logger.log("RealityView update called")
                updateScene(root: root, controller: controller)
            }
            .onReceive(controller.objectWillChange) { _ in
                logger.log("Controller changed, updating scene")
                if let root = sceneRoot {
                    logger.log("Updating scene with stored root")
                    updateScene(root: root, controller: controller)
                } else {
                    logger.warning("sceneRoot is nil, cannot update scene")
                }
            }

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
//                .logGeometry("Arm State")
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
