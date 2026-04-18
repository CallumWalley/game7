@tool
extends Node2D

## Subtle ambient motion for non-interactive background props.

@export_range(0.0, 24.0, 0.1) var bob_amplitude: float = 6.0
@export_range(0.05, 2.0, 0.01) var bob_speed: float = 0.35
@export_range(0.0, 0.12, 0.001) var rotate_amplitude: float = 0.03
@export_range(0.0, 1.0, 0.01) var alpha_pulse_amplitude: float = 0.05
@export_range(0.05, 2.0, 0.01) var alpha_pulse_speed: float = 0.28
@export var phase_offset: float = 0.0
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if not is_node_ready():
			return
		set_process(_should_animate())
		if not _should_animate():
			position = _base_position
			rotation = _base_rotation
			modulate = _base_modulate

var _time: float = 0.0
var _base_position: Vector2
var _base_rotation: float = 0.0
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_base_modulate = modulate
	set_process(_should_animate())


func _process(delta: float) -> void:
	if not _should_animate():
		position = _base_position
		rotation = _base_rotation
		modulate = _base_modulate
		set_process(false)
		return
	_time += delta
	var bob_phase := phase_offset + _time * bob_speed
	var rot_phase := phase_offset * 0.61 + _time * bob_speed * 0.85
	var alpha_phase := phase_offset * 0.47 + _time * alpha_pulse_speed
	position = _base_position + Vector2(0.0, sin(bob_phase) * bob_amplitude)
	rotation = _base_rotation + sin(rot_phase) * rotate_amplitude
	var pulse := 1.0 + sin(alpha_phase) * alpha_pulse_amplitude
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, clampf(_base_modulate.a * pulse, 0.0, 1.0))


func _should_animate() -> bool:
	if Engine.is_editor_hint():
		return preview_in_editor
	return true
