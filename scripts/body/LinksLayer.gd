@tool
extends Node2D

## Draws connection lines between nodes using shader-backed Line2D instances.
## Solid lines between detected clusters; near-transparent lines toward undetected ends.

@export var clusters_root_path: NodePath = NodePath("../ClustersRoot")

const LINK_SHADER := preload("res://shaders/body_link.gdshader")
const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")
const WORKER_WORLD_MARKERS := preload("res://scripts/ui/WorkerWorldMarkers.gd")
const LINE_WIDTH: float = 6.0
const COLOR_DETECTED: Color = Color(0.55, 0.85, 1.0, 0.90)
const ONE_SIDE_UNDETECTED_ALPHA: float = 0.10
const WAVE_SEGMENTS: int = 12
const WAVE_AMPLITUDE: float = 2.8
const WAVE_FREQUENCY: float = 0.9
const WAVE_SPEED: float = 1.2

var _clusters_root: Node2D
var _link_lines: Dictionary = {}
var _link_markers: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	_clusters_root = get_node(clusters_root_path)
	_rebuild_lines()


func _process(delta: float) -> void:
	_time += delta
	if Engine.is_editor_hint():
		_rebuild_lines()
	_refresh_lines(delta)



func _rebuild_lines() -> void:
	for line in _link_lines.values():
		line.queue_free()
	for marker_root in _link_markers.values():
		marker_root.queue_free()
	_link_lines.clear()
	_link_markers.clear()
	for cluster in _get_all_clusters():
		var nc = cluster
		for linked in nc.get_linked_clusters():
			var key := _pair_key(str(nc.get_path()), str(linked.get_path()))
			if _link_lines.has(key):
				continue
			var line := _create_link_line()
			_link_lines[key] = line
			var marker_root := Node2D.new()
			marker_root.z_index = line.z_index + 1
			add_child(marker_root)
			_link_markers[key] = marker_root


func _refresh_lines(delta: float) -> void:
	if _link_lines.is_empty():
		_rebuild_lines()
	var refreshed_keys: Dictionary = {}
	for cluster in _get_all_clusters():
		var nc = cluster
		for linked in nc.get_linked_clusters():
			var key := _pair_key(str(nc.get_path()), str(linked.get_path()))
			if refreshed_keys.has(key):
				continue
			var line: Line2D = _link_lines.get(key)
			_apply_link_state(line, nc, linked, delta)
			refreshed_keys[key] = true


func _get_all_clusters() -> Array:
	var result: Array = []
	_collect_clusters_recursive(_clusters_root, result)
	return result


func _collect_clusters_recursive(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_method("get_linked_clusters"):
			result.append(child)
		_collect_clusters_recursive(child, result)


func _apply_link_state(line: Line2D, a, b, delta: float) -> void:
	var pos_a := to_local(a.global_position)
	var pos_b := to_local(b.global_position)

	if Engine.is_editor_hint():
		line.visible = true
		line.points = PackedVector2Array([pos_a, pos_b])
		var editor_mat := line.material as ShaderMaterial
		editor_mat.set_shader_parameter("line_color_a", COLOR_DETECTED)
		editor_mat.set_shader_parameter("line_color_b", COLOR_DETECTED)
		editor_mat.set_shader_parameter("visibility_alpha", 0.75)
		return

	line.points = _wavy_points(pos_a, pos_b)

	var target_color_a: Color = a.get_link_display_color()
	var target_color_b: Color = b.get_link_display_color()
	var detected_a := bool(a.call("is_detected"))
	var detected_b := bool(b.call("is_detected"))
	var capture_progress := GameState.get_capture_progress_for_link(str(a.get_path()), str(b.get_path()))
	if capture_progress > 0.0:
		var player_color := GameState.get_entity_color(GameState.ENTITY_PLAYER)
		target_color_a = target_color_a.lerp(player_color, capture_progress)
		target_color_b = target_color_b.lerp(player_color, capture_progress)

	var shader_material := line.material as ShaderMaterial
	var lerp_speed := clampf(delta * 10.0, 0.0, 1.0)
	var current_a_raw = shader_material.get_shader_parameter("line_color_a")
	var current_b_raw = shader_material.get_shader_parameter("line_color_b")
	var current_a: Color = target_color_a if current_a_raw == null else current_a_raw
	var current_b: Color = target_color_b if current_b_raw == null else current_b_raw
	if not detected_a:
		target_color_a.a = ONE_SIDE_UNDETECTED_ALPHA
	if not detected_b:
		target_color_b.a = ONE_SIDE_UNDETECTED_ALPHA
	shader_material.set_shader_parameter("line_color_a", current_a.lerp(target_color_a, lerp_speed))
	shader_material.set_shader_parameter("line_color_b", current_b.lerp(target_color_b, lerp_speed))

	var target_visible := 1.0 if (detected_a or detected_b) else 0.0
	var current_visible_raw = shader_material.get_shader_parameter("visibility_alpha")
	var current_visible: float = target_visible if current_visible_raw == null else float(current_visible_raw)
	var smooth_visible := lerpf(current_visible, target_visible, lerp_speed)
	shader_material.set_shader_parameter("visibility_alpha", smooth_visible)
	line.visible = smooth_visible > 0.01
	_refresh_capture_markers(
		str(a.get_path()),
		str(b.get_path()),
		pos_a,
		pos_b,
		_link_markers.get(_pair_key(str(a.get_path()), str(b.get_path())))
	)


func _wavy_points(pos_a: Vector2, pos_b: Vector2) -> PackedVector2Array:
	var dir := pos_b - pos_a
	if dir.length_squared() < 1.0:
		return PackedVector2Array([pos_a, pos_b])
	var perp := dir.normalized().rotated(PI * 0.5)
	var points := PackedVector2Array()
	for i in range(WAVE_SEGMENTS + 1):
		var t := float(i) / float(WAVE_SEGMENTS)
		var base := pos_a.lerp(pos_b, t)
		var wave: float = (
			sin(t * TAU * WAVE_FREQUENCY - _time * WAVE_SPEED) * WAVE_AMPLITUDE
			+ sin(t * TAU * WAVE_FREQUENCY * 1.7 - _time * WAVE_SPEED * 0.8) * WAVE_AMPLITUDE * 0.4
		)
		points.append(base + perp * wave)
	return points


func _create_link_line() -> Line2D:
	var line := Line2D.new()
	line.width = LINE_WIDTH
	line.width_curve = _create_width_curve()
	line.default_color = Color.WHITE
	line.antialiased = true
	line.z_index = 1
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var shader_material := ShaderMaterial.new()
	shader_material.shader = LINK_SHADER
	line.material = shader_material
	add_child(line)
	return line


func _create_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.38))
	curve.add_point(Vector2(0.18, 0.72))
	curve.add_point(Vector2(0.52, 1.0))
	curve.add_point(Vector2(0.82, 0.78))
	curve.add_point(Vector2(1.0, 0.46))
	return curve


func _pair_key(id_a: String, id_b: String) -> String:
	if id_a < id_b:
		return id_a + "|" + id_b
	return id_b + "|" + id_a


func _refresh_capture_markers(path_a: String, path_b: String, pos_a: Vector2, pos_b: Vector2, marker_root: Node2D) -> void:
	if marker_root == null:
		return
	var workers := GameState.get_capture_workers_for_link(path_a, path_b)
	var marker_types := WORKER_DISPLAY_UTILS.ordered_worker_types(workers)
	if marker_types.is_empty():
		WORKER_WORLD_MARKERS.clear_markers(marker_root)
		return
	var midpoint := pos_a.lerp(pos_b, 0.5)
	var dir := pos_b - pos_a
	var normal := Vector2.ZERO
	if dir.length_squared() > 0.001:
		normal = dir.normalized().orthogonal()
	var start := midpoint + normal * 22.0 - Vector2(float(marker_types.size() - 1) * 9.0, 0.0)
	WORKER_WORLD_MARKERS.populate_from_workers(
		marker_root,
		workers,
		start,
		Vector2(18.0, 0.0),
		0.58,
		WORKER_DISPLAY_UTILS.ICON_FILL_COLOR,
		8.0,
		18
	)
