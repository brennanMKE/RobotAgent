// Nebius SF Robotics Hackathon 2026
// RobotToolHandler.swift - Execute robot tool calls from LLM

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "RobotToolHandler")

nonisolated struct ToolResult: Codable, Sendable {
    let success: Bool
    let message: String
    let data: String?
}

class RobotToolHandler {
    weak var controller: RobotSimulatorController?

    init(controller: RobotSimulatorController) {
        self.controller = controller
    }

    /// Execute a tool call and return the result as JSON
    func execute(toolCall: ToolCall) -> String {
        logger.log("Executing tool: \(toolCall.function.name, privacy: .public)")

        let result: ToolResult
        switch toolCall.function.name {
        case "get_arm_state":
            result = handleGetArmState()
        case "set_joint_angles":
            result = handleSetJointAngles(toolCall.function.arguments)
        case "set_joint_angles_sequence":
            result = handleSetJointAnglesSequence(toolCall.function.arguments)
        case "move_home":
            result = handleMoveHome()
        case "open_gripper":
            result = handleOpenGripper()
        case "close_gripper":
            result = handleCloseGripper()
        default:
            result = ToolResult(success: false, message: "Unknown tool: \(toolCall.function.name)", data: nil)
        }

        if let jsonData = try? JSONEncoder().encode(result),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{\"success\":false,\"message\":\"Failed to encode result\",\"data\":null}"
    }

    private func handleGetArmState() -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        let state = controller.joints
        let data: [String: Float] = [
            "baseYaw": state.baseYaw,
            "shoulderPitch": state.shoulderPitch,
            "elbowPitch": state.elbowPitch,
            "wristPitch": state.wristPitch,
            "gripperOpen": state.gripperOpen
        ]

        if let jsonData = try? JSONEncoder().encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return ToolResult(success: true, message: "Current arm state retrieved", data: jsonString)
        }
        return ToolResult(success: false, message: "Failed to encode state", data: nil)
    }

    private func handleSetJointAngles(_ argumentsJSON: String) -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        do {
            let command = try RobotToolExecutor.parseToolCall(jsonString: argumentsJSON)
            RobotToolExecutor.execute(command, on: controller)
            return ToolResult(
                success: true,
                message: "Joint angles set successfully",
                data: nil
            )
        } catch {
            logger.error("Failed to execute set_joint_angles: \(error, privacy: .public)")
            return ToolResult(success: false, message: "Failed to set joint angles: \(error)", data: nil)
        }
    }

    private func handleSetJointAnglesSequence(_ argumentsJSON: String) -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        guard let data = argumentsJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let positions = json["positions"] as? [[String: NSNumber]],
              let duration = json["duration"] as? NSNumber else {
            return ToolResult(success: false, message: "Invalid sequence format", data: nil)
        }

        let durationPerPosition = Float(duration.doubleValue)

        // Validate all positions before executing
        var commands: [RobotJointCommand] = []
        for position in positions {
            guard let baseYaw = position["baseYaw"]?.floatValue,
                  let shoulderPitch = position["shoulderPitch"]?.floatValue,
                  let elbowPitch = position["elbowPitch"]?.floatValue,
                  let wristPitch = position["wristPitch"]?.floatValue,
                  let gripperOpen = position["gripperOpen"]?.floatValue else {
                return ToolResult(success: false, message: "Invalid position in sequence", data: nil)
            }

            let command = RobotJointCommand(
                baseYaw: baseYaw,
                shoulderPitch: shoulderPitch,
                elbowPitch: elbowPitch,
                wristPitch: wristPitch,
                gripperOpen: gripperOpen
            )
            commands.append(command)
        }

        // Execute sequence asynchronously without blocking
        Task {
            for command in commands {
                RobotToolExecutor.execute(command, on: controller, duration: durationPerPosition)
                // Wait for this animation to complete before moving to next
                try? await Task.sleep(for: .seconds(TimeInterval(durationPerPosition)))
            }
        }

        return ToolResult(success: true, message: "Sequence executing with \(commands.count) positions", data: nil)
    }

    private func handleMoveHome() -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        controller.resetScene()
        return ToolResult(success: true, message: "Robot arm returned to home position", data: nil)
    }

    private func handleOpenGripper() -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        let command = RobotJointCommand(
            baseYaw: controller.joints.baseYaw,
            shoulderPitch: controller.joints.shoulderPitch,
            elbowPitch: controller.joints.elbowPitch,
            wristPitch: controller.joints.wristPitch,
            gripperOpen: 0.04
        )
        RobotToolExecutor.execute(command, on: controller)
        return ToolResult(success: true, message: "Gripper opened", data: nil)
    }

    private func handleCloseGripper() -> ToolResult {
        guard let controller else {
            return ToolResult(success: false, message: "Controller not available", data: nil)
        }

        let command = RobotJointCommand(
            baseYaw: controller.joints.baseYaw,
            shoulderPitch: controller.joints.shoulderPitch,
            elbowPitch: controller.joints.elbowPitch,
            wristPitch: controller.joints.wristPitch,
            gripperOpen: 0.005
        )
        RobotToolExecutor.execute(command, on: controller)
        return ToolResult(success: true, message: "Gripper closed", data: nil)
    }
}
