// Nebius SF Robotics Hackathon 2026
// RobotSimulatorController.swift - Robot state and animation logic

import Foundation
import Observation

@Observable
@MainActor
final class RobotSimulatorController {
    var joints = RobotJointState()
    var isAnimating = false
    var savedPoses: [RobotPose] = []

    private var animationTask: Task<Void, Never>?
    private let posesKey = "robot_saved_poses"

    init() {
        loadSavedPoses()
    }

    func resetScene() {
        moveTo(RobotJointState())
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

    // MARK: - Pose Management

    func savePose(name: String) {
        let pose = RobotPose(name: name, state: joints)
        savedPoses.append(pose)
        persistSavedPoses()
    }

    func loadPose(_ pose: RobotPose) {
        moveTo(pose.state)
    }

    func deletePose(_ pose: RobotPose) {
        savedPoses.removeAll { $0.id == pose.id }
        persistSavedPoses()
    }

    func loadPreset(_ preset: RobotPreset) {
        moveTo(preset.state)
    }

    private func persistSavedPoses() {
        do {
            let data = try JSONEncoder().encode(savedPoses)
            UserDefaults.standard.set(data, forKey: posesKey)
        } catch {
            print("Failed to save poses: \(error)")
        }
    }

    private func loadSavedPoses() {
        guard let data = UserDefaults.standard.data(forKey: posesKey) else {
            savedPoses = []
            return
        }
        do {
            savedPoses = try JSONDecoder().decode([RobotPose].self, from: data)
        } catch {
            print("Failed to load poses: \(error)")
            savedPoses = []
        }
    }
}

// MARK: - Preset Poses
nonisolated struct RobotPreset: Identifiable {
    let id: String
    let name: String
    let state: RobotJointState
}

extension RobotPreset {
    static let presets = [
        RobotPreset(
            id: "home",
            name: "Home Position",
            state: RobotJointState(baseYaw: 0, shoulderPitch: 0, elbowPitch: 0, wristPitch: 0, gripperOpen: 0.04)
        ),
        RobotPreset(
            id: "reach_forward",
            name: "Reach Forward",
            state: RobotJointState(baseYaw: 0, shoulderPitch: 0.5, elbowPitch: 0.8, wristPitch: 0, gripperOpen: 0.04)
        ),
        RobotPreset(
            id: "reach_up",
            name: "Reach Up",
            state: RobotJointState(baseYaw: 0, shoulderPitch: 1.0, elbowPitch: -1.0, wristPitch: 0, gripperOpen: 0.04)
        ),
        RobotPreset(
            id: "grip_ready",
            name: "Grip Ready",
            state: RobotJointState(baseYaw: 0, shoulderPitch: 0.3, elbowPitch: 0.3, wristPitch: 0, gripperOpen: 0.005)
        ),
        RobotPreset(
            id: "inspect",
            name: "Inspect Position",
            state: RobotJointState(baseYaw: 0, shoulderPitch: -0.3, elbowPitch: 0, wristPitch: 0, gripperOpen: 0.04)
        ),
    ]
}
