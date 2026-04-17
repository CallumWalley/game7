extends RefCounted

const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")


static func clear_markers(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()


static func populate_from_workers(
	root: Node,
	workers: Dictionary,
	origin: Vector2,
	step: Vector2,
	scale: float,
	color: Color,
	shape_radius: float = 8.0,
	circle_points: int = 18
) -> void:
	clear_markers(root)
	var marker_types := WORKER_DISPLAY_UTILS.ordered_worker_types(workers)
	for i in marker_types.size():
		var icon := Polygon2D.new()
		icon.polygon = WORKER_DISPLAY_UTILS.shape_points_for_type(marker_types[i], shape_radius, circle_points)
		icon.color = color
		icon.position = origin + step * float(i)
		icon.scale = Vector2.ONE * scale
		root.add_child(icon)
