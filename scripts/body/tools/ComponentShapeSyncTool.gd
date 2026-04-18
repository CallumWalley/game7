@tool
extends Node

## Editor-only helper that keeps Outline and CollisionPolygon in sync with Polygon.

@export var sync_now: bool = false:
	set(value):
		sync_now = value
		if value:
			_sync_shape_from_polygon()
			sync_now = false


func _sync_shape_from_polygon() -> void:
	if not Engine.is_editor_hint():
		return

	var host := self
	var polygon := host.get_node("Polygon") as Polygon2D
	var outline := host.get_node("Outline") as Line2D
	var collision := host.get_node("HoverArea/CollisionPolygon") as CollisionPolygon2D
	var verts := polygon.polygon
	if verts.is_empty():
		return

	var line_points := verts.duplicate()
	line_points.append(verts[0])
	outline.points = line_points
	collision.polygon = verts
