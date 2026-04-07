#!/bin/bash
# ClaudeMenuBar hook — forwards Claude Code events to the ClaudeMenuBar app
# Called by Claude Code with event JSON in $CLAUDE_HOOK_EVENT_JSON

curl -s -X POST "http://localhost:36787/event" \
  -H "Content-Type: application/json" \
  -d "${CLAUDE_HOOK_EVENT_JSON}" \
  --max-time 1 \
  --silent \
  --output /dev/null &
