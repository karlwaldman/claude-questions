#!/bin/bash

# Check if required env vars are set
if [ -z "$CLAUDE_GITHUB_TOKEN" ] || [ -z "$CLAUDE_REPO" ]; then
    echo "Error: Set CLAUDE_GITHUB_TOKEN and CLAUDE_REPO environment variables"
    exit 1
fi

# Function to ask a question
ask_question() {
    local priority="$1"
    local title="$2"
    local body="$3"
    local filename="$(date +%Y-%m-%d-%H%M)-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g').md"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clone the questions repo
    git clone "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions
    cd claude-questions
    
    # Create question
    cat > "questions/$filename" << EOF
# ${priority}: ${title}

${body}

Instance: $(hostname)
Project: $(basename "$(dirname "$0")")
Time: $(date)
EOF
    
    # Commit and push
    git add "questions/$filename"
    git commit -m "Question: $title"
    git push
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    echo "Question posted! Check: https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
}

# Check for response
check_response() {
    local question_file="$1"
    local response_file="responses/$question_file"
    
    # Clone and check for response
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions >/dev/null 2>&1
    
    if [ -f "claude-questions/$response_file" ]; then
        cat "claude-questions/$response_file"
        rm -rf "$temp_dir"
        return 0
    else
        rm -rf "$temp_dir"
        return 1
    fi
}

# Handle command line usage
case "$1" in
    urgent|high|normal)
        ask_question "${1^^}" "$2" "$3"
        ;;
    check)
        check_response "$2"
        ;;
    *)
        echo "Usage:"
        echo "  $0 [urgent|high|normal] \"Title\" \"Body\""
        echo "  $0 check \"question-filename.md\""
        ;;
esac