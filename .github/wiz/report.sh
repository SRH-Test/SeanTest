#!/usr/bin/env bash
# Builds the Wiz PR report from wizcli output in $WIZ_OUT:
#   comment.md            summary comment for the PR
#   review-comments.json  inline review comments for High and Critical code findings
#   sarif-upload.sarif    SARIF with repo-relative URIs for GitHub code scanning
# and writes the Wiz policy verdict to $GITHUB_OUTPUT.
set -euo pipefail

LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${WIZ_OUT:?}" "${REPO:?}" "${HEAD_SHA:?}"
SERVER_URL=${SERVER_URL:-https://github.com}
RUN_URL=${RUN_URL:-}
INLINE_MIN_SEVERITY=HIGH
MAX_ROWS=50
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/null}

JSON="$WIZ_OUT/wiz_result.json"
SARIF="$WIZ_OUT/wiz_result.sarif"

if [ ! -s "$JSON" ] || [ ! -s "$SARIF" ]; then
  {
    echo "<!-- ID: WIZ_SECURITY_SCAN_COMMENT_MARKER -->"
    echo "## 🛡️ Wiz Security Scan"
    echo ""
    echo "❗ **The scan did not complete**, so this pull request has not been checked."
    echo ""
    echo "See the [workflow run]($RUN_URL) for details."
  } > "$WIZ_OUT/comment.md"
  echo '[]' > "$WIZ_OUT/review-comments.json"
  exit 0
fi

jq -n -L "$LIB" \
  --slurpfile wiz "$JSON" --slurpfile sarif "$SARIF" --slurpfile files "$WIZ_OUT/pr_files.json" \
  -f "$LIB/normalize.jq" > "$WIZ_OUT/report.json"

jq -r -L "$LIB" \
  --arg repo "$REPO" --arg sha "$HEAD_SHA" --arg server "$SERVER_URL" --arg run_url "$RUN_URL" \
  --arg inline_min "$INLINE_MIN_SEVERITY" --argjson max_rows "$MAX_ROWS" \
  -f "$LIB/render.jq" "$WIZ_OUT/report.json" > "$WIZ_OUT/comment.md"

jq -c -L "$LIB" --arg min_severity "$INLINE_MIN_SEVERITY" \
  -f "$LIB/review.jq" "$WIZ_OUT/report.json" > "$WIZ_OUT/review-comments.json"

# Code scanning needs repo-relative, URI-encoded paths; Wiz anchors them at file:/// via ROOTPATH.
# The upload step sets the category, so drop Wiz's own automationDetails.
jq '(.runs[] |= del(.originalUriBaseIds, .automationDetails))
    | (.runs[].results[]?.locations[]?.physicalLocation.artifactLocation) |=
        (del(.uriBaseId) | .uri |= (sub("^(file://)?/+"; "") | split("/") | map(@uri) | join("/")))' \
  "$SARIF" > "$WIZ_OUT/sarif-upload.sarif"

VERDICT=$(jq -r '.meta.verdict // ""' "$WIZ_OUT/report.json")
echo "verdict=$VERDICT" >> "$GITHUB_OUTPUT"

jq -r '"Wiz report: \(.sast | length) code, \(.deps | length) dependency, \(.secrets | length) secret findings"' "$WIZ_OUT/report.json"
echo "Inline review comments: $(jq length "$WIZ_OUT/review-comments.json"); verdict: ${VERDICT:-n/a}"
