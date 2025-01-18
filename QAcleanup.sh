#!/bin/bash

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZEM"
EXECUTION_ID="452413"
USER_ID="koray.ayakin@pargesoft.com"

MAX_RETRIES=5  # Maximum retry attempts for API call
WAIT_TIME=10   # Wait time between retries (seconds)

# Step 1: Fetch AccelQ Test Results
echo "Fetching AccelQ test results..."
RETRIES=0
SUCCESS=false

while [[ $RETRIES -lt $MAX_RETRIES ]]; do
    HTTP_STATUS=$(curl -s -o accelq-results.json -w "%{http_code}" -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
      -H "api_key: ${API_TOKEN}" \
      -H "user_id: ${USER_ID}" \
      -H "Content-Type: application/json")
    
    if [[ $HTTP_STATUS -eq 200 && -s accelq-results.json ]]; then
        echo "AccelQ test results fetched successfully."
        SUCCESS=true
        break
    else
        echo "Failed to fetch test results (HTTP Status: $HTTP_STATUS). Retrying in $WAIT_TIME seconds... ($((RETRIES + 1))/$MAX_RETRIES)"
        sleep $WAIT_TIME
        ((RETRIES++))
    fi
done

if [[ $SUCCESS == false ]]; then
    echo "Failed to fetch AccelQ test results after $MAX_RETRIES attempts. Exiting."
    exit 1
fi

# Step 2: Identify Failed Branches
echo "Identifying failed branches..."
FAILED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail") | .metadata.tags[]' accelq-results.json | sort | uniq)

if [[ -z "$FAILED_BRANCHES" ]]; then
  echo "No failed branches found. QA branch is clean."
  rm -f accelq-results.json
  exit 0
fi

echo "Failed branches to revert: $FAILED_BRANCHES"

# Step 3: Checkout QA Branch
echo "Checking out QA branch..."
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git pull origin qa || { echo "Failed to pull latest QA branch"; exit 1; }

# Step 4: Create temporary branch for reverting
echo "Creating temporary branch for reverting operations..."
git checkout -b temp_revert_branch || { echo "Failed to create temporary branch"; exit 1; }

# Step 5: Find and revert merge commits from failed branches
for branch in $FAILED_BRANCHES; do
    echo "Processing failed branch: $branch"
    
    # Find merge commit of this feature branch into QA
    MERGE_COMMIT=$(git log --merges --grep="$branch" --format="%H")
    
    if [[ -n "$MERGE_COMMIT" ]]; then
        echo "Found merge commit for $branch: $MERGE_COMMIT"
        
        # Create revert commit with descriptive message
        git revert -m 1 "$MERGE_COMMIT" --no-edit || {
            echo "Conflict occurred while reverting $branch"
            echo "Please resolve conflicts manually and then continue"
            exit 1
        }
    else
        echo "No merge commit found for branch $branch"
        # Look for direct commits if no merge commit found
        DIRECT_COMMITS=$(git log --grep="$branch" --format="%H")
        if [[ -n "$DIRECT_COMMITS" ]]; then
            echo "Found direct commits for $branch"
            for commit in $DIRECT_COMMITS; do
                git revert "$commit" --no-edit || {
                    echo "Conflict occurred while reverting commit $commit"
                    echo "Please resolve conflicts manually and then continue"
                    exit 1
                }
            done
        fi
    fi
done

# Step 6: If all reverts successful, update QA branch
echo "Updating QA branch..."
git checkout qa
git merge temp_revert_branch || { 
    echo "Failed to merge revert changes into QA"
    echo "Please resolve any conflicts and merge manually"
    exit 1
}

# Step 7: Push changes
echo "Pushing changes to remote..."
git push origin qa || { echo "Failed to push to QA branch"; exit 1; }

# Cleanup
git branch -D temp_revert_branch
rm -f accelq-results.json

echo "QA branch cleanup completed successfully"
