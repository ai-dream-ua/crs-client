## CRS client

CRS client is a basic bash script that prepares the required data from git repository and sends it to CRS system

### How to use it

```bash
CRS_API_TOKEN=xxx \
./crs.sh
```

Also, the following parameters can be added:
- `CURRENT_COMMIT_REF` - default `HEAD`
- `BASE_COMMIT_REF` - default `origin/master`
- `CRS_API_BASE_URL` - `http://127.0.0.1:3000`
- `CLIENT_TYPE` - default - `cli`, possible values - `cli`, `github-actions`
- `OUTPUT_FILE_NAME` - default - `crs_response_${TIMESTAMP}.json`

In case of the `github-actions` client type, the following parameters are required: 
- `GITHUB_ACCOUNT_NAME`
- `GITHUB_REPO_NAME`
- `PR_NUMBER`
- `COMMIT_SHA`
- `GITHUB_TOKEN`
