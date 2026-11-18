shader_type canvas_item;
// Пост-эффект «Сырой свет», низкое качество (Intel UHD): тот же цвет и зерно, но экран без мип-цепочки
// (filter_linear) — без ореола и запотевания; аберрация только при страхе и «за спиной».

#include "res://src/fx/film.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float fear = 0.0;
uniform float behind = 0.0;
uniform float memory = 0.0;
uniform float grain = 0.045;
uniform float slats = 0.0;
uniform float hurt = 0.0;
uniform float time_s = 0.0;
uniform float brightness_k = 1.0;
uniform float lens = 0.0;
uniform float halation = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	float wob = fear * fear * 0.003;
	uv += vec2(sin(time_s * 31.0 + uv.y * 40.0), cos(time_s * 27.0 + uv.x * 35.0)) * wob;
	vec3 col;
	float ab = (fear * 0.007 + behind * 0.006) * d * 2.0;
	if (ab > 0.0001) {
		col.r = texture(screen, uv + c * ab).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - c * ab).b;
	} else {
		col = texture(screen, uv).rgb;
	}
	// пар без размытия: просто белёсая дымка по краям
	col = mix(col, col * 0.8 + vec3(0.08), lens * smoothstep(0.3, 0.75, d) * 0.7);
	col = film_grade(col, brightness_k);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.0), behind * 0.75);
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
