#!/bin/bash

: "${CRS_API_TOKEN?:CRS_API_TOKEN has to be specified}"

TIMESTAMP=$(date +%s)

CURRENT_COMMIT_REF="${CURRENT_COMMIT_REF:-"HEAD"}"
BASE_COMMIT_REF="${BASE_COMMIT_REF:-"origin/master"}"
CRS_API_URL="${CRS_API_URL:-"http://127.0.0.1:3000/v1/code-review/review-diff"}"
CLIENT_TYPE="${CLIENT_TYPE:-"cli"}"
OUTPUT_FILE_NAME="${OUTPUT_FILE_NAME:-"crs_response_${TIMESTAMP}.json"}"

if [[ "${CLIENT_TYPE}" == "github-actions" ]]
then
  : "${REPO_NAME?:REPO_NAME has to be specified}"
  : "${PR_NUMBER?:PR_NUMBER has to be specified}"
  : "${COMMIT_SHA?:COMMIT_SHA has to be specified}"
  : "${GITHUB_TOKEN?:GITHUB_TOKEN has to be specified}"
fi

PR_TITLE="${PR_TITLE:-}"
PR_DESCRIPTION="${PR_DESCRIPTION:-}"


GIT_DIFF=$(git diff $BASE_COMMIT_REF $CURRENT_COMMIT_REF)

JSON_PAYLOAD=$(jq -n \
    --arg gitdiff "$GIT_DIFF" \
    --arg title "$PR_TITLE" \
    --arg description "$PR_DESCRIPTION" \
    --arg client "$CLIENT_TYPE" \
    '{
      diff: $gitdiff,
      details: {
        pr: {
          title: $title,
          description: $description
        }
      },
      client: $client
    }')

CRS_API_RESPONSE=$(curl -X POST "$CRS_API_URL" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CRS_API_TOKEN}" \
    -d "$JSON_PAYLOAD")

echo $CRS_API_RESPONSE > $OUTPUT_FILE_NAME

echo "Response is saved to file: ${OUTPUT_FILE_NAME}"


if [[ "${CLIENT_TYPE}" == "github-actions" ]]
then
  # Loop over each file and its comments
  jq -c '.commentsForFiles[]' "$OUTPUT_FILE_NAME" | while read -r file_comments; do
    FILE_NAME=$(echo "$file_comments" | jq -r '.fileName')
    echo "Processing $FILE_NAME"

    # Loop over each review comment for the current file
    echo "$file_comments" | jq -c '.comments.reviews[]' | while read -r review; do
      LINE_NUMBER=$(echo "$review" | jq -r '.lineNumber')
      COMMENT=$(echo "$review" | jq -r '.reviewComment')

      echo "Adding comment on line $LINE_NUMBER in file $FILE_NAME: $COMMENT"

      # Create a review comment using GitHub API
      curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -X POST \
        -d "{\"body\": \"$COMMENT\", \"commit_id\": \"$COMMIT_SHA\", \"path\": \"$FILE_NAME\", \"line\": $LINE_NUMBER, \"side\": \"RIGHT\"}" \
        "https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER/comments"
    done
  done
fi
