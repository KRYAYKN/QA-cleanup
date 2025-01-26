#!/bin/bash

set -e

# Variables
GITHUB_REPO=${GITHUB_REPO:-"https://github.com/KRYAYKN/QA-cleanup.git"} # Replace with your repository
GITHUB_TOKEN=${GITHUB_TOKEN} # GitHub token from secrets
BASE_BRANCH="promotion/qa" # Target branch for the PR
FEATURE_BRANCH=${1:-} # Feature branch passed as the first argument
TEMP_BRANCH="TEMP_${FEATURE_BRANCH}" # Temporary branch name

# Validate inputs
if [[ -z "$FEATURE_BRANCH" ]]; then
  echo "Error: Feature branch name is required as an argument."
  exit 1
fi

# Checkout the repository
echo "Checking out the repository..."
git fetch origin
git checkout -b "$FEATURE_BRANCH" origin/$FEATURE_BRANCH
git pull origin $FEATURE_BRANCH

echo "Creating a temporary branch: $TEMP_BRANCH"
git checkout -b "$TEMP_BRANCH"
git push origin "$TEMP_BRANCH"

# Check for conflicts with the base branch
echo "Checking for conflicts with $BASE_BRANCH..."
git fetch origin $BASE_BRANCH
git merge --no-commit --no-ff origin/$BASE_BRANCH || {
  echo "Conflict detected with $BASE_BRANCH. Please resolve manually."
  echo "Conflict resolution link: https://github.com/$GITHUB_REPO/compare/$BASE_BRANCH...$FEATURE_BRANCH"
  exit 1
}

echo "No conflicts detected. Creating a PR from $TEMP_BRANCH to $BASE_BRANCH..."

# Create a PR using GitHub CLI
gh pr create \
  --title "Merge $TEMP_BRANCH into $BASE_BRANCH" \
  --body "Automated PR from $TEMP_BRANCH to $BASE_BRANCH." \
  --base "$BASE_BRANCH" \
  --head "$TEMP_BRANCH"

echo "PR created successfully. Check the PR here: https://github.com/$GITHUB_REPO/compare/$BASE_BRANCH...$TEMP_BRANCH"
