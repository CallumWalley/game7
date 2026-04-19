extends CanvasLayer
## Debug visibility control panel — collapsible sections, drag handle only.

@onready var container: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/Margin/VBox

var _toggle_buttons: Dictionary = {}
var _type_buttons: Dictionary = {}
var _resource_buttons: Dictionary = {}
var _option_buttons: Dictionary = {}
var _sensor_level_boxes: Dictionary = {}
var _kinematic_boxes: Dictionary = {}
var _dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO

const INDENT_PX: int = 14
const HANDLE_HEIGHT: float = 18.0
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


func _ready() -> void:
	_build_panel()
	DebugVisibilityManager.visibility_changed.connect(_on_visibility_changed)
	DebugVisibilityManager.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugVisibilityManager.option_changed.connect(_on_option_changed)
	DebugVisibilityManager.sensor_level_changed.connect(_on_sensor_level_changed)
	DebugVisibilityManager.kinematic_override_changed.connect(_on_kinematic_override_changed)
	container.gui_input.connect(_on_container_gui_input)
	container.position = Vector2(12, 12)
	container.custom_minimum_size = Vector2(260, 0)
	visible = DebugVisibilityManager.is_debug_mode_enabled()


func _build_panel() -> void:
	for child in vbox.get_children():
		child.queue_free()
	_toggle_buttons.clear()
	_type_buttons.clear()
	_resource_buttons.clear()
	_option_buttons.clear()
	_sensor_level_boxes.clear()
	_kinematic_boxes.clear()

	# Drag handle — the draggable top strip
	var handle := Label.new()
	handle.text = "⠿ debug"
	handle.add_theme_font_size_override("font_size", 11)
	handle.modulate = Color(1, 1, 1, 0.45)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(handle)

	vbox.add_child(HSeparator.new())

	# Debug info (maps to body_hover_stats — all cards show extra info)
	_add_leaf(vbox, "Debug info", 0,
		DebugVisibilityManager.get_option(DebugVisibilityManager.OPTION_BODY_HOVER_STATS),
		func(v: bool): DebugVisibilityManager.set_option(DebugVisibilityManager.OPTION_BODY_HOVER_STATS, v),
		DebugVisibilityManager.OPTION_BODY_HOVER_STATS, _option_buttons
	)

	vbox.add_child(HSeparator.new())

	# Top Bar
	var top_bar_children := _add_section(vbox, "Top Bar", "")

	# Resource List (no power — power is invisible)
	var resource_children := _add_section(top_bar_children, "Resource List", "resource_list", INDENT_PX)
	for resource_type in GameState.RESOURCE_TYPE_ORDER:
		var res_label: String = GameState.RESOURCE_TYPE_LABELS.get(resource_type, resource_type)
		_add_leaf(resource_children, res_label, INDENT_PX * 2,
			DebugVisibilityManager.is_resource_type_encountered(resource_type),
			func(v: bool): DebugVisibilityManager.set_resource_type_encountered(resource_type, v),
			resource_type, _resource_buttons
		)

	# Worker List
	var worker_children := _add_section(top_bar_children, "Worker List", "worker_list", INDENT_PX)
	for node_type in GameState.NODE_TYPE_ORDER:
		var label_text: String = GameState.NODE_TYPE_LABELS.get(node_type, node_type)
		_add_leaf(worker_children, label_text, INDENT_PX * 2,
			DebugVisibilityManager.is_worker_type_encountered(node_type),
			func(v: bool): DebugVisibilityManager.set_worker_type_encountered(node_type, v),
			node_type, _type_buttons
		)

	# Time Controls
	var time_children := _add_section(top_bar_children, "Time Controls", "time_controls", INDENT_PX)
	_add_leaf(time_children, "x10 button", INDENT_PX * 2,
		DebugVisibilityManager.is_visible("speed_10_visible"),
		func(v: bool): DebugVisibilityManager.set_visibility("speed_10_visible", v),
		"speed_10_visible", _toggle_buttons
	)
	_add_leaf(time_children, "x100 button", INDENT_PX * 2,
		DebugVisibilityManager.is_visible("speed_100_visible"),
		func(v: bool): DebugVisibilityManager.set_visibility("speed_100_visible", v),
		"speed_100_visible", _toggle_buttons
	)
	_add_leaf(time_children, "Pause + x1 button", INDENT_PX * 2,
		DebugVisibilityManager.is_visible("pause_visible"),
		func(v: bool): DebugVisibilityManager.set_visibility("pause_visible", v),
		"pause_visible", _toggle_buttons
	)
	_add_leaf(time_children, "Cycle counter", INDENT_PX * 2,
		DebugVisibilityManager.is_visible("cycle_counter"),
		func(v: bool): DebugVisibilityManager.set_visibility("cycle_counter", v),
		"cycle_counter", _toggle_buttons
	)

	vbox.add_child(HSeparator.new())

	# Mind View
	var mind_children := _add_section(vbox, "Mind View", "mind_window")
	_add_leaf(mind_children, "Timeline", INDENT_PX,
		DebugVisibilityManager.is_visible("timeline_bar"),
		func(v: bool): DebugVisibilityManager.set_visibility("timeline_bar", v),
		"timeline_bar", _toggle_buttons
	)

	vbox.add_child(HSeparator.new())

	# Environment View
	var env_children := _add_section(vbox, "Environment View", "environment_window")
	_add_leaf(env_children, "Right Hand Panel", INDENT_PX,
		DebugVisibilityManager.is_visible("env_sidebar"),
		func(v: bool): DebugVisibilityManager.set_visibility("env_sidebar", v),
		"env_sidebar", _toggle_buttons
	)
	for sensor_id in SENSOR_IDS:
		_add_sensor_level_leaf(env_children, SENSOR_LABELS.get(sensor_id, sensor_id.capitalize()), INDENT_PX,
			DebugVisibilityManager.get_sensor_level(sensor_id), sensor_id)

	var kine_children := _add_section(env_children, "Ship Kinematics", "", INDENT_PX)
	_add_kinematic_leaf(kine_children, "Thrust", INDENT_PX * 2,
		DebugVisibilityManager.get_kinematic_override("kine_acceleration", 260.0),
		"kine_acceleration", 10.0, 2000.0, 10.0)
	_add_kinematic_leaf(kine_children, "Rot. Speed", INDENT_PX * 2,
		DebugVisibilityManager.get_kinematic_override("kine_rotation_speed", 2.4),
		"kine_rotation_speed", 0.1, 10.0, 0.1)
	_add_kinematic_leaf(kine_children, "Max Speed", INDENT_PX * 2,
		DebugVisibilityManager.get_kinematic_override("kine_max_speed", 420.0),
		"kine_max_speed", 50.0, 2000.0, 10.0)
	_add_kinematic_leaf(kine_children, "Linear Drag", INDENT_PX * 2,
		DebugVisibilityManager.get_kinematic_override("kine_linear_drag", 110.0),
		"kine_linear_drag", 0.0, 500.0, 5.0)

	vbox.add_child(HSeparator.new())

	var reset_btn := Button.new()
	reset_btn.text = "Reset All"
	reset_btn.pressed.connect(func():
		DebugVisibilityManager.reset_all_visibility()
		_build_panel()
	)
	vbox.add_child(reset_btn)


## Adds a collapsible section header. Returns a VBoxContainer for children.
func _add_section(parent: VBoxContainer, label_text: String, feature_key: String, indent_px: int = 0) -> VBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)

	if indent_px > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(indent_px, 0)
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		header.add_child(spacer)

	var expand_btn := Button.new()
	expand_btn.text = "▼"
	expand_btn.custom_minimum_size = Vector2(22, 0)
	expand_btn.flat = true
	expand_btn.toggle_mode = true
	expand_btn.button_pressed = false
	header.add_child(expand_btn)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl)

	if feature_key != "":
		var toggle := CheckButton.new()
		toggle.button_pressed = DebugVisibilityManager.is_visible(feature_key)
		toggle.toggled.connect(func(v: bool): DebugVisibilityManager.set_visibility(feature_key, v))
		header.add_child(toggle)
		_toggle_buttons[feature_key] = toggle

	parent.add_child(header)

	var children_vbox := VBoxContainer.new()
	children_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(children_vbox)

	expand_btn.toggled.connect(func(pressed: bool):
		children_vbox.visible = not pressed
		expand_btn.text = "►" if pressed else "▼"
	)

	return children_vbox


## Adds a leaf toggle row. Stores the CheckButton in store_dict under store_key.
func _add_leaf(parent: VBoxContainer, label_text: String, indent_px: int, is_checked: bool, callback: Callable, store_key: String, store_dict: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	if indent_px > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(indent_px, 0)
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hbox.add_child(spacer)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var toggle := CheckButton.new()
	toggle.button_pressed = is_checked
	toggle.toggled.connect(callback)
	hbox.add_child(toggle)

	parent.add_child(hbox)
	store_dict[store_key] = toggle


func _on_visibility_changed(feature: String, feature_visible: bool) -> void:
	if feature.begins_with("worker_type_"):
		var node_type := feature.trim_prefix("worker_type_")
		if node_type in _type_buttons:
			_type_buttons[node_type].button_pressed = feature_visible
	elif feature.begins_with("resource_type_"):
		var resource_type := feature.trim_prefix("resource_type_")
		if resource_type in _resource_buttons:
			_resource_buttons[resource_type].button_pressed = feature_visible
	elif feature in _toggle_buttons:
		_toggle_buttons[feature].button_pressed = feature_visible


func _on_debug_mode_changed(enabled: bool) -> void:
	visible = enabled


func _on_option_changed(option: String, value: bool) -> void:
	if option in _option_buttons:
		_option_buttons[option].button_pressed = value


func _on_sensor_level_changed(sensor_id: String, level: int) -> void:
	if sensor_id in _sensor_level_boxes:
		_sensor_level_boxes[sensor_id].set_value_no_signal(level)


func _on_kinematic_override_changed(param_id: String, value: float) -> void:
	if param_id in _kinematic_boxes:
		_kinematic_boxes[param_id].set_value_no_signal(value)


func _on_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and mouse_button.position.y <= HANDLE_HEIGHT:
				_dragging = true
				_drag_start_mouse = get_viewport().get_mouse_position()
				_drag_start_pos = container.position
			elif not mouse_button.pressed:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta := get_viewport().get_mouse_position() - _drag_start_mouse
		container.position = _drag_start_pos + delta


func _add_kinematic_leaf(parent: VBoxContainer, label_text: String, indent_px: int, value: float, param_id: String, min_val: float, max_val: float, step: float) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	if indent_px > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(indent_px, 0)
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hbox.add_child(spacer)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.rounded = false
	spin.custom_minimum_size = Vector2(88, 0)
	spin.value = value
	spin.value_changed.connect(func(v: float): DebugVisibilityManager.set_kinematic_override(param_id, v))
	hbox.add_child(spin)

	parent.add_child(hbox)
	_kinematic_boxes[param_id] = spin


func _add_sensor_level_leaf(parent: VBoxContainer, label_text: String, indent_px: int, level: int, sensor_id: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	if indent_px > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(indent_px, 0)
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hbox.add_child(spacer)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var level_box := SpinBox.new()
	level_box.min_value = 0
	level_box.max_value = 9
	level_box.step = 1
	level_box.rounded = true
	level_box.custom_minimum_size = Vector2(72, 0)
	level_box.value = level
	level_box.value_changed.connect(func(v: float): DebugVisibilityManager.set_sensor_level(sensor_id, int(v)))
	hbox.add_child(level_box)

	parent.add_child(hbox)
	_sensor_level_boxes[sensor_id] = level_box
