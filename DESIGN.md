# Design

## Purpose
Narrative exploration game where the player is a sentient vessel rebuilding identity, capability, and context after trauma.

## Document map
- Core architecture and object relationships: `OBJECT_STRUCTURE.md`
- User interface and interaction notes: `UI.md`
- Visual design, aesthetic identity, and shader references: `VISUAL_DESIGN.md`
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

## Current implementation note
- Fragment conflict mechanics drive Act 2 progression gates. The runtime conflict loop is now implemented in `FragmentConflictSystem`: conflicts activate when their `required_memory` is unlocked and `trigger_cycle` is reached; resolution emits `EventBus.fragment_node_stabilized`. Conflict data lives in `data/fragment_conflicts.json`.

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
- If active worker capacity drops below assigned workers, overflow workers are auto-removed in this order:
	1. tasks first (capture and named tasks)
	2. components second

### Tasks (capture)
Capturing an unowned node is a task.

- Capture can only start when target is connected to a player-owned node.
- Left/right click on unowned node adds/removes assigned workers.
- Assigned worker symbols appear on the source-target link.
- Link color indicates capture progress.
- Capture pressure resistance starts low and scales with conversion ratio each cycle.
- This creates a stable equilibrium when assigned power is lower than node resistance.
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
- Runtime entries are added via the component memory progression system (see below).

### Knowledge progression states

Every piece of player knowledge moves through four stages. Preserve these distinctions when designing triggers, UI, and content:

| Stage | Description |
|---|---|
| **Observation** | The player senses something in the environment without understanding it. No entry exists yet, or entry is hidden (state 0). |
| **Unlock** | The entry becomes available (state 1 triggered). Knowledge exists but is incomplete — sensory, pre-functional. |
| **Unread** | The entry is available but the player has not yet read it. UI should highlight unread entries. |
| **Integrated** | The player has read and engaged with the entry; the system has advanced to state 2 where applicable. Full functional knowledge. |

### Component memory progression

Components like `PhotosyntheticTissue` have multi-state mind entries defined in `data/component_mind_entries.json`.

**States:**
- State 0: entry is hidden (default).
- State 1: triggered by first hover over the component in the Body view. Reveals a flavor entry with a short description and an in-text variable (typewriter gate).
- State 2: triggered when the component is first activated (controlled). Reveals the proper name, function, power requirement, and a live tally of controlled units and total resource contribution.

**Data format (`data/component_mind_entries.json`):**

Each item in the array defines:
- `component_type_id`: matches `@export var component_type_id` on the component script.
- `mind_entry_id`: the memory id registered in `GameState.unlocked_memories`.
- `states[]`: array of state objects, each with `state` (int), `title`, and `text_segments[]`.

**Text segments schema:**
- `{"type": "text", "content": "..."}` — plain text block. Supports `{token}` substitutions (see below).
- `{"type": "variable", "key": "...", "prompt": "...", "options": [...]}` — typewriter gate. Display pauses here until the player selects an option from the dropdown (`MindView.VariableSelector`). The chosen value replaces this segment on continuation.

**Supported `{token}` substitutions (resolved at render time):**
- `{controlled_count}` — count of components of this type with `is_activated == true`.
- `{required_power}` — from `GameState.register_component_properties`.
- `{food_output_per_cycle}` — per-cycle output from component properties (legacy name).
- `{glucose_production_per_cycle}` — per-cycle glucose output from component properties.
- `{total_food_contribution}` — `controlled_count × food_output_per_cycle`.

**Trigger points:**
- State 1: `BodyView._on_component_hovered` → `ProgressionSystem.report_component_first_hovered(component_type_id)`.
- State 2: component `update_activation_from_workers` → `ProgressionSystem.report_component_controlled(self)`.

**Adding a new component entry (no code changes required beyond the component script):**
1. Add `@export var component_type_id: String = "my_type"` to the component script.
2. Call `GameState.register_component_properties(component_type_id, {"required_power": ..., "glucose_production_per_cycle": ...})` in `_ready()`.
3. Add an entry object to `data/component_mind_entries.json` with the matching `component_type_id`, a `mind_entry_id`, and `states[]`.
4. Triggers and display are automatic.

### Progression core memories (main/body/environment)

Core progression memories are authored in `data/progression_mind_entries.json` and resolved by `ProgressionSystem`.

Current runtime behavior:
- Core progression entries are currently pinned to baseline stage (`stage 0`).
- `track` metadata remains in data for future staged progression logic.

- `waking_fragment` is now a staged main-story entry (`track: "main_story"`).
- `body_function_log` tracks Body capability progression (`track: "body"`).
- `environment_function_log` tracks Environment capability progression (`track: "environment"`).

Schema per entry:
- `id: String` (must be unique)
- `track: "main_story" | "body" | "environment"`
- `states: Array[{ stage: int, title: String, text: String }]`

Selection rule:
- Runtime currently resolves baseline stage only (`stage 0`) for core entries.
- Sensor entries (`data/sensor_mind_entries.json`) resolve by current sensor tier.
- Entries are registered as dynamic mind entries, which allows updates over time.

Authoring rules:
- Keep stage values monotonic (`0, 1, 2, ...`) with no duplicate stage numbers.
- Treat `stage 0` as baseline text shown at game start.
- Use these entries for progression recaps only; keep one-off discoveries in `mind_entries.json` or component state entries.
- Reusing an id from `mind_entries.json` is allowed for intentional override (used by `waking_fragment`).

---

### Memory entry authoring guidelines

This section covers how to write both static entries (`data/mind_entries.json`) and component progression entries (`data/component_mind_entries.json`).

#### Voice and tone

The player is a damaged mind re-learning itself. All entries are written from the first-person interior perspective — sensations, inference, incomplete data. Use sparse, fragmented prose. Avoid omniscient narration.

- **Do:** "A dense tiling. No wiring. It faces the star." — observational, clipped.
- **Do:** "Something about this feels like recognition without memory."
- **Don't:** "This component generates food by converting solar radiation." — expository, external.
- **Don't:** Full sentences that explain mechanics directly in flavor text.

State 1 entries are pre-understanding: the mind notices something without knowing what it is. Use sensory detail, shape, position, texture — no function names, no correct terminology.

State 2 entries are post-capture: the mind has integrated the system. Terminology is now correct. Functional information is appropriate here, but filtered through the mind's recovery voice, not a manual.

#### Title conventions

- State 1: describe what it *looks or feels like* from the outside. Not the real name. ("Unknown Membrane", "Dark Lattice", "Pulsing Ring")
- State 2: use the canonical in-world name. ("Photosynthetic Tissue", "Arithmetic Processor")

The title change from state 1 to state 2 is itself part of the narrative — the player is naming and claiming.

#### Text segments

Short segments are preferable to long runs of prose. Each segment should do one thing: establish a sensory image, raise a question, deliver a fact. A segment that tries to do all three at once usually does none of them well.

Blank lines between segments are acceptable in `content` strings using `\n\n`.

When a `variable` gate is used, place it at a natural pause — after an observation, not mid-sentence. The options should all be plausible completions, not obviously correct vs wrong. The choice is characterisation, not puzzle.

#### Variable gates

- Use sparingly: one per state 1 entry at most, zero in state 2 (which is informational).
- The chosen value is stored and displayed permanently after selection.
- Options should be short (2–5 words) and tonally consistent with the entry's voice.
- The `prompt` field is reserved for future UI use; write it as a fragment the player is completing. ("It reminds you of:" / "The closest word is:")

#### Live token substitutions (state 2)

Use `{token}` placeholders for values that update as the game progresses. This keeps the entry alive and removes the need to rewrite text when counts change.

- `{controlled_count}` — how many of this component type are currently active.
- `{total_food_contribution}` — aggregate resource output.
- `{required_power}` — power threshold for activation.
- `{food_output_per_cycle}` — per-unit output.
- `{glucose_production_per_cycle}` — per-unit glucose output.

Write the surrounding sentence so it reads correctly at count 0 and count 5+. ("Currently controlling {controlled_count} unit(s)." is better than "You control {controlled_count}." for count=1.)

#### ID conventions

- Static entries (`mind_entries.json`): `snake_case_phrase` describing the concept. e.g. `waking_fragment`, `signal_hum`.
- Component entries: `component_<component_type_id>`. e.g. `component_photosynthetic_tissue`.
- IDs must be unique across both files. A component entry with the same id as a static entry will shadow it silently.

#### Checklist before committing a new entry

- [ ] State 1 title does not use the real component name.
- [ ] State 1 prose does not explain what the component does.
- [ ] State 2 prose uses correct terminology and includes at least one live `{token}`.
- [ ] Variable options (if any) are all plausible, tonally matched, and short.
- [ ] `mind_entry_id` is unique and follows the `component_<type>` convention.
- [ ] `component_type_id` matches the export on the component script exactly.

## Failure condition (planned)
- Blackout from excessive G-load while unresolved rotation continues.

## Implementation directives
- Keep tunables script-exposed for iteration.
- Keep pan/zoom constrained to playable space.
- Fade vision outside controlled influence toward black.
- Keep visual transitions interpolated (avoid hard snapping).

## Complexity guardrail
When a feature is disproportionately expensive for current milestone goals, implement a simpler placeholder and document the tradeoff.
