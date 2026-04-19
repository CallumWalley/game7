@tool
extends "res://scripts/body/ComponentBase.gd"

## Produces glucose when sufficiently powered by assigned workers.
## Charges connected adipose tissue components proportionally by their charge rates.

@export var glucose_production_per_cycle: float = 5.0

@export_range(0.0, 315, 45) var direction: float = 0.0

func _get_component_type_id() -> String:
	return "photosynthetic_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"glucose_production_per_cycle": glucose_production_per_cycle,
		"direction": direction,
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
	if not is_activated:
		return 0.0
	var sun_factor := GameState.get_surface_sun_factor(_get_surface_local_direction())
	return glucose_production_per_cycle * sun_factor


func get_sun_exposure_factor() -> float:
	return GameState.get_surface_sun_factor(_get_surface_local_direction())


func _get_surface_local_direction() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(float(direction)))


func get_food_output_per_cycle() -> float:
	"""Legacy method for compatibility. Returns charge amount."""
	return get_glucose_production_per_cycle()
