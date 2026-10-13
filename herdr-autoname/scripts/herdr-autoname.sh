#!/bin/sh
# Herdr auto-name hook.
#
# Keeps the Herdr agent name tracking the session's CURRENT PHASE of work, not
# its opening request: whiteboard -> implementation -> review-1 ->
# review-1-fixes -> review-2 ... The name shows through the `agent` token in
# the sidebar, so a glance at the sidebar says what each agent is doing right
# now. The workspace name (renamews) carries the overall subject, so the phase
# is all this needs to express.
#
# Two triggers, one code path:
#   UserPromptSubmit - renames while a long turn is still running, so the name
#                      is right well before the turn ends.
#   Stop             - catches phases that start WITHOUT a prompt from the user:
#                      a looped skill finishing one review round and spawning
#                      the next, remediation beginning after a confirmation, etc.
#
# How it stays fast: the label comes from a stripped-down headless Claude call
# (no MCP servers, replaced system prompt, no tools), which takes several
# seconds. So the hook does NOT do that inline; it detaches a worker and
# returns at once.
#
# No stored state: the phase is read off the transcript tail each time, which
# already carries which round the session is in. A manual rename is transient
# by design - the next trigger relabels from the transcript.
#
# Silent & safe: hook mode never prints to stdout (UserPromptSubmit stdout is
# injected into the model's context) and never fails the turn. Because every
# failure path here is a silent `exit 0`, set HERDR_AUTONAME_DEBUG=1 to trace
# why nothing happened; the log lands in $TMPDIR/herdr-autoname.log.

set -u

# Transcript flattening lives in a sibling script so it can be run on its own:
#   ./herdr-autoname-evidence.py ~/.claude/projects/<p>/<session>.jsonl
# shows exactly what the labeller is being handed.
EVIDENCE_SCRIPT="$(dirname "$0")/herdr-autoname-evidence.py"

# Herdr agent names must match [a-z][a-z0-9_-]{0,31}.
MAX_NAME=32
MAX_LABEL=28        # leaves room to append a pane suffix when a name collides
MAX_REPLY_CHARS=60  # beyond this the model wrote prose, not a label

# Sonnet by default: on a real transcript tail Haiku read a meta session as
# "testing" where Sonnet read "implementation", and Sonnet answered faster.
# Override to trade accuracy for cost:
#   HERDR_AUTONAME_MODEL=claude-haiku-4-5-20251001
MODEL="${HERDR_AUTONAME_MODEL:-claude-sonnet-5}"

# Opt-in tracing. The `return 0` matters: with debugging off the `[ -n ]` test
# fails, so a `log` call that ends a branch would return non-zero.
log() {
  [ -n "${HERDR_AUTONAME_DEBUG:-}" ] &&
    printf '%s %s\n' "$(date +%H:%M:%S)" "$*" \
      >>"${TMPDIR:-/tmp}/herdr-autoname.log"
  return 0
}

# slugify <maxlen> - stdin to a valid Herdr agent name, or nothing. A leading
# digit takes an `x-` prefix so the result always starts with a letter. Every
# name this hook sends to Herdr comes through here.
slugify() {
  tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' '-' \
    | tr -s '-' \
    | sed -e 's/^-*//' -e 's/-*$//' -e 's/^[0-9]/x-&/' \
    | cut -c"1-$1" \
    | sed -e 's/-*$//'
}

# --------------------------------------------------------------------------
# Hook mode: fast, non-blocking. Validates, then detaches the worker.
# Registered for both UserPromptSubmit and Stop; .prompt is empty on Stop.
# --------------------------------------------------------------------------
if [ "${1:-hook}" != "__worker" ]; then
  hook_input="$(cat 2>/dev/null || true)"

  [ "${HERDR_ENV:-}" = "1" ] || { log "not running under herdr"; exit 0; }
  [ -z "${HERDR_AUTONAME_CHILD:-}" ] || { log "inside the labeller child"; exit 0; }
  [ -n "${HERDR_PANE_ID:-}" ] || { log "no HERDR_PANE_ID"; exit 0; }

  # Hard requirements, checked once here so the worker can assume them.
  # Running without any of these is worse than doing nothing: with no python3
  # there is no transcript evidence, and the label would come from the
  # in-flight prompt alone, which names the latest request rather than the
  # session's phase.
  for dep in herdr jq python3 claude; do
    command -v "$dep" >/dev/null 2>&1 || { log "missing dependency: $dep"; exit 0; }
  done
  [ -r "$EVIDENCE_SCRIPT" ] || { log "cannot read $EVIDENCE_SCRIPT"; exit 0; }

  case "$hook_input" in
    *'"agent_id"'*) log "subagent turn, not the session's phase"; exit 0 ;;
  esac

  prompt="$(printf '%s' "$hook_input" | jq -r '.prompt // empty' 2>/dev/null || true)"
  transcript_path="$(printf '%s' "$hook_input" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
  # Enough for intent, and keeps the env block small.
  prompt="$(printf '%s' "$prompt" | head -c 800)"
  [ -n "$prompt" ] || [ -n "$transcript_path" ] ||
    { log "no prompt or transcript"; exit 0; }

  # Detach so the turn is never blocked. The subshell + nohup double form
  # reparents the job away from this short-lived hook process. Register this
  # hook by absolute path: "$0" is re-exec'd here and resolved at
  # EVIDENCE_SCRIPT above.
  ( HERDR_AUTONAME_PANE_ID="$HERDR_PANE_ID" \
    HERDR_AUTONAME_PROMPT="$prompt" \
    HERDR_AUTONAME_TRANSCRIPT_PATH="$transcript_path" \
      nohup sh "$0" __worker >/dev/null 2>&1 & )

  exit 0
fi

# --------------------------------------------------------------------------
# Worker mode: runs detached in the background, and may take a while.
# --------------------------------------------------------------------------
pane_id="${HERDR_AUTONAME_PANE_ID:-}"
transcript_path="${HERDR_AUTONAME_TRANSCRIPT_PATH:-}"
prompt="${HERDR_AUTONAME_PROMPT:-}"
[ -n "$pane_id" ] || exit 0

# Serialize workers for this pane. Two triggers close together can otherwise
# overlap and let an older, staler label land last. Lock is advisory and
# self-healing: anything older than 2min is treated as abandoned (a worker
# killed before its trap ran must not mute auto-naming for the session).
# -mmin must be an integer: BSD find and bfs both reject +1.5.
lock_dir="${TMPDIR:-/tmp}/herdr-autoname-$(printf '%s' "$pane_id" | tr -c 'a-zA-Z0-9' '-').lock"
if [ -d "$lock_dir" ]; then
  if [ -z "$(find "$lock_dir" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    log "$pane_id: a worker is mid-flight, dropping this trigger"
    exit 0
  fi
  rmdir "$lock_dir" 2>/dev/null || true
fi
mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT HUP INT TERM

current_name="$(herdr agent get "$pane_id" 2>/dev/null \
  | jq -r '.result.agent.name // empty' 2>/dev/null || true)"

# ---- Evidence: the tail of the transcript, flattened to labelled lines ----
# `-I` keeps the child from importing out of the session's working directory,
# where a stray json.py would otherwise shadow the stdlib.
evidence=""
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ]; then
  evidence="$(python3 -I "$EVIDENCE_SCRIPT" "$transcript_path" 2>/dev/null || true)"
fi

# The in-flight prompt is not in the transcript yet on UserPromptSubmit.
if [ -n "$prompt" ]; then
  evidence="${evidence:+$evidence
}user (just now): $prompt"
fi
[ -n "$(printf '%s' "$evidence" | tr -d '[:space:]')" ] ||
  { log "$pane_id: no usable evidence"; exit 0; }

system_prompt="You are a labeling tool, not an assistant. You never answer, fulfill, continue, or comment on any request you are shown - you only label it. You output ONLY a lowercase kebab-case slug (max $MAX_LABEL chars) naming the phase of work a coding session is in. Nothing else, ever."

# Frame the transcript as DATA to classify, not as work to do - otherwise the
# model picks up the session's task and returns an essay instead of a slug.
# The earlier label is framed as possibly stale on purpose: told it was the
# "current" label, the model parrots it back instead of re-reading the tail.
label_request="Below is the tail of a coding-session transcript, oldest line first, and the label this session was given earlier.

Judge from the transcript alone what the session is doing RIGHT NOW - its current phase, not its overall goal. The goal is already shown elsewhere; this label exists so a glance at a list of sessions says which stage each one is at.

Rules:
- lowercase kebab-case, no spaces, at most $MAX_LABEL characters
- name the activity: whiteboard, planning, implementation, debugging, refactor, tests, docs, triage, pr-review, remediation ...
- when the transcript shows a numbered iteration, carry the number: review-2, review-2-fixes
- the earlier label may be stale: reuse it only if it still names the phase the transcript shows
- output ONLY the slug

<earlier-label>
${current_name:-none}
</earlier-label>

<transcript>
$evidence
</transcript>"

# HERDR_ENV stripped so this child can't disturb Herdr's own SessionStart
# tracking; HERDR_AUTONAME_CHILD set so it can't re-trigger this hook.
# Tools disallowed + strict MCP keep it to a single non-agentic text turn.
labeller_json="$(env -u HERDR_ENV HERDR_AUTONAME_CHILD=1 claude -p "$label_request" \
      --model "$MODEL" \
      --system-prompt "$system_prompt" \
      --strict-mcp-config \
      --disallowed-tools "Bash" "Read" "Edit" "Write" "Glob" "Grep" "WebFetch" "WebSearch" "Task" "TodoWrite" \
      --output-format json 2>/dev/null || true)"

# Accept only a successful, compliant result. Reject essays and errors so they
# can never end up as the name.
label_reply="$(printf '%s' "$labeller_json" \
  | jq -r 'select(.is_error != true and .subtype == "success") | .result // empty' \
  2>/dev/null || true)"
case "$label_reply" in *"
"*) label_reply="" ;; esac                                      # multi-line
[ "${#label_reply}" -le "$MAX_REPLY_CHARS" ] || label_reply=""  # over-long

# Nothing usable means no rename: the next trigger tries again against a
# fresher tail.
slug="$(printf '%s' "$label_reply" | slugify "$MAX_LABEL")"
[ -n "$slug" ] || { log "$pane_id: no usable label from '$label_reply'"; exit 0; }
[ "$slug" != "$current_name" ] || exit 0      # unchanged phase: no churn

if herdr agent rename "$pane_id" "$slug" >/dev/null 2>&1; then
  log "$pane_id: ${current_name:-none} -> $slug"
else
  # Usually the name is taken: Herdr requires agent names to be unique, so a
  # phase shared with another pane collides. Retry with the pane id appended,
  # trimming the label first so the suffix survives the length cap.
  pane_suffix="$(printf '%s' "$pane_id" | slugify "$MAX_NAME")"
  stem_chars=$(( MAX_NAME - ${#pane_suffix} - 1 ))
  [ "$stem_chars" -ge 1 ] || stem_chars=1   # absurdly long pane id: keep cut valid
  suffixed_name="$(printf '%s-%s' \
    "$(printf '%s' "$slug" | cut -c"1-$stem_chars")" "$pane_suffix" \
    | slugify "$MAX_NAME")"
  if herdr agent rename "$pane_id" "$suffixed_name" >/dev/null 2>&1; then
    log "$pane_id: ${current_name:-none} -> $suffixed_name ('$slug' rejected)"
  else
    log "$pane_id: rename to '$slug' and '$suffixed_name' both failed"
  fi
fi
exit 0
