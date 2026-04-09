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
- Xcode 15+ (for building from source)

## Install

```bash
git clone https://github.com/TwilightVoyager777/ClaudeMenuBar.git
cd ClaudeMenuBar
bash scripts/build-and-install.sh
```

This builds a Release version, registers Claude Code hooks, generates a DMG installer, and opens it. Drag **ClaudeMenuBar.app** into **Applications**, then launch it.

After launching, go to **System Settings → Privacy & Security → Accessibility** and grant permission to ClaudeMenuBar. This is required for sending keystrokes to your terminal.

> You can also open `ClaudeMenuBar.xcodeproj` in Xcode and press **Cmd+R** to build and run directly, then run `bash scripts/install.sh` to register hooks. Note: the Xcode debug build and the installed app are separate entries in the Accessibility list — grant permission to whichever one you're running.

## Usage

Once installed, just use Claude Code normally in your terminal. The menu bar updates automatically:

- **Working** — shows which tool Claude is running
- **Needs input** — dropdown appears with the permission message and stays until you respond
  - Click a button, or press **Y** (Allow once) / **A** (Allow all) / **N** (Deny)
  - The dropdown won't disappear due to new events — only your response or **Esc** dismisses it
  - If the content is too long to display, check your terminal for details
- **Done** — brief confirmation, then hides

When you select an option, ClaudeMenuBar switches back to the previously active app and sends the response keystroke automatically.

To launch at login, click the `>_` menu bar icon and select **Launch at Login**.

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
    ├── StateManager      @Published AppState + auto-dismiss for complete state
    ├── EventRouter       maps ClaudeEvent → AppState
    ├── HTTPServer        NWListener on port 36787
    ├── GlobalHotkeys     NSEvent monitors for Y/A/N/Esc (active only during WaitingInput)
    └── KeystrokeReplay   CGEventPost to forward responses to the terminal
```

## Feedback

This project is in early development. If you run into bugs or have feature requests, feel free to [open an issue](../../issues). Pull requests are also welcome!

## License

MIT
