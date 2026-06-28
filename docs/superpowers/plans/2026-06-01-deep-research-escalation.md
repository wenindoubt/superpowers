# Deep-Research Escalation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the model auto-escalate a web-research pass from `kiln-web-search-researcher` to the `/deep-research` harness when an unknown is high-stakes, with no user prompt.

**Architecture:** One shared markdown file holds the escalation logic; the `brainstorming` and `writing-plans` SKILL.md web-research sections each add a one-line pointer to it. Fork-local, additive — the default kiln pass is unchanged. Soft "if available" harness gate so it self-degrades off Claude Code.

**Tech Stack:** Markdown skill content only. No code, no runtime deps. `/deep-research` (CC built-in), `kiln-web-search-researcher` (existing agent).

**Web-research:** No external research needed — all components are known and local.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/brainstorming/deep-research-escalation.md` | NEW. Canonical escalation logic: the two gates (high-stakes, available), trigger criteria, announce-and-invoke mechanics, Research Findings tagging. |
| `skills/brainstorming/SKILL.md` | MODIFY. Append a pointer bullet to the "Mandatory Web-Research Pass" section (after line 177). |
| `skills/writing-plans/SKILL.md` | MODIFY. Append a pointer bullet to the "Mandatory Web-Research Pass" section (after line 143). |

This is a docs/skill-content change. There is no automated test harness for skill judgment, so "tests" are deterministic inspection checks (grep / file-exists / link-resolves) plus the manual scenarios in the spec.

---

### Task 1: Create the shared escalation file

**Files:**
- Create: `skills/brainstorming/deep-research-escalation.md`

- [ ] **Step 1: Write the file**

Create `skills/brainstorming/deep-research-escalation.md` with exactly this content:

````markdown
<!-- deep-research-escalation: fork-local -->

# Deep-Research Escalation

Shared logic for the web-research pass in `brainstorming` (step 4) and
`writing-plans`. The `kiln-web-search-researcher` pass runs first and always —
this describes when to AUTO-ESCALATE that unknown to the `/deep-research`
harness (parallel fan-out + adversarial claim verification + cited report).

## When to escalate

After the kiln researcher returns, escalate an unknown to `/deep-research` only
if BOTH gates pass.

**Gate 1 — high-stakes.** The unknown is at least one of:

- **Architecture-deciding** — locks in a hard-to-reverse direction (auth
  library, database, framework, protocol, data model).
- **Contested** — sources are likely to conflict, or recency is decisive
  ("is X still the recommended approach in 2026?").
- **Costly-if-wrong** — security, payments, compliance, auth, or data-loss
  surface.

If none apply, do NOT escalate. Single clear unknowns (a version number, one
documented gotcha) never escalate — kiln already handled them.

**Gate 2 — available.** `/deep-research` is a Claude Code built-in and does not
exist on every harness (Gemini, Copilot, Codex, opencode). Escalate only if
`/deep-research` is available in the current harness. If it is not, stay
kiln-only and say nothing about escalation.

## How to escalate

No user approval. Announce, then invoke:

> Escalating to /deep-research — <one-line why this unknown is high-stakes>.

    Skill(deep-research, args: "<scoped unknown, weaving in the clarifying answers>")

Fold the cited report into the approaches (brainstorming) or task code blocks
(writing-plans). In the `## Research Findings` section, tag which findings came
from `/deep-research` (verified, cited) versus `kiln-web-search-researcher`.
````

- [ ] **Step 2: Verify the file exists and carries the fork-local marker**

Run: `head -1 skills/brainstorming/deep-research-escalation.md`
Expected: `<!-- deep-research-escalation: fork-local -->`

- [ ] **Step 3: Verify both gates are present**

Run: `grep -c "Gate 1 — high-stakes\|Gate 2 — available" skills/brainstorming/deep-research-escalation.md`
Expected: `2`

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/deep-research-escalation.md
git commit -m "feat: shared deep-research escalation logic (fork-local)"
```

---

### Task 2: Point the brainstorming web-research pass at the shared file

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (insert after line 177, before `## Key Principles`)

- [ ] **Step 1: Add the pointer bullet**

In `skills/brainstorming/SKILL.md`, find this line (the last bullet of the "Mandatory Web-Research Pass" section):

```
- When writing the design doc, add a `## Research Findings` section listing each finding with its source URL and retrieval date, or "No external research required for this task."
```

Immediately after it (before the blank line preceding `## Key Principles`), add:

```
- **High-stakes unknowns — auto-escalate.** After the kiln pass returns, if an unknown is high-stakes (architecture-deciding / contested / costly-if-wrong) and `/deep-research` is available, auto-escalate it per `skills/brainstorming/deep-research-escalation.md` — announce and invoke, no user prompt. <!-- deep-research-escalation: fork-local -->
```

- [ ] **Step 2: Verify the pointer resolves to a real file**

Run: `grep -o 'skills/brainstorming/deep-research-escalation.md' skills/brainstorming/SKILL.md | head -1 | xargs test -f && echo OK`
Expected: `OK`

- [ ] **Step 3: Verify the fork-local marker is present in the edit**

Run: `grep -c "deep-research-escalation: fork-local" skills/brainstorming/SKILL.md`
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat: brainstorming web-research pass can escalate to deep-research (fork-local)"
```

---

### Task 3: Point the writing-plans web-research pass at the shared file

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (insert after line 143, before `## Self-Review`)

- [ ] **Step 1: Add the pointer bullet**

In `skills/writing-plans/SKILL.md`, find this line (the last bullet of the "Mandatory Web-Research Pass" section):

```
- Cite verified facts (with source URLs) inline where each external dependency is first used.
```

Immediately after it (before the blank line preceding `## Self-Review`), add:

```
- **High-stakes deps — auto-escalate.** After the kiln pass returns, if a dependency choice is high-stakes (architecture-deciding / contested / costly-if-wrong) and `/deep-research` is available, auto-escalate it per `skills/brainstorming/deep-research-escalation.md` — announce and invoke, no user prompt. <!-- deep-research-escalation: fork-local -->
```

- [ ] **Step 2: Verify the pointer resolves to a real file**

Run: `grep -o 'skills/brainstorming/deep-research-escalation.md' skills/writing-plans/SKILL.md | head -1 | xargs test -f && echo OK`
Expected: `OK`

- [ ] **Step 3: Verify the fork-local marker is present in the edit**

Run: `grep -c "deep-research-escalation: fork-local" skills/writing-plans/SKILL.md`
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "feat: writing-plans web-research pass can escalate to deep-research (fork-local)"
```

---

### Task 4: Final cross-file consistency check

**Files:** (read-only verification)

- [ ] **Step 1: All three files carry the same fork-local marker**

Run: `grep -rl "deep-research-escalation: fork-local" skills/ | sort`
Expected (3 paths):
```
skills/brainstorming/SKILL.md
skills/brainstorming/deep-research-escalation.md
skills/writing-plans/SKILL.md
```

- [ ] **Step 2: Both skills reference the canonical path**

Run: `grep -rc "skills/brainstorming/deep-research-escalation.md" skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md`
Expected: each file reports `1`.

- [ ] **Step 3: Default path untouched — kiln dispatch still present in both**

Run: `grep -c "kiln-web-search-researcher" skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md`
Expected: each file `>= 1` (the original kiln dispatch is unchanged).

No commit — verification only.

---

## Self-Review

**Spec coverage:**
- Shared file (spec §Architecture) → Task 1.
- Two gates / trigger criteria (spec §Trigger criteria, §Harness gate) → Task 1 file content.
- Announce, no approval (spec §Announce mechanics, §Control flow) → Task 1 "How to escalate".
- brainstorming pointer (spec §Affected files) → Task 2.
- writing-plans pointer (spec §Affected files) → Task 3.
- Fork-local marker (spec §Fork-local marking) → Tasks 1-3, checked in Task 4.
- Research Findings tagging (spec §Spec output) → Task 1 file content.
- Testing scenarios (spec §Testing) → deterministic checks in Tasks 1-4; manual judgment scenarios remain manual, noted in File Structure.

No gaps.

**Placeholder scan:** No TBD/TODO. The only `<...>` are intentional template slots inside the skill prose the engineer copies verbatim (e.g. `<one-line why...>`), not plan placeholders.

**Type consistency:** The path `skills/brainstorming/deep-research-escalation.md` and the marker string `deep-research-escalation: fork-local` are identical across Tasks 1-4.
