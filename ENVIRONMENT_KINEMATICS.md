# Environment Map and Ship Kinematics

## Purpose
This document describes the current runtime mechanics around ship kinematics and the environment map, plus a practical target end state consistent with the project design docs.

## System Ownership (Current)

- `scripts/environment/EnvironmentMap.gd`
  - Owns ship simulation state in environment space.
  - Integrates movement each frame.
  - Computes derived motion telemetry.
  - Builds progression-visible map objects and orbit visuals.
  - Applies sensor-filter gating to object rendering.
  - Auto-observes nearby visible objects.
  - Pushes ship/sun spatial relation to `GameState`.

- `scripts/environment/EnvironmentView.gd`
  - Owns environment UI behavior and overlays.
  - Reads ship state from `EnvironmentMap.get_player_state()`.
  - Applies player-centered camera lock.
  - Owns sensor sidebar visibility and sensor filter toggles.
  - Drives thermal and g-force overlays from telemetry + visible objects.
  - Drives motion telemetry HUD visibility and updates.

- `autoload/ObservationSystem.gd` (SSOT per docs)
  - Owns environment object definitions and sensor-gated visibility.
  - `EnvironmentMap` consumes `ObservationSystem.get_visible_objects()` and `get_system_objects()`.

- `autoload/GameState.gd`
  - Owns progression-facing shared state.
  - Receives environment ship and sun sync (`sync_environment_ship_and_sun(...)`).
  - Tracks observed environment IDs used by progression loops.

- `autoload/DebugVisibilityManager.gd` + `scripts/ui/DebugVisibilityPanel.gd`
  - Own debug sensor-tier overrides.
  - Own debug kinematic parameter overrides.
  - Feed runtime parameters into `EnvironmentMap` without duplicating simulation ownership.

## Ship Kinematics Mechanics (Current)

### Input and Integration
In `EnvironmentMap._integrate_player_motion(delta)`:

- Rotation input: `D - A` key state.
- Translation input: `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")`.
- Local acceleration vector is rotated into world space by ship rotation.
- Velocity update sequence:
  1. Add acceleration impulse (`world_accel * delta`).
  2. Clamp by max speed.
  3. Apply linear drag toward zero.
- Position update: `player_position += player_velocity * delta`.
- World bounds clamp to `WORLD_BOUNDS` rectangle.

### Effective Parameters
`EnvironmentMap` resolves live effective parameters from debug overrides, then falls back to exported defaults:

- `kine_rotation_speed` -> `player_rotation_speed`
- `kine_acceleration` -> `player_acceleration`
- `kine_max_speed` -> `player_max_speed`
- `kine_linear_drag` -> `player_linear_drag`

This makes debug tuning immediate while preserving authored defaults.

### Derived Telemetry
After integration:

- `player_angular_velocity` = wrapped rotation delta / sample delta.
- `player_linear_acceleration` = velocity delta / sample delta.

These values are not alternative simulation state; they are derived observability values used by overlays/HUD.

### Published Player State Contract
`EnvironmentMap.get_player_state()` publishes:

- `position`
- `rotation`
- `velocity`
- `linear_acceleration`
- `linear_acceleration_magnitude`
- `angular_velocity`
- `acceleration` (base acceleration setting)
- `sidebar_visible`

`EnvironmentView` consumes this contract each frame.

## Environment Map Mechanics (Current)

### Object Build and Visibility Scope
- The map only renders objects in `system0` plus spawn handling.
- Source objects come from `ObservationSystem`:
  - progression-visible objects (`get_visible_objects()`)
  - spawn object from full system list (`get_system_objects(system_id)`)
- `player_spawn` initializes ship position once and is not rendered as a normal object marker.

### Sensor Filter Gating
`EnvironmentView` maintains enabled sensor filter IDs and sends them to `EnvironmentMap.set_enabled_sensor_filters(...)`.

`EnvironmentMap` then:

- Rebuilds visible map objects when filters change.
- Includes an object if at least one enabled sensor channel reports signal > 0.
- Tints object visuals by average color of enabled sensors.
- Scales object alpha/visual weight by combined best signal strength.

### Sensor Signal Channels
Canonical channels in use:

- `thermal`
- `radio`
- `velocity`
- `gamma`
- `gravity`
- `acceleration` (data channel)

UI-facing split channels:

- `acceleration1` = g-force effect control channel.
- `acceleration2` = telemetry readout control channel.

Both map to the same underlying observability profile key (`acceleration`) in `EnvironmentMap._get_sensor_signal(...)`.

### Orbit and Object Rendering
- Planets get orbit line visuals around the current visible sun.
- Object glyph style depends on object kind (`sun`, `planet`, `rock_field`, `rock`, `curiosity`).
- Orbit alpha scales with computed signal strength.

### Observation/Progression Hook
`EnvironmentMap._observe_nearby_visible_objects()`:

- Loops currently visible `system0` objects.
- Skips already observed IDs.
- Auto-observes first object within `AUTO_OBSERVE_RADIUS`.
- Calls `ObservationSystem.observe_object(object_id)`.

This is the runtime environment discovery trigger that feeds memory/progression.

### Shared Spatial Hook to Body/Mind Context
Every `_process(delta)`:

- `GameState.sync_environment_ship_and_sun(player_position, _sun_position, _has_sun_position)`

This preserves shared-state linkage from environment movement to cross-view progression/readouts.

## Environment View and Sensor Presentation Mechanics (Current)

### Sidebar Availability and Sensor Unlock Rules
- Sensor toggles shown only when `GameState.get_effective_sensor_tier(sensor_id) > 0`.
- Debug sensor levels are included in effective tier resolution.
- Sidebar itself additionally gated by:
  - player tab toggle state (`sidebar_visible` from map state)
  - debug visibility flag (`env_sidebar`)

### Camera Rule
`EnvironmentView` applies ship state directly:

- `camera.position = player_position`
- `camera.rotation = player_rotation`

Result: player-centered, fixed-orientation perspective relative to ship motion.

### Acceleration Channel Split
- `acceleration1` gate controls only the g-force screen effect (`GForceOverlay`).
- `acceleration2` gate controls only the telemetry display (`AccelerationDisplay`).

### G-Force Overlay
`EnvironmentView._update_g_force_overlay(...)`:

- Uses `angular_velocity` and `linear_acceleration_magnitude` from map state.
- Computes target intensity with configurable rotation and linear gains.
- Smooths intensity over time.
- Drives shader params:
  - `intensity`
  - `pulse_time`
  - `pulse_depth`

### Thermal Overlay
`EnvironmentView._update_thermal_overlay(...)`:

- Consumes currently visible objects from `ObservationSystem`.
- Keeps only `system0` non-spawn objects with thermal signal > 0.
- Converts source directions into ship-relative frame.
- Applies distance falloff and kind-based source size.
- Picks strongest N sources (`THERMAL_MAX_SOURCES`) and smooths per-slot vector/strength.
- Writes shader params `source_i` and `intensity`.

### Motion Telemetry HUD
`AccelerationTelemetryDisplay.gd` receives:

- angular velocity
- linear acceleration vector
- ship position
- ship rotation

Display provides:

- normalized acceleration axes and vector
- normalized angular arc
- acceleration and angular trails
- textual readouts for position, heading, acceleration magnitude

## Debug Kinematic Controls (Current)

In `DebugVisibilityPanel` under Environment View -> Ship Kinematics:

- Thrust (`kine_acceleration`)
- Rot. Speed (`kine_rotation_speed`)
- Max Speed (`kine_max_speed`)
- Linear Drag (`kine_linear_drag`)

`DebugVisibilityManager` stores overrides in `_kinematic_overrides`, emits `kinematic_override_changed`, and `EnvironmentMap` consumes via `get_kinematic_override(...)` during movement integration.

Reset behavior:

- `reset_all_visibility()` clears sensor override levels and kinematic overrides.

## Data and Flow Summary

1. `ObservationSystem` exposes visible environment objects.
2. `EnvironmentMap` builds and filters map visuals; integrates ship kinematics.
3. `EnvironmentMap` publishes player state to `EnvironmentView`.
4. `EnvironmentView` drives camera + overlays + telemetry using that state.
5. `EnvironmentMap` auto-observation pushes discovery back into shared progression systems.

This keeps simulation ownership in map runtime while presentation remains in the view runtime.

## Desired End State (Recommended)

### 1) Keep EnvironmentMap as sole owner of movement simulation
Desired: all ship kinematics remain authored and integrated in one place (`EnvironmentMap`) with no duplicate movement logic in UI/view scripts.

Why: avoids divergence between displayed and simulated motion.

### 2) Treat sensor split as presentation channels over shared observability
Desired:

- Keep single data-channel semantics (`acceleration`) at observation data level.
- Keep UI channel split (`acceleration1`, `acceleration2`) for independent effect/readout gating.

Why: preserves data simplicity while supporting UX control.

### 3) Keep observation-driven progression explicit and data-first
Desired:

- Continue proximity auto-observe as the canonical environment discovery trigger.
- Ensure every observable object has clear `reveals_memories` and progression consequences.
- Keep no ad-hoc local trackers in environment view/map for discovery state.

Why: aligns with the design loop: body unlocks sensors -> environment observation -> memory unlock -> further body/progression unlock.

### 4) Clarify movement-rule scaling by sensor progression (next step)
Current behavior does not yet gate movement range/handling by sensor strength.

Desired option:

- Define explicit rule(s) in data, for example:
  - max map reveal radius by sensor tier,
  - navigation assist quality by velocity/gravity tier,
  - stability penalties when key sensors are absent.

Why: to make sensor unlocks mechanically meaningful beyond visibility/filtering.

### 5) Stabilize kinematic tuning path
Desired:

- Keep debug overrides for rapid balancing.
- Add a clear handoff path from debug-tuned values into authored defaults/data assets when values are accepted.

Why: avoid permanent dependence on debug panel state for balance.

### 6) Tighten map readability contract
Desired:

- Preserve player-centered camera behavior.
- Preserve thermal directional cues and g-force pulse readability.
- Keep object rendering tied to actual sensor signal contribution.

Why: map should communicate what the player can sense now, not abstract object completeness.

### 7) Maintain cross-view shared-state linkage
Desired:

- Continue syncing ship/sun spatial relation into `GameState` as the shared link to body/mind consequences.
- Any new environment mechanic should emit through existing shared systems (`GameState`, `EventBus`, `ProgressionSystem`) rather than local one-off state.

Why: core architecture requirement is one shared simulation seen through multiple views.

## Open Ambiguities

- Docs still mention canonical `light_heat` while runtime UI/channel naming is `thermal` (and acceleration split into `acceleration1`/`acceleration2`). A terminology sync pass is likely needed.
- Kinematic overrides currently expose no explicit disable/authoring-state indicator beyond reset; this is acceptable for debug but should stay debug-only.
- Movement constraints are world-bounds based; no explicit environmental hazards/fields currently feed back into motion integration.

## Practical Next Implementation Targets

1. Define data-driven movement/sensor coupling rules (if desired by design) and apply in `EnvironmentMap` integration path.
2. Align docs terminology for sensor channels (`light_heat` vs `thermal`, split acceleration UI channels).
3. Optionally expose current effective kinematic values in `EnvironmentView` hover/debug output for faster balancing.
