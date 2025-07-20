#!/bin/bash

# Enhanced ask-claude.sh with status updates and project tracking

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if required env vars are set
if [ -z "$CLAUDE_GITHUB_TOKEN" ] || [ -z "$CLAUDE_REPO" ]; then
    echo -e "${RED}Error: Set CLAUDE_GITHUB_TOKEN and CLAUDE_REPO environment variables${NC}"
    exit 1
fi

# Get project name from current directory
PROJECT_NAME=$(basename "$(pwd)")

case "$1" in
    status)
        # Status update
        message="$2"
        if [ -z "$message" ]; then
            echo "Usage: $0 status \"Your status message\""
            exit 1
        fi
        
        timestamp=$(date '+%Y-%m-%d-%H%M%S')
        filename="${timestamp}-${PROJECT_NAME}-status.md"
        
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        git clone -q "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions 2>/dev/null
        cd claude-questions
        
        mkdir -p status
        cat > "status/$filename" << EOF
---
timestamp: $(date '+%Y-%m-%d %H:%M:%S')
type: status
project: $PROJECT_NAME
---

[$PROJECT_NAME] $message
EOF
        
        git add "status/$filename"
        git commit -m "Status [$PROJECT_NAME]: $(echo "$message" | head -1 | cut -c1-40)..." -q
        git push -q
        
        cd /
        rm -rf "$temp_dir"
        
        echo -e "${GREEN}✓ Status posted for $PROJECT_NAME${NC}"
        ;;
        
    test|urgent|normal|low)
        # Original question functionality with project context
        priority=$1
        title="$2"
        question="$3"
        
        if [ -z "$title" ] || [ -z "$question" ]; then
            echo "Usage: $0 [urgent|normal|low] \"Title\" \"Question\""
            exit 1
        fi
        
        timestamp=$(date '+%Y-%m-%d-%H%M%S')
        safe_title=$(echo "$title" | tr ' ' '-' | tr -cd '[:alnum:]-')
        filename="${timestamp}-${PROJECT_NAME}-${safe_title}.md"
        
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        git clone -q "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions 2>/dev/null
        cd claude-questions
        
        mkdir -p questions
        cat > "questions/$filename" << EOF
---
priority: $priority
title: $title
timestamp: $(date '+%Y-%m-%d %H:%M:%S')
project: $PROJECT_NAME
---

# $title

**Project:** $PROJECT_NAME

$question
EOF
        
        git add "questions/$filename"
        git commit -m "Question [$PROJECT_NAME]: $title" -q
        git push -q
        
        cd /
        rm -rf "$temp_dir"
        
        echo -e "${GREEN}✓ Question posted!${NC}"
        echo -e "${BOLD}Project:${NC} $PROJECT_NAME"
        echo -e "${BOLD}Answer at:${NC} https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
        ;;
        
    check)
        # Check for response with better formatting
        filename="$2"
        response_file="responses/${filename%.md}.md"
        
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone -q "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions 2>/dev/null
        
        if [ -f "claude-questions/$response_file" ]; then
            echo -e "${GREEN}Response received:${NC}"
            echo "---"
            cat "claude-questions/$response_file"
        else
            echo -e "${YELLOW}No response yet.${NC}"
            echo -e "Check: ${BOLD}https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)${NC}"
        fi
        
        cd /
        rm -rf "$temp_dir"
        ;;
        
    list)
        # List recent questions and status updates
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone -q "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions 2>/dev/null
        cd claude-questions
        
        echo -e "${BOLD}Recent Questions:${NC}"
        ls -t questions/*.md 2>/dev/null | grep -v gitkeep | head -5 | while read f; do
            basename "$f"
        done
        
        echo ""
        echo -e "${BOLD}Recent Status Updates:${NC}"
        ls -t status/*.md 2>/dev/null | grep -v gitkeep | head -5 | while read f; do
            basename "$f"
        done
        
        cd /
        rm -rf "$temp_dir"
        ;;
        
    *)
        echo -e "${BOLD}Enhanced Claude Question & Status System${NC}"
        echo ""
        echo "Usage:"
        echo "  $0 status \"Status message\"                    # Post a status update"
        echo "  $0 [urgent|normal|low] \"Title\" \"Question\"    # Ask a question"
        echo "  $0 check \"question-filename.md\"              # Check for response"
        echo "  $0 list                                      # List recent items"
        echo ""
        echo "Current project: ${BOLD}$PROJECT_NAME${NC}"
        echo "Repository: ${BOLD}$CLAUDE_REPO${NC}"
        exit 1
        ;;
esac