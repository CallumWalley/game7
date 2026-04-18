extends Node

var conflict_defs: Array[Dictionary] = []
var conflict_by_node: Dictionary = {}
var activated_conflicts: Dictionary = {}
var resolved_conflicts: Dictionary = {}

func _ready() -> void:
	_load_conflicts()
	GameState.state_changed.connect(_on_state_changed)


func _load_conflicts() -> void:
	conflict_defs.clear()
	conflict_by_node.clear()
	var file := FileAccess.open("res://data/fragment_conflicts.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	for raw in (parsed as Array):
		var def := raw as Dictionary
		conflict_defs.append(def)
		var node_id := str(def.get("node_id", ""))
		if node_id != "":
			conflict_by_node[node_id] = def


func _on_state_changed() -> void:
	for def in conflict_defs:
		var conflict_id := str(def.get("id", ""))
		if resolved_conflicts.has(conflict_id):
			continue
		if activated_conflicts.has(conflict_id):
			continue
		_try_activate_conflict(def)


func _try_activate_conflict(conflict: Dictionary) -> void:
	var required_memory := str(conflict.get("required_memory", ""))
	if required_memory != "" and not GameState.unlocked_memories.has(required_memory):
		return
	var trigger_cycle := int(conflict.get("trigger_cycle", 0))
	if GameState.cycle < trigger_cycle:
		return
	var node_id := str(conflict.get("node_id", ""))
	if node_id == "" or GameState.contested_body_nodes.has(node_id):
		return
	var conflict_id := str(conflict.get("id", ""))
	activated_conflicts[conflict_id] = true
	GameState.mark_node_contested(node_id)
	GameState.unlock_memory("conflict_%s" % conflict_id)
	EventBus.fragment_node_contested.emit(node_id)


func get_active_conflicts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in conflict_defs:
		var conflict_id := str(def.get("id", ""))
		if activated_conflicts.has(conflict_id) and not resolved_conflicts.has(conflict_id):
			result.append(def)
	return result


func get_resolvable_conflicts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in get_active_conflicts():
		if _can_resolve(def):
			result.append(def)
	return result


func resolve_next_conflict() -> String:
	var resolvable := get_resolvable_conflicts()
	if resolvable.is_empty():
		return ""
	var first_node_id := str(resolvable[0].get("node_id", ""))
	resolve_conflict(first_node_id)
	return first_node_id


func resolve_conflict(node_id: String) -> bool:
	if not conflict_by_node.has(node_id):
		return false
	var def: Dictionary = conflict_by_node[node_id]
	var conflict_id := str(def.get("id", ""))
	if not activated_conflicts.has(conflict_id) or resolved_conflicts.has(conflict_id):
		return false
	resolved_conflicts[conflict_id] = true
	GameState.clear_node_contested(node_id)
	GameState.unlock_memory("conflict_%s_resolved" % conflict_id)
	EventBus.fragment_node_stabilized.emit(node_id)
	return true


func _can_resolve(_conflict: Dictionary) -> bool:
	# Resolution is available for any active conflict; callers decide cost.
	return true
