#!/bin/bash

# Script to set up Claude Questions in a project

echo "Setting up Claude Questions in current directory..."

# Download ask-claude.sh
if [ ! -f "./ask-claude.sh" ]; then
    echo "Downloading ask-claude.sh..."
    wget -q https://raw.githubusercontent.com/karlwaldman/claude-questions/main/ask-claude.sh
    chmod +x ask-claude.sh
    echo "✓ ask-claude.sh downloaded"
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "./CLAUDE.md" ]; then
    echo "Creating CLAUDE.md..."
    wget -q -O CLAUDE.md https://raw.githubusercontent.com/karlwaldman/claude-questions/main/CLAUDE.md.example
    echo "✓ CLAUDE.md created"
else
    echo "! CLAUDE.md already exists, skipping"
fi

# Add to .gitignore
if ! grep -q "ask-claude.sh" .gitignore 2>/dev/null; then
    echo -e "\n# Claude Questions\nask-claude.sh" >> .gitignore
    echo "✓ Added to .gitignore"
fi

echo ""
echo "✅ Setup complete! Claude will now ask questions through GitHub when needed."
echo ""
echo "Make sure you have set:"
echo "  export CLAUDE_GITHUB_TOKEN=<your-token>"
echo "  export CLAUDE_REPO=karlwaldman/claude-questions"