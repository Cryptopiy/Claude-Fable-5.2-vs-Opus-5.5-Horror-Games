shader_type spatial;
render_mode cull_back;
// Парка Отзыва: грязная, мокрая, на плечах и капюшоне иней. Чем «неправильнее» (wrong), тем сильнее
// контур мелко «кипит» — вершины дрожат вдоль нормали рывками, как плохая плёнка.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.26, 0.18, 0.14);
uniform float meters = 0.6;
uniform float frost = 0.32;
uniform float wrong = 0.0;
uniform float frost_all = 0.0;      // иней по всей парке (замёрзший Громов)
global uniform vec4 g_wind;
global uniform float g_gust;
varying vec3 wn;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	float k = smoothstep(0.45, 1.0, wrong);
	if (k > 0.0) {
		float tb = floor(TIME * 14.0);
		float n = hash(floor(VERTEX * 9.0) + vec3(tb, tb * 0.37, 0.0)) - 0.5;
		VERTEX += NORMAL * n * 0.022 * k;
	}
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV / meters).rgb * tint;
	float top = smoothstep(0.55, 0.95, wn.y);
	vec3 from_wind = -normalize(vec3(g_wind.x, 0.0, g_wind.y) + vec3(0.0001));
	float face = smoothstep(0.2, 0.9, dot(wn, from_wind));
	float fr = clamp(top * 0.75 + face * 0.25, 0.0, 1.0) * frost * (0.6 + 0.4 * texture(albedo_tex, UV * 2.3).g);
	fr = max(fr, frost_all * (0.45 + 0.55 * texture(albedo_tex, UV * 1.7).g));
	ALBEDO = mix(c, vec3(0.62, 0.66, 0.72), fr);
	NORMAL_MAP = texture(normal_tex, UV / meters).rgb;
	ROUGHNESS = mix(0.95, 0.6, fr);
	SPECULAR = 0.25;
}
