#!/usr/bin/env bash
# End-to-end proof of the beads-native pipeline. Self-contained; uses a scratch repo.
set -euo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"; git init -q; echo x > README.md; git add -A; git commit -qm init

export BD_NON_INTERACTIVE=1
bd init --prefix sm >/dev/null

# brainstorming: decision bead
DEC=$(bd create --type decision --title "smoke decision" --description=- --design "tradeoffs" --silent <<<'spec body')
# writing-plans: epic + 2 task beads, linked + ordered
EPIC=$(bd create --type epic --title "smoke epic" -d "goal" --silent)
bd update "$EPIC" --spec-id "$DEC" >/dev/null
T1=$(bd create --type task --parent "$EPIC" --title "t1" -d "body1" --acceptance "tests pass + committed" --silent)
T2=$(bd create --type task --parent "$EPIC" --title "t2" -d "body2" --acceptance "tests pass + committed" --silent)
bd dep add "$T2" "$T1" --type blocks >/dev/null

# executor: only T1 is ready
READY=$(bd ready --parent "$EPIC" --json | python3 -c 'import sys,json;d=json.load(sys.stdin);print(",".join(i["id"] for i in (d if isinstance(d,list) else d.get("issues",[]))))')
[ "$READY" = "$T1" ] || { echo "FAIL: expected only $T1 ready, got [$READY]"; exit 1; }

bd update "$T1" --claim >/dev/null
bd close "$T1" --reason "done" >/dev/null
# now T2 becomes ready
READY2=$(bd ready --parent "$EPIC" --json | python3 -c 'import sys,json;d=json.load(sys.stdin);print(",".join(i["id"] for i in (d if isinstance(d,list) else d.get("issues",[]))))')
[ "$READY2" = "$T2" ] || { echo "FAIL: expected $T2 ready after closing $T1, got [$READY2]"; exit 1; }

# handoff: note on in-progress bead
bd update "$T2" --claim >/dev/null
bd note "$T2" "STOPPED MID-TASK: smoke note" >/dev/null

# decision --design field stored, and epic --spec-id links to the decision.
# Query the live DB via `bd show` (export is incremental/throttled, so don't parse JSONL).
DESIGN=$(bd show "$DEC" --json | python3 -c 'import sys,json;d=json.load(sys.stdin);print((d[0] if isinstance(d,list) else d).get("design",""))')
[ "$DESIGN" = "tradeoffs" ] || { echo "FAIL: decision design lost, got [$DESIGN]"; exit 1; }
SPEC=$(bd show "$EPIC" --json | python3 -c 'import sys,json;d=json.load(sys.stdin);print((d[0] if isinstance(d,list) else d).get("spec_id",""))')
[ "$SPEC" = "$DEC" ] || { echo "FAIL: epic spec_id link lost, expected $DEC got [$SPEC]"; exit 1; }
echo "OK: design + spec_id persisted"

# export still produces a JSONL artifact (git-tracked source); just assert the file appears.
bd export >/dev/null
[ -f .beads/issues.jsonl ] || { echo "FAIL: bd export did not write .beads/issues.jsonl"; exit 1; }

echo "SMOKE TEST PASSED"
