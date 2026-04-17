extends Node

var environment_objects: Array = []
var objects_by_id: Dictionary = {}

func _ready() -> void:
	_load_environment_objects()

func _load_environment_objects() -> void:
	environment_objects.clear()
	objects_by_id.clear()
	var file := FileAccess.open("res://data/environment_objects.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var parsed_array: Array = parsed
	environment_objects = parsed_array
	for obj_data in environment_objects:
		var obj_id: String = str(obj_data.get("id", ""))
		if obj_id != "":
			objects_by_id[obj_id] = obj_data

func get_visible_objects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj_data in environment_objects:
		if _requirements_met(obj_data):
			result.append(obj_data)
	return result

func get_next_observable_id() -> String:
	for obj_data in get_visible_objects():
		var obj_id: String = str(obj_data.get("id", ""))
		if obj_id != "" and not GameState.observed_environment.has(obj_id):
			return obj_id
	return ""

func observe_object(object_id: String) -> Dictionary:
	if not objects_by_id.has(object_id):
		return {"success": false, "reason": "missing"}

	var obj_data: Dictionary = objects_by_id[object_id]
	if not _requirements_met(obj_data):
		return {"success": false, "reason": "requirements"}

	if not GameState.observed_environment.has(object_id):
		GameState.record_observation(object_id)
		EventBus.emit_signal("environment_observed", object_id)

	return {"success": true, "id": object_id}

func _requirements_met(obj_data: Dictionary) -> bool:
	for sensor_id in obj_data.get("required_sensors", []):
		if not GameState.unlocked_sensors.has(str(sensor_id)):
			return false
	return _evaluate_condition(obj_data.get("unlock_condition", {}))

func _evaluate_condition(condition: Variant) -> bool:
	var c: Dictionary = condition
	var kind: String = str(c.get("type", ""))
	match kind:
		"all":
			for child in c.get("conditions", []):
				if not _evaluate_condition(child):
					return false
			return true
		"any":
			for child in c.get("conditions", []):
				if _evaluate_condition(child):
					return true
			return false
		"body_node_unlocked":
			return GameState.unlocked_body_nodes.has(str(c.get("id", "")))
		"memory_unlocked":
			return GameState.unlocked_memories.has(str(c.get("id", "")))
		"sensor_unlocked":
			return GameState.unlocked_sensors.has(str(c.get("id", "")))
		"observation_seen":
			return GameState.observed_environment.has(str(c.get("id", "")))
		"min_cycle":
			return GameState.cycle >= int(c.get("value", 0))
		_:
			return true
