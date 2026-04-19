# UI Notes

## Experience goal
The interface should feel like the player mind reorganizing itself, not an external game shell.

UI.md is the authoritative document for shared HUD behavior, tab visibility, worker icon usage, and debug-only visibility controls.

## Global layout

- Top overlay: time controls and resources.
- Main area: tabs for Mind, Body, Environment.
- Left floating global key: worker node counts by type (`idle / total`).
- Center overlay: system menu card toggled with `Esc`.

Global HUD remains visible in all views.

## Top overlay

### Menu
- The top-bar menu button is removed.
- Press `Esc` to toggle a centered system menu card.
- Opening the card pauses cycle advancement; closing it unpauses.
- The card has a dedicated `Close` button and contains:
  - Save (placeholder)
  - Load (placeholder)
  - Settings
  - Debug mode toggle (single entry)
  - Quit (placeholder)

Debug options are centralized in the floating Debug window. The top menu no longer duplicates debug feature toggles.

### Settings menu skeleton

Settings uses a dedicated Godot `Window` with a `TabContainer` so categories stay consistent as the game grows.

- Gameplay: autosave, push scroll, difficulty, hover-card delay.
- Video: window mode, VSync, UI scale.
- Audio: master/music/sfx sliders.
- Accessibility: reduce motion, high contrast, text speed.
- Controls: `InputMap` action list scaffold for future rebinding.

Persistence scaffold uses Godot `ConfigFile` (`user://settings.cfg`) with `Apply`, `Cancel`, and `Reset Defaults` actions.

### Time controls
- Pause
- Step while paused
- Speed: `1x`, `10x`, `100x`
- Controls affect cycle size, not frame update rate.

#### Debug visibility gating

Development builds can hide time controls through the debug visibility system. The Time Controls container is the authoritative element for this state, so all pause, step, and speed actions disappear together when the feature is disabled.

### Resource line
- Shows food and signed net food balance per tick (`output - requested`).
- Food balance signal is authoritative:
  - red when requested food is greater than current output
  - green when output is greater than current requested usage
  - neutral when balanced

## Global key

- Displays worker types using canonical shapes/colors:
  - circle: `NeuronCluster`
  - square: `ArithmeticProcessor`
  - triangle: `QuantumCalculator`
- Displays `idle / total` per type.
- Is authoritative; Body-local duplicate key is removed.
- Shares icon language with WorkerBench and other worker markers through the same helper path.

## Tab: Mind

Purpose: internal awareness, journal, and semantic reflection.

- Entry list and content panel.
- Timeline placeholder.
- Placeholder worker task panel (for cross-view worker pool validation).
- Timeline visibility is debug-gated and should disappear cleanly without affecting the rest of the layout.

Planned:
- unread highlighting
- typewriter reveal
- tag filtering
- link navigation between entries

## Tab: Body

Purpose: internal systems map and capability recovery.

- Pannable/zoomable map over ship backdrop.
- Linked node graph with visibility and ownership rules.
- Left click on unowned node: assign capture workers.
- Right click on unowned node: remove capture workers.
- Left/right click on owned nodes: energy-state toggles (current simple enabled/disabled behavior).

### Body visuals

- Links wobble and color-shift with capture state.
- Nodes animate with soft shape wobble and glucose-scaled presentation.
- **WorkerBench**: the in-world display of workers assigned to a capture or component.
  - Icons match the global key icon style exactly (same `WorkerDisplayUtils` shapes/colors).
  - For node captures: icons orbit in a tight arc around the target node.
    - Icons are packed next to each other (not spread equidistant around the full circle).
    - The whole cluster rotates slowly to catch the player's attention.
    - Tuning constants in `LinksLayer.gd`: `WORKERBENCH_ORBIT_RADIUS`, `WORKERBENCH_ARC_STEP`, `WORKERBENCH_ORBIT_SPEED`.
  - For components (e.g. Photosynthetic Tissue): icons shown in a linear row beside the component.
- Status popups appear with randomized offset/cadence.

### Hover cards

- Follow cursor with left-offset placement to reduce map occlusion.
- Debug block includes glucose, power, and resistance.

## Tab: Environment

Purpose: external awareness and sensor-gated interactions.

- Sensor toggles.
- Observation controls.
- Placeholder worker task panel using shared worker pool.
- The entire right-side sensor panel is controlled by player state (`sidebar_visible`) and toggled in Environment view with `Tab`.
- Panel visibility remains gated by both player state and unlocked sensor availability.

Environment tab visibility can be debug-gated during development. If the active tab becomes unavailable, the UI should fall back to Body.

## Debug Visibility

The debug visibility system exists for development-time UI testing. It is not a second UI architecture; it is a temporary gating layer over the same authoritative HUD and tab elements.

### Authoritative elements

- `DebugVisibilityManager` autoload controls development-time visibility state and worker-type encounter state.
- `DebugVisibilityPanel` is the in-game control surface for toggling those states in debug builds.
- `Main.gd` is responsible for applying those states to shared HUD elements, tabs, and fallback tab selection.

### Scope

The system currently controls:

- UI feature visibility:
  - `mind_window`
  - `environment_window`
  - `time_controls`
  - `timeline_bar`
- Worker type encounter gating:
  - `neuron_cluster`
  - `arithmetic_processor`
  - `quantum_calculator`

### Behavioral rules

- The debug panel only appears in debug builds.
- Mind and Environment buttons and panels must respect the same visibility state as their tabs.
- The timeline bar is controlled independently from the rest of Mind so the tab can remain visible while the timeline is hidden.
- Worker type discovery is one-way in the panel: a type can be marked encountered, but not un-encountered.
- Worker-type groups should only appear after encounter, not merely after count becomes nonzero.
- If the current tab is hidden by a visibility toggle, the UI should switch to Body rather than leaving the player on an invalid tab.

### Default debug state

- All UI features visible.
- Only `NeuronCluster` encountered by default.

### Runtime API

Primary methods exposed by `DebugVisibilityManager`:

- `set_visibility(feature: String, visible: bool)`
- `is_visible(feature: String) -> bool`
- `encounter_worker_type(node_type: String)`
- `is_worker_type_encountered(node_type: String) -> bool`
- `get_visibility_state() -> Dictionary`
- `get_encountered_types() -> Dictionary`
- `reset_all_visibility()`

### Usage examples

```gdscript
# Mark a worker type as encountered.
DebugVisibilityManager.encounter_worker_type(GameState.NODE_TYPE_ARITHMETIC_PROCESSOR)

# Hide the environment window for testing.
DebugVisibilityManager.set_visibility("environment_window", false)

# Read current states.
var encountered_types = DebugVisibilityManager.get_encountered_types()
var visible_features = DebugVisibilityManager.get_visibility_state()
```

### Integration notes

- `DebugVisibilityPanel` lives at `scenes/ui/DebugVisibilityPanel.tscn` with logic in `scripts/ui/DebugVisibilityPanel.gd`.
- `DebugVisibilityManager` lives at `autoload/DebugVisibilityManager.gd`.
- The panel should stay focused on visibility and encounter testing only; broader debug controls belong elsewhere.

### Migration path

When progression or story systems take ownership of these gates:

- Replace direct debug visibility toggles with progression-driven state changes.
- Keep encounter events aligned with actual in-game discovery.
- Remove the panel from the shipped main scene, or keep it development-only.
- Preserve the shared visibility application points so debug and progression paths do not drift.

## Interaction and camera constraints

- Pan/zoom constrained to preserve context.
- Middle-mouse pan and wheel zoom are reliable defaults.
- Push-scroll is optional and disabled by default.
- Vision masks fade toward black outside influence.

## UI implementation rules

- Keep tuning values script-exposed.
- Keep terminology and input language consistent across tabs.
- Reuse shared worker icon/marker helpers to avoid visual drift.
- Treat shared HUD elements and worker icon helpers as single sources of truth.