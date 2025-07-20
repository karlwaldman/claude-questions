#!/bin/bash

# Setup Claude Questions in a project directory (safely)

PROJECT_DIR="${1:-.}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Setting up Claude Questions in: $PROJECT_DIR"

# Change to project directory
cd "$PROJECT_DIR" || { echo -e "${RED}Error: Cannot access directory $PROJECT_DIR${NC}"; exit 1; }

# Download ask-claude.sh if not present
if [ ! -f "./ask-claude.sh" ]; then
    echo -e "${YELLOW}Downloading ask-claude.sh...${NC}"
    wget -q https://raw.githubusercontent.com/karlwaldman/claude-questions/main/ask-claude.sh
    chmod +x ask-claude.sh
    echo -e "${GREEN}✓ ask-claude.sh downloaded${NC}"
else
    echo -e "${YELLOW}! ask-claude.sh already exists, skipping${NC}"
fi

# Handle CLAUDE.md - append if exists, create if not
CLAUDE_SECTION="
## Async Question Handling

When you need user input or encounter decisions requiring human judgment, use the Claude Questions system:

### Quick Usage
\`\`\`bash
# For urgent decisions (deployment, data deletion, security)
./ask-claude.sh urgent \"Title\" \"Detailed question\"

# For high priority (architecture, API changes)  
./ask-claude.sh high \"Title\" \"Question details\"

# For normal questions (clarifications, preferences)
./ask-claude.sh normal \"Title\" \"Question\"

# Check for response
./ask-claude.sh check \"question-filename.md\"
\`\`\`

### Example: Wait for User Response
\`\`\`bash
# Ask and wait for response
FILENAME=\$(date +%Y-%m-%d-%H%M)-decision.md
./ask-claude.sh high \"API Design\" \"REST or GraphQL for orders service?\"

echo \"Waiting for user response...\"
while ! ./ask-claude.sh check \"\$FILENAME\" 2>/dev/null; do
    sleep 30
done

RESPONSE=\$(./ask-claude.sh check \"\$FILENAME\")
echo \"User decided: \$RESPONSE\"
# Continue based on response...
\`\`\`

### When to Use
- Before destructive operations
- Architecture/design decisions  
- When requirements are unclear
- When multiple valid approaches exist

The user will be notified and can respond from any device at https://karlwaldman.github.io/claude-questions
"

if [ -f "./CLAUDE.md" ]; then
    # Check if section already exists
    if grep -q "Async Question Handling" CLAUDE.md; then
        echo -e "${YELLOW}! Claude Questions section already in CLAUDE.md, skipping${NC}"
    else
        echo -e "${YELLOW}Appending to existing CLAUDE.md...${NC}"
        # Create backup
        cp CLAUDE.md CLAUDE.md.backup
        echo "$CLAUDE_SECTION" >> CLAUDE.md
        echo -e "${GREEN}✓ Added Claude Questions section to CLAUDE.md${NC}"
        echo -e "${GREEN}  (Backup saved as CLAUDE.md.backup)${NC}"
    fi
else
    echo -e "${YELLOW}Creating new CLAUDE.md...${NC}"
    cat > CLAUDE.md << 'EOF'
# CLAUDE.md - AI Assistant Instructions

This file provides instructions for Claude when working in this repository.

## Project Overview
[Your existing project info here]

EOF
    echo "$CLAUDE_SECTION" >> CLAUDE.md
    echo -e "${GREEN}✓ Created CLAUDE.md with Claude Questions section${NC}"
fi

# Add to .gitignore if not already there
if [ -f ".gitignore" ]; then
    if ! grep -q "ask-claude.sh" .gitignore 2>/dev/null; then
        echo -e "\n# Claude Questions script" >> .gitignore
        echo "ask-claude.sh" >> .gitignore
        echo -e "${GREEN}✓ Added ask-claude.sh to .gitignore${NC}"
    fi
else
    echo -e "# Claude Questions script\nask-claude.sh" > .gitignore
    echo -e "${GREEN}✓ Created .gitignore with ask-claude.sh${NC}"
fi

# Final check
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Make sure you have environment variables set:"
echo "  export CLAUDE_GITHUB_TOKEN=\"your_github_token\""
echo "  export CLAUDE_REPO=\"karlwaldman/claude-questions\""
echo ""
echo "Claude will now automatically use the question system when needed."