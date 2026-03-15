// Nebius SF Robotics Hackathon 2026
// RobotToolExecutor.swift - LLM tool call decoder and command executor

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "RobotToolExecutor")

nonisolated struct JointLimits: Sendable {
    let min: Float
    let max: Float

    func clamp(_ value: Float) -> Float {
        return Swift.max(self.min, Swift.min(value, self.max))
    }
}

nonisolated enum RobotToolError: Error, Sendable {
    case invalidJSON
    case missingField(String)
    case decodingFailed(Error)
}

class RobotToolExecutor {
    // Joint angle limits (in radians, except gripper which is in meters)
    static let limits = (
        baseYaw: JointLimits(min: -.pi, max: .pi),
        shoulderPitch: JointLimits(min: -0.5, max: 1.2),
        elbowPitch: JointLimits(min: -1.5, max: 1.5),
        wristPitch: JointLimits(min: -1.5, max: 1.5),
        gripperOpen: JointLimits(min: 0.002, max: 0.05)
    )

    /// Decode and validate a tool call JSON for set_joint_angles
    static func parseToolCall(jsonString: String) throws -> RobotJointCommand {
        guard let data = jsonString.data(using: .utf8) else {
            logger.warning("Failed to encode JSON string to UTF-8 data")
            throw RobotToolError.invalidJSON
        }

        do {
            let decoder = JSONDecoder()
            let command = try decoder.decode(RobotJointCommand.self, from: data)
            logger.debug("Decoded joint command: base=\(command.baseYaw, privacy: .public), shoulder=\(command.shoulderPitch, privacy: .public)")
            return validateAndClamp(command)
        } catch let error as DecodingError {
            logger.error("JSON decoding failed: \(error, privacy: .public)")
            throw RobotToolError.decodingFailed(error)
        } catch {
            logger.error("Unexpected error during decoding: \(error, privacy: .public)")
            throw RobotToolError.decodingFailed(error)
        }
    }

    /// Validate and clamp joint angles to safe limits
    static func validateAndClamp(_ command: RobotJointCommand) -> RobotJointCommand {
        let clamped = RobotJointCommand(
            baseYaw: limits.baseYaw.clamp(command.baseYaw),
            shoulderPitch: limits.shoulderPitch.clamp(command.shoulderPitch),
            elbowPitch: limits.elbowPitch.clamp(command.elbowPitch),
            wristPitch: limits.wristPitch.clamp(command.wristPitch),
            gripperOpen: limits.gripperOpen.clamp(command.gripperOpen)
        )

        if clamped.baseYaw != command.baseYaw || clamped.shoulderPitch != command.shoulderPitch {
            logger.debug("Joint angles clamped to safe limits")
        }

        return clamped
    }

    /// Execute a joint command on the simulator controller
    static func execute(_ command: RobotJointCommand, on controller: RobotSimulatorController) {
        let validCommand = validateAndClamp(command)
        logger.info("Executing joint command on robot simulator")
        controller.moveTo(RobotJointState(
            baseYaw: validCommand.baseYaw,
            shoulderPitch: validCommand.shoulderPitch,
            elbowPitch: validCommand.elbowPitch,
            wristPitch: validCommand.wristPitch,
            gripperOpen: validCommand.gripperOpen
        ))
    }

    /// Execute from raw JSON tool call
    static func executeFromJSON(_ jsonString: String, on controller: RobotSimulatorController) throws {
        logger.debug("Processing tool call from LLM")
        let command = try parseToolCall(jsonString: jsonString)
        execute(command, on: controller)
    }
}
