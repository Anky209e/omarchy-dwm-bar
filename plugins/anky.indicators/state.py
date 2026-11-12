import json
import subprocess

def query(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=3)
        return result.returncode, result.stdout[:8192]
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""

def enabled(command):
    code, raw = query(command)
    try:
        return code == 0 and json.loads(raw).get("enabled") is True
    except (ValueError, AttributeError):
        return False

state = {
    "awake": enabled(["omarchy", "toggle", "idle", "status"]),
    "night": enabled(["omarchy", "toggle", "nightlight", "--status"]),
    "dnd": query(["omarchy-shell", "notifications", "isDnd"])[1].strip() == "on",
    "recording": query(["omarchy-capture-screenrecording", "--status"])[0] == 0,
}
print(json.dumps(state))
