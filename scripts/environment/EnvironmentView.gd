extends "res://scripts/common/MapViewBase.gd"

const EDGE_MARGIN: float = 40.0
const UI_BLOCKER_GRACE_PX: float = 52.0
const SENSOR_IDS: Array[String] = ["light", "radio", "heat", "gamma", "gravity"]

@onready var radio_toggle: CheckBox = $Root/Sidebar/Sensors/RadioToggle
@onready var heat_toggle: CheckBox = $Root/Sidebar/Sensors/HeatToggle
@onready var light_toggle: CheckBox = $Root/Sidebar/Sensors/LightToggle
@onready var gamma_toggle: CheckBox = $Root/Sidebar/Sensors/GammaToggle
@onready var gravity_toggle: CheckBox = $Root/Sidebar/Sensors/GravityToggle
@onready var overlay: Control = $Root/MapArea/Overlay
@onready var hover_card: HoverInfoCard = $Root/MapArea/Overlay/HoverCard
@onready var viewport_container: SubViewportContainer = $Root/MapArea/Inset/VBox/SubViewportContainer
@onready var subviewport: SubViewport = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport
@onready var camera: Camera2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/Camera2D
@onready var world_root: Node2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/WorldRoot
@onready var sidebar: Control = $Root/Sidebar

var _active_sensor_filter: String = "light"
var _has_available_filters: bool = false
var _sidebar_visible_by_player_state: bool = true

func _ready() -> void:
	for sensor_id in SENSOR_IDS:
		_get_sensor_button(sensor_id).toggled.connect(_on_sensor_toggled.bind(sensor_id))
	GameState.state_changed.connect(_refresh)
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
	var available_filters: Array[String] = []
	for sensor_id in SENSOR_IDS:
		var button := _get_sensor_button(sensor_id)
		var is_unlocked := GameState.get_sensor_tier(sensor_id) > 0
		button.visible = is_unlocked
		if is_unlocked:
			available_filters.append(sensor_id)

	_has_available_filters = not available_filters.is_empty()
	_apply_sidebar_visibility_from_player_state(world_root.get_player_state())
	if available_filters.is_empty():
		_active_sensor_filter = ""
		world_root.set_active_sensor_filter("")
		return

	if not available_filters.has(_active_sensor_filter):
		_active_sensor_filter = available_filters[0]

	for sensor_id in available_filters:
		var button := _get_sensor_button(sensor_id)
		button.button_pressed = sensor_id == _active_sensor_filter

	world_root.set_active_sensor_filter(_active_sensor_filter)


func _apply_sidebar_visibility_from_player_state(state: Dictionary) -> void:
	_sidebar_visible_by_player_state = bool(state.get("sidebar_visible", true))
	sidebar.visible = _has_available_filters and _sidebar_visible_by_player_state


func _get_sensor_button(sensor_id: String) -> CheckBox:
	match sensor_id:
		"radio":
			return radio_toggle
		"heat":
			return heat_toggle
		"gamma":
			return gamma_toggle
		"gravity":
			return gravity_toggle
		_:
			return light_toggle


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
			_active_sensor_filter.capitalize(),
		],
		Vector2(-220, 14),
		6.0
	)
