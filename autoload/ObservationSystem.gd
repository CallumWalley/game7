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


func get_system_objects(system_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj_data in environment_objects:
		if str(obj_data.get("system_id", "")) != system_id:
			continue
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
		ProgressionSystem.record_environment_observation(object_id, obj_data)

	return {"success": true, "id": object_id}

func _requirements_met(obj_data: Dictionary) -> bool:
	if not bool(obj_data.get("is_observable", true)):
		return false

	for sensor_id in obj_data.get("required_sensors", []):
		if GameState.get_effective_sensor_tier(str(sensor_id)) < 1:
			return false

	var sensor_requirements: Dictionary = obj_data.get("sensor_requirements", {})
	for sensor_id in sensor_requirements.keys():
		if GameState.get_effective_sensor_tier(str(sensor_id)) < int(sensor_requirements[sensor_id]):
			return false

	return ProgressionSystem.evaluate_condition(obj_data.get("unlock_condition", {}))
