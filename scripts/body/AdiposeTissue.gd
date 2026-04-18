@tool
extends "res://scripts/body/ComponentBase.gd"

## Dense metabolic buffer tissue. When powered, increases effective food
## storage capacity and smooths delivery to connected nodes.

@export var storage_units_per_cycle: float = 2.0


func _get_component_type_id() -> String:
	return "adipose_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	return {
		"required_power": required_power,
		"storage_units_per_cycle": storage_units_per_cycle,
	}


func _default_polygon_verts() -> PackedVector2Array:
	return PackedVector2Array([
Vector2(-52.0, -22.0),
Vector2(-14.0, -58.0),
Vector2(34.0, -56.0),
Vector2(66.0, -16.0),
Vector2(64.0, 28.0),
Vector2(22.0, 60.0),
Vector2(-28.0, 54.0),
Vector2(-60.0, 14.0),
])


func _activated_fill_primary() -> Color:
	return Color(0.78, 0.60, 0.18, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.58, 0.40, 0.08, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.24, 0.18, 0.06, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.16, 0.12, 0.04, 1.0)


func get_storage_units_per_cycle() -> float:
	return storage_units_per_cycle


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_adipose_tissue",
		"title": "Adipose Tissue",
		"text": "A dense energetic buffer that absorbs surplus food and releases it during lean cycles.",
	}
