@tool
extends "res://scripts/body/GeometricNode.gd"

## Small biological compute cluster. Primary node type on the body map.
## Uses an irregular organic polygon plus wobble animation.

const VERTICES: int = 21
const BASE_RADIUS: float = 38.0
const JITTER: float = 10.0
const WOBBLE_MIN: float = 0.35
const WOBBLE_MAX: float = 2.7
const WOBBLE_FREQ_MIN: float = 1.3
const WOBBLE_FREQ_MAX: float = 3.4

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


func get_worker_node_type() -> String:
	return GameState.NODE_TYPE_NEURON_CLUSTER


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "node_type_neuron_cluster",
		"title": "NeuronCluster",
		"text": "Biological thought clusters. Flexible, adaptive, and baseline-efficient.",
	}
