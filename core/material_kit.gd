class_name MaterialKit
extends RefCounted
## One kit of restrained, metre-scaled surfaces (EVAL-B04).
##
## VIS-004 gave the churches and castles a stone course and a roof tile; the
## house kept its own plaster-and-slate roof. Everything else in the world --
## courtyard houses, timber halls, pagodas, tulou, hammams, hans, mosques,
## stupas, the temples, bridges and trees -- was handed a flat colour. A
## building is made of something and the eye should be able to tell what, so
## the surfaces live here, one named function per material, and every
## assembler asks for them by name.
##
## THE CONTRACT. Every surface works in METRES. A pattern is a function of a
## point on the face measured in metres, which is exactly what VIS-003's
## `MeshKit._project_uv` hands a metric emitter: U runs along the face's
## horizontal (the eave, the course), V climbs it. An emitter that has no
## metric UVs (the house builder, the pagoda, the tulou, the timber hall, the
## bridge, the tree) does not need them: `metric()` below rebuilds the very
## same chart from the model-space position and normal, in the shader, so no
## vertex of any building moves and a house stays byte-identical. A revolved
## solid that DOES carry arc-length UVs (the stupa dome) passes `metric_uv =
## true` and the shader reads them as they are.
##
## Headless builds get a plain `StandardMaterial3D` of the same colour: the
## dummy renderer has no shader instances, and the massing harness does not
## look at one.
##
## The church and castle stone course, the church roof tile and the house roof
## course are the original VIS-004 / house shaders moved here unchanged, so
## `ShellAssembler` calls them and the portraits do not move.

static var _shaders: Dictionary = {}


static func live() -> bool:
	return DisplayServer.get_name() != "headless"


# ---------------------------------------------------------------- shared head

const HEAD := """shader_type spatial;
render_mode cull_disabled;
varying vec3 mpos;
varying vec3 mnrm;
uniform vec4 base_colour : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform bool use_uv = false;
uniform bool vertex_tint = false;

void vertex() {
	mpos = VERTEX;
	mnrm = NORMAL;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// MeshKit._surface_uv_axes / _project_uv, in the shader: U along the face's
// horizontal, V climbing it, both in metres.
vec2 metric(vec2 uv) {
	if (use_uv) {
		return uv;
	}
	vec3 n = normalize(mnrm);
	vec3 u = cross(vec3(0.0, 1.0, 0.0), n);
	if (dot(u, u) < 0.001) {
		u = vec3(1.0, 0.0, 0.0);
	} else {
		u = normalize(u);
	}
	vec3 v = normalize(cross(n, u));
	return vec2(dot(mpos, u), dot(mpos, v));
}

// 0 on a joint, 1 on the face; fades to the mean when the pattern is too fine
// for the pixel, so a distant wall is a tone and not a moire.
float joint(vec2 e, vec2 fw, float w) {
	float a = smoothstep(w, w + 0.03 + fw.x, e.x) * smoothstep(w, w + 0.03 + fw.y, e.y);
	float fade = clamp((max(fw.x, fw.y) - 0.35) * 2.0, 0.0, 1.0);
	return mix(a, 1.0 - w * 1.6, fade);
}

// A wall that is also a floor. HouseBuilder puts a stone ground storey in the
// FLOOR surface, so one slot holds both a wall and the paving beside it; where
// `floor_colour` has alpha, a face that looks up is paved (flags, or a glazed
// two-colour tile with `floor_checker`) and the red-marked vertices are rugs.
uniform vec4 floor_colour : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 floor_alt : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform vec4 rug_colour : source_color = vec4(0.44, 0.24, 0.22, 1.0);
uniform float floor_tile = 0.45;
uniform float floor_checker = 0.0;
// a rectangle of the paving (x0, z0, x1, z1) laid as small glazed tile instead
uniform vec4 court_rect = vec4(0.0);
uniform vec4 court_a : source_color = vec4(0.18, 0.5, 0.52, 1.0);
uniform vec4 court_b : source_color = vec4(0.9, 0.87, 0.78, 1.0);

bool paved(vec3 n) {
	return floor_colour.a > 0.5 && n.y > 0.85;
}

vec3 paving_albedo(vec2 q, vec2 uv, vec3 vcol) {
	if (court_rect.z > court_rect.x && vcol.r > 0.5 && mpos.x > court_rect.x && mpos.x < court_rect.z
			&& mpos.z > court_rect.y && mpos.z < court_rect.w) {
		vec2 t = mpos.xz / 0.3;
		float cchk = mod(floor(t.x) + floor(t.y), 2.0);
		float cg = joint(fract(t), fwidth(t), 0.05);
		vec3 cc = mix(court_a.rgb, court_b.rgb, cchk) * (0.93 + 0.12 * hash21(floor(t)));
		return mix(court_a.rgb * 0.5, cc, cg);
	}
	vec2 p = q / floor_tile;
	vec2 id = floor(p);
	float chk = mod(id.x + id.y, 2.0);
	float g = joint(fract(p), fwidth(p), 0.045);
	vec3 c = mix(floor_colour.rgb, floor_alt.rgb, chk * floor_checker) * (0.92 + 0.14 * hash21(id));
	c = mix(floor_colour.rgb * 0.62, c, g);
	if (vcol.r < 0.5) {
		vec2 edge = min(uv, vec2(1.0) - uv);
		float border = step(0.055, min(edge.x, edge.y)) * (1.0 - step(0.09, min(edge.x, edge.y)));
		float weave = 0.96 + 0.04 * sin(uv.x * 540.0) * sin(uv.y * 540.0);
		c = mix(rug_colour.rgb, vec3(0.72, 0.56, 0.30), border * 0.85) * weave;
	}
	return c;
}
"""


# ----------------------------------------------------------------- the bodies

const ASHLAR := """
uniform vec2 block = vec2(1.1, 0.46);
uniform float joint_w = 0.045;
uniform float jitter = 0.05;
uniform float stagger = 0.37;
uniform float coping = 0.0;
uniform vec4 inlay_rect = vec4(0.0);
uniform vec4 inlay_a : source_color = vec4(0.2, 0.45, 0.5, 1.0);
uniform vec4 inlay_b : source_color = vec4(0.88, 0.84, 0.72, 1.0);
void fragment() {
	vec3 n = normalize(mnrm);
	vec2 q = metric(UV);
	vec2 p = q / block;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5 + hash21(vec2(row, 3.1)) * stagger;
	vec2 cell = floor(p);
	float j = joint(fract(p), fwidth(p), joint_w);
	float v = hash21(cell + vec2(1.7, 9.2));
	float rv = hash21(vec2(row, 7.7));
	vec3 c = base_colour.rgb * (1.0 + (v - 0.5) * 2.0 * jitter + (rv - 0.5) * jitter);
	c *= 0.95 + 0.10 * vnoise(q * 5.0);
	vec3 col = mix(base_colour.rgb * 0.74, c, j);
	if (coping > 0.5 && n.y > 0.9) {
		vec2 cp = vec2(q.x / 1.3, q.y / 5.0);
		float cj = joint(fract(cp), fwidth(cp), 0.012);
		col = mix(base_colour.rgb * 0.7, base_colour.rgb * (1.07 + 0.05 * hash21(floor(cp))), cj);
	}
	if (inlay_rect.z > inlay_rect.x && n.y > 0.9 && mpos.x > inlay_rect.x && mpos.x < inlay_rect.z
			&& mpos.z > inlay_rect.y && mpos.z < inlay_rect.w) {
		vec2 t = mpos.xz / 0.45;
		float chk = mod(floor(t.x) + floor(t.y), 2.0);
		float g = joint(fract(t), fwidth(t), 0.045);
		col = mix(inlay_a.rgb, inlay_b.rgb, chk) * (0.93 + 0.12 * hash21(floor(t))) * mix(0.7, 1.0, g);
	}
	ALBEDO = col;
	ROUGHNESS = 0.94;
	if (paved(n)) {
		ALBEDO = paving_albedo(q, UV, COLOR.rgb);
	}
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const RUBBLE := """
uniform vec2 stone = vec2(0.75, 0.46);
void fragment() {
	vec2 q = metric(UV);
	vec2 p = q / stone;
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id1 = ip;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(ip + g), hash21(ip + g + vec2(31.7, 17.3)));
			vec2 r = g + o * 0.8 + 0.1 - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id1 = ip + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	vec2 fw = fwidth(p);
	float w = max(fw.x, fw.y);
	float j2 = smoothstep(0.03, 0.15 + w, edge);
	j2 = mix(j2, 0.85, clamp((w - 0.35) * 2.0, 0.0, 1.0));
	float v = hash21(id1 + vec2(4.4, 2.2));
	vec3 c = base_colour.rgb * (0.88 + 0.24 * v) * (0.95 + 0.1 * vnoise(q * 4.0));
	ALBEDO = mix(base_colour.rgb * 0.6, c, j2);
	ROUGHNESS = 0.97;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const PLASTER := """
uniform float plinth_h = 0.0;
uniform vec4 plinth_colour : source_color = vec4(0.62, 0.6, 0.55, 1.0);
uniform vec4 frame_colour : source_color = vec4(0.2, 0.14, 0.1, 1.0);
uniform float frame_bay = 0.0;
uniform float frame_floor = 0.0;
uniform float frame_top = 10.0;
void fragment() {
	vec3 n = normalize(mnrm);
	vec2 q = metric(UV);
	float m = vnoise(q * 0.9) * 0.6 + vnoise(q * 3.7) * 0.4;
	float run = vnoise(vec2(q.x * 2.0, q.y * 0.12));
	vec3 c = base_colour.rgb * (0.92 + 0.14 * m) * (0.96 + 0.07 * run);
	float upright = step(abs(n.y), 0.5);
	float foot = smoothstep(0.0, 1.1, mpos.y);
	c *= mix(1.0, mix(0.84, 1.0, foot), upright);
	if (plinth_h > 0.0 && upright > 0.5 && mpos.y < plinth_h) {
		vec2 pp = q / vec2(0.9, plinth_h * 0.5);
		float pj = joint(fract(pp), fwidth(pp), 0.03);
		c = mix(plinth_colour.rgb * 0.7, plinth_colour.rgb * (0.95 + 0.1 * hash21(floor(pp))), pj);
	}
	if (frame_bay > 0.0 && upright > 0.5) {
		float pe = abs(fract(q.x / frame_bay + 0.5) - 0.5) * frame_bay;
		float post = 1.0 - smoothstep(0.16, 0.19, pe);
		float rail = max(1.0 - smoothstep(0.52, 0.56, mpos.y - frame_floor),
			smoothstep(frame_top - 0.62, frame_top - 0.58, mpos.y));
		float tb = max(post, rail);
		float grain = 0.88 + 0.2 * vnoise(vec2(q.x * 30.0, q.y * 1.5));
		c = mix(c, frame_colour.rgb * grain, tb);
	}
	ALBEDO = c;
	ROUGHNESS = 0.96;
	if (paved(n)) {
		ALBEDO = paving_albedo(q, UV, COLOR.rgb);
	}
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const BRICK := """
uniform vec4 quoin_rect = vec4(0.0);
uniform vec4 quoin_colour : source_color = vec4(0.8, 0.77, 0.7, 1.0);
uniform vec4 court_colour : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float quoin_w = 0.8;
uniform vec2 brick = vec2(0.34, 0.15);
uniform vec4 mortar : source_color = vec4(0.70, 0.66, 0.58, 1.0);
void fragment() {
	vec3 n = normalize(mnrm);
	vec2 q = metric(UV);
	vec2 p = q / brick;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 id = floor(p);
	float j = joint(fract(p), fwidth(p), 0.07);
	float v = hash21(id + vec2(2.1, 8.3));
	vec3 b = base_colour.rgb * (0.82 + 0.34 * v) * (0.94 + 0.1 * vnoise(q * 3.0));
	vec3 col = mix(mortar.rgb, b, j);
	if (quoin_rect.z > quoin_rect.x && abs(n.y) < 0.5) {
		bool xface = abs(n.x) > abs(n.z);
		float along = xface ? mpos.z : mpos.x;
		float plane = xface ? mpos.x : mpos.z;
		float lo = xface ? quoin_rect.y : quoin_rect.x;
		float hi = xface ? quoin_rect.w : quoin_rect.z;
		float p0 = xface ? quoin_rect.x : quoin_rect.y;
		float p1 = xface ? quoin_rect.z : quoin_rect.w;
		float outer = min(abs(plane - p0), abs(plane - p1));
		if (outer < 0.2) {
			float course = floor(mpos.y / 0.5);
			float w = quoin_w * (mod(course, 2.0) < 1.0 ? 1.0 : 0.6);
			float d = min(along - lo, hi - along);
			if (d < w && d > 0.0) {
				float ce = fract(mpos.y / 0.5);
				float ve = d / w;
				float qj = smoothstep(0.03, 0.08, ce) * smoothstep(0.0, 0.05, w - d);
				vec3 qc = quoin_colour.rgb * (0.94 + 0.12 * hash21(vec2(course, floor(along))));
				col = mix(quoin_colour.rgb * 0.7, qc, qj);
			}
		} else if (court_colour.a > 0.5) {
			float m = vnoise(q * 0.9) * 0.6 + vnoise(q * 3.7) * 0.4;
			col = court_colour.rgb * (0.92 + 0.14 * m);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	if (paved(n)) {
		ALBEDO = paving_albedo(q, UV, COLOR.rgb);
	}
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const TILE := """
uniform vec2 cell = vec2(0.3, 0.22);
uniform float rib = 0.0;
uniform float lap = 0.3;
uniform float jitter = 0.06;
uniform float joint_w = 0.04;
uniform float stagger = 0.5;
uniform float sheen = 0.0;
void fragment() {
	vec2 q = metric(UV);
	vec2 p = q / cell;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * stagger;
	vec2 id = floor(p);
	vec2 e = fract(p);
	float v = hash21(id + vec2(5.3, 1.1));
	vec2 fw = fwidth(p);
	float far = clamp((max(fw.x, fw.y) - 0.22) * 3.0, 0.0, 1.0);
	float ribs = mix(mix(1.0, 0.8 + 0.2 * cos(6.2831853 * e.x), rib), mix(1.0, 0.9, rib), far);
	float lapv = mix(mix(1.0 - lap, 1.0, smoothstep(0.0, 0.85, e.y)), 1.0 - lap * 0.45, far);
	float j = joint(e, fw, joint_w);
	vec3 c = base_colour.rgb * (1.0 + (v - 0.5) * 2.0 * jitter) * ribs * lapv;
	ALBEDO = mix(base_colour.rgb * 0.5, c, j);
	ROUGHNESS = mix(0.9, 0.5, sheen);
	METALLIC = 0.04;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const THATCH := """
void fragment() {
	vec2 q = metric(UV);
	vec2 p = q / vec2(0.5, 0.26);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	float tint = hash21(floor(p) + vec2(3.3, 7.1));
	float seam = smoothstep(0.02, 0.2, fract(p.y));
	float reed = 0.94 + 0.06 * sin(q.x * 90.0 + tint * 6.0);
	ALBEDO = base_colour.rgb * mix(0.6, 0.9 + tint * 0.18, seam) * reed;
	ROUGHNESS = 0.97;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const TIMBER := """
uniform float weather = 0.0;
uniform bool along = false;
uniform vec4 roof_colour : source_color = vec4(0.0, 0.0, 0.0, 0.0);
void fragment() {
	vec2 q = metric(UV);
	vec3 n = normalize(mnrm);
	if (roof_colour.a > 0.5 && n.y > 0.2 && n.y < 0.95) {
		// a pitched face of a timber structure is its shingle roof
		vec2 sp = q / vec2(0.17, 0.21);
		float srow = floor(sp.y);
		sp.x += mod(srow, 2.0) * 0.5;
		vec2 sid = floor(sp);
		vec2 se = fract(sp);
		float sj = joint(se, fwidth(sp), 0.05);
		float sv = hash21(sid + vec2(5.3, 1.1));
		vec3 sc = roof_colour.rgb * (1.0 + (sv - 0.5) * 0.22) * mix(0.58, 1.0, smoothstep(0.0, 0.85, se.y));
		ALBEDO = mix(roof_colour.rgb * 0.45, sc, sj);
		ROUGHNESS = 0.92;
		if (vertex_tint) {
			ALBEDO *= COLOR.rgb;
		}
	} else {
	if (along) {
		q = q.yx;
	}
	float id = floor(q.x / 0.22);
	float e = fract(q.x / 0.22);
	float gap = smoothstep(0.0, 0.07, e) * smoothstep(1.0, 0.93, e);
	float tone = hash21(vec2(id, 1.3));
	float grain = vnoise(vec2(q.x * 38.0 + id * 7.0, q.y * 1.6));
	vec3 c = base_colour.rgb * (0.84 + 0.28 * tone) * (0.9 + 0.18 * grain);
	float wear = weather * (0.45 + 0.55 * vnoise(q * 2.2));
	c = mix(c, vec3(0.48, 0.45, 0.41) * (0.8 + 0.4 * grain), wear);
	float butt = smoothstep(0.0, 0.012, abs(fract(q.y / 2.4 + tone) - 0.5));
	ALBEDO = c * mix(0.5, 1.0, gap) * mix(0.82, 1.0, butt);
	ROUGHNESS = mix(0.84, 0.95, weather);
	if (paved(n)) {
		ALBEDO = paving_albedo(q, UV, COLOR.rgb);
	}
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
	}
}
"""

const LEAD := """
void fragment() {
	vec2 q = metric(UV);
	float s = q.x / 0.62;
	float seam = 1.0 - smoothstep(0.0, 0.03 + fwidth(s), min(fract(s), 1.0 - fract(s)));
	float patina = vnoise(q * 0.6) * 0.5 + vnoise(q * 2.4) * 0.5;
	vec3 c = mix(base_colour.rgb * 0.88, base_colour.rgb * 1.08, patina);
	c = mix(c, vec3(0.42, 0.52, 0.48), 0.18 * patina);
	ALBEDO = c * mix(1.0, 0.72, seam * 0.8);
	ROUGHNESS = 0.55;
	METALLIC = 0.14;
}
"""

const WATER := """
void fragment() {
	vec2 q = metric(UV);
	float r = vnoise(q * vec2(0.45, 1.3)) * 0.6 + vnoise(q * vec2(1.7, 3.1)) * 0.4;
	vec3 c = base_colour.rgb * (0.82 + 0.34 * r);
	ALBEDO = c;
	ROUGHNESS = 0.07;
	METALLIC = 0.0;
	SPECULAR = 0.85;
}
"""

const EARTH := """
void fragment() {
	vec2 q = metric(UV);
	float lift = q.y / 0.55;
	float row = floor(lift);
	float e = fract(lift);
	float strata = 0.9 + 0.2 * hash21(vec2(row, 4.2));
	float line = 1.0 - 0.22 * (1.0 - smoothstep(0.0, 0.06, e)) * (0.4 + 0.6 * vnoise(vec2(q.x * 1.3, row)));
	float m = vnoise(q * 2.3) * 0.6 + vnoise(q * 11.0) * 0.4;
	float crack = 1.0 - 0.16 * smoothstep(0.93, 1.0, vnoise(vec2(q.x * 3.0 + row * 5.0, q.y * 0.35)));
	ALBEDO = base_colour.rgb * strata * line * (0.88 + 0.22 * m) * crack;
	ROUGHNESS = 0.99;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const ROCK := """
void fragment() {
	vec2 q = metric(UV);
	float bed = vnoise(vec2(q.x * 0.11, q.y * 1.1)) * 0.55 + vnoise(vec2(q.x * 0.5, q.y * 3.0)) * 0.25
		+ vnoise(q * 2.6) * 0.2;
	float crack = smoothstep(0.9, 1.0, vnoise(vec2(q.x * 0.8 + 3.0, q.y * 0.2)));
	ALBEDO = base_colour.rgb * (0.78 + 0.4 * bed) * (1.0 - 0.25 * crack);
	ROUGHNESS = 0.98;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const PAVING := """
void fragment() {
	vec2 q = metric(UV);
	ALBEDO = paving_albedo(q, UV, COLOR.rgb);
	ROUGHNESS = COLOR.r < 0.5 ? 0.94 : mix(0.9, 0.55, floor_checker);
}
"""

const BARK := """
void fragment() {
	vec2 q = metric(UV);
	float fissure = vnoise(vec2(q.x * 9.0, q.y * 0.6));
	float ridge = smoothstep(0.25, 0.7, fissure);
	float fine = vnoise(vec2(q.x * 26.0, q.y * 2.4));
	vec3 c = base_colour.rgb * (0.62 + 0.5 * ridge) * (0.92 + 0.16 * fine);
	ALBEDO = c;
	ROUGHNESS = 0.97;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const LEAF := """
uniform float lobe = 1.8;
void fragment() {
	vec3 lc = floor(mpos / lobe);
	float lv = hash21(lc.xy + vec2(lc.z * 17.1, lc.z * 5.3));
	float lw = hash21(lc.yz + vec2(lc.x * 3.7, 11.0));
	float dapple = vnoise(mpos.xz * 1.9 + vec2(mpos.y * 1.3, 0.0));
	vec3 c = base_colour.rgb * (0.80 + 0.34 * lv) * (0.9 + 0.2 * dapple);
	// a warmer, yellower lobe now and then, as a real crown has
	c = mix(c, c * vec3(1.14, 1.06, 0.78), lw * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
}
"""

const ROPE := """
void fragment() {
	float t = sin(dot(mpos, vec3(34.0, 9.0, 9.0)));
	vec3 c = base_colour.rgb * (0.82 + 0.2 * smoothstep(-0.5, 0.5, t));
	ALBEDO = c;
	ROUGHNESS = 0.96;
}
"""


# ---------------------------------------------------------- the legacy shaders
# VIS-004's church and castle stone and roof, and the house's roof course,
# moved here VERBATIM. They read the UV the emitter wrote and nothing else.

const CHURCH_STONE := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_colour : source_color;
uniform float block_width = 2.2;
uniform float course_height = 0.92;
void fragment() {
	vec2 p = UV / vec2(block_width, course_height);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 edge = fract(p);
	float joint = smoothstep(0.025, 0.075, edge.y) * smoothstep(0.025, 0.075, edge.x);
	vec2 cell = floor(p);
	float variation = fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453);
	vec3 block = stone_colour.rgb * mix(0.975, 1.025, variation);
	ALBEDO = mix(stone_colour.rgb * 0.88, block, joint);
	ROUGHNESS = 0.94;
}
"""

const CHURCH_ROOF := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 roof_colour : source_color;
uniform float tile_width = 1.45;
uniform float course_height = 0.76;
void fragment() {
	vec2 p = UV / vec2(tile_width, course_height);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 edge = fract(p);
	float tile = smoothstep(0.025, 0.08, edge.y) * smoothstep(0.025, 0.08, edge.x);
	vec2 cell = floor(p);
	float variation = fract(sin(dot(cell, vec2(39.346,11.135))) * 24634.6345);
	vec3 surface = roof_colour.rgb * mix(0.95, 1.025, variation);
	ALBEDO = mix(roof_colour.rgb * 0.84, surface, tile);
	ROUGHNESS = 0.88;
	METALLIC = 0.06;
}
"""

const HOUSE_ROOF := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 roof_colour : source_color;
uniform float course = 0.28;
uniform float tile_width = 0.36;
uniform bool thatch = false;
uniform bool witch_thatch = false;
void fragment() {
	vec2 p = UV / vec2(tile_width, course);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	float tint = fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453);
	vec2 edge = fract(p);
	float seam = smoothstep(0.015, 0.065, edge.y);
	if (!thatch) { seam *= smoothstep(0.015, 0.05, edge.x); }
	float reed = thatch ? 0.96 + 0.04 * sin(UV.x * 115.0) : 1.0;
	ALBEDO = roof_colour.rgb * mix(0.68, 0.91 + tint * 0.16, seam) * reed;
	ROUGHNESS = 0.94;
	if (witch_thatch) {
		// Roof UV.x follows the ridge and UV.y climbs the actual slope. Staggered
		// bundles cross the eave in short laps; fine variation runs down-slope
		// like individual reeds, rather than drawing rectangular tile courses.
		float lap_wave = UV.y + 0.028 * sin(UV.x * 3.7)
			+ 0.009 * sin(UV.x * 11.0 + UV.y * 1.8);
		float lap_phase = fract(lap_wave / 0.54);
		float lap_shadow = exp(-pow((lap_phase - 0.07) / 0.055, 2.0));
		float bundle_variation = 0.94 + 0.035 * sin(UV.x * 5.2 + 0.8 * sin(UV.y * 2.4))
			+ 0.018 * sin(UV.x * 15.7 + UV.y * 1.3);
		float fiber = 0.5 + 0.5 * sin(UV.x * 146.0
			+ sin(UV.y * 2.7 + sin(UV.x * 4.1) * 0.6) * 1.8);
		float fiber_body = mix(0.82, 1.07, fiber);
		float bundle_body = bundle_variation * fiber_body * (1.0 - 0.19 * lap_shadow);
		ALBEDO = roof_colour.rgb * bundle_body;
		ROUGHNESS = 0.99;
	}
	if (COLOR.r < 0.5) {
		ALBEDO = vec3(0.1529, 0.3372, 0.3763);
		ROUGHNESS = 0.22;
		METALLIC = 0.25;
	}
}
"""


## The church and castle masonry course. Same shader, same parameters.
static func church_stone(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _cached("church_stone", CHURCH_STONE)
	m.set_shader_parameter("stone_colour", colour)
	return m


static func church_roof(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _cached("church_roof", CHURCH_ROOF)
	m.set_shader_parameter("roof_colour", colour)
	return m


## The house roof course: slate, shingle or thatch, from the spec's colour.
static func house_roof(colour: Color, course: float, tile_width: float,
		thatch: bool, witch_thatch := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _cached("house_roof", HOUSE_ROOF)
	m.set_shader_parameter("roof_colour", colour)
	m.set_shader_parameter("course", course)
	m.set_shader_parameter("tile_width", tile_width)
	m.set_shader_parameter("thatch", thatch)
	m.set_shader_parameter("witch_thatch", thatch and witch_thatch)
	return m


# ------------------------------------------------------------------ the kit
## Every function below returns a `Material` ready for a surface slot, in the
## colour it is given. `metric_uv` is true only for a revolved solid whose UVs
## are already metres; `tint` is true for a mesh that carries its own vertex
## colour (the tree).

## Cut stone laid in courses. Block and course size are the mason's, in metres.
static func ashlar(colour: Color, metric_uv := false, block := Vector2(1.1, 0.46),
		extra := {}) -> Material:
	var p := {"block": block}
	p.merge(extra, true)
	return _make("ashlar", ASHLAR, colour, p, metric_uv)


## Warm sandstone: a larger block, a softer joint, a stronger course-to-course
## value change, the way bedded sandstone weathers.
static func sandstone(colour: Color, metric_uv := false) -> Material:
	return _make("ashlar", ASHLAR, colour, {"block": Vector2(1.4, 0.55),
		"joint_w": 0.03, "jitter": 0.09, "stagger": 0.6}, metric_uv)


## Uncoursed fieldstone: a Voronoi of irregular stones with dark mortar.
static func rubble(colour: Color, metric_uv := false) -> Material:
	return _make("rubble", RUBBLE, colour, {}, metric_uv)


## Lime plaster: a wash with slow mottling, damp at the foot. `extra` takes a
## stone `plinth_h`/`plinth_colour`, a half-timber frame (`frame_bay`,
## `frame_colour`, `frame_floor`, `frame_top`).
static func plaster(colour: Color, metric_uv := false, extra := {}) -> Material:
	return _make("plaster", PLASTER, colour, extra, metric_uv)


## Fired brick in stretcher bond with pale mortar. `quoin_rect` is the outer
## wall outline (x0, z0, x1, z1): the corners are dressed in `quoin_colour`
## stone and, if `court_colour` has alpha, the faces inside it are plastered.
static func brick(colour: Color, extra := {}, metric_uv := false) -> Material:
	return _make("brick", BRICK, colour, extra, metric_uv)


## Barrel tile: ribbed pan-and-cover courses, a warm value jitter.
static func terracotta(colour: Color, metric_uv := false) -> Material:
	return _make("tile", TILE, colour, {"cell": Vector2(0.26, 0.40), "rib": 1.0,
		"lap": 0.34, "jitter": 0.09, "joint_w": 0.02}, metric_uv)


## The grey roof tile of the east: narrow ribs, a faint glaze.
static func grey_tile(colour: Color, metric_uv := false) -> Material:
	return _make("tile", TILE, colour, {"cell": Vector2(0.20, 0.34), "rib": 1.0,
		"lap": 0.3, "jitter": 0.07, "joint_w": 0.02, "sheen": 0.35}, metric_uv)


## Flat slates, cool and a little uneven.
static func slate(colour: Color, metric_uv := false) -> Material:
	return _make("tile", TILE, colour, {"cell": Vector2(0.30, 0.22), "rib": 0.0,
		"lap": 0.22, "jitter": 0.08, "joint_w": 0.04, "sheen": 0.15}, metric_uv)


## Riven wooden shingles: narrow, overlapped, each course shaded at its foot.
static func shingle(colour: Color, metric_uv := false) -> Material:
	return _make("tile", TILE, colour, {"cell": Vector2(0.17, 0.21), "rib": 0.0,
		"lap": 0.42, "jitter": 0.11, "joint_w": 0.05}, metric_uv)


static func thatch(colour: Color, metric_uv := false) -> Material:
	return _make("thatch", THATCH, colour, {}, metric_uv)


## Boarded timber with grain. `weathered` greys it toward driftwood; `along`
## turns the boards to run along the face's U instead of up it (a deck); a
## `roof` colour with alpha makes the pitched faces shingles (a covered bridge).
static func timber(colour: Color, weathered := false, metric_uv := false,
		along := false, tint := false, roof := Color(0.0, 0.0, 0.0, 0.0),
		extra := {}) -> Material:
	var p := {"weather": 0.55 if weathered else 0.0, "along": along, "roof_colour": roof}
	p.merge(extra, true)
	return _make("timber", TIMBER, colour, p, metric_uv, tint)


## Sheet lead over a dome or flat: standing seams every 0.62 m, a faint patina.
static func lead(colour: Color = Color("68706f"), metric_uv := false) -> Material:
	return _make("lead", LEAD, colour, {}, metric_uv, false, 0.55, 0.14)


## Still water: deep, glossy, a slow ripple. Never a flat blue plate.
static func water(colour: Color = Color("3f5c63"), metric_uv := false) -> Material:
	return _make("water", WATER, colour, {}, metric_uv, false, 0.07, 0.0)


## Rammed earth in 0.55 m lifts with a hairline between each.
static func rammed_earth(colour: Color, metric_uv := false) -> Material:
	return _make("earth", EARTH, colour, {}, metric_uv)


## Native rock: bedding planes and the odd crack.
static func rock(colour: Color, metric_uv := false) -> Material:
	return _make("rock", ROCK, colour, {}, metric_uv)


## Whitewash over masonry: plaster, but pale and with no foot stain worth the
## name. A thin wrapper so a stupa asks for what it is.
static func whitewash(colour: Color = Color("e9e4d6"), metric_uv := false) -> Material:
	return _make("plaster", PLASTER, colour, {}, metric_uv)


## A floor: flagstones (`checker` 0) or a two-colour glazed tile (`checker` 1).
## Keeps the house floor's rug marker (vertex colour red below 0.5).
static func paving(colour: Color, alt := Color("d9d0b8"), tile := 0.45,
		checker := 0.0, rug := Color("703c38")) -> Material:
	var p := floored(colour, alt, tile, checker)
	p["rug_colour"] = rug
	return _make("floor", PAVING, colour, p, false)


## The `extra` that lays a rectangle of the paving (x0, z0, x1, z1 in model
## space) as small two-colour glazed tile: a riad's court inside plain flags.
static func tiled_court(rect: Rect2, a: Color, b: Color) -> Dictionary:
	return {"court_rect": Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y),
		"court_a": a, "court_b": b}


## The `extra` that turns a wall material into wall-and-floor: every face that
## looks up is paved in `colour` (flags) or `colour`/`alt` (glazed tile,
## `checker` 1). HouseBuilder emits a stone ground storey in the FLOOR slot, so
## that slot has to be both.
static func floored(colour: Color, alt := Color("d9d0b8"), tile := 0.45,
		checker := 0.0) -> Dictionary:
	return {"floor_colour": Color(colour.r, colour.g, colour.b, 1.0),
		"floor_alt": alt, "floor_tile": tile, "floor_checker": checker}


## Bark: vertical fissures. Reads the mesh's vertex colour, because the tree's
## own per-cell grain is vertex colour.
static func bark(colour: Color) -> Material:
	return _make("bark", BARK, colour, {}, false, true)


## Foliage with a little value variation per lobe (a 1.8 m cell) and dapple
## inside it.
static func leaf(colour: Color, lobe := 1.8) -> Material:
	return _make("leaf", LEAF, colour, {"lobe": lobe}, false, true, 0.82)


## Hemp rope: a diagonal lay.
static func rope(colour: Color = Color("8a7550")) -> Material:
	return _make("rope", ROPE, colour, {}, false)


# ------------------------------------------------------------------ plumbing

static func _cached(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]


static func _make(key: String, body: String, colour: Color, params: Dictionary,
		metric_uv := false, tint := false, roughness := 0.94,
		metallic := 0.0) -> Material:
	if not live():
		var flat := StandardMaterial3D.new()
		flat.albedo_color = colour
		flat.roughness = roughness
		flat.metallic = metallic
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flat.vertex_color_use_as_albedo = tint
		return flat
	var m := ShaderMaterial.new()
	m.shader = _cached(key, HEAD + body)
	m.set_shader_parameter("base_colour", colour)
	m.set_shader_parameter("use_uv", metric_uv)
	m.set_shader_parameter("vertex_tint", tint)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Put `materials` (indexed by the builder's logical surface) on `node`. A
## surface named `material_slot:N` is surface N whatever its position; a null
## entry leaves the slot as the caller set it.
static func apply(node: MeshInstance3D, materials: Array) -> void:
	if node.mesh == null:
		return
	for i in range(node.mesh.get_surface_count()):
		var slot := i
		if node.mesh is ArrayMesh:
			var surface_name := (node.mesh as ArrayMesh).surface_get_name(i)
			if surface_name.begins_with("material_slot:"):
				slot = int(surface_name.trim_prefix("material_slot:"))
		if slot >= 0 and slot < materials.size() and materials[slot] != null:
			node.set_surface_override_material(i, materials[slot])


## What `metric()` in the shader computes, in GDScript: the point's chart on a
## face with this normal. The suite holds it equal to `MeshKit`'s own
## projection, which is the whole contract between the two.
static func metric_chart(point: Vector3, normal: Vector3) -> Vector2:
	var axes: Array = MeshKit._surface_uv_axes(normal)
	return MeshKit._project_uv(point, axes)
