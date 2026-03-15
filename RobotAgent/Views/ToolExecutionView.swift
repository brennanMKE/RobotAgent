// Nebius SF Robotics Hackathon 2026
// ToolExecutionView.swift - Display tool calls and results

import SwiftUI

struct ToolExecutionView: View {
    let executions: [ToolExecution]
    @State private var expandedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tool Calls")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(executions.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 4)

            VStack(spacing: 6) {
                ForEach(executions) { execution in
                    ToolExecutionItem(
                        execution: execution,
                        isExpanded: expandedId == execution.id,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedId = expandedId == execution.id ? nil : execution.id
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .padding(.vertical, 4)
    }
}

private struct ToolExecutionItem: View {
    let execution: ToolExecution
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(execution.toolName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arguments")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ToolCallCodeBlock(execution.arguments)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ToolCallCodeBlock(execution.result)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

private struct ToolCallCodeBlock: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToolExecutionView(executions: [
            ToolExecution(
                toolName: "get_arm_state",
                arguments: "{}",
                result: #"{"baseYaw":0,"shoulderPitch":0,"elbowPitch":0,"wristPitch":0,"gripperOpen":0.04}"#
            ),
            ToolExecution(
                toolName: "set_joint_angles",
                arguments: #"{"baseYaw":0.5,"shoulderPitch":0.3,"elbowPitch":0.2,"wristPitch":0,"gripperOpen":0.02,"duration":1.5}"#,
                result: #"{"success":true,"message":"Joint angles set successfully","data":null}"#
            )
        ])

        Spacer()
    }
    .padding()
    .background(Color(.windowBackgroundColor))
}
