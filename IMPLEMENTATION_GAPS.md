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

## Implemented

### Component memory progression (states 0 / 1 / 2)
- `data/component_mind_entries.json`: SSOT for all component entry configs — state content, variable gates, `{token}` substitutions.
- `GameState`: tracks `component_memory_states`, `component_memory_vars`, `_component_first_hovered`, `_component_properties` per `component_type_id`. Key functions: `on_component_first_hovered`, `on_component_captured`, `set_component_memory_var`, `get_component_memory_var`, `register_component_properties`, `get_component_property`, `get_controlled_component_count`.
- Trigger state 1: first hover → `GameState.on_component_first_hovered` (called from `BodyView._on_component_hovered`).
- Trigger state 2: activation → `GameState.report_component_controlled` → `on_component_captured`.
- `MindView`: renders `text_segments` arrays with inline `{token}` substitution for live runtime values.
- `MindView`: typewriter variable gate via `VariableSelector` (OptionButton) — display stops at an unresolved `variable` segment; continues after player picks an option from the dropdown.
- Adding new entries: add `component_type_id` export + `register_component_properties` call on the component script, then add a JSON entry in `data/component_mind_entries.json`. No further code changes required. See `DESIGN.md` for full schema.

### Memory unread state and read tracking
- `GameState.memory_read_state: Dictionary` maps entry id → bool (true = read).
- `GameState.mark_memory_read(id)` / `is_memory_read(id)` expose read state.
- `GameState._set_component_memory_state` calls `_clear_component_memory_read_state` before emitting `state_changed` — state advancement always resets the entry to unread.
- `MindView._populate_list` colours unread items with `UNREAD_COLOR` (amber). Colour reverts to white on read via `_update_list_item_read_state`.

### Typewriter animation
- Character-by-character reveal driven by `_process` in `MindView` using `RichTextLabel.visible_characters`.
- Speed tunable via `TYPEWRITER_SPEED` constant (default 40 chars/sec).
- Animation only runs when `MindView.is_visible_in_tree()` — pauses while the tab is hidden, resumes when the player opens Mind view.
- Completing animation with no pending variable gate calls `mark_memory_read` and updates the list colour.
- Guard in `_display_entry`: if the same entry is already animating, the call is a no-op (prevents `state_changed` side effects from restarting the animation mid-read).
- `EventBus.component_memory_state_changed` forces a display restart so state-1 → state-2 transition while the entry is visible plays the new text immediately.
- User clicking a different entry (or the same entry again via `_on_entry_selected`) sets `_typewriter_active = false` before calling `_display_entry`, bypassing the guard and starting fresh.

### Component mind entry image
- `polygon_verts`, `fill_color`, `outline_color` stored at the component level in `data/component_mind_entries.json`.
- `GameState.get_component_shape_data(type_id)` returns a typed dict with `PackedVector2Array` verts and `Color` values.
- `scripts/mind/ComponentShapePreview.gd`: minimal `Control` subclass that overrides `_draw()` to fill-and-outline the polygon, scaled to fit the control rect with 0.82 padding.
- Added as a node in `MindView.tscn` with `custom_minimum_size = Vector2(0, 100)`, visible only when the selected entry has a `component_type_id`.

### MindView entry selection persistence on refresh
- `_refresh_entries` records the currently selected entry id via `_get_selected_entry_id()` before rebuilding the list.
- After `_populate_list()`, `_find_entry_index_by_id()` locates the same entry and re-selects it.
- Falls back to index 0 if the entry was removed (e.g., hidden by a state rollback).

## Missing pieces needed for full system

1. Advanced node energy states (sleep/normal/boost)
- Need: design specifies richer state model than current enabled/disabled toggle.
- Proposed implementation:
  - Replace boolean `is_enabled` with enum state + boost level.
  - Recompute food request/power from state model.
  - Add input rules for single-click wake and double-click boost.

6. Fragment competition model
- Need: non-player fragment behavior and control contests.
- Proposed implementation:
  - Add fragment entities in `GameState`.
  - Implement pressure accumulation/decay in `FragmentConflictSystem`.
  - Expose fragment state overlays in Body view.

## Easily implementable next items

1. Show resistance in non-debug hover text for unowned targets.
2. Add sorting or compact grouping option for worker icon strips when counts get large.

## Reuse-first extensible environment framework (proposed)

Goal: keep Environment mechanics fully data-driven while reusing `GameState`, `TimeSystem`, `EventBus`, `ObservationSystem`, and `ProgressionSystem` as the only cross-view authorities.

### Core principles

1. One generic task model in `GameState`
- Continue using `worker_targets` as the shared task authority for capture, components, and environment actions.
- Add task metadata fields instead of new parallel managers (`domain`, `action_id`, `target_ref`, `completion_payload`).
- Keep worker assignment, power math, and progress rules in one place.

2. One condition evaluator for all gates
- Replace duplicate condition evaluation in `ObservationSystem` with shared `ConditionEvaluator` usage.
- Use the same condition schema for body unlocks, environment visibility, observations, and progression triggers.

3. Event-driven progression only
- Keep `EventBus` as the boundary between systems.
- Environment systems emit facts (`environment_object_spotted`, `environment_object_observed`, `sensor_strength_changed`) and `ProgressionSystem` translates facts into unlocks.
- Avoid direct unlock writes from view scripts.

4. Data-first environment definitions
- Extend `data/environment_objects.json` entries with optional movement/sensor/observation fields:
  - `visibility_rule`
  - `observation_rule`
  - `movement_rule`
  - `on_observed` (memory unlocks, sensor unlocks, body node unlock hooks)
- Keep `EnvironmentView` as a presenter and input adapter, not a rules owner.

### Decisions locked for current milestone

1. Sensor tiers use integers.
- Tier `0` means unavailable.
- Tier `1+` means available and can satisfy per-object minimum requirements.

2. Movement spends cycles only.
- Movement itself consumes cycle cost (`TimeSystem` action cost).
- Any prerequisite component operation (for example, route plotting or stabilization) can still require workers via normal `GameState.worker_targets` tasks.

3. Observation payload contract (`on_observed`)
- `unlock_memories: Array[String]`
- `unlock_body_nodes: Array[String]`
- `unlock_sensors: Array[String]` (grants tier 1)
- `sensor_tiers: Dictionary[String, int]` (explicit tier upgrades)
- Payload is interpreted only by `ProgressionSystem` to keep one progression authority.

### Ownership model by system

1. `GameState`
- Owns canonical environment runtime state:
  - discovered objects
  - observed objects
  - sensor strengths (not only unlocked boolean)
  - current environment position/node
  - active environment tasks in `worker_targets`

2. `ObservationSystem`
- Owns evaluation of object visibility and observability.
- Reads object definitions and asks `ConditionEvaluator` to evaluate rules.
- Emits observation domain events through `EventBus`.

3. `TimeSystem`
- Owns cycle costs for environment actions (`scan`, `observe`, `move`, `stabilize`).
- No environment rule logic beyond time cost accounting.

4. `ProgressionSystem`
- Subscribes to EventBus environment events.
- Applies unlock consequences (mind entries, sensors, body node gates).
- Keeps all cross-domain progression consequences centralized.
- Owns progression fact tracking (`progression_flags`) so Body, Environment, and Mind can query a single progression authority.

5. `EnvironmentView`
- Reads projected state and sends intents only:
  - toggle sensor mode
  - assign/remove workers on environment tasks
  - observe selected object
  - move to adjacent environment node
- Never directly computes unlock/visibility outcomes.

### Minimal implementation phases

1. De-duplicate condition logic
- Move environment requirement checks to `ConditionEvaluator` and delete local duplicate evaluator from `ObservationSystem`.

2. Promote sensors from boolean unlocks to strength tiers
- Keep backward compatibility by treating unlocked sensors as strength >= 1.
- Add optional per-object minimum sensor strength requirements.

3. Add environment graph + movement gating
- New data file for environment nodes/edges and movement requirements.
- Reuse `TimeSystem.spend_for_action("move")` and `ConditionEvaluator` for move validity.

4. Convert observe flow to explicit intents and events
- `EnvironmentView` sends observe intent for a selected object id.
- `ObservationSystem` validates and emits `environment_observed`.
- `ProgressionSystem` resolves `on_observed` payload.

5. Hook observation outcomes to progression payloads
- Data payload supports memory unlocks, sensor upgrades, body node unlock requests, and fragment pressure changes.

### Why this fits the current codebase

1. Reuses existing worker/task infrastructure in `GameState` instead of creating an environment-only assignment system.
2. Reuses existing action cost path in `TimeSystem`.
3. Reuses existing event topology in `EventBus`.
4. Preserves the design rule that Body, Environment, and Mind are projections over one shared simulation state.
