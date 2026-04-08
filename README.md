# ClaudeMenuBar

A lightweight macOS menu bar app that shows real-time Claude Code status and lets you respond to permission requests without switching windows.

## What it does

| State | Menu bar shows |
|-------|---------------|
| Idle | `>_` icon only |
| Claude is running a tool | Tool name + animated dots |
| Claude needs permission | "Needs input" + dropdown |
| Task complete | "Done" + checkmark (auto-hides after 3 s) |

When Claude Code asks for permission, a dropdown appears below the menu bar with action buttons. You can respond by:

- **Clicking a button** in the dropdown
- **Pressing Y / A / N** on your keyboard while the dropdown is active
- **Pressing Esc** to dismiss without responding (Claude keeps waiting)

The app detects whether a request has 2 options (Yes / No) or 3 options (Yes / Always / No) and shows buttons accordingly.

## Requirements

- macOS 13 (Ventura) or later
- [Claude Code](https://claude.ai/code) CLI installed
- Xcode 15+ to build from source

## Setup

### 1. Build and run

Open `ClaudeMenuBar.xcodeproj` in Xcode and press **Cmd+R**.

### 2. Install hooks

Run once to wire ClaudeMenuBar into Claude Code:

```bash
bash scripts/install.sh
```

This registers hooks for `PreToolUse`, `PostToolUse`, `Stop`, `StopFailure`, `Notification`, and `PermissionRequest` in `~/.claude/settings.json`. The hook script POSTs each event to `http://localhost:36787` in the background so it never slows Claude down.

## Usage

Once set up, just use Claude Code normally in your terminal. The menu bar updates automatically:

- **Working** — shows which tool Claude is running
- **Needs input** — dropdown appears with the permission message
  - Click a button, or press **Y** (Allow once) / **A** (Allow all) / **N** (Deny)
  - If the content is too long to display, check your terminal for details
  - Press **Esc** to dismiss without responding (Claude keeps waiting)
- **Done** — brief confirmation, then hides

When you select an option, ClaudeMenuBar switches back to your terminal and sends the response keystroke automatically.

## Manual testing

With the app running, simulate events via curl:

```bash
# Permission request — 3 options (Y/A/N)
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf node_modules"},"permission_suggestions":[{"allow":"y"}]}'

# Permission request — 2 options (Y/N)
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"npm install"}}'

# Working state
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/test.py"}}'

# Complete
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"Stop"}'
```

## Architecture

```
ClaudeMenuBarApp          @main entry point
└── MenuBarController     orchestrates all subsystems
    ├── MenuBarPill       NSStatusItem embedded in the menu bar
    ├── DropdownPanel     NSPanel shown below the pill
    ├── StateManager      @Published AppState + auto-dismissal timers
    ├── EventRouter       maps ClaudeEvent → AppState
    ├── HTTPServer        NWListener on port 36787
    ├── GlobalHotkeys     NSEvent monitors for Y/A/N/Esc (active only during WaitingInput)
    └── KeystrokeReplay   CGEventPost to forward responses to the terminal
```

## License

MIT
