extends Node

const CONDITION_EVALUATOR := preload("res://scripts/common/ConditionEvaluator.gd")
const PROGRESSION_MIND_ENTRIES_PATH := "res://data/progression_mind_entries.json"
const AUTO_SENSOR_UNLOCKS: Array[Dictionary] = [
	{"sensor_id": "radio", "environment_stage": 1},
	{"sensor_id": "heat", "environment_stage": 2},
	{"sensor_id": "gamma", "body_stage": 2},
	{"sensor_id": "gravity", "body_stage": 2, "environment_stage": 3},
]

## Shared progression authority across Body, Environment, and Mind.
## Systems report progression facts here; this system applies unlock consequences.

var progression_flags: Dictionary = {}
var _core_memory_defs: Array[Dictionary] = []
var _refreshing_core_memories: bool = false


func _ready() -> void:
	_load_progression_mind_entries()
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
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var parsed_array: Array = parsed
	for raw_def in parsed_array:
		_core_memory_defs.append(raw_def as Dictionary)


func _refresh_core_memories_from_state() -> void:
	if _refreshing_core_memories:
		return
	_refreshing_core_memories = true

	var changed_without_unlock_signal := false
	var body_stage := _compute_body_progress_stage()
	var environment_stage := _compute_environment_progress_stage()
	var main_story_stage := _compute_main_story_stage(body_stage, environment_stage)

	for raw_def in _core_memory_defs:
		var def := raw_def as Dictionary
		var entry_id := str(def.get("id", "")).strip_edges()
		if entry_id == "":
			continue
		var track := str(def.get("track", ""))
		var stage := 0
		match track:
			"body":
				stage = body_stage
			"environment":
				stage = environment_stage
			_:
				stage = main_story_stage
		if _upsert_core_memory_entry(def, entry_id, stage):
			changed_without_unlock_signal = true

	progression_flags["progress_stage:body"] = body_stage
	progression_flags["progress_stage:environment"] = environment_stage
	progression_flags["progress_stage:main_story"] = main_story_stage
	_apply_auto_sensor_unlocks(body_stage, environment_stage)
	_update_ui_unlock_flags()

	if changed_without_unlock_signal:
		GameState.emit_signal("state_changed")

	_refreshing_core_memories = false


func _update_ui_unlock_flags() -> void:
	"""Update UI visibility flags based on progression state."""
	var adi_count := GameState.get_owned_adipose_tissue_count()
	var food_counter_unlocked := adi_count >= 2
	
	var previous_flag := progression_flags.get("ui:food_counter_visible", false)
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


func _compute_body_progress_stage() -> int:
	var controlled_nodes := _count_controlled_nodes()
	var activated_components := _count_activated_components()
	var contested_count := GameState.contested_body_nodes.size()
	var unlocked_body_count := maxi(0, GameState.unlocked_body_nodes.size() - contested_count)

	if unlocked_body_count >= 2 or controlled_nodes >= 5:
		return 3
	if activated_components >= 1:
		return 2
	if controlled_nodes >= 2:
		return 1
	return 0


func _compute_environment_progress_stage() -> int:
	var observed_count := GameState.observed_environment.size()
	var available_sensor_count := _count_available_sensors()

	if GameState.get_sensor_tier("gravity") >= 1 or observed_count >= 3:
		return 3
	if available_sensor_count >= 2 or observed_count >= 2:
		return 2
	if observed_count >= 1:
		return 1
	return 0


func _compute_main_story_stage(body_stage: int, environment_stage: int) -> int:
	if environment_stage >= 3:
		return 4
	if body_stage >= 2 and environment_stage >= 2:
		return 3
	if environment_stage >= 1:
		return 2
	if body_stage >= 1:
		return 1
	return 0


func _count_controlled_nodes() -> int:
	var counts := GameState.get_node_type_counts()
	var total := 0
	for node_type in GameState.NODE_TYPE_ORDER:
		var row: Dictionary = counts.get(node_type, {})
		total += int(row.get("total", 0))
	return total


func _count_activated_components() -> int:
	var activated := 0
	for component in get_tree().get_nodes_in_group("worker_components"):
		if bool(component.get("is_activated")):
			activated += 1
	return activated


func _count_available_sensors() -> int:
	var total := 0
	for sensor_id in GameState.unlocked_sensors.keys():
		if GameState.get_sensor_tier(str(sensor_id)) > 0:
			total += 1
	return total


func _apply_auto_sensor_unlocks(body_stage: int, environment_stage: int) -> void:
	for raw_unlock in AUTO_SENSOR_UNLOCKS:
		var unlock := raw_unlock as Dictionary
		if not _sensor_unlock_requirements_met(unlock, body_stage, environment_stage):
			continue
		ensure_sensor_tier(str(unlock.get("sensor_id", "")), int(unlock.get("tier", 1)))


func _sensor_unlock_requirements_met(unlock: Dictionary, body_stage: int, environment_stage: int) -> bool:
	var required_body_stage := int(unlock.get("body_stage", -1))
	if required_body_stage >= 0 and body_stage < required_body_stage:
		return false
	var required_environment_stage := int(unlock.get("environment_stage", -1))
	if required_environment_stage >= 0 and environment_stage < required_environment_stage:
		return false
	return true


func record_environment_observation(observation_id: String, observation_def: Dictionary) -> void:
	if GameState.observed_environment.has(observation_id):
		return
	GameState.record_observation(observation_id)
	EventBus.environment_observed.emit(observation_id)
	_apply_observation_def(observation_def)
	progression_flags["observation:%s" % observation_id] = true


func _apply_observation_def(observation_def: Dictionary) -> void:
	for memory_id in observation_def.get("reveals_memories", []):
		GameState.unlock_memory(str(memory_id))

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
