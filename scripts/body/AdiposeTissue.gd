@tool
extends "res://scripts/body/ComponentBase.gd"

const GLUCOSE_SYSTEM := preload("res://scripts/body/systems/GlucoseSystem.gd")

## Dense metabolic glucose storage buffer. No workers required.
## Requires only to be owned (connected to player-controlled node).
## 
## Charge rate: glucose intake from food sources
## Discharge rate: glucose delivery to connected nodes (approx 2x charge)
##
## Grows/shrinks visually with glucose level.
## Links pulse and thicken in proportion to charge/discharge activity.

@export var max_glucose: float = 100.0
@export var charge_rate: float = 5.0
@export var discharge_rate: float = 10.0
@export var initial_glucose: float = 50.0
@export var scale_min: float = 0.88
@export var scale_max: float = 1.12

var _glucose: GlucoseSystem
var _color_tween: Tween

signal glucose_changed(amount: float)


func _ready() -> void:
	_glucose = GLUCOSE_SYSTEM.new(max_glucose, charge_rate, discharge_rate * 2.0)
	_glucose.set_glucose(initial_glucose)
	super()
	# Sync activation immediately so ADI does not render as inactive until first simulation tick.
	update_activation_from_workers()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_visual_from_glucose()


func _get_component_type_id() -> String:
	return "adipose_tissue"


func _get_preferred_node_type() -> String:
	return "neuron_cluster"


func _get_registered_properties() -> Dictionary:
	var props := super()
	props.erase("required_power")
	props["max_glucose"] = max_glucose
	props["charge_rate"] = charge_rate
	props["discharge_rate"] = discharge_rate
	props["initial_glucose"] = initial_glucose
	props["current_glucose"] = _glucose.current_glucose
	return props


func allows_worker_assignment() -> bool:
	return false


func get_current_glucose() -> float:
	return _glucose.current_glucose


func set_current_glucose(amount: float) -> void:
	var old := _glucose.current_glucose
	_glucose.set_glucose(amount)
	if _glucose.current_glucose != old:
		glucose_changed.emit(_glucose.current_glucose)


func get_max_glucose() -> float:
	return _glucose.max_glucose


func get_charge_rate() -> float:
	return _glucose.get_effective_charge_rate(is_activated)


func get_discharge_rate() -> float:
	return _glucose.get_effective_discharge_rate(is_activated)


func charge_glucose(requested: float) -> float:
	var amount := _glucose.charge(requested, is_activated)
	if amount > 0.0:
		glucose_changed.emit(_glucose.current_glucose)
	return amount


func discharge_glucose(requested: float) -> float:
	var amount := _glucose.discharge(requested, is_activated)
	if amount > 0.0:
		glucose_changed.emit(_glucose.current_glucose)
	return amount


func get_glucose_fill_ratio() -> float:
	return _glucose.get_fill_ratio()


func _update_visual_from_glucose() -> void:
	if _polygon == null:
		return
	var glucose_ratio := _glucose.get_fill_ratio()
	var target_scale := lerpf(scale_min, scale_max, glucose_ratio)
	_polygon.scale = Vector2.ONE * target_scale
	# Muted glucose indicator: subtle desaturation rather than bright color swings
	if glucose_ratio < 0.2:
		_polygon.modulate = Color(0.75, 0.55, 0.52, 1.0)
	elif glucose_ratio < 0.5:
		_polygon.modulate = Color(0.90, 0.85, 0.80, 1.0)
	else:
		_polygon.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _activated_fill_primary() -> Color:
	return Color(0.78, 0.60, 0.18, 1.0)


func _activated_fill_secondary() -> Color:
	return Color(0.58, 0.40, 0.08, 1.0)


func _inactive_fill_primary() -> Color:
	return Color(0.22, 0.20, 0.18, 1.0)


func _inactive_fill_secondary() -> Color:
	return Color(0.14, 0.13, 0.12, 1.0)


## Override: ADI activates from manual enabled state + connection, not worker power.
func update_activation_from_workers() -> bool:
	var active := is_enabled and is_connected_to_player_node()
	var was_active := is_activated
	if active != is_activated:
		is_activated = active
		controlling_entity = GameState.ENTITY_PLAYER if active else GameState.ENTITY_NONE
		if is_activated:
			ProgressionSystem.report_component_controlled(self)
		activation_changed.emit(is_activated)
		_animate_color_transition(was_active, is_activated)
	else:
		_update_visual_state()
	_update_visual_from_glucose()
	return is_activated


func _animate_color_transition(from_active: bool, to_active: bool) -> void:
	if _color_tween:
		_color_tween.kill()
	var mat := _polygon.material as ShaderMaterial
	if mat == null:
		return
	var from_primary := _activated_fill_primary() if from_active else _inactive_fill_primary()
	var from_secondary := _activated_fill_secondary() if from_active else _inactive_fill_secondary()
	var to_primary := _activated_fill_primary() if to_active else _inactive_fill_primary()
	var to_secondary := _activated_fill_secondary() if to_active else _inactive_fill_secondary()
	_color_tween = create_tween()
	_color_tween.set_trans(Tween.TRANS_SINE)
	_color_tween.set_ease(Tween.EASE_IN_OUT)
	_color_tween.tween_callback(func() -> void:
		mat.set_shader_parameter("primary_color", from_primary)
		mat.set_shader_parameter("secondary_color", from_secondary)
	)
	_color_tween.tween_method(
		func(t: float) -> void:
			mat.set_shader_parameter("primary_color", from_primary.lerp(to_primary, t))
			mat.set_shader_parameter("secondary_color", from_secondary.lerp(to_secondary, t)),
		0.0,
		1.0,
		0.7
	)


