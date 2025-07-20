#!/bin/bash
# Add this to your .bashrc for global claude-status function

# Claude status update function
claude-status() {
    local message="$1"
    local project_name=$(basename "$PWD")
    local timestamp=$(date '+%Y-%m-%d-%H%M%S')
    local filename="${timestamp}-${project_name}-status.md"
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    git clone -q "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions 2>/dev/null
    cd claude-questions
    
    mkdir -p status
    cat > "status/$filename" << EOF
---
timestamp: $(date '+%Y-%m-%d %H:%M:%S')
type: status
project: $project_name
---

[$project_name] $message
EOF
    
    git add "status/$filename"
    git commit -m "Status [$project_name]: $(echo "$message" | head -1 | cut -c1-40)..." -q
    git push -q
    
    cd /
    rm -rf "$temp_dir"
    
    echo "✓ Status posted for $project_name"
}

# Export the function so it's available in subshells
export -f claude-status

# Optional: Create a short alias
alias cs='claude-status'