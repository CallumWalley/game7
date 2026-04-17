@tool
extends "res://scripts/body/BodyObject.gd"

## Abstract base class for thought-processing nodes on the body map.
## Do not instantiate directly.

const POLYGON_VISUAL_CONTROLLER := preload("res://scripts/body/visual/PolygonVisualController.gd")
const NODE_FILL_SHADER := preload("res://shaders/node_fill.gdshader")

enum ControllingEntity {
	NONE,
	PLAYER,
}

## Ownership enum: NONE = unowned, PLAYER = player.
@export_enum("None", "Player") var controlling_entity: int = ControllingEntity.NONE

## Per-node innate tint used by renderers.
@export var node_tint: Color = Color(0.0, 0.0, 0.0, 0.0)

## Start nodes use the player color as their innate tint.
@export var startNode: bool = false

## Disabled nodes do not consume full resources.
@export var is_enabled: bool = true

## Conversion resistance used by capture tasks.
## If left at default, a seeded random value is generated at runtime.
@export var resistance: float = -1.0

## Human-facing concept label (adjectiveNoun), generated from the global word pool.
@export var concept_name: String = ""

@export var status: String = ""
@export var status_refresh_min_cycles: int = 14
@export var status_refresh_max_cycles: int = 32

@export_group("Visual Tuning")
@export_range(0.0, 1.0, 0.01) var neutral_activeness_scale: float = 0.42
@export_range(0.0, 1.0, 0.01) var neutral_energy_scale: float = 0.46
@export_range(0.0, 1.0, 0.01) var neutral_extra_wash: float = 0.24
@export_range(0.0, 1.0, 0.01) var neutral_innate_blend: float = 0.16
@export_range(0.0, 1.0, 0.01) var owned_innate_blend: float = 0.24

## pressure[entity_id: String] = pressure_amount: int
## When the total pressure from one entity reaches the threshold,
## control transfers to that entity. Ticks down each cycle.
var pressure: Dictionary = {}
var _last_status_refresh_cycle: int = -1000000
var _next_status_refresh_cycle: int = 0
var _status_rng := RandomNumberGenerator.new()
var _rng := RandomNumberGenerator.new()
var _runtime_generated: bool = false
var _is_hovered: bool = false
var _capture_pulse_intensity: float = 0.0
var _current_fill_primary: Color = Color.WHITE
var _current_fill_secondary: Color = Color.WHITE
var _target_fill_primary: Color = Color.WHITE
var _target_fill_secondary: Color = Color.WHITE
var _polygon_visual := POLYGON_VISUAL_CONTROLLER.new()

signal ownership_changed(old_entity: int, new_entity: int)
signal enabled_changed(enabled: bool)
signal status_changed(new_status: String)
signal hovered(node)
signal unhovered
signal clicked(node, button_index: int)

const UNCLAIMED_COLOR: Color = Color(0.94, 0.93, 0.90, 1.0)
const PLAYER_COLOR: Color = Color(0.35, 0.62, 1.0, 1.0)
const DISABLED_WASH_AMOUNT: float = 0.62
const VISUAL_LERP_SPEED: float = 7.5
const SCALE_MIN: float = 0.84
const SCALE_MAX: float = 1.18
const CAPTURE_PULSE_SCALE_MAX: float = 0.09
const OWNERSHIP_CONTRAST_NEUTRAL: float = 0.72
const OWNERSHIP_CONTRAST_PLAYER: float = 1.26
const SECONDARY_BLEND_SCALE: float = 0.42
const NEUTRAL_WASH_AMOUNT: float = 0.56
const GLUCOSE_COLOR_LOW: float = 0.58
const GLUCOSE_COLOR_HIGH: float = 1.32
const GLUCOSE_SAT_LOW: float = 0.58
const GLUCOSE_SAT_HIGH: float = 1.26
const DEFAULT_NODE_TINT: Color = Color(0.0, 0.0, 0.0, 0.0)

@onready var _polygon: Polygon2D = $ClusterPolygon
@onready var _outline: Polygon2D = $OutlinePolygon
@onready var _hover_area: Area2D = $HoverArea
@onready var _collision: CollisionPolygon2D = $HoverArea/CollisionPolygon


func _ready() -> void:
	if name != "":
		_rng.seed = name.hash()
	if Engine.is_editor_hint():
		_setup_polygon()
		_update_visuals()
		return
	_rng.seed = GameState.get_world_seeded_value(str(get_path()) + ":visual")
	_status_rng.seed = GameState.get_world_seeded_value(str(get_path()) + ":status")
	if resistance < 0.0:
		resistance = _status_rng.randf_range(0.5, 3.0)
	_hover_area.mouse_entered.connect(_on_hover_enter)
	_hover_area.mouse_exited.connect(_on_hover_exit)
	_hover_area.input_event.connect(_on_area_input_event)
	add_to_group("nerve_clusters")
	enabled_changed.connect(func(_e: bool) -> void: _update_visuals())
	ownership_changed.connect(func(_o: int, _n: int) -> void: _update_visuals())
	GameState.state_changed.connect(_on_state_changed)
	_update_visuals()


func _process(delta: float) -> void:
	if _polygon.polygon.is_empty():
		_setup_polygon()
	if Engine.is_editor_hint():
		_update_visuals()
	_animate_visuals(delta)


func _on_state_changed() -> void:
	_update_visuals()


## Override in subclasses to define the node's polygon shape.
func _build_shape_polygon() -> PackedVector2Array:
return PackedVector2Array()


func _setup_polygon() -> void:
var verts := _build_shape_polygon()
if verts.is_empty():
return
_polygon.polygon = verts
_outline.polygon = verts
_collision.polygon = verts
_polygon.color = Color.WHITE
var created := _polygon_visual.ensure_fill_material(_polygon, NODE_FILL_SHADER, _rng)
if created:
_current_fill_primary = UNCLAIMED_COLOR
_current_fill_secondary = PLAYER_COLOR
_target_fill_primary = _current_fill_primary
_target_fill_secondary = _current_fill_secondary
if node_tint == DEFAULT_NODE_TINT:
node_tint = _get_default_innate_tint()


func _update_visuals() -> void:
var visible_to_player := is_visible_to_player()
visible = visible_to_player
_hover_area.input_pickable = visible_to_player
if visible_to_player and not _runtime_generated:
_generate_runtime_state_on_first_visibility()
if not visible_to_player:
return
if _polygon.polygon.is_empty():
_setup_polygon()
var fill_colors := _compute_fill_colors()
_target_fill_primary = fill_colors[0]
_target_fill_secondary = fill_colors[1]
_polygon_visual.update_outline(_outline, _is_hovered)
match controlling_entity:
ControllingEntity.PLAYER:
z_index = 3
_:
z_index = 2


func _animate_visuals(delta: float) -> void:
if _polygon.polygon.is_empty():
return
var target_scale := _polygon_visual.compute_target_scale(
_get_visual_energy_factor(),
controlling_entity,
ControllingEntity.NONE,
SCALE_MIN,
SCALE_MAX,
neutral_activeness_scale,
_capture_pulse_intensity,
CAPTURE_PULSE_SCALE_MAX
)
scale = scale.lerp(Vector2.ONE * target_scale, clampf(delta * VISUAL_LERP_SPEED, 0.0, 1.0))
var color_lerp := clampf(delta * VISUAL_LERP_SPEED, 0.0, 1.0)
_current_fill_primary = _current_fill_primary.lerp(_target_fill_primary, color_lerp)
_current_fill_secondary = _current_fill_secondary.lerp(_target_fill_secondary, color_lerp)
_polygon_visual.set_fill_colors(_polygon, _current_fill_primary, _current_fill_secondary)


func _compute_fill_colors() -> Array[Color]:
return _polygon_visual.get_fill_colors({
"controlling_entity": controlling_entity,
"none_entity": ControllingEntity.NONE,
"player_entity": ControllingEntity.PLAYER,
"owner_none_color": UNCLAIMED_COLOR,
"owner_player_color": PLAYER_COLOR,
"node_tint": node_tint,
"start_node": startNode,
"neutral_wash_amount": NEUTRAL_WASH_AMOUNT,
"neutral_extra_wash": neutral_extra_wash,
"neutral_innate_blend": neutral_innate_blend,
"owned_innate_blend": owned_innate_blend,
"secondary_blend_scale": SECONDARY_BLEND_SCALE,
"is_enabled": is_enabled,
"is_in_coma": is_in_coma(),
"glucose_factor": _get_visual_energy_factor(),
"neutral_energy_scale": neutral_energy_scale,
"glucose_color_low": GLUCOSE_COLOR_LOW,
"glucose_color_high": GLUCOSE_COLOR_HIGH,
"glucose_sat_low": GLUCOSE_SAT_LOW,
"glucose_sat_high": GLUCOSE_SAT_HIGH,
"ownership_contrast_neutral": OWNERSHIP_CONTRAST_NEUTRAL,
"ownership_contrast_player": OWNERSHIP_CONTRAST_PLAYER,
"disabled_wash_amount": DISABLED_WASH_AMOUNT,
})


func _get_visual_energy_factor() -> float:
return 1.0 if is_enabled else 0.35


func _generate_random_tint() -> Color:
var hue := _rng.randf()
var saturation := _rng.randf_range(0.58, 0.95)
var value := _rng.randf_range(0.72, 1.0)
return Color.from_hsv(hue, saturation, value, 0.0)


func _get_default_innate_tint() -> Color:
if startNode:
return PLAYER_COLOR
return _generate_random_tint()


func _generate_runtime_state_on_first_visibility() -> void:
if _runtime_generated:
return
_runtime_generated = true
initialize_identity_if_needed()


func set_capture_pulse_intensity(value: float) -> void:
_capture_pulse_intensity = clampf(value, 0.0, 1.0)


func set_enabled(value: bool) -> void:
if is_enabled == value:
return
is_enabled = value
refresh_status(true)
enabled_changed.emit(value)
GameState.state_changed.emit()


func set_controlling_entity(entity: int) -> void:
if controlling_entity == entity:
return
var old := controlling_entity
controlling_entity = entity
refresh_status(true)
ownership_changed.emit(old, entity)
if entity == ControllingEntity.PLAYER:
GameState.report_node_controlled(self)
GameState.state_changed.emit()


func is_player_owned() -> bool:
return controlling_entity == ControllingEntity.PLAYER


func claim_by_player() -> void:
set_controlling_entity(ControllingEntity.PLAYER)


func initialize_identity_if_needed() -> void:
if not _can_generate_identity():
return
if concept_name.strip_edges() == "":
var generated_name := _generate_concept_name()
if generated_name.strip_edges() != "":
concept_name = generated_name
refresh_status(true)


## Re-evaluates status from high-level pools based on ownership.
## This can be extended later with additional condition layers.
func refresh_status(force: bool = false) -> void:
if Engine.is_editor_hint():
return
if not _can_generate_identity():
return
if not _can_refresh_status():
return
if not force and GameState.cycle < _next_status_refresh_cycle:
return
var parts: Array[String] = []
var base_status := _generate_base_status()
if base_status != "":
parts.append(base_status)
var overlays := _get_condition_overlay_statuses()
for tag in overlays:
if tag == "":
continue
if parts.has(tag):
continue
parts.append(tag)
var next_status := ", ".join(parts)
_last_status_refresh_cycle = GameState.cycle
_schedule_next_status_refresh()
_set_status(next_status)


func _schedule_next_status_refresh() -> void:
var min_cycles := maxi(status_refresh_min_cycles, 1)
var max_cycles := maxi(status_refresh_max_cycles, min_cycles)
_next_status_refresh_cycle = GameState.cycle + _status_rng.randi_range(min_cycles, max_cycles)


func _can_generate_identity() -> bool:
return _runtime_generated


func _generate_concept_name() -> String:
return GameState.get_or_assign_node_concept_name(_get_identity_key())


func _generate_base_status() -> String:
if controlling_entity == ControllingEntity.NONE:
GameState.clear_owned_emotion(_get_identity_key())
GameState.clear_inactive_owned_emotion(_get_identity_key())
return _generate_unowned_status()
return _generate_owned_status()


func _generate_unowned_status() -> String:
return GameState.get_random_unowned_status()


func _generate_owned_status() -> String:
return GameState.get_or_assign_owned_emotion(_get_identity_key())


func _can_refresh_status() -> bool:
return true


func _get_base_status_for_ownership() -> String:
return _generate_base_status()


func _get_condition_overlay_statuses() -> Array[String]:
var tags: Array[String] = []
if controlling_entity == ControllingEntity.PLAYER and not is_enabled:
tags.append(GameState.get_or_assign_inactive_owned_emotion(_get_identity_key()))
var data := _get_status_condition_data()
var glucose_value := int(data.get("glucose", -1))
if glucose_value < 0:
return tags
if glucose_value <= 30:
tags.append(GameState.get_random_very_hungry_status())
return tags
if glucose_value <= 60:
tags.append(GameState.get_random_hungry_status())
return tags


func _get_status_condition_data() -> Dictionary:
return {}


func _set_status(value: String) -> void:
var normalized := value.strip_edges().to_lower()
if status == normalized:
return
status = normalized
status_changed.emit(status)


func _get_status_pool_key() -> String:
return _get_identity_key()


func _get_identity_key() -> String:
if name.strip_edges() != "":
return name
if is_inside_tree():
return str(get_path())
return "node_%d" % get_instance_id()


func get_food_request_units() -> float:
return 0.0


func compute_glucose_delta(_request_units: float, _allocated_units: float) -> float:
return 0.0


func apply_food_result(_request_units: float, _allocated_units: float, _glucose_delta: float) -> void:
pass


func get_hidden_power() -> float:
return 1.0 if is_enabled else 0.0


func is_in_coma() -> bool:
return false


func can_player_enable() -> bool:
return true


func get_link_display_color() -> Color:
if not is_visible_to_player():
return Color(0.0, 0.0, 0.0, 0.0)
var fill_colors := _compute_fill_colors()
var representative := fill_colors[0].lerp(fill_colors[1], 0.32)
representative.a = 1.0
return representative


func is_detected() -> bool:
return controlling_entity == ControllingEntity.PLAYER or is_linked_to_player_owned()


## Resolves dragged inspector NodePaths into live node references.
func get_linked_nodes() -> Array:
return get_linked_body_objects()


func get_linked_clusters() -> Array:
return get_linked_nodes()


func is_visible_to_player() -> bool:
if Engine.is_editor_hint():
return true
return controlling_entity == ControllingEntity.PLAYER or is_linked_to_player_owned()


func is_linked_to_player_owned() -> bool:
for linked in get_linked_clusters():
if int(linked.get("controlling_entity")) == ControllingEntity.PLAYER:
return true
for cluster in _get_all_clusters_in_map():
if cluster == self:
continue
if int(cluster.get("controlling_entity")) != ControllingEntity.PLAYER:
continue
for linked in cluster.get_linked_clusters():
if linked == self:
return true
return false


func _get_all_clusters_in_map() -> Array:
var root := _find_clusters_root()
var result: Array = []
_collect_clusters_recursive(root, result)
return result


func _find_clusters_root() -> Node:
var cursor: Node = get_parent()
while cursor != null and cursor.name != "ClustersRoot":
cursor = cursor.get_parent()
return cursor


func _collect_clusters_recursive(node: Node, result: Array) -> void:
for child in node.get_children():
if child.has_method("get_linked_clusters"):
result.append(child)
_collect_clusters_recursive(child, result)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
if not event is InputEventMouseButton:
return
var mbe := event as InputEventMouseButton
if not mbe.pressed:
return
if not is_visible_to_player():
return
clicked.emit(self, mbe.button_index)


func _on_hover_enter() -> void:
_is_hovered = true
_update_visuals()
hovered.emit(self)


func _on_hover_exit() -> void:
_is_hovered = false
_update_visuals()
unhovered.emit()


func get_worker_node_type() -> String:
return GameState.NODE_TYPE_NEURON_CLUSTER


func get_mind_entry_data() -> Dictionary:
return {
"id": "node_type_neuron_cluster",
"title": "NeuronCluster",
"text": "Biological thought clusters. Flexible, adaptive, and baseline-efficient.",
}
