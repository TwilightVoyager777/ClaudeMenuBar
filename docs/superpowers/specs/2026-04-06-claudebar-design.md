# ClaudeMenuBar — Design Spec

**Date:** 2026-04-06  
**Project:** ClaudeMenuBar  
**Summary:** A macOS menu bar app that integrates with Claude Code via hooks. A floating pill appears to the right of the notch in the menu bar, showing Claude's current state and allowing keyboard-driven responses without switching windows.

---

## Problem

Claude Code is terminal-based. When it pauses waiting for user input (permission confirmations, multi-choice decisions) or finishes a task, users who have switched to another window miss it entirely. There is no ambient notification that demands attention without being intrusive.

---

## Architecture

```
Claude Code (terminal)
    │
    │  Hook events (PreToolUse / PostToolUse / Stop / Notification)
    ▼
  ~/.claude/hooks/claudemenubar.sh
    │  POST /event  (JSON body)
    ▼
  ClaudeMenuBar.app  (localhost:36787)
  ┌──────────────────────────────┐
  │  HTTPServer   (port 36787)   │  ← receives hook events
  │  EventRouter                 │  ← parses event type & payload
  │  StateManager                │  ← owns current state, drives UI
  │  MenuBarPill  (NSPanel)      │  ← floating pill right of notch
  │  DropdownPanel (NSPanel)     │  ← expands downward on input request
  │  GlobalHotkeys (CGEventTap)  │  ← Y / A / N / 1 / 2 / 3 / Esc
  │  MenuBarExtra  (NSStatusItem)│  ← settings icon, quit
  └──────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| `HTTPServer` | Listens on `localhost:36787`, accepts POST `/event` |
| `EventRouter` | Deserializes JSON, maps to `AppEvent` enum, forwards to `StateManager` |
| `StateManager` | Single source of truth for `AppState`; publishes changes via `@Published` |
| `MenuBarPill` | Borderless `NSPanel` at menu bar level, right of notch; renders compact states |
| `DropdownPanel` | Borderless `NSPanel` anchored below the pill; renders expanded input state |
| `GlobalHotkeys` | `CGEventTap` registered only when state is `.waitingInput`; sends response back to Claude via HTTP |
| `MenuBarExtra` | `NSStatusItem` for settings window and quit |

---

## States

Four states, driven by `StateManager`:

### 1. Silent
- Pill hidden, `MenuBarExtra` dot only
- Entered when: app launches, task completes (after 3s fade), or user presses `Esc`

### 2. Working
- Pill visible (purple), compact, right of notch
- Content: `{ToolName} · {command/filename}` + breathing dot + bouncing ellipsis
- Entered when: `PreToolUse` or `PostToolUse` event received
- Global hotkeys: **inactive**

### 3. WaitingInput
- Pill anchor visible (orange), dropdown panel expanded downward
- Content: message text + Y / A / N buttons (or numbered options 1/2/3)
- Entered when: `Stop` event with `reason: input_required`
- Global hotkeys: **active** — Y, A, N, 1, 2, 3, Esc
- macOS system sound plays on entry

### 4. Complete
- Pill visible (green), compact
- Content: "任务完成" + countdown
- Auto-transitions to Silent after 3 seconds
- Entered when: `Stop` event with `reason: task_complete`
- Global hotkeys: **inactive**

### State Transitions

```
Silent ──PreToolUse──► Working ──PostToolUse──► Working
                                 └──Stop(input)──► WaitingInput ──Y/A/N──► Working or Silent
                                 └──Stop(done)───► Complete ──3s──► Silent
```

---

## Visual Design

**Pill position:** Right of the notch, within menu bar height (28px). On Macs without a notch, centered near top-right of screen.

**Pill dimensions:**
- Compact (Working/Complete): height 22px, border-radius 11px, variable width
- Anchor (WaitingInput): height 22px, top-rounded only, connects to dropdown

**Color coding:**
| State | Pill color | Accent |
|-------|-----------|--------|
| Working | `#13111f` border `#7c3aed44` | Purple `#7c3aed` |
| WaitingInput | `#120c00` border `#f59e0b44` | Amber `#f59e0b` |
| Complete | `#052e16` border `#22c55e44` | Green `#22c55e` |

**Dropdown panel (WaitingInput):**
- Width: 220px, anchored to left edge of pill
- Three option buttons (Y / A / N or 1 / 2 / 3)
- `Y` = green, `A` = blue, `N` = red

**Animations:**
- Working dot: breathing scale + opacity (1.5s ease-in-out loop)
- Ellipsis: staggered bounce (0, 0.2s, 0.4s delay)
- WaitingInput dot: faster pulse (0.8s)
- Pill expand/collapse: spring animation (~0.3s)
- Complete fade-out: opacity 0 over 0.5s after 3s hold

---

## Claude Code Hook Integration

### Hook events used

| Hook | When triggered | ClaudeMenuBar action |
|------|---------------|-----------------|
| `PreToolUse` | Before each tool call | → Working state, show tool name |
| `PostToolUse` | After each tool call | → Update tool name in Working state |
| `Stop` | Claude stops running | → WaitingInput or Complete depending on `reason` |
| `Notification` | Claude emits notification | → Brief message in Working pill |

### Hook script (`~/.claude/hooks/claudemenubar.sh`)

```bash
#!/bin/bash
curl -s -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d "$CLAUDE_HOOK_EVENT_JSON" \
  --max-time 1 &
```

### Event JSON schema

```json
// PreToolUse / PostToolUse
{ "event": "PreToolUse", "tool": "Bash", "input": { "command": "npm run build" } }

// Stop — waiting for input
{ "event": "Stop", "reason": "input_required", "message": "...", "options": ["y","a","n"] }

// Stop — task complete
{ "event": "Stop", "reason": "task_complete" }

// Notification
{ "event": "Notification", "message": "..." }
```

### settings.json hook configuration

```json
{
  "hooks": {
    "PreToolUse":   [{ "matcher": "*", "hooks": [{ "type": "command", "command": "~/.claude/hooks/claudemenubar.sh" }] }],
    "PostToolUse":  [{ "matcher": "*", "hooks": [{ "type": "command", "command": "~/.claude/hooks/claudemenubar.sh" }] }],
    "Stop":         [{ "matcher": "*", "hooks": [{ "type": "command", "command": "~/.claude/hooks/claudemenubar.sh" }] }],
    "Notification": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "~/.claude/hooks/claudemenubar.sh" }] }]
  }
}
```

---

## Keyboard Shortcuts

Global hotkeys registered via `CGEventTap`. Active **only** in `WaitingInput` state.

| Key | Action | Equivalent Claude input |
|-----|--------|------------------------|
| `Y` | Allow once | `y` + Enter |
| `A` | Allow all | `a` + Enter |
| `N` | Deny | `n` + Enter |
| `1` / `2` / `3` | Select numbered option | `1`/`2`/`3` + Enter |
| `Esc` | Dismiss panel (no response sent) | — |

**Permission required:** Accessibility (System Settings → Privacy & Security → Accessibility). ClaudeMenuBar prompts on first launch.

**Response mechanism:** When the user presses a key, ClaudeMenuBar uses `CGEventPost` to simulate the keystroke into the active terminal window (the one running Claude Code). This requires no bidirectional channel — ClaudeMenuBar simply replays the keypress as if the user typed it directly in the terminal.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI + AppKit (`NSPanel`, `NSStatusItem`) |
| Window level | `.statusBar + 1` (above menu bar) |
| HTTP server | Built-in `NWListener` (Network framework) |
| Global hotkeys | `CGEventTap` (CoreGraphics) |
| Minimum macOS | macOS 13 Ventura |

---

## Distribution & Installation

### One-line install
```bash
curl -fsSL https://raw.githubusercontent.com/user/ClaudeMenuBar/main/install.sh | bash
```

### Install script actions
1. Download latest `.dmg` from GitHub Releases
2. Mount and copy `ClaudeMenuBar.app` to `/Applications`
3. Merge hook config into `~/.claude/settings.json`
4. Create `~/.claude/hooks/claudemenubar.sh` and `chmod +x`
5. Launch app and prompt for Accessibility permission

### Distribution channels
- GitHub Releases (notarized `.dmg`)
- Homebrew Cask (`brew install --cask claudemenubar`)

### Non-notch Mac fallback
On Macs without a notch, the pill is positioned at the top-center of the screen at menu bar height, blending into the menu bar background.

---

## Out of Scope (v1)

- Multiple simultaneous Claude Code sessions
- Custom hotkey remapping in settings
- Light mode support (dark menu bar assumed)
- iOS / iPadOS companion
