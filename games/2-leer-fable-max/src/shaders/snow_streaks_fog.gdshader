shader_type fog;
// Метель, штрихи по ветру (snow_streaks.gd) — объём пурги в объёмном тумане (только с полными эффектами). Туман светится лишь там,
// где есть свет (ambient_inject 0), поэтому всё это видно только в луче фонаря и у огней:
//  • дымка позёмки — тонкий плотный слой у самого наста, струями вдоль ветра;
//  • стена порыва — рваный гребень плотности у переднего края порыва, бежит по ветру;
//  • за фронтом — волны гуще снега, сносимые ветром.
// Внутри построек плотность не добавляется; к краям коробки — плавно в ноль.

uniform sampler2D n_lo : filter_linear, repeat_enable;
uniform sampler2D n_hi : filter_linear, repeat_enable;
uniform vec3 cam_pos = vec3(0.0);
uniform vec2 wd = vec2(0.7071, 0.7071);
uniform float adv = 0.0;            // путь ветра по модулю 400 м
uniform float front_s = -10000.0;
uniform float gust = 0.0;
uniform float drift_d = 0.03;       // плотность дымки позёмки у наста
uniform float wall_d = 0.035;       // плотность стены порыва
uniform float band_d = 0.012;       // плотность волн за фронтом
uniform float half_w = 26.0;        // полуширина коробки, м
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

void fog() {
	vec3 p = WORLD_POSITION;
	vec2 pr = vec2(-wd.y, wd.x);
	float s = dot(p.xz, wd);
	float r = dot(p.xz, pr);
	float sa = s - adv;
	// дымка позёмки: экспонента от наста, струи вдоль ветра
	float wob = textureLod(n_lo, vec2(sa * (5.0 / 400.0), r * 0.021 + 0.3), 0.0).r - 0.5;
	float st = textureLod(n_hi, vec2(sa * (13.0 / 400.0), (r + wob * 4.0) * 0.08), 0.0).r;
	float hy = max(p.y, 0.0);
	float low = exp(-hy / 0.32) * (0.3 + 0.9 * smoothstep(0.42, 0.72, st));
	// стена порыва: рваный передний край
	float rag = textureLod(n_lo, vec2(r * 0.023, 0.31), 0.0).r - 0.5;
	float fd = front_s + rag * 9.0 - s;
	float xr = (fd - 2.5) / 2.8;
	float ridge = exp(-xr * xr);
	float behind = smoothstep(-1.5, 3.5, fd);
	float band = smoothstep(0.36, 0.68, textureLod(n_lo, vec2(sa * (17.0 / 400.0), r * 0.019 + 0.53), 0.0).r);
	float lump = 0.6 + 0.8 * textureLod(n_hi, vec2(sa * (29.0 / 400.0) + 0.5, r * 0.05 + p.y * 0.07), 0.0).r;
	float dens = drift_d * low + gust * (wall_d * ridge * lump + band_d * behind * band);
	// стена пурги — не выше ~12 м; к краям коробки — в ноль
	dens *= 1.0 - smoothstep(5.0, 12.0, p.y);
	vec2 dd = abs(p.xz - cam_pos.xz);
	dens *= 1.0 - smoothstep(half_w * 0.75, half_w * 0.98, max(dd.x, dd.y));
	for (int i = 0; i < box_n; i++) {
		vec3 b = step(box_min[i], p) * step(p, box_max[i]);
		dens *= 1.0 - b.x * b.y * b.z;
	}
	DENSITY = max(dens, 0.0);
	ALBEDO = vec3(0.88, 0.91, 0.96);
}
