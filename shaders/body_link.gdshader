shader_type canvas_item;

uniform vec4 line_color_a : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 line_color_b : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float visibility_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 5.0) = 1.4;
uniform float capture_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 capture_color : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform float capture_glow_strength : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	// Smooth gradient from end A to end B along the line
	vec4 base_color = mix(line_color_a, line_color_b, UV.x);
	float progress_mix = smoothstep(capture_progress - 0.012, capture_progress + 0.006, UV.x);
	vec3 captured_rgb = mix(capture_color.rgb * 1.22, capture_color.rgb * 1.58, 1.0 - abs(UV.y - 0.5) * 2.0);
	base_color.rgb = mix(captured_rgb, base_color.rgb, progress_mix);

	// Soft falloff at the line edges
	float beam = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));

	// Two layered sine waves travelling in opposite directions for a wispy shimmer
	float shimmer = 0.83
		+ sin(UV.x * 10.0 - TIME * flow_speed) * 0.10
		+ sin(UV.x * 4.5  + TIME * flow_speed * 0.6) * 0.07;
	float length_alpha = 0.84
		+ sin(UV.x * 7.0 - TIME * flow_speed * 0.55) * 0.10
		+ sin(UV.x * 15.0 + TIME * flow_speed * 0.35) * 0.06;
	length_alpha = clamp(length_alpha, 0.55, 1.0);
	float pulse_wave = 0.5 - 0.5 * cos(TIME * 3.2 + UV.x * 6.0);
	float pulse = 1.0 + capture_glow_strength * (1.0 - progress_mix) * (0.06 + pulse_wave * 0.18);

	float alpha = visibility_alpha * beam * shimmer * length_alpha;
	COLOR = vec4(base_color.rgb * shimmer * pulse, base_color.a * alpha);
}
