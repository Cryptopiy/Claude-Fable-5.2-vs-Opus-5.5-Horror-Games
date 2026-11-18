shader_type spatial;
render_mode cull_back;
// Снежная земля: мировые UV (земля бесконечная), заструги и наметённые волны (snowfield.gdshaderinc),
// утоптанный наст вдоль лееров и у построек, позёмка вдоль ветра, искры наста.
// relief = 1 — ближний лоскут земли вокруг камеры: вершины поднимаются по высоте наста (к краю лоскута — в ноль);
// relief = 0 — дальняя плоскость: только освещение рельефа через нормали.

#include "res://src/shaders/snowfield.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.6;
uniform vec3 tint : source_color = vec3(0.9, 0.93, 1.0);
uniform float relief = 0.0;
uniform vec2 patch_c = vec2(0.0);   // центр ближнего лоскута
uniform float patch_r = 30.0;       // полуширина лоскута
uniform float quality = 1.0;        // 0 — дешёвый вариант: без нормалей рельефа
global uniform float g_gust;
varying vec3 wpos;
varying vec2 msk;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	msk = snow_mask(wpos.xz);
	if (relief > 0.5) {
		vec2 dd = abs(wpos.xz - patch_c);
		float edge = 1.0 - smoothstep(patch_r * 0.72, patch_r * 0.97, max(dd.x, dd.y));
		float h = snow_h(wpos.xz, msk) * edge;
		VERTEX.y += h;
		wpos.y += h;
	}
}

void fragment() {
	vec2 m = msk;
	vec2 uv = wpos.xz / tile;
	vec2 uv2 = uv * 0.37 + vec2(0.31, 0.17);
	float macro = texture(noise_tex, wpos.xz * 0.011).r;
	vec3 alb = mix(texture(albedo_tex, uv).rgb, texture(albedo_tex, uv2).rgb, 0.45);
	alb = mix(vec3(0.80, 0.83, 0.88), alb, 0.42);
	alb *= mix(0.84, 1.04, macro);
	// рельеф наста: нормаль по разности высот
	float h0 = snow_h(wpos.xz, m);
	vec3 nw = vec3(0.0, 1.0, 0.0);
	if (quality > 0.5) {
		float e = 0.09;
		float hx = snow_h(wpos.xz + vec2(e, 0.0), m);
		float hz = snow_h(wpos.xz + vec2(0.0, e), m);
		nw = normalize(vec3(h0 - hx, e * 0.4, h0 - hz));
	}
	// гребни застругов зализаны ветром — светлее и глаже; ложбины — в тени и рыхлые
	float crest = smoothstep(0.03, 0.24, h0);
	alb *= mix(0.8, 1.08, crest);
	// утоптанный наст у лееров: серее, плотнее, без застругов
	alb = mix(alb, alb * vec3(0.86, 0.88, 0.92), m.r * 0.8);
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	vec2 q = vec2(dot(wpos.xz, wd), dot(wpos.xz, vec2(-wd.y, wd.x)));
	float t = TIME * (4.5 + g_gust * 7.0);
	float s1 = texture(noise_tex, vec2((q.x - t) * 0.035, q.y * 0.31)).g;
	float s2 = texture(noise_tex, vec2((q.x - t * 1.7) * 0.052, q.y * 0.55 + 0.4)).g;
	float drift = smoothstep(0.50, 0.78, s1 * 0.6 + s2 * 0.5) * (0.25 + g_wind.z * 0.5 + g_gust * 0.5);
	ALBEDO = alb * tint * 0.9 + vec3(drift * 0.22);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 n = mix(texture(normal_tex, uv).rgb, texture(normal_tex, uv2).rgb, 0.45);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.3 * (1.0 - drift * 0.7) * mix(1.0, 0.55, m.r);
	float sp = texture(noise_tex, wpos.xz * 2.3).b * texture(noise_tex, wpos.zx * 3.1 + 0.37).b;
	float glint = smoothstep(0.62, 0.8, sp) * mix(0.6, 1.2, crest);
	ROUGHNESS = mix(0.9, 0.22, clamp(glint, 0.0, 1.0));
	SPECULAR = mix(0.2, 0.9, clamp(glint, 0.0, 1.0));
}
