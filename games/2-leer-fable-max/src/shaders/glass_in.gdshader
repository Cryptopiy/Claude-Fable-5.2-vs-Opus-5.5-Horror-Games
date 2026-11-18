shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled;
// Окно изнутри: за стеклом чёрная полярная ночь, иней растёт от рамы (frost — по ночам больше),
// внизу конденсат, на стекле блики ламп, снаружи изредка проносятся полосы снега.

uniform sampler2D frost_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 size = vec2(1.0, 0.9);    // стекло, м
uniform float frost = 0.3;             // 0..1 — сколько затянуло инеем
global uniform vec4 g_wind;
global uniform float g_gust;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// расстояние до рамы в метрах; низ стекла холоднее — иней и конденсат там выше
	vec2 m = vec2(min(uv.x, 1.0 - uv.x) * size.x, min(uv.y, 1.0 - uv.y) * size.y);
	float e = min(m.x, m.y);
	float bottom = smoothstep(0.55, 1.0, uv.y);
	float reach = 0.03 + 0.26 * frost + 0.1 * bottom * frost;
	vec4 ft = texture(frost_tex, uv);
	float grow = 1.0 - smoothstep(reach * 0.3, reach, e - ft.a * 0.05);
	// узор «папоротника» из текстуры: иней не сплошной, между веточками видно ночь
	float fr = clamp(grow * smoothstep(0.25, 0.85, ft.a) * (0.65 + 0.35 * ft.g), 0.0, 1.0);
	// конденсат: молочная дымка снизу
	float fog = bottom * 0.25 * (0.4 + frost);
	// снаружи несёт снег: редкие косые полосы, в порыв гуще
	vec2 su = vec2(uv.x * 9.0 + uv.y * 3.0 * sign(g_wind.x + 0.01), uv.y * 1.2 - TIME * (1.6 + 2.5 * g_gust));
	float lane = floor(su.x);
	float ph = fract(su.y + hash(vec2(lane, 3.1)) * 7.0);
	float streak = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.08, 0.45, ph));
	streak *= smoothstep(0.35, 0.5, abs(fract(su.x) - 0.5) * -1.0 + 0.85) * step(0.55 - g_gust * 0.25, hash(vec2(lane, floor(su.y + hash(vec2(lane, 9.0)) * 7.0))));
	vec3 night = vec3(0.006, 0.008, 0.012) + vec3(0.05, 0.055, 0.065) * streak * (1.0 - fr);
	vec3 ice = mix(vec3(0.3, 0.35, 0.41), vec3(0.6, 0.65, 0.72), ft.g);
	ALBEDO = mix(night, ice, fr) + vec3(fog * 0.3);
	ALPHA = clamp(mix(0.5 + fog, 0.86, fr), 0.0, 1.0);
	ROUGHNESS = mix(0.06, 0.65, fr);
	SPECULAR = 0.7;
}
