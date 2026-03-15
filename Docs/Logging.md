# FlaschenTaschen - Logging

## Overview

The app uses Apple's [unified logging system](https://developer.apple.com/documentation/os/logging) (`os.log`) for structured, privacy-aware debug output. Logs appear in **Console.app** and `log` CLI and are automatically captured in crash reports.

## Setup

A shared `Logging` enum in `Logging.swift` provides the subsystem string:

```swift
// Logging.swift
import Foundation

enum Logging {
    static let subsystem = Bundle.main.bundleIdentifier ?? "co.sstools.FlaschenTaschen"
}
```

Each file that needs logging declares a **file-scoped, nonisolated logger** at the top:

```swift
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "CategoryName")
```

- `nonisolated` — avoids main-actor isolation warnings since `Logger` is a value type and safe to create from any context.
- `private` — scoped to the file; no logger leaks between modules.
- `category` — identifies the source file or subsystem area in Console.app (e.g. `"UDPServer"`, `"PPMParser"`).

## Usage

Use the appropriate log level for the situation:

| Level | Method | When to use |
|-------|--------|-------------|
| Debug | `logger.debug(...)` | Verbose tracing: method calls, state transitions, values |
| Info | `logger.info(...)` | Informational: significant but expected events |
| Notice | `logger.notice(...)` | Default level: important runtime events |
| Warning | `logger.warning(...)` | Unexpected but recoverable situations |
| Error | `logger.error(...)` | Errors that affect functionality |
| Fault | `logger.fault(...)` | Programming errors / assertions |

### Examples

```swift
// Trace a UDP packet
logger.debug("Packet received: size=\(image.width)x\(image.height) offset=(\(image.offsetX),\(image.offsetY))")

// Server startup
logger.info("UDP server starting on port 1337, grid=\(gridWidth)x\(gridHeight)")

// Warn about an invalid value
logger.warning("Invalid color depth: \(maxValue), expected 255")

// Record a parse failure
logger.error("Failed to parse packet: \(error.localizedDescription)")
```

## Privacy

`os.log` redacts dynamic string interpolation in release builds by default. To make a value visible in release logs, use `.public`:

```swift
logger.debug("Count: \(items.count, privacy: .public)")
```

Sensitive data (user text, URLs) should remain at the default (redacted in release) or use `.private`.

## Viewing Logs

**Console.app:**
1. Open Console.app → select the device (Mac)
2. Filter by subsystem: `co.sstools.FlaschenTaschen`
3. Filter by category (e.g. `UDPServer`) for per-file logs

**Command line:**
```sh
# All logs from the app
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --level debug

# Logs from a specific category
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen" and category == "UDPServer"' --level debug

# Follow logs in real-time (add --level debug to see debug messages)
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --follow --level debug
```

## Current Loggers

| File | Category | Events logged |
|------|----------|-----------------|
| `UDPServer.swift` | `UDPServer` | Server startup, port binding, connection events, packet parse errors |
| `PPMParser.swift` | `PPMParser` | Magic number validation, color depth checks, successful parse events |
| `DisplayModel.swift` | `DisplayModel` | Server start/stop, grid dimension changes, packet count, startup failures |

## Development Workflow

### Testing Server Auto-Start

The UDP server starts automatically when the app launches. Use the debug script to verify startup:

```bash
# Build, run, and capture logs
./debug.sh --note "Testing server auto-start" build run logs screenshot

# Check for successful startup in the logs
grep "UDP server ready" debug/*/logs.txt

# Check for errors (if any)
grep -i "error\|failed" debug/*/logs.txt

# Verify UI shows "Server: Running"
open debug/*/screenshot.png
```

### Real-Time Log Monitoring

Watch logs as they happen:

```bash
# Terminal 1: Run the app
./debug.sh build run

# Terminal 2: Watch logs in real-time (in another terminal)
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --level debug --follow
```

### Testing with Network Packets

After the server is running:

```bash
# Terminal 1: Run the app
./debug.sh build run

# Terminal 2: Watch logs
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --level debug --follow

# Terminal 3: Send a test packet (from flaschen-taschen repo)
# Use the C++ client or test utilities to send PPM data to port 1337
```

This allows you to correlate app behavior with detailed logging output.
