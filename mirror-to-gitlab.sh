#!/bin/bash
# Repository Mirroring Script: GitHub → GitLab
# This script can be used to manually sync the repository from GitHub to GitLab
# For automated mirroring, use GitLab's push mirror feature or GitHub Actions

set -e

# Configuration
GITHUB_REPO="${GITHUB_REPO:-git@github.com:YOUR_USERNAME/YOUR_REPO.git}"
GITLAB_REPO="${GITLAB_REPO:-git@gitlab.com:YOUR_GROUP/YOUR_REPO.git}"
BRANCHES_TO_MIRROR="${BRANCHES_TO_MIRROR:-master main develop}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "Repository Mirroring: GitHub → GitLab"
echo "==========================================${NC}"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo -e "${YELLOW}Not in a git repository. Cloning from GitHub...${NC}"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    git clone --mirror "$GITHUB_REPO" repo.git
    cd repo.git
else
    echo -e "${GREEN}Found git repository${NC}"
    # Fetch all from origin (GitHub)
    echo -e "${YELLOW}Fetching latest changes from GitHub...${NC}"
    git fetch origin --prune
fi

# Add GitLab remote if it doesn't exist
if ! git remote | grep -q gitlab; then
    echo -e "${YELLOW}Adding GitLab remote...${NC}"
    git remote add gitlab "$GITLAB_REPO" || git remote set-url gitlab "$GITLAB_REPO"
else
    echo -e "${GREEN}GitLab remote already configured${NC}"
fi

# Push all branches and tags to GitLab
echo -e "${YELLOW}Pushing to GitLab...${NC}"
if [ -d .git ] && [ ! -f HEAD ]; then
    # This is a bare repository (mirror)
    git push gitlab --mirror
else
    # This is a regular repository
    # Push all branches
    for branch in $BRANCHES_TO_MIRROR; do
        if git show-ref --verify --quiet refs/heads/$branch || git show-ref --verify --quiet refs/remotes/origin/$branch; then
            echo -e "${YELLOW}Pushing branch: $branch${NC}"
            git push gitlab "$branch" || echo -e "${RED}Warning: Failed to push $branch${NC}"
        fi
    done
    
    # Push all tags
    echo -e "${YELLOW}Pushing tags...${NC}"
    git push gitlab --tags || echo -e "${RED}Warning: Failed to push tags${NC}"
fi

echo -e "${GREEN}=========================================="
echo "Mirroring complete!"
echo "==========================================${NC}"

# Cleanup if we created a temp directory
if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    echo -e "${YELLOW}Cleaning up temporary directory...${NC}"
    rm -rf "$TEMP_DIR"
fi

echo ""
echo "For automated mirroring, consider:"
echo "1. GitLab Push Mirror (Settings → Repository → Mirroring)"
echo "2. GitHub Actions workflow (see .github/workflows/mirror-to-gitlab.yml)"
echo "3. Cron job running this script"

