# ClaudeMenuBar

A lightweight macOS menu bar app that shows real-time status when Claude Code is working, needs your input, or finishes a task.

## What it does

| State | Menu bar shows |
|-------|---------------|
| Idle | `>_` icon |
| Claude is running a tool | Tool name + animated ellipsis |
| Claude needs Y/A/N input | "Needs input" + dropdown with buttons |
| Task complete | "Done" + checkmark (auto-hides after 3 s) |

When Claude Code asks for confirmation, a dropdown panel appears below the menu bar showing the message and three buttons — **Y** (Allow once), **A** (Allow all), **N** (Deny). You can click a button or press the matching key on your keyboard.

## Requirements

- macOS 13 (Ventura) or later
- [Claude Code](https://claude.ai/code) CLI
- Xcode 15+ (to build from source)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Installation

### Build from source

```bash
git clone https://github.com/yourname/ClaudeMenuBar
cd ClaudeMenuBar
xcodegen generate
open ClaudeMenuBar.xcodeproj
```

Press **Cmd+R** in Xcode to build and run.

### Hook setup

Run the install script to wire ClaudeMenuBar into Claude Code's hook system:

```bash
bash scripts/install.sh
```

This adds entries for `PreToolUse`, `PostToolUse`, `Stop`, and `Notification` hooks to `~/.claude/settings.json`. The hook script POSTs each event to `http://localhost:36787/event` in the background so it never slows down Claude.

### Grant Accessibility permission

Global keyboard shortcuts (Y/A/N/Esc) require Accessibility access:

**System Settings → Privacy & Security → Accessibility → ClaudeMenuBar → enable**

Restart the app after granting permission.

## Manual testing

With the app running, send events directly via curl:

```bash
# Working state
curl -s -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'

# Needs input
curl -s -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"Stop","stop_reason":"input_required","message":"Allow this action?"}'

# Complete
curl -s -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"Stop","stop_reason":"task_complete"}'
```

## Architecture

```
ClaudeMenuBarApp        @main entry point
└── MenuBarController   orchestrates all subsystems
    ├── MenuBarPill     NSStatusItem in the menu bar
    ├── DropdownPanel   NSPanel that appears below the pill
    ├── StateManager    @Published AppState, auto-dismissal timers
    ├── EventRouter     maps ClaudeEvent → AppState
    ├── HTTPServer      NWListener on port 36787
    ├── GlobalHotkeys   CGEventTap for Y/A/N/Esc
    └── KeystrokeReplay CGEventPost to forward keystrokes to terminal
```

## Development

```bash
# Regenerate .xcodeproj after editing project.yml
xcodegen generate

# Build from terminal
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ClaudeMenuBar.xcodeproj \
             -scheme ClaudeMenuBar \
             -configuration Debug build

# Run tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
             -project ClaudeMenuBar.xcodeproj \
             -scheme ClaudeMenuBar \
             -testPlan ClaudeMenuBar
```

## License

MIT
