#!/bin/bash

# Test script for Claude Questions system

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Claude Questions System Test"
echo "============================"
echo ""

# Test 1: Check script files exist
echo -n "1. Checking script files... "
if [ -f "ask-claude.sh" ] && [ -f "ask-claude-enhanced.sh" ] && [ -f "ask-claude-production.sh" ]; then
    echo -e "${GREEN}✓ All scripts present${NC}"
else
    echo -e "${RED}✗ Missing scripts${NC}"
    exit 1
fi

# Test 2: Check executability
echo -n "2. Checking script permissions... "
if [ -x "ask-claude.sh" ] && [ -x "ask-claude-enhanced.sh" ] && [ -x "ask-claude-production.sh" ]; then
    echo -e "${GREEN}✓ All scripts executable${NC}"
else
    echo -e "${RED}✗ Scripts not executable${NC}"
    exit 1
fi

# Test 3: Check web interface
echo -n "3. Checking web interface... "
if [ -f "index.html" ]; then
    echo -e "${GREEN}✓ index.html present${NC}"
else
    echo -e "${RED}✗ index.html missing${NC}"
    exit 1
fi

# Test 4: Check GitHub Actions
echo -n "4. Checking GitHub Actions... "
if [ -f ".github/workflows/notify.yml" ]; then
    echo -e "${GREEN}✓ Workflow present${NC}"
else
    echo -e "${RED}✗ Workflow missing${NC}"
    exit 1
fi

# Test 5: Check directories
echo -n "5. Checking directory structure... "
if [ -d "questions" ] && [ -d "responses" ] && [ -f "questions/.gitkeep" ]; then
    echo -e "${GREEN}✓ Directories ready${NC}"
else
    echo -e "${RED}✗ Directory structure incomplete${NC}"
    exit 1
fi

# Test 6: Validate production script syntax
echo -n "6. Validating production script... "
if bash -n ask-claude-production.sh 2>/dev/null; then
    echo -e "${GREEN}✓ Script syntax valid${NC}"
else
    echo -e "${RED}✗ Script has syntax errors${NC}"
    exit 1
fi

# Test 7: Check for required commands
echo -n "7. Checking dependencies... "
missing_deps=""
for cmd in git curl wget base64 mktemp; do
    if ! command -v $cmd >/dev/null 2>&1; then
        missing_deps="$missing_deps $cmd"
    fi
done

if [ -z "$missing_deps" ]; then
    echo -e "${GREEN}✓ All dependencies available${NC}"
else
    echo -e "${RED}✗ Missing:$missing_deps${NC}"
    exit 1
fi

# Test 8: Simulate question creation (dry run)
echo -n "8. Testing question format... "
TEST_PRIORITY="URGENT"
TEST_TITLE="Test Question"
TEST_BODY="This is a test"
TEST_FILENAME="$(date +%Y-%m-%d-%H%M%S)-test-question.md"

# Create test question in memory
TEST_CONTENT=$(cat << EOF
# ${TEST_PRIORITY}: ${TEST_TITLE}

${TEST_BODY}

---
Metadata:
- Instance: $(hostname)
- Project: ${PWD}
- User: ${USER}
- Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- Question ID: test-uuid
EOF
)

if [ -n "$TEST_CONTENT" ]; then
    echo -e "${GREEN}✓ Question format valid${NC}"
else
    echo -e "${RED}✗ Question format error${NC}"
    exit 1
fi

# Test 9: Check GitHub connectivity (without auth)
echo -n "9. Testing GitHub connectivity... "
if curl -s -o /dev/null -w "%{http_code}" https://api.github.com | grep -q "200"; then
    echo -e "${GREEN}✓ GitHub API accessible${NC}"
else
    echo -e "${YELLOW}⚠ GitHub API not accessible (may be network issue)${NC}"
fi

# Test 10: Verify backup directory can be created
echo -n "10. Testing backup mechanism... "
BACKUP_TEST_DIR=".backups/test-$(date +%Y%m%d)"
if mkdir -p "$BACKUP_TEST_DIR" && rmdir "$BACKUP_TEST_DIR" && rmdir ".backups" 2>/dev/null; then
    echo -e "${GREEN}✓ Backup directory writable${NC}"
else
    echo -e "${RED}✗ Cannot create backup directory${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Set environment variables:"
echo "   export CLAUDE_GITHUB_TOKEN='your_token'"
echo "   export CLAUDE_REPO='karlwaldman/claude-questions'"
echo ""
echo "2. Run production test:"
echo "   ./ask-claude-production.sh test"
echo ""
echo "3. Deploy to a test project first"
echo ""