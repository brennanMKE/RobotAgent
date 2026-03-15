// Nebius SF Robotics Hackathon 2026
// RobotModels.swift - Data structures for robot state and commands

import Foundation
import simd

nonisolated struct RobotJointState: Sendable, Equatable {
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
