# Object Structure

## High-level architecture

Single shared state with thin view controllers:

- `GameState` (autoload): canonical simulation state, worker assignments, capture progress, resource economy.
- `TimeSystem` (autoload): cycle stepping and action costs.
- `EventBus` (autoload): decoupled cross-system signaling.

Views are projections over shared state, not separate game modes.

## Scene and script ownership

- `Main` (`scenes/ui/Main.tscn`, `scripts/ui/Main.gd`): shell, tab switching, top HUD, global node-type key.
- `BodyView` (`scenes/body/BodyView.tscn`, `scripts/body/BodyView.gd`): body map interactions, capture/component assignment, vision mask, hover details.
- `EnvironmentView` (`scenes/environment/EnvironmentView.tscn`, `scripts/environment/EnvironmentView.gd`): sensors and placeholder environment task assignment.
- `MindView` (`scenes/mind/MindView.tscn`, `scripts/mind/MindView.gd`): memories plus placeholder mind task assignment.

## Data files

- `data/mind_entries.json`: base memory entries.
- `data/environment_objects.json`: environment object data.
- `data/fragment_conflicts.json`: fragment conflict data.

Body map layout and links are authored directly in scenes (`BodyMap.tscn`) via `linked_node_paths`.

## Body domain classes

### `BodyObject` (abstract)
- Extends: `Node2D`
- Shared fields:
  - `linked_node_paths: Array[NodePath]`
- Shared link logic:
  - `get_linked_body_objects()`
  - `is_connected_to_player_node()`
  - `get_connected_player_node_path()`

### `ThoughtNode` (abstract)
- Extends: `BodyObject`
- Ownership/state:
  - `controlling_entity: int` (`NONE` / `PLAYER`)
  - `is_enabled: bool`
  - `resistance: float` (default sentinel `-1`, randomized to `0.5..3.0` at runtime if unchanged)
  - `concept_name: String`
  - `status: String`
- Signals:
  - `ownership_changed(old_entity, new_entity)`
  - `enabled_changed(enabled)`
  - `status_changed(new_status)`
- Key methods:
  - `set_enabled(...)`
  - `set_controlling_entity(...)`
  - `get_linked_nodes()` (delegates to `BodyObject`)

### `GeometricNode` (abstract)
- Extends: `ThoughtNode`
- Shared implementation for geometric node types:
  - glucose resource behavior
  - visibility and ownership visuals
  - capture-related helper behavior
  - hover/click signals

### `NerveCluster`
- Extends: `GeometricNode`
- Organic rough circle shape + wobble animation.
- Worker type: `neuron_cluster`.

### `ArithmeticProcessor`
- Extends: `GeometricNode`
- Square geometry.
- Worker type: `arithmetic_processor`.

### `QuantumCalculator`
- Extends: `GeometricNode`
- Triangle geometry.
- Worker type: `quantum_calculator`.

### `PhotosyntheticTissue`
- Extends: `BodyObject`
- Placeholder component with worker target:
  - preferred type + multiplier support
  - requires link connection to player node
  - activates at required power and produces food per cycle

### `LinksLayer`
- Extends: `Node2D`
- Draws dynamic links between connected nodes.
- Renders capture progress tint and assigned-worker symbols on links.

### `GridDraw`
- Extends: `Node2D`
- Draws static background grid.

## Worker and task model

Worker pool is global across views.

- Assignment and removal priority logic lives in `GameState`.
- Capture task targets are keyed by target node path.
- Component targets are keyed by component path.
- Named placeholder tasks are used in Environment and Mind views.

Capture specifics:

- requires connectivity to a player-owned source node
- progress accumulates from worker power minus target resistance
- progress decays when no workers are assigned
- completion transfers control at cycle end

## Mind and environment model

### Mind
- Base entries from JSON.
- Dynamic entries can be registered from runtime objects and unlocked into the list.

### Environment
- Sensor-gated visibility based on unlocked sensor set.
- Placeholder worker-assignment task currently exists for vertical slice testing.

## Shared UI helpers

- `WorkerDisplayUtils`: type ordering, worker text formatting, shape generation, canonical icon colors.
- `WorkerIconStrip`: control-space worker icon rendering for panels.
- `WorkerWorldMarkers`: world-space worker icon rendering for links/components.

## Roadmap note

Stress/boost states, fragment personalities, and advanced memory UX are design targets, not fully implemented systems yet. See `IMPLEMENTATION_GAPS.md`.
