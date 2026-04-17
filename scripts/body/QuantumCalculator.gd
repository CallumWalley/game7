@tool
extends "res://scripts/body/GeometricNode.gd"

## Quantum calculation node. Equilateral triangle shape (pointing up).
## Placeholder: represents high-level probabilistic/quantum computation.

const RADIUS: float = 38.0


func _build_shape_polygon() -> PackedVector2Array:
	var r := RADIUS
	var half_rt3 := r * sqrt(3.0) / 2.0
	return PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(half_rt3, r * 0.5),
		Vector2(-half_rt3, r * 0.5),
	])


func get_worker_node_type() -> String:
	return GameState.NODE_TYPE_QUANTUM_CALCULATOR


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "node_type_quantum_calculator",
		"title": "QuantumCalculator",
		"text": "Probabilistic compute lattices that trade certainty for breadth and speed of inference.",
	}
