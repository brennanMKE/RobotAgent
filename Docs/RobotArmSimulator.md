# RobotArmSimulator Implementation Plan
**Nebius Robotics Hackathon 2026**

## Overview
Build a RealityKit-based 3D robotic arm simulator inside a SwiftUI macOS app. The arm will receive joint angle data from LLM tool calls and animate smoothly to those positions. Use case: jewelry making and soldering assistance.

---

## Design Goals
- **Precision**: Support fine-grained joint control for delicate soldering/jewelry work
- **Animation**: Smooth interpolation of joint angles over time
- **Extensibility**: Easy to add manual controls and preset positions later
- **LLM Integration**: Accept movement data from tool calls directly
- **Visual Fidelity**: Cyan/turquoise aesthetic matching Nebius robot branding

---

## Architecture

### Layers
1. **View Layer** (`RobotArmView.swift`)
   - Embeds `RealityView` with the 3D scene
   - Displays current joint state (debug/info panel)
   - Placeholder for future manual controls

2. **Scene Layer** (`RobotSceneBuilder.swift`)
   - Creates 3D entities (base, joints, links, gripper)
   - Handles lighting and camera
   - Manages floor/workspace plane

3. **Simulator Layer** (`RobotSimulatorController.swift`)
   - Maintains robot joint state
   - Handles animation/interpolation
   - Exposes methods for receiving movement commands
   - Observable for SwiftUI binding

4. **Data Models** (`RobotModels.swift`)
   - `RobotJointState`: Current angles for all joints
   - `RobotJointCommand`: Incoming movement data from LLM
   - `RobotAnimationConfig`: Timing and easing for animations

5. **LLM Integration** (`RobotToolExecutor.swift`)
   - Decodes tool call JSON arguments
   - Maps to simulator commands
   - Validates joint ranges

6. **Entity Management** (`RobotEntities.swift`)
   - Transform updates based on joint state
   - Joint naming conventions and hierarchy

---

## Robot Kinematics & Joint Structure

### Joints (with estimated ranges for soldering precision)
```
Base (Yaw)
  ├─ Range: -π to π (full rotation for workspace positioning)
  └─ Shoulder Joint (Pitch)
      ├─ Range: -0.5 to 1.2 rad (reach up/down over work surface)
      └─ Upper Arm Link
          └─ Elbow Joint (Pitch)
              ├─ Range: -1.5 to 1.5 rad (bend for height adjustment)
              └─ Forearm Link
                  └─ Wrist Joint (Pitch)
                      ├─ Range: -1.5 to 1.5 rad (fine angle control for tool orientation)
                      └─ Gripper
                          ├─ Open/Close (0.002 to 0.05 m separation)
                          ├─ LeftFinger
                          └─ RightFinger
```

### Link Proportions
- **Upper Arm**: ~180mm (long reach)
- **Forearm**: ~160mm (extended reach for workspace)
- **Wrist**: ~50mm (compact for detail work)
- **Gripper**: Precision-focused, ~40mm opening width max

---

## Color Palette (Nebius Cyan Theme)
- **Primary (arm links)**: Cyan/turquoise `#1DD3B0` or similar
- **Joints**: Dark blue/navy `#2D3E50`
- **Gripper**: Dark blue or darker cyan
- **Base**: Dark blue/charcoal
- **Floor**: Light gray or matte surface

---

## Data Models

### Input from LLM Tool Calls
```swift
struct RobotJointCommand {
    let baseYaw: Float
    let shoulderPitch: Float
    let elbowPitch: Float
    let wristPitch: Float
    let gripperOpen: Float  // 0.0 = closed, 0.05 = fully open
}
```

### Animation Config
```swift
struct RobotAnimationConfig {
    let duration: TimeInterval  // seconds
    let stepCount: Int         // frames
    let easing: EasingType     // .linear, .easeInOut, etc.
}
```

---

## Animation Strategy
1. **No physics simulation** — just smooth interpolation of joint angles
2. **Linear interpolation** between current and target joint states
3. **Fixed framerate**: ~60fps using `Task.sleep(for: .milliseconds(16))`
4. **Configurable duration**: Default 1.0-1.5 seconds per command
5. **Queue support**: Stack commands if needed, or cancel in-flight animations

---

## LLM Tool Integration Flow
1. LLM emits tool call: `set_joint_angles(baseYaw: ..., shoulderPitch: ..., ...)`
2. App decodes JSON arguments → `RobotJointCommand`
3. Validates ranges (clamp to safe limits)
4. Controller animates to target state
5. UI optionally displays: "Animating for 1.2s..."

---

## File Structure
```
RobotAgent/
├── Views/
│   └── RobotArmView.swift              (main container with RealityView)
├── Models/
│   └── RobotModels.swift               (data structures)
├── Controllers/
│   └── RobotSimulatorController.swift  (state + animation logic)
├── Scene/
│   ├── RobotSceneBuilder.swift         (entity creation)
│   └── RobotEntities.swift             (entity transform updates)
└── Tools/
    └── RobotToolExecutor.swift         (LLM tool decoding)
```

---

## Implementation Phases

### Phase 1: MVP (core simulation)
- [ ] Data models (`RobotModels.swift`)
- [ ] Scene builder with static arm (`RobotSceneBuilder.swift`)
- [ ] Controller with basic state (`RobotSimulatorController.swift`)
- [ ] View with `RealityView` embedding (`RobotSimulatorView.swift`)
- [ ] Entity transform updates (`RobotEntities.swift`)

### Phase 2: Animation
- [ ] Interpolation logic in controller
- [ ] Smooth animation over time
- [ ] Debug panel showing joint values

### Phase 3: LLM Integration
- [ ] Tool call decoder (`RobotToolExecutor.swift`)
- [ ] Input validation and clamping
- [ ] Command queuing (optional)

### Phase 4: Manual Controls (post-hackathon)
- [ ] Joint sliders
- [ ] Preset buttons
- [ ] Save/load poses

---

## Key Implementation Notes

1. **Entity Naming**: Use consistent names for joint lookups:
   - `"Robot"`, `"Base"`, `"ShoulderJoint"`, `"UpperArm"`, `"ElbowJoint"`, `"Forearm"`, `"WristJoint"`, `"Gripper"`, `"LeftFinger"`, `"RightFinger"`

2. **Gripper Design**: Use two vertical fingers (like precision tweezers) for holding small components:
   - Each finger: ~30mm length, 2-3mm width
   - Open range: 0.002m (nearly touching) to 0.05m (fully open)
   - Symmetric motion around center

3. **Transform Updates**: Only update during animation frames, not on every state change

4. **Camera**: Fixed perspective looking at the arm from a working angle (above/front)

5. **No Physics**: Objects resting on surfaces or gripper attachment comes later

---

## Success Criteria
- [ ] Arm renders and updates joint angles smoothly
- [ ] LLM tool call data flows to animation
- [ ] Gripper opens/closes smoothly
- [ ] Can manually update joint angles later
- [ ] Clean code separation (view/scene/control/tools)
