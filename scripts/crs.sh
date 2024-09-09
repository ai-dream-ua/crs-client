#!/bin/bash

: "${CRS_API_TOKEN?:CRS_API_TOKEN has to be specified}"

TIMESTAMP=$(date +%s)

CURRENT_COMMIT_REF="${CURRENT_COMMIT_REF:-"HEAD"}"
BASE_COMMIT_REF="${BASE_COMMIT_REF:-"origin/master"}"
CRS_API_URL="${CRS_API_URL:-"http://127.0.0.1:3000/v1/code-review/review-diff"}"
CLIENT_TYPE="${CLIENT_TYPE:-"cli"}"
OUTPUT_FILE_NAME="${OUTPUT_FILE_NAME:-"crs_response_${TIMESTAMP}.json"}"

PR_TITLE="${PR_TITLE:-}"
PR_DESCRIPTION="${PR_DESCRIPTION:-}"


GIT_DIFF=$(git diff $BASE_COMMIT_REF $CURRENT_COMMIT_REF)

JSON_PAYLOAD=$(jq -n \
    --arg gitdiff "$GIT_DIFF" \
    --arg title "$PR_TITLE" \
    --arg description "$PR_DESCRIPTION" \
    '{
      diff: $gitdiff,
      details: {
        pr: {
          title: $title,
          description: $description
        }
      },
      client: "cli"
    }')

CRS_API_RESPONSE=$(curl -X POST "$CRS_API_URL" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CRS_API_TOKEN}" \
    -d "$JSON_PAYLOAD")

echo $CRS_API_RESPONSE > "crs_response_${TIMESTAMP}".json

echo "Response is saved to file: ${OUTPUT_FILE_NAME}"
