#!/bin/bash

set -e

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452922"
USER_ID="koray.ayakin@pargesoft.com"

# Step 1: Fetch AccelQ Test Results
echo "Fetching AccelQ test results..."
curl -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
  -H "api_key: ${API_TOKEN}" \
  -H "user_id: ${USER_ID}" \
  -H "Content-Type: application/json" > accelq-results.json
echo "AccelQ test results saved to accelq-results.json"

# Step 2: Identify Failed and Passed Branches
echo "Identifying failed and passed branches..."

# Extract failed branches
FAILED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail") | .metadata.tags[]' accelq-results.json | sort | uniq)

# Extract passed branches
PASSED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "pass") | .metadata.tags[]' accelq-results.json | sort | uniq)

# Check if there are any failed branches
if [[ -z "$FAILED_BRANCHES" ]]; then
  echo "No failed branches found."
else
  echo "Failed branches:"
  echo "$FAILED_BRANCHES"
fi

# Check if there are any passed branches
if [[ -z "$PASSED_BRANCHES" ]]; then
  echo "No passed branches found."
else
  echo "Passed branches:"
  echo "$PASSED_BRANCHES"
fi

# Step 3: Process Passed Branches
STAGING_BRANCH="promotion/staging"
for BRANCH in $PASSED_BRANCHES; do
  TEMP_BRANCH="TEMP_${BRANCH}"
  echo "Processing passed branch: $BRANCH with temp branch: $TEMP_BRANCH"

  # Check if TEMP_BRANCH exists in remote
  if git ls-remote --exit-code --heads origin "$TEMP_BRANCH" > /dev/null; then
    echo "$TEMP_BRANCH exists. Preparing to create a PR to $STAGING_BRANCH..."

    # Create a PR from TEMP_BRANCH to STAGING_BRANCH
    gh pr create \
      --title "Merge $TEMP_BRANCH into $STAGING_BRANCH" \
      --body "Automated PR from $TEMP_BRANCH to $STAGING_BRANCH." \
      --base "$STAGING_BRANCH" \
      --head "$TEMP_BRANCH"

    # Check for conflicts
    PR_NUMBER=$(gh pr list --base "$STAGING_BRANCH" --head "$TEMP_BRANCH" --state open --json number --jq '.[0].number')
    if [[ -n "$PR_NUMBER" ]]; then
      echo "Checking for conflicts in PR #$PR_NUMBER..."
      if gh pr view "$PR_NUMBER" --json mergeable --jq '.mergeable' | grep -q "true"; then
        echo "No conflicts detected. Merging PR #$PR_NUMBER into $STAGING_BRANCH..."
        gh pr merge "$PR_NUMBER" --merge --body "Merging $TEMP_BRANCH into $STAGING_BRANCH."
        echo "PR #$PR_NUMBER merged successfully."
      else
        echo "Conflict detected in PR #$PR_NUMBER. Please resolve manually."
        echo "Conflict resolution link: https://github.com/$(echo $GITHUB_REPO | cut -d'/' -f4,5)/pull/$PR_NUMBER"
      fi
    else
      echo "Failed to create or find PR for $TEMP_BRANCH to $STAGING_BRANCH."
    fi
  else
    echo "$TEMP_BRANCH does not exist in the remote repository. Skipping."
  fi

done

# Cleanup
rm -f accelq-results.json

echo "Completed processing branches."