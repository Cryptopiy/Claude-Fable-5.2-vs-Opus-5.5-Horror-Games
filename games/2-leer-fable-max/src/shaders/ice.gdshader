shader_type spatial;
render_mode cull_back;
// Лёд ледника: тёмная толща с трещинами и пузырьками на разной глубине (параллакс по взгляду), блеск по краю,
// изморозь в стыках у пола и потолка. Раньше это был светлый «кафель» с яркими швами.

uniform sampler2D crack_tex : filter_linear_mipmap, repeat_enable;      // ice_d: светлые линии — трещины
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float meters = 2.4;
uniform vec3 deep : source_color = vec3(0.025, 0.06, 0.085);
uniform vec3 shallow : source_color = vec3(0.22, 0.33, 0.42);
uniform float floor_y = 0.0;
uniform float ceil_y = 2.1;
uniform bool is_floor = false;
varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV / meters;
	// направление взгляда в касательном пространстве — для глубины
	vec3 v = normalize(-VIEW);
	vec2 par = vec2(dot(v, TANGENT), dot(v, BINORMAL)) / max(dot(v, NORMAL), 0.25);
	float c0 = texture(crack_tex, uv).r;
	float c1 = texture(crack_tex, uv * 0.73 + vec2(0.31, 0.17) - par * 0.035).r;
	float c2 = texture(crack_tex, uv * 1.37 + vec2(0.61, 0.43) - par * 0.08).r;
	float cracks = smoothstep(0.72, 0.97, c0) * 0.55 + smoothstep(0.7, 0.97, c1) * 0.35 + smoothstep(0.7, 0.97, c2) * 0.2;
	// трещины не по всей стене одинаковой сеткой: местами лёд цельный
	cracks *= smoothstep(0.3, 0.7, texture(noise_tex, uv * 0.35 + 0.2).g);
	// толща: светлее там, где лёд «тоньше», пятнами
	float n = texture(noise_tex, uv * 0.6 - par * 0.05).r;
	float n2 = texture(noise_tex, uv * 2.2 - par * 0.12).g;
	vec3 col = mix(deep, shallow, smoothstep(0.25, 0.85, n * 0.7 + n2 * 0.4));
	// пузырьки воздуха на глубине
	float b = texture(noise_tex, uv * 9.0 - par * 0.1).b * texture(noise_tex, uv * 13.0 + 0.5 - par * 0.15).b;
	col += vec3(0.5, 0.6, 0.65) * smoothstep(0.55, 0.75, b) * 0.35;
	col += vec3(0.55, 0.65, 0.72) * cracks * 0.45;
	// изморозь в стыках и на полу
	// иней — у пола на стенах; на потолке (грань смотрит вниз) — только редкие пятна, иначе потолок как «облака»
	float wall = 1.0 - abs(wn.y);
	float edge = (1.0 - smoothstep(0.0, 0.35, wpos.y - floor_y)) * wall + smoothstep(ceil_y - 0.25, ceil_y, wpos.y) * wall * 0.6;
	float rime = clamp(edge, 0.0, 1.0) * smoothstep(0.35, 0.7, texture(noise_tex, wpos.xz * 1.3 + wpos.y).g);
	if (wn.y < -0.5) {
		rime = 0.25 * smoothstep(0.6, 0.85, texture(noise_tex, wpos.xz * 0.9).g);
	}
	if (is_floor) {
		rime = 0.35 + 0.4 * smoothstep(0.4, 0.8, texture(noise_tex, wpos.xz * 0.8).g);
	}
	col = mix(col, vec3(0.62, 0.68, 0.74), rime * 0.6);
	float fres = pow(1.0 - clamp(dot(v, NORMAL), 0.0, 1.0), 4.0);
	ALBEDO = col;
	ROUGHNESS = mix(0.08, 0.6, rime) + cracks * 0.1;
	SPECULAR = 0.6;
	EMISSION = vec3(0.02, 0.035, 0.045) * fres;
}
