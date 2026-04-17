@tool
extends Control

## Tiny polygon icon representing a player-owned NerveCluster.
## Draws a small irregular polygon in the player color for use in the key panel.

const VERTICES: int = 11
const ICON_RADIUS: float = 10.0
const ICON_COLOR: Color = Color(0.35, 0.62, 1.0, 1.0)

func _ready() -> void:
	custom_minimum_size = Vector2(ICON_RADIUS * 2 + 4, ICON_RADIUS * 2 + 4)


func _draw() -> void:
	var center := size * 0.5
	var points := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99137  # fixed seed so the shape is stable
	for i in VERTICES:
		var angle := (TAU / VERTICES) * i
		var r := ICON_RADIUS + rng.randf_range(-2.0, 2.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, ICON_COLOR)
