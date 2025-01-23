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

echo "Failed branches to clean: $FAILED_BRANCHES"

# Step 3: Checkout QA Branch
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git pull origin qa || { echo "Failed to pull latest QA branch"; exit 1; }

# Step 4: Create a Temporary Reset Branch
TEMP_BRANCH="temp_reset_branch"
git checkout -b $TEMP_BRANCH || { echo "Failed to create temporary branch"; exit 1; }

# Step 5: Remove Merge Commits for Failed Branches
echo "Removing merge commits for failed branches in temporary branch..."
for branch in $FAILED_BRANCHES; do
    branch=$(echo "$branch" | xargs)  # Trim spaces
    echo "Processing branch: '$branch'"
    
    # Find merge commits for the failed branch
    MERGE_COMMITS=$(git log --merges --oneline --grep="Merge pull request.*from.*$branch" --format="%H")
    
    if [[ -n "$MERGE_COMMITS" ]]; then
        echo "Found merge commits for branch '$branch':"
        echo "$MERGE_COMMITS"
        
        # Remove each merge commit using rebase
        for commit in $MERGE_COMMITS; do
            echo "Rebasing to remove merge commit: $commit"
            git rebase --onto $(git rev-parse $commit^) $commit || {
                echo "Failed to rebase commit $commit. Please resolve manually."
                exit 1
            }
        done
    else
        echo "No merge commits found for branch '$branch'."
    fi

done

# Step 6: Merge Temporary Branch into QA
echo "Merging temporary branch into QA branch..."
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git merge $TEMP_BRANCH --no-ff --no-edit || {
    echo "Conflict occurred while merging changes into QA. Please resolve conflicts manually."
    exit 1
}

# Step 7: Push Changes to QA
echo "Pushing changes to QA branch..."
git push origin qa || { echo "Failed to push to QA branch"; exit 1; }

# Step 8: Cleanup
echo "Cleanup temporary branch and files..."
git branch -D $TEMP_BRANCH
rm -f accelq-results.json

echo "QA branch updated successfully after removing failed branches."
