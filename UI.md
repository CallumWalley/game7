# UI Notes

## Experience goal
The interface should feel like the structure of the player mind, not a separate game shell.

## Global layout
- Top bar: menu, time controls, and resources.
- Main area: three primary tabs (Mind, Body, Environment).
- UI should reveal progressively as awareness returns.

## Top bar
### Menu
- Save
- Load
- Settings
- Quit

### Time controls
- Pause
- Play
- Step (debugging and inspection)
- Speed options: 1x, 10x, 100x
- Next-step control should only be available while paused.
- These controls change cycle size, not update frequency.

### Resources
- Display current food and projected change, for example: 112k -12/m.
- Keep this visible across tabs.
- Treat food as global supply and glucose as per-body-node energy.

### Nodes
- shows idle and total nodes by type.

## Tab: Mind
Purpose: internal awareness, journal, and knowledge graph.

- Left panel: alphabetical entry list.
- Main panel: selected memory text or media.
- Bottom timeline: alternate navigation path.
- Entry links should allow cross-references.
- Some entries can be lightweight animations, not only text.

## Tab: Body
Purpose: internal systems map and capability recovery.

- Pannable/zoomable map over ship backdrop.
- Graph of connected body nodes (NerveCluster) with gated reveal through links.
- Left click: activate or restore a player-controlled body node when possible.
- Right click: disable a player-controlled body node (reduced consumption mode).
- Key/overlay should count only eligible active player-controlled body nodes.

### Node and link visuals
- Links should wobble subtly, not only recolor.
- Node polygons should animate with soft shape wobble.
- Glucose should influence scale and intensity.
- Inactive nodes should retain glucose-based size but shift toward low-energy hue.
- Player color and innate tint should blend smoothly.
- State transitions should animate, not snap.

### Ambient feedback
- Emotion/status word popups should appear with slight randomized offset.
- Popup cadence and refresh timing should be slightly randomized.

## Tab: Environment
Purpose: external awareness and interaction.

- Solar-system style 2D map.
- Sensor layers (optical, thermal, radio, gravity).
- Interactions unlocked by body capabilities.
- Future: navigation between regions/maps.

## Interaction and camera constraints
- Prevent full loss of context through unrestricted pan/zoom.
- Keep middle-mouse pan and wheel zoom reliable.
- Apply vision radius around player-controlled body nodes with outer fade to black.

## UI implementation notes
- Keep display and control logic parameterized and tweakable.
- Favor clear readability over dense decoration.
- Maintain consistency of input language across tabs.
- Global elements (time control, resources, view change buttons, node count) are visible in all views.
  Views should expect their presense and not place their view specific elements where they will be covered. When in a map view (environment, body). These global elements should look like they are floating over the map (with map extending all the way to edges), however when in mind view they should fit in seamlessly with the other UI elements.