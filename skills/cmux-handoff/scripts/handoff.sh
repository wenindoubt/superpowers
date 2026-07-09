#!/bin/sh
# cmux-handoff — spawn a fresh Claude Code session in a NEW TAB of the current
# cmux pane, launch it via the user's `clxp` alias, and optionally seed it with a
# handoff prompt. On a successful *prompted* handoff it also bounds the session
# pool: it retires the calling session into a FIFO ring and closes the oldest
# already-handed-off tabs so only CMUX_HANDOFF_KEEP stay alive (default 5).
#
# POSIX sh. Run from inside a cmux + Claude Code session.
#
# Usage:
#   handoff.sh [handoff prompt words...]
#     with a prompt -> the new session is auto-submitted that prompt
#     no prompt      -> the new session is launched and left idle (no reaping)
#
# Env tunables:
#   CMUX_HANDOFF_KEEP   max live handoff sessions to keep (default 5; <2 => 2)
#   CMUX_HANDOFF_RING   ring registry path (default ~/.claude/state/cmux-handoff-ring.tsv)
#
# Exit codes:
#   0  success (prompt submitted, or idle if no prompt)
#   1  setup error (not in cmux / cmux missing / tab creation failed)
#   2  tab + clxp launched but agent prompt not ready in time; prompt NOT sent

set -eu

# --- tunables ---------------------------------------------------------------
LAUNCH_CMD="clxp --chrome"   # interactive command that starts the agent in the new tab (--chrome enables claude-in-chrome)
READY_MARKER="❯"     # Claude Code input caret: signals the TUI is ready for input
BOOT_FLOOR=2        # seconds to wait before polling (shell -> agent handoff)
BOOT_TIMEOUT=30     # max seconds to wait for the agent prompt
KEEP_ALIVE="${CMUX_HANDOFF_KEEP:-5}"
RING="${CMUX_HANDOFF_RING:-$HOME/.claude/state/cmux-handoff-ring.tsv}"

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

# --- helpers ----------------------------------------------------------------
# Best-effort desktop notification pinned to the fresh child tab (falls back to
# self). Never fails the script.
hf_notify() {
  cmux notify --title "cmux-handoff: $1" --body "$2" \
    --surface "${SID:-$CMUX_SURFACE_ID}" >/dev/null 2>&1 || true
}

# Uppercase a UUID so comparisons are case-stable (cmux emits upper; env vars may vary).
upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# Bound the pool. Called ONLY on a successful prompted handoff — reaching here
# means THIS session committed+pushed+closed its bead (the handoff protocol), so
# it is safe to retire. A session that never runs handoff.sh (still mid-task, or
# idle awaiting a human decision) is never in the ring and never reaped.
#
# The ring is the handoff chain itself: each retiring session appends its own
# surface UUID; the newest KEEP_ALIVE-1 retired tabs (plus the just-spawned child)
# stay, older ones are closed. UUIDs — never cmux short refs (surface:NN), which
# are reassigned as tabs come and go.
ring_reap() {
  [ -n "${SID:-}" ] || return 0
  mkdir -p "$(dirname "$RING")" 2>/dev/null || true

  # Retire self as the newest ring entry (append is atomic).
  printf '%s\t%s\t%s\n' "$(date +%s)" "$CMUX_SURFACE_ID" "${BEAD:-$NAME}" >> "$RING" 2>/dev/null || return 0
  [ -f "$RING" ] || return 0

  # Serialize concurrent reaps (parallel handoffs) with an atomic mkdir lock;
  # if another session holds it, just skip reaping this round (self is already
  # appended, so it will be considered next time).
  LOCK="$RING.lock"
  mkdir "$LOCK" 2>/dev/null || return 0

  # Snapshot of surface UUIDs that currently exist, and the focused one.
  EXISTING=" $(cmux tree --all --id-format both 2>/dev/null \
    | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | tr '[:lower:]' '[:upper:]' | tr '\n' ' ') "
  FOCUSED=$(cmux tree --all --id-format both 2>/dev/null \
    | awk '/surface surface:/ && /◀ active/ { print $3; exit }')
  FOCUSED=$(upper "${FOCUSED:-}")
  CHILD=$(upper "$SID")
  SELF=$(upper "$CMUX_SURFACE_ID")

  # Alive retired surfaces, oldest-first, excluding the just-spawned child.
  alive=""
  while IFS='	' read -r _ts uuid _label; do
    [ -n "${uuid:-}" ] || continue
    u=$(upper "$uuid")
    case "$EXISTING" in *" $u "*) : ;; *) continue ;; esac   # gone -> pruned on rewrite
    [ "$u" = "$CHILD" ] && continue
    alive="$alive $u"
  done < "$RING"

  # Keep the newest (KEEP_ALIVE-1) retired alive; the child takes the last slot.
  keep=$((KEEP_ALIVE - 1))
  [ "$keep" -lt 1 ] && keep=1
  remaining=0
  for _u in $alive; do remaining=$((remaining + 1)); done

  # Close oldest-first until the surviving retired pool fits `keep`. A SKIPPED entry
  # (self, focused, or a failed close) stays ALIVE, so it must not consume a reap slot:
  # counting it as progress leaves the pool a tab over KEEP until some later hop happens
  # to find it closable. Only a successful close decrements `remaining`. If every entry
  # is unclosable the loop simply runs out — the next handoff retries.
  reaped=" "
  for u in $alive; do
    [ "$remaining" -gt "$keep" ] || break
    [ "$u" = "$SELF" ] && continue     # never close the surface running this script
    [ "$u" = "$FOCUSED" ] && continue  # a human may be viewing it
    if cmux close-surface --surface "$u" >/dev/null 2>&1; then
      reaped="$reaped$u "
      remaining=$((remaining - 1))
    else
      hf_notify "reap error" "could not close idle handoff session $u"
    fi
  done

  # Rewrite the ring: drop closed tabs and any that no longer exist (crashed
  # sessions that never handed off self-heal here).
  tmp="$RING.$$"
  : > "$tmp"
  while IFS='	' read -r ts uuid label; do
    [ -n "${uuid:-}" ] || continue
    u=$(upper "$uuid")
    case "$EXISTING" in *" $u "*) : ;; *) continue ;; esac
    case "$reaped" in *" $u "*) continue ;; esac
    printf '%s\t%s\t%s\n' "$ts" "$uuid" "$label" >> "$tmp"
  done < "$RING"
  mv "$tmp" "$RING" 2>/dev/null || rm -f "$tmp"

  rmdir "$LOCK" 2>/dev/null || true
}

# --- resolve the pane that owns the calling surface -------------------------
# `cmux identify` reports the caller's pane_ref, so the new tab lands in THIS
# pane even if keyboard focus has drifted. Empty result -> fall back to
# new-surface's default (the focused pane).
PANE=$(cmux identify --surface "$CMUX_SURFACE_ID" 2>/dev/null | awk '
  /"caller"/        { in_caller = 1 }
  in_caller && /"pane_ref"/ { gsub(/[",]/, "", $3); print $3; exit }
') || PANE=""

# --- tab name: the next bead id (legible in the pool) else a random handle ---
# The seed prompt names the next work as "... task: <bead-id> ...". Labeling the
# tab with that id makes a pool of handoff tabs scannable at a glance; the random
# adjective-noun handle is the fallback + the ring's log label.
NAME=$(awk 'BEGIN {
  srand()
  na = split("swift brisk calm bold lush vivid keen wry nimble sly amber dusk slate", A, " ")
  nn = split("otter falcon cedar maple raven lynx heron koi ember finch quartz reef", N, " ")
  printf "%s-%s-%02d", A[int(rand()*na)+1], N[int(rand()*nn)+1], int(rand()*90)+10
}')
BEAD=$(printf '%s' "$PROMPT" | sed -n 's/.*[Tt]ask:[[:space:]]*\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)
TABNAME="${BEAD:-$NAME}"

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

cmux rename-tab --surface "$SID" "$TABNAME" >/dev/null

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
  echo "cmux-handoff: opened tab '$TABNAME' (surface $SID); '$LAUNCH_CMD' launched, left idle (no prompt)."
  exit 0
fi

if [ "$ready" -ne 1 ]; then
  echo "cmux-handoff: tab '$TABNAME' (surface $SID) created and '$LAUNCH_CMD' launched, but the agent prompt was not ready within ${BOOT_TIMEOUT}s." >&2
  echo "cmux-handoff: NOT sending the prompt (avoiding a dump into the shell). Switch to the tab and paste it:" >&2
  printf '%s\n' "$PROMPT" >&2
  exit 2
fi

cmux send --surface "$SID" "$PROMPT" >/dev/null
sleep 1
cmux send-key --surface "$SID" enter >/dev/null
echo "cmux-handoff: handed off to tab '$TABNAME' (surface $SID); prompt submitted."

# Retire self + bound the pool to CMUX_HANDOFF_KEEP. Best-effort: a reaper
# hiccup must never fail an otherwise-successful handoff.
ring_reap || true

exit 0
