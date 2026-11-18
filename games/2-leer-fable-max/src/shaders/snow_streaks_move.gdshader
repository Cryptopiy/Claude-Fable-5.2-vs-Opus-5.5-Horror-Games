shader_type particles;
render_mode disable_force, disable_velocity;
// Метель, штрихи по ветру (snow_streaks.gd) — движение снега (общий для всех слоёв частиц).
// Частицы живут всё время в коробке вокруг камеры: вышедшая за грань переносится на противоположную —
// снег вокруг есть всегда, куда ни беги и ни смотри (пустых мест «у края выброса» не бывает).
// Ветер: средний поток с северо-запада + вихри (ABC-поток в осях ветра: бездивергентный, хлопья кружат,
// но не сбиваются в кучи; узор сносится ветром) + порыв, приходящий рваной стеной с наветренной стороны.
// Видна ли частица — решает поле плотности: у каждой свой «ранг», видна, если ранг ниже плотности в её точке.
// Так порыв приходит стеной и волнами гуще снега, а не общим «прибавить яркость».
// Для рисования: CUSTOM.xyz — скорость относительно камеры (смаз), CUSTOM.w — ранг,
// COLOR.r — размер, COLOR.g — яркость (у позёмки и высота), COLOR.b — своя прибавка скорости, COLOR.a — видимость.

const float PERIOD = 400.0;   // узоры, сносимые ветром, повторяются через столько метров (путь adv — по модулю)

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 center = vec3(0.0);           // центр коробки
uniform vec3 half_ext = vec3(5.0, 2.5, 5.0);
uniform vec3 cam_vel = vec3(0.0);          // скорость камеры, м/с
uniform vec2 wd = vec2(0.7071, 0.7071);    // куда дует ветер (x, z)
uniform float wind_u = 8.0;                // средняя скорость ветра, м/с
uniform float adv = 0.0;                   // путь ветра по модулю PERIOD, м
uniform float turb = 2.0;                  // сила вихрей, м/с
uniform float fall_min = 0.4;              // скорость падения, м/с
uniform float fall_max = 1.4;
uniform float speed_var = 0.25;            // разброс скорости по частицам
uniform float dens = 0.5;                  // доля видимых частиц без порыва
uniform float gust = 0.0;                  // сила порыва 0..1
uniform float front_s = -10000.0;          // передний край порыва: координата вдоль ветра, м
uniform float gust_dens = 1.0;             // насколько порыв добавляет снега за фронтом
uniform float ridge_dens = 0.5;            // и в самой стене у фронта
uniform float band_k = 0.25;               // волны плотности вдоль ветра (в порыв сильнее)
uniform float ground = 0.0;                // 1 — позёмка: у самого наста, только вдоль поверхности
uniform float h_max = 0.45;                // позёмка: до какой высоты, м
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

uint pcg(uint v) {
	uint s = v * 747796405u + 1013904223u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}

float rnd(uint v) {
	return float(pcg(v) & 16777215u) / 16777215.0;
}

void start() {
	uint id = INDEX * 8u + RANDOM_SEED * 7919u;
	vec3 r = vec3(rnd(id + 1u), rnd(id + 2u), rnd(id + 3u));
	vec3 p = center + (r * 2.0 - 1.0) * half_ext;
	TRANSFORM = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 1.0));
	COLOR = vec4(rnd(id + 4u), rnd(id + 5u), rnd(id + 6u), 0.0);
	CUSTOM = vec4(0.0, 0.0, 0.0, rnd(id + 7u) * 0.9);
	VELOCITY = vec3(0.0);
}

void process() {
	vec3 p = TRANSFORM[3].xyz;
	vec2 pr = vec2(-wd.y, wd.x);
	float s = dot(p.xz, wd);       // вдоль ветра
	float rr = dot(p.xz, pr);      // поперёк ветра
	float sa = s - adv;            // координата в узоре, который сносит ветер
	float t = TIME;

	// порыв: рваная стена поперёк ветра, бежит по ветру
	float rag = textureLod(noise_tex, vec2(rr * 0.023, 0.31), 0.0).r - 0.5;
	float fd = front_s + rag * 9.0 - s;                    // > 0 — порыв уже здесь
	float behind = smoothstep(-1.5, 3.5, fd);
	float xr = (fd - 2.5) / 2.8;
	float ridge = exp(-xr * xr) * gust;                    // сама стена — у переднего края
	float g = gust * behind;
	// волны плотности бегут вместе с ветром
	float band = smoothstep(0.36, 0.68, textureLod(noise_tex, vec2(sa * (17.0 / PERIOD), rr * 0.019 + 0.53), 0.0).r);
	float bk = clamp(band_k + 0.6 * g, 0.0, 1.0);

	// скорость вдоль ветра: за фронтом и в стене — быстрее, в волнах — чуть быстрее
	float pv = COLOR.b * 2.0 - 1.0;
	float u = wind_u * (1.0 + 0.4 * g + 0.3 * ridge) * (1.0 + 0.16 * bk * (band - 0.5)) * (1.0 + speed_var * pv);
	// вихри: ABC-поток в осях (s — вдоль ветра, y — вверх, r — поперёк). Каждая составляющая не зависит
	// от своей координаты — поле без источников и стоков. Частоты вдоль ветра кратны 2π/PERIOD.
	float k1 = TAU * 23.0 / PERIOD;    // волна ≈ 17 м
	float k2 = TAU * 71.0 / PERIOD;    // волна ≈ 5,6 м
	float y = p.y;
	vec3 v1 = vec3(sin(k1 * rr + t * 0.31) + 0.8 * cos(k1 * 1.7 * y + t * 0.23),
			0.9 * sin(k1 * sa) + cos(k1 * 1.3 * rr - t * 0.27),
			0.8 * sin(k1 * 1.7 * y - t * 0.19) + 0.9 * cos(k1 * sa + 1.3));
	vec3 v2 = vec3(sin(k2 * 0.9 * rr + t * 0.7) + 0.7 * cos(k2 * 1.4 * y - t * 0.5),
			0.8 * sin(k2 * sa + 2.1) + 0.6 * cos(k2 * 1.1 * rr + t * 0.6),
			0.7 * sin(k2 * 1.4 * y + t * 0.4) + 0.8 * cos(k2 * sa + 0.4));
	vec3 tv = (v1 * 0.6 + v2 * 0.4) * turb * (1.0 + 0.7 * g);
	float fall = mix(fall_min, fall_max, COLOR.r);         // крупные падают быстрее
	// стена порыва поднимает снег вверх
	vec3 vs = vec3(u + tv.x, tv.y - fall + 1.6 * ridge, tv.z);
	if (ground > 0.5) {
		// позёмка: по самому насту, змеится поперёк ветра, вверх не уходит
		vs = vec3(u * 1.1 + tv.x * 0.4, 0.0, tv.z * 0.7);
	}
	vec3 vel = vec3(wd.x * vs.x + pr.x * vs.z, vs.y, wd.y * vs.x + pr.y * vs.z);

	// шаг и перенос на другую сторону коробки
	p += vel * DELTA;
	vec3 rel = p - center;
	rel -= 2.0 * half_ext * floor((rel + half_ext) / (2.0 * half_ext));
	p = center + rel;
	vec3 e = abs(rel) / half_ext;

	float vis;
	float dn;
	if (ground > 0.5) {
		// высота над настом (наст добавит шейдер рисования): больше всего у самой поверхности, лёгкие скачки
		p.y = 0.012 + h_max * COLOR.g * COLOR.g * (0.8 + 0.2 * sin(t * (2.0 + 3.0 * COLOR.b) + COLOR.r * 37.0));
		// позёмка идёт струями: длинные по ветру, змеятся поперёк
		float wob = textureLod(noise_tex, vec2(sa * (6.0 / PERIOD), rr * 0.03 + 0.7), 0.0).r - 0.5;
		float st = textureLod(noise_tex, vec2(sa * (11.0 / PERIOD) + 0.21, (rr + wob * 5.0) * 0.21), 0.0).r;
		dn = dens * (0.15 + 1.5 * smoothstep(0.42, 0.7, st)) * (1.0 + gust_dens * g) + ridge_dens * ridge;
		vis = 1.0 - smoothstep(0.8, 1.0, max(e.x, e.z));
	} else {
		dn = dens * (1.0 + gust_dens * g) * mix(1.0, 0.45 + 1.1 * band, bk) + ridge_dens * ridge;
		// у граней коробки гаснет — перенос не виден
		vis = (1.0 - smoothstep(0.82, 1.0, max(e.x, e.z))) * (1.0 - smoothstep(0.75, 1.0, e.y));
	}
	vis *= smoothstep(CUSTOM.w, CUSTOM.w + 0.1, dn);
	// внутри построек снега нет
	for (int i = 0; i < box_n; i++) {
		vec3 a = step(box_min[i], p) * step(p, box_max[i]);
		vis *= 1.0 - a.x * a.y * a.z;
	}
	TRANSFORM[3] = vec4(p, 1.0);
	VELOCITY = vel;
	CUSTOM.xyz = vel - cam_vel;
	COLOR.a = vis;
}
