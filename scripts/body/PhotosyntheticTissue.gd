@tool
extends "res://scripts/body/ComponentBase.gd"

## Produces glucose when sufficiently powered by assigned workers.
## Charges connected adipose tissue components proportionally by their charge rates.

@export var glucose_production_per_cycle: float = 5.0


func _get_component_type_id() -> String:
	return "photosynthetic_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"glucose_production_per_cycle": glucose_production_per_cycle,
	}


func _activated_fill_primary() -> Color:
	return Color(0.30, 0.72, 0.36, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.16, 0.50, 0.20, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.12, 0.20, 0.14, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.07, 0.13, 0.09, 1.0)


func get_glucose_production_per_cycle() -> float:
	return glucose_production_per_cycle if is_activated else 0.0


func get_food_output_per_cycle() -> float:
	"""Legacy method for compatibility. Returns charge amount."""
	return get_glucose_production_per_cycle()


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_photosynthetic_tissue",
		"title": "Photosynthetic Tissue",
		"text": "A metabolically active tissue layer that converts ambient radiation into glucose, charging connected adipose reserves.",
	}
