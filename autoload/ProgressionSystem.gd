extends Node

## Evaluates generic unlock conditions used across systems.
## Body node placement is now scene-based; this system only provides
## the shared condition evaluator for gates in other systems (e.g. FragmentConflictSystem).

func evaluate_condition(condition: Variant) -> bool:
	return _check(condition)


func _check(c: Variant) -> bool:
	var d: Dictionary = c
	match str(d.get("type", "")):
		"all":
			for child in d.get("conditions", []):
				if not _check(child):
					return false
			return true
		"any":
			for child in d.get("conditions", []):
				if _check(child):
					return true
			return false
		"body_node_unlocked":
			return GameState.unlocked_body_nodes.has(str(d.get("id", "")))
		"memory_unlocked":
			return GameState.unlocked_memories.has(str(d.get("id", "")))
		"sensor_unlocked":
			return GameState.unlocked_sensors.has(str(d.get("id", "")))
		"observation_seen":
			return GameState.observed_environment.has(str(d.get("id", "")))
		"min_cycle":
			return GameState.cycle >= int(d.get("value", 0))
		_:
			return true
