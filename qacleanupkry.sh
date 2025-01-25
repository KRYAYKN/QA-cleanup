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

echo "Failed branches to revert: $FAILED_BRANCHES"

# Step 3: Find and Remove Merge Commits for Failed Branches
echo "Finding and removing merge commits for failed branches..."
for branch in $FAILED_BRANCHES; do
    branch=$(echo "$branch" | xargs)  # Trim spaces
    echo "Processing branch: '$branch'"

    # Search for merge commits related to the current branch
    MERGE_COMMITS=$(git log qa --merges --grep="Merge pull request.*from.*$branch" --format="%H")

    if [[ -n "$MERGE_COMMITS" ]]; then
        echo "Merge commits for branch '$branch':"
        echo "$MERGE_COMMITS"

        # Remove merge commits one by one
        for commit in $MERGE_COMMITS; do
            echo "Deleting merge commit: $commit"
            git checkout qa || { echo "Failed to checkout qa branch."; exit 1; }
            
            # Reset only the merge commit itself, preserving other changes
            git rebase --onto "$commit^" "$commit" || {
                echo "Failed to rebase commit $commit. Resolve manually."
                exit 1
            }
            echo "Deleted merge commit: $commit"
        done
    else
        echo "No merge commits found for branch '$branch'."
    fi
    
    echo "Finished processing branch: '$branch'"
done

# Cleanup
rm -f accelq-results.json

echo "Completed processing failed branches."
