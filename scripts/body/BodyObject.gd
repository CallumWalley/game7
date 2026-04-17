@tool
extends Node2D

## Base class for all objects placed on the body map.
## Do not instantiate directly.

## Inspector-authored links to other body objects.
## Drag objects here from the scene tree to establish graph links.
@export var linked_node_paths: Array[NodePath] = []


func get_linked_body_objects() -> Array:
	var result: Array = []
	for path in linked_node_paths:
		var node := get_node(path)
		if node == self:
			continue
		if result.has(node):
			continue
		result.append(node)
	return result


func get_connected_player_node() -> Node:
	for linked in get_linked_body_objects():
		if int(linked.get("controlling_entity")) == GameState.ENTITY_PLAYER:
			return linked
	return null


func get_connected_player_node_path() -> String:
	var node := get_connected_player_node()
	if node == null:
		return ""
	return str(node.get_path())


func is_connected_to_player_node() -> bool:
	return get_connected_player_node() != null
