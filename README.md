# Awakening Vessel

Godot 4 prototype for a narrative systems game about rebuilding cognition and control.

## Project docs

- `DESIGN.md`: game design intent, mechanics, and priorities.
- `UI.md`: UX layout, interaction language, and presentation rules.
- `OBJECT_STRUCTURE.md`: runtime architecture, class ownership, and data flow.
- `STORY.md`: narrative direction and tonal guidance.
- `IMPLEMENTATION_GAPS.md`: contradictions, missing pieces, and implementation proposals.

## Current implemented slice

- Shared `GameState` across Mind/Body/Environment tabs.
- Cycle simulation with food economy and per-node glucose.
- Worker-placement system with typed workers:
	- `NeuronCluster` (circle)
	- `ArithmeticProcessor` (square)
	- `QuantumCalculator` (triangle)
- Capture tasks on unowned nodes with resistance and link-based progress visualization.
- Placeholder component (`PhotosyntheticTissue`) with worker assignment and food output when activated.
- Global left-side key showing idle/total by worker type in all views.
- Mind entries from JSON plus dynamic runtime entries unlocked on first control of node/component types.

## Run

1. Open this repository root in Godot 4.
2. Verify autoloads exist:
	 - `GameState`
	 - `TimeSystem`
	 - `EventBus`
	 - `ProgressionSystem`
	 - `ObservationSystem`
	 - `FragmentConflictSystem`
3. Run `res://scenes/ui/Main.tscn`.

## Status note

This repo is intentionally hybrid: core worker/capture loop is implemented, while several narrative and progression systems are still placeholder-level. See `IMPLEMENTATION_GAPS.md` for the exact delta.
