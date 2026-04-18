# Visual Design

## Document map
- Shader files: `shaders/`
- Polygon animation controller: `scripts/body/visual/PolygonVisualController.gd`
- Visual effects agent instructions: `.github/agents/visual-effects.agent.md`

## Aesthetic direction

The game's visual identity fuses organic biology with machine precision. The ship is a fusion of body and machine — that tension should be visible at all times. Biological elements (veins of energy, pulsing nodes, membrane fills) thread through circuitry and clean geometry. Nothing is purely mechanical or purely organic.

## Visual identity

### Palette
- **Backgrounds:** Deep and dark.
- **Player-owned elements:** Cool cyan/blue (`#8DD6FF` range).
- **Neutral state:** Desaturated blue-grey.
- **Capture/hostile state:** Warm accent color.

### Organic language
Shapes breathe and pulse rather than snap. Edges are soft. Patterns feel biological — marbling, membrane-like fills, flowing shimmer.

### Contrast
Blend organic glow and motion with crisp geometry and clean lines. Links have a precise beam shape but shimmer with energy. Nodes have defined shapes but pulse with life.

### Restraint
Effects support readability. Glow and motion reinforce gameplay state (ownership, activity, capture progress) — they must not obscure it.

### Backgrounds
Subtle and dark, so interactive elements pop. Evocative patterns of unknown machinery in the darkness, but they must not compete with gameplay elements for attention.

## Visual effects as gameplay communication

Many object states are not directly visible to the player. Every change in an object state that the player can influence or should be aware of should have a corresponding visual cue.

Examples of expected mappings:
- **Capture progress:** glowing gradient that fills a node.
- **Ownership change:** pulse or color shift on transition.
- **Sensor activity:** shimmering patterns or particle effects that grow more intense at higher activity levels.

Every state the player can act on should be visually legible without requiring a numeric readout.

## Key shader files

| File | Purpose |
|---|---|
| `shaders/body_link.gdshader` | Link shimmer, capture-progress gradient, beam falloff |
| `shaders/node_fill.gdshader` | Organic marbled polygon fill driven by `pattern_seed` |
| `shaders/vision_mask.gdshader` | Multi-center fog-of-war with feathered radii |

## Key scripts

- `scripts/body/visual/PolygonVisualController.gd` — polygon scale animation, outline hover, shader material setup. Reuse and extend this rather than duplicating its logic.
