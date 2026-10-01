# Notification Handling - EduMaps Development

This document describes the notification infrastructure for development cycles.

## Files

- `tools/notify/notify.sh` - Main notification script
- `tools/notify/telegram.sh` - Telegram Bot API integration
- `tools/notify/github.sh` - GitHub comment integration via `gh` CLI
- `tools/notify/.env` - Configuration (NOT version controlled)

## User Constraint

⚠️ **Do NOT run `notify.sh` during agent testing or demonstrations.**

The script sends real messages to Telegram and comments on GitHub PRs/issues.
Only run when a development cycle is truly complete, blocked, or at a significant milestone.

## Testing Without Sending

Use `--dry-run` to preview messages without sending:

```bash
./tools/notify/notify.sh --event stage --title "Prévia" --dry-run
```

## When Notifications Are Appropriate

| Event | When to Run |
|---|---|
| `stage` | After completing a development phase (not during testing) |
| `blocked` | When the agent needs developer input/permission |
| `done` | After merging a PR and completing documentation |

## Configuration

See `tools/notify/.env.example` for required variables:
- `TELEGRAM_BOT_TOKEN` - Bot token from @BotFather
- `TELEGRAM_CHAT_ID` - Your chat ID (from getUpdates)
- `ENABLE_TELEGRAM=1` - Set to enable Telegram notifications