# Design

## Purpose
Narrative exploration game where the player is a sentient vessel rebuilding identity, capability, and context after trauma.

## Document map
- Core architecture and object relationships: OBJECT_STRUCTURE.md
- User interface and interaction notes: UI.md
- Narrative and story structure: story.md

## Shared terminology
- Cycle: one simulation step. Use "cycle" in docs (not "tick").
- Body node: an interactable unit on the body map. Current concrete class: NerveCluster.
- Controlling entity: ownership identifier for a body node. "player" is the player entity.
- Fragment: a non-player mind entity that can contest body-node control.
- Food vs glucose: food is the global resource pool; glucose is per-node energy.

## Core gameplay loop
1. Reclaim body systems and restore node networks.
2. Restored systems unlock new sensing and actions in the environment.
3. Environmental observations trigger memory recovery.
4. Recovered memories unlock further body regions and progression gates.

## Systems design priorities
- One shared state model across tabs.
- Body, Environment, and Mind are perspectives on the same state.
- Time progression is explicit and player-readable.
- Resource pressure creates meaningful prioritization.

## Economy and pacing

### Resources
- Primary resource: food.
- Player-controlled active body nodes consume food each cycle.
- Node performance scales with glucose level.
- Nodes below coma threshold are treated as disabled until restored.
- Time controls adjust tick size (not update frequency).
- Expected baseline start speed: 1x.
- Number of controlled nodes of each type is also a tracked resource (shown as idle/total on left).

### Workers/Nodes

Your nodes funtion as a worker placement mechanic. Left clicking assigns another node, right click removes it. Nodes can be assigned to components and Tasks.
Components require a certain amount of thought-power to function, nodes need to be assigned until that threshold is passed. Nodes assigned to a component stay there until removed.
Tasks have a certain amount of work that needs to be done, the more nodes assigned the faster it will be done. On completion, nodes are returned to idle pool.
There are various types of nodes (currently NeuronCluster, ArithmeticProcessor, and QuantumCalculator), components and tasks have a 'prefered' node type and non prefered nodes get a malus to the power they contribute. When adding a node to a task or component the prefered type will be added if available, otherwise the node type with the most idle nodes will be used. Removing a node is this logic revesed (i.e remove least numerous non preffered first and preffered last).

Number of idle nodes and total nodes per type are displayed in a key on the left hand side of the UI. (Circle, square and triangle for NeuronCluster, ArithmeticProcessor, and QuantumCalculator).
This should be visible in all views.

### Tasks

Converting or capturing another node is considered a task.
To capture a node it must be connected to an owned node.
Left / right clicking on an unowned node will add/remove nodes working on this task. 
A number of symbols (same as in key) are arranged near the link between your node and the node being captuted to show your assigned nodes.

Nodes have a resistance to being converted, and amount that is subtracted from the player progress to convert.

Progress is shown by coloring the link player colors.

### Components

Components are objects on the map that inherit from body object. Can be mostly placeholder for now.
Require a certain amount of thought-power to function. Assigned node symbols are shown next to.
Left Clicking adds nodes right removed.

some components have various levels based on how many of that component are controlled.

e.g. 

Level 0 [0 sensors]: nothing
Level 1 [1 sensors]: enable UI element.
Level 2 [4+ sensors]: enable another thing.

Reaching a level for the first time unlocks it, and makes the memory 'unread'
Unlocked levels and it's effects are shown in the memory for this component type.
Current level is shown.



## Fail condtionS
- Black out from too many G'S (continuing to increaSe rotation).

## Current implementation directives
- Keep tunable values script-exposed for fast iteration.
- Keep pan/zoom constrained to playable space.
- Vision outside controlled influence should fade toward black.
- Deactivated or starving nodes should not count toward key overlays.
- Visual transitions should interpolate smoothly between states.

## Memories

Mind panel contains a list of 'memories'

Memories can be text and contain images. And may be unlocked in stages.
Unread memories will be highlighted.
When memories are read for the first time the text will appear with a typewriter effect (come in word at a time, mimic patter of thinking it through).

Other memories can have links that will take you to that entry when clicked.

Occasionally you will be prompted to select a word, is persistant and stored in the player data. 

And can be referenced elsewhere. e.g. `The radar signatures are ["a threat", "friends", "not important"]`. This value may be used later to determine different behavior.

Titles and text content can be updated, in which case a memory will become unread again, and show typewriter effect again.

Memories can be triggered by various game conditions.

Memories that have a time attached are selectable on the timeline.

Memories can have tags.

Filter by tags.

## Complexity guardrails
When a proposed feature is disproportionately expensive relative to current milestone goals, prefer a simpler placeholder and document the tradeoff.
