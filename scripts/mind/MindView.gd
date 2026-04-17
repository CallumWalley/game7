extends Control

const WORKER_ICON_STRIP := preload("res://scripts/ui/WorkerIconStrip.gd")
const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")

@onready var entry_list: ItemList = $Root/EntryList
@onready var entry_text: RichTextLabel = $Root/Content/EntryText
@onready var add_worker_button: Button = $Root/Content/WorkerTaskButtons/AddWorkerButton
@onready var remove_worker_button: Button = $Root/Content/WorkerTaskButtons/RemoveWorkerButton
@onready var worker_task_status: Label = $Root/Content/WorkerTaskStatus
@onready var worker_task_icons: HBoxContainer = $Root/Content/WorkerTaskIcons

var entries: Array = []
var visible_entries: Array = []
const MIND_TASK_ID: String = "mind_task_mnemonic_weave"

func _ready() -> void:
	_load_entries()
	entry_list.item_selected.connect(_on_entry_selected)
	add_worker_button.pressed.connect(_on_add_worker)
	remove_worker_button.pressed.connect(_on_remove_worker)
	GameState.ensure_named_task_target(MIND_TASK_ID, GameState.NODE_TYPE_ARITHMETIC_PROCESSOR, 12.0, 0.9, 0.3)
	GameState.state_changed.connect(_refresh_entries)
	_refresh_entries()


func _on_add_worker() -> void:
	GameState.assign_worker_to_target(MIND_TASK_ID)


func _on_remove_worker() -> void:
	GameState.remove_worker_from_target(MIND_TASK_ID)

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
		entry_list.add_item(str(item.title))


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
	_populate_list()
	var workers := GameState.get_target_workers(MIND_TASK_ID)
	WORKER_ICON_STRIP.populate(worker_task_icons, workers)
	worker_task_status.text = "Progress: %d%% | Power: %.2f\nWorkers: %s" % [
		int(round(GameState.get_target_progress_ratio(MIND_TASK_ID) * 100.0)),
		GameState.get_target_total_power(MIND_TASK_ID),
		WORKER_DISPLAY_UTILS.format_worker_mix(workers),
	]
	if entry_list.item_count > 0:
		entry_list.select(0)
		_display_entry(0)
	else:
		entry_text.text = "No memories available."
func _on_entry_selected(index: int) -> void:
	_display_entry(index)


func _display_entry(index: int) -> void:
	if index < 0 or index >= visible_entries.size():
		return
	var item: Dictionary = visible_entries[index]
	entry_text.text = "[b]%s[/b]\n\n%s" % [item.get("title", "Untitled"), item.get("text", "")]
