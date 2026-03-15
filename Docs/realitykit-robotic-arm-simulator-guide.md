# RealityKit Robotic Arm Simulator in a SwiftUI Mac App
*A build guide for a 3D robotic arm view that manipulates objects in a shared scene*

This guide shows how to build a **robotic arm simulator** embedded inside a **SwiftUI macOS app** using **RealityKit**. The goal is a practical simulator you can connect to **LLM tool calls** later, while keeping the 3D rendering native to your app.

The simulator will support:

- a 3D scene embedded in SwiftUI
- a robotic arm made from articulated joints
- movable objects in the workspace
- simple pick/place behavior
- a clean separation between:
  - scene rendering
  - robot state
  - simulation logic
  - LLM/tool-call control

---

# 1. What you are building

Architecture:

```text
SwiftUI app
   ↓
RealityView
   ↓
RealityKit scene
   ↓
Robot entities + object entities
   ↓
Simulator/controller
   ↓
Optional LLM tool calls
```

The robot arm is represented as a hierarchy of entities:

```text
Root
 └─ Base
     └─ Shoulder
         └─ UpperArmLink
             └─ Elbow
                 └─ ForearmLink
                     └─ Wrist
                         └─ Gripper
                             ├─ LeftFinger
                             └─ RightFinger
```

Objects sit on a floor plane in the same scene.

---

# 2. Project setup

Requirements:

- Xcode with macOS SwiftUI support
- macOS target that supports `RealityView`
- `RealityKit`
- `SwiftUI`

Start with a new **macOS App** project in Xcode.

---

# 3. High-level design

Use four layers:

## A. View layer
Responsible for embedding the RealityKit scene.

## B. Scene layer
Creates entities, materials, lights, and object models.

## C. Simulator layer
Maintains robot joint state and object attachment state.

## D. Command layer
Receives user commands or LLM tool calls and converts them into simulator actions.

This separation matters. Do not make the 3D view itself decide robot logic.

---

# 4. Data model

Create a robot state model.

```swift
import Foundation
import simd

struct RobotJointState {
    var baseYaw: Float = 0
    var shoulderPitch: Float = 0
    var elbowPitch: Float = 0
    var wristPitch: Float = 0
    var gripperOpen: Float = 0.04
}

struct RobotPose {
    var joints: RobotJointState
}

struct SceneObjectState: Identifiable {
    let id: UUID
    var name: String
    var position: SIMD3<Float>
    var size: SIMD3<Float>
    var isHeld: Bool
}

enum RobotAction {
    case moveToJoints(RobotJointState)
    case openGripper
    case closeGripper
    case pickObject(UUID)
    case placeHeldObject(position: SIMD3<Float>)
}
```

Keep your simulator state in an observable controller:

```swift
import SwiftUI
import RealityKit

@MainActor
final class RobotSimulatorController: ObservableObject {
    @Published var joints = RobotJointState()
    @Published var objects: [SceneObjectState] = []
    @Published var heldObjectID: UUID?

    func resetScene() {
        joints = RobotJointState()
        heldObjectID = nil
        objects = [
            SceneObjectState(
                id: UUID(),
                name: "Red Cube",
                position: [0.18, 0.02, -0.08],
                size: [0.04, 0.04, 0.04],
                isHeld: false
            ),
            SceneObjectState(
                id: UUID(),
                name: "Blue Cube",
                position: [0.24, 0.02, 0.02],
                size: [0.04, 0.04, 0.04],
                isHeld: false
            )
        ]
    }
}
```

---

# 5. Embedding RealityKit in SwiftUI

Create a simple view shell:

```swift
import SwiftUI
import RealityKit

struct RobotSimulatorView: View {
    @StateObject private var controller = RobotSimulatorController()

    var body: some View {
        VStack {
            RealityView { content in
                let sceneRoot = makeSceneRoot(controller: controller)
                sceneRoot.name = "SceneRoot"
                content.add(sceneRoot)
            } update: { content in
                guard let root = content.entities.first(where: { $0.name == "SceneRoot" }) else { return }
                updateScene(root: root, controller: controller)
            }

            controlPanel
        }
        .onAppear {
            controller.resetScene()
        }
    }

    var controlPanel: some View {
        VStack {
            Text("Robot Simulator")
                .font(.headline)

            HStack {
                Button("Home") {
                    controller.joints = RobotJointState()
                }
                Button("Open Gripper") {
                    controller.joints.gripperOpen = 0.04
                }
                Button("Close Gripper") {
                    controller.joints.gripperOpen = 0.005
                }
            }
        }
        .padding()
    }
}
```

---

# 6. Creating the 3D scene

Create a reusable scene builder.

```swift
import RealityKit
import SwiftUI

func makeSceneRoot(controller: RobotSimulatorController) -> Entity {
    let root = Entity()

    let floor = ModelEntity(
        mesh: .generatePlane(width: 0.8, depth: 0.8),
        materials: [SimpleMaterial(color: .gray.opacity(0.35), roughness: 0.9, isMetallic: false)]
    )
    floor.name = "Floor"
    floor.position = [0, 0, 0]
    root.addChild(floor)

    let anchor = Entity()
    anchor.name = "RobotAnchor"
    anchor.position = [0, 0, 0]
    root.addChild(anchor)

    let robot = makeRobotArm()
    robot.name = "Robot"
    anchor.addChild(robot)

    let cameraPivot = Entity()
    cameraPivot.name = "CameraPivot"
    cameraPivot.position = [0, 0.25, 0.45]
    root.addChild(cameraPivot)

    addSceneObjects(root: root, controller: controller)
    return root
}
```

---

# 7. Building the robot arm hierarchy

Use boxes and simple primitives first. Fancy models can come later.

```swift
func makeRobotArm() -> Entity {
    let root = Entity()

    let base = ModelEntity(
        mesh: .generateCylinder(height: 0.03, radius: 0.05),
        materials: [SimpleMaterial(color: .darkGray, roughness: 0.4, isMetallic: true)]
    )
    base.name = "Base"
    root.addChild(base)

    let shoulder = Entity()
    shoulder.name = "ShoulderJoint"
    shoulder.position = [0, 0.015, 0]
    base.addChild(shoulder)

    let upperArm = ModelEntity(
        mesh: .generateBox(size: [0.04, 0.18, 0.04]),
        materials: [SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: true)]
    )
    upperArm.name = "UpperArm"
    upperArm.position = [0, 0.09, 0]
    shoulder.addChild(upperArm)

    let elbow = Entity()
    elbow.name = "ElbowJoint"
    elbow.position = [0, 0.18, 0]
    shoulder.addChild(elbow)

    let forearm = ModelEntity(
        mesh: .generateBox(size: [0.035, 0.16, 0.035]),
        materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
    )
    forearm.name = "Forearm"
    forearm.position = [0, 0.08, 0]
    elbow.addChild(forearm)

    let wrist = Entity()
    wrist.name = "WristJoint"
    wrist.position = [0, 0.16, 0]
    elbow.addChild(wrist)

    let wristBody = ModelEntity(
        mesh: .generateBox(size: [0.03, 0.05, 0.03]),
        materials: [SimpleMaterial(color: .green, roughness: 0.3, isMetallic: true)]
    )
    wristBody.name = "WristBody"
    wristBody.position = [0, 0.025, 0]
    wrist.addChild(wristBody)

    let gripper = Entity()
    gripper.name = "Gripper"
    gripper.position = [0, 0.05, 0]
    wrist.addChild(gripper)

    let leftFinger = ModelEntity(
        mesh: .generateBox(size: [0.01, 0.05, 0.01]),
        materials: [SimpleMaterial(color: .red, roughness: 0.2, isMetallic: true)]
    )
    leftFinger.name = "LeftFinger"
    leftFinger.position = [-0.015, 0.025, 0]
    gripper.addChild(leftFinger)

    let rightFinger = ModelEntity(
        mesh: .generateBox(size: [0.01, 0.05, 0.01]),
        materials: [SimpleMaterial(color: .red, roughness: 0.2, isMetallic: true)]
    )
    rightFinger.name = "RightFinger"
    rightFinger.position = [0.015, 0.025, 0]
    gripper.addChild(rightFinger)

    return root
}
```

---

# 8. Adding scene objects

Represent workspace objects as named entities.

```swift
func addSceneObjects(root: Entity, controller: RobotSimulatorController) {
    for object in controller.objects {
        let entity = ModelEntity(
            mesh: .generateBox(size: object.size),
            materials: [SimpleMaterial(color: object.name.contains("Red") ? .red : .blue, roughness: 0.6, isMetallic: false)]
        )
        entity.name = "Object_\(object.id.uuidString)"
        entity.position = object.position
        root.addChild(entity)
    }
}
```

When objects are added or reset, rebuild or reconcile them in `updateScene`.

---

# 9. Updating transforms from simulator state

This is the core of the simulator.

```swift
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

    let offset = max(0.002, controller.joints.gripperOpen / 2)
    leftFinger.position.x = -offset
    rightFinger.position.x = offset

    reconcileObjects(root: root, controller: controller)
    updateHeldObjectAttachment(root: root, controller: controller)
}
```

---

# 10. Managing scene objects

Use IDs in state and names in RealityKit.

```swift
func reconcileObjects(root: Entity, controller: RobotSimulatorController) {
    for object in controller.objects {
        let name = "Object_\(object.id.uuidString)"
        if let entity = root.findEntity(named: name) {
            if controller.heldObjectID != object.id {
                entity.position = object.position
            }
        } else {
            let entity = ModelEntity(
                mesh: .generateBox(size: object.size),
                materials: [SimpleMaterial(color: .cyan, roughness: 0.6, isMetallic: false)]
            )
            entity.name = name
            entity.position = object.position
            root.addChild(entity)
        }
    }
}
```

---

# 11. Simulating grasping

For a first version, do not simulate contact forces. Attach the held object to the gripper.

```swift
func updateHeldObjectAttachment(root: Entity, controller: RobotSimulatorController) {
    guard let robot = root.findEntity(named: "Robot"),
          let gripper = robot.findEntity(named: "Gripper")
    else { return }

    for object in controller.objects {
        let name = "Object_\(object.id.uuidString)"
        guard let entity = root.findEntity(named: name) ?? gripper.findEntity(named: name) else { continue }

        if controller.heldObjectID == object.id {
            if entity.parent !== gripper {
                entity.removeFromParent()
                entity.position = [0, 0.06, 0]
                gripper.addChild(entity)
            }
        } else {
            if entity.parent === gripper {
                let worldTransform = entity.transformMatrix(relativeTo: nil)
                entity.removeFromParent()
                root.addChild(entity)
                entity.setTransformMatrix(worldTransform, relativeTo: nil)
            }
        }
    }
}
```

This gives you a reliable pick/place illusion for a demo.

---

# 12. Implementing simulator actions

Add action methods on the controller.

```swift
extension RobotSimulatorController {
    func moveTo(_ newState: RobotJointState) {
        joints = newState
    }

    func openGripper() {
        joints.gripperOpen = 0.04
    }

    func closeGripper() {
        joints.gripperOpen = 0.005
    }

    func pickNearestObject() {
        guard heldObjectID == nil else { return }
        guard let target = objects.first else { return }

        heldObjectID = target.id
        if let index = objects.firstIndex(where: { $0.id == target.id }) {
            objects[index].isHeld = true
        }
    }

    func placeHeldObject(at position: SIMD3<Float>) {
        guard let heldObjectID else { return }
        if let index = objects.firstIndex(where: { $0.id == heldObjectID }) {
            objects[index].position = position
            objects[index].isHeld = false
        }
        self.heldObjectID = nil
    }
}
```

Later you can replace `pickNearestObject()` with a better selection algorithm based on gripper position.

---

# 13. Adding basic animation

For a better demo, interpolate joint values.

A simple approach is to store a target joint state and update over time with a timer or task loop.

```swift
extension RobotSimulatorController {
    func animate(to target: RobotJointState, steps: Int = 30) {
        let start = joints

        Task { @MainActor in
            for step in 1...steps {
                let t = Float(step) / Float(steps)
                joints = RobotJointState(
                    baseYaw: start.baseYaw + (target.baseYaw - start.baseYaw) * t,
                    shoulderPitch: start.shoulderPitch + (target.shoulderPitch - start.shoulderPitch) * t,
                    elbowPitch: start.elbowPitch + (target.elbowPitch - start.elbowPitch) * t,
                    wristPitch: start.wristPitch + (target.wristPitch - start.wristPitch) * t,
                    gripperOpen: start.gripperOpen + (target.gripperOpen - start.gripperOpen) * t
                )
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}
```

This is enough for a smooth hackathon demo.

---

# 14. Tool-call integration design

This simulator is a perfect target for LLM tools.

Example tool schema:

```json
[
  {
    "type": "function",
    "function": {
      "name": "set_joint_angles",
      "description": "Move robot joints to the provided angles in radians.",
      "parameters": {
        "type": "object",
        "properties": {
          "baseYaw": { "type": "number" },
          "shoulderPitch": { "type": "number" },
          "elbowPitch": { "type": "number" },
          "wristPitch": { "type": "number" },
          "gripperOpen": { "type": "number" }
        },
        "required": ["baseYaw", "shoulderPitch", "elbowPitch", "wristPitch", "gripperOpen"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "pick_object",
      "description": "Pick up the named object if reachable.",
      "parameters": {
        "type": "object",
        "properties": {
          "objectName": { "type": "string" }
        },
        "required": ["objectName"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "place_object",
      "description": "Place the held object at the provided coordinates.",
      "parameters": {
        "type": "object",
        "properties": {
          "x": { "type": "number" },
          "y": { "type": "number" },
          "z": { "type": "number" }
        },
        "required": ["x", "y", "z"]
      }
    }
  }
]
```

Recommended rule:

**Let the LLM choose actions, but let Swift enforce all limits and validity.**

---

# 15. Swift decoding example for tool calls

```swift
struct SetJointAnglesArgs: Decodable {
    let baseYaw: Float
    let shoulderPitch: Float
    let elbowPitch: Float
    let wristPitch: Float
    let gripperOpen: Float
}

@MainActor
func handleToolCall(name: String, argumentsData: Data, controller: RobotSimulatorController) throws {
    switch name {
    case "set_joint_angles":
        let args = try JSONDecoder().decode(SetJointAnglesArgs.self, from: argumentsData)
        controller.animate(
            to: RobotJointState(
                baseYaw: clamp(args.baseYaw, min: -.pi, max: .pi),
                shoulderPitch: clamp(args.shoulderPitch, min: -1.2, max: 1.2),
                elbowPitch: clamp(args.elbowPitch, min: -1.5, max: 1.5),
                wristPitch: clamp(args.wristPitch, min: -1.5, max: 1.5),
                gripperOpen: clamp(args.gripperOpen, min: 0.002, max: 0.05)
            )
        )

    default:
        break
    }
}

func clamp(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
    Swift.max(minValue, Swift.min(maxValue, value))
}
```

---

# 16. Reachability and simple kinematics

For a first version, do not overcomplicate inverse kinematics.

Use one of these approaches:

## Option A: Tool calls provide joint values
Fastest to implement.

## Option B: Tool calls provide named actions
Examples:
- `pick_object("Red Cube")`
- `place_object(x:y:z:)`

Your Swift simulator maps those to predefined poses.

## Option C: Add lightweight IK later
Only add this if time permits.

For the hackathon, **Option B** is the sweet spot.

---

# 17. Manipulating objects in a believable way

You do not need full rigid-body physics for a strong demo. Use these rules:

- objects rest on the table when not held
- held objects become children of the gripper
- placing detaches the object back into world space
- if an object is stacked, snap it onto a target position

This looks convincing and is much more reliable than trying to simulate grasp friction under time pressure.

---

# 18. Suggested MVP

Build this first:

- one robot arm
- two cubes
- floor plane
- home/open/close controls
- one `pick` button
- one `place` button
- one tool-call path for `set_joint_angles`

That already proves the concept.

---

# 19. Suggested next features

If you finish the MVP, add:

## Better visuals
- directional light
- shadows
- colored materials
- labels or overlays

## Better control
- sliders for each joint
- reset button
- scene inspector panel

## Better simulation
- pick nearest object to gripper
- simple stack points
- command queue display

## Better AI integration
- tool log panel
- JSON viewer
- "Run task" text field
- system prompt tuned for robot actions

---

# 20. Debugging tips

## The arm rotates strangely
Check the axis for each joint. Many arm issues are just the wrong rotation axis.

## Objects jump when dropped
Always preserve world transform when reparenting between root and gripper.

## Gripper looks wrong
Keep finger motion simple and symmetric.

## The scene rebuilds unexpectedly
Keep entity lookup stable by naming important entities.

---

# 21. Recommended file layout

```text
RobotSimulatorView.swift
RobotSimulatorController.swift
RobotSceneBuilder.swift
RobotEntities.swift
RobotToolExecutor.swift
RobotModels.swift
```

---

# 22. Good prompt strategy for an LLM

Tell the model:

- it is controlling a simulated robotic arm
- it may only use the provided tools
- it must not invent objects
- it should ask for scene state when uncertain
- it must prefer safe, simple actions

Example system prompt:

```text
You are controlling a simulated robotic arm in a 3D workspace.
Only use the provided tools.
Do not assume object positions unless a tool has reported them.
Prefer small, safe actions.
If you need the robot state or scene state, request it with a tool call.
```

---

# 23. Best implementation strategy for tonight

Build in this order:

1. SwiftUI view with `RealityView`
2. static floor and robot entities
3. joint sliders to prove transforms work
4. object entities
5. held-object attachment
6. tool-call decoder
7. animation
8. polish

---

# 24. What success looks like

A strong demo would be:

1. user enters: “pick up the red cube and move it next to the blue cube”
2. model emits tool calls
3. your app shows the calls in a side panel
4. the RealityKit arm animates to the command
5. the red cube gets attached to the gripper
6. the cube is placed in the new location

That is a very convincing robotics + LLM demo even without hardware.

---

# 25. Final recommendation

For your use case, the best path is:

- **RealityKit for rendering**
- **Swift state/controller for simulation**
- **tool calls for robot commands**
- **simple attachment-based object manipulation**
- **no full physics unless you have extra time**

That gives you a robust, native, and hackathon-friendly simulator inside your Mac app.

