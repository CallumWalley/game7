extends RefCounted

const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")


static func clear_markers(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()
	if root.has_meta("wb_types"):
		root.remove_meta("wb_types")


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
	var marker_types := WORKER_DISPLAY_UTILS.ordered_worker_types(workers)
	var count := marker_types.size()
	if count == 0:
		clear_markers(root)
		return
	var types_key := ",".join(marker_types)
	if root.get_meta("wb_types", "") != types_key:
		for child in root.get_children():
			child.free()
		root.set_meta("wb_types", types_key)
		for i in count:
			var icon := _build_worker_icon(
				marker_types[i],
				scale,
				color,
				shape_radius,
				circle_points,
				stroke_color,
				stroke_width
			)
			root.add_child(icon)
	for i in count:
		root.get_child(i).position = origin + step * float(i)


## WorkerBench display helper for task-assignment UI.
## Icons are packed in a tight arc around [param center] and orbit slowly.
## Only rebuilds icon nodes when the worker type/count changes; positions are
## updated every call so the orbit animation is smooth with no per-frame alloc.
##
## Tuning constants live in the caller (e.g. BodyView):
##   orbit_radius              – distance from center to icon centers in screen px
##   arc_step                  – angular gap between adjacent icons (radians)
##   orbit_phase               – radians of animated orbit offset
static func populate_orbiting_arc_from_workers(
	root: Node2D,
	workers: Dictionary,
	center: Vector2,
	base_angle: float,
	orbit_radius: float,
	arc_step: float,
	orbit_phase: float,
	scale: float,
	color: Color = WORKER_DISPLAY_UTILS.ICON_FILL_COLOR,
	shape_radius: float = 8.0,
	circle_points: int = 18,
	stroke_color: Color = WORKER_DISPLAY_UTILS.ICON_STROKE_COLOR,
	stroke_width: float = WORKER_DISPLAY_UTILS.ICON_STROKE_WIDTH
) -> void:
	var marker_types := WORKER_DISPLAY_UTILS.ordered_worker_types(workers)
	var count := marker_types.size()

	if count == 0:
		# Use free() so removal is immediate before any subsequent add.
		for child in root.get_children():
			child.free()
		root.set_meta("wb_types", "")
		return

	# Lazy rebuild: only recreate Polygon2D nodes when worker types change.
	var types_key := ",".join(marker_types)
	if root.get_meta("wb_types", "") != types_key:
		for child in root.get_children():
			child.free()
		root.set_meta("wb_types", types_key)
		for i in count:
			var icon := _build_worker_icon(
				marker_types[i],
				scale,
				color,
				shape_radius,
				circle_points,
				stroke_color,
				stroke_width
			)
			root.add_child(icon)

	# Update positions every call – this drives the orbit animation.
	# Icons are packed together: the cluster center tracks base_angle + orbit_phase,
	# and individual icons sit at adjacent steps around that point.
	var half_span := arc_step * float(count - 1) * 0.5
	var arc_start := base_angle + orbit_phase - half_span
	for i in count:
		var angle := arc_start + arc_step * float(i)
		root.get_child(i).position = center + Vector2(cos(angle), sin(angle)) * orbit_radius


static func _build_worker_icon(
	node_type: String,
	scale: float,
	color: Color,
	shape_radius: float,
	circle_points: int,
	stroke_color: Color,
	stroke_width: float
) -> Polygon2D:
	var icon := Polygon2D.new()
	var shape := WORKER_DISPLAY_UTILS.shape_points_for_type(node_type, shape_radius, circle_points)
	icon.polygon = shape
	icon.color = color
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
	return icon


