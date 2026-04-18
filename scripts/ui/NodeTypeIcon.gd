extends Control

const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")

@export var node_type: String = "neuron_cluster"
@export var fill_color: Color = WORKER_DISPLAY_UTILS.ICON_FILL_COLOR
@export var stroke_color: Color = WORKER_DISPLAY_UTILS.ICON_STROKE_COLOR
@export var stroke_width: float = WORKER_DISPLAY_UTILS.ICON_STROKE_WIDTH


func _draw() -> void:
	var shape := _shape_points()
	if shape.is_empty():
		return
	draw_colored_polygon(shape, fill_color)
	if shape.size() > 1:
		for i in shape.size():
			var a := shape[i]
			var b := shape[(i + 1) % shape.size()]
			draw_line(a, b, stroke_color, stroke_width)


func _shape_points() -> PackedVector2Array:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	var centered := WORKER_DISPLAY_UTILS.shape_points_for_type(node_type, r, 20)
	var points := PackedVector2Array()
	for p in centered:
		points.append(c + p)
	return points
