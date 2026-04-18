extends RefCounted

## Reusable helper for polygon-based node visuals.
## Keeps rendering math separate from gameplay state.


func ensure_fill_material(
	polygon: Polygon2D,
	shader: Shader,
	rng: RandomNumberGenerator
) -> bool:
	if polygon.material is ShaderMaterial:
		return false
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("pattern_seed", rng.randf_range(0.0, 1000.0))
	polygon.material = shader_material
	return true


func compute_target_scale(
	glucose_factor: float,
	controlling_entity: int,
	none_entity: int,
	scale_min: float,
	scale_max: float,
	neutral_activeness_scale: float,
	capture_pulse_intensity: float,
	capture_pulse_scale_max: float
) -> float:
	var effective_factor := glucose_factor
	if controlling_entity == none_entity:
		effective_factor *= neutral_activeness_scale
	var target_scale := lerpf(scale_min, scale_max, effective_factor)
	if capture_pulse_intensity > 0.0:
		target_scale *= 1.0 + capture_pulse_intensity * capture_pulse_scale_max
	return target_scale


func update_outline(outline: Polygon2D, is_hovered: bool) -> void:
	outline.visible = true
	var hover_boost := 0.32 if is_hovered else 0.0
	outline.modulate = Color(0.72 + hover_boost, 0.85 + hover_boost * 0.4, 0.96 + hover_boost * 0.2, 0.20 + hover_boost * 0.55)
	outline.scale = Vector2.ONE * (1.01 + hover_boost * 0.08)


func set_fill_colors(polygon: Polygon2D, primary: Color, secondary: Color) -> void:
	var shader_material := polygon.material as ShaderMaterial
	shader_material.set_shader_parameter("primary_color", primary)
	shader_material.set_shader_parameter("secondary_color", secondary)


func set_fill_effects(polygon: Polygon2D, ownership_pulse_strength: float, capture_flash_strength: float) -> void:
	var shader_material := polygon.material as ShaderMaterial
	shader_material.set_shader_parameter("ownership_pulse_strength", clampf(ownership_pulse_strength, 0.0, 1.0))
	shader_material.set_shader_parameter("capture_flash_strength", clampf(capture_flash_strength, 0.0, 1.0))


func get_fill_colors(data: Dictionary) -> Array[Color]:
	var controlling_entity: int = int(data.get("controlling_entity", 0))
	var none_entity: int = int(data.get("none_entity", 0))
	var owner_none_color: Color = data.get("owner_none_color", Color.WHITE)
	var owner_player_color: Color = data.get("owner_player_color", Color(0.35, 0.62, 1.0, 1.0))
	var owner_color: Color = data.get("owner_color", owner_player_color)
	var node_tint: Color = data.get("node_tint", Color(1, 1, 1, 1))
	var start_node: bool = bool(data.get("start_node", false))
	var neutral_wash_amount: float = float(data.get("neutral_wash_amount", 0.5))
	var neutral_extra_wash: float = float(data.get("neutral_extra_wash", 0.0))
	var neutral_innate_blend: float = float(data.get("neutral_innate_blend", 0.16))
	var owned_innate_blend: float = float(data.get("owned_innate_blend", 0.24))
	var secondary_blend_scale: float = float(data.get("secondary_blend_scale", 0.42))
	var is_enabled: bool = bool(data.get("is_enabled", true))
	var is_in_coma: bool = bool(data.get("is_in_coma", false))
	var glucose_factor: float = float(data.get("glucose_factor", 1.0))
	var neutral_energy_scale: float = float(data.get("neutral_energy_scale", 1.0))
	var glucose_color_low: float = float(data.get("glucose_color_low", 1.0))
	var glucose_color_high: float = float(data.get("glucose_color_high", 1.0))
	var glucose_sat_low: float = float(data.get("glucose_sat_low", 1.0))
	var glucose_sat_high: float = float(data.get("glucose_sat_high", 1.0))
	var ownership_contrast_neutral: float = float(data.get("ownership_contrast_neutral", 1.0))
	var ownership_contrast_player: float = float(data.get("ownership_contrast_player", 1.0))
	var player_entity: int = int(data.get("player_entity", 1))
	var disabled_wash_amount: float = float(data.get("disabled_wash_amount", 0.62))
	var personality_persistence_strength: float = float(data.get("personality_persistence_strength", 0.12))
	var personality_neutral_scale: float = float(data.get("personality_neutral_scale", 0.42))

	var owner_base_color := owner_color
	if controlling_entity == none_entity:
		owner_base_color = _wash_out(owner_none_color, neutral_wash_amount)

	var innate_tint := owner_player_color if start_node else node_tint
	innate_tint.a = 1.0
	innate_tint.s = clampf(maxf(innate_tint.s, 0.62), 0.0, 1.0)
	innate_tint.v = clampf(maxf(innate_tint.v, 0.78), 0.0, 1.0)

	var primary_blend := neutral_innate_blend if controlling_entity == none_entity else owned_innate_blend
	var secondary_blend := primary_blend * secondary_blend_scale
	var primary := owner_base_color.lerp(innate_tint, primary_blend)
	var secondary := owner_base_color.lerp(innate_tint, secondary_blend)

	primary = _filter_fill_color(
		primary,
		controlling_entity,
		none_entity,
		player_entity,
		glucose_factor,
		neutral_energy_scale,
		glucose_color_low,
		glucose_color_high,
		glucose_sat_low,
		glucose_sat_high,
		ownership_contrast_neutral,
		ownership_contrast_player,
		neutral_extra_wash,
		is_enabled,
		is_in_coma,
		disabled_wash_amount
	)
	secondary = _filter_fill_color(
		secondary,
		controlling_entity,
		none_entity,
		player_entity,
		glucose_factor,
		neutral_energy_scale,
		glucose_color_low,
		glucose_color_high,
		glucose_sat_low,
		glucose_sat_high,
		ownership_contrast_neutral,
		ownership_contrast_player,
		neutral_extra_wash,
		is_enabled,
		is_in_coma,
		disabled_wash_amount
	)

	var personality_strength := personality_persistence_strength
	if controlling_entity == none_entity:
		personality_strength *= personality_neutral_scale
	primary = _apply_personality_signature(primary, innate_tint, personality_strength)
	secondary = _apply_personality_signature(secondary, innate_tint, personality_strength * 0.85)
	return [primary, secondary]


func _filter_fill_color(
	color: Color,
	controlling_entity: int,
	none_entity: int,
	player_entity: int,
	glucose_factor: float,
	neutral_energy_scale: float,
	glucose_color_low: float,
	glucose_color_high: float,
	glucose_sat_low: float,
	glucose_sat_high: float,
	ownership_contrast_neutral: float,
	ownership_contrast_player: float,
	neutral_extra_wash: float,
	is_enabled: bool,
	is_in_coma: bool,
	disabled_wash_amount: float
) -> Color:
	var factor := glucose_factor
	if controlling_entity == none_entity:
		factor *= neutral_energy_scale
	var filtered := _apply_hue_energy(color, factor, glucose_color_low, glucose_color_high, glucose_sat_low, glucose_sat_high)
	filtered = _apply_ownership_contrast(filtered, controlling_entity, player_entity, ownership_contrast_neutral, ownership_contrast_player)
	if controlling_entity == none_entity:
		filtered = _wash_out(filtered, neutral_extra_wash)
	if not is_enabled or is_in_coma:
		filtered = _wash_out(filtered, disabled_wash_amount)
	return filtered


func _apply_hue_energy(
	color: Color,
	factor: float,
	glucose_color_low: float,
	glucose_color_high: float,
	glucose_sat_low: float,
	glucose_sat_high: float
) -> Color:
	var gain := lerpf(glucose_color_low, glucose_color_high, factor)
	var boosted := Color(
		clampf(color.r * gain, 0.0, 1.0),
		clampf(color.g * gain, 0.0, 1.0),
		clampf(color.b * gain, 0.0, 1.0),
		color.a
	)
	var sat_scale := lerpf(glucose_sat_low, glucose_sat_high, factor)
	return _scale_saturation(boosted, sat_scale)


func _scale_saturation(color: Color, scale_factor: float) -> Color:
	var hsv := color
	hsv.s = clampf(hsv.s * scale_factor, 0.0, 1.0)
	hsv.a = color.a
	return hsv


func _apply_ownership_contrast(
	color: Color,
	controlling_entity: int,
	player_entity: int,
	ownership_contrast_neutral: float,
	ownership_contrast_player: float
) -> Color:
	var gain := ownership_contrast_neutral
	if controlling_entity == player_entity:
		gain = ownership_contrast_player
	return Color(
		clampf(color.r * gain, 0.0, 1.0),
		clampf(color.g * gain, 0.0, 1.0),
		clampf(color.b * gain, 0.0, 1.0),
		color.a
	)


func _wash_out(color: Color, amount: float) -> Color:
	var a := clampf(amount, 0.0, 1.0)
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(
		lerpf(color.r, gray, a),
		lerpf(color.g, gray, a),
		lerpf(color.b, gray, a),
		color.a
	)


func _apply_personality_signature(base: Color, personality: Color, strength: float) -> Color:
	var s := clampf(strength, 0.0, 1.0)
	var signature := personality
	signature.a = base.a
	return base.lerp(signature, s)
