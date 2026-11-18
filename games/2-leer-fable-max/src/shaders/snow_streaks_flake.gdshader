shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled, fog_disabled, world_vertex_coords;
// Метель, штрихи по ветру (snow_streaks.gd) — хлопья. Каждое хлопье рисуется так, как его сняла бы кинокамера:
//  • смаз за выдержку — отрезок вдоль скорости относительно камеры; виден только поперечный лучу зрения
//    кусок (летящие на камеру — короткие точки, летящие поперёк — штрихи);
//  • кружок нерезкости объектива: ближние у самого лица — большие мягкие пятна «боке», дальние — чуть размыты;
//  • не уже пикселя кадра: мельче — бледнее, а не «ступенькой».
// Энергия хлопья сохраняется: длинный штрих или большое пятно бледнее, компактная точка ярче — поэтому
// в порыв штрихи длиннее, но не превращаются в светящиеся палки. Профиль — гауссов, краёв квада нет;
// голова штриха ярче хвоста — видно, куда несёт. Светится только в настоящем свете (фонарь, лампы, фальшфейер),
// у ламп ярче, если свет из-за хлопья (рассеяние вперёд). Туман считает сам (мягче общего: ближний снег
// в порыв не тонет). Внутри построек не рисуется.

#include "res://src/shaders/snowfield.gdshaderinc"

uniform float r_min = 0.003;          // собственный радиус хлопья, м
uniform float r_max = 0.008;
uniform float shutter = 0.0125;       // выдержка, с — длина смаза
uniform float aperture = 0.02;        // диаметр зрачка объектива, м — размытие вне фокуса
uniform float focus = 4.0;            // дистанция фокуса, м
uniform float px_k = 1.0;             // ширина «не уже пикселя» (в пикселях², гаусс)
uniform float opacity = 1.0;          // множитель непрозрачности слоя
uniform float a_max = 0.5;
uniform float near_a = 0.2;           // ближе — не видно (м)
uniform float near_b = 0.4;
uniform float far_a = 7.0;            // дальше — гаснет
uniform float far_b = 8.5;
uniform float fade_k = 1.0;           // общий множитель слоя (гаснет плавно, когда видимость падает)
uniform float disc = 0.0;            // 0 — гаусс, 1 — ровный диск «боке» с мягким краем
uniform float tail = 0.3;             // яркость хвоста штриха относительно головы
uniform float twinkle = 0.0;          // мерцание граней кристаллов
uniform float lift = 0.0;             // 1 — поднять на высоту наста (позёмка)
uniform float relief_k = 1.0;
uniform float vp_h = 540.0;           // строк в кадре
uniform float fog_b = 1.0;            // туман (как у окружения)
uniform float fog_e = 14.0;
uniform float fog_k = 0.8;
uniform float lit = 0.4;              // доля света, которую хлопье отражает к камере
uniform float fwd = 2.5;              // рассеяние вперёд: свет из-за хлопья
uniform vec3 tint = vec3(0.9, 0.93, 1.0);
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

varying vec2 q;          // точка квада в единицах σ: x — вдоль смаза, y — поперёк
varying float hl;        // полудлина отрезка смаза, σ
varying float amp;       // пиковая непрозрачность
varying vec3 wp;         // мировая точка фрагмента

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	if (lift > 0.5) {
		c.y += snow_h(c.xz, snow_mask(c.xz)) * relief_k;
	}
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to = c - cam;
	float dist = max(length(to), 0.001);
	vec3 vd = to / dist;
	float depth = max(dot(to, -INV_VIEW_MATRIX[2].xyz), 0.05);
	float fz = smoothstep(fog_b, fog_e, dist);
	float vis = COLOR.a * fade_k * smoothstep(near_a, near_b, dist) * (1.0 - smoothstep(far_a, far_b, dist));
	vis *= 1.0 - fog_k * pow(fz, 0.75);
	// смаз: часть скорости поперёк луча зрения
	vec3 vel = INSTANCE_CUSTOM.xyz;
	vec3 vpp = vel - vd * dot(vel, vd);
	float vl = length(vpp);
	vec3 upv = INV_VIEW_MATRIX[1].xyz;
	vec3 upp = upv - vd * dot(upv, vd);
	// оси квада перпендикулярны лучу зрения; вырожденный случай — квад в точку, а не NaN
	vec3 ax = vl > 0.0001 ? vpp / vl : upp / max(length(upp), 0.0001);
	vec3 sd = cross(vd, ax);
	// размер пятна: собственный радиус, кружок нерезкости и не меньше пикселя кадра
	float pxw = 2.0 * depth / (PROJECTION_MATRIX[1][1] * vp_h);
	float rf = mix(r_min, r_max, COLOR.r * COLOR.r);
	float coc = 0.5 * aperture * abs(1.0 - depth / focus);
	float sig = sqrt(rf * rf + coc * coc + px_k * pxw * pxw);
	float sl = vl * shutter;
	// энергия хлопья π·rf² размазана по гауссу π·σ² и по штриху √π·σ·sl
	float en = rf * rf / (sig * sig + 0.5642 * sig * sl);
	float tw = mix(0.45, 1.4, COLOR.g);
	tw *= 1.0 + twinkle * (0.3 * sin(TIME * (4.0 + 9.0 * COLOR.b) + COLOR.r * 53.0)
			+ 0.9 * pow(max(sin(TIME * (1.3 + 2.1 * COLOR.r) + COLOR.b * 31.0), 0.0), 24.0));
	amp = min(en * opacity * tw, a_max) * vis;
	// невидимые схлопываются в точку — без фрагментов
	float keep = step(0.0015, amp);
	float hx = 0.5 * sl + 2.2 * sig;
	float hy = 2.2 * sig;
	vec2 cr = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	VERTEX = c + (ax * (cr.x * hx) + sd * (cr.y * hy)) * keep;
	wp = VERTEX;
	q = cr * vec2(hx, hy) / sig;
	hl = 0.5 * sl / sig;
}

void fragment() {
	// расстояние до отрезка смаза в σ
	float dx = max(abs(q.x) - hl, 0.0);
	float d2 = dx * dx + q.y * q.y;
	// гаусс, к краю квада ровно ноль
	float g = max(exp(-d2) - 0.0079, 0.0) * 1.008;
	// диск «боке»: ровное пятно радиусом 2σ, мягкий край, чуть светлее у ободка
	float rr = sqrt(d2) * 0.5;
	float dk = (1.0 - smoothstep(0.62, 1.0, rr)) * (0.8 + 0.2 * smoothstep(0.3, 0.85, rr)) * 0.3;
	float a = mix(g, dk, disc);
	// голова (по ходу движения) ярче хвоста; у коротких штрихов — без разницы
	float tp = clamp((q.x + hl + 1.0) / (2.0 * hl + 2.0), 0.0, 1.0);
	a *= mix(1.0, mix(tail, 1.0, smoothstep(0.0, 1.0, tp)), clamp(hl * 0.5, 0.0, 1.0));
	for (int i = 0; i < box_n; i++) {
		vec3 b = step(box_min[i], wp) * step(wp, box_max[i]);
		a *= 1.0 - b.x * b.y * b.z;
	}
	ALBEDO = tint;
	ALPHA = a * amp;
}

void light() {
	float ph = 1.0 + fwd * pow(max(-dot(LIGHT, VIEW), 0.0), 6.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (lit * ph);
}
