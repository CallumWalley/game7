@tool
extends "res://scripts/body/ThoughtNode.gd"

## Arithmetic processing node. Square shape.
## Placeholder: represents logical/sequential computational capability.

const HALF_SIZE: float = 32.0


func _build_shape_polygon() -> PackedVector2Array:
	var h := HALF_SIZE
	return PackedVector2Array([
Vector2(-h, -h),
Vector2(h, -h),
Vector2(h, h),
Vector2(-h, h),
])


func get_worker_node_type() -> String:
	return GameState.NODE_TYPE_ARITHMETIC_PROCESSOR


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "node_type_arithmetic_processor",
		"title": "ArithmeticProcessor",
		"text": "Deterministic compute units specialized in sequence, precision, and repeatability.",
	}
