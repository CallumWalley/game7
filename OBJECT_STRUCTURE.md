# Object Structure Proposal

## High-level architecture

Use one global game state source of truth with lightweight feature controllers:

- `GameState` (autoload): canonical world + progression state.
- `TimeSystem` (autoload): cycle costs and pacing rules.
- `EventBus` (autoload): decoupled notifications between tabs.

UI tabs should be *views over shared state*, not isolated mini-games. Each view dispatches intent, systems mutate state, then views refresh.

## Scene + script ownership

- `Main` scene/script: shell, tab navigation, top-level HUD (cycle counter).
- `MindView`: journal/wiki rendering, timeline filtering, memory links.
- `BodyView`: ship node graph exploration, repair/unlock actions, thought queue.
- `EnvironmentView`: map overlays and interactions constrained by unlocked sensors.

## Data model (recommended)

Create data-driven content files for narrative iteration:

- `mind_entries.json`: memory records.
- `environment_objects.json`: map objects with required sensors and outcomes.
- `fragment_conflicts.json`: act gates and reclaim pressure rules.

> **Body node placement** is defined directly in `scenes/body/BodyView.tscn` via the
> Godot editor. This removes the need for `body_nodes.json` and allows visual layout
> without a data-file round-trip.

---

### Body

The body map is a pannable, zoomable 2D canvas (pan: edge-scroll or middle-mouse drag;
zoom: scroll wheel). The background shows a faint grid and the ship silhouette (Polygon2D).

Ownership is tracked as a plain string; `"player"` identifies the player character.
Fragment IDs (arbitrary strings) are reserved for future antagonist fragments.
Note: `owner` is a reserved name in GDScript — use `controlling_entity` everywhere.

---

#### Class: BodyObject *(abstract)*
- Extends: `Node2D`
- Responsibility: Base class for all objects placed on the body map.

#### Class: ThoughtNode *(abstract)*
- Extends: `BodyObject`
- Responsibility: Base class for all thought-processing nodes.
- State:
  - `controlling_entity: String` — `""` = unowned, `"player"` = player.
  - `is_enabled: bool` — disabled nodes consume fewer resources and process slower.
  - `pressure: Dictionary` — `{ entity_id: int }`. Ticks down each cycle; reaching threshold transfers control.
- Signals:
  - `ownership_changed(old_entity: String, new_entity: String)`
  - `enabled_changed(enabled: bool)`
- Methods:
  - `set_enabled(value: bool) -> void`
  - `set_controlling_entity(entity: String) -> void`
  - `is_detected() -> bool` *(override in subclass)* — `true` if directly linked to a player-controlled node.

#### Class: NerveCluster
- Extends: `ThoughtNode`
- Responsibility: Small biological compute cluster. Primary node type on the body map.
- State:
  - `cluster_id: String` — unique identifier; used to resolve `link_ids` at runtime.
  - `link_ids: PackedStringArray` — IDs of directly connected clusters.
  - `glucose: int` — energy level. Drains each cycle: enabled −2/cycle, disabled −1/cycle.
- Signals:
  - `hovered(cluster: NerveCluster)`
  - `unhovered()`
  - `glucose_changed(new_value: int)`
- Methods:
  - `get_linked_clusters() -> Array` — returns live `NerveCluster` refs resolved from `link_ids`.
  - `is_detected() -> bool` — `true` if this node or any directly linked node is player-controlled.
  - `tick_glucose(cycles: int) -> void`
- Visuals:
  - `ClusterPolygon (Polygon2D)`: procedural rough circle seeded from `cluster_id`. Warm pinkish-red range.
  - Grey/desaturated when `is_enabled = false`.
  - Right-click: disable node. Left-click on a disabled node: re-enable.
- Relationships:
  - Parent: `ClustersRoot (Node2D)` inside `BodyView`.
  - Links to: other `NerveCluster` nodes (via `link_ids`).
  - Reads: `GameState.cycle` (for glucose ticking).

stressed and very stressed are considered status effects and has it's own word pool and associated visual changes.

stress should increase the speed that polygon shifts.

sleeping is considered a status.

Neural nodes can have various toggled states.
Right clicking lowers energy state.
single left click moves from 'sleeping' to normal.
double clicking when normal can boost node.

stress is a flat decrease to node power output.
1 stress = 0.95 power.
2 stress = 0.90 power

N=0 sleep
  0.3 x food requirement
  0 x power
  0.02% chance/tick to reduce stress if any.

N=1 normal
  1 x food requirement
  1 x power
  0.01% chance to reduce stress if any.
  
N=2 boost (can only be activated if glucose is 100)
  N x (N-1) food requirement
  N x power
  0.05 * N chance/tick to incriment stress per tick.
  0.00005 * N chance/tick to trigger burnout.

Can keep being double clicked to increase boost.

each additional double click increments boost level.
boosted nodes should be proporionally larger and brighter.

glucose level is a seperate status.

if burnout is triggered, a random amount of stress is added and the node is set to sleep.


### Node controller 

can be controlled by player, neurtal or other fragment.

Nodes can be capture by assigning your own active nodes to assign pressure.

Neutral nerve clusters should have varying randomised 'personalities'.
  - Co-operative: resists less when more nodes assigned.
  - Contrarian: resists more when more nodes assigned.
  - Determined: resists more the closer it is to capture.
  - Lazy: resists less the closer it is to capture.
  - various other possible cyclic.

Fragments are named entities that compete with the player for nodes

#### Class: LinksLayer

- Extends: `Node2D`
- Responsibility: Draws connection lines between clusters each frame.
  - Both endpoints detected: solid line.
  - One endpoint undetected: near-transparent line.
  - Both endpoints undetected: hidden (alpha 0).

#### Class: GridDraw
- Extends: `Node2D`
- Responsibility: Draws a faint static background grid (`z_index = -10`). Rendered once and cached.

#### Class: BodyView
- Extends: `Control`
- Responsibility: Body tab shell; hosts the SubViewport world and the overlay key panel.
- Navigation:
  - Pan: middle-mouse drag or edge-scroll (within 40 px of the map border).
  - Zoom: scroll wheel, zooming toward the cursor position.
- Overlay: top-left key panel showing player-controlled node counts and hovered-node details.

---

### Mind

#### Class: MindView
- Extends: `Control`
- Responsibility: Journal/wiki tab. Renders unlocked memory entries from `mind_entries.json`.

#### Data record: MindEntry (`mind_entries.json`)
- Fields:
  - `id: String`
  - `title: String`
  - `text: String` (BBCode)
  - `links: Array[String]` — IDs of related entries.
  - `unlock_conditions: Variant`

---

### Environment

#### Class: EnvObject *(data record)*
- Source: `environment_objects.json`
- Fields:
  - `id: String`
  - `region: String`
  - `required_sensors: Array[String]`
  - `interactions: Array[Dictionary]`
  - `reveals: Array[String]`


## Suggested class layout (next pass)

- `autoload/ProgressionSystem.gd`: evaluates unlock conditions.
- `autoload/ObservationSystem.gd`: resolves sensor/object interactions.
- `autoload/FragmentConflictSystem.gd`: enemy fragment pressure and act gating.
- `scripts/common/ConditionEvaluator.gd`: shared condition checks.

## Why this fits your loop

Your loop is cyclical and stateful:

1. Body actions unlock capabilities.
2. Capabilities expand environmental observations.
3. Observations unlock memories and body gates.

This architecture keeps the loop explicit and testable, while narrative content remains data-driven.

## Practical next milestone

Implement one vertical slice:

- 4 body nodes.
- 3 environment objects.
- 5 memory entries.
- 1 fragment-conflict gate.

That slice will validate pacing, cycle economy, and emotional tone before scaling content.
