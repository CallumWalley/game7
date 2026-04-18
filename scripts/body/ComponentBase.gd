@tool
extends "res://scripts/body/BodyObject.gd"

## Base class for all body-map components.
## Handles shader setup, worker activation, link interface, and hover/click plumbing.
## Subclasses override the virtual methods to define appearance and gameplay properties.

const NODE_FILL_SHADER := preload("res://shaders/node_fill.gdshader")

@export var required_power: float = 1.0
@export var non_preferred_multiplier: float = 0.3
## Per-instance polygon override. Non-empty replaces the type's default shape.
@export var polygon_verts: PackedVector2Array = PackedVector2Array():
	set(v):
		polygon_verts = v
		if is_node_ready():
			_setup_shape()

@onready var _polygon: Polygon2D = $Polygon
@onready var _outline: Line2D = $Outline
@onready var _hover_area: Area2D = $HoverArea
@onready var _collision: CollisionPolygon2D = $HoverArea/CollisionPolygon

var is_activated: bool = false
var controlling_entity: int = GameState.ENTITY_NONE

## Property accessor so external code can read component_type_id uniformly.
var component_type_id: String:
	get: return _get_component_type_id()

signal clicked(component, button_index: int)
signal activation_changed(active: bool)
signal hovered(component)
signal unhovered(component)


func _ready() -> void:
	_setup_shape()
	if Engine.is_editor_hint():
		return
	add_to_group("worker_components")
	_hover_area.input_event.connect(_on_input_event)
	_hover_area.mouse_entered.connect(func() -> void: hovered.emit(self))
	_hover_area.mouse_exited.connect(func() -> void: unhovered.emit(self))
	GameState.ensure_component_target(self)
	GameState.register_component_properties(_get_component_type_id(), _get_registered_properties())
	_update_visual_state()


func _setup_shape() -> void:
	if not polygon_verts.is_empty():
		_apply_verts(polygon_verts)
	elif _polygon.polygon.is_empty():
		var verts := _default_polygon_verts()
		if not verts.is_empty():
			_apply_verts(verts)
	_outline.default_color = Color(1.0, 1.0, 1.0, 0.95)
	_outline.width = 2.4
	_outline.antialiased = true
	_ensure_shader_material()


func _apply_verts(verts: PackedVector2Array) -> void:
	_polygon.polygon = verts
	var line_points := verts.duplicate()
	line_points.append(verts[0])
	_outline.points = line_points
	_collision.polygon = verts


func _ensure_shader_material() -> void:
	if _polygon.material is ShaderMaterial:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(get_path()) + name)
	var mat := ShaderMaterial.new()
	mat.shader = NODE_FILL_SHADER
	mat.set_shader_parameter("pattern_seed", rng.randf_range(0.0, 1000.0))
	_polygon.material = mat
	_polygon.color = Color.WHITE


func get_preferred_node_type() -> String:
	return _get_preferred_node_type()


func get_non_preferred_multiplier() -> float:
	return non_preferred_multiplier


func get_worker_target_id() -> String:
	if Engine.is_editor_hint():
		return ""
	return GameState.ensure_component_target(self)


func update_activation_from_workers() -> bool:
	var powered := GameState.get_target_total_power(get_worker_target_id()) >= required_power and is_connected_to_player_node()
	if powered != is_activated:
		is_activated = powered
		controlling_entity = GameState.ENTITY_PLAYER if powered else GameState.ENTITY_NONE
		if is_activated:
			GameState.report_component_controlled(self)
		activation_changed.emit(is_activated)
	_update_visual_state()
	return is_activated


func get_link_display_color() -> Color:
	if is_activated:
		return _activated_fill_primary()
	return _inactive_fill_primary()


func is_detected() -> bool:
	return is_connected_to_player_node()


func set_capture_pulse_intensity(_v: float) -> void:
	pass


func _update_visual_state() -> void:
	var mat := _polygon.material as ShaderMaterial
	if mat == null:
		return
	if is_activated:
		mat.set_shader_parameter("primary_color", _activated_fill_primary())
		mat.set_shader_parameter("secondary_color", _activated_fill_secondary())
	else:
		mat.set_shader_parameter("primary_color", _inactive_fill_primary())
		mat.set_shader_parameter("secondary_color", _inactive_fill_secondary())


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	clicked.emit(self, mbe.button_index)


## Virtual: unique string id for this component type.
func _get_component_type_id() -> String:
	return ""


## Virtual: preferred node type string for worker power bonuses.
func _get_preferred_node_type() -> String:
	return "neuron_cluster"


## Virtual: properties dict forwarded to GameState.register_component_properties.
func _get_registered_properties() -> Dictionary:
	return {"required_power": required_power}


## Virtual: default polygon vertices for brand-new instances.
func _default_polygon_verts() -> PackedVector2Array:
	return PackedVector2Array()


## Virtual: shader primary color when the component is activated.
func _activated_fill_primary() -> Color:
	return Color(0.4, 0.7, 0.4, 1.0)


## Virtual: shader secondary color when the component is activated.
func _activated_fill_secondary() -> Color:
	return Color(0.2, 0.5, 0.3, 1.0)


## Virtual: shader primary color when the component is inactive.
func _inactive_fill_primary() -> Color:
	return Color(0.15, 0.22, 0.16, 1.0)


## Virtual: shader secondary color when the component is inactive.
func _inactive_fill_secondary() -> Color:
	return Color(0.10, 0.14, 0.12, 1.0)
