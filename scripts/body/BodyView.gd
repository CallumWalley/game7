extends "res://scripts/common/MapViewBase.gd"

const WORKER_DISPLAY_UTILS := preload("res://scripts/ui/WorkerDisplayUtils.gd")

## Pan (middle-mouse drag, edge scroll) and zoom (scroll wheel) the body map.
## Hosts a SubViewport containing the 2D world and an overlay key panel.

@onready var _viewport_container: SubViewportContainer = $Frame/Inset/VBox/SubViewportContainer
@onready var _subviewport: SubViewport                 = $Frame/Inset/VBox/SubViewportContainer/SubViewport
@onready var _camera: Camera2D                         = $Frame/Inset/VBox/SubViewportContainer/SubViewport/Camera2D
@onready var _clusters_root: Node2D                   = $Frame/Inset/VBox/SubViewportContainer/SubViewport/WorldRoot/ClustersRoot
@onready var _overlay: Control                        = $Overlay
@onready var _hovered_card: HoverInfoCard = $Overlay/HoveredCard
@onready var _vision_mask: ColorRect = $Overlay/VisionMask

@export var debug_show_hover_stats: bool = true

var _hovered_cluster: Node = null
var _hovered_component: Node = null
var _suppress_status_popup_once: Dictionary = {}
var _known_cluster_statuses: Dictionary = {}
var _hover_card_hide_timer: float = -1.0
const HOVER_CARD_HIDE_DELAY: float = 0.18
const HOVER_CARD_MOUSE_OFFSET: Vector2 = Vector2(-220.0, 14.0)
const PAN_BOUNDS_PADDING: float = 420.0
const VISION_RADIUS_WORLD: float = 280.0
const VISION_FEATHER_WORLD: float = 300.0
const VISION_SECONDARY_RADIUS_WORLD: float = 120.0
const VISION_SECONDARY_FEATHER_WORLD: float = 180.0
const VISION_MAX_DARK_ALPHA: float = 0.92
const MAX_VISION_CENTERS: int = 8
const UI_BLOCKER_GRACE_PX: float = 52.0

const VISION_SHADER := preload("res://shaders/vision_mask.gdshader")


func _ready() -> void:
	var vision_material := ShaderMaterial.new()
	vision_material.shader = VISION_SHADER
	_vision_mask.material = vision_material
	for child in _get_all_clusters():
		_assign_concept_name_if_needed(child)
		if child.has_signal("hovered") and child.has_signal("unhovered"):
			child.hovered.connect(_on_cluster_hovered)
			child.unhovered.connect(_on_cluster_unhovered)
			if child.has_signal("clicked"):
				child.clicked.connect(_on_cluster_clicked)
			if child.has_signal("glucose_changed"):
				child.glucose_changed.connect(func(_v: int) -> void: _on_cluster_data_changed(child))
			if child.has_signal("status_changed"):
				child.status_changed.connect(func(v: String) -> void: _on_cluster_status_changed(child, v))
			if child.has_signal("ownership_changed"):
				child.ownership_changed.connect(func(_old_entity: int, _new_entity: int) -> void: _on_cluster_ownership_changed(child))
	for component in _get_all_components():
		if component.has_signal("clicked"):
			component.clicked.connect(_on_component_clicked)
		if component.has_signal("hovered"):
			component.hovered.connect(_on_component_hovered)
		if component.has_signal("unhovered"):
			component.unhovered.connect(_on_component_unhovered)
	_refresh_key()


func _on_map_process(delta: float) -> void:
	if _hovered_cluster == null and _hovered_component == null and _hover_card_hide_timer >= 0.0:
		_hover_card_hide_timer -= delta
		if _hover_card_hide_timer <= 0.0:
			_hide_card(_hovered_card)
			_hover_card_hide_timer = -1.0
	_update_cards_position()
	_update_vision_mask()


func _on_map_interaction_disabled() -> void:
	_hide_card(_hovered_card)


func _get_map_viewport_container() -> SubViewportContainer:
	return _viewport_container


func _get_map_subviewport() -> SubViewport:
	return _subviewport


func _get_map_camera() -> Camera2D:
	return _camera


func _is_edge_scroll_enabled() -> bool:
	return GameState.enable_push_scroll


func _on_cluster_hovered(cluster) -> void:
	_hovered_component = null
	_hovered_cluster = cluster
	_hover_card_hide_timer = -1.0
	_update_info()


func _on_cluster_unhovered() -> void:
	_hovered_cluster = null
	_hover_card_hide_timer = HOVER_CARD_HIDE_DELAY


func _on_component_hovered(component) -> void:
	_hovered_cluster = null
	_hovered_component = component
	_hover_card_hide_timer = -1.0
	_update_info()


func _on_component_unhovered(_component) -> void:
	_hovered_component = null
	_hover_card_hide_timer = HOVER_CARD_HIDE_DELAY


func _on_cluster_clicked(cluster, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT:
		if not bool(cluster.call("is_player_owned")):
			if not GameState.can_create_capture_task(cluster):
				return
			var target_id := GameState.ensure_capture_task_for_node(cluster)
			GameState.assign_worker_to_target(target_id)
			_update_info()
			return
		if not bool(cluster.get("is_enabled")) and bool(cluster.call("can_player_enable")):
			cluster.call("set_enabled", true)
		_refresh_key()
		_update_info()
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		if not bool(cluster.call("is_player_owned")):
			var target_id := GameState.get_capture_task_id_if_exists(cluster)
			if target_id != "":
				GameState.remove_worker_from_target(target_id)
			_update_info()
			return
		if bool(cluster.call("is_player_owned")) and bool(cluster.get("is_enabled")):
			cluster.call("set_enabled", false)
		_update_info()


func _on_component_clicked(component: Node, button_index: int) -> void:
	var target_id := GameState.ensure_component_target(component)
	if button_index == MOUSE_BUTTON_LEFT:
		if not GameState.can_assign_to_component(component):
			return
		GameState.assign_worker_to_target(target_id)
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		GameState.remove_worker_from_target(target_id)


func _update_info() -> void:
	if not is_instance_valid(_hovered_cluster) and not is_instance_valid(_hovered_component):
		if _hover_card_hide_timer < 0.0:
			_hide_card(_hovered_card)
		return
	_refresh_cards_content()


func _refresh_key() -> void:
	# Body-local key was removed; global key in Main is now authoritative.
	pass


func _get_all_clusters() -> Array:
	var result: Array = []
	_collect_clusters_recursive(_clusters_root, result)
	return result


func _collect_clusters_recursive(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_method("get_linked_clusters"):
			result.append(child)
		_collect_clusters_recursive(child, result)


func _get_all_components() -> Array:
	var result: Array = []
	_collect_components_recursive(_clusters_root, result)
	return result


func _collect_components_recursive(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_method("get_worker_target_id"):
			result.append(child)
		_collect_components_recursive(child, result)


func _set_card_content(card: HoverInfoCard, cluster: Node) -> void:
	if not is_instance_valid(cluster):
		_hide_card(card)
		return
	var emotion_txt := str(cluster.get("status")).strip_edges()
	if emotion_txt == "":
		emotion_txt = "unknown"
	var title := str(cluster.get("concept_name"))
	if title == "":
		title = str(cluster.name)
	var details := "%s" % emotion_txt
	if not bool(cluster.call("is_player_owned")):
		var task_id := GameState.get_capture_task_id_if_exists(cluster)
		if task_id != "":
			var workers := GameState.get_target_workers(task_id)
			details += "\nCapture: %d%%" % int(round(GameState.get_target_progress_ratio(task_id) * 100.0))
			details += "\nWorkers: %s" % WORKER_DISPLAY_UTILS.format_worker_mix(workers)
			details += "\nEff. power: %.2f" % GameState.get_target_total_power(task_id)
	if debug_show_hover_stats:
		var glucose_value := float(cluster.get("glucose"))
		var power_value := 0.0
		var resistance_value := float(cluster.get("resistance"))
		if cluster.has_method("get_hidden_power"):
			power_value = float(cluster.call("get_hidden_power"))
		details += "\nGlucose: %d\nPower: %.2f\nResistance: %.2f" % [int(round(glucose_value)), power_value, resistance_value]
	card.set_content(
		title,
		details
	)
	card.visible = true


func _set_component_card_content(card: HoverInfoCard, component: Node) -> void:
	if not is_instance_valid(component):
		_hide_card(card)
		return
	var title := str(component.get("component_label"))
	if title.strip_edges() == "":
		title = str(component.name)
	var target_id: String = str(component.call("get_worker_target_id"))
	var workers: Dictionary = GameState.get_target_workers(target_id)
	var current_power: float = GameState.get_target_total_power(target_id)
	var required_power := float(component.get("required_power"))
	var connected := bool(component.call("is_connected_to_player_node"))
	var details := "Workers: %s" % WORKER_DISPLAY_UTILS.format_worker_mix(workers)
	details += "\nPower: %.2f / %.2f" % [current_power, required_power]
	details += "\nConnected: %s" % ("yes" if connected else "no")
	details += "\nActive: %s" % ("yes" if bool(component.get("is_activated")) else "no")
	card.set_content(title, details)
	card.visible = true


func _assign_concept_name_if_needed(cluster: Node) -> void:
	if not is_instance_valid(cluster):
		return
	if str(cluster.get("concept_name")) != "":
		return
	var id := str(cluster.name)
	if id == "":
		return
	cluster.set("concept_name", GameState.get_or_assign_node_concept_name(id))


func _update_cards_position() -> void:
	if _hovered_card.visible:
		_hovered_card.follow_mouse(_overlay, HOVER_CARD_MOUSE_OFFSET, 6.0)


func _refresh_cards_content() -> void:
	if is_instance_valid(_hovered_cluster):
		_set_card_content(_hovered_card, _hovered_cluster)
	elif is_instance_valid(_hovered_component):
		_set_component_card_content(_hovered_card, _hovered_component)
	else:
		_hide_card(_hovered_card)


func _on_cluster_data_changed(cluster: Node) -> void:
	if cluster == _hovered_cluster:
		_update_info()


func _on_cluster_status_changed(cluster: Node, status_text: String) -> void:
	_on_cluster_data_changed(cluster)
	if not is_instance_valid(cluster):
		return
	if status_text.strip_edges() == "":
		return
	var key := cluster.get_instance_id()
	# Always advance the tracker so diffs stay accurate even when invisible
	var old_status: String = _known_cluster_statuses.get(key, "")
	_known_cluster_statuses[key] = status_text
	# One-shot suppression (e.g. triggered by ownership change)
	if _suppress_status_popup_once.get(key, false):
		_suppress_status_popup_once.erase(key)
		return
	# Suppress while not in player's vision
	if cluster.has_method("is_visible_to_player") and not bool(cluster.call("is_visible_to_player")):
		return
	# Suppress the very first status assignment (node just becoming known/visible)
	if old_status == "":
		return
	# Only pop up the parts that are genuinely new
	var old_parts := old_status.to_lower().split(", ", false)
	var new_parts := status_text.to_lower().split(", ", false)
	var added: Array[String] = []
	for part in new_parts:
		if not (part in old_parts):
			added.append(part)
	if added.is_empty():
		return
	_show_status_popup(cluster, ", ".join(added))


func _on_cluster_ownership_changed(cluster: Node) -> void:
	if not is_instance_valid(cluster):
		return
	_suppress_status_popup_once[cluster.get_instance_id()] = true


func _show_status_popup(cluster: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.96, 0.97, 1.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(label)

	var base_pos := _world_to_overlay(cluster.global_position)
	var jitter := Vector2(randf_range(-34.0, 34.0), randf_range(-28.0, 18.0))
	label.position = base_pos + jitter

	var drift := Vector2(randf_range(-12.0, 12.0), randf_range(-30.0, -16.0))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.24)
	tween.parallel().tween_property(label, "position", label.position + drift * 0.28, 0.24)
	tween.tween_interval(0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.48)
	tween.parallel().tween_property(label, "position", label.position + drift, 0.48)
	tween.finished.connect(label.queue_free)


func _world_to_overlay(world_pos: Vector2) -> Vector2:
	var vp_pos: Vector2 = _subviewport.get_canvas_transform() * world_pos
	var vp_size := Vector2(_subviewport.size)
	var container_size := _viewport_container.size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0 or container_size.x <= 0.0 or container_size.y <= 0.0:
		return _overlay.get_local_mouse_position()
	var container_local: Vector2 = vp_pos * container_size / vp_size
	var global_anchor: Vector2 = _viewport_container.get_global_rect().position + container_local
	return global_anchor - _overlay.global_position


func _update_vision_mask() -> void:
	var centers: Array[Vector2] = []
	var centers_secondary: Array[Vector2] = []
	for cluster in _get_all_clusters():
		var is_player_owned := bool(cluster.call("is_player_owned"))
		var cluster_is_visible := true
		if cluster.has_method("is_visible_to_player"):
			cluster_is_visible = bool(cluster.call("is_visible_to_player"))
		if is_player_owned:
			if centers.size() < MAX_VISION_CENTERS:
				centers.append(_world_to_overlay(cluster.global_position))
			continue
		if cluster_is_visible and centers_secondary.size() < MAX_VISION_CENTERS:
			centers_secondary.append(_world_to_overlay(cluster.global_position))

	var vision_material := _vision_mask.material as ShaderMaterial
	var origin_overlay := _world_to_overlay(_camera.global_position)
	var radius_overlay := _world_to_overlay(_camera.global_position + Vector2(VISION_RADIUS_WORLD, 0.0))
	var feather_overlay := _world_to_overlay(_camera.global_position + Vector2(VISION_RADIUS_WORLD + VISION_FEATHER_WORLD, 0.0))
	var secondary_radius_overlay := _world_to_overlay(_camera.global_position + Vector2(VISION_SECONDARY_RADIUS_WORLD, 0.0))
	var secondary_feather_overlay := _world_to_overlay(_camera.global_position + Vector2(VISION_SECONDARY_RADIUS_WORLD + VISION_SECONDARY_FEATHER_WORLD, 0.0))
	var radius_pixels := origin_overlay.distance_to(radius_overlay)
	var feather_pixels := maxf(feather_overlay.distance_to(origin_overlay) - radius_pixels, 1.0)
	var secondary_radius_pixels := origin_overlay.distance_to(secondary_radius_overlay)
	var secondary_feather_pixels := maxf(secondary_feather_overlay.distance_to(origin_overlay) - secondary_radius_pixels, 1.0)
	vision_material.set_shader_parameter("viewport_size", _overlay.size)
	vision_material.set_shader_parameter("radius", radius_pixels)
	vision_material.set_shader_parameter("feather", feather_pixels)
	vision_material.set_shader_parameter("radius_secondary", secondary_radius_pixels)
	vision_material.set_shader_parameter("feather_secondary", secondary_feather_pixels)
	vision_material.set_shader_parameter("max_dark_alpha", VISION_MAX_DARK_ALPHA)
	vision_material.set_shader_parameter("center_count", centers.size())
	vision_material.set_shader_parameter("center_count_secondary", centers_secondary.size())

	for i in MAX_VISION_CENTERS:
		var center := Vector2(-100000.0, -100000.0)
		var center_secondary := Vector2(-100000.0, -100000.0)
		if i < centers.size():
			center = centers[i]
		if i < centers_secondary.size():
			center_secondary = centers_secondary[i]
		vision_material.set_shader_parameter("center_%d" % i, center)
		vision_material.set_shader_parameter("center_secondary_%d" % i, center_secondary)


func _get_pan_bounds_rect() -> Rect2:
	var points: Array[Vector2] = []
	for cluster in _get_all_clusters():
		points.append(cluster.global_position)
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var pos := Vector2(min_x - PAN_BOUNDS_PADDING, min_y - PAN_BOUNDS_PADDING)
	var bounds_size := Vector2((max_x - min_x) + PAN_BOUNDS_PADDING * 2.0, (max_y - min_y) + PAN_BOUNDS_PADDING * 2.0)
	return Rect2(pos, bounds_size)


func _is_mouse_over_ui_blocker() -> bool:
	var mouse_global := get_global_mouse_position()
	if _expand_rect(_vision_mask.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	if _hovered_card.visible and _expand_rect(_hovered_card.get_global_rect(), UI_BLOCKER_GRACE_PX).has_point(mouse_global):
		return true
	return false


func _expand_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position - Vector2.ONE * amount, rect.size + Vector2.ONE * amount * 2.0)
