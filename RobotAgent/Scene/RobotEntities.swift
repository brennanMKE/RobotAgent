// Nebius SF Robotics Hackathon 2026
// RobotEntities.swift - Entity transform updates based on joint state

import RealityKit
import simd

func updateScene(root: Entity, controller: RobotSimulatorController) {
    guard let robot = root.findEntity(named: "Robot"),
          let base = robot.findEntity(named: "Base"),
          let shoulder = robot.findEntity(named: "ShoulderJoint"),
          let elbow = robot.findEntity(named: "ElbowJoint"),
          let wrist = robot.findEntity(named: "WristJoint"),
          let leftFinger = robot.findEntity(named: "LeftFinger"),
          let rightFinger = robot.findEntity(named: "RightFinger")
    else { return }

    base.transform.rotation = simd_quatf(angle: controller.joints.baseYaw, axis: [0, 1, 0])
    shoulder.transform.rotation = simd_quatf(angle: controller.joints.shoulderPitch, axis: [0, 0, 1])
    elbow.transform.rotation = simd_quatf(angle: controller.joints.elbowPitch, axis: [0, 0, 1])
    wrist.transform.rotation = simd_quatf(angle: controller.joints.wristPitch, axis: [0, 0, 1])

    let scale: Float = 3.5
    let offset = max(Float(0.002) * scale, (controller.joints.gripperOpen * scale) / Float(2))
    leftFinger.position.x = -offset
    rightFinger.position.x = offset
}
