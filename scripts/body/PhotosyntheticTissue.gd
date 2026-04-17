@tool
extends "res://scripts/body/BodyObject.gd"

const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")
const WORKER_WORLD_MARKERS := preload("res://scripts/ui/WorkerWorldMarkers.gd")

## Placeholder component: produces food when sufficiently powered by assigned workers.

@export var preferred_node_type: String = "neuron_cluster"
@export var non_preferred_multiplier: float = 0.3
@export var required_power: float = 1.0
@export var food_output_per_cycle: float = 1.0
@export var component_label: String = "Photosynthetic Tissue"

@onready var _polygon: Polygon2D = $Polygon
@onready var _outline: Line2D = $Outline
@onready var _hover_area: Area2D = $HoverArea
@onready var _collision: CollisionPolygon2D = $HoverArea/CollisionPolygon
@onready var _marker_root: Node2D = $WorkerMarkers

var is_activated: bool = false

signal clicked(component, button_index: int)
signal activation_changed(active: bool)


func _ready() -> void:
	_setup_shape()
	add_to_group("worker_components")
	_hover_area.input_event.connect(_on_input_event)
	GameState.ensure_component_target(self)
	GameState.state_changed.connect(_refresh_worker_markers)
	_update_visual_state()
	_refresh_worker_markers()


func _setup_shape() -> void:
	if _polygon.polygon.is_empty():
		var verts := PackedVector2Array([
			Vector2(-76.0, -48.0),
			Vector2(68.0, -54.0),
			Vector2(84.0, 34.0),
			Vector2(-60.0, 58.0),
		])
		_polygon.polygon = verts
		var line_points := verts.duplicate()
		line_points.append(verts[0])
		_outline.points = line_points
		_collision.polygon = verts
	_outline.default_color = Color(1.0, 1.0, 1.0, 0.95)
	_outline.width = 2.4
	_outline.antialiased = true


func get_preferred_node_type() -> String:
	return preferred_node_type


func get_non_preferred_multiplier() -> float:
	return non_preferred_multiplier


func get_food_output_per_cycle() -> float:
	return food_output_per_cycle


func get_worker_target_id() -> String:
	return GameState.ensure_component_target(self)


func update_activation_from_workers() -> bool:
	var powered := GameState.get_target_total_power(get_worker_target_id()) >= required_power and is_connected_to_player_node()
	if powered != is_activated:
		is_activated = powered
		if is_activated:
			GameState.report_component_controlled(self)
		activation_changed.emit(is_activated)
	_update_visual_state()
	return is_activated


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "component_photosynthetic_tissue",
		"title": "Photosynthetic Tissue",
		"text": "A metabolically active tissue layer that converts ambient radiation into food reserves.",
	}


func _update_visual_state() -> void:
	if is_activated:
		_polygon.color = Color(0.26, 0.55, 0.28, 0.58)
	else:
		_polygon.color = Color(0.12, 0.17, 0.13, 0.42)


func _refresh_worker_markers() -> void:
	var workers := GameState.get_target_workers(get_worker_target_id())
	WORKER_WORLD_MARKERS.populate_from_workers(
		_marker_root,
		workers,
		Vector2(96.0, -38.0),
		Vector2(18.0, 0.0),
		0.62,
		Color(0.96, 0.96, 0.96, 0.95),
		7.0,
		18
	)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	clicked.emit(self, mbe.button_index)
