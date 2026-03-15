#!/bin/zsh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
CLEAN=false
AUTOPROMPT=false

for arg in "$@"; do
    case "$arg" in
        clean)
            CLEAN=true
            ;;
        autoprompt)
            AUTOPROMPT=true
            ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="RobotAgent"
BUILD_PATH="$PROJECT_DIR/build"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "${BLUE}Cleaning project...${NC}"
    xcodebuild clean -scheme "$SCHEME" -derivedDataPath "$BUILD_PATH" > /dev/null
    echo "${GREEN}✓ Clean complete${NC}"
fi

# Build
echo "${BLUE}Building project...${NC}"
xcodebuild build -scheme "$SCHEME" -derivedDataPath "$BUILD_PATH" > /dev/null
echo "${GREEN}✓ Build complete${NC}"

# Kill existing instances
echo "${BLUE}Stopping existing instances...${NC}"
pkill -f "RobotAgent" || true
sleep 1

# Run
echo "${BLUE}Launching app...${NC}"
APP_PATH="$BUILD_PATH/Build/Products/Debug/RobotAgent.app/Contents/MacOS/RobotAgent"

if [ "$AUTOPROMPT" = true ]; then
    echo "${GREEN}✓ Running with autoprompt flag${NC}"
    "$APP_PATH" -autoprompt
else
    echo "${GREEN}✓ Running normally${NC}"
    "$APP_PATH"
fi
