// Nebius SF Robotics Hackathon 2026
// RobotModels.swift - Data structures for robot state and commands

import Foundation
import simd

nonisolated struct RobotJointState: Sendable, Equatable, Codable {
    var baseYaw: Float = 0
    var shoulderPitch: Float = 0
    var elbowPitch: Float = 0
    var wristPitch: Float = 0
    var gripperOpen: Float = 0.04
}

nonisolated struct RobotJointCommand: Decodable, Sendable {
    let baseYaw: Float
    let shoulderPitch: Float
    let elbowPitch: Float
    let wristPitch: Float
    let gripperOpen: Float
}

nonisolated struct RobotAnimationConfig: Sendable {
    let duration: TimeInterval
    let stepCount: Int
    let easing: EasingType

    static let `default` = RobotAnimationConfig(
        duration: 1.0,
        stepCount: 30,
        easing: .linear
    )
}

nonisolated enum EasingType: Sendable {
    case linear
    case easeInOut
}

nonisolated struct RobotPose: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var state: RobotJointState
    var timestamp: Date

    init(name: String, state: RobotJointState) {
        self.id = UUID()
        self.name = name
        self.state = state
        self.timestamp = Date()
    }
}

// Joint range constraints
nonisolated struct JointRanges {
    static let baseYaw: ClosedRange<Float> = -Float.pi...Float.pi
    static let shoulderPitch: ClosedRange<Float> = -0.5...1.2
    static let elbowPitch: ClosedRange<Float> = -1.5...1.5
    static let wristPitch: ClosedRange<Float> = -1.5...1.5
    static let gripperOpen: ClosedRange<Float> = 0.002...0.05

    static func clamp(_ state: RobotJointState) -> RobotJointState {
        RobotJointState(
            baseYaw: state.baseYaw.clamped(to: baseYaw),
            shoulderPitch: state.shoulderPitch.clamped(to: shoulderPitch),
            elbowPitch: state.elbowPitch.clamped(to: elbowPitch),
            wristPitch: state.wristPitch.clamped(to: wristPitch),
            gripperOpen: state.gripperOpen.clamped(to: gripperOpen)
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
