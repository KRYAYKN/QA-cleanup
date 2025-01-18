#!/bin/bash

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452413"
USER_ID="koray.ayakin@pargesoft.com"

# Step 1: Fetch AccelQ Test Results
echo "Fetching AccelQ test results..."
curl -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
  -H "api_key: ${API_TOKEN}" \
  -H "user_id: ${USER_ID}" \
  -H "Content-Type: application/json" > accelq-results.json
echo "AccelQ test results saved to accelq-results.json"

echo "Identifying failed branches..."
FAILED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail") | .metadata.tags[]' accelq-results.json | sort | uniq)

if [[ -z "$FAILED_BRANCHES" ]]; then
  echo "No failed branches found. QA branch is clean."
  rm -f accelq-results.json
  exit 0
fi

echo "Failed branches to revert: $FAILED_BRANCHES"

