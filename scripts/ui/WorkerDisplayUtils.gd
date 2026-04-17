extends RefCounted


static func ordered_worker_types(workers: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for node_type in GameState.NODE_TYPE_ORDER:
		for _i in int(workers.get(node_type, 0)):
			result.append(node_type)
	return result


static func format_worker_mix(workers: Dictionary) -> String:
	var parts: Array[String] = []
	for node_type in GameState.NODE_TYPE_ORDER:
		var count := int(workers.get(node_type, 0))
		if count <= 0:
			continue
		parts.append("%s:%d" % [GameState.get_node_type_label(node_type), count])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)


static func shape_points_for_type(node_type: String, radius: float = 8.0, circle_points: int = 18) -> PackedVector2Array:
	if node_type == GameState.NODE_TYPE_ARITHMETIC_PROCESSOR:
		return PackedVector2Array([
			Vector2(-radius, -radius),
			Vector2(radius, -radius),
			Vector2(radius, radius),
			Vector2(-radius, radius),
		])
	if node_type == GameState.NODE_TYPE_QUANTUM_CALCULATOR:
		return PackedVector2Array([
			Vector2(0.0, -radius * 1.1),
			Vector2(radius, radius * 0.9),
			Vector2(-radius, radius * 0.9),
		])
	var points := PackedVector2Array()
	for i in max(circle_points, 3):
		var ang := TAU * float(i) / float(max(circle_points, 3))
		points.append(Vector2(cos(ang), sin(ang)) * radius)
	return points
