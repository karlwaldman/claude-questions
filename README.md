# Claude Questions

Cross-device Claude workflow: work on laptop → Claude asks questions → phone notification → respond from anywhere → Claude continues.

Now with **status updates**: Claude can post progress updates that appear on the web interface!

## Mobile Interface

🔗 **[Answer Questions & View Status](https://karlwaldman.github.io/claude-questions)**

## Features

- 📱 **Mobile-friendly web interface** - Answer from anywhere
- 📊 **Status updates** - Claude posts progress updates with project context
- 🔴 **Priority levels** - Urgent, High, Normal questions
- 🏷️ **Project tracking** - Automatically includes project name
- ♻️ **Auto-refresh** - Updates every 30 seconds
- 📍 **Pull-to-refresh** - Mobile gesture support

## Setup

1. Set environment variables:
```bash
export CLAUDE_GITHUB_TOKEN="your_token_here"
export CLAUDE_REPO="karlwaldman/claude-questions"
```

2. Use the enhanced `ask-claude-status.sh` script:
```bash
# Post a status update
./ask-claude-status.sh status "Completed database migration"

# Ask a question
./ask-claude-status.sh urgent "Database Issue" "Should I drop the users table?"

# Check for response
./ask-claude-status.sh check "2025-01-20-1234-database-issue.md"

# List recent items
./ask-claude-status.sh list