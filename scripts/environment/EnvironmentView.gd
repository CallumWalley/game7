extends "res://scripts/common/MapViewBase.gd"

const WORKER_ICON_STRIP := preload("res://scripts/ui/WorkerIconStrip.gd")
const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")

const EDGE_MARGIN: float = 40.0
const UI_BLOCKER_GRACE_PX: float = 52.0

@onready var radio_toggle: CheckBox = $Root/Sidebar/Sensors/RadioToggle
@onready var heat_toggle: CheckBox = $Root/Sidebar/Sensors/HeatToggle
@onready var light_toggle: CheckBox = $Root/Sidebar/Sensors/LightToggle
@onready var gamma_toggle: CheckBox = $Root/Sidebar/Sensors/GammaToggle
@onready var gravity_toggle: CheckBox = $Root/Sidebar/Sensors/GravityToggle
@onready var observe_button: Button = $Root/Sidebar/ObserveNextButton
@onready var overlay: Control = $Root/MapArea/Overlay
@onready var hover_card: HoverInfoCard = $Root/MapArea/Overlay/HoverCard
@onready var viewport_container: SubViewportContainer = $Root/MapArea/Inset/VBox/SubViewportContainer
@onready var subviewport: SubViewport = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport
@onready var camera: Camera2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/Camera2D
@onready var world_root: Node2D = $Root/MapArea/Inset/VBox/SubViewportContainer/SubViewport/WorldRoot
@onready var sidebar: Control = $Root/Sidebar
@onready var add_worker_button: Button = $Root/Sidebar/WorkerTaskButtons/AddWorkerButton
@onready var remove_worker_button: Button = $Root/Sidebar/WorkerTaskButtons/RemoveWorkerButton
@onready var worker_task_status: Label = $Root/Sidebar/WorkerTaskStatus
@onready var worker_task_icons: HBoxContainer = $Root/Sidebar/WorkerTaskIcons

const ENV_TASK_ID: String = "env_task_signal_decode"

func _ready() -> void:
	radio_toggle.toggled.connect(func(pressed: bool): _toggle_sensor("radio", pressed))
	heat_toggle.toggled.connect(func(pressed: bool): _toggle_sensor("heat", pressed))
	light_toggle.toggled.connect(func(pressed: bool): _toggle_sensor("light", pressed))
	gamma_toggle.toggled.connect(func(pressed: bool): _toggle_sensor("gamma", pressed))
	gravity_toggle.toggled.connect(func(pressed: bool): _toggle_sensor("gravity", pressed))
	observe_button.pressed.connect(_observe_next)
	add_worker_button.pressed.connect(_on_add_worker)
	remove_worker_button.pressed.connect(_on_remove_worker)
	GameState.ensure_named_task_target(ENV_TASK_ID, GameState.NODE_TYPE_QUANTUM_CALCULATOR, 15.0, 1.2, 0.3)
	GameState.state_changed.connect(_refresh)
	_refresh()


func _on_add_worker() -> void:
	GameState.assign_worker_to_target(ENV_TASK_ID)


func _on_remove_worker() -> void:
	GameState.remove_worker_from_target(ENV_TASK_ID)

func _on_map_process(_delta: float) -> void:
	_lock_camera_to_player_state()
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
	if _expand_rect(sidebar.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	if _expand_rect(overlay.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	if hover_card.visible and _expand_rect(hover_card.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	return false


func _expand_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position - Vector2.ONE * amount, rect.size + Vector2.ONE * amount * 2.0)

func _toggle_sensor(sensor_id: String, pressed: bool) -> void:
	if pressed:
		ProgressionSystem.ensure_sensor_tier(sensor_id, 1)
		TimeSystem.spend_for_action("scan")
	_refresh()

func _observe_next() -> void:
	var next_id := ObservationSystem.get_next_observable_id()
	if next_id == "":
		return
	var result := ObservationSystem.observe_object(next_id)
	if bool(result.get("success", false)):
		TimeSystem.spend_for_action("scan")
	_refresh()

func _refresh() -> void:
	radio_toggle.button_pressed = GameState.get_sensor_tier("radio") > 0
	heat_toggle.button_pressed = GameState.get_sensor_tier("heat") > 0
	light_toggle.button_pressed = GameState.get_sensor_tier("light") > 0
	gamma_toggle.button_pressed = GameState.get_sensor_tier("gamma") > 0
	gravity_toggle.button_pressed = GameState.get_sensor_tier("gravity") > 0
	observe_button.disabled = ObservationSystem.get_next_observable_id() == ""
	var workers := GameState.get_target_workers(ENV_TASK_ID)
	var worker_text := WORKER_DISPLAY_UTILS.format_worker_mix(workers)
	WORKER_ICON_STRIP.populate(worker_task_icons, workers)
	worker_task_status.text = "Progress: %d%% | Power: %.2f\nSensors: %s\nWorkers: %s" % [
		int(round(GameState.get_target_progress_ratio(ENV_TASK_ID) * 100.0)),
		GameState.get_target_total_power(ENV_TASK_ID),
		_build_sensor_text(),
		worker_text,
	]


func _build_sensor_text() -> String:
	var parts: Array[String] = []
	for sensor_id in ["radio", "heat", "light", "gamma", "gravity"]:
		parts.append("%s:%d" % [sensor_id, GameState.get_sensor_tier(sensor_id)])
	return " ".join(parts)


func _lock_camera_to_player_state() -> void:
	var state: Dictionary = world_root.get_player_state()
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
		"Visible: %d | Observed: %d\nDecode workers: %s\nDecode power: %.2f" % [
			visible_count,
			observed_count,
			WORKER_DISPLAY_UTILS.format_worker_mix(GameState.get_target_workers(ENV_TASK_ID)),
			GameState.get_target_total_power(ENV_TASK_ID),
		],
		Vector2(-220, 14),
		6.0
	)
