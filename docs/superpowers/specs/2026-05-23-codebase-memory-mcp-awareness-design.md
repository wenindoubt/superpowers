# Design: codebase-memory-mcp awareness in superpowers (fork-local)

**Date:** 2026-05-23
**Status:** Approved, ready for implementation plan

## Problem

`codebase-memory-mcp` provides a knowledge-graph over indexed repos (`search_graph`, `trace_path`, `get_code_snippet`, `query_graph`, `get_architecture`, `search_code`, `index_repository`/`index_status`/`detect_changes`). It is faster, more token-efficient, and more accurate than `Grep`/`Read` for code discovery.

The **main agent** is already steered toward it by global harness config:
- `PreToolUse` hook on `Grep|Glob|Read|Search` (`cbm-code-discovery-gate`) blocks the first such call per session and nudges to the MCP.
- `SessionStart` (`cbm-session-reminder`) injects a "Code Discovery Protocol" reminder.

**Gap — subagents are not steered:**
- The gate keys on `$PPID`. Subagents (Task tool) share the main process PPID + gate file, so after the main session trips the gate once, every subagent gets `exit 0` (allowed) and is never nudged.
- `SessionStart:startup` does not fire for Task dispatches.
- The `using-superpowers` bootstrap explicitly `<SUBAGENT-STOP>`s, so subagents skip it.

Superpowers dispatches `general-purpose` subagents (which have all tools, including the MCP) via prompt templates that say "read the code" with zero mention of the graph. Process skills (brainstorming, debugging, writing-plans) also drive code exploration without mentioning it.

## Goal

Bake awareness of `codebase-memory-mcp` into superpowers content so subagents and process-skill flows prefer it for code discovery — while degrading cleanly for users/harnesses without the MCP, and surviving upstream resync.

Non-goal: replace `Grep`/`Read`. The MCP is a preferred option, not a mandate. No change to the existing hooks.

## Approach

One canonical, concise block, **inlined** at each insertion point.

Rejected alternatives:
- Shared-file-pointer: breaks the subagent self-containment rule ("provide full text, don't make subagent read a file").
- Verbose per-site custom text: token bloat and drift risk.

### Canonical block (graceful, fork-local)

> **Exploring code:** If `codebase-memory-mcp` tools are available, prefer them over reading files for code discovery — faster, more token-efficient, more accurate: `search_graph` (find funcs/classes/routes), `trace_path` (call chains / data flow), `get_code_snippet` (read source by qualified name), `get_architecture` (structure), `search_code` (graph-augmented grep). If the repo isn't indexed, run `index_repository` first (`index_status` to check). Fall back to Grep/Glob/Read for text/config/unindexed code.

Voice adapts per site: imperative inside subagent prompts, descriptive in process-skill prose. "If available … else fall back" phrasing everywhere.

### Insertion points (6 files)

| File | Where | Audience |
|---|---|---|
| `skills/subagent-driven-development/implementer-prompt.md` | inside fenced prompt, near "Code Organization" | implementer subagent |
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | inside fenced prompt, at the "Read the actual code" verification block | spec reviewer subagent |
| `skills/requesting-code-review/code-reviewer.md` | in the reviewer template body (covers the subagent code-quality reviewer AND requesting-code-review, both route through this file) | review subagents |
| `skills/dispatching-parallel-agents/SKILL.md` | "Agent Prompt Structure" section | parallel agents |
| `skills/brainstorming/SKILL.md` | "Working in existing codebases" / "Explore project context" | main agent (reinforces hook) |
| `skills/systematic-debugging/SKILL.md` | the code-exploration / reproduction-investigation step | main agent |
| `skills/writing-plans/SKILL.md` | the codebase-exploration / research pass | main agent |

(6 files; the table's code-reviewer.md row collapses two audiences into one edit.)

### Conventions

- **Inside fenced subagent prompts:** insert the instruction text only (clean for the subagent). Place the `<!-- codebase-memory-mcp: fork-local -->` marker on a markdown line *outside* the fence.
- **In SKILL.md prose:** insert the block with an adjacent `<!-- codebase-memory-mcp: fork-local -->` marker (matching the existing `<!-- superpowers-teams: fork-local -->` convention).
- Every instance uses "if available … else fall back" so it is a no-op for environments without the MCP.

## Testing / verification

- Grep confirms the fork-local marker + block present in all 7 locations (6 files).
- Manual read of each fenced subagent prompt confirms the block sits inside the fence and reads cleanly as an instruction.
- No existing fenced-prompt structure broken (templates still valid).
- Note: behavioral eval (does a dispatched subagent actually call the MCP?) is out of scope for this edit; the change is additive guidance, not a tuned behavior-shaping rewrite.

## Research Findings

No external research required for this task — `codebase-memory-mcp` is local/internal tooling with no external API/version unknowns.

## Notes

Fork-local only. Do NOT upstream — superpowers core is zero-dependency and MCP-agnostic; this depends on the user's local MCP + hooks.
