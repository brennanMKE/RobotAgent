# RobotAgent

A SwiftUI-based macOS application for controlling a robotic arm through natural language commands using LLM-powered tool calling.

**Developed for:** Nebius SF Robotics Hackathon 2026

## Features

- **Natural Language Control**: Issue commands like "lower the gripper" via chat interface
- **Multi-turn Tool Calling**: LLM autonomously executes robot commands and processes results (up to 5 iterations)
- **Dual API Support**: Works with both OpenAI-compatible APIs and Kimi's custom tool call format
- **Real-time Chat Display**: View conversation history with tool execution details
- **Auto-generated Session Names**: Intelligently names chat sessions based on first exchange
- **Export Functionality**: Save conversations to markdown files
- **Robot Simulator**: Visual 3D representation of robot arm state
- **Comprehensive Logging**: Detailed logs for debugging LLM interactions and tool execution
- **Autoprompt Testing**: Launch with `-autoprompt` flag to automatically test with "lower the gripper" command

## Architecture

### Core Components

**ChatViewModel** (`Models/ChatViewModel.swift`)
- Manages conversation state and history
- Handles multi-turn tool calling loop
- Parses both OpenAI and Kimi tool call formats
- Tracks tool execution results for display

**RobotToolHandler** (`Tools/RobotToolHandler.swift`)
- Orchestrates tool execution
- Routes tool calls to appropriate executor
- Returns formatted results to LLM

**RobotToolExecutor** (`Tools/RobotToolExecutor.swift`)
- Parses and validates robot joint commands
- Enforces safety limits (joint angle clamping)
- Executes commands on simulator controller

**RobotAgentClient** (`Networking/RobotAgentClient.swift`)
- HTTP client for OpenAI-compatible APIs
- Handles Kimi API response format (with extra fields)
- Supports both tool_calls array and Kimi's text-based format

### Tool Calling Flow

```
User Prompt
    ↓
LLM Response (check for tool calls)
    ↓
Parse Tool Calls (OpenAI format or Kimi text format)
    ↓
Execute Tool Calls
    ↓
Collect Tool Results
    ↓
Send Results + History Back to LLM
    ↓
Repeat (up to 5 iterations) or Return Final Response
```

## Building and Running

### Quick Start

```bash
# Normal build and run
./build.sh

# Clean build and run
./build.sh clean

# Build and test with autoprompt
./build.sh autoprompt

# Clean, build, and autoprompt
./build.sh clean autoprompt
```

### Manual Build

```bash
xcodebuild build -scheme RobotAgent -derivedDataPath ./build
./build/Build/Products/Debug/RobotAgent.app/Contents/MacOS/RobotAgent
```

## Configuration

Configure API settings through the app's Settings panel:

1. **Base URL**: OpenAI-compatible API endpoint (e.g., `https://api.openai.com/v1`)
2. **API Key**: Your API key for the selected service
3. **Model**: Select from available models after validating connection
4. **System Prompt**: Custom system message for all conversations

Settings are validated automatically when changed and stored in UserDefaults.

### Logging

View real-time logs:
```bash
/usr/bin/log show --predicate 'subsystem == "co.sstools.RobotAgent"' --follow
```

View logs from last minute:
```bash
/usr/bin/log show --predicate 'subsystem == "co.sstools.RobotAgent"' --last 1m
```

## API Compatibility

### OpenAI Format
Tool calls returned as structured array in `tool_calls` field:
```json
{
  "tool_calls": [
    {
      "id": "call_123",
      "type": "function",
      "function": {
        "name": "set_joint_angles",
        "arguments": "{\"baseYaw\": 0.5}"
      }
    }
  ]
}
```

### Kimi Format
Tool calls embedded in response text with markers:
```
<|tool_calls_section_begin|>
<|tool_call_begin|>functions.set_joint_angles:0 {"baseYaw\": 0.5}<|tool_call_end|>
<|tool_calls_section_end|>
```

The app automatically detects and parses both formats.

## Robot Joint Limits

Safety limits are enforced before command execution:
- **Base Yaw**: -π to π radians
- **Shoulder Pitch**: -0.5 to 1.2 radians
- **Elbow Pitch**: -1.5 to 1.5 radians
- **Wrist Pitch**: -1.5 to 1.5 radians
- **Gripper Opening**: 0.002 to 0.05 meters

## Testing

### Autoprompt Feature
Automatically sends "lower the gripper" on launch:
```bash
./build.sh autoprompt
# or
RobotAgent -autoprompt
```

### Session Persistence
Chat sessions are automatically saved and restored on app restart.

### Tool Execution Verification
1. Send a command that triggers tool calls
2. Check logs: `/usr/bin/log show --predicate 'subsystem == "co.sstools.RobotAgent"'`
3. Verify tool execution appears in chat and log output
4. Confirm robot simulator arm moves accordingly

## Troubleshooting

**"No handler available" error**: RobotToolHandler not initialized before tool execution
**JSON decoding failed**: Kimi API response includes unexpected fields (usually auto-resolved with optional fields)
**Tool calls not executing**: Verify API is returning tool calls in expected format (check logs)
**Connection validation fails**: Check Settings - verify Base URL is correct and API Key is valid
**Models don't load**: Ensure connection is validated in Settings; some APIs require specific model names

## Known Limitations

- Tool calling limited to 5 iterations maximum (prevents infinite loops)
- Simulator-only (no real hardware integration yet)
- macOS only

## Future Enhancements

- Hardware robot control
- Advanced motion planning
- Obstacle detection and avoidance
- Multi-robot coordination
- Voice control integration

## Project Structure

```
RobotAgent/
├── Models/
│   ├── ChatViewModel.swift        # Chat state and tool calling logic
│   ├── ChatSession.swift          # Session persistence
│   └── RobotJointCommand.swift    # Robot command structures
├── Tools/
│   ├── RobotToolHandler.swift     # Tool execution orchestration
│   └── RobotToolExecutor.swift    # Joint command execution
├── Networking/
│   └── RobotAgentClient.swift     # LLM API client
├── Views/
│   ├── ChatView.swift             # Main chat interface
│   ├── ResponseList.swift         # Conversation display
│   └── RobotArmView.swift         # 3D arm simulator
└── build.sh                       # Build automation script
```

## License

Developed for Nebius SF Robotics Hackathon 2026
