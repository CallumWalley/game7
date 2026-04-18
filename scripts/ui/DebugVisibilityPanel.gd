extends CanvasLayer
## Debug visibility control panel.

@onready var container: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/Margin/VBox

var _toggle_buttons: Dictionary = {}
var _type_buttons: Dictionary = {}
var _option_buttons: Dictionary = {}
var _dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_panel()
	DebugVisibilityManager.visibility_changed.connect(_on_visibility_changed)
	DebugVisibilityManager.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugVisibilityManager.option_changed.connect(_on_option_changed)
	container.gui_input.connect(_on_container_gui_input)

	container.position = Vector2(12, 12)
	container.custom_minimum_size = Vector2(280, 0)
	visible = DebugVisibilityManager.is_debug_mode_enabled()


func _build_panel() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "DEBUG: UI Control (drag from top bar)"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var mode_hbox := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "Debug mode (~)"
	mode_label.custom_minimum_size = Vector2(160, 0)
	var mode_toggle := CheckButton.new()
	mode_toggle.button_pressed = DebugVisibilityManager.is_debug_mode_enabled()
	mode_toggle.toggled.connect(func(pressed: bool):
		DebugVisibilityManager.set_debug_mode_enabled(pressed)
	)
	mode_hbox.add_child(mode_label)
	mode_hbox.add_child(mode_toggle)
	vbox.add_child(mode_hbox)
	_option_buttons["debug_mode"] = mode_toggle

	var options_label := Label.new()
	options_label.text = "Debug Options:"
	vbox.add_child(options_label)

	_add_option_toggle("Log food ticks", DebugVisibilityManager.OPTION_DEBUG_LOG_FOOD_TICKS)
	_add_option_toggle("Body hover stats", DebugVisibilityManager.OPTION_BODY_HOVER_STATS)
	_add_option_toggle("ADI glucose stats", DebugVisibilityManager.OPTION_DEBUG_ADI_STATS)

	var features_label := Label.new()
	features_label.text = "UI Features:"
	vbox.add_child(features_label)

	for feature in ["mind_window", "environment_window", "time_controls", "timeline_bar"]:
		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = feature.replace("_", " ").capitalize()
		label.custom_minimum_size = Vector2(160, 0)
		var toggle := CheckButton.new()
		toggle.button_pressed = DebugVisibilityManager.is_visible(feature)
		toggle.toggled.connect(func(pressed: bool):
			DebugVisibilityManager.set_visibility(feature, pressed)
		)
		_toggle_buttons[feature] = toggle
		hbox.add_child(label)
		hbox.add_child(toggle)
		vbox.add_child(hbox)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var types_label := Label.new()
	types_label.text = "Worker Types Encountered:"
	vbox.add_child(types_label)

	for node_type in GameState.NODE_TYPE_ORDER:
		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = GameState.NODE_TYPE_LABELS.get(node_type, node_type)
		label.custom_minimum_size = Vector2(160, 0)
		var toggle := CheckButton.new()
		toggle.button_pressed = DebugVisibilityManager.is_worker_type_encountered(node_type)
		toggle.toggled.connect(func(pressed: bool):
			if pressed:
				DebugVisibilityManager.encounter_worker_type(node_type)
		)
		_type_buttons[node_type] = toggle
		hbox.add_child(label)
		hbox.add_child(toggle)
		vbox.add_child(hbox)

	var reset_btn := Button.new()
	reset_btn.text = "Reset All"
	reset_btn.pressed.connect(func():
		DebugVisibilityManager.reset_all_visibility()
		_build_panel()
	)
	vbox.add_child(reset_btn)
	_update_option_states()


func _on_visibility_changed(feature: String, visible: bool) -> void:
	if feature.begins_with("worker_type_"):
		var node_type := feature.trim_prefix("worker_type_")
		if node_type in _type_buttons:
			_type_buttons[node_type].button_pressed = visible
	elif feature in _toggle_buttons:
		_toggle_buttons[feature].button_pressed = visible


func _add_option_toggle(label_text: String, option_key: String) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	var toggle := CheckButton.new()
	toggle.button_pressed = DebugVisibilityManager.get_option(option_key)
	toggle.toggled.connect(func(pressed: bool):
		DebugVisibilityManager.set_option(option_key, pressed)
	)
	hbox.add_child(label)
	hbox.add_child(toggle)
	vbox.add_child(hbox)
	_option_buttons[option_key] = toggle


func _on_debug_mode_changed(enabled: bool) -> void:
	visible = enabled
	_update_option_states()


func _on_option_changed(option: String, value: bool) -> void:
	if option in _option_buttons:
		_option_buttons[option].button_pressed = value
	_update_option_states()


func _update_option_states() -> void:
	var debug_enabled := DebugVisibilityManager.is_debug_mode_enabled()
	for option in [
		DebugVisibilityManager.OPTION_DEBUG_LOG_FOOD_TICKS,
		DebugVisibilityManager.OPTION_BODY_HOVER_STATS,
		DebugVisibilityManager.OPTION_DEBUG_ADI_STATS,
	]:
		if option in _option_buttons:
			_option_buttons[option].disabled = not debug_enabled
	if "debug_mode" in _option_buttons:
		_option_buttons["debug_mode"].button_pressed = debug_enabled


func _on_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and mouse_button.position.y <= 26.0:
				_dragging = true
				_drag_start_mouse = get_viewport().get_mouse_position()
				_drag_start_pos = container.position
			elif not mouse_button.pressed:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta := get_viewport().get_mouse_position() - _drag_start_mouse
		container.position = _drag_start_pos + delta
