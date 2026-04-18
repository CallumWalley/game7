# Implementation Gaps

## Purpose
Track confirmed design/implementation drift, integration risks, and the smallest changes that keep Body, Mind, Environment, UI, and Story coherent.

## Resolved

### Missing implementation-gap reference doc
- Problem: `DESIGN.md`, `README.md`, and `OBJECT_STRUCTURE.md` referenced `IMPLEMENTATION_GAPS.md`, but the file did not exist.
- Fix: created this file and aligned doc references.

### Duplicate component token rendering logic
- Problem: component text token substitution existed in both `GameState` and `MindView`, risking drift between runtime memory rendering and UI rendering.
- Fix: `MindView` now uses `GameState.render_component_text(...)` as SSOT.

### Environment refresh dead local logic
- Problem: `EnvironmentView._refresh()` built sensor/object temporary values that were never consumed.
- Fix: removed dead locals; replaced with `_build_sensor_text()` helper that is actively consumed.

### Body architecture docs mention `GeometricNode`, runtime uses `ThoughtNode`
- Problem: `OBJECT_STRUCTURE.md` described a phantom `GeometricNode` abstract layer; no such class exists.
- Fix: corrected inheritance docs to `ThoughtNode` → `NerveCluster` / `ArithmeticProcessor` / `QuantumCalculator`.

### Fragment conflict autoload ownership — decided: keep stub
- Decision: `FragmentConflictSystem` remains autoloaded as a named stub. Zero runtime callsites; all method bodies return empty/false/zero. Keeping the autoload preserves the global namespace so future code can call `FragmentConflictSystem.get_active_conflicts()` without touching `project.godot`. Risk of misleading architecture is fully mitigated by doc notes in `DESIGN.md`, `README.md`, and `OBJECT_STRUCTURE.md`.
- No further action required until conflict behavior is implemented.

### DebugVisibilityManager ownership split — decided: won't split
- Analysis: the three concerns (UI visibility gating, worker-type encounter tracking, debug runtime options) are correctly co-owned by one manager — they are all developer-controlled state that the panel `DebugVisibilityPanel.gd` consumes together. Signals are already distinct (`visibility_changed`, `debug_mode_changed`, `option_changed`). Internal dictionary separation is sufficient. Splitting to two autoloads would add file/callsite overhead with no coherence improvement.
- `_match_option_to_system()` is the only coupling point outward (routes `push_scroll` and `log_food_ticks` back to GameState); this is intentional and correct.

### Environment panel progression routing — moved off the right-hand task UI
- Analysis: the environment sidebar is now reserved for sensor filter controls only. Sensor existence is driven by `ProgressionSystem` stage unlocks, and environment discoveries advance through `EnvironmentMap.gd` proximity observation rather than a dedicated observe/decode panel.

### Environment map was static art — implemented first data-driven system map
- Problem: Environment map visuals were authored as static polygons with no object-space data and no player-centric navigation model.
- Fix: `data/environment_objects.json` now includes `system_id`, `kind`, `map_position`, `observability_profile` (`radio`, `heat`, `light`, `gamma`, `gravity`), and `is_observable`. `EnvironmentMap.gd` now builds `system0` objects from this data, owns player movement physics state, and publishes it to `EnvironmentView` for player-centered fixed-orientation camera behavior.

## Current Gaps

### Fragment conflict loop — implemented
- Systems: Story, Body, Mind, shared-state progression
- Files: `autoload/FragmentConflictSystem.gd`, `data/fragment_conflicts.json`, `data/mind_entries.json`, `autoload/ProgressionSystem.gd`
- Status: implemented
- Loop: `_load_conflicts()` reads `fragment_conflicts.json` on ready; `_on_state_changed()` is subscribed to `GameState.state_changed` and calls `_try_activate_conflict()` for any un-activated, un-resolved conflict; activation requires `required_memory` in `GameState.unlocked_memories` AND `GameState.cycle >= trigger_cycle`; on activation: `GameState.mark_node_contested(node_id)` + `GameState.unlock_memory("conflict_<id>")` + `EventBus.fragment_node_contested.emit(node_id)`; `resolve_conflict(node_id)` clears contested state, unlocks `"conflict_<id>_resolved"` memory entry, and emits `EventBus.fragment_node_stabilized`.
- ProgressionSystem stage gating: `_compute_body_progress_stage()` now deducts contested node count from `unlocked_body_count`, so contested body regions cannot advance body stage until resolved.
- Mind narrative: conflict activation and resolution each unlock a corresponding `mind_entries.json` entry surfaced in MindView (e.g. "Fracture Echo", "Fracture Echo — Stabilized").
- Remaining gap: `BodyView` map does not surface contested state visually. The contested node IDs (`sensor_array`, `nav_core`) are abstract progression keys; map-level coloring requires a mapping from progression ID to scene node identity.

### Observation → memory recall loop — verified working
- The pipeline is fully wired: `EnvironmentView._observe_next()` → `ObservationSystem.observe_object()` → `ProgressionSystem.record_environment_observation()` → `GameState.record_observation()` + `GameState.unlock_memory()` + `EventBus.environment_observed.emit()`. Environment object data in `environment_objects.json` carries `reveals_memories` entries that match IDs in `mind_entries.json`. No implementation work needed.

## Integration Sequencing

1. **Fragment conflict → Body visual mapping** — the only remaining fragment conflict gap. `GameState.contested_body_nodes` holds abstract progression keys (`sensor_array`, `nav_core`). Body map ThoughtNodes are identified by scene node `name`. A mapping from progression key → on-map scene name is needed before contested state can color or badge nodes on the body map. Lowest-urgency gap since MindView already surfaces conflict text entries when activated. Files: `scripts/body/BodyView.gd`, `scripts/body/ThoughtNode.gd`, `data/fragment_conflicts.json` (add `scene_node_name` field).

2. **Continue SSOT cleanup** opportunistically when duplication is visible during active feature work.
