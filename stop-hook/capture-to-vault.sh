#!/usr/bin/env bash
set -euo pipefail

# Stop-hook body. Invoked by claude-code / codex with a JSON event on
# stdin. Writes a session note into ${SHMULISTAN_VAULT}/${SHMULISTAN_INBOX}/.
#
# Required env: SHMULISTAN_VAULT
# Optional env: SHMULISTAN_INBOX (default: 00_Inbox)
# Required argv: runtime label (claude-code | codex)

runtime="${1:?missing runtime arg}"
vault="${SHMULISTAN_VAULT:?SHMULISTAN_VAULT not set}"
inbox="${SHMULISTAN_INBOX:-00_Inbox}"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

ts="$(date -u +%Y%m%d%H%M%S)"
slug="${session_id:0:8}"
[ -z "$slug" ] && slug="anon"
note="${vault}/${inbox}/${ts}-session-${runtime}-${slug}.md"

last_msg=""
if [ -n "$transcript" ] && [ -r "$transcript" ]; then
  last_msg="$(jq -r 'select(.role=="assistant") | .content // ""' "$transcript" 2>/dev/null \
              | tail -n 1 | head -c 2000 || true)"
fi

mkdir -p "$(dirname "$note")"
{
  printf -- '---\n'
  printf 'date: %s\n'        "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'tags: [auto-capture, %s]\n' "$runtime"
  printf 'session_id: %s\n'  "$session_id"
  printf 'cwd: %s\n'         "$cwd"
  printf 'transcript: %s\n'  "$transcript"
  printf -- '---\n\n'
  printf '## Last assistant message\n\n%s\n' "$last_msg"
} > "$note"
