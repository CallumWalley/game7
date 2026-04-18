# Agent Routing Guide

Use this folder as the source of truth for which specialist should handle a task.

## Quick Pick

- Body mechanics, node logic, components, fragments, resources: `Body Systems`
- Mind progression, memories, codex or journal state, unlock tracking: `Mind Systems`
- Sensors, environment map, movement, observations, environment progression hooks: `Environment Systems`
- UI hierarchy, HUD consistency, hover cards, link or node readability, WorkerBench visuals: `UI Leader`
- Story beats, tone, naming continuity, terminology canon: `Story Consultant`
- Multi-system integration, sequencing across specialists, documentation alignment: `Leader`

## Routing Rules

1. If one system owns the mechanic and UI is secondary, route to that system specialist.
2. If readability, hierarchy, icon consistency, or signal clarity is the main problem, route to `UI Leader`.
3. If wording, tone, beat timing, or term consistency is the main problem, route to `Story Consultant`.
4. If multiple systems need coordinated change or docs must be reconciled, route to `Leader`.

## Escalation Pattern

- Start with one specialist agent whenever possible.
- Escalate to `Leader` when ownership is ambiguous or changes must be staged across systems.
- After major behavior changes, update docs in the same pass to keep implementation state legible.