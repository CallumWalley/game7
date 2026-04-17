# Awakening Vessel - Godot Skeleton

This is a Godot 4 starter skeleton based on the design document.

## Design docs

- `DESIGN.md`: core loop and systems priorities.
- `UI.md`: interface structure and interaction notes.
- `story.md`: narrative premise, arc, and story direction.
- `OBJECT_STRUCTURE.md`: scene/script ownership and class/data model details.

## Current loop scaffold

1. Body unlock actions spend cycles and unlock capabilities.
2. Environment sensor interactions spend cycles and reveal observations.
3. Mind entries unlock progressively and consume reflection cycles.
4. Fragment conflicts can contest unlocked body nodes and block further progression until resolved.

## Run

1. Open the `project` folder in Godot 4.
2. Ensure autoload entries are present (`GameState`, `TimeSystem`, `EventBus`, `ProgressionSystem`, `ObservationSystem`, `FragmentConflictSystem`).
3. Run the main scene: `res://scenes/ui/Main.tscn`.

## Next implementation passes

- Replace placeholders with graph map scenes for body and environment.
- Add unlock conditions and scripted act gates.
- Convert mind entries to richer data resources and link graph.
