extends Control

@onready var _mind_panel: Control    = $VBox/ContentArea/ViewStack/MindPanel
@onready var _body_panel: Control    = $VBox/ContentArea/ViewStack/BodyPanel
@onready var _env_panel: Control     = $VBox/ContentArea/ViewStack/EnvironmentPanel
@onready var _mind_btn: Button       = $VBox/BottomBar/HBox/MindButton
@onready var _body_btn: Button       = $VBox/BottomBar/HBox/BodyButton
@onready var _env_btn: Button        = $VBox/BottomBar/HBox/EnvironmentButton
@onready var cycle_label: Label      = $VBox/TopBar/Margin/HBox/CycleLabel
@onready var resource_label: Label   = $VBox/TopBar/Margin/HBox/ResourceLabel
@onready var system_menu: MenuButton = $VBox/TopBar/Margin/HBox/SystemMenu
@onready var pause_button: Button    = $VBox/TopBar/Margin/HBox/TimeControls/PauseButton
@onready var next_button: Button     = $VBox/TopBar/Margin/HBox/TimeControls/NextButton
@onready var speed_1_button: Button  = $VBox/TopBar/Margin/HBox/TimeControls/Speed1Button
@onready var speed_10_button: Button = $VBox/TopBar/Margin/HBox/TimeControls/Speed10Button
@onready var speed_100_button: Button = $VBox/TopBar/Margin/HBox/TimeControls/Speed100Button
@onready var neuron_count_label: Label = $VBox/TopBar/Margin/HBox/KeyStrip/NeuronGroup/Count
@onready var arithmetic_count_label: Label = $VBox/TopBar/Margin/HBox/KeyStrip/ArithmeticGroup/Count
@onready var quantum_count_label: Label = $VBox/TopBar/Margin/HBox/KeyStrip/QuantumGroup/Count

var _panels: Array
var _buttons: Array
var _current_tab: int = 1
var _is_paused: bool = false
var _tick_size: int = 1
var _time_accumulator: float = 0.0
const REAL_SECONDS_PER_TICK: float = 1.0
const MENU_ID_SAVE: int = 0
const MENU_ID_LOAD: int = 1
const MENU_ID_PUSH_SCROLL: int = 2
const MENU_ID_QUIT: int = 3


func _ready() -> void:
	_panels  = [_mind_panel, _body_panel, _env_panel]
	_buttons = [_mind_btn,   _body_btn,   _env_btn]
	_configure_menu()
	pause_button.pressed.connect(_set_paused.bind(true))
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
	_switch_tab(_current_tab)


func _process(delta: float) -> void:
	if _is_paused:
		return
	_time_accumulator += delta
	while _time_accumulator >= REAL_SECONDS_PER_TICK:
		_time_accumulator -= REAL_SECONDS_PER_TICK
		GameState.advance_cycles(_tick_size, "time")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_tab"):
		_switch_tab((_current_tab + 1) % _panels.size())
	elif event.is_action_pressed("prev_tab"):
		_switch_tab((_current_tab - 1 + _panels.size()) % _panels.size())


func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in _panels.size():
		_panels[i].visible = (i == index)
	_buttons[index].button_pressed = true


func _update_cycle_label() -> void:
	cycle_label.text = "Cycle %d" % GameState.cycle


func _update_resource_label() -> void:
	resource_label.text = "Food %.1f | -%.2f/tick | Power %.2f" % [GameState.food, GameState.last_tick_food_consumed, GameState.last_tick_power_total]


func _update_global_key() -> void:
	var counts := GameState.get_node_type_counts()
	var neuron: Dictionary = counts.get(GameState.NODE_TYPE_NEURON_CLUSTER, {})
	var arithmetic: Dictionary = counts.get(GameState.NODE_TYPE_ARITHMETIC_PROCESSOR, {})
	var quantum: Dictionary = counts.get(GameState.NODE_TYPE_QUANTUM_CALCULATOR, {})
	neuron_count_label.text = "%d / %d" % [int(neuron.get("idle", 0)), int(neuron.get("total", 0))]
	arithmetic_count_label.text = "%d / %d" % [int(arithmetic.get("idle", 0)), int(arithmetic.get("total", 0))]
	quantum_count_label.text = "%d / %d" % [int(quantum.get("idle", 0)), int(quantum.get("total", 0))]


func _configure_menu() -> void:
	var popup := system_menu.get_popup()
	popup.add_item("Save (placeholder)", MENU_ID_SAVE)
	popup.add_item("Load (placeholder)", MENU_ID_LOAD)
	popup.add_separator()
	popup.add_check_item("Enable push scroll", MENU_ID_PUSH_SCROLL)
	popup.set_item_checked(popup.get_item_index(MENU_ID_PUSH_SCROLL), GameState.enable_push_scroll)
	popup.add_item("Quit (placeholder)", MENU_ID_QUIT)
	popup.id_pressed.connect(_on_menu_id_pressed)


func _on_menu_id_pressed(id: int) -> void:
	if id == MENU_ID_PUSH_SCROLL:
		GameState.set_push_scroll_enabled(not GameState.enable_push_scroll)
		var popup := system_menu.get_popup()
		popup.set_item_checked(popup.get_item_index(MENU_ID_PUSH_SCROLL), GameState.enable_push_scroll)


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
	pause_button.disabled = _is_paused
	next_button.disabled = not _is_paused
	speed_1_button.disabled = _tick_size == 1 and not _is_paused
	speed_10_button.disabled = _tick_size == 10 and not _is_paused
	speed_100_button.disabled = _tick_size == 100 and not _is_paused
