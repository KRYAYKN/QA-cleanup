#!/bin/bash

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452413"
USER_ID="koray.ayakin@pargesoft.com"

MAX_RETRIES=5
WAIT_TIME=10

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
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git pull origin qa || { echo "Failed to pull latest QA branch"; exit 1; }

# Step 4: Create temporary branch for reverting
git checkout -b temp_revert_branch || { echo "Failed to create temporary branch"; exit 1; }

# Step 5: Find and revert merge commits or direct commits
for branch in $FAILED_BRANCHES; do
    echo "Processing failed branch: $branch"
    
    # Debug merge commits
    echo "Searching for merge commits for $branch..."
    git log --merges --oneline --grep="$branch"

    # Find merge commits
    MERGE_COMMITS=$(git log --merges --oneline --all --grep="Merge pull request.*from.*$branch" --format="%H")

    echo "failed branches commits: $MERGE_COMMİTS"