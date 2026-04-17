# UI Notes

## Experience goal
The interface should feel like the player mind reorganizing itself, not an external game shell.

## Global layout

- Top overlay: menu, time controls, and resources.
- Main area: tabs for Mind, Body, Environment.
- Left floating global key: worker node counts by type (`idle / total`).

Global HUD remains visible in all views.

## Top overlay

### Menu
- Save (placeholder)
- Load (placeholder)
- Push-scroll toggle
- Quit (placeholder)

### Time controls
- Pause
- Step while paused
- Speed: `1x`, `10x`, `100x`
- Controls affect cycle size, not frame update rate.

### Resource line
- Shows food, last-cycle food consumption, and aggregate power.

## Global key

- Displays worker types using canonical shapes/colors:
  - circle: `NeuronCluster`
  - square: `ArithmeticProcessor`
  - triangle: `QuantumCalculator`
- Displays `idle / total` per type.
- Is authoritative; Body-local duplicate key is removed.

## Tab: Mind

Purpose: internal awareness, journal, and semantic reflection.

- Entry list and content panel.
- Timeline placeholder.
- Placeholder worker task panel (for cross-view worker pool validation).

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
- Worker symbols on links/components match global key icon style.
- Status popups appear with randomized offset/cadence.

### Hover cards

- Follow cursor with left-offset placement to reduce map occlusion.
- Debug block includes glucose, power, and resistance.

## Tab: Environment

Purpose: external awareness and sensor-gated interactions.

- Sensor toggles.
- Observation controls.
- Placeholder worker task panel using shared worker pool.

## Interaction and camera constraints

- Pan/zoom constrained to preserve context.
- Middle-mouse pan and wheel zoom are reliable defaults.
- Push-scroll is optional and disabled by default.
- Vision masks fade toward black outside influence.

## UI implementation rules

- Keep tuning values script-exposed.
- Keep terminology and input language consistent across tabs.
- Reuse shared worker icon/marker helpers to avoid visual drift.