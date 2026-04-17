# Implementation Gaps and Resolutions

This file tracks contradictions, missing pieces, and concrete proposals.

## Contradictions found and proposed resolutions

1. Document naming mismatch
- Issue: some docs referenced `story.md` while file is `STORY.md`.
- Resolution: normalize references to `STORY.md`.

2. Body-local key vs global key
- Issue: Body had an extra key panel while Main already had global key.
- Resolution: remove Body-local key and keep global key as single source.

3. Icon style drift
- Issue: world worker markers differed from key icons.
- Resolution: shared icon geometry + color + stroke helpers now drive all worker icon contexts.

## Missing pieces needed for full system

1. Component level progression system
- Need: components with multi-threshold levels, first-time unlock events, unread memory updates.
- Proposed implementation:
  - Add `component_type_id` and `level_thresholds` to component scripts/data.
  - Add `GameState.component_type_counts` and `component_levels_unlocked`.
  - Evaluate thresholds at cycle end and emit unlock events.
  - On new level, register/update dynamic mind entry and mark unread.

2. Memory unread state and read tracking
- Need: unread highlighting and mark-as-read behavior.
- Proposed implementation:
  - Add `GameState.memory_read_state: Dictionary[id -> bool]`.
  - `MindView` marks selected entry as read.
  - Dynamic updates reset read state to unread.

3. Typewriter reveal for first read
- Need: first-read staged text reveal.
- Proposed implementation:
  - Add per-entry reveal coroutine in `MindView`.
  - Gate by read-state and skip on already-read entries.

4. Advanced node energy states (sleep/normal/boost)
- Need: design specifies richer state model than current enabled/disabled toggle.
- Proposed implementation:
  - Replace boolean `is_enabled` with enum state + boost level.
  - Recompute food request/power from state model.
  - Add input rules for single-click wake and double-click boost.

5. Fragment competition model
- Need: non-player fragment behavior and control contests.
- Proposed implementation:
  - Add fragment entities in `GameState`.
  - Implement pressure accumulation/decay in `FragmentConflictSystem`.
  - Expose fragment state overlays in Body view.

## Easily implementable next items

1. Show resistance in non-debug hover text for unowned targets.
2. Add component hover card with required power/current power/connected status.
3. Add sorting or compact grouping option for worker icon strips when counts get large.
