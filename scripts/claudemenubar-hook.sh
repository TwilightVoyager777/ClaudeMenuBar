#!/bin/bash
# ClaudeMenuBar hook — Claude Code delivers event JSON on stdin
# Read it all, then POST to the app asynchronously so Claude isn't blocked.

INPUT=$(cat)

curl -s -X POST "http://localhost:36787" \
  -H "Content-Type: application/json" \
  --data-binary "$INPUT" \
  --max-time 1 \
  --output /dev/null &
