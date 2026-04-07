# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ClaudeMenuBar — a macOS menu bar app that integrates with Claude Code via hooks. A floating pill appears right of the notch in the menu bar, showing Claude's current state and enabling keyboard responses without switching windows.

## Build

Requires Xcode 15+ and xcodegen (`brew install xcodegen`).

```bash
# Regenerate .xcodeproj after modifying project.yml
xcodegen generate

# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run a single test suite
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  -only-testing ClaudeMenuBarTests/EventRouterTests
```

## Architecture

- `StateManager` — single source of truth for `AppState` (silent / working / waitingInput / complete); auto-transitions complete → silent after 3s
- `HTTPServer` — `NWListener` on port 36787; receives Claude Code hook events as JSON POST
- `EventRouter` — maps `ClaudeEvent` JSON to `AppState` transitions
- `MenuBarController` — `@MainActor` orchestrator; observes `StateManager.$state` and updates the two NSPanel windows
- `MenuBarPill` / `DropdownPanel` — borderless `NSPanel` windows that render SwiftUI views at menu bar level
- `GlobalHotkeys` — `CGEventTap` active only in `waitingInput` state; intercepts Y / A / N / 1 / 2 / 3 / Esc
- `KeystrokeReplay` — `CGEventPost` to replay chosen key + Return into the active terminal

## Manual Testing

Run the app, then send test events:

```bash
# Working state (purple pill)
curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"PreToolUse","tool":"Bash","input":{"command":"npm run build"}}'

# Waiting state (orange anchor + dropdown)
curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"input_required","message":"Overwrite files?"}'

# Complete state (green pill, auto-hides after 3s)
curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"task_complete"}'
```

## Notes

- SourceKit will show false "Cannot find type in scope" errors across files — ignore them. `xcodebuild` is the source of truth.
- After adding new `.swift` files, run `xcodegen generate` to update the `.xcodeproj`.
- Accessibility permission is required for `GlobalHotkeys` (CGEventTap) to function.
