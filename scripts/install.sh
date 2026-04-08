#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claudemenubar-hook.sh"

echo "Installing ClaudeMenuBar hooks..."

# 1. Create hooks directory
mkdir -p "$HOOK_DIR"

# 2. Copy hook script from this repo (no network required)
cp "$SCRIPT_DIR/claudemenubar-hook.sh" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"
echo "  ✓ Hook script installed at $HOOK_SCRIPT"

# 3. Merge hook config into settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

python3 - "$SETTINGS_FILE" "$HOOK_SCRIPT" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_cmd      = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

# Claude Code expects matcher-group objects:
#   { "matcher": "<regex>", "hooks": [ { "type": "command", "command": "..." } ] }
matcher_group = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_cmd}]
}

# Subscribe to all relevant events including PermissionRequest
for event in ["PreToolUse", "PostToolUse", "Stop", "Notification", "PermissionRequest"]:
    event_hooks = hooks.setdefault(event, [])
    # Avoid duplicates — check every existing matcher group's inner hooks list
    already = any(
        any(h.get("command") == hook_cmd for h in g.get("hooks", []))
        for g in event_hooks
        if isinstance(g, dict)
    )
    if not already:
        event_hooks.append(matcher_group)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"  ✓ Hooks registered in {settings_path}")
PYEOF

echo "  ✓ Claude Code hooks configured"
echo ""
echo "Done. Open ClaudeMenuBar.app and grant Accessibility permission when prompted."
