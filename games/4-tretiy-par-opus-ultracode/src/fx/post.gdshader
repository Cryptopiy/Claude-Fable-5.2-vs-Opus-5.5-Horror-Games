shader_type canvas_item;
// Пост-эффект «Сырой свет» (среднее и высокое качество): цвет и зерно плёночной печати (film.gdshaderinc),
// тонкий красно-оранжевый ореол только у горячих тёплых источников (топки, свечи, угли — не синие окна),
// запотевание объектива в пару (края кадра, центр чище), страх (аберрация, дрожь), «за спиной» (серебро,
// сужение), воспоминание (выцветший пурпурный позитив), щели шкафчика, краснота от вреда.
// Низкое качество — post_lo.gdshader: без ореола и запотевания, экран без мип-цепочки.

#include "res://src/fx/film.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float fear = 0.0;
uniform float behind = 0.0;
uniform float memory = 0.0;
uniform float grain = 0.045;
uniform float slats = 0.0;
uniform float hurt = 0.0;
uniform float time_s = 0.0;
uniform float brightness_k = 1.0;  // настройка «Яркость» поднимает и пол чёрного
uniform float lens = 0.0;          // запотевание объектива 0..1 (пар)
uniform float halation = 0.4;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	// дрожь только от страха: в покое кадр неподвижен
	float wob = fear * fear * 0.003;
	uv += vec2(sin(time_s * 31.0 + uv.y * 40.0), cos(time_s * 27.0 + uv.x * 35.0)) * wob;
	float ab = (0.0008 + fear * 0.007 + behind * 0.006) * d * 2.0;
	vec3 col;
	col.r = texture(screen, uv + c * ab).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - c * ab).b;
	// ореол: размытая копия кадра, только яркое и тёплое
	vec3 b1 = textureLod(screen, uv, 2.5).rgb;
	vec3 b2 = textureLod(screen, uv, 4.5).rgb;
	vec3 bl = b1 * 0.6 + b2 * 0.4;
	float hot = smoothstep(0.45, 0.95, max(bl.r, max(bl.g, bl.b)));
	float warmb = smoothstep(0.08, 0.35, bl.r - bl.b);
	col += vec3(1.0, 0.32, 0.12) * hot * warmb * halation * bl.r;
	// запотевание: по краям размыто и белёсо, рваная граница, дорожки стёкших капель
	if (lens > 0.001) {
		float edge = smoothstep(0.28, 0.72, d + (vnoise(uv * 7.0) - 0.5) * 0.22);
		float col_x = floor(uv.x * 70.0);
		float drip = step(0.93, hash12(vec2(col_x, 3.0))) * step(fract(hash12(vec2(col_x, 7.0)) + uv.y * 0.6 - time_s * 0.02), 0.55);
		float m = lens * edge * (1.0 - drip * 0.8);
		vec3 fogged = textureLod(screen, uv, 3.5).rgb * 0.85 + vec3(0.07, 0.075, 0.075);
		col = mix(col, fogged, clamp(m, 0.0, 1.0));
	}
	col = film_grade(col, brightness_k);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	// «за спиной»: кадр уходит в серебро, края темнеют (центр и рука остаются читаемыми)
	col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.0), behind * 0.75);
	// воспоминание о 2004-м: выцветший пурпурный позитив
	col = mix(col, vec3(lum * 1.25 + 0.12) * vec3(1.0, 0.84, 0.9), memory);
	float vig = smoothstep(0.85 - fear * 0.25 - behind * 0.35, 0.25 - behind * 0.15, d);
	col *= mix(1.0, vig, 0.65);
	col = mix(col, col * vec3(1.3, 0.4, 0.35), hurt);
	col = film_grain(col, FRAGCOORD.xy, time_s, grain + fear * 0.06 + memory * 0.12);
	if (slats > 0.0) {
		// края полосы — посреди тёмных промежутков узора (1/9): две целые щели без тонких обрезков по краям
		float sl = step(0.5, fract(SCREEN_UV.y * 9.0)) * step(0.361, SCREEN_UV.y) * step(SCREEN_UV.y, 0.583);
		col *= mix(0.05, 1.0, mix(1.0, sl, slats));
	}
	COLOR = vec4(col, 1.0);
}
