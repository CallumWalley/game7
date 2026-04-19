extends Node

const CONDITION_EVALUATOR := preload("res://scripts/common/ConditionEvaluator.gd")
const PROGRESSION_MIND_ENTRIES_PATH := "res://data/progression_mind_entries.json"
const SENSOR_MIND_ENTRIES_PATH := "res://data/sensor_mind_entries.json"

# Component-count-based sensor unlocks: own >= min_count activated components of type → unlock sensor at tier.
const COMPONENT_COUNT_SENSOR_UNLOCKS: Array[Dictionary] = [
	{"sensor_id": "thermal",      "component_type_id": "photosynthetic_tissue", "min_count": 2,  "tier": 1},
	{"sensor_id": "acceleration", "component_type_id": "membranous_labyrinth",  "min_count": 1,  "tier": 1},
	{"sensor_id": "acceleration", "component_type_id": "membranous_labyrinth",  "min_count": 3,  "tier": 2},
	{"sensor_id": "acceleration", "component_type_id": "membranous_labyrinth",  "min_count": 12, "tier": 3},
]

## Shared progression authority across Body, Environment, and Mind.
## Systems report facts here; this system applies progression consequences.

var progression_flags: Dictionary = {}
var _core_memory_defs: Array[Dictionary] = []
var _sensor_mind_entry_defs: Array[Dictionary] = []
var _refreshing_core_memories: bool = false


func _ready() -> void:
	_load_progression_mind_entries()
	_load_sensor_mind_entries()
	GameState.state_changed.connect(_refresh_core_memories_from_state)
	_refresh_core_memories_from_state()


func evaluate_condition(condition: Variant) -> bool:
	return CONDITION_EVALUATOR.evaluate(condition)


func ensure_sensor_tier(sensor_id: String, min_tier: int = 1) -> bool:
	var current_tier := GameState.get_sensor_tier(sensor_id)
	if current_tier >= min_tier:
		return false
	GameState.set_sensor_tier(sensor_id, min_tier)
	return true


func _load_progression_mind_entries() -> void:
	_core_memory_defs.clear()
	var file := FileAccess.open(PROGRESSION_MIND_ENTRIES_PATH, FileAccess.READ)
	for raw_def in (JSON.parse_string(file.get_as_text()) as Array):
		_core_memory_defs.append(raw_def as Dictionary)


func _load_sensor_mind_entries() -> void:
	_sensor_mind_entry_defs.clear()
	var file := FileAccess.open(SENSOR_MIND_ENTRIES_PATH, FileAccess.READ)
	var parsed: Array = JSON.parse_string(file.get_as_text())
	for raw_def in parsed:
		_sensor_mind_entry_defs.append(raw_def as Dictionary)


func _refresh_core_memories_from_state() -> void:
	if _refreshing_core_memories:
		return
	_refreshing_core_memories = true

	var changed_without_unlock_signal := false

	# Core progression logs (currently baseline stage only).
	for raw_def in _core_memory_defs:
		var def := raw_def as Dictionary
		var entry_id := str(def.get("id", "")).strip_edges()
		if entry_id == "":
			continue
		if _upsert_core_memory_entry(def, entry_id, 0):
			changed_without_unlock_signal = true

	# Rule passes in deterministic order: sensors -> sensor memories -> UI flags.
	_apply_component_count_sensor_unlocks()
	_refresh_sensor_mind_entries()
	_update_ui_unlock_flags()

	if changed_without_unlock_signal:
		GameState.emit_signal("state_changed")

	_refreshing_core_memories = false


func _update_ui_unlock_flags() -> void:
	"""Update UI visibility flags based on progression state."""
	var adi_count := GameState.get_owned_adipose_tissue_count()
	var food_counter_unlocked := adi_count >= 2
	var previous_flag: bool = bool(progression_flags.get("ui:food_counter_visible", false))
	if food_counter_unlocked != previous_flag:
		progression_flags["ui:food_counter_visible"] = food_counter_unlocked


func is_food_counter_visible() -> bool:
	"""Check if the food resource counter should be displayed."""
	return bool(progression_flags.get("ui:food_counter_visible", false))


func _upsert_core_memory_entry(def: Dictionary, entry_id: String, stage: int) -> bool:
	var state_def := _find_core_memory_state(def, stage)
	if state_def.is_empty():
		return false

	var was_unlocked := GameState.unlocked_memories.has(entry_id)
	var stage_key := "progress_memory_stage:%s" % entry_id
	var previous_stage := int(progression_flags.get(stage_key, -1))
	var stage_changed := previous_stage != stage

	GameState.register_dynamic_mind_entry(
		entry_id,
		str(state_def.get("title", entry_id)),
		str(state_def.get("text", ""))
	)
	GameState.unlock_memory(entry_id)

	if stage_changed and previous_stage >= 0:
		GameState.memory_read_state.erase(entry_id)

	progression_flags[stage_key] = stage
	return was_unlocked and stage_changed


func _find_core_memory_state(def: Dictionary, target_stage: int) -> Dictionary:
	var best_state: Dictionary = {}
	var best_stage := -999999
	for raw_state in def.get("states", []):
		var state := raw_state as Dictionary
		var stage_value := int(state.get("stage", 0))
		if stage_value > target_stage:
			continue
		if stage_value > best_stage:
			best_stage = stage_value
			best_state = state
	if not best_state.is_empty():
		return best_state
	for raw_state in def.get("states", []):
		return raw_state as Dictionary
	return {}


func _apply_component_count_sensor_unlocks() -> void:
	for raw_unlock in COMPONENT_COUNT_SENSOR_UNLOCKS:
		var unlock := raw_unlock as Dictionary
		var count := GameState.get_controlled_component_count(str(unlock.get("component_type_id", "")))
		if count >= int(unlock.get("min_count", 1)):
			ensure_sensor_tier(str(unlock.get("sensor_id", "")), int(unlock.get("tier", 1)))


func _refresh_sensor_mind_entries() -> void:
	for raw_def in _sensor_mind_entry_defs:
		var def := raw_def as Dictionary
		var entry_id := str(def.get("id", "")).strip_edges()
		var sensor_id := str(def.get("sensor_id", "")).strip_edges()
		if entry_id == "" or sensor_id == "":
			continue
		var tier := GameState.get_sensor_tier(sensor_id)
		if tier < 1:
			continue
		_upsert_core_memory_entry(def, entry_id, tier)


# Trigger entrypoint: node ownership changed to player.
func report_node_controlled(node: Node) -> void:
	GameState.report_node_controlled(node)


# Trigger entrypoint: component reached controlled/activated state.
func report_component_controlled(component: Node) -> void:
	GameState.report_component_controlled(component)


# Trigger entrypoint: component first hover discovery.
func report_component_first_hovered(component_type_id: String) -> void:
	GameState.on_component_first_hovered(component_type_id)


func record_environment_observation(observation_id: String, observation_def: Dictionary) -> void:
	if GameState.observed_environment.has(observation_id):
		return
	GameState.record_observation(observation_id)
	EventBus.environment_observed.emit(observation_id)
	_apply_observation_def(observation_def)
	progression_flags["observation:%s" % observation_id] = true


func _apply_observation_def(observation_def: Dictionary) -> void:
	var payload: Dictionary = observation_def.get("on_observed", {})
	for memory_id in payload.get("unlock_memories", []):
		GameState.unlock_memory(str(memory_id))
	for node_id in payload.get("unlock_body_nodes", []):
		GameState.unlock_body_node(str(node_id))
	for sensor_id in payload.get("unlock_sensors", []):
		ensure_sensor_tier(str(sensor_id), 1)

	var sensor_tiers: Dictionary = payload.get("sensor_tiers", {})
	for sensor_id in sensor_tiers.keys():
		ensure_sensor_tier(str(sensor_id), int(sensor_tiers[sensor_id]))
