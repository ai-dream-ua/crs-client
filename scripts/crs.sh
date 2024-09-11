#!/bin/bash

: "${CRS_API_TOKEN?:CRS_API_TOKEN has to be specified}"

TIMESTAMP=$(date +%s)

BASE_BRANCH_NAME="${BASE_BRANCH_NAME:-"master"}"
CURRENT_COMMIT_REF="${CURRENT_COMMIT_REF:-"HEAD"}"
BASE_COMMIT_REF="${BASE_COMMIT_REF:-"origin/${BASE_BRANCH_NAME}"}"
CRS_API_BASE_URL="${CRS_API_BASE_URL:-"crs-api.e-post.kiev.ua:3000"}"
CLIENT_TYPE="${CLIENT_TYPE:-"cli"}"
OUTPUT_FILE_NAME="${OUTPUT_FILE_NAME:-"crs_response_${TIMESTAMP}.json"}"

if [[ "${CLIENT_TYPE}" == "github-actions" ]]
then
  : "${GITHUB_ACCOUNT_NAME?:GITHUB_ACCOUNT_NAME has to be specified}"
  : "${GITHUB_REPO_NAME?:GITHUB_REPO_NAME has to be specified}"
  : "${PR_NUMBER?:PR_NUMBER has to be specified}"
  : "${COMMIT_SHA?:COMMIT_SHA has to be specified}"
  : "${GITHUB_TOKEN?:GITHUB_TOKEN has to be specified}"
fi

PR_TITLE="${PR_TITLE:-}"
PR_DESCRIPTION="${PR_DESCRIPTION:-}"

echo "Running git diff for: BASE_COMMIT_REF=$BASE_COMMIT_REF CURRENT_COMMIT_REF=$CURRENT_COMMIT_REF"
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

CRS_API_RESPONSE=$(curl -s -X POST "$CRS_API_BASE_URL/v1/code-review/review-diff" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CRS_API_TOKEN}" \
    -d "$JSON_PAYLOAD")

echo $CRS_API_RESPONSE > $OUTPUT_FILE_NAME

echo "Response is saved to file: ${OUTPUT_FILE_NAME}"

cat $OUTPUT_FILE_NAME

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

      # https://docs.github.com/en/rest/pulls/comments?apiVersion=2022-11-28#create-a-review-comment-for-a-pull-request
      curl -L \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/${GITHUB_ACCOUNT_NAME}/${GITHUB_REPO_NAME}/pulls/${PR_NUMBER}/comments \
        -d "{\"body\": \"${COMMENT}\", \"commit_id\": \"$COMMIT_SHA\", \"path\": \"$FILE_NAME\", \"line\": $LINE_NUMBER, \"side\": \"RIGHT\"}"
          done
  done
fi
