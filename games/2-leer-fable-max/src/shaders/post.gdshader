shader_type canvas_item;
// «Плёнка»: кадр выглядит как советская 16-мм съёмка 1987 года (обращаемая плёнка, проявка с сохранением серебра).
// Холодный почти бесцветный мир, провалы в чёрное, тёплые огни с красноватым ореолом засветки (халация),
// дрожь кадра в фильмовом канале, мерцание экспозиции, пыль и царапины, зерно — гуще в тенях.
// Поверх — игровые слои: изморозь от холода, помехи рядом с существом, страх, вспышка, затемнение.

uniform vec2 src_size = vec2(960.0, 540.0);
uniform float grain = 1.0;          // сила «плёнки» 0..1.5: зерно, пыль, дрожь кадра (настройка «Плёнка»)
uniform float halation = 1.0;       // ореол засветки вокруг огней (0 — упрощённые эффекты)
uniform float cold = 0.0;           // 0..1 изморозь от краёв
uniform float fear = 0.0;           // 0..1 сужение поля зрения, обесцвечивание
uniform float interference = 0.0;   // 0..1 помехи (существо рядом)
uniform float flash = 0.0;          // белая вспышка
uniform float dark = 0.0;           // затемнение (моргание, обморок)
uniform float blur = 0.0;           // 0..1 расфокус (замерзание)
uniform float pulse = 0.0;          // удар сердца 0..1
uniform float red = 0.0;            // красный оттенок (смерть)
uniform sampler2D frost_tex : repeat_disable, filter_linear;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	float t = TIME;
	float tb = floor(t * 24.0);                 // кадры плёнки — 24 в секунду
	float fk = clamp(grain, 0.0, 1.5);
	vec2 uv = UV;
	// дрожь кадра в канале проектора: медленный дрейф + рывок на каждом кадре
	vec2 weave = vec2(sin(t * 1.3) * 0.6 + (hash(vec2(tb, 1.7)) - 0.5) * 0.7, sin(t * 0.9 + 1.1) * 0.4 + (hash(vec2(tb, 5.3)) - 0.5) * 0.9);
	uv += weave * fk / src_size * 0.9;
	// объектив: лёгкая бочка, края чуть сжаты внутрь (без чёрных полос)
	vec2 c0 = uv - 0.5;
	uv = 0.5 + c0 * (0.985 + 0.03 * dot(c0, c0));
	// помехи: строки рвутся в стороны
	if (interference > 0.001) {
		float line = floor(uv.y * src_size.y * 0.5);
		float n = hash(vec2(line, tb + 0.5));
		float band = step(1.0 - interference * 0.35, hash(vec2(floor(uv.y * 14.0), floor(t * 9.0))));
		uv.x += (n - 0.5) * interference * 0.012 + band * (n - 0.5) * interference * 0.06;
	}
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.0, 0.82));
	// изморозь растёт от краёв: в текстуре записано, когда иней дойдёт до каждой точки
	vec4 fr = texture(frost_tex, UV);
	float frost = smoothstep(fr.r - 0.05, fr.r + 0.12, cold * 1.08) * step(0.002, cold);
	uv += (fr.g - fr.b) * 0.012 * frost;
	// хроматическая аберрация
	float ca = 0.0012 + fear * 0.0025 + interference * 0.004 + blur * 0.002;
	vec2 dir = c * ca * 2.0;
	vec3 col;
	col.r = texture(TEXTURE, uv + dir).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - dir).b;
	if (blur > 0.001) {
		vec2 px = blur * 3.0 / src_size;
		vec3 b = texture(TEXTURE, uv + vec2(px.x, px.y)).rgb + texture(TEXTURE, uv + vec2(-px.x, px.y)).rgb
			+ texture(TEXTURE, uv + vec2(px.x, -px.y)).rgb + texture(TEXTURE, uv + vec2(-px.x, -px.y)).rgb;
		col = mix(col, b * 0.25, clamp(blur * 1.2, 0.0, 1.0));
	}
	// халация: свет пробивает эмульсию и отражается от подложки — красно-рыжий ореол вокруг ярких огней
	if (halation > 0.001) {
		vec3 h = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236 + hash(vec2(tb, 9.0)) * 0.4;
			float rad = (i % 2 == 0) ? 3.5 : 8.0;
			vec3 s = texture(TEXTURE, uv + vec2(cos(a), sin(a)) * rad / src_size).rgb;
			float w = (i % 2 == 0) ? 1.0 : 0.6;
			h += max(s - vec3(0.62), vec3(0.0)) * w;
			wsum += w;
		}
		h /= wsum;
		float hl = luma(h);
		col += vec3(1.0, 0.36, 0.14) * hl * 2.4 * halation;
	}
	float l = luma(col);
	// проявка с сохранением серебра: цвета выцветают, контраст в средних тонах растёт
	vec3 bb = mix(2.0 * col * l, 1.0 - 2.0 * (1.0 - col) * (1.0 - l), step(0.5, l));
	col = mix(col, bb, 0.26);
	l = luma(col);
	col = mix(col, vec3(l), 0.3 + fear * 0.35);
	// тёплое остаётся тёплым: огни, окна, флажки не теряют цвет полностью; зелёный блеск глаз — тоже
	float warm = clamp((col.r - col.b) * 2.2, 0.0, 1.0);
	float eyeg = clamp((col.g - max(col.r, col.b)) * 3.0, 0.0, 1.0);
	col = mix(col, col * vec3(1.06, 0.98, 0.9), warm * 0.5);
	col = mix(col, col * vec3(0.8, 1.1, 0.7), eyeg);
	// раздельное тонирование: тени — сизые, свет — чуть тёплый; чёрное проваливается
	col += vec3(-0.006, 0.002, 0.012) * (1.0 - smoothstep(0.0, 0.35, l));
	col *= mix(vec3(1.0), vec3(1.03, 1.0, 0.95), smoothstep(0.45, 1.0, l));
	col = max(col - 0.006, vec3(0.0)) * 1.02;
	col = col / (1.0 + col * 0.06);
	// мерцание экспозиции от кадра к кадру
	col *= 1.0 + (hash(vec2(tb, 3.1)) - 0.5) * 0.035 * fk;
	// изморозь
	vec3 ice = mix(vec3(0.50, 0.62, 0.78), vec3(0.92, 0.96, 1.0), fr.g);
	col = mix(col, ice * (0.10 + l * 0.75 + fr.g * 0.22), frost * (0.5 + 0.45 * fr.g));
	// виньетка (у плёночной камеры — овальная, глубокая) и пульс страха
	float vg = smoothstep(1.08 - fear * 0.32 - pulse * fear * 0.08, 0.38 - fear * 0.2, r);
	col *= mix(1.0, vg, 0.78);
	col = mix(col, col * vec3(1.25, 0.25, 0.2) + vec3(0.12, 0.0, 0.0), red);
	// пыль на плёнке: на каждом кадре до трёх редких тёмных пылинок разной формы
	vec2 sp = UV * src_size;
	float dust = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 dp = vec2(hash(vec2(tb, float(i) * 7.1)), hash(vec2(tb + 0.3, float(i) * 3.7))) * src_size;
		float rr = 0.6 + 1.6 * hash(vec2(tb, float(i) + 11.0));
		float on = step(0.55, hash(vec2(tb, float(i) + 21.0)));
		dust += on * (1.0 - smoothstep(rr * 0.4, rr, length((sp - dp) * vec2(1.0, 0.8 + hash(vec2(float(i), tb))))));
	}
	col *= 1.0 - clamp(dust, 0.0, 1.0) * 0.7 * fk;
	// царапина: тонкая светлая вертикаль держится несколько кадров и чуть гуляет
	float sb = floor(t * 1.7);
	float sx = hash(vec2(sb, 4.4)) * src_size.x + sin(t * 7.0) * 1.5;
	float scr = step(0.7, hash(vec2(sb, 8.8))) * (1.0 - smoothstep(0.0, 0.9, abs(sp.x - sx)));
	scr *= 0.5 + 0.5 * hash(vec2(floor(sp.y / 6.0), tb));
	col += scr * 0.08 * fk;
	// зерно: два масштаба зёрен, гуще в тенях и полутонах, почти нет в светах
	float g1 = hash(floor(uv * src_size) + vec2(tb * 17.0, tb * 31.0)) - 0.5;
	float g2 = hash(floor(uv * src_size * 0.5) + vec2(tb * 7.0, tb * 13.0)) - 0.5;
	float gm = (g1 * 0.65 + g2 * 0.55) * (0.04 + 0.07 * (1.0 - l) * (0.4 + l * 2.0));
	col += vec3(gm) * fk + vec3(gm * 0.12, 0.0, -gm * 0.12) * fk;
	if (interference > 0.001) {
		float sn = hash(floor(uv * src_size * 0.5) + tb * 3.0);
		col = mix(col, vec3(sn), interference * 0.18);
	}
	col = mix(col, vec3(1.0), flash);
	col *= 1.0 - dark;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
