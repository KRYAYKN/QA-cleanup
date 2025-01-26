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

# Cleanup
rm -f accelq-results.json

echo "Completed processing branches."