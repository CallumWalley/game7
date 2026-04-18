@tool
extends "res://scripts/body/ComponentBase.gd"

## Produces food when sufficiently powered by assigned workers.

@export var food_output_per_cycle: float = 1.0
const HALF_SIZE: float = 64.0


func _get_component_type_id() -> String:
	return "photosynthetic_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"food_output_per_cycle": food_output_per_cycle,
	}


func _default_polygon_verts() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-HALF_SIZE, -HALF_SIZE),
		Vector2(HALF_SIZE, -HALF_SIZE),
		Vector2(HALF_SIZE, HALF_SIZE),
		Vector2(-HALF_SIZE, HALF_SIZE),
])


func _activated_fill_primary() -> Color:
	return Color(0.30, 0.72, 0.36, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.16, 0.50, 0.20, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.12, 0.20, 0.14, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.07, 0.13, 0.09, 1.0)


func get_food_output_per_cycle() -> float:
	return food_output_per_cycle


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_photosynthetic_tissue",
		"title": "Photosynthetic Tissue",
		"text": "A metabolically active tissue layer that converts ambient radiation into food reserves.",
	}
