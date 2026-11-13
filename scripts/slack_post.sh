#!/usr/bin/env bash
# Post a message to #job-hunt as "Job Hunt Bot" (so the user gets notified).
# Usage: scripts/slack_post.sh "message text (Slack mrkdwn)" [thread_ts]
#   thread_ts: optional; replies inside that job's thread (still notifies the user, since it comes from the bot).
# Webhook: $SLACK_WEBHOOK_URL (cloud routine secret) or ~/.config/job-hunt/slack_webhook (local). Never commit it.
set -euo pipefail
url="${SLACK_WEBHOOK_URL:-$(cat ~/.config/job-hunt/slack_webhook 2>/dev/null || true)}"
[ -n "$url" ] || { echo "No Slack webhook configured" >&2; exit 1; }
payload=$(python3 -c 'import json,sys
d={"text": sys.argv[1], "unfurl_links": False}
if len(sys.argv)>2 and sys.argv[2]: d["thread_ts"]=sys.argv[2]
print(json.dumps(d))' "$1" "${2:-}")
curl -sf -X POST -H 'Content-type: application/json' --data "$payload" "$url" >/dev/null && echo posted
