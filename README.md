# Claude Questions

Cross-device Claude workflow: work on laptop → Claude asks questions → phone notification → respond from anywhere → Claude continues.

## Mobile Interface

🔗 **[Answer Questions Here](https://karlwaldman.github.io/claude-questions)**

## Setup

1. Set environment variables:
```bash
export CLAUDE_GITHUB_TOKEN="your_token_here"
export CLAUDE_REPO="karlwaldman/claude-questions"
```

2. Use the included `ask-claude.sh` script in any project:
```bash
# Ask a question
./ask-claude.sh urgent "Database Issue" "Should I drop the users table?"

# Check for response
./ask-claude.sh check "2025-01-20-1234-database-issue.md"