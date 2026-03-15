#!/bin/bash

# Create screenshots directory if it doesn't exist
SCREENSHOTS_DIR="$(dirname "$0")/../screenshots"
mkdir -p "$SCREENSHOTS_DIR"

# Find the window ID for RobotAgent using bundle ID
WINDOW_ID=$(windows --json | jq -r '.[] | select(.bundleID == "co.sstools.RobotAgent") | .windowID' | head -1)

if [ -z "$WINDOW_ID" ]; then
    echo "Error: Could not find RobotAgent window"
    exit 1
fi

# Generate timestamp with millisecond precision
TIMESTAMP=$(date +%Y%m%d_%H%M%S)_$(python3 -c "import time; print(f'{int((time.time() % 1) * 1000):03d}')")

# Take screenshot
OUTPUT_FILE="$SCREENSHOTS_DIR/robotagent_$TIMESTAMP.png"
screencapture -l "$WINDOW_ID" "$OUTPUT_FILE"

echo "Screenshot saved to: $OUTPUT_FILE"
