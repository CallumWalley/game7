extends "res://scripts/common/MapViewBase.gd"

const EDGE_MARGIN: float = 40.0
const UI_BLOCKER_GRACE_PX: float = 52.0
const THERMAL_MAX_SOURCES: int = 6
const THERMAL_SOURCE_SIZE_BY_KIND := {
	"sun": 60.0,
	"planet": 26.0,
	"rock_field": 20.0,
	"curiosity": 16.0,
	"rock": 10.0,
}
const SENSOR_IDS: Array[String] = ["thermal", "radio", "velocity", "gamma", "gravity", "acceleration1", "acceleration2"]
const SENSOR_LABELS := {
	"thermal": "Thermal",
	"radio": "Radio",
	"velocity": "Velocity",
	"gamma": "Gamma",
	"gravity": "Gravity",
	"acceleration1": "G-Force",
	"acceleration2": "Motion",
}

@export var g_force_rotation_scale: float = 0.22
@export var g_force_linear_scale: float = 0.0028
@export var g_force_smoothing: float = 6.0
@export var g_force_pulse_speed_base: float = 1.8
@export var g_force_pulse_speed_gain: float = 6.4
@export var g_force_pulse_depth_base: float = 0.1
@export var g_force_pulse_depth_gain: float = 0.34
@export var thermal_edge_intensity: float = 0.9
@export var thermal_strength_smoothing: float = 7.0
@export var thermal_distance_falloff: float = 700.0

@onready var radio_toggle: CheckBox = $Root/Sidebar/Sensors/RadioToggle
@onready var thermal_toggle: CheckBox = $Root/Sidebar/Sensors/ThermalToggle
@onready var velocity_toggle: CheckBox = $Root/Sidebar/Sensors/VelocityToggle
@onready var gamma_toggle: CheckBox = $Root/Sidebar/Sensors/GammaToggle
@onready var gravity_toggle: CheckBox = $Root/Sidebar/Sensors/GravityToggle
@onready var acceleration1_toggle: CheckBox = $Root/Sidebar/Sensors/Acceleration1Toggle
@onready var acceleration2_toggle: CheckBox = $Root/Sidebar/Sensors/Acceleration2Toggle
@onready var overlay: Control = $Root/MapArea/Overlay
@onready var thermal_overlay: ColorRect = $Root/MapArea/Overlay/ThermalOverlay
@onready var g_force_overlay: ColorRect = $Root/MapArea/Overlay/GForceOverlay
@onready var acceleration_display: Control = $Root/MapArea/Overlay/AccelerationDisplay
@onready var hover_card: HoverInfoCard = $Root/MapArea/Overlay/HoverCard
@onready var viewport_container: SubViewportContainer = $Root/MapArea/Inset/VBox/SubViewportContainer
@onready var subviewport: SubViewport = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport
@onready var camera: Camera2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/Camera2D
@onready var world_root: Node2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/WorldRoot
@onready var sidebar: Control = $Root/Sidebar

var _enabled_sensor_filters: Dictionary = {}
var _has_available_filters: bool = false
var _sidebar_visible_by_player_state: bool = true
var _g_force_intensity: float = 0.0
var _g_force_pulse_time: float = 0.0
var _thermal_slots: Array[Vector4] = [
	Vector4.ZERO,
	Vector4.ZERO,
	Vector4.ZERO,
	Vector4.ZERO,
	Vector4.ZERO,
	Vector4.ZERO,
]

signal content_visibility_changed(has_content: bool)


func _ready() -> void:
	for sensor_id in SENSOR_IDS:
		_get_sensor_button(sensor_id).toggled.connect(_on_sensor_toggled.bind(sensor_id))
	GameState.state_changed.connect(_refresh)
	DebugVisibilityManager.visibility_changed.connect(_on_debug_visibility_changed)
	DebugVisibilityManager.sensor_level_changed.connect(_on_debug_sensor_level_changed)
	_refresh()


func _on_map_process(delta: float) -> void:
	var state: Dictionary = world_root.get_player_state()
	_lock_camera_to_player_state(state)
	_apply_sidebar_visibility_from_player_state(state)
	_update_g_force_overlay(state, delta)
	_update_thermal_overlay(state, delta)
	_update_acceleration_display(state)
	_update_hover_card()


func _on_map_interaction_disabled() -> void:
	_hide_card(hover_card)


func _get_map_viewport_container() -> SubViewportContainer:
	return viewport_container


func _get_map_subviewport() -> SubViewport:
	return subviewport


func _get_map_camera() -> Camera2D:
	return camera


func _is_edge_scroll_enabled() -> bool:
	return GameState.enable_push_scroll


func _get_edge_margin() -> float:
	return EDGE_MARGIN


func _is_mouse_over_ui_blocker() -> bool:
	var mouse_global := get_global_mouse_position()
	if sidebar.visible and _expand_rect(sidebar.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	if _expand_rect(overlay.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	if hover_card.visible and _expand_rect(hover_card.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	return false


func _expand_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position - Vector2.ONE * amount, rect.size + Vector2.ONE * amount * 2.0)


func _on_sensor_toggled(pressed: bool, sensor_id: String) -> void:
	_enabled_sensor_filters[sensor_id] = pressed
	world_root.set_enabled_sensor_filters(_get_enabled_sensor_filters())


func _refresh() -> void:
	var unlocked_filters: Array[String] = []
	for sensor_id in SENSOR_IDS:
		var sensor_button: CheckBox = _get_sensor_button(sensor_id)
		var unlocked := _is_sensor_available(sensor_id)
		sensor_button.visible = unlocked
		if unlocked:
			if not _enabled_sensor_filters.has(sensor_id):
				_enabled_sensor_filters[sensor_id] = true
			unlocked_filters.append(sensor_id)
		else:
			_enabled_sensor_filters.erase(sensor_id)

	var was_available := _has_available_filters
	_has_available_filters = not unlocked_filters.is_empty()
	if _has_available_filters != was_available:
		content_visibility_changed.emit(_has_available_filters)
	_apply_sidebar_visibility_from_player_state(world_root.get_player_state())
	if unlocked_filters.is_empty():
		var no_filters: Array[String] = []
		world_root.set_enabled_sensor_filters(no_filters)
		return

	for sensor_id in unlocked_filters:
		var sensor_button: CheckBox = _get_sensor_button(sensor_id)
		sensor_button.set_pressed_no_signal(bool(_enabled_sensor_filters.get(sensor_id, false)))

	world_root.set_enabled_sensor_filters(_get_enabled_sensor_filters())


func _apply_sidebar_visibility_from_player_state(state: Dictionary) -> void:
	_sidebar_visible_by_player_state = bool(state.get("sidebar_visible", true))
	var debug_gate := DebugVisibilityManager.is_visible("env_sidebar")
	sidebar.visible = _has_available_filters and _sidebar_visible_by_player_state and debug_gate
	acceleration_display.visible = _is_sensor_available("acceleration2") and _is_sensor_enabled("acceleration2")


func _get_sensor_button(sensor_id: String) -> CheckBox:
	match sensor_id:
		"thermal":
			return thermal_toggle
		"radio":
			return radio_toggle
		"velocity":
			return velocity_toggle
		"gamma":
			return gamma_toggle
		"gravity":
			return gravity_toggle
		"acceleration1":
			return acceleration1_toggle
		"acceleration2":
			return acceleration2_toggle
		_:
			return thermal_toggle


func _on_debug_visibility_changed(feature: String, _value: bool) -> void:
	if feature == "env_sidebar":
		_refresh()


func _on_debug_sensor_level_changed(_sensor_id: String, _level: int) -> void:
	_refresh()


func _lock_camera_to_player_state(state: Dictionary) -> void:
	var player_position: Vector2 = state.get("position", Vector2.ZERO)
	var player_rotation := float(state.get("rotation", 0.0))
	camera.position = player_position
	camera.rotation = player_rotation


func _update_g_force_overlay(state: Dictionary, delta: float) -> void:
	var shader_material := g_force_overlay.material as ShaderMaterial
	if not _is_sensor_available("acceleration1") or not _is_sensor_enabled("acceleration1"):
		_g_force_intensity = lerpf(_g_force_intensity, 0.0, 1.0 - exp(-g_force_smoothing * delta))
		shader_material.set_shader_parameter("intensity", _g_force_intensity)
		shader_material.set_shader_parameter("pulse_time", _g_force_pulse_time)
		shader_material.set_shader_parameter("pulse_depth", g_force_pulse_depth_base)
		return

	var angular_speed := absf(float(state.get("angular_velocity", 0.0)))
	var linear_accel := float(state.get("linear_acceleration_magnitude", 0.0))
	var target_intensity := clampf(
angular_speed * g_force_rotation_scale + linear_accel * g_force_linear_scale,
0.0,
1.0
)
	var lerp_factor := 1.0 - exp(-g_force_smoothing * delta)
	_g_force_intensity = lerpf(_g_force_intensity, target_intensity, lerp_factor)
	_g_force_pulse_time += delta * (g_force_pulse_speed_base + _g_force_intensity * g_force_pulse_speed_gain)

	shader_material.set_shader_parameter("intensity", _g_force_intensity)
	shader_material.set_shader_parameter("pulse_time", _g_force_pulse_time)
	shader_material.set_shader_parameter("pulse_depth", g_force_pulse_depth_base + _g_force_intensity * g_force_pulse_depth_gain)


func _update_thermal_overlay(state: Dictionary, delta: float) -> void:
	var material := thermal_overlay.material as ShaderMaterial
	if not _is_sensor_available("thermal") or not _is_sensor_enabled("thermal"):
		material.set_shader_parameter("intensity", 0.0)
		return

	var player_position: Vector2 = state.get("position", Vector2.ZERO)
	var player_rotation := float(state.get("rotation", 0.0))
	var candidates: Array[Dictionary] = []
	for obj_data in ObservationSystem.get_visible_objects():
		if str(obj_data.get("system_id", "")) != "system0":
			continue
		var kind := str(obj_data.get("kind", ""))
		if kind == "player_spawn":
			continue
		var observability_profile: Dictionary = obj_data.get("observability_profile", {})
		var thermal_signal := clampf(float(observability_profile.get("thermal", 0.0)), 0.0, 1.0)
		if thermal_signal <= 0.0:
			continue
		var obj_position := _to_vec2(obj_data.get("map_position", [0.0, 0.0]))
		var to_source := obj_position - player_position
		var distance := maxf(to_source.length(), 1.0)
		var direction := to_source / distance
		var rel_direction := direction.rotated(-player_rotation)
		var size := float(THERMAL_SOURCE_SIZE_BY_KIND.get(kind, 14.0))
		var distance_gain := 1.0 / (1.0 + distance / thermal_distance_falloff)
		candidates.append({
"dir": rel_direction,
"strength": thermal_signal * size * distance_gain,
})

	if candidates.is_empty():
		material.set_shader_parameter("intensity", 0.0)
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("strength", 0.0)) > float(b.get("strength", 0.0)))
	var peak_strength := float(candidates[0].get("strength", 1.0))
	for i in THERMAL_MAX_SOURCES:
		var target_slot := Vector4.ZERO
		if i < candidates.size():
			var source: Dictionary = candidates[i]
			var dir: Vector2 = source.get("dir", Vector2.RIGHT)
			var normalized_strength := clampf(float(source.get("strength", 0.0)) / maxf(peak_strength, 0.0001), 0.0, 1.0)
			target_slot = Vector4(dir.x, dir.y, normalized_strength, 0.0)
		var lerp_factor := 1.0 - exp(-thermal_strength_smoothing * delta)
		_thermal_slots[i] = _thermal_slots[i].lerp(target_slot, lerp_factor)
		material.set_shader_parameter("source_%d" % i, _thermal_slots[i])

	material.set_shader_parameter("intensity", thermal_edge_intensity)


func _update_acceleration_display(state: Dictionary) -> void:
	if not _is_sensor_available("acceleration2") or not _is_sensor_enabled("acceleration2"):
		return
	var angular_velocity := float(state.get("angular_velocity", 0.0))
	var linear_acceleration: Vector2 = state.get("linear_acceleration", Vector2.ZERO)
	var position: Vector2 = state.get("position", Vector2.ZERO)
	var rotation := float(state.get("rotation", 0.0))
	acceleration_display.call("set_motion_state", angular_velocity, linear_acceleration, position, rotation)


func _is_sensor_available(sensor_id: String) -> bool:
	return GameState.get_effective_sensor_tier(sensor_id) > 0


func _is_sensor_enabled(sensor_id: String) -> bool:
	return bool(_enabled_sensor_filters.get(sensor_id, false))


func _get_enabled_sensor_filters() -> Array[String]:
	var enabled_filters: Array[String] = []
	for sensor_id in SENSOR_IDS:
		if bool(_enabled_sensor_filters.get(sensor_id, false)):
			enabled_filters.append(sensor_id)
	return enabled_filters


func _get_enabled_filter_label() -> String:
	var labels: Array[String] = []
	for sensor_id in _get_enabled_sensor_filters():
		labels.append(SENSOR_LABELS.get(sensor_id, sensor_id.capitalize()))
	if labels.is_empty():
		return "None"
	return ", ".join(labels)


func _to_vec2(value: Variant) -> Vector2:
	var arr: Array = value
	return Vector2(float(arr[0]), float(arr[1]))


func _update_hover_card() -> void:
	if not _is_mouse_over_map():
		_hide_card(hover_card)
		return
	var visible_count := ObservationSystem.get_visible_objects().size()
	var observed_count := GameState.observed_environment.size()
	_show_card_at_mouse(
hover_card,
overlay,
"Environment",
"Visible: %d | Observed: %d\nFilter: %s" % [
visible_count,
observed_count,
_get_enabled_filter_label(),
		],
		Vector2(-220, 14),
		6.0
	)
