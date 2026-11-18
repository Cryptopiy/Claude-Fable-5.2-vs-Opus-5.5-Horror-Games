shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled, fog_disabled;
// Метель: настоящие частицы у огней построек. Экранный слой (snow_screen) знает только налобный фонарь,
// а окна, лампы над дверями, бочки с огнём, маяк и фальшфейер посчитать дёшево не может — эти хлопья освещает
// настоящий свет через light(). Свет из точки у самой камеры (налобный фонарь и подсветка у лица) здесь пропускаем:
// его уже дал экранный слой, иначе снег в луче светился бы дважды. Рассеянного света нет — в темноте их не видно.
// Форма — мягкий кружок, чуть вытянутый по скорости; у камеры гаснут, вдали тонут в тумане, в помещениях не рисуются.

uniform float stretch = 2.4;        // длина квада / ширина
uniform float near_a = 0.35;
uniform float near_b = 1.4;
uniform float fog_begin = 1.0;
uniform float fog_end = 14.0;
uniform float fog_curve = 0.75;
uniform float bright = 0.3;
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];
global uniform float g_gust;
varying float fade;
varying float st;
varying float vdist;

void vertex() {
	float sk = 1.0 + g_gust * 0.5;
	VERTEX.y *= sk;
	st = stretch * sk;
	vec3 wc = MODEL_MATRIX[3].xyz;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vdist = length(vp);
	float d = -vp.z;
	fade = smoothstep(near_a, near_b, d) * COLOR.a * (1.0 - pow(smoothstep(fog_begin, fog_end, d), fog_curve));
	for (int i = 0; i < box_n; i++) {
		vec3 a = step(box_min[i], wc) * step(wc, box_max[i]);
		fade *= 1.0 - a.x * a.y * a.z;
	}
}

void fragment() {
	// капсула: круг поперёк, вытянутый вдоль скорости (UV.y); края мягкие, середина ярче
	float x = (UV.x - 0.5) * 2.0;
	float y = (0.5 - UV.y) * 2.0 * st;
	float r = length(vec2(x, max(abs(y) - (st - 1.0), 0.0)));
	float a = 1.0 - smoothstep(0.0, 1.0, r);
	a = a * a * (3.0 - 2.0 * a);
	a *= 1.0 - 0.5 * smoothstep(0.3, 1.0, abs(y) / st);
	ALBEDO = vec3(0.9, 0.93, 1.0);
	ALPHA = a * fade;
	ROUGHNESS = 1.0;
}

void light() {
	// источник почти там же, где камера (ближе 0,16 м): это фонарь на лбу — пропускаем
	float s = clamp(0.16 / max(vdist, 0.16), 0.0, 1.0);
	float thr = sqrt(1.0 - s * s) - 0.004;
	float head = LIGHT_IS_DIRECTIONAL ? 0.0 : step(thr, dot(LIGHT, VIEW));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (1.0 - head) * bright;
}
