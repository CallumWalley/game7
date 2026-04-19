extends Node2D

const SYSTEM_ID := "system0"
const WORLD_BOUNDS := Rect2(Vector2(-1400.0, -900.0), Vector2(2800.0, 1800.0))
const AUTO_OBSERVE_RADIUS: float = 150.0
const ORBIT_SEGMENTS: int = 80
const SENSOR_FILTER_COLORS := {
	"thermal": Color(0.96, 0.82, 0.56, 1.0),
	"radio": Color(0.48, 0.92, 1.0, 1.0),
	"velocity": Color(0.72, 0.95, 0.68, 1.0),
	"gamma": Color(0.96, 0.7, 0.4, 1.0),
	"gravity": Color(0.62, 0.82, 1.0, 1.0),
	"acceleration": Color(1.0, 0.74, 0.38, 1.0),
}

@export var player_acceleration: float = 260.0
@export var player_rotation_speed: float = 2.4
@export var player_max_speed: float = 420.0
@export var player_linear_drag: float = 110.0

var player_position: Vector2 = Vector2.ZERO
var player_rotation: float = 0.0
var player_velocity: Vector2 = Vector2.ZERO
var player_sidebar_visible: bool = true
var _active_sensor_filter: String = "thermal"
var _player_spawn_initialized: bool = false
var _sun_position: Vector2 = Vector2.ZERO
var _has_sun_position: bool = false

@onready var orbits_layer: Node2D = $OrbitsLayer
@onready var objects_layer: Node2D = $ObjectsLayer
@onready var player_marker: Polygon2D = $PlayerMarker


func _ready() -> void:
	GameState.state_changed.connect(_build_system_objects)
	_build_system_objects()
	player_marker.position = player_position
	player_marker.rotation = player_rotation


func _process(delta: float) -> void:
	_integrate_player_motion(delta)
	_observe_nearby_visible_objects()
	GameState.sync_environment_ship_and_sun(player_position, _sun_position, _has_sun_position)
	player_marker.position = player_position
	player_marker.rotation = player_rotation


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		player_sidebar_visible = not player_sidebar_visible


func get_player_state() -> Dictionary:
	return {
		"position": player_position,
		"rotation": player_rotation,
		"velocity": player_velocity,
		"acceleration": player_acceleration,
		"sidebar_visible": player_sidebar_visible,
	}


func set_active_sensor_filter(sensor_id: String) -> void:
	var next_filter := sensor_id.strip_edges()
	if _active_sensor_filter == next_filter:
		return
	_active_sensor_filter = next_filter
	_build_system_objects()


func _build_system_objects() -> void:
	for child in orbits_layer.get_children():
		child.queue_free()
	for child in objects_layer.get_children():
		child.queue_free()

	var system_objects := _get_progression_visible_objects()
	var sun_position := Vector2.ZERO
	var has_sun := false
	for obj_data in system_objects:
		if str(obj_data.get("kind", "")) != "sun":
			continue
		sun_position = _to_vec2(obj_data.get("map_position", [0.0, 0.0]))
		has_sun = true
		break
	if has_sun:
		_build_orbit_visuals(system_objects, sun_position)
	_sun_position = sun_position
	_has_sun_position = has_sun

	for obj_data in system_objects:
		var kind := str(obj_data.get("kind", ""))
		var pos := _to_vec2(obj_data.get("map_position", [0.0, 0.0]))
		if kind == "player_spawn":
			if not _player_spawn_initialized:
				player_position = pos
				_player_spawn_initialized = true
			continue
		if not _passes_active_filter(obj_data):
			continue
		objects_layer.add_child(_build_object_visual(obj_data, pos))


func _get_progression_visible_objects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj_data in ObservationSystem.get_visible_objects():
		if str(obj_data.get("system_id", "")) == SYSTEM_ID:
			result.append(obj_data)
	for obj_data in ObservationSystem.get_system_objects(SYSTEM_ID):
		if str(obj_data.get("kind", "")) == "player_spawn":
			result.append(obj_data)
	return result


func _build_object_visual(obj_data: Dictionary, pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = pos

	var kind := str(obj_data.get("kind", ""))
	var signal_strength := _get_signal_strength(obj_data)
	var filter_tint := _get_filter_tint()
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
	color = color.lerp(filter_tint, 0.2 + signal_strength * 0.45)
	color.a *= 0.45 + signal_strength * 0.55

	var body := Polygon2D.new()
	body.polygon = _regular_polygon(size, 16)
	body.color = color
	root.add_child(body)

	if kind == "sun":
		var glow := Polygon2D.new()
		glow.polygon = _regular_polygon(size * 1.45, 18)
		glow.color = Color(color.r, color.g, color.b, 0.18)
		root.add_child(glow)

	if kind == "planet":
		var ring := Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(color.r, color.g, color.b, 0.48)
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


func _build_orbit_visuals(system_objects: Array[Dictionary], sun_position: Vector2) -> void:
	for obj_data in system_objects:
		if str(obj_data.get("kind", "")) != "planet":
			continue
		if not _passes_active_filter(obj_data):
			continue
		var orbit := Line2D.new()
		var orbit_radius := sun_position.distance_to(_to_vec2(obj_data.get("map_position", [0.0, 0.0])))
		var strength := _get_signal_strength(obj_data)
		orbit.width = 1.35
		orbit.closed = true
		orbit.default_color = Color(0.72, 0.82, 0.92, 0.08 + strength * 0.08)
		orbit.points = _orbit_points(sun_position, orbit_radius)
		orbits_layer.add_child(orbit)


func _orbit_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ORBIT_SEGMENTS:
		var angle := TAU * float(i) / float(ORBIT_SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _observe_nearby_visible_objects() -> void:
	for obj_data in ObservationSystem.get_visible_objects():
		if str(obj_data.get("system_id", "")) != SYSTEM_ID:
			continue
		var object_id := str(obj_data.get("id", ""))
		if object_id == "" or GameState.observed_environment.has(object_id):
			continue
		var obj_pos := _to_vec2(obj_data.get("map_position", [0.0, 0.0]))
		if player_position.distance_to(obj_pos) > AUTO_OBSERVE_RADIUS:
			continue
		var result := ObservationSystem.observe_object(object_id)
		if bool(result.get("success", false)):
			return


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


func _passes_active_filter(obj_data: Dictionary) -> bool:
	if _active_sensor_filter == "":
		return true
	return _get_signal_strength(obj_data) > 0.0


func _get_signal_strength(obj_data: Dictionary) -> float:
	if _active_sensor_filter == "":
		return 1.0
	var observability_profile: Dictionary = obj_data.get("observability_profile", {})
	if _active_sensor_filter == "velocity":
		var velocity_signal := float(observability_profile.get("velocity", -1.0))
		if velocity_signal < 0.0:
			velocity_signal = maxf(float(observability_profile.get("radio", 0.0)) * 0.65, float(observability_profile.get("gravity", 0.0)) * 0.55)
		return clampf(velocity_signal, 0.0, 1.0)
	if _active_sensor_filter == "acceleration":
		var acceleration_signal := float(observability_profile.get("acceleration", -1.0))
		if acceleration_signal < 0.0:
			acceleration_signal = maxf(float(observability_profile.get("gamma", 0.0)) * 0.55, float(observability_profile.get("gravity", 0.0)) * 0.75)
		return clampf(acceleration_signal, 0.0, 1.0)
	return clampf(float(observability_profile.get(_active_sensor_filter, 0.0)), 0.0, 1.0)


func _get_filter_tint() -> Color:
	if _active_sensor_filter == "":
		return Color(0.82, 0.88, 0.95, 1.0)
	return SENSOR_FILTER_COLORS.get(_active_sensor_filter, Color(0.82, 0.88, 0.95, 1.0))


func _to_vec2(value: Variant) -> Vector2:
	var arr: Array = value
	return Vector2(float(arr[0]), float(arr[1]))


func _regular_polygon(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
