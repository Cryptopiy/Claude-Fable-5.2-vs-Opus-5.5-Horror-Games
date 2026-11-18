shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;
// Метель, штрихи по ветру (snow_streaks.gd) — пелена позёмки: тонкий полупрозрачный слой несомого снега прямо над настом. Сетка едет
// за камерой, вершины лежат на рельефе наста (тот же snow_h, что у земли) чуть выше него.
// Струи длинные по ветру, змеятся поперёк, бегут по ветру; за фронтом порыва гуще.
// Видна только в настоящем свете; у камеры и к краю сетки гаснет; в постройках и на их полу её нет.

#include "res://src/shaders/snowfield.gdshaderinc"

uniform sampler2D n_lo : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float density = 0.1;
uniform float h_ofs = 0.08;           // над настом, м
uniform float relief_k = 1.0;
uniform vec2 patch_c = vec2(0.0);
uniform float patch_r = 17.0;
uniform float adv = 0.0;              // путь ветра по модулю 400 м
uniform float gust = 0.0;
uniform float front_s = -10000.0;
uniform float lit = 0.4;
uniform float fwd = 2.0;
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

varying vec3 wpos;
varying float fade;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 m = snow_mask(wpos.xz);
	float h = snow_h(wpos.xz, m) * relief_k + h_ofs;
	VERTEX.y += h;
	wpos.y += h;
	vec2 dd = abs(wpos.xz - patch_c);
	fade = (1.0 - smoothstep(patch_r * 0.55, patch_r * 0.95, max(dd.x, dd.y))) * (1.0 - m.g);
}

void fragment() {
	vec2 wdir = normalize(g_wind.xy + vec2(0.0001));
	vec2 pr = vec2(-wdir.y, wdir.x);
	float s = dot(wpos.xz, wdir);
	float r = dot(wpos.xz, pr);
	float sa = s - adv;
	// струи змеятся: поперечная координата сбита крупным шумом
	float wob = texture(n_lo, vec2(sa * (5.0 / 400.0), r * 0.021 + 0.3)).r - 0.5;
	float rw = r + wob * 4.0;
	float s1 = texture(n_hi, vec2(sa * (13.0 / 400.0), rw * 0.19)).r;
	float s2 = texture(n_hi, vec2(sa * (31.0 / 400.0) + 0.41, rw * 0.47 + 0.13)).r;
	float fil = smoothstep(0.5, 0.78, s1) * (0.45 + 0.55 * smoothstep(0.4, 0.72, s2));
	// крупные «языки» позёмки
	float tongue = smoothstep(0.36, 0.66, texture(n_lo, vec2(sa * (7.0 / 400.0) + 0.7, r * 0.045)).r);
	// за фронтом порыва — гуще; край фронта рваный, как у хлопьев и тумана (тот же шум, та же выборка)
	float rag = textureLod(n_lo, vec2(r * 0.023, 0.31), 0.0).r - 0.5;
	float behind = smoothstep(-1.5, 3.5, front_s + rag * 9.0 - s);
	float gk = 1.0 + 1.3 * gust * behind;
	// у камеры не мешает, под косым взглядом слой толще
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 tv = wpos - cam;
	float dist = length(tv);
	float graz = clamp(0.3 / max(abs(tv.y) / max(dist, 0.001), 0.12), 0.7, 2.2);
	float nk = smoothstep(0.6, 2.2, dist);
	// мягко у наста и стен
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float scene_d = -sv.z / sv.w;
	float soft = clamp((scene_d + VERTEX.z) / 0.3, 0.0, 1.0);
	float a = density * fil * (0.35 + 0.65 * tongue) * gk * graz * nk * soft * fade;
	for (int i = 0; i < box_n; i++) {
		vec3 b = step(box_min[i], wpos) * step(wpos, box_max[i]);
		a *= 1.0 - b.x * b.y * b.z;
	}
	ALBEDO = vec3(0.9, 0.93, 0.98);
	ALPHA = clamp(a, 0.0, 0.5);
}

void light() {
	float ph = 1.0 + fwd * pow(max(-dot(LIGHT, VIEW), 0.0), 6.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (lit * ph);
}
