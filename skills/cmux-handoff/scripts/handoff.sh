#!/bin/sh
# cmux-handoff — spawn a fresh Claude Code session in a NEW TAB of the current
# cmux pane, launch it via the user's `clxp` alias, and optionally seed it with a
# handoff prompt.
#
# POSIX sh. Run from inside a cmux + Claude Code session.
#
# Usage:
#   handoff.sh [handoff prompt words...]
#     with a prompt -> the new session is auto-submitted that prompt
#     no prompt      -> the new session is launched and left idle
#
# Exit codes:
#   0  success (prompt submitted, or idle if no prompt)
#   1  setup error (not in cmux / cmux missing / tab creation failed)
#   2  tab + clxp launched but agent prompt not ready in time; prompt NOT sent

set -eu

# --- tunables ---------------------------------------------------------------
LAUNCH_CMD="clxp"   # interactive command that starts the agent in the new tab
READY_MARKER="❯"     # Claude Code input caret: signals the TUI is ready for input
BOOT_FLOOR=2        # seconds to wait before polling (shell -> agent handoff)
BOOT_TIMEOUT=30     # max seconds to wait for the agent prompt

PROMPT="$*"

# --- guards -----------------------------------------------------------------
command -v cmux >/dev/null 2>&1 || {
  echo "cmux-handoff: 'cmux' not found on PATH." >&2
  exit 1
}

if [ -z "${CMUX_SURFACE_ID:-}" ]; then
  echo "cmux-handoff: not inside a cmux terminal (CMUX_SURFACE_ID is unset)." >&2
  exit 1
fi

# --- resolve the pane that owns the calling surface -------------------------
# `cmux identify` reports the caller's pane_ref, so the new tab lands in THIS
# pane even if keyboard focus has drifted. Empty result -> fall back to
# new-surface's default (the focused pane).
PANE=$(cmux identify --surface "$CMUX_SURFACE_ID" 2>/dev/null | awk '
  /"caller"/        { in_caller = 1 }
  in_caller && /"pane_ref"/ { gsub(/[",]/, "", $3); print $3; exit }
') || PANE=""

# --- short random tab name: <adj>-<noun>-<2 digits> -------------------------
NAME=$(awk 'BEGIN {
  srand()
  na = split("swift brisk calm bold lush vivid keen wry nimble sly amber dusk slate", A, " ")
  nn = split("otter falcon cedar maple raven lynx heron koi ember finch quartz reef", N, " ")
  printf "%s-%s-%02d", A[int(rand()*na)+1], N[int(rand()*nn)+1], int(rand()*90)+10
}')

# --- create + name the new tab (focused so the user lands on the handoff) ---
if [ -n "$PANE" ]; then
  CREATED=$(cmux new-surface --type terminal --pane "$PANE" --focus true --id-format both)
else
  CREATED=$(cmux new-surface --type terminal --focus true --id-format both)
fi

# CREATED: "OK surface:NN (UUID) pane:NN (UUID) workspace:NN (UUID)"
# Grab the surface UUID (stable handle) from the parenthesised 3rd field.
SID=$(printf '%s\n' "$CREATED" | awk '{ gsub(/[()]/, "", $3); print $3 }')
if [ -z "$SID" ]; then
  echo "cmux-handoff: failed to create a new tab (cmux said: $CREATED)." >&2
  exit 1
fi

cmux rename-tab --surface "$SID" "$NAME" >/dev/null

# --- launch the agent -------------------------------------------------------
cmux send --surface "$SID" "$LAUNCH_CMD" >/dev/null
cmux send-key --surface "$SID" enter >/dev/null

# --- wait for the agent prompt to be ready ----------------------------------
sleep "$BOOT_FLOOR"
elapsed=$BOOT_FLOOR
ready=0
while [ "$elapsed" -lt "$BOOT_TIMEOUT" ]; do
  if cmux read-screen --surface "$SID" 2>/dev/null | grep -q "$READY_MARKER"; then
    ready=1
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

# --- seed the prompt (or leave idle) ----------------------------------------
if [ -z "$PROMPT" ]; then
  echo "cmux-handoff: opened tab '$NAME' (surface $SID); '$LAUNCH_CMD' launched, left idle (no prompt)."
  exit 0
fi

if [ "$ready" -ne 1 ]; then
  echo "cmux-handoff: tab '$NAME' (surface $SID) created and '$LAUNCH_CMD' launched, but the agent prompt was not ready within ${BOOT_TIMEOUT}s." >&2
  echo "cmux-handoff: NOT sending the prompt (avoiding a dump into the shell). Switch to the tab and paste it:" >&2
  printf '%s\n' "$PROMPT" >&2
  exit 2
fi

cmux send --surface "$SID" "$PROMPT" >/dev/null
sleep 1
cmux send-key --surface "$SID" enter >/dev/null
echo "cmux-handoff: handed off to tab '$NAME' (surface $SID); prompt submitted."
exit 0
