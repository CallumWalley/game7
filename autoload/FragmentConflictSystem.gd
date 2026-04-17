extends Node

# Rival fragment systems are disabled during the current MVP.

var conflict_defs: Array = []
var conflict_by_node: Dictionary = {}
var activated_conflicts: Dictionary = {}
var resolved_conflicts: Dictionary = {}

func _ready() -> void:
	pass

func _load_conflicts() -> void:
	pass

func _on_state_changed() -> void:
	pass

func _try_activate_conflict(_conflict: Dictionary) -> void:
	pass

func get_active_conflicts() -> Array[Dictionary]:
	return []

func get_resolvable_conflicts() -> Array[Dictionary]:
	return []

func resolve_next_conflict() -> String:
	return ""

func resolve_conflict(_node_id: String) -> bool:
	return false

func _can_resolve(_conflict: Dictionary) -> bool:
	return false
