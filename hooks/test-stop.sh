#!/usr/bin/env bash
# Ephemeral test harness for hooks/stop — no live Claude session needed.
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/stop"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

mk_transcript() { # file model occupied [footer_line]
  printf '{"type":"user","message":{"role":"user"}}\n' > "$1"
  if [ -n "${4:-}" ]; then
    printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5},"content":[{"type":"text","text":"body mentions 🔴 🟡 🟢 states\\n%s"}]}}\n' "$2" "$3" "$4" >> "$1"
  else
    printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5}}}\n' "$2" "$3" >> "$1"
  fi
}
mk_bd_stub() { # dir ready_count inprog_count
  mkdir -p "$1"
  cat > "$1/bd" <<STUB
#!/usr/bin/env bash
emit(){ printf '['; i=0; while [ "\$i" -lt "\$1" ]; do [ "\$i" -gt 0 ] && printf ','; printf '{"id":"x%s"}' "\$i"; i=\$((i+1)); done; printf ']'; }
case "\$1" in
  ready) emit $2 ;;
  list) case "\$*" in *in_progress*) emit $3 ;; *) emit 0 ;; esac ;;
  *) emit 0 ;;
esac
STUB
  chmod +x "$1/bd"
}
# run NAME EXPECT_EXIT EXPECT_SUBSTR(""=expect empty stdout) STDIN_JSON  [extra env KEY=VAL ...]
run() {
  local name="$1" eexit="$2" esub="$3" stdin="$4"; shift 4
  mk_bd_stub "$TMP/bin" "${READY:-1}" "${INPROG:-0}"
  local out code
  out="$(printf '%s' "$stdin" | env -u CMUX_SURFACE_ID PATH="$TMP/bin:$PATH" HANDOFF_STATE_DIR="$TMP/state" BD_BIN=bd "$@" bash "$HOOK" 2>/dev/null)"; code=$?
  local ok=1
  [ "$code" = "$eexit" ] || ok=0
  if [ -z "$esub" ]; then [ -z "$out" ] || ok=0; else case "$out" in *"$esub"*) : ;; *) ok=0 ;; esac; fi
  if [ "$ok" = 1 ]; then PASS=$((PASS+1)); echo "ok   - $name"; else FAIL=$((FAIL+1)); echo "FAIL - $name (exit=$code out=$out)"; fi
}

T="$TMP/t.jsonl"; S="{\"session_id\":\"s1\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
# --- input guards (NO FIRE -> exit0, empty stdout) ---
mk_transcript "$T" "claude-opus-4-8" 50000
run "disable kill-switch"          0 "" "{\"session_id\":\"s1\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}" HANDOFF_DISABLE=1
run "loop guard stop_hook_active"  0 "" "{\"session_id\":\"s1\",\"transcript_path\":\"$T\",\"stop_hook_active\":true}"
run "missing transcript path"      0 "" "{\"session_id\":\"s1\",\"stop_hook_active\":false}"
run "unreadable transcript"        0 "" "{\"session_id\":\"s1\",\"transcript_path\":\"$TMP/nope.jsonl\",\"stop_hook_active\":false}"
run "below threshold (5% of 1M)"   0 "" "$S"
# --- ready check ---
mk_transcript "$T" "claude-opus-4-8" 350000   # 35% of 1M
READY=0 run "over threshold but no ready -> exit0" 0 "" "$S"
# --- window inference: model name decides 1M vs 200k (250k = 25% of 1M but 125% of 200k) ---
mk_transcript "$T" "claude-opus-4-8" 250000
run "opus-4-8 250k = 25% of 1M -> NO fire" 0 "" "$S"
mk_transcript "$T" "claude-sonnet-4-5" 80000  # sonnet-4-5 NOT in 1M set -> 200k default; 40%
run "sonnet-4-5 80k = 40% of 200k -> FIRE" 0 '"decision":"block"' "{\"session_id\":\"fsonnet\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
# --- MINIMAL FIRE + window override (unique session per fire so dedup flags don't bleed) ---
mk_transcript "$T" "claude-opus-4-8" 350000
READY=1 run "over threshold + ready -> FIRE (1M)" 0 '"decision":"block"' "{\"session_id\":\"f1m\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
mk_transcript "$T" "claude-opus-4-8" 250000
READY=1 run "override 200k makes 250k = 125% -> FIRE" 0 '"decision":"block"' "{\"session_id\":\"fovr\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}" HANDOFF_CTX_WINDOW=200000

# --- seam guard: mid-task -> NO fire ---
mk_transcript "$T" "claude-opus-4-8" 350000   # 35% over threshold
READY=2 INPROG=1 run "ready but in_progress (mid-task) -> exit0" 0 "" "$S"

# --- dedup: fire once per session ---
mk_transcript "$T" "claude-opus-4-8" 350000
rm -rf "$TMP/state"
D1="{\"session_id\":\"dedup1\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
READY=1 run "first fire writes flag -> FIRE"              0 '"decision":"block"' "$D1"
READY=1 run "second stop same session -> exit0 (deduped)" 0 "" "$D1"
mkdir -p "$TMP/state"; : > "$TMP/state/pref"
READY=1 run "pre-existing flag -> exit0" 0 "" "{\"session_id\":\"pref\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"

# --- footer seam signal (last line only; body mentions all three states) ---
mk_transcript "$T" "claude-opus-4-8" 350000 "🔴 Need prod API key to continue"
READY=1 run "footer 🔴 -> suppress" 0 "" "{\"session_id\":\"fred\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
mk_transcript "$T" "claude-opus-4-8" 350000 "🟡 Code done, set SECRET before testing"
READY=1 run "footer 🟡 -> suppress" 0 "" "{\"session_id\":\"fyel\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"
mk_transcript "$T" "claude-opus-4-8" 350000 "🟢 Wired footer-aware handoff"
READY=1 run "footer 🟢 (body has 🔴🟡) -> still fires" 0 '"decision":"block"' "{\"session_id\":\"fgrn\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}"

# --- C path: in cmux -> direct spawn via HANDOFF_SH stub, no block on stdout ---
mk_bd_stub "$TMP/bin" 2 0
cat > "$TMP/bin/cmux" <<'CMX'
#!/usr/bin/env bash
exit 0
CMX
chmod +x "$TMP/bin/cmux"
SPAWN_LOG="$TMP/spawn.log"; rm -f "$SPAWN_LOG"
cat > "$TMP/handoff_stub.sh" <<STB
#!/usr/bin/env sh
printf '%s' "\$1" > "$SPAWN_LOG"
STB
chmod +x "$TMP/handoff_stub.sh"
mk_transcript "$T" "claude-opus-4-8" 350000 "🟢 ready to hand off"
cout="$(printf '%s' "{\"session_id\":\"cmuxc\",\"transcript_path\":\"$T\",\"stop_hook_active\":false}" | env PATH="$TMP/bin:$PATH" HANDOFF_STATE_DIR="$TMP/state" BD_BIN=bd CMUX_SURFACE_ID=test HANDOFF_SH="$TMP/handoff_stub.sh" bash "$HOOK" 2>/dev/null)"; ccode=$?
i=0; while [ ! -s "$SPAWN_LOG" ] && [ "$i" -lt 20 ]; do sleep 0.1; i=$((i+1)); done
if [ "$ccode" = 0 ] && [ -z "$cout" ] && grep -q "Next ready task" "$SPAWN_LOG" 2>/dev/null; then
  PASS=$((PASS+1)); echo "ok   - C path: in cmux -> direct spawn, no block"
else
  FAIL=$((FAIL+1)); echo "FAIL - C path direct spawn (code=$ccode out=$cout log=$(cat "$SPAWN_LOG" 2>/dev/null))"
fi
# --- wiring: hooks.json registers a Stop hook pointing at run-hook.cmd stop ---
HJ="$(cd "$(dirname "$0")" && pwd)/hooks.json"
if jq -e '.hooks.Stop[0].hooks[0].command | test("run-hook.cmd. stop")' "$HJ" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "ok   - hooks.json registers Stop -> run-hook.cmd stop"
else
  FAIL=$((FAIL+1)); echo "FAIL - hooks.json Stop wiring missing"
fi

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" = 0 ]
