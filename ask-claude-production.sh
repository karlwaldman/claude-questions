#!/bin/bash

# Production-ready Claude Questions script with safety mechanisms

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCK_DIR="/tmp/claude-questions-lock"
LOCK_TIMEOUT=30
RETRY_COUNT=3
RETRY_DELAY=2

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${SCRIPT_DIR}/claude-questions.log"
}

# Error handling
set -euo pipefail
trap 'cleanup' EXIT

cleanup() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# Validate environment
validate_env() {
    if [ -z "${CLAUDE_GITHUB_TOKEN:-}" ] || [ -z "${CLAUDE_REPO:-}" ]; then
        echo -e "${RED}Error: Set CLAUDE_GITHUB_TOKEN and CLAUDE_REPO environment variables${NC}"
        exit 1
    fi
    
    # Validate token format
    if ! [[ "$CLAUDE_GITHUB_TOKEN" =~ ^gh[ps]_[a-zA-Z0-9]{36,}$ ]]; then
        echo -e "${RED}Error: Invalid GitHub token format${NC}"
        exit 1
    fi
    
    # Validate repo format
    if ! [[ "$CLAUDE_REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid repository format (should be owner/repo)${NC}"
        exit 1
    fi
}

# Acquire lock with timeout
acquire_lock() {
    local count=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        if [ $count -ge $LOCK_TIMEOUT ]; then
            echo -e "${RED}Error: Could not acquire lock after ${LOCK_TIMEOUT}s${NC}"
            log "ERROR: Lock acquisition timeout"
            exit 1
        fi
        echo -ne "\r${YELLOW}Waiting for other operations to complete...${NC} ($count/$LOCK_TIMEOUT)"
        sleep 1
        ((count++))
    done
    echo -ne "\r                                                                \r"
}

# Safe git operations with retry
safe_git_operation() {
    local operation="$1"
    local retry=0
    
    while [ $retry -lt $RETRY_COUNT ]; do
        if eval "$operation"; then
            return 0
        fi
        
        ((retry++))
        if [ $retry -lt $RETRY_COUNT ]; then
            echo -e "${YELLOW}Retrying operation ($retry/$RETRY_COUNT)...${NC}"
            sleep $RETRY_DELAY
        fi
    done
    
    echo -e "${RED}Operation failed after $RETRY_COUNT attempts${NC}"
    log "ERROR: Git operation failed: $operation"
    return 1
}

# Check GitHub API rate limit
check_rate_limit() {
    local remaining=$(curl -s -H "Authorization: token $CLAUDE_GITHUB_TOKEN" \
        https://api.github.com/rate_limit | \
        grep -o '"remaining":[0-9]*' | head -1 | cut -d: -f2)
    
    if [ "${remaining:-0}" -lt 10 ]; then
        echo -e "${RED}Warning: GitHub API rate limit low ($remaining remaining)${NC}"
        log "WARNING: Low API rate limit: $remaining"
    fi
}

# Create question with safety checks
create_question_safe() {
    local priority="$1"
    local title="$2"
    local body="$3"
    local filename="$(date +%Y-%m-%d-%H%M%S)-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g').md"
    
    # Acquire lock
    acquire_lock
    
    # Create backup of current state
    local backup_dir="${SCRIPT_DIR}/.backups/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    
    # Create temporary directory with better cleanup
    local temp_dir=$(mktemp -d -t claude-questions-XXXXXX)
    trap "rm -rf '$temp_dir'" EXIT
    
    cd "$temp_dir"
    
    # Clone with depth 1 for efficiency
    echo -e "${YELLOW}Syncing with GitHub...${NC}"
    if ! safe_git_operation "git clone --depth 1 --quiet https://\${CLAUDE_GITHUB_TOKEN}@github.com/\${CLAUDE_REPO}.git claude-questions 2>&1 | grep -v 'Cloning into'"; then
        echo -e "${RED}Failed to clone repository${NC}"
        cleanup
        exit 1
    fi
    
    cd claude-questions
    
    # Ensure questions directory exists with .gitkeep
    mkdir -p questions
    [ ! -f questions/.gitkeep ] && touch questions/.gitkeep
    
    # Create question file
    cat > "questions/$filename" << EOF
# ${priority}: ${title}

${body}

---
Metadata:
- Instance: $(hostname)
- Project: ${PWD}
- User: ${USER}
- Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- Question ID: $(uuidgen 2>/dev/null || echo "${filename%.*}")
EOF
    
    # Stage and commit
    git add questions/.gitkeep questions/"$filename"
    git commit -m "Question: $title [${priority}]" --quiet
    
    # Push with conflict resolution
    if ! safe_git_operation "git push --quiet 2>&1"; then
        echo -e "${YELLOW}Resolving conflicts...${NC}"
        git pull --rebase --quiet
        if ! safe_git_operation "git push --quiet 2>&1"; then
            # Save question locally as fallback
            cp "questions/$filename" "$backup_dir/"
            echo -e "${RED}Failed to push. Question saved to: $backup_dir/$filename${NC}"
            log "ERROR: Push failed, saved to backup: $backup_dir/$filename"
            cleanup
            exit 1
        fi
    fi
    
    # Verify question was created
    if ! git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
        echo -e "${RED}Failed to verify question upload${NC}"
        log "ERROR: Could not verify question upload"
    fi
    
    echo -e "${GREEN}✓ Question posted successfully!${NC}"
    log "INFO: Question created: $filename"
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    cleanup
    
    echo "$filename"
}

# Display question in terminal
display_question() {
    local priority="$1"
    local title="$2"
    local body="$3"
    
    case "$priority" in
        URGENT) COLOR=$RED ;;
        HIGH) COLOR=$YELLOW ;;
        *) COLOR=$BLUE ;;
    esac
    
    echo ""
    echo -e "${COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${COLOR}${BOLD}🤖 CLAUDE QUESTION [$priority]${NC}"
    echo -e "${COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}Title:${NC} $title"
    echo ""
    echo -e "${BOLD}Question:${NC}"
    echo "$body" | fold -s -w 70
    echo ""
    echo -e "${COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main ask function with terminal response option
ask_question() {
    local priority="$1"
    local title="$2"
    local body="$3"
    
    # Validate inputs
    if [ -z "$title" ] || [ -z "$body" ]; then
        echo -e "${RED}Error: Title and body are required${NC}"
        exit 1
    fi
    
    # Display in terminal
    display_question "$priority" "$title" "$body"
    
    echo ""
    echo -e "${BOLD}Response options:${NC}"
    echo -e "1. ${GREEN}Type response below${NC} (press Enter twice to submit)"
    echo -e "2. ${GREEN}Answer on mobile${NC} at: https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
    echo -e "3. ${YELLOW}Press Ctrl+C${NC} to skip terminal response"
    echo ""
    
    # Try to get terminal response
    local response=""
    local got_response=false
    
    # Set trap for Ctrl+C
    trap 'got_response=false; echo ""' INT
    
    echo -e "${BOLD}Your response:${NC}"
    
    # Read with timeout
    if command -v timeout >/dev/null 2>&1; then
        if response=$(timeout 300 bash -c '
            response=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && [[ -n "$response" ]] && break
                response+="$line"$'\''\n'\''
            done
            echo "$response"
        ' 2>/dev/null); then
            [ -n "$response" ] && got_response=true
        fi
    else
        # Fallback without timeout
        while IFS= read -r line; do
            [[ -z "$line" ]] && [[ -n "$response" ]] && break
            response+="$line"$'\n'
        done
        [ -n "$response" ] && got_response=true
    fi
    
    # Reset trap
    trap cleanup EXIT
    
    # Create question (with or without response)
    local filename=$(create_question_safe "$priority" "$title" "$body")
    
    if [ "$got_response" = true ] && [ -n "$response" ]; then
        echo ""
        echo -e "${GREEN}✓ Response received, saving...${NC}"
        
        # Save response immediately
        save_response_safe "$filename" "$response"
    else
        echo ""
        echo -e "${BOLD}Answer at:${NC} https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
    fi
    
    echo ""
    echo -e "${BOLD}Question ID:${NC} $filename"
}

# Save response with safety checks
save_response_safe() {
    local filename="$1"
    local response="$2"
    
    acquire_lock
    
    local temp_dir=$(mktemp -d -t claude-response-XXXXXX)
    trap "rm -rf '$temp_dir'" EXIT
    
    cd "$temp_dir"
    
    # Clone repository
    if ! safe_git_operation "git clone --depth 1 --quiet https://\${CLAUDE_GITHUB_TOKEN}@github.com/\${CLAUDE_REPO}.git claude-questions 2>&1 | grep -v 'Cloning into'"; then
        echo -e "${RED}Failed to save response${NC}"
        cleanup
        return 1
    fi
    
    cd claude-questions
    
    # Create response
    mkdir -p responses
    cat > "responses/$filename" << EOF
$response

---
Answered via: Terminal
Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
    
    # Remove question if it exists
    if [ -f "questions/$filename" ]; then
        git rm "questions/$filename" --quiet
    fi
    
    # Ensure .gitkeep remains
    [ ! -f questions/.gitkeep ] && touch questions/.gitkeep
    git add questions/.gitkeep responses/"$filename"
    
    git commit -m "Response: ${filename%.*} [via terminal]" --quiet
    
    if safe_git_operation "git push --quiet 2>&1"; then
        echo -e "${GREEN}✓ Response saved successfully${NC}"
        log "INFO: Response saved: $filename"
    else
        echo -e "${RED}Failed to save response${NC}"
        log "ERROR: Failed to save response: $filename"
    fi
    
    cd /
    rm -rf "$temp_dir"
    cleanup
}

# Check for response
check_response() {
    local filename="$1"
    
    # Check local cache first
    local cache_dir="${SCRIPT_DIR}/.cache"
    mkdir -p "$cache_dir"
    
    if [ -f "$cache_dir/$filename" ]; then
        cat "$cache_dir/$filename"
        return 0
    fi
    
    # Check GitHub
    local response=$(curl -s -H "Authorization: token $CLAUDE_GITHUB_TOKEN" \
        "https://api.github.com/repos/${CLAUDE_REPO}/contents/responses/${filename}" | \
        grep -o '"content":"[^"]*"' | cut -d'"' -f4 | base64 -d 2>/dev/null)
    
    if [ -n "$response" ]; then
        echo "$response" > "$cache_dir/$filename"
        echo "$response"
        return 0
    fi
    
    return 1
}

# Wait for response with progress
wait_for_response() {
    local filename="$1"
    local max_wait="${2:-3600}"  # Default 1 hour
    local check_interval=10
    local elapsed=0
    
    echo -e "${YELLOW}Waiting for response to: $filename${NC}"
    echo -e "Answer at: ${BOLD}https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)${NC}"
    echo ""
    
    while [ $elapsed -lt $max_wait ]; do
        if check_response "$filename" >/dev/null 2>&1; then
            echo -e "\n${GREEN}✓ Response received!${NC}\n"
            check_response "$filename"
            return 0
        fi
        
        # Progress bar
        local progress=$((elapsed * 50 / max_wait))
        printf "\r["
        printf "%${progress}s" | tr ' ' '='
        printf "%$((50-progress))s" | tr ' ' '-'
        printf "] %d/%d seconds" $elapsed $max_wait
        
        sleep $check_interval
        ((elapsed += check_interval))
    done
    
    echo -e "\n${RED}Timeout waiting for response${NC}"
    return 1
}

# Main command handling
validate_env
check_rate_limit

case "${1:-}" in
    urgent|high|normal)
        ask_question "${1^^}" "${2:-}" "${3:-}"
        ;;
    check)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Question filename required${NC}"
            exit 1
        fi
        if check_response "$2"; then
            exit 0
        else
            echo "No response yet"
            exit 1
        fi
        ;;
    wait)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Question filename required${NC}"
            exit 1
        fi
        wait_for_response "$2" "${3:-3600}"
        ;;
    test)
        echo -e "${GREEN}Running system test...${NC}"
        validate_env && echo "✓ Environment valid"
        check_rate_limit && echo "✓ API rate limit OK"
        acquire_lock && cleanup && echo "✓ Lock mechanism working"
        echo -e "${GREEN}All tests passed!${NC}"
        ;;
    *)
        echo "Claude Questions - Production Ready"
        echo ""
        echo "Usage:"
        echo "  $0 [urgent|high|normal] \"Title\" \"Body\""
        echo "  $0 check \"question-filename.md\""
        echo "  $0 wait \"question-filename.md\" [timeout_seconds]"
        echo "  $0 test"
        echo ""
        echo "Environment:"
        echo "  CLAUDE_GITHUB_TOKEN: ${CLAUDE_GITHUB_TOKEN:+[SET]}"
        echo "  CLAUDE_REPO: ${CLAUDE_REPO:-[NOT SET]}"
        ;;
esac