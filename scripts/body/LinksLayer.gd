@tool
extends Node2D

## Draws connection lines between nodes using shader-backed Line2D instances.
## Solid lines between detected clusters; near-transparent lines toward undetected ends.

@export var clusters_root_path: NodePath = NodePath("../ClustersRoot")
@export_group("Visual Tuning")
@export_range(0.0, 1.0, 0.01) var neutral_wash_strength: float = 0.78
@export_range(0.0, 3.0, 0.01) var capture_glow_intensity: float = 1.0
@export_range(0.0, 4.0, 0.05) var capture_width_per_worker: float = 1.25

const LINK_SHADER := preload("res://shaders/body_link.gdshader")
const LINE_WIDTH: float = 6.0
const LINE_CAPTURE_PULSE_AMPLITUDE: float = 1.2
const LINE_CAPTURE_PULSE_SPEED: float = 2.6
const COLOR_DETECTED: Color = Color(0.55, 0.85, 1.0, 0.90)
const ONE_SIDE_UNDETECTED_ALPHA: float = 0.10
const CAPTURE_OWNER_BLEND: float = 0.96
const CAPTURE_PROGRESS_COLOR: Color = Color(0.35, 0.72, 1.0, 1.0)
const WAVE_SEGMENTS: int = 12
const WAVE_AMPLITUDE: float = 2.8
const WAVE_FREQUENCY: float = 0.9
const WAVE_SPEED: float = 1.2

var _clusters_root: Node2D
var _link_lines: Dictionary = {}
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
	_link_lines.clear()
	for cluster in _get_all_clusters():
		var nc = cluster
		for linked in nc.get_linked_clusters():
			var key := _pair_key(str(nc.get_path()), str(linked.get_path()))
			if _link_lines.has(key):
				continue
			var line := _create_link_line()
			_link_lines[key] = line


func _refresh_lines(delta: float) -> void:
	if _link_lines.is_empty():
		_rebuild_lines()
	for cluster in _get_all_clusters():
		cluster.call("set_capture_pulse_intensity", 0.0)
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
	var node_a = a
	var node_b = b
	if int(node_a.get("controlling_entity")) != GameState.ENTITY_PLAYER and int(node_b.get("controlling_entity")) == GameState.ENTITY_PLAYER:
		node_a = b
		node_b = a
	var pos_a := to_local(node_a.global_position)
	var pos_b := to_local(node_b.global_position)

	if Engine.is_editor_hint():
		line.visible = true
		line.points = PackedVector2Array([pos_a, pos_b])
		var editor_mat := line.material as ShaderMaterial
		editor_mat.set_shader_parameter("line_color_a", COLOR_DETECTED)
		editor_mat.set_shader_parameter("line_color_b", COLOR_DETECTED)
		editor_mat.set_shader_parameter("visibility_alpha", 0.75)
		return

	line.points = _wavy_points(pos_a, pos_b)
	var path_a := str(node_a.get_path())
	var path_b := str(node_b.get_path())
	var visual := _compute_link_visual_state(node_a, node_b, path_a, path_b)
	var target_color_a: Color = visual.color_a
	var target_color_b: Color = visual.color_b
	var capture_progress: float = visual.capture_progress
	var capture_worker_count: int = visual.capture_worker_count
	var detected_a := bool(node_a.call("is_detected"))
	var detected_b := bool(node_b.call("is_detected"))

	var pulse := 0.0
	var pulse_cycle := _smooth_pulse(_time * LINE_CAPTURE_PULSE_SPEED)
	if capture_worker_count > 0:
		pulse = pulse_cycle * LINE_CAPTURE_PULSE_AMPLITUDE
		if int(node_a.get("controlling_entity")) == GameState.ENTITY_PLAYER and int(node_b.get("controlling_entity")) != GameState.ENTITY_PLAYER:
			node_a.call("set_capture_pulse_intensity", clampf(float(capture_worker_count) * (0.10 + pulse_cycle * 0.14), 0.0, 0.48))
	var width_target := LINE_WIDTH + float(capture_worker_count) * capture_width_per_worker + pulse
	line.width = lerpf(line.width, width_target, clampf(delta * 10.0, 0.0, 1.0))

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
	shader_material.set_shader_parameter("capture_progress", clampf(capture_progress, 0.0, 1.0))
	shader_material.set_shader_parameter("capture_color", CAPTURE_PROGRESS_COLOR)
	shader_material.set_shader_parameter(
		"capture_glow_strength",
		clampf((0.35 + 0.22 * float(capture_worker_count)) * capture_glow_intensity, 0.0, 2.0)
	)

	var target_visible := 1.0 if (detected_a or detected_b) else 0.0
	if capture_progress > 0.0:
		target_visible = 1.0
	var current_visible_raw = shader_material.get_shader_parameter("visibility_alpha")
	var current_visible: float = target_visible if current_visible_raw == null else float(current_visible_raw)
	var smooth_visible := lerpf(current_visible, target_visible, lerp_speed)
	shader_material.set_shader_parameter("visibility_alpha", smooth_visible)
	line.visible = smooth_visible > 0.01


func _smooth_pulse(phase: float) -> float:
	return 0.5 - 0.5 * cos(phase)


func _compute_link_visual_state(a, b, path_a: String, path_b: String) -> Dictionary:
	var color_a: Color = a.get_link_display_color()
	var color_b: Color = b.get_link_display_color()
	var wash_neutral := lerpf(0.58, 0.88, neutral_wash_strength)
	var wash_mixed := lerpf(0.36, 0.68, neutral_wash_strength)
	var alpha_neutral := lerpf(0.26, 0.08, neutral_wash_strength)
	var alpha_mixed := lerpf(0.38, 0.16, neutral_wash_strength)
	var owner_a := int(a.get("controlling_entity"))
	var owner_b := int(b.get("controlling_entity"))
	if owner_a == GameState.ENTITY_NONE and owner_b == GameState.ENTITY_NONE:
		color_a = _wash_color(color_a, wash_neutral)
		color_b = _wash_color(color_b, wash_neutral)
		color_a.a *= alpha_neutral
		color_b.a *= alpha_neutral
	elif owner_a == GameState.ENTITY_NONE or owner_b == GameState.ENTITY_NONE:
		color_a = _wash_color(color_a, wash_mixed)
		color_b = _wash_color(color_b, wash_mixed)
		color_a.a *= alpha_mixed
		color_b.a *= alpha_mixed

	var capture_progress := GameState.get_capture_progress_for_link(path_a, path_b)
	var capture_worker_count := _capture_worker_count(path_a, path_b)
	if capture_progress > 0.0:
		var player_color := GameState.get_entity_color(GameState.ENTITY_PLAYER)
		var blend := clampf(capture_progress * CAPTURE_OWNER_BLEND, 0.0, 1.0)
		color_a = color_a.lerp(player_color, blend)
		color_b = color_b.lerp(player_color, blend)

	return {
		"color_a": color_a,
		"color_b": color_b,
		"capture_progress": capture_progress,
		"capture_worker_count": capture_worker_count,
	}


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


func _capture_worker_count(path_a: String, path_b: String) -> int:
	var workers := GameState.get_capture_workers_for_link(path_a, path_b)
	var total := 0
	for v in workers.values():
		total += int(v)
	return total


func _wash_color(color: Color, amount: float) -> Color:
	var a := clampf(amount, 0.0, 1.0)
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(
		lerpf(color.r, gray, a),
		lerpf(color.g, gray, a),
		lerpf(color.b, gray, a),
		color.a
	)
