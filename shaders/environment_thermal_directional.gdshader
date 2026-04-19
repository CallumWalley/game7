shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform float edge_width : hint_range(0.05, 0.8) = 0.28;
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
	float edge_distance = max(abs(centered_uv.x), abs(centered_uv.y)) * 2.0;
	float edge_mask = smoothstep(1.0 - edge_width, 1.0, edge_distance);
	if (edge_mask <= 0.0 || intensity <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 edge_dir = normalize(centered_uv);
		float beam = 0.0;
		beam += directional_beam(edge_dir, source_0, direction_focus);
		beam += directional_beam(edge_dir, source_1, direction_focus);
		beam += directional_beam(edge_dir, source_2, direction_focus);
		beam += directional_beam(edge_dir, source_3, direction_focus);
		beam += directional_beam(edge_dir, source_4, direction_focus);
		beam += directional_beam(edge_dir, source_5, direction_focus);
		beam = 1.0 - exp(-beam * overlap_gain);

		float alpha = edge_mask * beam * intensity;
		COLOR = vec4(thermal_color.rgb, alpha * thermal_color.a);
	}
}
