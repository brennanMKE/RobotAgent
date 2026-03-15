// Nebius SF Robotics Hackathon 2026
// RobotSceneBuilder.swift - Creates 3D entities and scene hierarchy

import RealityKit
import SwiftUI

func makeSceneRoot() -> Entity {
    let root = Entity()

    // Large workspace floor with grid appearance
    let floor = ModelEntity(
        mesh: .generatePlane(width: 2.0, depth: 2.0),
        materials: [SimpleMaterial(color: NSColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0), roughness: 0.8, isMetallic: false)]
    )
    floor.name = "Floor"
    floor.position = [0, 0, 0]
    root.addChild(floor)

    // Add grid lines for better depth perception
    addGridLines(to: root)

    // Anchor for the robot
    let anchor = Entity()
    anchor.name = "RobotAnchor"
    anchor.position = [0, 0.05, 0]
    root.addChild(anchor)

    let robot = makeRobotArm()
    robot.name = "Robot"
    anchor.addChild(robot)

    // Add lighting for better visibility
    addLighting(to: root)

    return root
}

func addGridLines(to root: Entity) {
    let gridSize: Float = 2.0
    let gridSpacing: Float = 0.25
    let lineThickness: Float = 0.005
    let lineHeight: Float = 0.001

    // Vertical lines (along Z axis)
    var x: Float = -gridSize / 2
    while x <= gridSize / 2 {
        let line = ModelEntity(
            mesh: .generateBox(size: [lineThickness, lineHeight, gridSize]),
            materials: [SimpleMaterial(color: NSColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 0.6), roughness: 0.8, isMetallic: false)]
        )
        line.position = [x, 0.0005, 0]
        root.addChild(line)
        x += gridSpacing
    }

    // Horizontal lines (along X axis)
    var z: Float = -gridSize / 2
    while z <= gridSize / 2 {
        let line = ModelEntity(
            mesh: .generateBox(size: [gridSize, lineHeight, lineThickness]),
            materials: [SimpleMaterial(color: NSColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 0.6), roughness: 0.8, isMetallic: false)]
        )
        line.position = [0, 0.0005, z]
        root.addChild(line)
        z += gridSpacing
    }
}

func addLighting(to root: Entity) {
    // Directional light to simulate sun
    var directionalLightTransform = Transform()
    directionalLightTransform.translation = [0.5, 1.0, 0.5]
    let directionalLight = DirectionalLight()
    directionalLight.light.intensity = 1000
    directionalLight.transform = directionalLightTransform
    root.addChild(directionalLight)
}

func makeRobotArm() -> Entity {
    let root = Entity()
    let scale: Float = 3.5  // Scale factor for visibility

    let base = ModelEntity(
        mesh: .generateCylinder(height: 0.03 * scale, radius: 0.05 * scale),
        materials: [SimpleMaterial(color: .darkGray, roughness: 0.4, isMetallic: true)]
    )
    base.name = "Base"
    root.addChild(base)

    let shoulder = Entity()
    shoulder.name = "ShoulderJoint"
    shoulder.position = [0, 0.015 * scale, 0]
    base.addChild(shoulder)

    let upperArm = ModelEntity(
        mesh: .generateBox(size: [0.04 * scale, 0.18 * scale, 0.04 * scale]),
        materials: [SimpleMaterial(color: .cyan, roughness: 0.3, isMetallic: true)]
    )
    upperArm.name = "UpperArm"
    upperArm.position = [0, 0.09 * scale, 0]
    shoulder.addChild(upperArm)

    let elbow = Entity()
    elbow.name = "ElbowJoint"
    elbow.position = [0, 0.18 * scale, 0]
    shoulder.addChild(elbow)

    let forearm = ModelEntity(
        mesh: .generateBox(size: [0.035 * scale, 0.16 * scale, 0.035 * scale]),
        materials: [SimpleMaterial(color: .cyan, roughness: 0.3, isMetallic: true)]
    )
    forearm.name = "Forearm"
    forearm.position = [0, 0.08 * scale, 0]
    elbow.addChild(forearm)

    let wrist = Entity()
    wrist.name = "WristJoint"
    wrist.position = [0, 0.16 * scale, 0]
    elbow.addChild(wrist)

    let wristBody = ModelEntity(
        mesh: .generateBox(size: [0.03 * scale, 0.05 * scale, 0.03 * scale]),
        materials: [SimpleMaterial(color: .cyan, roughness: 0.3, isMetallic: true)]
    )
    wristBody.name = "WristBody"
    wristBody.position = [0, 0.025 * scale, 0]
    wrist.addChild(wristBody)

    let gripper = Entity()
    gripper.name = "Gripper"
    gripper.position = [0, 0.05 * scale, 0]
    wrist.addChild(gripper)

    let leftFinger = ModelEntity(
        mesh: .generateBox(size: [0.01 * scale, 0.05 * scale, 0.01 * scale]),
        materials: [SimpleMaterial(color: .blue, roughness: 0.2, isMetallic: true)]
    )
    leftFinger.name = "LeftFinger"
    leftFinger.position = [-0.015 * scale, 0.025 * scale, 0]
    gripper.addChild(leftFinger)

    let rightFinger = ModelEntity(
        mesh: .generateBox(size: [0.01 * scale, 0.05 * scale, 0.01 * scale]),
        materials: [SimpleMaterial(color: .blue, roughness: 0.2, isMetallic: true)]
    )
    rightFinger.name = "RightFinger"
    rightFinger.position = [0.015 * scale, 0.025 * scale, 0]
    gripper.addChild(rightFinger)

    return root
}
