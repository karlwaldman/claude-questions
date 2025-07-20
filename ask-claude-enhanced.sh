#!/bin/bash

# Enhanced ask-claude script that shows questions in both terminal and web

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Check if required env vars are set
if [ -z "$CLAUDE_GITHUB_TOKEN" ] || [ -z "$CLAUDE_REPO" ]; then
    echo -e "${RED}Error: Set CLAUDE_GITHUB_TOKEN and CLAUDE_REPO environment variables${NC}"
    exit 1
fi

# Function to display question in terminal
display_question() {
    local priority="$1"
    local title="$2"
    local body="$3"
    
    # Set priority color
    case "$priority" in
        URGENT) COLOR=$RED ;;
        HIGH) COLOR=$YELLOW ;;
        *) COLOR=$BLUE ;;
    esac
    
    # Display in terminal with nice formatting
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
    echo ""
}

# Function to ask a question
ask_question() {
    local priority="$1"
    local title="$2"
    local body="$3"
    local filename="$(date +%Y-%m-%d-%H%M)-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g').md"
    
    # Display in terminal first
    display_question "$priority" "$title" "$body"
    
    # Show response options
    echo -e "${BOLD}You can respond in two ways:${NC}"
    echo -e "1. ${GREEN}Terminal:${NC} Type your response below (or press Ctrl+C to skip)"
    echo -e "2. ${GREEN}Mobile/Web:${NC} https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
    echo ""
    
    # Try to get immediate terminal response
    echo -e "${BOLD}Response (press Enter twice when done, Ctrl+C to respond later):${NC}"
    
    # Set trap to handle Ctrl+C gracefully
    trap 'echo ""; echo "Posting question to web..."; post_to_github=true' INT
    
    # Read response (with timeout)
    response=""
    post_to_github=false
    
    # Try to read response with timeout
    if command -v timeout >/dev/null 2>&1; then
        # Use timeout if available
        response=$(timeout 300 bash -c 'response=""; while IFS= read -r line; do [[ -z "$line" ]] && [[ -n "$response" ]] && break; response+="$line"$'\''\n'\''; done; echo "$response"') || post_to_github=true
    else
        # Fallback without timeout
        echo "(Waiting for response... Press Ctrl+C to skip and answer on mobile)"
        while IFS= read -r line; do
            [[ -z "$line" ]] && [[ -n "$response" ]] && break
            response+="$line"$'\n'
        done
    fi
    
    # Reset trap
    trap - INT
    
    if [[ -n "$response" ]] && [[ "$post_to_github" == "false" ]]; then
        # User provided response in terminal
        echo ""
        echo -e "${GREEN}✓ Response received!${NC}"
        echo ""
        echo -e "${BOLD}Your response:${NC}"
        echo "$response"
        echo ""
        
        # Save response locally
        mkdir -p responses
        echo "$response" > "responses/$filename"
        echo -e "${GREEN}✓ Response saved to responses/$filename${NC}"
        
        # Also post to GitHub for record keeping
        post_question_and_response "$filename" "$priority" "$title" "$body" "$response"
    else
        # Post question to GitHub for mobile response
        post_question_only "$filename" "$priority" "$title" "$body"
    fi
    
    echo "$filename"
}

# Function to post question only
post_question_only() {
    local filename="$1"
    local priority="$2"
    local title="$3"  
    local body="$4"
    
    echo -e "${YELLOW}Posting question to GitHub for mobile response...${NC}"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clone the questions repo
    git clone "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions >/dev/null 2>&1
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
    git commit -m "Question: $title" >/dev/null 2>&1
    git push >/dev/null 2>&1
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✓ Question posted!${NC}"
    echo -e "${BOLD}Answer at:${NC} https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)"
    echo ""
}

# Function to post question and response together
post_question_and_response() {
    local filename="$1"
    local priority="$2"
    local title="$3"
    local body="$4"
    local response="$5"
    
    echo -e "${YELLOW}Syncing to GitHub...${NC}"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clone the questions repo
    git clone "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions >/dev/null 2>&1
    cd claude-questions
    
    # Create response file directly (skip question since already answered)
    cat > "responses/$filename" << EOF
$response

---
Answered via terminal at $(date)
EOF
    
    # Commit and push
    git add "responses/$filename"
    git commit -m "Response to: $title (via terminal)" >/dev/null 2>&1
    git push >/dev/null 2>&1
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✓ Synced to GitHub${NC}"
}

# Function to check for response
check_response() {
    local question_file="$1"
    
    # First check local responses
    if [ -f "responses/$question_file" ]; then
        cat "responses/$question_file"
        return 0
    fi
    
    # Then check GitHub
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone "https://${CLAUDE_GITHUB_TOKEN}@github.com/${CLAUDE_REPO}.git" claude-questions >/dev/null 2>&1
    
    if [ -f "claude-questions/responses/$question_file" ]; then
        cat "claude-questions/responses/$question_file"
        
        # Sync to local
        cp "claude-questions/responses/$question_file" "$OLDPWD/responses/" 2>/dev/null
        
        rm -rf "$temp_dir"
        return 0
    else
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to wait for response with visual feedback
wait_for_response() {
    local question_file="$1"
    local check_count=0
    
    echo -e "${YELLOW}Waiting for response...${NC}"
    echo -e "Answer at: ${BOLD}https://$(echo $CLAUDE_REPO | cut -d'/' -f1).github.io/$(echo $CLAUDE_REPO | cut -d'/' -f2)${NC}"
    echo ""
    
    while ! check_response "$question_file" >/dev/null 2>&1; do
        # Animated waiting indicator
        case $((check_count % 4)) in
            0) echo -ne "\r${YELLOW}⠋${NC} Checking for response... ";;
            1) echo -ne "\r${YELLOW}⠙${NC} Checking for response... ";;
            2) echo -ne "\r${YELLOW}⠹${NC} Checking for response... ";;
            3) echo -ne "\r${YELLOW}⠸${NC} Checking for response... ";;
        esac
        
        sleep 5
        ((check_count++))
        
        # Every minute, show how long we've been waiting
        if [ $((check_count % 12)) -eq 0 ]; then
            echo -ne "\r${YELLOW}⏱${NC}  Waiting for $((check_count * 5)) seconds... "
        fi
    done
    
    echo -ne "\r${GREEN}✓${NC} Response received!                    \n"
    echo ""
}

# Handle command line usage
case "$1" in
    urgent|high|normal)
        filename=$(ask_question "${1^^}" "$2" "$3")
        echo -e "${BOLD}Question ID:${NC} $filename"
        ;;
    check)
        if check_response "$2"; then
            exit 0
        else
            echo "No response yet"
            exit 1
        fi
        ;;
    wait)
        wait_for_response "$2"
        check_response "$2"
        ;;
    *)
        echo "Enhanced Claude Questions - Works in terminal AND mobile!"
        echo ""
        echo "Usage:"
        echo "  $0 [urgent|high|normal] \"Title\" \"Body\""
        echo "  $0 check \"question-filename.md\""
        echo "  $0 wait \"question-filename.md\""
        echo ""
        echo "Examples:"
        echo "  $0 urgent \"Delete Database?\" \"Should I proceed with dropping the users table?\""
        echo "  $0 wait \"2025-01-20-1234-delete-database.md\""
        ;;
esac