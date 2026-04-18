extends Node2D

const SYSTEM_ID := "system0"
const WORLD_BOUNDS := Rect2(Vector2(-1400.0, -900.0), Vector2(2800.0, 1800.0))

@export var player_acceleration: float = 260.0
@export var player_rotation_speed: float = 2.4
@export var player_max_speed: float = 420.0
@export var player_linear_drag: float = 110.0

var player_position: Vector2 = Vector2.ZERO
var player_rotation: float = 0.0
var player_velocity: Vector2 = Vector2.ZERO

@onready var objects_layer: Node2D = $ObjectsLayer
@onready var player_marker: Polygon2D = $PlayerMarker


func _ready() -> void:
	_build_system_objects()
	player_marker.position = player_position
	player_marker.rotation = player_rotation


func _process(delta: float) -> void:
	_integrate_player_motion(delta)
	player_marker.position = player_position
	player_marker.rotation = player_rotation


func get_player_state() -> Dictionary:
	return {
		"position": player_position,
		"rotation": player_rotation,
		"velocity": player_velocity,
		"acceleration": player_acceleration,
	}


func _build_system_objects() -> void:
	for child in objects_layer.get_children():
		child.queue_free()

	for obj_data in ObservationSystem.get_system_objects(SYSTEM_ID):
		var kind := str(obj_data.get("kind", ""))
		var pos := _to_vec2(obj_data.get("map_position", [0.0, 0.0]))
		if kind == "player_spawn":
			player_position = pos
			continue
		objects_layer.add_child(_build_object_visual(obj_data, pos))


func _build_object_visual(obj_data: Dictionary, pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = pos

	var kind := str(obj_data.get("kind", ""))
	var size := 14.0
	var color := Color(0.75, 0.8, 0.9, 0.85)
	match kind:
		"sun":
			size = 60.0
			color = Color(0.98, 0.78, 0.32, 0.96)
		"planet":
			size = 26.0
			color = Color(0.52, 0.7, 0.9, 0.88)
		"rock_field":
			size = 20.0
			color = Color(0.58, 0.62, 0.68, 0.75)
		"rock":
			size = 10.0
			color = Color(0.6, 0.63, 0.7, 0.7)
		"curiosity":
			size = 16.0
			color = Color(0.72, 0.9, 0.96, 0.9)

	var body := Polygon2D.new()
	body.polygon = _regular_polygon(size, 16)
	body.color = color
	root.add_child(body)

	if kind == "planet":
		var ring := Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(0.8, 0.86, 0.92, 0.55)
		ring.points = PackedVector2Array([
			Vector2(-size * 1.5, 0.0),
			Vector2(0.0, -size * 0.35),
			Vector2(size * 1.5, 0.0),
		])
		ring.closed = false
		root.add_child(ring)

	if kind == "curiosity":
		var halo := Polygon2D.new()
		halo.polygon = _regular_polygon(size * 1.65, 5)
		halo.color = Color(color.r, color.g, color.b, 0.22)
		root.add_child(halo)

	return root


func _integrate_player_motion(delta: float) -> void:
	var rotate_input := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	player_rotation += rotate_input * player_rotation_speed * delta

	var local_accel := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var world_accel := local_accel.rotated(player_rotation) * player_acceleration
	player_velocity += world_accel * delta
	player_velocity = player_velocity.limit_length(player_max_speed)
	player_velocity = player_velocity.move_toward(Vector2.ZERO, player_linear_drag * delta)

	player_position += player_velocity * delta
	player_position.x = clampf(player_position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
	player_position.y = clampf(player_position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)


func _to_vec2(value: Variant) -> Vector2:
	var arr: Array = value
	return Vector2(float(arr[0]), float(arr[1]))


func _regular_polygon(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
