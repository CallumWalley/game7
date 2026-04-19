shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float ring_radius : hint_range(0.9, 1.8) = 1.08;
uniform float min_ring_width : hint_range(0.01, 0.3) = 0.03;
uniform float max_ring_width : hint_range(0.05, 0.8) = 0.28;
uniform vec4 edge_color : source_color = vec4(1.0, 0.12, 0.12, 1.0);

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 radial_uv = vec2(centered_uv.x * aspect, centered_uv.y);
	float radial_distance = length(radial_uv) * 2.0;
	float ring_width = mix(min_ring_width, max_ring_width, intensity);
	float inner = max(ring_radius - ring_width * 0.5, 0.0);
	float outer = ring_radius + ring_width * 0.5;
	float ring_mask = smoothstep(inner, ring_radius, radial_distance) * (1.0 - smoothstep(ring_radius, outer, radial_distance));
	float alpha = intensity * ring_mask;
	COLOR = vec4(edge_color.rgb, alpha * edge_color.a);
}
