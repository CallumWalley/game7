extends Control

@onready var _mind_panel: Control = $VBox/ContentArea/ViewStack/MindPanel
@onready var _body_panel: Control = $VBox/ContentArea/ViewStack/BodyPanel
@onready var _env_panel: Control = $VBox/ContentArea/ViewStack/EnvironmentPanel
@onready var _mind_btn: Button = $VBox/BottomBar/HBox/MindButton
@onready var _body_btn: Button = $VBox/BottomBar/HBox/BodyButton
@onready var _env_btn: Button = $VBox/BottomBar/HBox/EnvironmentButton
@onready var cycle_label: Label = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/CycleLabel
@onready var resource_label: Label = $VBox/TopBar/Margin/HBox/LeftZone/ResourceLabel
@onready var time_controls: HBoxContainer = $VBox/TopBar/Margin/HBox/RightZone/TimeControls
@onready var pause_button: Button = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/PauseButton
@onready var next_button: Button = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/NextButton
@onready var speed_1_button: Button = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/Speed1Button
@onready var speed_10_button: Button = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/Speed10Button
@onready var speed_100_button: Button = $VBox/TopBar/Margin/HBox/RightZone/TimeControls/Speed100Button
@onready var neuron_group: HBoxContainer = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/NeuronGroup
@onready var arithmetic_group: HBoxContainer = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/ArithmeticGroup
@onready var quantum_group: HBoxContainer = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/QuantumGroup
@onready var neuron_count_label: Label = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/NeuronGroup/Count
@onready var arithmetic_count_label: Label = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/ArithmeticGroup/Count
@onready var quantum_count_label: Label = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip/QuantumGroup/Count
@onready var _key_strip: HBoxContainer = $VBox/TopBar/Margin/HBox/CenterZone/KeyStrip
@onready var mind_view: Control = $VBox/ContentArea/ViewStack/MindPanel
@onready var debug_visibility_panel: CanvasLayer = $DebugVisibilityPanel
@onready var settings_menu_window: Window = $SettingsMenu
@onready var system_menu_card: Control = $SystemMenuCard
@onready var menu_save_button: Button = $SystemMenuCard/Panel/Margin/VBox/MenuButtons/SaveButton
@onready var menu_load_button: Button = $SystemMenuCard/Panel/Margin/VBox/MenuButtons/LoadButton
@onready var menu_settings_button: Button = $SystemMenuCard/Panel/Margin/VBox/MenuButtons/SettingsButton
@onready var menu_debug_button: Button = $SystemMenuCard/Panel/Margin/VBox/MenuButtons/DebugModeButton
@onready var menu_quit_button: Button = $SystemMenuCard/Panel/Margin/VBox/MenuButtons/QuitButton
@onready var menu_close_button: Button = $SystemMenuCard/Panel/Margin/VBox/TopRow/CloseButton

var _panels: Array
var _buttons: Array
var _current_tab: int = 1
var _is_paused: bool = false
var _tick_size: int = 1
var _time_accumulator: float = 0.0
const REAL_SECONDS_PER_TICK: float = 1.0
const SETTINGS_PATH: String = "user://settings.cfg"
const FOOD_BALANCE_WARN_COLOR: Color = Color(1.0, 0.44, 0.40, 1.0)
const FOOD_BALANCE_GOOD_COLOR: Color = Color(0.60, 0.95, 0.68, 1.0)
const FOOD_BALANCE_NEUTRAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	_apply_tooltip_delay_from_settings()
	_panels = [_mind_panel, _body_panel, _env_panel]
	_buttons = [_mind_btn, _body_btn, _env_btn]
	_configure_system_menu_card()
	pause_button.toggled.connect(_set_paused)
	next_button.pressed.connect(_step_once)
	speed_1_button.pressed.connect(_set_speed.bind(1))
	speed_10_button.pressed.connect(_set_speed.bind(10))
	speed_100_button.pressed.connect(_set_speed.bind(100))
	_mind_btn.pressed.connect(func(): _switch_tab(0))
	_body_btn.pressed.connect(func(): _switch_tab(1))
	_env_btn.pressed.connect(func(): _switch_tab(2))
	_update_cycle_label()
	_update_resource_label()
	_update_global_key()
	_update_time_controls()
	GameState.state_changed.connect(_update_cycle_label)
	GameState.state_changed.connect(_update_resource_label)
	GameState.state_changed.connect(_update_global_key)
	_env_panel.content_visibility_changed.connect(
		func(_has: bool) -> void: _update_env_tab_visibility()
	)
	
	# Connect debug visibility manager
	DebugVisibilityManager.visibility_changed.connect(_on_debug_visibility_changed)
	DebugVisibilityManager.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugVisibilityManager.option_changed.connect(_on_debug_option_changed)
	_apply_initial_debug_visibility()
	_sync_debug_controls()


func _process(delta: float) -> void:
	if _is_paused:
		return
	_time_accumulator += delta
	while _time_accumulator >= REAL_SECONDS_PER_TICK:
		_time_accumulator -= REAL_SECONDS_PER_TICK
		GameState.advance_cycles(_tick_size, "time")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_system_menu_card()
		get_viewport().set_input_as_handled()
		return
	if system_menu_card.visible:
		return
	if event.is_action_pressed("next_tab"):
		_switch_tab((_current_tab + 1) % _panels.size())
	elif event.is_action_pressed("prev_tab"):
		_switch_tab((_current_tab - 1 + _panels.size()) % _panels.size())


func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in _panels.size():
		_panels[i].visible = (i == index)
	_buttons[index].button_pressed = true
	_validate_tab_buttons()


func _update_cycle_label() -> void:
	cycle_label.text = "Cycle %d" % GameState.cycle


func _update_resource_label() -> void:
	var food_counter_visible := (ProgressionSystem.is_food_counter_visible() \
		or DebugVisibilityManager.is_resource_type_encountered(GameState.RESOURCE_TYPE_FOOD)) \
		and DebugVisibilityManager.is_visible("resource_list")
	if food_counter_visible:
		var balance_per_tick := GameState.last_tick_food_output - GameState.last_tick_food_requested
		resource_label.text = "Food %.1f | %+0.2f/tick" % [GameState.food, balance_per_tick]
		if balance_per_tick < 0.0:
			resource_label.modulate = FOOD_BALANCE_WARN_COLOR
		elif balance_per_tick > 0.0:
			resource_label.modulate = FOOD_BALANCE_GOOD_COLOR
		else:
			resource_label.modulate = FOOD_BALANCE_NEUTRAL_COLOR
	else:
		resource_label.text = ""
		resource_label.modulate = FOOD_BALANCE_NEUTRAL_COLOR
	_update_resource_tooltip(food_counter_visible)
	resource_label.visible = food_counter_visible


func _update_resource_tooltip(should_show: bool) -> void:
	if not should_show:
		resource_label.tooltip_text = ""
		return
	var lines: Array[String] = []
	lines.append("Food Flow")
	lines.append("")
	lines.append("Sources (+/tick):")
	var source_total := 0.0
	if GameState.food_regen_per_tick != 0.0:
		source_total += GameState.food_regen_per_tick
		lines.append("- Baseline regen: +%.2f" % GameState.food_regen_per_tick)
	for component in get_tree().get_nodes_in_group("worker_components"):
		if str(component.get("component_type_id")) != "photosynthetic_tissue":
			continue
		if not bool(component.get("is_activated")):
			continue
		var production := float(component.call("get_glucose_production_per_cycle"))
		if production <= 0.0:
			continue
		source_total += production
		lines.append("- %s: +%.2f" % [component.name, production])
	if source_total == 0.0:
		lines.append("- none")
	lines.append("- Total sources: +%.2f" % source_total)
	lines.append("")
	lines.append("Sinks (-/tick requested):")
	var sink_total := 0.0
	for cluster in get_tree().get_nodes_in_group("nerve_clusters"):
		if int(cluster.get("controlling_entity")) != GameState.ENTITY_PLAYER:
			continue
		var requested := float(cluster.call("get_food_request_units"))
		if requested <= 0.0:
			continue
		sink_total += requested
		var cluster_name := str(cluster.get("concept_name")).strip_edges()
		if cluster_name == "":
			cluster_name = str(cluster.name)
		lines.append("- %s: -%.2f" % [cluster_name, requested])
	if sink_total == 0.0:
		lines.append("- none")
	lines.append("- Total sinks: -%.2f" % sink_total)
	resource_label.tooltip_text = "\n".join(lines)


func _apply_tooltip_delay_from_settings() -> void:
	var cfg := ConfigFile.new()
	var tooltip_seconds := 2.0
	if cfg.load(SETTINGS_PATH) == OK:
		tooltip_seconds = float(cfg.get_value("gameplay", "tooltip_seconds", 2.0))
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", tooltip_seconds)


func _update_global_key() -> void:
	var counts := GameState.get_node_type_counts()
	var neuron: Dictionary = counts.get(GameState.NODE_TYPE_NEURON_CLUSTER, {})
	var arithmetic: Dictionary = counts.get(GameState.NODE_TYPE_ARITHMETIC_PROCESSOR, {})
	var quantum: Dictionary = counts.get(GameState.NODE_TYPE_QUANTUM_CALCULATOR, {})
	
	# Update visibility based on encounter status
	neuron_group.visible = DebugVisibilityManager.is_worker_type_encountered(GameState.NODE_TYPE_NEURON_CLUSTER)
	arithmetic_group.visible = DebugVisibilityManager.is_worker_type_encountered(GameState.NODE_TYPE_ARITHMETIC_PROCESSOR)
	quantum_group.visible = DebugVisibilityManager.is_worker_type_encountered(GameState.NODE_TYPE_QUANTUM_CALCULATOR)
	
	# Update counts for visible groups
	neuron_count_label.text = "%d / %d" % [int(neuron.get("idle", 0)), int(neuron.get("total", 0))]
	arithmetic_count_label.text = "%d / %d" % [int(arithmetic.get("idle", 0)), int(arithmetic.get("total", 0))]
	quantum_count_label.text = "%d / %d" % [int(quantum.get("idle", 0)), int(quantum.get("total", 0))]


func _configure_system_menu_card() -> void:
	system_menu_card.visible = false
	menu_save_button.pressed.connect(func() -> void: print("Save placeholder"))
	menu_load_button.pressed.connect(func() -> void: print("Load placeholder"))
	menu_settings_button.pressed.connect(_open_settings_from_menu)
	menu_debug_button.pressed.connect(_toggle_debug_mode)
	menu_quit_button.pressed.connect(func() -> void: print("Quit placeholder"))
	menu_close_button.pressed.connect(_close_system_menu_card)
	settings_menu_window.close_requested.connect(_on_settings_window_closed)
	_sync_debug_controls()


func _toggle_system_menu_card() -> void:
	if system_menu_card.visible:
		_close_system_menu_card()
		return
	_open_system_menu_card()


func _open_system_menu_card() -> void:
	system_menu_card.visible = true
	_set_paused(true)
	_sync_debug_controls()


func _close_system_menu_card() -> void:
	if settings_menu_window.visible:
		settings_menu_window.hide()
	system_menu_card.visible = false
	_set_paused(false)


func _open_settings_from_menu() -> void:
	settings_menu_window.popup_centered_ratio(0.72)


func _on_settings_window_closed() -> void:
	settings_menu_window.hide()


func _toggle_debug_mode() -> void:
	DebugVisibilityManager.toggle_debug_mode()
	sync_to_debug_options()


func _set_paused(value: bool) -> void:
	_is_paused = value
	if not _is_paused:
		_time_accumulator = 0.0
	_update_time_controls()


func _step_once() -> void:
	if not _is_paused:
		return
	GameState.advance_cycles(_tick_size, "step")


func _set_speed(value: int) -> void:
	_tick_size = max(value, 1)
	_set_paused(false)


func _update_time_controls() -> void:
	pause_button.set_pressed_no_signal(_is_paused)
	next_button.disabled = not _is_paused
	speed_1_button.set_pressed_no_signal(_tick_size == 1)
	speed_10_button.set_pressed_no_signal(_tick_size == 10)
	speed_100_button.set_pressed_no_signal(_tick_size == 100)


func _apply_initial_debug_visibility() -> void:
	"""Apply initial visibility states from DebugVisibilityManager."""
	_mind_btn.visible = DebugVisibilityManager.is_visible("mind_window")
	_mind_btn.disabled = not DebugVisibilityManager.is_visible("mind_window")
	_update_env_tab_visibility()
	time_controls.visible = DebugVisibilityManager.is_visible("time_controls")
	pause_button.visible = DebugVisibilityManager.is_visible("pause_visible")
	speed_1_button.visible = DebugVisibilityManager.is_visible("pause_visible")
	speed_10_button.visible = DebugVisibilityManager.is_visible("speed_10_visible")
	speed_100_button.visible = DebugVisibilityManager.is_visible("speed_100_visible")
	cycle_label.visible = DebugVisibilityManager.is_visible("cycle_counter")
	_key_strip.visible = DebugVisibilityManager.is_visible("worker_list")
	_update_timeline_visibility()
	_switch_tab(_current_tab)
	_update_global_key()
	_update_resource_label()


func _on_debug_visibility_changed(feature: String, feature_visible: bool) -> void:
	"""Handle debug visibility changes."""
	match feature:
		"mind_window":
			_mind_btn.visible = feature_visible
			_mind_btn.disabled = not feature_visible
			if _current_tab == 0 and not feature_visible:
				_switch_tab(1)
		"environment_window":
			_update_env_tab_visibility()
		"time_controls":
			time_controls.visible = feature_visible
		"pause_visible":
			pause_button.visible = feature_visible
			speed_1_button.visible = feature_visible
		"cycle_counter":
			cycle_label.visible = feature_visible
		"speed_10_visible":
			speed_10_button.visible = feature_visible
		"speed_100_visible":
			speed_100_button.visible = feature_visible
		"resource_list":
			_update_resource_label()
		"worker_list":
			_key_strip.visible = feature_visible
			_update_global_key()
		"timeline_bar":
			_update_timeline_visibility()
		_:
			if feature.begins_with("worker_type_"):
				_update_global_key()
				_validate_tab_buttons()
			elif feature.begins_with("resource_type_"):
				_update_resource_label()


func _validate_tab_buttons() -> void:
	"""Ensure we're on a visible tab, switch if needed."""
	if _current_tab == 0 and not _mind_btn.visible:
		_switch_tab(1)
	elif _current_tab == 2 and not _env_btn.visible:
		_switch_tab(1)


func _update_env_tab_visibility() -> void:
	var has_content: bool = _env_panel.get("_has_available_filters")
	var visible := has_content and DebugVisibilityManager.is_visible("environment_window")
	_env_btn.visible = visible
	_env_btn.disabled = not visible
	if _current_tab == 2 and not visible:
		_switch_tab(1)


func _update_timeline_visibility() -> void:
	"""Update the timeline bar visibility based on debug settings."""
	var timeline = mind_view.get_node_or_null("Timeline")
	if timeline:
		timeline.visible = DebugVisibilityManager.is_visible("timeline_bar")


func _on_debug_mode_changed(_enabled: bool) -> void:
	_sync_debug_controls()


func _on_debug_option_changed(_option: String, _value: bool) -> void:
	_sync_debug_controls()


func sync_to_debug_options() -> void:
	_sync_debug_controls()


func _sync_debug_controls() -> void:
	debug_visibility_panel.visible = DebugVisibilityManager.is_debug_mode_enabled()
	menu_debug_button.toggle_mode = true
	menu_debug_button.button_pressed = DebugVisibilityManager.is_debug_mode_enabled()
	menu_debug_button.text = "Disable debug mode (~)" if menu_debug_button.button_pressed else "Enable debug mode (~)"
