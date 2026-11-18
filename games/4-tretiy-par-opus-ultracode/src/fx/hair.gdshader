shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Мокрые волосы Хозяйки: пряди-ленты, качаются, ложатся на пол, могут расступиться (part) перед лицом.

// без source_color: s.r — как в картинке (0.02…0.08); после линеаризации было ~0.005 и пряди не различались
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.05, 0.045, 0.045);
uniform float floor_y = 0.0;
uniform float sway = 1.0;
uniform float part = 0.0;        // 0 — лицо закрыто, 1 — пряди разошлись
uniform float wet = 0.85;
uniform vec3 move_dir = vec3(0.0);  // скорость в локальных координатах — пряди отстают
uniform float reveal = 1.0;       // 0..1 — появление из трапа (растворение снизу)
uniform float clip_y = -1000.0;

varying float v_len;
varying vec3 v_world;

void vertex() {
	float t = UV.y;
	float phase = COLOR.r * 6.2831;
	float front = COLOR.g;            // 1 — прядь спереди лица
	float side = COLOR.b * 2.0 - 1.0; // в какую сторону расступаться
	vec3 v = VERTEX;
	float w = t * t;
	v.x += sin(TIME * 1.3 + phase) * 0.03 * w * sway;
	v.z += cos(TIME * 1.1 + phase * 1.7) * 0.03 * w * sway;
	v -= move_dir * 0.18 * w;
	v.x += side * part * front * 0.22 * smoothstep(0.0, 0.25, t);
	v.z -= part * front * 0.05 * smoothstep(0.0, 0.3, t);
	vec3 wp = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	// пряди ложатся на пол и растекаются
	if (wp.y < floor_y + 0.01) {
		float under = floor_y + 0.01 - wp.y;
		vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec2 dir = normalize(wp.xz - c.xz + vec2(0.0001));
		wp.xz += dir * under * 0.6;
		wp.y = floor_y + 0.01 + COLOR.r * 0.01;
	}
	v_world = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	v_len = t;
}

void fragment() {
	vec4 s = texture(strands, vec2(UV.x * 0.5 + COLOR.r * 0.5, UV.y * 0.8 + COLOR.r * 0.2));
	if (v_world.y < clip_y) {
		discard;
	}
	// лента сужается к кончику (прядь, а не доска с прямыми краями); у корня — во всю ширину, чтобы не просвечивал
	// скальп. Альфа в текстуре двоичная (0 или ≥0.6), поэтому сужение режет край, а не делает его полупрозрачным.
	// Порог 0.5, а не 0.35: в дальних мипах альфа размыта, и при 0.35 они закрашены на 93–95% — пряди сливаются
	// в сплошные ленты; вблизи (мип 0, непрозрачное ≥0.6) разницы почти нет
	float e = mix(0.0, 0.3, smoothstep(0.1, 1.0, v_len));
	float edge = smoothstep(0.0, e + 0.001, UV.x) * (1.0 - smoothstep(0.999 - e, 1.0, UV.x));
	float a = s.a * edge * (1.0 - smoothstep(0.85, 1.0, v_len) * 0.7);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// разброс яркости по прядям и по лентам (COLOR.r — своя фаза у каждой ленты)
	ALBEDO = tint * (0.35 + s.r * 5.0) * (0.85 + COLOR.r * 0.3);
	ROUGHNESS = mix(0.6, 0.12, wet);
	SPECULAR = 0.75;
	// нормали теперь смотрят на зрителя: ободок только на силуэте, 0.4 выжигал бы края лент
	RIM = 0.25;
	RIM_TINT = 0.5;
	BACKLIGHT = vec3(0.02);
}
