@tool
extends "res://scripts/body/ThoughtNode.gd"

## Shared base for geometrically-shaped thought nodes (square, triangle, etc.).
## Subclasses must override _build_shape_polygon() to define their visual shape.
## Do not instantiate directly.

@export var glucose: float = 100.0

signal hovered(node)
signal unhovered
signal clicked(node, button_index: int)
signal glucose_changed(new_value: int)

const UNCLAIMED_COLOR: Color = Color(0.94, 0.93, 0.90, 1.0)
const PLAYER_COLOR: Color = Color(0.35, 0.62, 1.0, 1.0)
const DISABLED_WASH_AMOUNT: float = 0.62
const VISUAL_LERP_SPEED: float = 7.5
const SCALE_MIN: float = 0.84
const SCALE_MAX: float = 1.18
const OWNERSHIP_CONTRAST_NEUTRAL: float = 0.72
const OWNERSHIP_CONTRAST_PLAYER: float = 1.26
const GLUCOSE_COLOR_LOW: float = 0.58
const GLUCOSE_COLOR_HIGH: float = 1.32
const GLUCOSE_SAT_LOW: float = 0.58
const GLUCOSE_SAT_HIGH: float = 1.26
const NODE_FILL_SHADER := preload("res://shaders/node_fill.gdshader")
const DEFAULT_GLUCOSE: float = 100.0
const DEFAULT_NODE_TINT: Color = Color(0.0, 0.0, 0.0, 0.0)

@onready var _polygon: Polygon2D = $ClusterPolygon
@onready var _outline: Polygon2D = $OutlinePolygon
@onready var _hover_area: Area2D = $HoverArea
@onready var _collision: CollisionPolygon2D = $HoverArea/CollisionPolygon

var _rng := RandomNumberGenerator.new()
var _runtime_generated: bool = false
var _is_hovered: bool = false
var _current_fill_primary: Color = Color.WHITE
var _current_fill_secondary: Color = Color.WHITE
var _target_fill_primary: Color = Color.WHITE
var _target_fill_secondary: Color = Color.WHITE


func _ready() -> void:
	if Engine.is_editor_hint():
		if name != "":
			_rng.seed = name.hash()
		_setup_polygon()
		_update_visuals()
		return
	_rng.seed = GameState.get_world_seeded_value(str(get_path()) + ":visual")
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
	_ensure_fill_material()
	if node_tint == DEFAULT_NODE_TINT:
		node_tint = _get_default_innate_tint()


func _on_state_changed() -> void:
	_update_visuals()


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


func _can_generate_identity() -> bool:
	return _runtime_generated


func _generate_runtime_state_on_first_visibility() -> void:
	if _runtime_generated:
		return
	_setup_polygon()
	if Engine.is_editor_hint() and glucose == DEFAULT_GLUCOSE:
		glucose = 40
	elif glucose == DEFAULT_GLUCOSE:
		glucose = GameState.sample_initial_node_glucose_percent()
	_runtime_generated = true
	initialize_identity_if_needed()
	glucose_changed.emit(int(round(glucose)))


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
	var fill_colors := _get_fill_colors()
	_target_fill_primary = fill_colors[0]
	_target_fill_secondary = fill_colors[1]
	_outline.visible = true
	var hover_boost := 0.32 if _is_hovered else 0.0
	_outline.modulate = Color(0.72 + hover_boost, 0.85 + hover_boost * 0.4, 0.96 + hover_boost * 0.2, 0.20 + hover_boost * 0.55)
	_outline.scale = Vector2.ONE * (1.01 + hover_boost * 0.08)
	match controlling_entity:
		ControllingEntity.PLAYER:
			z_index = 3
		_:
			z_index = 2


func _animate_visuals(delta: float) -> void:
	if _polygon.polygon.is_empty():
		return
	var fed_actual := _glucose_factor(glucose)
	var target_scale := lerpf(SCALE_MIN, SCALE_MAX, fed_actual)
	scale = scale.lerp(Vector2.ONE * target_scale, clampf(delta * VISUAL_LERP_SPEED, 0.0, 1.0))
	var color_lerp := clampf(delta * VISUAL_LERP_SPEED, 0.0, 1.0)
	_current_fill_primary = _current_fill_primary.lerp(_target_fill_primary, color_lerp)
	_current_fill_secondary = _current_fill_secondary.lerp(_target_fill_secondary, color_lerp)
	var shader_material := _polygon.material as ShaderMaterial
	shader_material.set_shader_parameter("primary_color", _current_fill_primary)
	shader_material.set_shader_parameter("secondary_color", _current_fill_secondary)


func _generate_random_tint() -> Color:
	var hue := _rng.randf()
	var saturation := _rng.randf_range(0.58, 0.95)
	var value := _rng.randf_range(0.72, 1.0)
	return Color.from_hsv(hue, saturation, value, 0.0)


func _get_default_innate_tint() -> Color:
	if startNode:
		return PLAYER_COLOR
	return _generate_random_tint()


func _ensure_fill_material() -> void:
	if _polygon.material is ShaderMaterial:
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = NODE_FILL_SHADER
	shader_material.set_shader_parameter("pattern_seed", _rng.randf_range(0.0, 1000.0))
	_polygon.material = shader_material
	_current_fill_primary = UNCLAIMED_COLOR
	_current_fill_secondary = PLAYER_COLOR
	_target_fill_primary = _current_fill_primary
	_target_fill_secondary = _current_fill_secondary


func _get_fill_colors() -> Array[Color]:
	var controller_color := _get_owner_base_color(controlling_entity)
	var innate_color := _get_innate_tint_color()
	var primary := controller_color.lerp(innate_color, 0.62)
	var secondary := controller_color.lerp(innate_color, 0.26)
	primary = _filter_fill_color(primary)
	secondary = _filter_fill_color(secondary)
	return [primary, secondary]


func _get_innate_tint_color() -> Color:
	var tint_color := PLAYER_COLOR if startNode else node_tint
	tint_color.a = 1.0
	tint_color.s = clampf(maxf(tint_color.s, 0.62), 0.0, 1.0)
	tint_color.v = clampf(maxf(tint_color.v, 0.78), 0.0, 1.0)
	return tint_color


func _filter_fill_color(color: Color) -> Color:
	var hue_glucose := glucose if is_enabled else 30.0
	var hue_factor := _glucose_factor(hue_glucose)
	var filtered := _apply_hue_energy(color, hue_factor)
	filtered = _apply_ownership_contrast(filtered)
	if not is_enabled or is_in_coma():
		filtered = _wash_out(filtered, DISABLED_WASH_AMOUNT)
	return filtered


func _get_owner_base_color(owner_id: int) -> Color:
	if owner_id == ControllingEntity.NONE:
		return UNCLAIMED_COLOR
	if Engine.is_editor_hint() and owner_id == ControllingEntity.PLAYER:
		return PLAYER_COLOR
	return GameState.get_entity_color(owner_id)


func _wash_out(color: Color, amount: float) -> Color:
	var a := clampf(amount, 0.0, 1.0)
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(
		lerpf(color.r, gray, a),
		lerpf(color.g, gray, a),
		lerpf(color.b, gray, a),
		color.a
	)


func _glucose_factor(value: float) -> float:
	return clampf(remap(clampf(value, GameState.coma_glucose_threshold, 100.0), GameState.coma_glucose_threshold, 100.0, 0.0, 1.0), 0.0, 1.0)


func _apply_hue_energy(color: Color, factor: float) -> Color:
	var gain := lerpf(GLUCOSE_COLOR_LOW, GLUCOSE_COLOR_HIGH, factor)
	var boosted := Color(
		clampf(color.r * gain, 0.0, 1.0),
		clampf(color.g * gain, 0.0, 1.0),
		clampf(color.b * gain, 0.0, 1.0),
		color.a
	)
	var sat_scale := lerpf(GLUCOSE_SAT_LOW, GLUCOSE_SAT_HIGH, factor)
	return _scale_saturation(boosted, sat_scale)


func _scale_saturation(color: Color, scale_factor: float) -> Color:
	var hsv := color
	hsv.s = clampf(hsv.s * scale_factor, 0.0, 1.0)
	hsv.a = color.a
	return hsv


func _apply_ownership_contrast(color: Color) -> Color:
	var gain := OWNERSHIP_CONTRAST_NEUTRAL
	if controlling_entity == ControllingEntity.PLAYER:
		gain = OWNERSHIP_CONTRAST_PLAYER
	return Color(
		clampf(color.r * gain, 0.0, 1.0),
		clampf(color.g * gain, 0.0, 1.0),
		clampf(color.b * gain, 0.0, 1.0),
		color.a
	)


func get_link_display_color() -> Color:
	if not is_visible_to_player():
		return Color(0.0, 0.0, 0.0, 0.0)
	var fill_colors := _get_fill_colors()
	var representative := fill_colors[0].lerp(fill_colors[1], 0.32)
	representative.a = 1.0
	return representative


func is_detected() -> bool:
	return controlling_entity == ControllingEntity.PLAYER or is_linked_to_player_owned()


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
