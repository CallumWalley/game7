extends Control

@onready var entry_list: ItemList = $Root/EntryList
@onready var entry_text: RichTextLabel = $Root/Content/EntryText
@onready var component_shape_preview = $Root/Content/ComponentShapeMargin/ComponentShapePreview

var entries: Array[Dictionary] = []
var visible_entries: Array[Dictionary] = []
const TYPEWRITER_SPEED: float = 40.0
const UNREAD_COLOR: Color = Color(1.0, 0.82, 0.3, 1.0)
const THOUGHT_DIVERGENCE_PLACEHOLDER := "?????"
var _awaiting_var_selection: bool = false
var _typewriter_active: bool = false
var _typewriter_elapsed: float = 0.0
var _typewriter_target: int = 0
var _typewriter_entry_id: String = ""
var _force_instant_entry_id: String = ""
var _inline_var_options: Dictionary = {}
var _inline_var_option_seq: int = 0
var _active_thought_divergence_token: String = ""
var _thought_divergence_menu: PopupMenu

func _ready() -> void:
	_load_entries()
	_thought_divergence_menu = PopupMenu.new()
	add_child(_thought_divergence_menu)
	_thought_divergence_menu.id_pressed.connect(_on_thought_divergence_option_selected)
	entry_list.item_selected.connect(_on_entry_selected)
	GameState.state_changed.connect(_refresh_entries)
	entry_text.meta_clicked.connect(_on_entry_text_meta_clicked)
	EventBus.component_memory_state_changed.connect(_on_component_memory_state_changed)
	_refresh_entries()


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
		if not _awaiting_var_selection:
			GameState.mark_memory_read(_typewriter_entry_id)
			_update_list_item_read_state(_typewriter_entry_id)


func _load_entries() -> void:
	var file := FileAccess.open("res://data/mind_entries.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var parsed_array: Array = parsed
	entries.clear()
	for raw_entry in parsed_array:
		entries.append(raw_entry as Dictionary)

func _populate_list() -> void:
	entry_list.clear()
	visible_entries.clear()
	var unlocked_entries: Array[Dictionary] = _get_unlocked_entries()
	for i in unlocked_entries.size():
		var entry_data: Dictionary = unlocked_entries[i]
		visible_entries.append(entry_data)
		var idx := entry_list.item_count
		entry_list.add_item(str(entry_data.get("title", "")))
		if not GameState.is_memory_read(str(entry_data.get("id", ""))):
			entry_list.set_item_custom_fg_color(idx, UNREAD_COLOR)


func _get_unlocked_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dynamic_by_id: Dictionary = {}
	var dynamic_order: Array[String] = []
	var dynamic_entries: Array[Dictionary] = []
	var runtime_dynamic_entries: Array = GameState.get_dynamic_mind_entries()
	for i in runtime_dynamic_entries.size():
		var raw_item: Dictionary = runtime_dynamic_entries[i] as Dictionary
		dynamic_entries.append(raw_item)
	for i in dynamic_entries.size():
		var dynamic_item: Dictionary = dynamic_entries[i]
		var dynamic_id := str(dynamic_item.get("id", "")).strip_edges()
		if dynamic_id == "":
			continue
		dynamic_by_id[dynamic_id] = dynamic_item
		dynamic_order.append(dynamic_id)

	for i in entries.size():
		var static_entry: Dictionary = entries[i]
		var entry_id := str(static_entry.get("id", "")).strip_edges()
		if entry_id == "" or GameState.unlocked_memories.has(entry_id):
			if dynamic_by_id.has(entry_id):
				var dynamic_entry := dynamic_by_id[entry_id] as Dictionary
				result.append(dynamic_entry)
			else:
				result.append(static_entry)
	for entry_id in dynamic_order:
		if not GameState.unlocked_memories.has(entry_id):
			continue
		if _contains_entry_id(result, entry_id):
			continue
		var dynamic_entry := dynamic_by_id[entry_id] as Dictionary
		result.append(dynamic_entry)
	return result


func _contains_entry_id(items: Array[Dictionary], entry_id: String) -> bool:
	for i in items.size():
		var entry_data: Dictionary = items[i]
		if str(entry_data.get("id", "")) == entry_id:
			return true
	return false

func _refresh_entries() -> void:
	var selected_id := _get_selected_entry_id()
	_populate_list()
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
	var entry: Dictionary = visible_entries[index]
	var entry_id := str(entry.get("id", ""))
	if _awaiting_var_selection and not _typewriter_active and _typewriter_entry_id == entry_id:
		# Keep the prompt visible and token mapping stable until the player chooses.
		entry_text.visible_characters = -1
		return
	if _typewriter_active and _typewriter_entry_id == entry_id:
		return
	_typewriter_active = false
	_awaiting_var_selection = false
	_inline_var_options.clear()
	var title := str(entry.get("title", "Untitled"))
	var body := _resolve_entry_text(entry)
	entry_text.text = "[b]%s[/b]\n\n%s" % [title, body]
	var component_type_id := str(entry.get("component_type_id", ""))
	if component_type_id != "":
		var shape_data := GameState.get_component_shape_data(component_type_id)
		if not shape_data.is_empty():
			component_shape_preview.set_shape(shape_data["verts"], shape_data["fill_color"], shape_data["outline_color"])
			component_shape_preview.visible = true
		else:
			component_shape_preview.visible = false
	else:
		component_shape_preview.visible = false
	if _force_instant_entry_id == entry_id:
		_force_instant_entry_id = ""
		entry_text.visible_characters = -1
		GameState.mark_memory_read(entry_id)
		_update_list_item_read_state(entry_id)
		return
	if GameState.is_memory_read(entry_id):
		entry_text.visible_characters = -1
	else:
		entry_text.visible_characters = 0
		_typewriter_entry_id = entry_id
		_typewriter_elapsed = 0.0
		_typewriter_target = entry_text.get_total_character_count()
		_typewriter_active = true


func _resolve_entry_text(entry_data: Dictionary) -> String:
	if not entry_data.has("text_segments"):
		return str(entry_data.get("text", ""))
	var component_type_id := str(entry_data.get("component_type_id", ""))
	var result := ""
	for raw_segment in entry_data.get("text_segments", []):
		var segment: Dictionary = raw_segment as Dictionary
		match str(segment.get("type", "text")):
			"text":
				result += GameState.render_component_text(str(segment.get("content", "")), component_type_id)
			"variable":
				var divergence_id := str(segment.get("thought_divergence_id", segment.get("key", ""))).strip_edges()
				var chosen := GameState.get_thought_divergence(divergence_id)
				if chosen == "":
					_awaiting_var_selection = true
					result += _build_thought_divergence_placeholder(divergence_id, segment.get("options", []))
					break
				result += chosen
	return result


func _build_thought_divergence_placeholder(divergence_id: String, options: Array) -> String:
	if options.is_empty():
		return "[i](missing options)[/i]"
	if divergence_id == "":
		return "[i](missing thoughtDivergence id)[/i]"
	var option_values: Array[String] = []
	for option: Variant in options:
		option_values.append(str(option))
	var token := "td%d" % _inline_var_option_seq
	_inline_var_option_seq += 1
	_inline_var_options[token] = {
		"thought_divergence_id": divergence_id,
		"options": option_values,
	}
	return "[url=td:%s]%s[/url]" % [token, THOUGHT_DIVERGENCE_PLACEHOLDER]


func _on_entry_text_meta_clicked(meta: Variant) -> void:
	var meta_text: String = str(meta)
	if not meta_text.begins_with("td:"):
		return
	var token := meta_text.substr(3)
	if not _inline_var_options.has(token):
		return
	_active_thought_divergence_token = token
	_show_thought_divergence_dropdown(token)


func _show_thought_divergence_dropdown(token: String) -> void:
	var option_data: Dictionary = _inline_var_options[token]
	var option_values: Array[String] = []
	for option: Variant in option_data.get("options", []):
		option_values.append(str(option))
	if option_values.is_empty():
		return
	_thought_divergence_menu.clear()
	for i in option_values.size():
		_thought_divergence_menu.add_item(option_values[i], i)
	var mouse_pos := get_viewport().get_mouse_position()
	_thought_divergence_menu.popup(Rect2i(Vector2i(mouse_pos), Vector2i(220, 1)))


func _on_thought_divergence_option_selected(option_index: int) -> void:
	if _active_thought_divergence_token == "":
		return
	if not _inline_var_options.has(_active_thought_divergence_token):
		return
	var option_data: Dictionary = _inline_var_options[_active_thought_divergence_token]
	var divergence_id := str(option_data.get("thought_divergence_id", "")).strip_edges()
	if divergence_id == "":
		return
	var option_values: Array[String] = []
	for option: Variant in option_data.get("options", []):
		option_values.append(str(option))
	if option_index < 0 or option_index >= option_values.size():
		return
	var selected_value := str(option_values[option_index])
	_active_thought_divergence_token = ""
	var selected := entry_list.get_selected_items()
	if selected.is_empty():
		return
	var selected_idx := int(selected[0])
	if selected_idx < 0 or selected_idx >= visible_entries.size():
		return
	var selected_entry := visible_entries[selected_idx] as Dictionary
	_force_instant_entry_id = str(selected_entry.get("id", ""))
	_awaiting_var_selection = false
	_typewriter_active = false
	GameState.set_thought_divergence(divergence_id, selected_value)


func _on_component_memory_state_changed(component_type_id: String, _new_state: int) -> void:
	var selected := entry_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := int(selected[0])
	if idx >= visible_entries.size():
		return
	if str(visible_entries[idx].get("component_type_id", "")) == component_type_id:
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