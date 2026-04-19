extends Control

@export var ring_radius: float = 78.0
@export var ring_thickness: float = 3.0
@export var vector_extent: float = 46.0
@export var angular_radius: float = 92.0
@export var max_linear_acceleration: float = 320.0
@export var max_angular_velocity: float = 3.6
@export var trail_samples: int = 6
@export var base_color: Color = Color(0.98, 0.62, 0.24, 0.34)
@export var axis_color: Color = Color(1.0, 0.72, 0.34, 0.68)
@export var angular_positive_color: Color = Color(1.0, 0.78, 0.42, 0.96)
@export var angular_negative_color: Color = Color(1.0, 0.48, 0.26, 0.96)
@export var vector_color: Color = Color(1.0, 0.84, 0.5, 0.96)
@export var text_color: Color = Color(1.0, 0.88, 0.62, 0.92)

var _angular_velocity: float = 0.0
var _linear_acceleration: Vector2 = Vector2.ZERO
var _position: Vector2 = Vector2.ZERO
var _rotation: float = 0.0
var _acceleration_history: Array[Vector2] = []
var _angular_history: Array[float] = []


func set_motion_state(angular_velocity: float, linear_acceleration: Vector2, position: Vector2 = Vector2.ZERO, rotation: float = 0.0) -> void:
	_angular_velocity = angular_velocity
	_linear_acceleration = linear_acceleration
	_position = position
	_rotation = rotation
	_push_history_sample(angular_velocity, linear_acceleration)
	queue_redraw()


func _push_history_sample(angular_velocity: float, linear_acceleration: Vector2) -> void:
	_acceleration_history.push_front(linear_acceleration)
	_angular_history.push_front(angular_velocity)
	while _acceleration_history.size() > trail_samples:
		_acceleration_history.pop_back()
	while _angular_history.size() > trail_samples:
		_angular_history.pop_back()


func _draw() -> void:
	var center := size * 0.5
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var normalized_accel := _linear_acceleration / maxf(max_linear_acceleration, 0.001)
	normalized_accel.x = clampf(normalized_accel.x, -1.0, 1.0)
	normalized_accel.y = clampf(normalized_accel.y, -1.0, 1.0)
	var normalized_angular := clampf(_angular_velocity / maxf(max_angular_velocity, 0.001), -1.0, 1.0)

	draw_arc(center, ring_radius, 0.0, TAU, 72, base_color, ring_thickness, true)
	draw_line(center + Vector2(-vector_extent, 0.0), center + Vector2(vector_extent, 0.0), axis_color, 1.5, true)
	draw_line(center + Vector2(0.0, -vector_extent), center + Vector2(0.0, vector_extent), axis_color, 1.5, true)
	_draw_acceleration_trail(center)
	_draw_angular_trail(center)

	var accel_vector := Vector2(normalized_accel.x, normalized_accel.y) * vector_extent
	var accel_tip := center + accel_vector
	draw_line(center, accel_tip, vector_color, 3.0, true)
	draw_circle(accel_tip, 5.0, vector_color)

	var angular_color := angular_positive_color if normalized_angular >= 0.0 else angular_negative_color
	var angular_span := absf(normalized_angular) * PI * 1.4
	if angular_span > 0.02:
		var start_angle := -PI * 0.5
		var end_angle := start_angle + angular_span * signf(normalized_angular)
		draw_arc(center, angular_radius, start_angle, end_angle, 48, angular_color, 4.0, true)
		var arc_tip := center + Vector2.from_angle(end_angle) * angular_radius
		draw_circle(arc_tip, 4.0, angular_color)

	var label_gap := 16.0
	draw_string(font, center + Vector2(vector_extent + label_gap, 5.0), "x %+0.2f" % normalized_accel.x, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_string(font, center + Vector2(-30.0, -vector_extent - label_gap), "y %+0.2f" % -normalized_accel.y, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_string(font, center + Vector2(-34.0, angular_radius + label_gap + font_size), "rot %+0.2f" % normalized_angular, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, angular_color)

	var readout_x := center.x - angular_radius - label_gap
	var readout_top := center.y - angular_radius
	draw_string(font, Vector2(readout_x - 60.0, readout_top), "pos  %+6.1f  %+6.1f" % [_position.x, _position.y], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_string(font, Vector2(readout_x - 60.0, readout_top + font_size + 4.0), "hdg  %+.1f°" % rad_to_deg(_rotation), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_string(font, Vector2(readout_x - 60.0, readout_top + (font_size + 4.0) * 2.0), "acc  %+.1f m/s²" % _linear_acceleration.length(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)


func _draw_acceleration_trail(center: Vector2) -> void:
	for i in range(1, _acceleration_history.size()):
		var sample := _normalize_linear_acceleration(_acceleration_history[i])
		var alpha := (1.0 - float(i) / float(_acceleration_history.size())) * 0.45
		var sample_color := Color(vector_color.r, vector_color.g, vector_color.b, vector_color.a * alpha)
		var sample_vector := sample * vector_extent
		var sample_tip := center + sample_vector
		draw_line(center, sample_tip, sample_color, maxf(1.0, 3.0 - float(i) * 0.35), true)
		draw_circle(sample_tip, maxf(2.0, 5.0 - float(i) * 0.5), sample_color)


func _draw_angular_trail(center: Vector2) -> void:
	for i in range(1, _angular_history.size()):
		var normalized_angular := _normalize_angular_velocity(_angular_history[i])
		var angular_span := absf(normalized_angular) * PI * 1.4
		if angular_span <= 0.02:
			continue
		var base_color_for_dir := angular_positive_color if normalized_angular >= 0.0 else angular_negative_color
		var alpha := (1.0 - float(i) / float(_angular_history.size())) * 0.4
		var trail_color := Color(base_color_for_dir.r, base_color_for_dir.g, base_color_for_dir.b, base_color_for_dir.a * alpha)
		var start_angle := -PI * 0.5
		var end_angle := start_angle + angular_span * signf(normalized_angular)
		draw_arc(center, angular_radius, start_angle, end_angle, 48, trail_color, maxf(1.0, 4.0 - float(i) * 0.45), true)


func _normalize_linear_acceleration(value: Vector2) -> Vector2:
	var normalized := value / maxf(max_linear_acceleration, 0.001)
	normalized.x = clampf(normalized.x, -1.0, 1.0)
	normalized.y = clampf(normalized.y, -1.0, 1.0)
	return normalized


func _normalize_angular_velocity(value: float) -> float:
	return clampf(value / maxf(max_angular_velocity, 0.001), -1.0, 1.0)
