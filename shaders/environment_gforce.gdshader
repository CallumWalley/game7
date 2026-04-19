shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_time = 0.0;
uniform float pulse_depth : hint_range(0.0, 0.75) = 0.2;
uniform float edge_width : hint_range(0.05, 0.8) = 0.36;
uniform float pulse_softness : hint_range(0.01, 0.35) = 0.08;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float edge_distance = max(abs(centered_uv.x), abs(centered_uv.y)) * 2.0;
	float front = 1.0 - pulse_depth * (0.5 + 0.5 * sin(pulse_time));
	float pulse_band = smoothstep(front - pulse_softness, front + pulse_softness, edge_distance);
	float edge_mask = smoothstep(1.0 - edge_width, 1.0, edge_distance);
	float alpha = intensity * edge_mask * max(0.35, pulse_band);
	COLOR = vec4(edge_color.rgb, alpha * edge_color.a);
}
