#!/bin/bash
set -e

APP_NAME="ClaudeMenuBar"
INSTALL_DIR="/Applications"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claudemenubar-hook.sh"
REPO_RAW="https://raw.githubusercontent.com/user/ClaudeMenuBar/main"  # TODO: update with actual GitHub username before publishing

echo "Installing ClaudeMenuBar..."

# 1. Create hooks directory
mkdir -p "$HOOK_DIR"

# 2. Install hook script
curl -fsSL "$REPO_RAW/scripts/claudemenubar-hook.sh" -o "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"
echo "  ✓ Hook script installed at $HOOK_SCRIPT"

# 3. Merge hook config into settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

HOOK_ENTRY=$(cat <<EOF
{
  "type": "command",
  "command": "$HOOK_SCRIPT"
}
EOF
)

python3 - "$SETTINGS_FILE" "$HOOK_ENTRY" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_json = json.loads(sys.argv[2])

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
for event in ["PreToolUse", "PostToolUse", "Stop", "Notification"]:
    event_hooks = hooks.setdefault(event, [])
    # Avoid duplicates
    if not any(h.get("command") == hook_json["command"] for h in event_hooks):
        event_hooks.append(hook_json)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"  ✓ Hooks registered in {settings_path}")
PYEOF

echo "  ✓ Claude Code hooks configured"
echo ""
echo "ClaudeMenuBar installed. Open ClaudeMenuBar.app to start."
echo "Grant Accessibility permission when prompted."
