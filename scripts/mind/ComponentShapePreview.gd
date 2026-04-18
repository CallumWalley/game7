extends Control

var _polygon: PackedVector2Array
var _fill_color: Color
var _outline_color: Color


func set_shape(polygon: PackedVector2Array, fill_color: Color, outline_color: Color) -> void:
	_polygon = polygon
	_fill_color = fill_color
	_outline_color = outline_color
	queue_redraw()


func _draw() -> void:
	if _polygon.is_empty():
		return
	var bounds := _compute_bounds()
	if bounds.size.x < 1.0 or bounds.size.y < 1.0:
		return
	var s := minf(size.x / bounds.size.x, size.y / bounds.size.y) * 0.82
	var center := bounds.position + bounds.size * 0.5
	var display_center := size * 0.5
	var pts := PackedVector2Array()
	for pt in _polygon:
		pts.append(display_center + (pt - center) * s)
	draw_colored_polygon(pts, _fill_color)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], _outline_color, 2.0, true)


func _compute_bounds() -> Rect2:
	var min_pt := _polygon[0]
	var max_pt := _polygon[0]
	for pt in _polygon:
		min_pt = Vector2(minf(min_pt.x, pt.x), minf(min_pt.y, pt.y))
		max_pt = Vector2(maxf(max_pt.x, pt.x), maxf(max_pt.y, pt.y))
	return Rect2(min_pt, max_pt - min_pt)
