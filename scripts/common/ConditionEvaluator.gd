extends RefCounted

static func evaluate(condition: Variant) -> bool:
	var c: Dictionary = condition
	var kind := str(c.get("type", ""))
	match kind:
		"all":
			for child in c.get("conditions", []):
				if not evaluate(child):
					return false
			return true
		"any":
			for child in c.get("conditions", []):
				if evaluate(child):
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
