extends Control
class_name MapViewBase

## Shared SubViewport map controls: middle-mouse drag, scroll-wheel zoom, edge scroll.

const ZOOM_STEP: float = 0.12
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 4.0
const PAN_SPEED: float = 450.0
const DEFAULT_EDGE_MARGIN: float = 120.0

var _dragging: bool = false
var _drag_start_mouse: Vector2
var _drag_start_cam: Vector2


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		var map_rect := _get_map_viewport_container().get_global_rect()
		if not map_rect.has_point(mbe.global_position):
			return
		match mbe.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = mbe.pressed
				if mbe.pressed:
					_drag_start_mouse = mbe.global_position
					_drag_start_cam   = _get_map_camera().position
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if mbe.pressed:
					_do_zoom(ZOOM_STEP, mbe.global_position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mbe.pressed:
					_do_zoom(-ZOOM_STEP, mbe.global_position)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var cam := _get_map_camera()
		cam.position = _drag_start_cam - (motion.global_position - _drag_start_mouse) / cam.zoom.x
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		_dragging = false
		_on_map_interaction_disabled()
		return
	_on_map_process(delta)
	if not _dragging and _is_edge_scroll_enabled() and not _is_mouse_over_ui_blocker():
		_edge_scroll(delta)


func _edge_scroll(delta: float) -> void:
	var rect := _get_map_viewport_container().get_global_rect()
	var mouse := get_global_mouse_position()
	if not rect.has_point(mouse):
		return
	var local := mouse - rect.position
	var em    := _get_edge_margin()
	var dir   := Vector2.ZERO
	if local.x > 0.0 and local.x < em:
		dir.x = -(1.0 - local.x / em)
	elif local.x > rect.size.x - em and local.x < rect.size.x:
		dir.x = (local.x - (rect.size.x - em)) / em
	if local.y > 0.0 and local.y < em:
		dir.y = -(1.0 - local.y / em)
	elif local.y > rect.size.y - em and local.y < rect.size.y:
		dir.y = (local.y - (rect.size.y - em)) / em
	if dir == Vector2.ZERO:
		return
	var cam := _get_map_camera()
	cam.position += dir.normalized() * PAN_SPEED * delta / cam.zoom.x


func _do_zoom(step: float, mouse_global: Vector2) -> void:
	var cam   := _get_map_camera()
	var old_z := cam.zoom.x
	var new_z := clampf(old_z * (1.0 + step), ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_z, new_z):
		return
	# Zoom toward the mouse position so the point under the cursor stays fixed.
	var rect      := _get_map_viewport_container().get_global_rect()
	var vp_size   := Vector2(_get_map_subviewport().size)
	var mouse_vp  := (mouse_global - rect.position) * vp_size / rect.size
	var vp_half   := vp_size * 0.5
	cam.position  += (mouse_vp - vp_half) * (1.0 / old_z - 1.0 / new_z)
	cam.zoom = Vector2(new_z, new_z)


func _is_mouse_over_map() -> bool:
	return _get_map_viewport_container().get_global_rect().has_point(get_global_mouse_position())


func _hide_card(card: HoverInfoCard) -> void:
	card.hide_card()


func _show_card_at_mouse(card: HoverInfoCard, overlay: Control, title: String, body: String, offset := Vector2(14, 14), padding := 6.0) -> void:
	card.show_with_content_at_mouse(overlay, title, body, offset, padding)


# -- Override in subclasses --

func _on_map_process(_delta: float) -> void:
	pass


func _on_map_interaction_disabled() -> void:
	pass


func _get_map_viewport_container() -> SubViewportContainer:
	return null


func _get_map_subviewport() -> SubViewport:
	return null


func _get_map_camera() -> Camera2D:
	return null


func _get_edge_margin() -> float:
	return DEFAULT_EDGE_MARGIN


func _is_edge_scroll_enabled() -> bool:
	return true


func _is_mouse_over_ui_blocker() -> bool:
	return false