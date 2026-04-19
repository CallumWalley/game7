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


## Returns true if self has a route back to any active source node
## through the active (player-owned + enabled) ThoughtNode subgraph.
## Falls back to true if no source nodes are configured in the scene.
func is_connected_to_source_node() -> bool:
	if Engine.is_editor_hint():
		return true
	var all_clusters: Array = get_tree().get_nodes_in_group("nerve_clusters")
	var active: Dictionary = {}
	var seeds: Array = []
	var source_exists := false
	for cluster in all_clusters:
		if bool(cluster.get("is_source_node")):
			source_exists = true
		if int(cluster.get("controlling_entity")) != GameState.ENTITY_PLAYER:
			continue
		if not bool(cluster.get("is_enabled")):
			continue
		active[cluster] = true
		if bool(cluster.get("is_source_node")):
			seeds.append(cluster)
	# No is_source_node set in the map — skip connectivity requirement
	if not source_exists:
		return true
	# Source exists but isn't active — nothing is reachable
	if seeds.is_empty():
		return false
	# BFS through active bidirectional graph from all seeds
	var visited: Dictionary = {}
	var queue: Array = []
	for source_seed in seeds:
		visited[source_seed] = true
		queue.append(source_seed)
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		# Forward edges
		for neighbor in current.get_linked_body_objects():
			if visited.has(neighbor) or not active.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
		# Reverse edges
		for cluster in all_clusters:
			if visited.has(cluster) or not active.has(cluster):
				continue
			for linked in cluster.get_linked_body_objects():
				if linked == current:
					visited[cluster] = true
					queue.append(cluster)
					break
	# ThoughtNode: self must be in visited set
	if is_in_group("nerve_clusters"):
		return visited.has(self )
	# Component: any directly-linked active ThoughtNode must be reachable
	for neighbor in get_linked_body_objects():
		if visited.has(neighbor):
			return true
	return false
