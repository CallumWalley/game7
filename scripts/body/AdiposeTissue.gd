@tool
extends "res://scripts/body/Biological.gd"

## Dense metabolic glucose storage buffer. No workers required.
## Requires only to be owned (connected to player-controlled node).
## 
## Charge rate: glucose intake from food sources
## Discharge rate: glucose delivery to connected nodes (approx 2x charge)
##
## Grows/shrinks visually with glucose level.
## Links pulse and thicken in proportion to charge/discharge activity.


func _get_component_type_id() -> String:
	return "adipose_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	var props := super()
	# Remove worker-related properties; ADI doesn't use workers
	props.erase("required_power")
	return props


func _activated_fill_primary() -> Color:
	return Color(0.78, 0.60, 0.18, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.58, 0.40, 0.08, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.24, 0.18, 0.06, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.16, 0.12, 0.04, 1.0)


## Override: ADI activates based on ownership alone, not worker power.
## Requires connection to player-controlled node.
func update_activation_from_workers() -> bool:
	var connected := is_connected_to_player_node()
	if connected != is_activated:
		is_activated = connected
		controlling_entity = GameState.ENTITY_PLAYER if connected else GameState.ENTITY_NONE
		if is_activated:
			GameState.report_component_controlled(self)
		activation_changed.emit(is_activated)
	_update_visual_state()
	return is_activated


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_adipose_tissue",
		"title": "Adipose Tissue",
		"text": "A dense glucose storage buffer that doesn't require workers—only connection to your controlled systems. Accumulates and releases glucose to meet demand.",
	}
