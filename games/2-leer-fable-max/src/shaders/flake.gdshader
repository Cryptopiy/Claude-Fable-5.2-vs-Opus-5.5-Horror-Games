shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;
// Снежинка пурги: мягкое круглое хлопье с коротким штрихом по скорости (квад вытянут по скорости частицы).
// Светится только в настоящем свете (фонарь, лампы), без учёта нормали. У самой камеры гаснет,
// внутри построек не рисуется (коробки зон), в порыв плотность идёт волнами по ветру.

uniform float bright = 1.0;
uniform float stretch = 2.2;        // длина квада / ширина: сколько «смазано» движением
uniform float near_a = 0.45;        // ближе этого — не видно (м)
uniform float near_b = 1.6;         // дальше этого — полная яркость
uniform float waves = 1.0;          // насколько слой подчиняется волнам порыва
uniform float gust_stretch = 0.6;   // в порыв хлопья летят быстрее — штрих длиннее (не больше чем в 1,6 раза: иначе снова «иглы»)
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];
global uniform vec4 g_wind;
global uniform float g_gust;
varying float fade;
varying float st;

void vertex() {
	float sk = 1.0 + g_gust * gust_stretch;
	VERTEX.y *= sk;
	st = stretch * sk;
	vec3 wc = MODEL_MATRIX[3].xyz;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = -vp.z;
	fade = smoothstep(near_a, near_b, d) * COLOR.a;
	// внутри построек снега нет
	for (int i = 0; i < box_n; i++) {
		vec3 a = step(box_min[i], wc) * step(wc, box_max[i]);
		fade *= 1.0 - a.x * a.y * a.z;
	}
	// порыв идёт волнами: полосы плотного снега бегут по ветру
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	vec2 pd = vec2(-wd.y, wd.x);
	float ph = dot(wc.xz, wd) * 0.42 - TIME * (6.0 + 5.0 * g_gust) + 2.2 * sin(dot(wc.xz, pd) * 0.11 + TIME * 0.27);
	float band = smoothstep(-0.35, 0.75, sin(ph));
	fade *= mix(1.0, 0.25 + band * 1.1, clamp(g_gust * waves, 0.0, 1.0));
}

void fragment() {
	// капсула: круг радиусом 1 поперёк, вытянутый вдоль оси скорости (UV.y)
	float x = (UV.x - 0.5) * 2.0;
	float y = (0.5 - UV.y) * 2.0 * st;   // +y — верх квада, по ходу движения
	float r = length(vec2(x, max(abs(y) - (st - 1.0), 0.0)));
	float a = smoothstep(1.0, 0.15, r);
	// голова хлопья (по ходу движения, +Y) ярче хвоста
	a *= mix(0.55, 1.0, clamp((y + st - 1.0) / max(2.0 * st - 2.0, 0.001), 0.0, 1.0));
	ALBEDO = vec3(0.9, 0.94, 1.0) * bright;
	ALPHA = a * fade;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.3;
}
