shader_type canvas_item;

uniform vec4 primary_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.35, 0.62, 1.0, 1.0);
uniform float pattern_seed = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos / 26.0;
	float field = 0.0;
	field += sin(p.x * 1.15 + pattern_seed * 0.021 + TIME * 0.22);
	field += sin(p.y * 1.33 - pattern_seed * 0.018 - TIME * 0.17);
	field += sin((p.x + p.y) * 0.82 + pattern_seed * 0.013 + TIME * 0.11);
	field += sin(length(p) * 1.9 - pattern_seed * 0.027 - TIME * 0.24) * 0.55;
	float mix_amount = smoothstep(-0.72, 0.72, field);
	float marbling = 0.5 + 0.5 * sin((p.x - p.y) * 1.7 + pattern_seed * 0.031);
	mix_amount = mix(mix_amount, marbling, 0.22);
	vec4 organic_color = mix(secondary_color, primary_color, mix_amount);
	COLOR = organic_color;
}