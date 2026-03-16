// Nebius SF Robotics Hackathon 2026
// RobotArmView.swift

import SwiftUI
import RealityKit
import os.log

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
            .onChange(of: controller.joints) { _, _ in
                logger.log("Controller joints changed, updating scene")
                if let root = sceneRoot {
                    logger.log("Updating scene with stored root")
                    updateScene(root: root, controller: controller)
                } else {
                    logger.warning("sceneRoot is nil, cannot update scene")
                }
            }

            if !controlsHidden {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Robot Simulator")
                        .font(.headline)
                    RobotControlsView()
                }
                .padding()
                .background(.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .onAppear {
            controller.resetScene()
        }
        .focusable()
        .onKeyPress("t", phases: .down) { _ in
            controlsHidden.toggle()
            return .handled
        }
    }
}

#Preview {
    RobotArmView()
}
