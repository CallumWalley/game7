@tool
class_name GridDraw
extends Node2D

## Draws a faint static background grid behind the body map.
## Rendered once and cached by the CanvasItem system.

const SPACING: float = 64.0
const EXTENT: float  = 4096.0
const COLOR: Color   = Color(0.28, 0.32, 0.40, 0.10)


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _draw() -> void:
	var start := -EXTENT
	var end   :=  EXTENT
	var steps := int((end - start) / SPACING)
	for i: int in steps + 1:
		var t := start + i * SPACING
		draw_line(Vector2(t, start), Vector2(t, end),   COLOR)  # vertical
		draw_line(Vector2(start, t), Vector2(end,   t), COLOR)  # horizontal
