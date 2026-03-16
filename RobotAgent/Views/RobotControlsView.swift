// Nebius SF Robotics Hackathon 2026
// RobotControlsView.swift - Manual controls for robot arm

import SwiftUI

struct RobotControlsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var saveName = ""
    @State private var presetExpanded = false
    @State private var savedExpanded = false

    private var controller: RobotSimulatorController {
        appViewModel.robotController
    }

    var body: some View {
        VStack(spacing: 12) {
            // Joint Sliders
            VStack(spacing: 8) {
                Text("Joint Controls")
                    .font(.subheadline.bold())

                JointSliderControl(
                    label: "Base (Yaw)",
                    value: controller.joints.baseYaw,
                    range: JointRanges.baseYaw,
                    onValueChange: { value in
                        var state = controller.joints
                        state.baseYaw = value
                        controller.joints = state
                    }
                )

                JointSliderControl(
                    label: "Shoulder",
                    value: controller.joints.shoulderPitch,
                    range: JointRanges.shoulderPitch,
                    onValueChange: { value in
                        var state = controller.joints
                        state.shoulderPitch = value
                        controller.joints = state
                    }
                )

                JointSliderControl(
                    label: "Elbow",
                    value: controller.joints.elbowPitch,
                    range: JointRanges.elbowPitch,
                    onValueChange: { value in
                        var state = controller.joints
                        state.elbowPitch = value
                        controller.joints = state
                    }
                )

                JointSliderControl(
                    label: "Wrist",
                    value: controller.joints.wristPitch,
                    range: JointRanges.wristPitch,
                    onValueChange: { value in
                        var state = controller.joints
                        state.wristPitch = value
                        controller.joints = state
                    }
                )

                JointSliderControl(
                    label: "Gripper",
                    value: controller.joints.gripperOpen,
                    range: JointRanges.gripperOpen,
                    onValueChange: { value in
                        var state = controller.joints
                        state.gripperOpen = value
                        controller.joints = state
                    }
                )
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)

            // Presets
            VStack(spacing: 4) {
                DisclosureGroup(isExpanded: $presetExpanded) {
                    VStack(spacing: 4) {
                        ForEach(RobotPreset.presets) { preset in
                            Button(preset.name) {
                                controller.loadPreset(preset)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Presets")
                        .font(.subheadline.bold())
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)

            // Save/Load Poses
            VStack(spacing: 4) {
                DisclosureGroup(isExpanded: $savedExpanded) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            TextField("Pose name", text: $saveName)
                                .textFieldStyle(.roundedBorder)
                            Button("Save") {
                                if !saveName.isEmpty {
                                    controller.savePose(name: saveName)
                                    saveName = ""
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        if !controller.savedPoses.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            ForEach(controller.savedPoses) { pose in
                                HStack(spacing: 4) {
                                    Button(pose.name) {
                                        controller.loadPose(pose)
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Button(action: { controller.deletePose(pose) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Saved Poses")
                        .font(.subheadline.bold())
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)

            Button("Home") {
                controller.resetScene()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding(12)
    }
}

struct JointSliderControl: View {
    let label: String
    let value: Float
    let range: ClosedRange<Float>
    let onValueChange: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .frame(width: 80, alignment: .leading)
                Slider(value: .init(
                    get: { value },
                    set: { onValueChange($0) }
                ), in: range)
                Text(String(format: "%.2f", value))
                    .font(.caption.monospaced())
                    .frame(width: 45, alignment: .trailing)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RobotControlsView()
            .environment(AppViewModel())
    }
}
