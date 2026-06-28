# Team Mode (experimental, fork-local)

<!-- superpowers-teams: fork-local -->

Optional multi-agent **debate** layer for the exploration step of
`brainstorming`, `systematic-debugging`, and `requesting-code-review`. Gated
behind an env flag, so it is inert unless explicitly enabled. SP6 has no
equivalent: `dispatching-parallel-agents` scopes *independent* parallel work;
Team Mode adds *cross-challenging* perspectives that argue with each other.

## Activation

Active only when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set. If it is unset,
ignore Team Mode entirely and run the host step solo. When it is set, **always
spawn a team** for the host step — even if the topic, bug, or diff seems small.

**REQUIRED SUB-SKILL:** use `superpowers:dispatching-parallel-agents` for how to
scope and dispatch the teammates concurrently.

## The pattern

1. The lead decides team size and the distinct roles/lenses from the context.
2. Teammates work in parallel and **actively challenge each other**
   (scientific-debate style) — the goal is to disprove, not to agree.
3. The lead synthesizes the debate into the single output the host step expects.
4. Every gate, law, and approval the host skill already enforces still applies,
   unchanged.

## Per-host variants

| Host skill | Run as a team | Roles / lenses | Spawn when | Lead synthesizes into | Invariants kept |
|---|---|---|---|---|---|
| **brainstorming** | the approach-exploration step (checklist 5) | UX, technical architecture, devil's advocate | after clarifying questions + the web-research pass, before converging on a design | the 2-3 approaches + the design presented to the user | HARD-GATE, per-section approval, spec write, user review, writing-plans handoff |
| **systematic-debugging** | Phase 3 (competing hypotheses — fights anchoring) | one hypothesis per teammate, drawn from the candidate causes | after Phase 1 reproduction is confirmed, before locking a root cause | the surviving hypothesis, carried into Phase 4 unchanged | Iron Law: no fixes until the root cause is found |
| **requesting-code-review** | the review itself | security, performance, correctness, test coverage | any diff | one report with the usual Critical/Important/Minor severities | every lens evaluates the same `BASE_SHA..HEAD_SHA`; teammates debate overlaps before the lead merges |
