shader_type canvas_item;

uniform vec4 primary_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.35, 0.62, 1.0, 1.0);
uniform float pattern_seed = 0.0;
uniform float pattern_scale : hint_range(12.0, 60.0) = 26.0;
uniform float flow_speed : hint_range(0.0, 2.0) = 1.0;
uniform float marbling_strength : hint_range(0.0, 1.0) = 0.22;
uniform float ownership_pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float capture_flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ownership_pulse_color : source_color = vec4(0.56, 0.86, 1.0, 1.0);
uniform vec4 capture_flash_color : source_color = vec4(0.98, 0.76, 0.42, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos / max(pattern_scale, 0.001);
	float t = TIME * flow_speed;
	float field = 0.0;
	field += sin(p.x * 1.15 + pattern_seed * 0.021 + t * 0.22);
	field += sin(p.y * 1.33 - pattern_seed * 0.018 - t * 0.17);
	field += sin((p.x + p.y) * 0.82 + pattern_seed * 0.013 + t * 0.11);
	field += sin(length(p) * 1.9 - pattern_seed * 0.027 - t * 0.24) * 0.55;
	float mix_amount = smoothstep(-0.72, 0.72, field);
	float marbling = 0.5 + 0.5 * sin((p.x - p.y) * 1.7 + pattern_seed * 0.031);
	mix_amount = mix(mix_amount, marbling, marbling_strength);
	vec4 organic_color = mix(secondary_color, primary_color, mix_amount);

	float pulse_wave = 0.5 - 0.5 * cos(t * 3.8 + field * 1.2);
	float pulse_mix = ownership_pulse_strength * (0.35 + pulse_wave * 0.65);
	vec3 with_pulse = mix(organic_color.rgb, ownership_pulse_color.rgb, pulse_mix * 0.32);
	vec3 with_flash = mix(with_pulse, capture_flash_color.rgb, capture_flash_strength * 0.58);
	float glow = 1.0 + pulse_mix * 0.20 + capture_flash_strength * 0.24;
	COLOR = vec4(with_flash * glow, organic_color.a);
}