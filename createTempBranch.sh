#!/bin/bash
#This code makes --> PR Check: Checks for an open PR targeting the promotion/qa branch and identifies the feature branch that opened the PR.
#Conflict Check: Verifies if the feature branch has any conflicts with the promotion/qa branch.
#Temp Branch Creation: If no conflicts are found, creates a temporary branch in the format TEMP_feature/xx_branch.
#PR Merge Process:1.Merges the feature branch's PR into the promotion/qa branch.2.Creates a new PR from promotion/qa to the qa branch and merges it.

Merges the feature branch's PR into the promotion/qa branch.
Creates a new PR from promotion/qa to the qa branch and merges it.
#
Conflict Check: Verifies if the feature branch has any conflicts with the promotion/qa branch.

Temp Branch Creation: If no conflicts are found, creates a temporary branch in the format TEMP_feature/xx_branch.

PR Merge Process:

Merges the feature branch's PR into the promotion/qa branch.
Creates a new PR from promotion/qa to the qa branch and merges it.
set -e

# Variables
GITHUB_REPO=${GITHUB_REPO:-"https://github.com/KRYAYKN/QA-cleanup.git"} # Replace with your repository
GITHUB_TOKEN=${GITHUB_TOKEN} # GitHub token from secrets
BASE_BRANCH="promotion/qa" # Target branch for the PR
QA_BRANCH="qa" # QA branch

# Fetch open PRs targeting promotion/qa
echo "Fetching open PRs targeting $BASE_BRANCH..."
PR_INFO=$(gh pr list --base "$BASE_BRANCH" --state open --json headRefName --jq '.[0].headRefName')

if [[ -z "$PR_INFO" ]]; then
  echo "No open PRs found targeting $BASE_BRANCH. Exiting."
  exit 0
fi

FEATURE_BRANCH="$PR_INFO"
TEMP_BRANCH="TEMP_${FEATURE_BRANCH}"

echo "Found open PR from branch: $FEATURE_BRANCH"

# Checkout the repository
echo "Checking out the repository..."
git fetch origin
git checkout "$FEATURE_BRANCH" || git checkout -b "$FEATURE_BRANCH" origin/$FEATURE_BRANCH
git pull origin "$FEATURE_BRANCH"

# Check for conflicts with the base branch
echo "Checking for conflicts with $BASE_BRANCH..."
git fetch origin $BASE_BRANCH
git merge --no-commit --no-ff origin/$BASE_BRANCH || {
  echo "Conflict detected with $BASE_BRANCH. Please resolve manually."
  echo "Conflict resolution link: https://github.com/$GITHUB_REPO/compare/$BASE_BRANCH...$FEATURE_BRANCH"
  exit 1
}

# Create a temporary branch
echo "No conflicts detected. Creating a temporary branch: $TEMP_BRANCH"
git checkout -b "$TEMP_BRANCH"
git push origin "$TEMP_BRANCH"

echo "Temporary branch $TEMP_BRANCH created successfully."

# Merge the PR into promotion/qa
PR_NUMBER=$(gh pr list --base "$BASE_BRANCH" --head "$FEATURE_BRANCH" --state open --json number --jq '.[0].number')
if [[ -n "$PR_NUMBER" ]]; then
  gh pr merge "$PR_NUMBER" --merge --body "Merging $FEATURE_BRANCH into $BASE_BRANCH."
  echo "PR merged successfully into $BASE_BRANCH."
else
  echo "Failed to find the PR for merging into $BASE_BRANCH."
  exit 1
fi

# Create a PR from promotion/qa to QA branch
echo "Creating a PR from $BASE_BRANCH to $QA_BRANCH..."
gh pr create \
  --title "Merge $BASE_BRANCH into $QA_BRANCH" \
  --body "Automated PR from $BASE_BRANCH to $QA_BRANCH." \
  --base "$QA_BRANCH" \
  --head "$BASE_BRANCH"

if [[ $? -eq 0 ]]; then
  echo "PR created successfully from $BASE_BRANCH to $QA_BRANCH."

  # Merge the PR into QA branch
  PR_NUMBER_QA=$(gh pr list --base "$QA_BRANCH" --head "$BASE_BRANCH" --state open --json number --jq '.[0].number')
  if [[ -n "$PR_NUMBER_QA" ]]; then
    gh pr merge "$PR_NUMBER_QA" --merge --body "Merging $BASE_BRANCH into $QA_BRANCH."
    echo "PR merged successfully into $QA_BRANCH."
  else
    echo "Failed to find the PR for merging into $QA_BRANCH."
    exit 1
  fi
else
  echo "Failed to create PR from $BASE_BRANCH to $QA_BRANCH."
  exit 1
fi
