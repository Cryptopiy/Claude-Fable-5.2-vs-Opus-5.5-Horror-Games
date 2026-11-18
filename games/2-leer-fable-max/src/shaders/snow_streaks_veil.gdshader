shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled, world_vertex_coords;
// Метель, штрихи по ветру (snow_streaks.gd) — завесы: большие мягкие облака несомого снега. Повёрнуты к камере и вытянуты по ветру,
// узор привязан к миру и сносится ветром (лоскут не «вертится» за взглядом): длинные пряди вдоль ветра.
// Очень прозрачные — дают в луче фонаря и у ламп волны и стену порыва, а не белую кашу.
// Края мягкие (эллипс в ноль), у земли и стен растворяются, у камеры гаснут, внутри построек не рисуются.

uniform sampler2D n_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 wd = vec2(0.7071, 0.7071);
uniform float adv = 0.0;              // путь ветра по модулю 400 м
uniform float density = 0.05;
uniform float size_min = 1.0;         // полувысота, м
uniform float size_max = 1.7;
uniform float near_a = 1.2;
uniform float near_b = 3.2;
uniform float far_a = 10.0;
uniform float far_b = 14.0;
uniform float fade_k = 1.0;           // общий множитель слоя (гаснет плавно, когда видимость падает)
uniform float lit = 0.3;
uniform float fwd = 2.0;
uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

varying vec3 wp;
varying vec2 lq;
varying float amp;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to = c - cam;
	float dist = max(length(to), 0.001);
	vec3 vd = to / dist;
	// длинная ось — ветер в плоскости кадра; если смотрим вдоль ветра — горизонталь кадра
	vec3 w3 = vec3(wd.x, 0.0, wd.y);
	vec3 aw = w3 - vd * dot(w3, vd);
	float al = length(aw);
	vec3 sdv = INV_VIEW_MATRIX[0].xyz;
	sdv -= vd * dot(sdv, vd);
	sdv *= sign(dot(sdv, aw) + 0.00001);
	sdv /= max(length(sdv), 0.0001);
	// оси перпендикулярны лучу зрения; вырожденный случай — квад в точку, а не NaN
	vec3 axm = mix(sdv, aw / max(al, 0.0001), smoothstep(0.05, 0.3, al));
	vec3 ax = axm / max(length(axm), 0.0001);
	vec3 up2 = cross(vd, ax);
	float sz = mix(size_min, size_max, COLOR.r);
	float st = mix(1.0, 1.9, smoothstep(0.2, 0.9, al));
	amp = COLOR.a * fade_k * smoothstep(near_a, near_b, dist) * (1.0 - smoothstep(far_a, far_b, dist));
	float keep = step(0.002, amp);
	vec2 cr = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	VERTEX = c + (ax * (cr.x * sz * st) + up2 * (cr.y * sz * 0.62)) * keep;
	wp = VERTEX;
	lq = cr;
}

void fragment() {
	// мягкий эллипс: к краю квада ровно ноль
	float e = clamp(1.0 - dot(lq, lq), 0.0, 1.0);
	float edge = e * e * (3.0 - 2.0 * e);
	vec2 pr = vec2(-wd.y, wd.x);
	float sa = dot(wp.xz, wd) - adv;
	float r = dot(wp.xz, pr);
	// пряди вдоль ветра (частоты вдоль ветра кратны 1/400 м — без скачка при переносе adv)
	float n1 = texture(n_lo, vec2(sa * (19.0 / 400.0), r * 0.09 + wp.y * 0.17)).r;
	float n2 = texture(n_hi, vec2(sa * (47.0 / 400.0) + 0.37, r * 0.23 - wp.y * 0.31 + 0.11)).r;
	float n = smoothstep(0.42, 0.8, n1 * 0.7 + n2 * 0.45);
	// мягко у земли и стен
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float scene_d = -sv.z / sv.w;
	float soft = clamp((scene_d + VERTEX.z) / 0.8, 0.0, 1.0);
	float a = density * n * edge * soft * amp;
	for (int i = 0; i < box_n; i++) {
		vec3 b = step(box_min[i], wp) * step(wp, box_max[i]);
		a *= 1.0 - b.x * b.y * b.z;
	}
	ALBEDO = vec3(0.9, 0.93, 0.98);
	ALPHA = a;
}

void light() {
	float ph = 1.0 + fwd * pow(max(-dot(LIGHT, VIEW), 0.0), 6.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (lit * ph);
}
