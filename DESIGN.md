# Design

## Purpose
Narrative exploration game where the player is a sentient vessel rebuilding identity, capability, and context after trauma.

## Document map
- Core architecture and object relationships: `OBJECT_STRUCTURE.md`
- User interface and interaction notes: `UI.md`
- Narrative and story structure: `STORY.md`
- Open implementation issues and proposals: `IMPLEMENTATION_GAPS.md`

## Shared terminology
- Cycle: one simulation step. Use "cycle" in docs (not "tick").
- Body node: an interactable unit on the body map.
- Controlling entity: ownership identifier for a body node.
- Fragment: a non-player mind entity that can contest body-node control.
- Food vs glucose: food is global resource supply; glucose is per-node energy.
- Resistance: per-node conversion resistance used by capture tasks.

## Core gameplay loop
1. Reclaim body systems and restore node networks.
2. Restored systems unlock sensing and actions in Environment.
3. Environmental observations trigger memory recovery.
4. Recovered memories unlock further body regions and progression gates.

## Systems priorities
- One shared state model across tabs.
- Body, Environment, and Mind are different views over the same simulation state.
- Time progression is explicit and player-readable.
- Resource pressure creates meaningful prioritization.

## Economy and pacing

### Resources
- Primary resource: food.
- Player-controlled active body nodes consume food each cycle.
- Node output scales with glucose.
- Nodes below coma threshold are treated as disabled until restored.
- Time controls adjust cycle size, not update frequency.
- Baseline starting speed: `1x`.
- Idle/total worker counts by node type are shown in a global left key.

### Workers and node types
Nodes are a worker-placement pool.

- Left click assigns a worker (when valid).
- Right click removes a worker (when valid).
- Workers can be assigned to tasks and components.

Current worker node types:
- `NeuronCluster` (circle)
- `ArithmeticProcessor` (square)
- `QuantumCalculator` (triangle)

Each task/component has a preferred node type.

- Preferred type contributes full power.
- Non-preferred type contributes with multiplier penalty.
- Assignment priority:
	1. preferred type if idle exists
	2. otherwise type with highest idle count
- Removal priority:
	1. least numerous non-preferred first
	2. preferred last

### Tasks (capture)
Capturing an unowned node is a task.

- Capture can only start when target is connected to a player-owned node.
- Left/right click on unowned node adds/removes assigned workers.
- Assigned worker symbols appear on the source-target link.
- Link color indicates capture progress.
- Resistance is subtracted from worker power each cycle.
- If no workers remain, capture progress decays over time.

### Components
Components are `BodyObject` instances with worker targets.

- Require thought-power to activate.
- Assigned worker symbols appear near the component.
- Left/right click adds/removes workers.
- Components must be connected to player-owned nodes to receive workers.

Current placeholder component:
- `PhotosyntheticTissue`
	- activation threshold: `1.0` power
	- when active: `+1` food per cycle

## Node states and behavior roadmap
The following are design goals and are not fully implemented yet:

- Multi-level neural energy states (`sleep`, `normal`, `boost`).
- Stress accumulation/reduction and burnout behavior.
- Personality-modified capture resistance curves.
- Fragment-specific node contest behavior.

See `IMPLEMENTATION_GAPS.md` for implementation proposals.

## Memories (mind layer)
Mind view contains memory entries.

- Entries may be unlocked by game conditions.
- Runtime entries are added when node/component types are first controlled.
- Planned extensions: unread/highlight state, staged updates, typewriter reveal, tags, filters, and timeline-linked entries.

## Failure condition (planned)
- Blackout from excessive G-load while unresolved rotation continues.

## Implementation directives
- Keep tunables script-exposed for iteration.
- Keep pan/zoom constrained to playable space.
- Fade vision outside controlled influence toward black.
- Keep visual transitions interpolated (avoid hard snapping).

## Complexity guardrail
When a feature is disproportionately expensive for current milestone goals, implement a simpler placeholder and document the tradeoff.
