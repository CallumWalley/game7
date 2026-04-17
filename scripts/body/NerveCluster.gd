@tool
extends "res://scripts/body/ThoughtNode.gd"

## Small biological compute cluster. Primary node type on the body map.
## Uses an irregular organic polygon plus wobble animation.

@export var glucose: float = 100.0

signal glucose_changed(new_value: int)

const VERTICES: int = 21
const BASE_RADIUS: float = 38.0
const JITTER: float = 10.0
const WOBBLE_MIN: float = 0.35
const WOBBLE_MAX: float = 2.7
const WOBBLE_FREQ_MIN: float = 1.3
const WOBBLE_FREQ_MAX: float = 3.4
const DEFAULT_GLUCOSE: float = 100.0

var _base_polygon: PackedVector2Array = PackedVector2Array()
var _vertex_phases: Array[float] = []


func _build_shape_polygon() -> PackedVector2Array:
	var verts: PackedVector2Array = []
	for i: int in VERTICES:
		var angle := (TAU / VERTICES) * i
		var r := BASE_RADIUS + _rng.randf_range(-JITTER, JITTER)
		verts.append(Vector2(cos(angle), sin(angle)) * r)
	_base_polygon = verts
	_vertex_phases.clear()
	for _i in verts.size():
		_vertex_phases.append(_rng.randf_range(0.0, TAU))
	return verts


func _generate_runtime_state_on_first_visibility() -> void:
	if _runtime_generated:
		return
	if Engine.is_editor_hint() and glucose == DEFAULT_GLUCOSE:
		glucose = 40.0
	elif glucose == DEFAULT_GLUCOSE:
		glucose = GameState.sample_initial_node_glucose_percent()
	super._generate_runtime_state_on_first_visibility()
	glucose_changed.emit(int(round(glucose)))


func _animate_visuals(delta: float) -> void:
	super._animate_visuals(delta)
	if _base_polygon.is_empty():
		return
	var fed_actual := _glucose_factor(glucose)
	var wobble_factor := fed_actual
	if not is_enabled:
		wobble_factor *= 0.35
	var amplitude := lerpf(WOBBLE_MIN, WOBBLE_MAX, wobble_factor)
	var freq := lerpf(WOBBLE_FREQ_MIN, WOBBLE_FREQ_MAX, wobble_factor)
	var wobble_points := PackedVector2Array()
	for i in _base_polygon.size():
		var base: Vector2 = _base_polygon[i]
		var normal := base.normalized()
		var wobble := sin((Time.get_ticks_msec() * 0.001 * freq) + _vertex_phases[i]) * amplitude
		wobble_points.append(base + normal * wobble)
	_polygon.polygon = wobble_points
	_outline.polygon = wobble_points
	_collision.polygon = wobble_points


func get_food_request_units() -> float:
	var effective_glucose := glucose
	if not is_enabled and not is_in_coma():
		effective_glucose = GameState.manual_disabled_request_glucose_equivalent
	return remap(
clampf(effective_glucose, GameState.request_glucose_min, GameState.request_glucose_max),
GameState.request_glucose_min,
GameState.request_glucose_max,
GameState.food_request_min,
GameState.food_request_max
)


func compute_glucose_delta(request_units: float, allocated_units: float) -> float:
	if request_units <= 0.0:
		return GameState.baseline_delta_request_zero
	var allocation_ratio := clampf(allocated_units / request_units, 0.0, 1.0)
	var full_delta := _delta_if_fully_fed(request_units)
	return lerpf(GameState.baseline_delta_request_zero, full_delta, allocation_ratio)


func apply_food_result(_request_units: float, _allocated_units: float, glucose_delta: float) -> void:
	glucose = clampf(glucose + glucose_delta, 0.0, 100.0)
	refresh_status()
	glucose_changed.emit(int(round(glucose)))


func get_hidden_power() -> float:
	return remap(clampf(glucose, GameState.coma_glucose_threshold, GameState.power_full_glucose), GameState.coma_glucose_threshold, GameState.power_full_glucose, 0.0, 1.0)


func is_in_coma() -> bool:
	return glucose < GameState.coma_glucose_threshold


func can_player_enable() -> bool:
	return not is_in_coma()


func _delta_if_fully_fed(request_units: float) -> float:
	var req := maxf(request_units, 0.0)
	if req >= GameState.critical_request_units:
		return remap(req, GameState.critical_request_units, GameState.food_request_max, GameState.baseline_delta_at_critical_request, GameState.baseline_delta_at_full_request)
	return remap(req, 0.0, GameState.critical_request_units, GameState.baseline_delta_request_zero, GameState.baseline_delta_at_critical_request)


func _get_status_condition_data() -> Dictionary:
	return {"glucose": int(round(glucose))}


func _get_visual_energy_factor() -> float:
	var hue_glucose := glucose if is_enabled else 30.0
	return _glucose_factor(hue_glucose)


func _glucose_factor(value: float) -> float:
	return clampf(remap(clampf(value, GameState.coma_glucose_threshold, 100.0), GameState.coma_glucose_threshold, 100.0, 0.0, 1.0), 0.0, 1.0)


func get_worker_node_type() -> String:
	return GameState.NODE_TYPE_NEURON_CLUSTER


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "node_type_neuron_cluster",
		"title": "NeuronCluster",
		"text": "Biological thought clusters. Flexible, adaptive, and baseline-efficient.",
	}
