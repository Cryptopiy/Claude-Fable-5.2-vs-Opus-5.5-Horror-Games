shader_type spatial;
render_mode cull_back;
// Крашеные доски дома: у пола и под потолком темнее (копоть, грязь от валенок), рыжие пятна приглушены,
// комнаты изношены по-разному (кладовая и тамбур грязнее, радиорубка — серее и холоднее).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.8, 0.79, 0.72);
uniform float meters = 2.0;           // сколько метров на повтор текстуры (UV у Batch — в метрах)
uniform float floor_y = 0.03;
uniform float ceil_y = 2.5;
global uniform sampler2D g_noise : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV / meters;
	vec3 c = texture(albedo_tex, uv).rgb;
	// рыжие пятна-повторы текстуры: увести к цвету краски
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float stain = smoothstep(0.12, 0.26, c.r - c.b);
	c = mix(c, vec3(lum) * vec3(1.06, 1.0, 0.86), stain * 0.75);
	// износ комнат: x < −2 — радиорубка (север) и кладовая (юг), x > 2 — спальня и тамбур
	vec3 room = vec3(1.0);
	if (wpos.x < -2.0) {
		room = wpos.z < 0.0 ? vec3(0.86, 0.9, 0.93) : vec3(0.78, 0.76, 0.7);
	} else if (wpos.x > 2.0) {
		room = wpos.z < 0.0 ? vec3(0.95, 0.93, 0.88) : vec3(0.8, 0.78, 0.72);
	}
	float h = wpos.y - floor_y;
	float low = 1.0 - smoothstep(0.0, 0.55, h);             // низ стены: грязь, сырость
	float top = smoothstep(ceil_y - 0.5, ceil_y, wpos.y);   // копоть под потолком
	float grime = texture(g_noise, wpos.xz * 0.35 + vec2(wpos.y * 0.6, 0.0)).r;
	float dirt = clamp(low * 0.45 + top * 0.3 + (grime - 0.45) * 0.35, 0.0, 0.7);
	ALBEDO = c * tint * room * (1.0 - dirt);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = clamp(texture(rough_tex, uv).r + low * 0.1, 0.0, 1.0);
	SPECULAR = 0.3;
}
