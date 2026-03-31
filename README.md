# ClaudeMonitor

A lightweight macOS menu bar app that monitors your Claude Code sessions in real time.

## Features

- Detects all running Claude Code processes (interactive and background)
- Shows CPU, RAM, and uptime per session
- Extracts session titles from conversation logs
- Kill sessions directly from the UI
- Floating widget (stays on all Spaces)
- Configurable scan interval (5s / 10s / 30s)

## Requirements

- macOS 14.0+
- Claude Code CLI installed

## Install

Download the latest DMG from [Releases](https://github.com/ginoftn/claude-monitor/releases), or build from source:

```bash
make build    # Build Release
make dmg      # Create DMG
```

Since the app is not notarized, right-click > Open on first launch to bypass Gatekeeper.

## How it works

ClaudeMonitor scans running processes for `claude` CLI instances and classifies them:

| Signal | Type |
|--------|------|
| TTY present + parent is a shell | Interactive (orange) |
| No TTY or parent is not a shell | Background (blue) |

Session titles are resolved from `~/.claude/sessions/` and `~/.claude/projects/` — the same data Claude Code uses internally.

## License

MIT
