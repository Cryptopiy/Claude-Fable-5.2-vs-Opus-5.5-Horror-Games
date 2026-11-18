shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Метель: экранные слои. Один квад во весь кадр (его ставит snow_screen.gd) рисует снег процедурно.
//  * Хлопья живут в трёх решётках мира — ближняя, средняя и дальняя полосы глубины; каждая решётка повёрнута
//    по-своему, чтобы ряды не читались. Луч пикселя проходит решётку по ячейкам (DDA), в ячейке — не больше одной
//    снежинки со своим размером, яркостью, скоростью и завитком турбулентности. Снежинка целиком лежит внутри
//    своей ячейки (поля m), поэтому её пятно никогда не обрезается. Параллакс и снос ветром честные, как у частиц:
//    снос (off_*) копится в осях самой решётки и оборачивается на её период — узор при обёртке не прыгает.
//  * Ближние снежинки — мягкие диски расфокуса (объектив наведён на 3,5 м), средние — короткие мягкие штрихи
//    (смаз за выдержку 1/96 с, длина мягко ограничена, концы мягче середины — шторка открывается не мгновенно),
//    дальние — мелкая мерцающая пыль, тонущая в тумане.
//  * Завесы несомого снега — четыре среза мягкого шума, бегущего по ветру; в порыв — плотные стены по ветру.
//  * Позёмка — тонкий слой у наста (высота наста — та же функция, что у земли); интеграл по лучу аналитический.
// Свет посчитан так же, как его считает движок для настоящих ламп игрока (квад во весь кадр не может взять light()
// в точке снежинки): налобный фонарь — конус SpotLight3D, пятно tex/cookie.png (оно в sRGB — переводим в линейный
// свет, как движок) и затухание с дальностью; подсветка у лица и фальшфейер — OmniLight3D; плюс рассеянный свет
// окружения. Без этих ламп снега не видно. Снег закрыт глубиной сцены и не рисуется в коробках помещений.

#include "res://src/shaders/snowfield.gdshaderinc"   // g_noise, g_wind, snow_mask(), snow_h() — высота наста

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
global uniform float g_gust;

uniform int box_n = 0;
uniform vec3 box_min[12];
uniform vec3 box_max[12];

uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_e = 0.0;                     // энергия фонаря сейчас (13 — полная), 0 — не светит
uniform vec3 lamp_col = vec3(1.0, 0.85, 0.6);   // цвет фонаря, линейный
uniform vec2 lamp_att = vec2(0.037, 0.72);      // 1/дальность, показатель затухания (как у SpotLight3D)
uniform float fill_e = 0.0;                     // подсветка у лица (OmniLight3D в голове, цвет как у фонаря)
uniform vec2 fill_att = vec2(0.25, 1.6);
uniform float flare_e = 0.0;                    // фальшфейер в руке
uniform vec3 flare_pos = vec3(0.0);
uniform vec3 flare_col = vec3(1.0, 0.018, 0.005);
uniform vec2 flare_att = vec2(0.059, 1.1);
uniform vec3 amb_col = vec3(0.009, 0.016, 0.035); // рассеянный свет окружения (линейный цвет × энергия)
uniform vec3 wind_vel = vec3(5.6, -1.1, 5.6);    // скорость снега, м/с (мир)
uniform vec3 cam_vel = vec3(0.0);                // скорость камеры, м/с (мир) — для смаза
uniform float wind_speed = 8.0;
uniform vec3 off_n = vec3(0.0);                  // снос решёток ветром (м) в осях каждой решётки, обёрнут на 256 ячеек
uniform vec3 off_m = vec3(0.0);
uniform vec3 off_f = vec3(0.0);
uniform vec3 cells = vec3(0.4, 0.45, 0.7);       // размер ячеек решёток (м): ближняя, средняя, дальняя
uniform float dens = 1.0;                        // 0..1 плотность хлопьев от силы пурги
uniform float fx = 1.0;                          // 1 — полные эффекты (дальняя пыль, завесы)
uniform float fog_begin = 1.0;
uniform float fog_end = 14.0;
uniform float fog_curve = 0.75;
uniform float veil_u = 0.0;                      // снос завес вдоль ветра (м), обёрнут на 25 м
uniform float drift_u = 0.0;                     // снос позёмки вдоль ветра (м), обёрнут на 100 м
uniform vec2 band_ph = vec2(0.0);                // фазы волн порыва (копятся в snow_screen.gd: без скачков, когда меняется сила)
uniform float veil_k = 0.02;
uniform float drift_k = 0.15;
uniform float storm = 0.6;                       // сила пурги 0..1
uniform float gain = 1.0;

const float PXR = 1.1;        // минимальный радиус снежинки, пикселей: мягкая даже после растяжения кадра
const float AP = 0.012;       // «диафрагма»: радиус кружка нерезкости = AP · |1/t − 1/FOCUS| (в тангенсах угла)
const float FOCUS = 3.5;
const float SHUTTER = 0.0104; // выдержка, с
const float TURB = 0.18;      // доля скорости ветра в завитках турбулентности
const float WOB = 0.03;       // завиток положения снежинки, доля ячейки по каждой оси
const float KR = 2.5;         // мягкий предел полудлины штриха: KR·R + KPX пикселей
const float KRB = 0.3;        // у дисков расфокуса — почти круглые
const float KPX = 4.0;
const float KF = 0.6;         // нижняя граница «покрытия» мелкой снежинки (иначе дальняя пыль пропадает)
const float KST = 0.8;        // штрих растягивает тот же свет на большую длину
const float BK_FLAT = 0.25;   // плоская середина диска расфокуса
const float TAPER = 0.6;      // концы штриха мягче середины
const float AMB_K = 3.0;

// повёрнутые решётки: мир → решётка (те же матрицы — в snow_screen.gd, по ним копится снос)
const mat3 ROT_N = mat3(vec3(0.95534, 0.14168, 0.25934), vec3(0.0, 0.87758, -0.47943), vec3(-0.29552, 0.45801, 0.83839));
const mat3 ROT_M = mat3(vec3(0.16997, 0.77193, 0.61257), vec3(0.0, 0.62161, -0.78333), vec3(-0.98545, 0.13314, 0.10565));
const mat3 ROT_F = mat3(vec3(-0.58850, 0.77903, 0.21627), vec3(0.0, 0.26750, -0.96356), vec3(-0.80850, -0.56706, -0.15742));

uvec3 pcg3d(uvec3 v) {
	v = v * uvec3(1664525u) + uvec3(1013904223u);
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v = v ^ (v >> uvec3(16u));
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return v;
}

float fog_k(float t) {
	return 1.0 - pow(smoothstep(fog_begin, fog_end, t), fog_curve);
}

// затухание точечного света — как в движке (get_omni_attenuation): окно дальности × d^−decay; ra = (1/дальность, decay)
float light_att(float d, vec2 ra) {
	float nd = d * ra.x;
	nd *= nd;
	nd *= nd;
	nd = max(1.0 - nd, 0.0);
	return nd * nd * pow(max(d, 0.0001), -ra.y);
}

// порыв идёт волнами: полосы плотного снега бегут по ветру (как в базовой метели)
float gust_band(vec2 xz) {
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	vec2 pd = vec2(-wd.y, wd.x);
	float ph = dot(xz, wd) * 0.42 - band_ph.x + 2.2 * sin(dot(xz, pd) * 0.11 + band_ph.y);
	return smoothstep(-0.35, 0.75, sin(ph));
}

// Одна полоса глубины [ta, tb]: луч идёт по ячейкам решётки. Возвращает x — свет цвета фонаря (фонарь с конусом
// и подсветка у лица), y — рассеянный, z — свет фальшфейера. amb_k — доля рассеянного, sec — 1: подсветка и фальшфейер.
vec3 flakes(vec3 ro, vec3 rd, mat3 rot, vec3 off, float c, float ta, float tb, float fin, float fout,
		float t_lo, float t_hi, float p, float smin, float smax, float m, float hmax, uint seed, int steps,
		float px, float lamp_i, float amb_k, float sec) {
	vec3 acc = vec3(0.0);
	float t0 = max(ta, t_lo);
	float t1 = min(tb, t_hi);
	if (t1 <= t0) {
		return acc;
	}
	vec3 rol = rot * ro - off;
	vec3 rdl = rot * rd;
	vec3 wl = rot * wind_vel;
	vec3 cl = rot * cam_vel;
	float ic = 1.0 / c;
	vec3 q = rol * ic + rdl * (t0 * ic);
	vec3 cell = floor(q);
	vec3 sg = step(vec3(0.0), rdl) * 2.0 - 1.0;
	vec3 ird = 1.0 / max(abs(rdl), vec3(1e-5));
	vec3 tn = (sg * (cell - q) + max(sg, vec3(0.0))) * ird;
	float tend = (t1 - t0) * ic;
	float tmin = max(t_lo, 0.05);
	float pr2 = PXR * PXR * px * px;
	// запас ячейки, м: пятно и штрих снежинки дальше него не заходят (иначе соседняя ячейка срежет край)
	float mw = (m - WOB - 0.01) * c;
	float wr = 1.75 * WOB * c;    // наибольший сдвиг завитком, м
	for (int i = 0; i < steps; i++) {
		uvec3 h = pcg3d(uvec3(mod(cell, 256.0)) + uvec3(seed));
		vec3 rp = vec3(h >> uvec3(16u)) * (1.0 / 65536.0);
		vec3 ra = vec3(h & uvec3(65535u)) * (1.0 / 65536.0);
		vec3 x = (cell + m + rp * (1.0 - 2.0 * m)) * c - rol;
		float tf = dot(x, rdl);
		if (tf > tmin && tf < t_hi) {
			// грубая проверка (с запасом на завиток): далеко от луча — дальше не считаем
			vec3 a = x / tf - rdl;
			float coc = AP * abs(1.0 / tf - 1.0 / FOCUS);
			float rs = smax / tf;
			float rmax = sqrt(rs * rs + coc * coc + pr2) * (1.0 + KR) + KPX * px + wr / tf;
			if (dot(a, a) < rmax * rmax) {
				vec3 fw = ro + rd * tf;
				float gb = g_gust > 0.001 ? gust_band(fw.xz) * 2.0 - 0.3 : 0.0;
				float pk = p * dens * (1.0 + g_gust * gb);
				float ex = clamp((pk - ra.x) * 14.0 + 0.5, 0.0, 1.0);
				if (ex > 0.0) {
					// завиток положения
					float ph = ra.z * 6.2832;
					x += (WOB * c) * vec3(sin(TIME * 1.9 + ph), sin(TIME * 1.3 + ph * 1.7), sin(TIME * 1.6 + ph * 2.9));
					tf = dot(x, rdl);
					a = x / tf - rdl;
					fw = ro + rd * tf;
					coc = AP * abs(1.0 / tf - 1.0 / FOCUS);
					uvec3 h2 = pcg3d(h ^ uvec3(1540483477u));
					vec3 r2 = vec3(h2 >> uvec3(16u)) * (1.0 / 65536.0);
					vec3 r3 = vec3(h2 & uvec3(65535u)) * (1.0 / 65536.0);
					// размер и расфокус
					float s = mix(smin, smax, ra.y * ra.y);
					float rpa = s / tf;
					float R = sqrt(rpa * rpa + coc * coc + pr2);
					float bk = clamp(coc / R, 0.0, 1.0);
					// смаз: у каждой снежинки своя скорость и свой завиток турбулентности
					float spd = 0.6 + 0.8 * r2.x;
					vec3 vt = wind_speed * TURB * vec3(sin(TIME * 1.7 + r2.z * 6.2832 + fw.x * 0.35),
						0.6 * sin(TIME * 1.3 + r3.x * 6.2832 + fw.z * 0.3), sin(TIME * 2.1 + ph * 2.0 + fw.y * 0.5));
					vec3 v = wl * spd - cl + vt;
					vec3 vp = v - rdl * dot(v, rdl);
					vec3 hs = vp * (SHUTTER * 0.5 / tf);
					float hl = length(hs);
					float cap = min(hmax / tf, (KR * (1.0 - bk) + KRB * bk) * R + KPX * px * (1.0 - bk));
					cap = max(min(cap, mw / tf - R), 1e-6);
					float hl2 = hl / sqrt(1.0 + (hl / cap) * (hl / cap));
					hs *= hl2 / max(hl, 1e-9);
					// расстояние от пикселя до отрезка смаза (в тангенсах угла)
					vec3 pa = hs - a;
					vec3 ba = 2.0 * hs;
					float hh = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-14), 0.0, 1.0);
					float d = length(pa - ba * hh);
					float pr = 1.0 - smoothstep(BK_FLAT * bk, 1.0, d / R);
					pr = pr * pr * (3.0 - 2.0 * pr);
					pr *= 1.0 - TAPER * smoothstep(0.35, 1.0, abs(2.0 * hh - 1.0));
					// свет снежинки растекается по пятну расфокуса и по штриху
					float cov = min((rpa * rpa + KF * px * px) / (R * R), 1.0) / (1.0 + KST * hl2 / R);
					float wb = smoothstep(ta, ta + fin, tf) * (1.0 - smoothstep(tb - fout, tb, tf));
					float soft = clamp((t_hi - tf) * 4.0, 0.0, 1.0) * clamp((tf - t_lo) * 10.0, 0.0, 1.0);
					float tw = 0.75 + 0.25 * sin(TIME * (3.0 + 6.0 * ra.x) + ph * 3.0);
					float br = (0.35 + 0.65 * r2.y * sqrt(r2.y)) * tw;
					float w = pr * ex * wb * soft * cov * br * fog_k(tf);
					if (w > 0.0) {
						float lt = lamp_i * light_att(tf, lamp_att);
						float lf = 0.0;
						if (sec > 0.5) {
							lt += fill_e * light_att(tf, fill_att);
							if (flare_e > 0.001) {
								lf = flare_e * light_att(length(fw - flare_pos), flare_att);
							}
						}
						acc += w * vec3(lt, amb_k, lf);
					}
				}
			}
		}
		// следующая ячейка по лучу
		float tm = min(min(tn.x, tn.y), tn.z);
		if (tm > tend) {
			break;
		}
		vec3 msk = step(tn, tn.yzx) * step(tn, tn.zxy);
		cell += msk * sg;
		tn += msk * ird;
	}
	return acc;
}

// Срез завесы на глубине t толщиной dk.
float veil_at(vec3 ro, vec3 rd, float t, float dk, float t_lo, float t_hi, vec2 wd, vec2 pd) {
	float tc = min(t, t_hi);
	vec3 s = ro + rd * tc;
	float u = dot(s.xz, wd) - veil_u;
	float v = dot(s.xz, pd);
	float n1 = textureLod(g_noise, vec2(u * 0.08, v * 0.15 + s.y * 0.12), 0.0).r;
	float n2 = textureLod(g_noise, vec2(u * 0.16 + 0.3, (v + s.y * 0.8) * 0.28), 0.0).g;
	float dv = smoothstep(0.35, 0.9, n1 * 0.6 + n2 * 0.55);
	dv *= (0.4 + 0.6 * storm) * (1.0 + g_gust * (gust_band(s.xz) * 2.0 - 0.4));
	float w = clamp((t_hi - t) / dk + 0.5, 0.0, 1.0) * clamp((t - t_lo) / dk + 0.5, 0.0, 1.0);
	return dv * dk * light_att(max(tc, 0.3), lamp_att) * fog_k(tc) * w;
}

// Позёмка: экспоненциальный слой у наста (высота 0,16 м) над настом под точкой сцены.
float drift_layer(vec3 ro, vec3 rd, float t_lo, float t_hi, vec2 wd, vec2 pd) {
	vec3 hp = ro + rd * t_hi;
	// луч вверх или точка сцены выше метра (стена, небо) — слой у наста луч не задевает
	if (rd.y > -0.0005 || hp.y > 1.0) {
		return 0.0;
	}
	// наст под точкой — та же высота, что у земли; дальняя плоскость земли плоская, поэтому не выше самой точки
	float gy = min(snow_h(hp.xz, snow_mask(hp.xz)), hp.y);
	float hs = 0.16;
	float ry = min(rd.y, -0.03);
	float y0 = max(ro.y + rd.y * t_lo - gy, 0.0);
	float y1 = max(hp.y - gy, 0.0);
	float od = hs / (-ry) * (exp(-y1 / hs) - exp(-y0 / hs));
	od = clamp(od, 0.0, 1.2 * exp(-y1 / hs));
	if (od < 0.0005) {
		return 0.0;
	}
	float ts = clamp(t_hi - 0.12 / (-ry), min(t_lo, 14.0), min(t_hi, 14.0));
	// шум — на плоскости над настом (не на стене: иначе полосы встанут вертикально)
	float tg = clamp((gy + 0.08 - ro.y) / ry, 0.0, 30.0);
	vec2 s = ro.xz + rd.xz * tg;
	float u = dot(s, wd) - drift_u;
	float v = dot(s, pd);
	float n = textureLod(g_noise, vec2(u * 0.07, v * 0.4), 0.0).g;
	float n2 = textureLod(g_noise, vec2(u * 0.18 + 0.5, v * 0.9 + 0.2), 0.0).r;
	float dd = smoothstep(0.3, 0.95, n * 0.7 + n2 * 0.45);
	return dd * od * light_att(max(ts, 0.3), lamp_att) * fog_k(ts);
}

void vertex() {
	// квад 2×2 закрывает весь кадр у ближней плоскости
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	float raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sp = INV_PROJECTION_MATRIX * vec4(ndc, raw, 1.0);
	vec3 spos = sp.xyz / sp.w;
	vec4 np4 = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	vec3 vdir = normalize(np4.xyz / np4.w);
	vec3 ro = INV_VIEW_MATRIX[3].xyz;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * vdir);
	float t_lo = 0.0;
	float t_hi = min(length(spos), 400.0);
	// помещения: камера внутри коробки — снег только за её стенами; коробка впереди — за ней снега нет
	vec3 sgn = step(vec3(0.0), rd) * 2.0 - 1.0;
	vec3 inv = sgn / max(abs(rd), vec3(1e-6));
	for (int i = 0; i < box_n; i++) {
		vec3 b0 = (box_min[i] - ro) * inv;
		vec3 b1 = (box_max[i] - ro) * inv;
		vec3 bs = min(b0, b1);
		vec3 bb = max(b0, b1);
		float tin = max(max(bs.x, bs.y), bs.z);
		float tout = min(min(bb.x, bb.y), bb.z);
		if (tout > max(tin, 0.0)) {
			if (tin <= 0.0) {
				t_lo = max(t_lo, tout);
			} else {
				t_hi = min(t_hi, tin);
			}
		}
	}
	if (t_hi <= t_lo + 0.05) {
		discard;
	}
	// фонарь: конус SpotLight3D (43°, мягкость 0,5) × пятно и кольца отражателя (tools/make_tex.py t_cookie)
	float lamp_i = 0.0;
	vec3 ld = normalize(lamp_dir);
	float cs = dot(rd, ld);
	if (lamp_e > 0.001 && cs > 0.7314) {
		float rim = max(1e-4, (1.0 - cs) / 0.2686);
		float rr = sqrt(max(1.0 - cs * cs, 0.0)) / cs / 0.9325;
		float q1 = rr / 0.34;
		float q2 = (rr - 0.62) / 0.05;
		float q3 = (rr - 0.8) / 0.04;
		float ck = 0.75 * exp(-q1 * q1) + 0.42 * pow(max(1.0 - rr, 0.0), 0.9) + 0.06 * exp(-q2 * q2) + 0.03 * exp(-q3 * q3);
		ck *= clamp((1.0 - rr) / 0.12, 0.0, 1.0) / 1.17;
		// пятно лежит в cookie.png в sRGB, движок читает его в линейный свет — иначе края луча на снегу ярче, чем на стенах
		ck = ck <= 0.04045 ? ck / 12.92 : pow((ck + 0.055) / 1.055, 2.4);
		lamp_i = lamp_e * (1.0 - sqrt(rim)) * ck;
	}
	float px = 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	vec3 acc = vec3(0.0);
	if (dens > 0.005) {
		// ближняя полоса: диски расфокуса и крупные хлопья — в луче, в подсветке у лица, у фальшфейера и в рассеянном свете
		acc += flakes(ro, rd, ROT_N, off_n, cells.x, 0.12, 2.3, 0.28, 0.4, t_lo, t_hi,
			0.65, 0.0012, 0.0032, 0.22, 0.06, 17u, 12, px, lamp_i, AMB_K, 1.0);
		// средняя и дальняя — только в луче и только его светом: вне луча их не видно, а граница луча мягкая
		if (lamp_i > 0.002) {
			if (fx > 0.5) {
				acc += flakes(ro, rd, ROT_M, off_m, cells.y, 1.9, 7.0, 0.4, 0.8, t_lo, t_hi,
					0.9, 0.001, 0.0028, 0.24, 0.07, 4099u, 24, px, lamp_i, 0.0, 0.0);
				acc += flakes(ro, rd, ROT_F, off_f, cells.z, 6.2, 15.0, 0.8, 2.0, t_lo, t_hi,
					1.0, 0.002, 0.005, 0.22, 0.09, 9001u, 24, px, lamp_i, 0.0, 0.0);
			} else {
				acc += flakes(ro, rd, ROT_M, off_m, cells.y, 1.9, 9.0, 0.4, 1.2, t_lo, t_hi,
					0.9, 0.001, 0.0028, 0.24, 0.07, 4099u, 30, px, lamp_i, 0.0, 0.0);
			}
		}
	}
	vec3 col = acc.x * lamp_col + acc.y * amb_col + acc.z * flare_col;
	if (lamp_i > 0.002) {
		vec2 wd = normalize(g_wind.xy + vec2(0.0001));
		vec2 pd = vec2(-wd.y, wd.x);
		float lit = 0.0;
		if (fx > 0.5 && veil_k > 0.0001) {
			lit += veil_k * (veil_at(ro, rd, 2.0, 1.6, t_lo, t_hi, wd, pd) + veil_at(ro, rd, 3.8, 2.0, t_lo, t_hi, wd, pd)
				+ veil_at(ro, rd, 6.0, 2.4, t_lo, t_hi, wd, pd) + veil_at(ro, rd, 9.0, 3.0, t_lo, t_hi, wd, pd));
		}
		if (drift_k > 0.0001) {
			lit += drift_k * drift_layer(ro, rd, t_lo, t_hi, wd, pd);
		}
		col += lit * lamp_i * lamp_col;
	}
	ALBEDO = col * gain;
	ALPHA = 1.0;
}
