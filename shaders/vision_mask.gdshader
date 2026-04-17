shader_type canvas_item;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float radius = 280.0;
uniform float feather = 300.0;
uniform float radius_secondary = 120.0;
uniform float feather_secondary = 180.0;
uniform float max_dark_alpha : hint_range(0.0, 1.0) = 0.92;
uniform int center_count = 0;
uniform int center_count_secondary = 0;
uniform vec2 center_0 = vec2(-100000.0, -100000.0);
uniform vec2 center_1 = vec2(-100000.0, -100000.0);
uniform vec2 center_2 = vec2(-100000.0, -100000.0);
uniform vec2 center_3 = vec2(-100000.0, -100000.0);
uniform vec2 center_4 = vec2(-100000.0, -100000.0);
uniform vec2 center_5 = vec2(-100000.0, -100000.0);
uniform vec2 center_6 = vec2(-100000.0, -100000.0);
uniform vec2 center_7 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_0 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_1 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_2 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_3 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_4 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_5 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_6 = vec2(-100000.0, -100000.0);
uniform vec2 center_secondary_7 = vec2(-100000.0, -100000.0);

float distance_to_nearest_center(vec2 p) {
	float d = 1e20;
	if (center_count > 0) d = min(d, distance(p, center_0));
	if (center_count > 1) d = min(d, distance(p, center_1));
	if (center_count > 2) d = min(d, distance(p, center_2));
	if (center_count > 3) d = min(d, distance(p, center_3));
	if (center_count > 4) d = min(d, distance(p, center_4));
	if (center_count > 5) d = min(d, distance(p, center_5));
	if (center_count > 6) d = min(d, distance(p, center_6));
	if (center_count > 7) d = min(d, distance(p, center_7));
	return d;
}

float distance_to_nearest_secondary_center(vec2 p) {
	float d = 1e20;
	if (center_count_secondary > 0) d = min(d, distance(p, center_secondary_0));
	if (center_count_secondary > 1) d = min(d, distance(p, center_secondary_1));
	if (center_count_secondary > 2) d = min(d, distance(p, center_secondary_2));
	if (center_count_secondary > 3) d = min(d, distance(p, center_secondary_3));
	if (center_count_secondary > 4) d = min(d, distance(p, center_secondary_4));
	if (center_count_secondary > 5) d = min(d, distance(p, center_secondary_5));
	if (center_count_secondary > 6) d = min(d, distance(p, center_secondary_6));
	if (center_count_secondary > 7) d = min(d, distance(p, center_secondary_7));
	return d;
}

void fragment() {
	vec2 p = UV * viewport_size;
	float nearest = distance_to_nearest_center(p);
	float nearest_secondary = distance_to_nearest_secondary_center(p);
	float visible_primary = 1.0 - smoothstep(radius, radius + max(feather, 1.0), nearest);
	float visible_secondary = 1.0 - smoothstep(radius_secondary, radius_secondary + max(feather_secondary, 1.0), nearest_secondary);
	float visible = max(visible_primary, visible_secondary);
	float alpha = (1.0 - visible) * max_dark_alpha;
	if (center_count <= 0 && center_count_secondary <= 0) {
		alpha = max_dark_alpha;
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
