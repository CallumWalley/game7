extends Node

const CONDITION_EVALUATOR := preload("res://scripts/common/ConditionEvaluator.gd")

## Shared progression authority across Body, Environment, and Mind.
## Systems report progression facts here; this system applies unlock consequences.

var progression_flags: Dictionary = {}


func evaluate_condition(condition: Variant) -> bool:
	return CONDITION_EVALUATOR.evaluate(condition)


func ensure_sensor_tier(sensor_id: String, min_tier: int = 1) -> bool:
	var current_tier := GameState.get_sensor_tier(sensor_id)
	if current_tier >= min_tier:
		return false
	GameState.set_sensor_tier(sensor_id, min_tier)
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
