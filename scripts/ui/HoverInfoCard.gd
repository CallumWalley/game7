extends PanelContainer
class_name HoverInfoCard

@onready var _title_label: Label = $Margin/VBox/Title
@onready var _details_label: Label = $Margin/VBox/Details


func set_content(title: String, details: String) -> void:
	_title_label.text = title
	_details_label.text = details


func show_with_content_at_mouse(
	overlay: Control,
	title: String,
	details: String,
	mouse_offset: Vector2 = Vector2(14, 14),
	padding: float = 6.0
) -> void:
	set_content(title, details)
	var pos := overlay.get_local_mouse_position() + mouse_offset
	show_at_overlay_pos(overlay, pos, padding)


func show_at_overlay_pos(overlay: Control, overlay_pos: Vector2, padding: float = 6.0) -> void:
	visible = true
	var max_x := overlay.size.x - size.x - padding
	var max_y := overlay.size.y - size.y - padding
	position = Vector2(
		clampf(overlay_pos.x, padding, max_x),
		clampf(overlay_pos.y, padding, max_y)
	)


func follow_mouse(overlay: Control, mouse_offset: Vector2 = Vector2(14, 14), padding: float = 6.0) -> void:
	if not visible:
		return
	var pos := overlay.get_local_mouse_position() + mouse_offset
	show_at_overlay_pos(overlay, pos, padding)


func hide_card() -> void:
	visible = false
