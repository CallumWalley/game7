extends "res://scripts/common/MapViewBase.gd"

const EDGE_MARGIN: float = 40.0
const UI_BLOCKER_GRACE_PX: float = 52.0
const SENSOR_IDS: Array[String] = ["thermal", "radio", "velocity", "gamma", "gravity", "acceleration"]
const SENSOR_LABELS := {
	"thermal": "Thermal",
	"radio": "Radio",
	"velocity": "Velocity",
	"gamma": "Gamma",
	"gravity": "Gravity",
	"acceleration": "Acceleration",
}

@onready var radio_toggle: CheckBox = $Root/Sidebar/Sensors/RadioToggle
@onready var thermal_toggle: CheckBox = $Root/Sidebar/Sensors/ThermalToggle
@onready var velocity_toggle: CheckBox = $Root/Sidebar/Sensors/VelocityToggle
@onready var gamma_toggle: CheckBox = $Root/Sidebar/Sensors/GammaToggle
@onready var gravity_toggle: CheckBox = $Root/Sidebar/Sensors/GravityToggle
@onready var acceleration_toggle: CheckBox = $Root/Sidebar/Sensors/AccelerationToggle
@onready var overlay: Control = $Root/MapArea/Overlay
@onready var hover_card: HoverInfoCard = $Root/MapArea/Overlay/HoverCard
@onready var viewport_container: SubViewportContainer = $Root/MapArea/Inset/VBox/SubViewportContainer
@onready var subviewport: SubViewport = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport
@onready var camera: Camera2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/Camera2D
@onready var world_root: Node2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/WorldRoot
@onready var sidebar: Control = $Root/Sidebar

var _active_sensor_filter: String = "thermal"
var _has_available_filters: bool = false
var _sidebar_visible_by_player_state: bool = true

signal content_visibility_changed(has_content: bool)

func _ready() -> void:
	for sensor_id in SENSOR_IDS:
		_get_sensor_button(sensor_id).toggled.connect(_on_sensor_toggled.bind(sensor_id))
	GameState.state_changed.connect(_refresh)
	DebugVisibilityManager.visibility_changed.connect(_on_debug_visibility_changed)
	_refresh()


func _on_map_process(_delta: float) -> void:
	var state: Dictionary = world_root.get_player_state()
	_lock_camera_to_player_state(state)
	_apply_sidebar_visibility_from_player_state(state)
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
	if not pressed:
		return
	_active_sensor_filter = sensor_id
	world_root.set_active_sensor_filter(_active_sensor_filter)


func _refresh() -> void:
	var unlocked_filters: Array[String] = []
	for sensor_id in SENSOR_IDS:
		var sensor_button: CheckBox = _get_sensor_button(sensor_id)
		var unlocked := GameState.get_sensor_tier(sensor_id) > 0 or DebugVisibilityManager.get_sensor_visible(sensor_id)
		sensor_button.visible = unlocked
		if unlocked:
			unlocked_filters.append(sensor_id)

	var was_available := _has_available_filters
	_has_available_filters = not unlocked_filters.is_empty()
	if _has_available_filters != was_available:
		content_visibility_changed.emit(_has_available_filters)
	_apply_sidebar_visibility_from_player_state(world_root.get_player_state())
	if unlocked_filters.is_empty():
		_active_sensor_filter = ""
		world_root.set_active_sensor_filter("")
		return

	if not unlocked_filters.has(_active_sensor_filter):
		_active_sensor_filter = unlocked_filters[0]

	for sensor_id in unlocked_filters:
		var sensor_button: CheckBox = _get_sensor_button(sensor_id)
		sensor_button.button_pressed = sensor_id == _active_sensor_filter

	world_root.set_active_sensor_filter(_active_sensor_filter)


func _apply_sidebar_visibility_from_player_state(state: Dictionary) -> void:
	_sidebar_visible_by_player_state = bool(state.get("sidebar_visible", true))
	var debug_gate := DebugVisibilityManager.is_visible("env_sidebar")
	sidebar.visible = _has_available_filters and _sidebar_visible_by_player_state and debug_gate


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
		"acceleration":
			return acceleration_toggle
		_:
			return thermal_toggle


func _on_debug_visibility_changed(feature: String, _value: bool) -> void:
	if feature == "env_sidebar" or feature.begins_with("sensor_"):
		_refresh()


func _lock_camera_to_player_state(state: Dictionary) -> void:
	var player_position: Vector2 = state.get("position", Vector2.ZERO)
	var player_rotation := float(state.get("rotation", 0.0))
	camera.position = player_position
	camera.rotation = player_rotation


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
			SENSOR_LABELS.get(_active_sensor_filter, _active_sensor_filter.capitalize()),
		],
		Vector2(-220, 14),
		6.0
	)
