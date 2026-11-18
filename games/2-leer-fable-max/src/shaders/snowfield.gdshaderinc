// Снежный покров: высота наста в точке мира (м). Общая для земли и следов, чтобы следы лежали на рельефе.
// Заструги — узкие гребни вдоль ветра, пологие волны — крупные наметённые валы. Маска станции (её рисует world.gd):
// R — утоптанный наст у лееров и построек (ниже и ровнее), G — пол построек (ровно ноль, снег не лезет в дом).

global uniform sampler2D g_snow_mask : filter_linear_mipmap, repeat_disable;
global uniform vec4 g_snow_rect;       // x, z начала маски и её размер по x, z (м)
global uniform sampler2D g_noise : filter_linear_mipmap, repeat_enable;
global uniform vec4 g_wind;

vec2 snow_mask(vec2 xz) {
	vec2 uv = (xz - g_snow_rect.xy) / max(g_snow_rect.zw, vec2(1.0));
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return textureLod(g_snow_mask, uv, 1.6).rg * inside.x * inside.y;
}

// m — маска в этой точке (snow_mask). Возвращает высоту 0..~0.4 м.
float snow_h(vec2 xz, vec2 m) {
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	vec2 q = vec2(dot(xz, wd), dot(xz, vec2(-wd.y, wd.x)));
	// заструги: длинные по ветру, частые поперёк
	float s1 = textureLod(g_noise, vec2(q.x * 0.03, q.y * 0.19), 0.0).g;
	float s2 = textureLod(g_noise, vec2(q.x * 0.055 + 0.31, q.y * 0.37 + 0.73), 0.0).g;
	// пологие наметённые волны
	float dune = textureLod(g_noise, xz * 0.011 + vec2(0.17, 0.61), 0.0).r;
	float h = smoothstep(0.38, 0.82, s1) * 0.13 + smoothstep(0.46, 0.88, s2) * 0.07 + smoothstep(0.2, 0.9, dune) * 0.22;
	h *= 1.0 - 0.8 * m.r;
	h *= 1.0 - m.g;
	return h;
}
