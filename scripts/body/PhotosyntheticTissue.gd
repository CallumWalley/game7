@tool
extends "res://scripts/body/ComponentBase.gd"

## Produces glucose when sufficiently powered by assigned workers.
## Charges connected adipose tissue components proportionally by their charge rates.

@export var glucose_production_per_cycle: float = 5.0
@export_enum("forward", "aft", "port", "starboard") var hull_side_primary: String = "forward"
@export_enum("none", "forward", "aft", "port", "starboard") var hull_side_secondary: String = "none"


func _get_component_type_id() -> String:
	return "photosynthetic_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"glucose_production_per_cycle": glucose_production_per_cycle,
		"hull_side_primary": hull_side_primary,
		"hull_side_secondary": hull_side_secondary,
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
	var dir := _side_to_direction(hull_side_primary)
	if hull_side_secondary != "none":
		dir += _side_to_direction(hull_side_secondary)
	if dir.length_squared() <= 0.0:
		return Vector2.RIGHT
	return dir.normalized()


func _side_to_direction(side: String) -> Vector2:
	match side:
		"forward":
			return Vector2.RIGHT
		"aft":
			return Vector2.LEFT
		"port":
			return Vector2.UP
		"starboard":
			return Vector2.DOWN
		_:
			return Vector2.ZERO


func get_food_output_per_cycle() -> float:
	"""Legacy method for compatibility. Returns charge amount."""
	return get_glucose_production_per_cycle()


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_photosynthetic_tissue",
		"title": "Photosynthetic Tissue",
		"text": "A metabolically active tissue layer that converts ambient radiation into glucose, charging connected adipose reserves.",
	}
