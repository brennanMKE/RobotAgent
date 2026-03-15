# Screenshot

Find the window ID for RobotAgent using bundle ID filtering:

```bash
windows --json | jq '.[] | select(.bundleID == "co.sstools.RobotAgent") | .windowID'
```

Take a screenshot of just that window:

```bash
WINDOW_ID=$(windows --json | jq -r '.[] | select(.bundleID == "co.sstools.RobotAgent") | .windowID' | head -1)
screencapture -l $WINDOW_ID robotagent_screenshot.png
```
