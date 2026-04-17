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
	color: Color = WORKER_DISPLAY_UTILS.ICON_FILL_COLOR,
	shape_radius: float = 8.0,
	circle_points: int = 18,
	stroke_color: Color = WORKER_DISPLAY_UTILS.ICON_STROKE_COLOR,
	stroke_width: float = WORKER_DISPLAY_UTILS.ICON_STROKE_WIDTH
) -> void:
	clear_markers(root)
	var marker_types := WORKER_DISPLAY_UTILS.ordered_worker_types(workers)
	for i in marker_types.size():
		var icon := Polygon2D.new()
		var shape := WORKER_DISPLAY_UTILS.shape_points_for_type(marker_types[i], shape_radius, circle_points)
		icon.polygon = shape
		icon.color = color
		icon.position = origin + step * float(i)
		icon.scale = Vector2.ONE * scale
		var stroke := Line2D.new()
		var stroke_points := shape.duplicate()
		if not stroke_points.is_empty():
			stroke_points.append(shape[0])
		stroke.points = stroke_points
		stroke.default_color = stroke_color
		stroke.width = stroke_width
		stroke.antialiased = true
		icon.add_child(stroke)
		root.add_child(icon)
