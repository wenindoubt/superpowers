# Beads-Native Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make 5 superpowers skills store specs/plans/handoffs in beads (`bd`) instead of markdown, with an ask-first per-repo init.

**Architecture:** One shared reference doc defines the superpowers bead model (decision→epic→task) + ask-first preflight. The 5 skills reference it and add their skill-specific `bd` commands. Runtime hard-rules (never `bd edit`, `--json`, `--claim`, push-before-done) are delegated to bd's own generated `AGENTS.md` (via `bd setup claude`), not restated. An end-to-end smoke test in a scratch repo proves the pipeline.

**Tech Stack:** Markdown skill files; `bd` (beads) v1.0.3, Dolt-backed; bash for the smoke test.

---

## ⚠️ Verification reality — read before executing

These are **behavior-shaping skill files, not code.** Classic pytest red-green does not apply. Verification per task is:
1. **Structural assertions** — `grep` confirms new `bd` instructions present and old markdown-path instructions removed.
2. **Empirical command proof** — the exact `bd` commands were already verified in a scratch repo on 2026-06-01 (bd 1.0.3); see "Verified commands" below. Do not re-derive syntax — use these.
3. **End-to-end smoke test** (Task 7) — the real behavioral proof: runs the full pipeline in a throwaway repo and asserts beads are created/linked/closed correctly.

Per the project CLAUDE.md, skill-content changes ideally also get a `superpowers:writing-skills` adversarial eval before being relied on. These edits are **fork-local** (the user's own workflow, not an upstream PR), so the smoke test is the gate for this plan; a `writing-skills` trigger-eval on the two trigger-critical skills (brainstorming, session-handoff) is recommended as a follow-up before daily reliance. This is flagged again in Task 7.

## Verified commands (empirical, bd 1.0.3, 2026-06-01)

```bash
BD_NON_INTERACTIVE=1 bd init --prefix <p>                      # creates .beads/, ships its own .gitignore
echo "<body>" | bd create --type decision --title "T" --description=- --design "<rationale>"
EPIC=$(bd create --type epic --title "T" -d "<goal>" --silent)
T1=$(printf '<body>' | bd create --type task --parent "$EPIC" --title "T" --description=- --acceptance "tests pass + committed" --silent)
bd dep add <dependent-id> <blocker-id> --type blocks           # dependent depends on blocker
bd update <epic-id> --spec-id <decision-id>                    # link epic→decision
bd ready --parent <epic-id> --json                             # only unblocked children
bd update <id> --claim                                         # atomic claim
bd note <id> "<text>"                                          # append note
bd close <id> --reason "<why>"
bd export                                                      # writes .beads/issues.jsonl
bd setup claude                                                # AGENTS.md + CLAUDE.md beads section + hooks + .claude/settings.json
bd bootstrap                                                   # rebuild Dolt DB from committed JSONL (fresh clone)
```

Facts confirmed: hierarchical IDs (`epic`, `epic.1`, `epic.2`); `bd ready --parent` excludes blocked children; `--description=-` reads stdin; decision bead stores `description`+`design`; epic stores `notes`; `.beads/.gitignore` (bd-shipped) ignores `embeddeddolt/` + runtime, keeps `config.yaml`/`metadata.json`/`issues.jsonl` tracked.

## File structure

| File | Action | Responsibility |
|------|--------|----------------|
| `skills/_shared/beads-workflow.md` | **create** | Superpowers bead model (decision→epic→task) + ask-first preflight. Single source the 5 skills reference. |
| `skills/brainstorming/SKILL.md` | modify | Spec output: markdown file → `decision` bead |
| `skills/writing-plans/SKILL.md` | modify | Plan output: markdown file → `epic` + `task` beads |
| `skills/subagent-driven-development/SKILL.md` | modify | Task source: markdown checkboxes → `bd ready` loop |
| `skills/executing-plans/SKILL.md` | modify | Task source: markdown checkboxes → `bd ready` loop |
| `skills/session-handoff/SKILL.md` | **move-in + modify** | Moved from `~/.claude/skills/`; handoff markdown doc → note-on-bead / no-op. Consolidates all behavior into the repo. |
| `tests/beads-workflow/smoke-test.sh` | create | End-to-end pipeline assertion in a scratch repo |

**Edit convention:** all skill edits are fork-local — mark inserted blocks with `<!-- beads-native: fork-local -->` (matching the repo's existing `<!-- ...: fork-local -->` markers) so they're greppable and distinguishable from upstream content.

---

## Task 1: Shared bead-model reference

**Files:**
- Create: `skills/_shared/beads-workflow.md`

- [ ] **Step 1: Create the shared reference doc**

Create `skills/_shared/beads-workflow.md` with this exact content:

````markdown
<!-- beads-native: fork-local -->
# Beads Workflow (shared reference)

The superpowers spec→plan→handoff pipeline stores everything in **beads** (`bd`), not markdown.
This doc is referenced by: brainstorming, writing-plans, subagent-driven-development,
executing-plans, session-handoff.

## Ask-first preflight (run before any bd write)

```bash
if [ ! -d .beads ]; then
  echo "No beads database in this repo."   # ASK the human first — never init silently
fi
```

If `.beads/` is missing, STOP and ask the human:
"This repo has no beads database. Initialize one? Suggested prefix: `<short>` (from repo name)."
On yes:
```bash
BD_NON_INTERACTIVE=1 bd init --prefix <short>
bd setup claude   # generates AGENTS.md + CLAUDE.md beads section + hooks
git add .beads AGENTS.md CLAUDE.md .claude/settings.json && git commit -m "chore: init beads"
```
On no: fall back to the skill's pre-beads behavior for this session and tell the human.

## The bead model (one feature)

```
decision bead  (type: decision)   ← brainstorming
  --description : the spec
  --design      : approach + tradeoffs
  --notes       : research findings
   ▲ --spec-id
epic bead  (type: epic)           ← writing-plans
  body: goal, architecture, tech stack
  └── task beads (type: task, --parent epic)   ← one per behavioral unit
       --description : TDD steps as a checklist + code blocks
       --acceptance  : "tests pass + committed"
       deps: bd dep add <dependent> <blocker> --type blocks
       discovered work → bd create ... --deps discovered-from:<id>
```

**Granularity:** a bead is a behavioral unit you could block on, reorder, or assign.
TDD micro-steps (write test / run / implement / run / commit) live in the task body,
NEVER as separate beads.

## Runtime hard rules

These are owned by bd's generated `AGENTS.md` — run `bd prime` for the authoritative list.
Summary: never `bd edit` (use `bd update` w/ flags or `--description=-` stdin); always `--json`
when parsing; `bd update <id> --claim` before work; `bd close <id> --reason "..."` after;
put `(bd-id)` in commit messages; **work is not done until `git push` succeeds**.
````

- [ ] **Step 2: Verify the doc exists and is well-formed**

Run: `test -f skills/_shared/beads-workflow.md && grep -c "type: decision\|type: epic\|--claim\|Ask-first" skills/_shared/beads-workflow.md`
Expected: prints a number ≥ 4 (all anchor phrases present).

- [ ] **Step 3: Commit**

```bash
git add skills/_shared/beads-workflow.md
git commit -m "feat(beads): shared bead-model reference for workflow skills (bd-<id>)"
```

---

## Task 2: brainstorming → emit decision bead

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (the "After the Design / Documentation" section, ~lines 158-170, which currently says *"Write the validated design (spec) to `docs/superpowers/specs/...md`"* and *"Commit the design document to git"*)

- [ ] **Step 1: Replace the markdown-spec output with a decision bead**

In `skills/brainstorming/SKILL.md`, under **## After the Design → Documentation**, replace the bullet that writes the spec markdown with:

```markdown
<!-- beads-native: fork-local -->
- **Run the ask-first preflight** in `skills/_shared/beads-workflow.md`. If the human declines beads, fall back to writing `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and skip the rest of this block.
- Otherwise write the validated design as a **decision bead** (do NOT write a spec markdown file):

      DECISION=$(bd create --type decision --title "<topic>" \
        --description=- \
        --design "<chosen approach + key tradeoffs>" --silent <<'SPEC'
      <the full spec body: goal, architecture, components, data flow, error handling, testing>
      SPEC
      )
      bd note "$DECISION" "Research Findings: <findings + source URLs + retrieval date>"

- Record the decision bead ID — writing-plans needs it for `--spec-id`.
- The auto-exported `.beads/issues.jsonl` is the committed artifact; commit it: `git add .beads/issues.jsonl && git commit -m "docs(spec): <topic> decision bead (bd-<id>)"`.
```

- [ ] **Step 2: Pass the decision ID to writing-plans**

In the **## After the Design → Implementation** section, change the writing-plans handoff line to include the decision bead ID:

```markdown
- Invoke the writing-plans skill to create the implementation plan; pass it the decision bead ID (`$DECISION`) so the epic links via `--spec-id`.
```

- [ ] **Step 3: Verify edits**

Run: `grep -c "decision bead\|--spec-id\|beads-workflow.md\|\\$DECISION" skills/brainstorming/SKILL.md`
Expected: ≥ 3. Also: `grep -c "specs/YYYY-MM-DD" skills/brainstorming/SKILL.md` should be `1` (only the fallback path remains).

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat(beads): brainstorming emits a decision bead (bd-<id>)"
```

---

## Task 3: writing-plans → emit epic + task beads

**Files:**
- Modify: `skills/writing-plans/SKILL.md` — the header block, "Save plans to" line, "Task Structure" section, and "Execution Handoff" section.

- [ ] **Step 1: Replace the "Save plans to" instruction with the bead model**

Replace the `**Save plans to:** docs/superpowers/plans/...` line with:

```markdown
<!-- beads-native: fork-local -->
**Save plans as beads** (run the ask-first preflight in `skills/_shared/beads-workflow.md` first):

    EPIC=$(bd create --type epic --title "<feature>" --silent -d - <<'GOAL'
    Goal: <one sentence>
    Architecture: <2-3 sentences>
    Tech Stack: <key tech>
    GOAL
    )
    bd update "$EPIC" --spec-id "$DECISION"   # decision bead ID from brainstorming, if present

If the human declined beads, fall back to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
```

- [ ] **Step 2: Replace the per-task markdown structure with per-task beads**

Under **## Task Structure**, add a fork-local block stating that each task becomes one bead:

```markdown
<!-- beads-native: fork-local -->
**Each task = one `task` bead** (not a markdown section). The 5 TDD steps + code blocks go in the bead BODY as a checklist — never as separate beads.

    T=$(bd create --type task --parent "$EPIC" --title "<task name>" \
      --acceptance "tests pass + committed" --silent --description=- <<'BODY'
    ### Files
    - Create: <path>   - Modify: <path:lines>   - Test: <path>

    - [ ] Step 1: Write the failing test
    <test code>
    - [ ] Step 2: Run it, verify it fails — `<cmd>` → FAIL
    - [ ] Step 3: Minimal implementation
    <impl code>
    - [ ] Step 4: Run it, verify it passes — `<cmd>` → PASS
    - [ ] Step 5: Commit (include "(bd-<this-id>)" in the message)
    BODY
    )

Wire ordering with dependencies (a task that must follow another):

    bd dep add "$T_later" "$T_earlier" --type blocks
```

Keep the existing "Bite-Sized Task Granularity" and "No Placeholders" guidance — they now describe the bead body content.

- [ ] **Step 3: Update the Execution Handoff section**

Replace the "Plan complete and saved to `docs/.../<filename>.md`" line with:

```markdown
**"Plan complete: epic `$EPIC` with N task beads. Executing Subagent-Driven: fresh subagent per ready task, review between tasks."**
```

- [ ] **Step 4: Verify edits**

Run: `grep -c "type: epic\|type task\|--parent\|bd dep add\|--spec-id" skills/writing-plans/SKILL.md`
Expected: ≥ 4.

- [ ] **Step 5: Commit**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "feat(beads): writing-plans emits epic + task beads (bd-<id>)"
```

---

## Task 4: subagent-driven-development → bd ready loop

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` — the "Read plan, extract all tasks..." entry point and the "Mark task complete in TodoWrite" step.

- [ ] **Step 1: Replace plan-reading with the ready loop**

Add a fork-local "## Task source: beads" section near the top (after the Overview), stating the controller drives from `bd ready`:

```markdown
<!-- beads-native: fork-local -->
## Task source: beads

The plan is an epic + task beads (see `skills/_shared/beads-workflow.md`), not a markdown file. The controller loop:

    bd ready --parent "$EPIC" --json     # next unblocked task(s), priority-ordered
    bd update "$TASK" --claim            # claim before dispatching
    # → dispatch fresh implementer subagent with the bead BODY as the task text
    #   (bd show "$TASK" --json | jq -r '.[0].description')
    # → spec review, then code-quality review (unchanged)
    bd close "$TASK" --reason "<summary>"   # ONLY after the subagent has git push-ed
    # repeat until: bd ready --parent "$EPIC" --json  → empty

Replace every "Mark task complete in TodoWrite" with `bd close <id> --reason "..."`.
Discovered work → `bd create ... --deps discovered-from:<task-id>` (do not silently expand scope).
```

- [ ] **Step 2: Update the Red Flags list**

Add to the **Never** list: `- Close a task bead before the implementer's work is git push-ed`. Replace "Make subagent read plan file (provide full text instead)" with "Make subagent run bd commands — the controller provides the bead body as task text".

- [ ] **Step 3: Verify edits**

Run: `grep -c "bd ready --parent\|--claim\|bd close\|discovered-from" skills/subagent-driven-development/SKILL.md`
Expected: ≥ 3.

- [ ] **Step 4: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md
git commit -m "feat(beads): subagent-driven-development drives from bd ready (bd-<id>)"
```

---

## Task 5: executing-plans → bd ready loop

**Files:**
- Modify: `skills/executing-plans/SKILL.md` — "Step 1: Load and Review Plan" and "Step 2: Execute Tasks".

- [ ] **Step 1: Replace plan-file reading with the ready loop**

Rewrite Step 1 and Step 2 with a fork-local block:

```markdown
<!-- beads-native: fork-local -->
### Step 1: Load and review the epic
1. `bd show "$EPIC" --json` and `bd ready --parent "$EPIC" --json` — review the work critically
2. Concerns → raise with your human partner before starting

### Step 2: Execute tasks
For each ready task:
1. `bd update <id> --claim`
2. Read the bead body (`bd show <id> --json`) and follow its bite-sized steps exactly
3. Run the verifications in the body
4. `bd close <id> --reason "..."` — only after `git push`
5. Loop until `bd ready --parent "$EPIC" --json` is empty

(If beads is unavailable in this repo, fall back to reading a plan markdown file.)
```

- [ ] **Step 2: Verify edits**

Run: `grep -c "bd ready --parent\|--claim\|bd close" skills/executing-plans/SKILL.md`
Expected: ≥ 2.

- [ ] **Step 3: Commit**

```bash
git add skills/executing-plans/SKILL.md
git commit -m "feat(beads): executing-plans drives from bd ready (bd-<id>)"
```

---

## Task 6: Consolidate session-handoff into the repo + note-on-bead / no-op

**Files:**
- Move: `~/.claude/skills/session-handoff/SKILL.md` → `skills/session-handoff/SKILL.md`
- Modify: `skills/session-handoff/SKILL.md` (the moved copy)
- Delete: `~/.claude/skills/session-handoff/` (avoid name collision / double-load)

- [ ] **Step 1: Move the skill into the repo**

```bash
mkdir -p skills/session-handoff
cp ~/.claude/skills/session-handoff/SKILL.md skills/session-handoff/SKILL.md
```
(Source is outside this git repo, so `cp` not `git mv`; the original is removed in Step 4.)

- [ ] **Step 2: Replace the markdown-doc workflow with bead state + conditional note**

In `skills/session-handoff/SKILL.md`, replace "## The workflow" steps 2-4 and the "Document template" with a fork-local block:

```markdown
<!-- beads-native: fork-local -->
## The workflow (beads-native)

State lives in beads. Do NOT write a handoff markdown file.

1. **Gather real state** (ground in evidence): `git status`, run the relevant tests, and:
   - Done:     `bd list --parent <epic> --status closed --json`
   - Remaining:`bd ready --parent <epic> --json` + open/blocked
   - Active:   `bd list --status in_progress --json`
2. **Decide if anything would be lost:**
   - **Clean boundary** (no half-done bead with un-encoded context) → write NOTHING. Tell the human:
     *"Clean boundary. New session: say 'do the next ready work'."*
   - **Stopped mid-task** with context not in any bead → pin ONE note to the in-progress bead:

         bd note <in-progress-id> "STOPPED MID-TASK: <what failed / why / what to try next / what NOT to retry>"

3. **Output**: the trigger phrase, not a file path: *"New session: 'do the next ready work'"* (and the note ID if one was written).
```

- [ ] **Step 3: Verify edits**

Run: `grep -c "do the next ready work\|bd note\|in_progress\|bd ready --parent" skills/session-handoff/SKILL.md`
Expected: ≥ 3.

- [ ] **Step 4: Delete the original + commit the move-in**

```bash
rm -rf ~/.claude/skills/session-handoff
# sanity: only the repo copy remains
test -f skills/session-handoff/SKILL.md && ! test -e ~/.claude/skills/session-handoff
git add skills/session-handoff/SKILL.md
git commit -m "feat(beads): consolidate session-handoff into repo, beads-native handoff (bd-<id>)"
```
After this, restart Claude Code so the plugin loads `superpowers:session-handoff` and the stale personal skill is gone (no double-load).

---

## Task 7: End-to-end smoke test + eval recommendation

**Files:**
- Create: `tests/beads-workflow/smoke-test.sh`

- [ ] **Step 1: Write the smoke test**

Create `tests/beads-workflow/smoke-test.sh` (executable) that proves the pipeline in a throwaway repo:

```bash
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

# spec-id link + design field survive export
bd export >/dev/null
python3 - "$TMP" "$DEC" "$EPIC" <<'PY'
import sys,json
tmp,dec,epic=sys.argv[1:4]
rows=[json.loads(l) for l in open(f"{tmp}/.beads/issues.jsonl") if l.strip()]
by={r["id"]:r for r in rows}
assert by[dec].get("design")=="tradeoffs", "decision design lost"
assert by[epic].get("spec_id")==dec, "epic spec_id link lost"
print("OK: design + spec_id persisted")
PY
echo "SMOKE TEST PASSED"
```

- [ ] **Step 2: Run it, expect failure first (script not yet executable / typo guard)**

Run: `bash tests/beads-workflow/smoke-test.sh`
Expected on a correct script: ends with `SMOKE TEST PASSED`. If any `FAIL:`/assertion fires, fix the skill or test and re-run. (This is the red-green proxy: a broken pipeline assumption surfaces here.)

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x tests/beads-workflow/smoke-test.sh
git add tests/beads-workflow/smoke-test.sh
git commit -m "test(beads): end-to-end pipeline smoke test (bd-<id>)"
```

- [ ] **Step 4: Recommend the writing-skills eval (do not skip silently)**

Tell the human: the trigger-critical skills (brainstorming, session-handoff) should get a `superpowers:writing-skills` trigger/adversarial eval before daily reliance, since their descriptions/auto-trigger behavior were not changed but their bodies were. This plan's gate is the smoke test; the eval is the recommended follow-up.

---

## Self-review

- **Spec coverage:** decision bead (Task 2), epic+task beads (Task 3), executor ready-loop (Tasks 4-5), handoff note/no-op (Task 6), ask-first init + git model (Task 1 + bd-shipped gitignore), all-projects lever = editing the global skills (Tasks 2-5) — all covered. Dolt remote correctly out of scope.
- **Placeholders:** `<...>` angle-bracket slots are intentional fill-ins for the editing agent (skill content is templated by nature), not TODO placeholders; every `bd` command is concrete and verified.
- **Consistency:** `$DECISION`/`$DEC`, `$EPIC`, `$T1/$T2` used consistently; `bd dep add <dependent> <blocker> --type blocks` matches verified syntax everywhere.

## Resolved decisions

1. **Shared-doc location** — `skills/_shared/beads-workflow.md` (one shared file, not 5 copies). Rename later if desired.
2. **No dogfood** — do NOT `bd init` the superpowers repo itself; skills init beads only in *target* repos.
3. **Consolidate session-handoff** — moved into `skills/session-handoff/` (Task 6); original deleted. All behavior now lives in the superpowers repo.
4. **Eval rigor** — smoke test (Task 7) is the gate for this plan; one live trial each of brainstorming + session-handoff as follow-up. Full `writing-skills` adversarial eval only if a trial misbehaves.

What inherently stays outside the repo (tool + per-project runtime, not sprawl): the `bd` binary, each target repo's `.beads/` data, and target repos' generated `AGENTS.md`/CLAUDE.md beads section.
