@tool
extends "res://scripts/body/ComponentBase.gd"

## Fluid-filled sensory structure. Produces signal clarity when powered,
## enhancing observation range for connected nodes.

@export var signal_clarity_per_cycle: float = 1.0


func _get_component_type_id() -> String:
	return "membranous_labyrinth"


func _get_preferred_node_type() -> String:
	return "quantum_calculator"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"signal_clarity_per_cycle": signal_clarity_per_cycle,
	}


func _activated_fill_primary() -> Color:
	return Color(0.22, 0.52, 0.78, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.12, 0.34, 0.60, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.10, 0.16, 0.26, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.07, 0.11, 0.18, 1.0)


func get_signal_clarity_per_cycle() -> float:
	return signal_clarity_per_cycle


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_membranous_labyrinth",
		"title": "Membranous Labyrinth",
		"text": "A fluid-filled sensory organ that processes spatial and directional signals.",
	}
