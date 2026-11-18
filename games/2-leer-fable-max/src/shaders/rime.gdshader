shader_type spatial;
render_mode cull_back;
// Обмёрзшее на ветру: на гранях, обращённых к ветру (северо-запад), — иней пятнами, на верхних гранях — снег.
// Для столбов лееров, указателей, ограды. Цвет основы — base (или экземпляра MultiMesh, если use_inst).

uniform vec3 base : source_color = vec3(0.2, 0.165, 0.13);
uniform float rough = 0.92;
uniform float rime = 1.0;            // сколько инея
uniform bool use_inst = false;
global uniform vec4 g_wind;
global uniform sampler2D g_noise : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 icol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icol = use_inst ? COLOR.rgb : base;
}

void fragment() {
	vec3 from_wind = -normalize(vec3(g_wind.x, 0.0, g_wind.y) + vec3(0.0001));
	float face = smoothstep(0.05, 0.7, dot(wnrm, from_wind));
	float top = smoothstep(0.55, 0.9, wnrm.y);
	// пятна инея: гуще внизу (позёмка) и к ветру
	float n = texture(g_noise, wpos.xz * 1.7 + vec2(wpos.y * 2.3, wpos.y * 0.7)).g;
	float n2 = texture(g_noise, vec2(wpos.x + wpos.z, wpos.y) * 4.1).b;
	float low = 1.0 - smoothstep(0.2, 1.6, wpos.y);
	float frost = face * smoothstep(0.62 - 0.3 * low, 0.85 - 0.2 * low, n * 0.75 + n2 * 0.4) * rime;
	float snow = top * rime;
	float k = clamp(max(frost * 0.9, snow), 0.0, 1.0);
	ALBEDO = mix(icol, vec3(0.78, 0.83, 0.9), k);
	ROUGHNESS = mix(rough, 0.55, k);
	SPECULAR = mix(0.25, 0.45, k);
}
