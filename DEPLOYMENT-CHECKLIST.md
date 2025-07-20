# Claude Questions Deployment Checklist

## Pre-Deployment Verification ✓

### System Requirements
- [x] Git installed and configured
- [x] GitHub token with repo access
- [x] curl, wget, base64, mktemp available
- [x] Web interface deployed to GitHub Pages

### Security Checks
- [x] Token validation in place
- [x] No tokens in command history
- [x] Secure temp directory usage
- [x] .gitignore includes ask-claude.sh

### Safety Mechanisms
- [x] File locking to prevent race conditions
- [x] Automatic backups before operations
- [x] Retry logic for network failures
- [x] .gitkeep protection

## Deployment Steps

### 1. Test Project First
```bash
# Create a test project
mkdir test-claude-questions
cd test-claude-questions
git init

# Run setup
curl -s https://raw.githubusercontent.com/karlwaldman/claude-questions/main/setup-claude-questions.sh | bash
```

### 2. Verify Environment
```bash
# Check variables are set
echo $CLAUDE_GITHUB_TOKEN
echo $CLAUDE_REPO

# Run built-in test
./ask-claude.sh test
```

### 3. Test Question Flow
```bash
# Create test question
./ask-claude.sh normal "Test" "Is the system working?"

# Check web interface
# Answer the question
# Verify response received
```

### 4. Production Deployment
```bash
# In your actual project
cd /path/to/your/project

# Backup existing CLAUDE.md if present
[ -f CLAUDE.md ] && cp CLAUDE.md CLAUDE.md.backup

# Run setup
./setup-claude-questions.sh .

# Verify CLAUDE.md was updated correctly
```

## Rollback Procedure

If issues occur:

```bash
# 1. Restore CLAUDE.md
[ -f CLAUDE.md.backup ] && mv CLAUDE.md.backup CLAUDE.md

# 2. Remove ask-claude.sh
rm -f ask-claude.sh

# 3. Remove from .gitignore
sed -i '/ask-claude.sh/d' .gitignore

# 4. Clear any local cache/logs
rm -rf .cache .backups claude-questions.log
```

## Known Limitations

1. **API Rate Limits**: 5000 requests/hour per token
2. **File Size**: GitHub API limits to 1MB per file
3. **Concurrent Users**: Lock timeout of 30 seconds
4. **Network Dependencies**: Requires internet connection

## Monitoring

Check system health:
```bash
# View logs
tail -f claude-questions.log

# Check GitHub API status
curl -s https://api.github.com/rate_limit -H "Authorization: token $CLAUDE_GITHUB_TOKEN" | jq .

# List recent questions
ls -la questions/

# List recent responses  
ls -la responses/
```

## Support

- Issues: https://github.com/karlwaldman/claude-questions/issues
- Web Interface: https://karlwaldman.github.io/claude-questions

## Version

Current: 1.0.0 (Production Ready)
- Basic: ask-claude.sh
- Enhanced: ask-claude-enhanced.sh  
- Production: ask-claude-production.sh (RECOMMENDED)