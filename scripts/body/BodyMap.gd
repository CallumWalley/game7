@tool
extends Node2D

## Minimal authoring helpers for large node maps.
## Toggle actions in the inspector to run them.

@export var run_validate_graph: bool = false:
	set(value):
		if _suppress_setters:
			run_validate_graph = value
			return
		if value:
			_validate_graph()
		_suppress_setters = true
		run_validate_graph = false
		_suppress_setters = false

var _suppress_setters: bool = false


func _get_clusters_root() -> Node:
	return get_node("ClustersRoot")


func _get_clusters() -> Array:
	var result: Array = []
	var root := _get_clusters_root()
	_collect_clusters_recursive(root, result)
	return result


func _collect_clusters_recursive(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_method("get_linked_clusters"):
			result.append(child)
		_collect_clusters_recursive(child, result)


func _validate_graph() -> void:
	if not Engine.is_editor_hint():
		return
	var clusters := _get_clusters()
	var by_id: Dictionary = {}
	var issues: Array[String] = []
	var reciprocal_added: Array[String] = []

	for cluster in clusters:
		var id := str(cluster.name)
		if id == "":
			issues.append("%s has empty name" % cluster.name)
			continue
		if by_id.has(id):
			issues.append("Duplicate name '%s' on %s and %s" % [id, by_id[id].name, cluster.name])
		else:
			by_id[id] = cluster

	for cluster in clusters:
		for path in cluster.get("linked_node_paths"):
			cluster.get_node(path)
		for linked in cluster.call("get_linked_nodes"):
			if linked == cluster:
				continue
			var reverse_path: NodePath = linked.get_path_to(cluster)
			var linked_paths: Array[NodePath] = (linked.get("linked_node_paths") as Array[NodePath]).duplicate()
			if linked_paths.has(reverse_path):
				continue
			linked_paths.append(reverse_path)
			linked.set("linked_node_paths", linked_paths)
			reciprocal_added.append("%s <- %s" % [linked.name, cluster.name])

	if not reciprocal_added.is_empty():
		print("[BodyMap] Validate Graph: added reciprocal links (%d):\n- %s" % [reciprocal_added.size(), "\n- ".join(reciprocal_added)])

	if not issues.is_empty():
		push_warning("[BodyMap] Validate Graph found %d issue(s):\n- %s" % [issues.size(), "\n- ".join(issues)])
	else:
		print("[BodyMap] Validate Graph: OK (%d clusters)" % clusters.size())
