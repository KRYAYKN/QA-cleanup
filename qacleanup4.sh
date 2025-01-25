#!/bin/bash

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

# Step 2: Identify Failed Branches
echo "Identifying failed branches..."
FAILED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail") | .metadata.tags[]' accelq-results.json | sort | uniq)

if [[ -z "$FAILED_BRANCHES" ]]; then
  echo "No failed branches found. QA branch is clean."
  rm -f accelq-results.json
  exit 0
fi

echo "Failed branches to reset: $FAILED_BRANCHES"

# Step 3: Checkout QA Branch
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git pull origin qa || { echo "Failed to pull latest QA branch"; exit 1; }

# Step 4: Create a Temporary Reset Branch
TEMP_BRANCH="temp_reset_branch"
git checkout -b $TEMP_BRANCH || { echo "Failed to create temporary branch"; exit 1; }

# Step 5: Reset Merge Commits for Failed Branches
echo "Resetting merge commits for failed branches..."
for branch in $FAILED_BRANCHES; do
    branch=$(echo "$branch" | xargs)  # Trim spaces
    echo "Processing branch: '$branch'"
    
    # Search for merge commits related to the current branch
    MERGE_COMMITS=$(git log --merges --oneline --all --grep="Merge pull request.*from.*$branch" --format="%H")
    
    if [[ -n "$MERGE_COMMITS" ]]; then
        echo "Found merge commits for branch '$branch':"
        echo "$MERGE_COMMITS"
        
        # Reset to the parent of each merge commit
        for commit in $MERGE_COMMITS; do
            echo "Resetting merge commit: $commit"
            git reset --hard $(git rev-parse $commit^) || {
                echo "Failed to reset merge commit $commit. Please resolve manually."
                exit 1
            }
        done
    else
        echo "No merge commits found for branch '$branch'."
    fi
done

# Step 6: Force Push Temporary Branch to QA
echo "Force pushing temporary reset branch to QA branch..."
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git reset --hard $TEMP_BRANCH || { echo "Failed to hard reset QA branch"; exit 1; }
git push origin qa --force || { echo "Failed to force push to QA branch"; exit 1; }

# Note: Do not delete the temporary branch to allow manual inspection if needed
echo "Temporary branch '$TEMP_BRANCH' has not been deleted for manual inspection."

# Cleanup Temporary Files
rm -f accelq-results.json

echo "Successfully reset all failed branches and updated QA branch."