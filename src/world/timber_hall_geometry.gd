class_name TimberHallGeometry
extends RefCounted
## Single source of truth for timber hall plan geometry.

const PATH_MIN := 1.6
const PLATFORM_MIN := 0.6
const STAIR_TREAD := 0.55
const STAIR_RISE := 0.2
const ROOF_DEPTH := 0.18

static func hall_rect(spec: TimberHallSpec) -> Rect2:
	return Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))

static func platform_rect(spec: TimberHallSpec) -> Rect2:
	var h := hall_rect(spec)
	return h.grow(1.5)

static func front_stair_rect(spec: TimberHallSpec) -> Rect2:
	var p := platform_rect(spec)
	return Rect2(Vector2(-2.2, p.position.y - 3.3), Vector2(4.4, 3.3))

static func column_rects(spec: TimberHallSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in column_records(spec):
		var p: Vector3 = c["pos"]
		var r: float = c["radius"]
		out.append(Rect2(Vector2(p.x - r, p.z - r), Vector2(r * 2.0, r * 2.0)))
	return out

static func column_records(spec: TimberHallSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h := hall_rect(spec)
	var outer_x: float = spec.width / 2.0 - maxf(2.0, spec.width * 0.16)
	var inner_x: float = maxf(outer_x - spec.width * 0.18, spec.column_r * 3.0)
	var outer_z: float = h.size.y / 2.0 - 2.0
	var inner_z: float = maxf(outer_z - 2.4, spec.column_r * 3.0)
	for ring in range(2):
		var x_edge: float = outer_x if ring == 0 else inner_x
		var z_edge: float = outer_z if ring == 0 else inner_z
		var xs: Array[float] = [-x_edge, -inner_x if ring == 0 else -inner_x * 0.72,
			inner_x if ring == 0 else inner_x * 0.72, x_edge]
		for z in [-z_edge, z_edge]:
			for x in xs:
				out.append({"pos": Vector3(x, spec.platform_h, z),
					"radius": spec.column_r, "height": spec.column_h, "ring": ring})
		for side in [-1.0, 1.0]:
			var x: float = side * x_edge
			for i in range(1, 3):
				var z: float = lerpf(-z_edge, z_edge, float(i) / 3.0)
				out.append({"pos": Vector3(x, spec.platform_h, z),
					"radius": spec.column_r, "height": spec.column_h, "ring": ring})
	return out

static func dais_rect(spec: TimberHallSpec) -> Rect2:
	var h := hall_rect(spec)
	return Rect2(Vector2(-spec.width * 0.28, h.end.y - 4.5),
		Vector2(spec.width * 0.56, 3.5))

static func image_center(spec: TimberHallSpec) -> Vector3:
	var d := dais_rect(spec)
	return Vector3(0.0, spec.platform_h + spec.dais_h + spec.image_h / 2.0,
		d.end.y - 0.7)

static func window_records(spec: TimberHallSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h := hall_rect(spec)
	for side in [-1.0, 1.0]:
		for i in range(4):
			var z := lerpf(h.position.y + 3.0, h.end.y - 3.0, float(i) / 3.0)
			var wy: float = spec.platform_h + (9.0 if spec.wings else 5.0)
			out.append({"pos": Vector3(side * spec.width / 2.0, wy, z),
				"normal": Vector3(side, 0.0, 0.0), "size": Vector2(1.2, 2.0)})
	return out

static func water_rect(spec: TimberHallSpec) -> Rect2:
	return spec.water
