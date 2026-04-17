extends RefCounted

const NODE_TYPE_ICON_SCRIPT := preload("res://scripts/ui/NodeTypeIcon.gd")
const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")


static func populate(container: Control, workers: Dictionary, icon_size: Vector2 = Vector2(18.0, 18.0)) -> void:
	for child in container.get_children():
		child.queue_free()
	for node_type in WORKER_DISPLAY_UTILS.ordered_worker_types(workers):
		var icon := Control.new()
		icon.custom_minimum_size = icon_size
		icon.set_script(NODE_TYPE_ICON_SCRIPT)
		icon.set("node_type", node_type)
		container.add_child(icon)
