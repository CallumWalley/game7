shader_type canvas_item;

uniform float intensity : hint_range(0.0, 3) = 3;
uniform float ring_radius : hint_range(0.9, 1.8) = 2;
uniform float min_ring_width : hint_range(0.01, 0.4) = 0.14;
uniform float max_ring_width : hint_range(0.02, 0.7) = 0.34;
uniform float direction_focus : hint_range(1.0, 32.0) = 8.0;
uniform float direction_softness : hint_range(0.0, 1.0) = 0.34;
uniform float overlap_gain : hint_range(0.5, 4.0) = 1.8;
uniform vec4 thermal_color : source_color = vec4(1.0, 0.56, 0.18, 1.0);
uniform vec4 source_0 = vec4(0.0, -1.0, 0.0, 0.0);
uniform vec4 source_1 = vec4(0.0, -1.0, 0.0, 0.0);
uniform vec4 source_2 = vec4(0.0, -1.0, 0.0, 0.0);
uniform vec4 source_3 = vec4(0.0, -1.0, 0.0, 0.0);
uniform vec4 source_4 = vec4(0.0, -1.0, 0.0, 0.0);
uniform vec4 source_5 = vec4(0.0, -1.0, 0.0, 0.0);

float directional_beam(vec2 edge_dir, vec4 source_data, float focus) {
	vec2 source_dir = normalize(source_data.xy);
	float alignment = max(dot(edge_dir, source_dir), 0.0);
	float broad_alignment = mix(alignment, smoothstep(0.0, 1.0, alignment), direction_softness);
	return pow(broad_alignment, focus) * source_data.z;
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 radial_uv = vec2(centered_uv.x * aspect, centered_uv.y);
	float radial_distance = length(radial_uv) * 2.0;
	float ring_width = mix(min_ring_width, max_ring_width, clamp(intensity, 0.0, 1.0));
	float inner = max(ring_radius - ring_width * 0.5, 0.0);
	float outer = ring_radius + ring_width * 0.5;
	float ring_mask = smoothstep(inner, ring_radius, radial_distance) * (1.0 - smoothstep(ring_radius, outer, radial_distance));
	if (ring_mask <= 0.0 || intensity <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 edge_dir = normalize(radial_uv);
		float beam = 0.0;
		beam += directional_beam(edge_dir, source_0, direction_focus);
		beam += directional_beam(edge_dir, source_1, direction_focus);
		beam += directional_beam(edge_dir, source_2, direction_focus);
		beam += directional_beam(edge_dir, source_3, direction_focus);
		beam += directional_beam(edge_dir, source_4, direction_focus);
		beam += directional_beam(edge_dir, source_5, direction_focus);
		beam = 1.0 - exp(-beam * overlap_gain);

		float alpha = ring_mask * beam * intensity;
		COLOR = vec4(thermal_color.rgb, alpha * thermal_color.a);
	}
}
