# codebase-memory-mcp Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inject one canonical, graceful, fork-local "prefer codebase-memory-mcp for code discovery" block into 7 superpowers skill files so dispatched subagents and process-skill flows leverage the knowledge graph.

**Architecture:** Same ~5-line block at each site, adapted in voice (imperative inside fenced subagent prompts, descriptive in SKILL.md prose). Every instance is conditioned on "if available … else fall back to Grep/Read" so it is a no-op for environments without the MCP. Each file carries a `<!-- codebase-memory-mcp: fork-local -->` marker (matching the existing `<!-- superpowers-teams: fork-local -->` convention) placed OUTSIDE fenced prompt blocks so subagent prompts stay clean.

**Tech Stack:** Markdown skill files only. No code, no tests-as-such — verification is grep/read structural checks.

**Web research:** No external dependencies — `codebase-memory-mcp` is local/internal tooling. No external research needed.

**Scope correction:** Spec doc said "6 files"; it is actually 7 distinct files (the code-reviewer.md row serves two audiences but is one file). This plan has 7 tasks, one per file.

**Canonical block (verbatim — reused in all tasks, voice-adapted):**

> If `codebase-memory-mcp` tools are available, prefer them over reading files for code discovery — faster, more token-efficient, more accurate: `search_graph` (find funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet` (read source by qualified name), `get_architecture` (structure), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

All file paths relative to repo root `/Users/wenje/Documents/repositories/superpowers`.

---

### Task 1: implementer-prompt.md (implementer subagent)

**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md`

- [ ] **Step 1: Add fork-local marker outside the fenced prompt**

Edit. Find:
```
Use this template when dispatching an implementer subagent.

```
```
Replace with:
```
Use this template when dispatching an implementer subagent.

<!-- codebase-memory-mcp: fork-local — the "Exploring the Codebase" block inside the prompt below is fork-local guidance -->

```
```
(Note: the third line above is the opening ``` of the prompt fence — preserve it.)

- [ ] **Step 2: Insert the exploration block inside the fenced prompt**

Edit. Find (the end of the Code Organization list, indented 4 spaces inside the prompt):
```
    - In existing codebases, follow established patterns. Improve code you're touching
      the way a good developer would, but don't restructure things outside your task.

    ## When You're in Over Your Head
```
Replace with:
```
    - In existing codebases, follow established patterns. Improve code you're touching
      the way a good developer would, but don't restructure things outside your task.

    ## Exploring the Codebase

    If `codebase-memory-mcp` tools are available, prefer them over reading files for
    code discovery — faster, more token-efficient, more accurate: `search_graph` (find
    funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet`
    (read source by qualified name), `get_architecture` (structure), `search_code`
    (graph-augmented grep). If the repo isn't indexed, run `index_repository` first
    (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

    ## When You're in Over Your Head
```

- [ ] **Step 3: Verify marker and block present, fence intact**

Run: `grep -n "codebase-memory-mcp: fork-local\|## Exploring the Codebase\|search_graph" skills/subagent-driven-development/implementer-prompt.md`
Expected: 3+ matches (marker line, the new heading, the search_graph mention).

Run: `awk '/^```$/{c++} END{print c}' skills/subagent-driven-development/implementer-prompt.md`
Expected: `2` (one opening, one closing fence — unchanged count).

- [ ] **Step 4: Commit**

```bash
git add skills/subagent-driven-development/implementer-prompt.md
git commit -m "feat: prefer codebase-memory-mcp in implementer subagent prompt (fork-local)"
```

---

### Task 2: spec-reviewer-prompt.md (spec reviewer subagent)

**Files:**
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md`

- [ ] **Step 1: Add fork-local marker outside the fenced prompt**

Edit. Find:
```
Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify implementer built what was requested (nothing more, nothing less)
```
Replace with:
```
Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify implementer built what was requested (nothing more, nothing less)

<!-- codebase-memory-mcp: fork-local — the "Reading the Code Efficiently" block inside the prompt below is fork-local guidance -->
```

- [ ] **Step 2: Insert the exploration block inside the fenced prompt**

Edit. Find (the DO list end + Your Job heading, indented 4 spaces):
```
    - Look for extra features they didn't mention

    ## Your Job
```
Replace with:
```
    - Look for extra features they didn't mention

    ## Reading the Code Efficiently

    If `codebase-memory-mcp` tools are available, prefer them over reading files for
    code discovery — faster, more token-efficient, more accurate: `search_graph` (find
    funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet`
    (read source by qualified name), `get_architecture` (structure), `search_code`
    (graph-augmented grep). If the repo isn't indexed, run `index_repository` first
    (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

    ## Your Job
```

- [ ] **Step 3: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|## Reading the Code Efficiently\|search_graph" skills/subagent-driven-development/spec-reviewer-prompt.md`
Expected: 3+ matches.

Run: `awk '/^```$/{c++} END{print c}' skills/subagent-driven-development/spec-reviewer-prompt.md`
Expected: `2`.

- [ ] **Step 4: Commit**

```bash
git add skills/subagent-driven-development/spec-reviewer-prompt.md
git commit -m "feat: prefer codebase-memory-mcp in spec-reviewer subagent prompt (fork-local)"
```

---

### Task 3: code-reviewer.md (code-quality + requesting-code-review subagents)

**Files:**
- Modify: `skills/requesting-code-review/code-reviewer.md`

- [ ] **Step 1: Add fork-local marker outside the fenced prompt**

Edit. Find:
```
**Purpose:** Review completed work against requirements and code quality standards before it cascades into more work.

```
```
Replace with:
```
**Purpose:** Review completed work against requirements and code quality standards before it cascades into more work.

<!-- codebase-memory-mcp: fork-local — the "Reading the Code" block inside the prompt below is fork-local guidance -->

```
```
(The trailing ``` is the opening fence of the prompt — preserve it.)

- [ ] **Step 2: Insert the exploration block inside the fenced prompt, after the git diff range**

Edit. Find (indented 4 spaces inside the prompt):
```
    ```bash
    git diff --stat {BASE_SHA}..{HEAD_SHA}
    git diff {BASE_SHA}..{HEAD_SHA}
    ```

    ## What to Check
```
Replace with:
```
    ```bash
    git diff --stat {BASE_SHA}..{HEAD_SHA}
    git diff {BASE_SHA}..{HEAD_SHA}
    ```

    ## Reading the Code

    Use git for the diff itself. To understand the surrounding code (callers, definitions,
    structure), if `codebase-memory-mcp` tools are available, prefer them over reading files —
    faster, more token-efficient, more accurate: `search_graph` (find funcs/classes/routes),
    `trace_path` (call chains / data flow, e.g. who calls a changed function),
    `get_code_snippet` (read source by qualified name), `get_architecture` (structure),
    `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository`
    first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

    ## What to Check
```

- [ ] **Step 3: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|## Reading the Code\|trace_path" skills/requesting-code-review/code-reviewer.md`
Expected: 3+ matches.

Run: `awk '/^    ```bash$/{b++} /^    ```$/{c++} /^```$/{f++} END{print "outer="f}' skills/requesting-code-review/code-reviewer.md`
Expected: `outer=2` (outer prompt fence still balanced; the inner ```bash block we added near is unchanged).

- [ ] **Step 4: Commit**

```bash
git add skills/requesting-code-review/code-reviewer.md
git commit -m "feat: prefer codebase-memory-mcp in code-reviewer subagent prompt (fork-local)"
```

---

### Task 4: dispatching-parallel-agents/SKILL.md (parallel agents)

**Files:**
- Modify: `skills/dispatching-parallel-agents/SKILL.md`

- [ ] **Step 1: Add a guidance bullet + marker in "Agent Prompt Structure"**

Edit. Find:
```
Good agent prompts are:
1. **Focused** - One clear problem domain
2. **Self-contained** - All context needed to understand the problem
3. **Specific about output** - What should the agent return?
```
Replace with:
```
Good agent prompts are:
1. **Focused** - One clear problem domain
2. **Self-contained** - All context needed to understand the problem
3. **Specific about output** - What should the agent return?

<!-- codebase-memory-mcp: fork-local -->
**Tell the agent how to explore.** When the dispatched agent will read code, include this in its prompt: if `codebase-memory-mcp` tools are available, prefer them over reading files for code discovery — faster, more token-efficient, more accurate: `search_graph` (find funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet` (read source by qualified name), `get_architecture` (structure), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.
```

- [ ] **Step 2: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|Tell the agent how to explore\|search_graph" skills/dispatching-parallel-agents/SKILL.md`
Expected: 3+ matches.

- [ ] **Step 3: Commit**

```bash
git add skills/dispatching-parallel-agents/SKILL.md
git commit -m "feat: tell dispatched agents to prefer codebase-memory-mcp (fork-local)"
```

---

### Task 5: brainstorming/SKILL.md (main agent — context exploration)

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1: Add a bullet + marker under "Working in existing codebases"**

Edit. Find:
```
**Working in existing codebases:**

- Explore the current structure before proposing changes. Follow existing patterns.
```
Replace with:
```
**Working in existing codebases:**

<!-- codebase-memory-mcp: fork-local -->
- Explore the current structure before proposing changes. Follow existing patterns. If `codebase-memory-mcp` tools are available, prefer them for this exploration — faster, more token-efficient, more accurate: `get_architecture` (structure overview), `search_graph` (find funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet` (read source by qualified name), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.
```

- [ ] **Step 2: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|get_architecture" skills/brainstorming/SKILL.md`
Expected: 2+ matches.

- [ ] **Step 3: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat: prefer codebase-memory-mcp for brainstorming code exploration (fork-local)"
```

---

### Task 6: systematic-debugging/SKILL.md (main agent — investigation)

**Files:**
- Modify: `skills/systematic-debugging/SKILL.md`

- [ ] **Step 1: Add an investigation-aid note + marker in Phase 1**

Edit. Find:
```
### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
```
Replace with:
```
### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

<!-- codebase-memory-mcp: fork-local -->
**Locating code during investigation:** If `codebase-memory-mcp` tools are available, prefer them for tracing the bug — faster, more token-efficient, more accurate: `search_graph` (find the failing func/class/route), `trace_path` (call chains / data flow to follow how a value reaches the failure), `get_code_snippet` (read source by qualified name), `get_architecture` (structure), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

1. **Read Error Messages Carefully**
```

- [ ] **Step 2: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|Locating code during investigation\|trace_path" skills/systematic-debugging/SKILL.md`
Expected: 3+ matches.

- [ ] **Step 3: Commit**

```bash
git add skills/systematic-debugging/SKILL.md
git commit -m "feat: prefer codebase-memory-mcp for debugging investigation (fork-local)"
```

---

### Task 7: writing-plans/SKILL.md (main agent — file-structure mapping)

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1: Add a note + marker under "File Structure"**

Edit. Find:
```
## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.
```
Replace with:
```
## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

<!-- codebase-memory-mcp: fork-local -->
When mapping an existing codebase, if `codebase-memory-mcp` tools are available, prefer them over reading files — faster, more token-efficient, more accurate: `get_architecture` (structure / packages), `search_graph` (find funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet` (read source by qualified name), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.
```

- [ ] **Step 2: Verify**

Run: `grep -n "codebase-memory-mcp: fork-local\|get_architecture" skills/writing-plans/SKILL.md`
Expected: 2+ matches.

- [ ] **Step 3: Commit**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "feat: prefer codebase-memory-mcp for writing-plans file mapping (fork-local)"
```

---

## Final Verification (after all tasks)

- [ ] **Confirm all 7 files carry the marker**

Run:
```bash
grep -rl "codebase-memory-mcp: fork-local" skills/ | sort
```
Expected — exactly these 7 files:
```
skills/brainstorming/SKILL.md
skills/dispatching-parallel-agents/SKILL.md
skills/requesting-code-review/code-reviewer.md
skills/subagent-driven-development/implementer-prompt.md
skills/subagent-driven-development/spec-reviewer-prompt.md
skills/systematic-debugging/SKILL.md
skills/writing-plans/SKILL.md
```

- [ ] **Confirm the two subagent prompt fences stayed balanced**

Run:
```bash
for f in skills/subagent-driven-development/implementer-prompt.md skills/subagent-driven-development/spec-reviewer-prompt.md; do echo "$f: $(awk '/^```$/{c++} END{print c}' "$f") closing-level fences"; done
```
Expected: each reports `2`.
