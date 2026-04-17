shader_type canvas_item;

uniform vec4 line_color_a : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 line_color_b : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float visibility_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 5.0) = 1.4;

void fragment() {
	// Smooth gradient from end A to end B along the line
	vec4 base_color = mix(line_color_a, line_color_b, UV.x);

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

	float alpha = visibility_alpha * beam * shimmer * length_alpha;
	COLOR = vec4(base_color.rgb * shimmer, base_color.a * alpha);
}
