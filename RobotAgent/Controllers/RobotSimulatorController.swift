// Nebius SF Robotics Hackathon 2026
// RobotSimulatorController.swift - Robot state and animation logic

import Foundation
import SwiftUI
import Combine

@MainActor
final class RobotSimulatorController: ObservableObject {
    @Published var joints = RobotJointState()
    @Published var isAnimating = false

    private var animationTask: Task<Void, Never>?

    func resetScene() {
        joints = RobotJointState()
    }

    func moveTo(_ targetState: RobotJointState, config: RobotAnimationConfig = .default) {
        animationTask?.cancel()
        animationTask = Task {
            await animate(to: targetState, config: config)
        }
    }

    func openGripper() {
        joints.gripperOpen = 0.04
    }

    func closeGripper() {
        joints.gripperOpen = 0.005
    }

    private func animate(to target: RobotJointState, config: RobotAnimationConfig) async {
        let start = joints
        isAnimating = true

        for step in 1...config.stepCount {
            let t = Float(step) / Float(config.stepCount)
            let easedT = config.easing == .linear ? t : easeInOut(t)

            joints = RobotJointState(
                baseYaw: start.baseYaw + (target.baseYaw - start.baseYaw) * easedT,
                shoulderPitch: start.shoulderPitch + (target.shoulderPitch - start.shoulderPitch) * easedT,
                elbowPitch: start.elbowPitch + (target.elbowPitch - start.elbowPitch) * easedT,
                wristPitch: start.wristPitch + (target.wristPitch - start.wristPitch) * easedT,
                gripperOpen: start.gripperOpen + (target.gripperOpen - start.gripperOpen) * easedT
            )

            try? await Task.sleep(for: .milliseconds(16))
        }

        isAnimating = false
    }

    private func easeInOut(_ t: Float) -> Float {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - 2 * (1 - t) * (1 - t)
        }
    }
}
