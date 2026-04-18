extends Control

const WORKER_ICON_STRIP := preload("res://scripts/ui/WorkerIconStrip.gd")
const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")

@onready var entry_list: ItemList = $Root/EntryList
@onready var entry_text: RichTextLabel = $Root/Content/EntryText
@onready var add_worker_button: Button = $Root/Content/WorkerTaskButtons/AddWorkerButton
@onready var remove_worker_button: Button = $Root/Content/WorkerTaskButtons/RemoveWorkerButton
@onready var worker_task_status: Label = $Root/Content/WorkerTaskStatus
@onready var worker_task_icons: HBoxContainer = $Root/Content/WorkerTaskIcons
@onready var variable_selector: OptionButton = $Root/Content/VariableSelector
@onready var component_shape_preview = $Root/Content/ComponentShapePreview

var entries: Array = []
var visible_entries: Array = []
const MIND_TASK_ID: String = "mind_task_mnemonic_weave"
const TYPEWRITER_SPEED: float = 40.0
const UNREAD_COLOR: Color = Color(1.0, 0.82, 0.3, 1.0)
var _pending_var_component_type_id: String = ""
var _pending_var_key: String = ""
var _typewriter_active: bool = false
var _typewriter_elapsed: float = 0.0
var _typewriter_target: int = 0
var _typewriter_entry_id: String = ""

func _ready() -> void:
	_load_entries()
	entry_list.item_selected.connect(_on_entry_selected)
	add_worker_button.pressed.connect(_on_add_worker)
	remove_worker_button.pressed.connect(_on_remove_worker)
	GameState.ensure_named_task_target(MIND_TASK_ID, GameState.NODE_TYPE_ARITHMETIC_PROCESSOR, 12.0, 0.9, 0.3)
	GameState.state_changed.connect(_refresh_entries)
	variable_selector.item_selected.connect(_on_variable_selected)
	EventBus.component_memory_state_changed.connect(_on_component_memory_state_changed)
	_refresh_entries()


func _on_add_worker() -> void:
	GameState.assign_worker_to_target(MIND_TASK_ID)


func _on_remove_worker() -> void:
	GameState.remove_worker_from_target(MIND_TASK_ID)


func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	if not is_visible_in_tree():
		return
	_typewriter_elapsed += delta
	var new_chars := int(_typewriter_elapsed * TYPEWRITER_SPEED)
	entry_text.visible_characters = mini(new_chars, _typewriter_target)
	if entry_text.visible_characters >= _typewriter_target:
		_typewriter_active = false
		if _pending_var_key == "":
			GameState.mark_memory_read(_typewriter_entry_id)
			_update_list_item_read_state(_typewriter_entry_id)


func _load_entries() -> void:
	var file := FileAccess.open("res://data/mind_entries.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var parsed_array: Array = parsed
	entries = parsed_array

func _populate_list() -> void:
	entry_list.clear()
	visible_entries.clear()
	for item in _get_unlocked_entries():
		visible_entries.append(item)
		var idx := entry_list.item_count
		entry_list.add_item(str(item.get("title", "")))
		if not GameState.is_memory_read(str(item.get("id", ""))):
			entry_list.set_item_custom_fg_color(idx, UNREAD_COLOR)


func _get_unlocked_entries() -> Array:
	var result: Array = []
	for item in entries:
		var entry_id := str(item.get("id", "")).strip_edges()
		if entry_id == "" or GameState.unlocked_memories.has(entry_id):
			result.append(item)
	for item in GameState.get_dynamic_mind_entries():
		var entry_id := str(item.get("id", "")).strip_edges()
		if entry_id == "":
			continue
		if not GameState.unlocked_memories.has(entry_id):
			continue
		if _contains_entry_id(result, entry_id):
			continue
		result.append(item)
	return result


func _contains_entry_id(items: Array, entry_id: String) -> bool:
	for item in items:
		if str(item.get("id", "")) == entry_id:
			return true
	return false

func _refresh_entries() -> void:
	var selected_id := _get_selected_entry_id()
	_populate_list()
	var workers := GameState.get_target_workers(MIND_TASK_ID)
	WORKER_ICON_STRIP.populate(worker_task_icons, workers)
	worker_task_status.text = "Progress: %d%% | Power: %.2f\nWorkers: %s" % [
		int(round(GameState.get_target_progress_ratio(MIND_TASK_ID) * 100.0)),
		GameState.get_target_total_power(MIND_TASK_ID),
		WORKER_DISPLAY_UTILS.format_worker_mix(workers),
	]
	var restore_idx := _find_entry_index_by_id(selected_id)
	if restore_idx >= 0:
		entry_list.select(restore_idx)
		_display_entry(restore_idx)
	elif entry_list.item_count > 0:
		entry_list.select(0)
		_display_entry(0)
	else:
		entry_text.text = "No memories available."
func _on_entry_selected(index: int) -> void:
	_typewriter_active = false
	_display_entry(index)


func _display_entry(index: int) -> void:
	if index < 0 or index >= visible_entries.size():
		return
	var item: Dictionary = visible_entries[index]
	var entry_id := str(item.get("id", ""))
	if _typewriter_active and _typewriter_entry_id == entry_id:
		return
	_typewriter_active = false
	variable_selector.clear()
	variable_selector.visible = false
	_pending_var_component_type_id = ""
	_pending_var_key = ""
	var title := str(item.get("title", "Untitled"))
	var body := _resolve_entry_text(item)
	entry_text.text = "[b]%s[/b]\n\n%s" % [title, body]
	var component_type_id := str(item.get("component_type_id", ""))
	if component_type_id != "":
		var shape_data := GameState.get_component_shape_data(component_type_id)
		if not shape_data.is_empty():
			component_shape_preview.set_shape(shape_data["verts"], shape_data["fill_color"], shape_data["outline_color"])
			component_shape_preview.visible = true
		else:
			component_shape_preview.visible = false
	else:
		component_shape_preview.visible = false
	if GameState.is_memory_read(entry_id):
		entry_text.visible_characters = -1
	else:
		entry_text.visible_characters = 0
		_typewriter_entry_id = entry_id
		_typewriter_elapsed = 0.0
		_typewriter_target = entry_text.get_total_character_count()
		_typewriter_active = true


func _resolve_entry_text(item: Dictionary) -> String:
	if not item.has("text_segments"):
		return str(item.get("text", ""))
	var component_type_id := str(item.get("component_type_id", ""))
	var result := ""
	for segment in item.get("text_segments", []):
		match str(segment.get("type", "text")):
			"text":
				result += _substitute_component_vars(str(segment.get("content", "")), component_type_id)
			"variable":
				var var_key := str(segment.get("key", ""))
				var chosen := GameState.get_component_memory_var(component_type_id, var_key)
				if chosen == "":
					_pending_var_component_type_id = component_type_id
					_pending_var_key = var_key
					for option in segment.get("options", []):
						variable_selector.add_item(str(option))
					variable_selector.visible = true
					break
				result += chosen
	return result


func _substitute_component_vars(text: String, component_type_id: String) -> String:
	var result := text
	var controlled_count := GameState.get_controlled_component_count(component_type_id)
	var food_per := float(GameState.get_component_property(component_type_id, "food_output_per_cycle", 0.0))
	result = result.replace("{required_power}", str(GameState.get_component_property(component_type_id, "required_power", "?")))
	result = result.replace("{food_output_per_cycle}", str(food_per))
	result = result.replace("{controlled_count}", str(controlled_count))
	result = result.replace("{total_food_contribution}", "%.1f" % (controlled_count * food_per))
	return result


func _on_variable_selected(option_index: int) -> void:
	if _pending_var_key == "":
		return
	var value := variable_selector.get_item_text(option_index)
	GameState.set_component_memory_var(_pending_var_component_type_id, _pending_var_key, value)
	_pending_var_component_type_id = ""
	_pending_var_key = ""
	variable_selector.visible = false


func _on_component_memory_state_changed(component_type_id: String, _new_state: int) -> void:
	var selected := entry_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := int(selected[0])
	if idx >= visible_entries.size():
		return
	var item := visible_entries[idx]
	if str(item.get("component_type_id", "")) == component_type_id:
		_typewriter_active = false
		_display_entry(idx)


func _update_list_item_read_state(entry_id: String) -> void:
	for i in visible_entries.size():
		if str(visible_entries[i].get("id", "")) == entry_id:
			entry_list.set_item_custom_fg_color(i, Color(1.0, 1.0, 1.0, 1.0))
			break


func _get_selected_entry_id() -> String:
	var selected := entry_list.get_selected_items()
	if selected.is_empty():
		return ""
	var idx := int(selected[0])
	if idx >= visible_entries.size():
		return ""
	return str(visible_entries[idx].get("id", ""))


func _find_entry_index_by_id(entry_id: String) -> int:
	if entry_id == "":
		return -1
	for i in visible_entries.size():
		if str(visible_entries[i].get("id", "")) == entry_id:
			return i
	return -1
