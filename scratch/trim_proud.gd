extends SceneTree
## Does any timber stand proud of the roof it is holding up?
##
## For every TRIM vertex above the wall head, work out how high the ROOF
## surface is at that same (x, z) and report the excess. A gable truss, a
## bargeboard and a purlin all live UNDER the rafters; a member sticking out
## through the slates is a member drawn to the wrong length.
##
## Finials and the ridge are excluded by looking only outside the middle of
## the span -- a finial stands on the apex on purpose.


func _init() -> void:
	for style in HouseSweep.styles():
		var worst := 0.0
		var where := ""
		var worst_truss := &""
		for i in range(24):
			var spec := HouseSpec.new()
			spec.style = style
			spec.width = 6.0 + float(i % 5) * 1.6
			spec.length = 7.0 + float(i % 7) * 1.5
			spec.height = 2.5
			spec.storeys = 1 + (i % 2)
			var plan: HousePlan = HouseGenerator.generate(spec, 74000 + i)
			var b := HouseBuilder.new()
			var mesh: ArrayMesh = b.build(plan)
			# A chimney stands proud of the roof on purpose; that is what a
			# chimney is. Its plan footprint comes out of the mass log so the
			# measurement below is about TIMBER only.
			var flue := Rect2()
			for m in b.mass_log:
				if String(m["name"]).begins_with("chimney"):
					var a: AABB = m["aabb"]
					flue = Rect2(a.position.x, a.position.z, a.size.x, a.size.z).grow(0.6)
			var r: Array = _worst(mesh, spec, flue)
			if float(r[0]) > worst:
				worst = float(r[0])
				where = "seed %d %s %s" % [74000 + i, String(spec.roof_type), str(r[1])]
				worst_truss = spec.gable_truss
		print("%-11s worst %.2f m proud  truss=%-12s %s"
			% [String(style), worst, String(worst_truss), where])
	quit()


## [excess, point] for the trim vertex that stands furthest above the roof.
func _worst(mesh: ArrayMesh, spec: HouseSpec, flue: Rect2) -> Array:
	var wall_top: float = spec.height * mini(spec.storeys, 3)
	var half: float = HouseGeometry.site_rect(spec).size.x / 2.0
	var buckets: Dictionary = {}
	for t in _tris(mesh, HouseBuilder.SURF_ROOF):
		# A box has vertical side faces, and a vertical triangle projects to a
		# LINE in plan: asking how high it is over a point is meaningless, and
		# interpolating across one is what made this probe report a bargeboard
		# sitting on its own verge as two metres of timber in the sky.
		if _plan_area(t) < 0.01:
			continue
		var lo := Vector2i(int(floor(minf(t[0].x, minf(t[1].x, t[2].x)))),
			int(floor(minf(t[0].z, minf(t[1].z, t[2].z)))))
		var hi := Vector2i(int(floor(maxf(t[0].x, maxf(t[1].x, t[2].x)))),
			int(floor(maxf(t[0].z, maxf(t[1].z, t[2].z)))))
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var k := Vector2i(cx, cz)
				if not buckets.has(k):
					buckets[k] = []
				buckets[k].append(t)
	var worst := 0.0
	var at := Vector3.ZERO
	for p in mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]:
		if p.y < wall_top + 0.2:
			continue
		# leave the apex alone: a finial belongs above the ridge
		if absf(p.x) < half * 0.25:
			continue
		if flue.size.x > 0.0 and flue.has_point(Vector2(p.x, p.z)):
			continue
		var top := -INF
		for t2 in buckets.get(Vector2i(int(floor(p.x)), int(floor(p.z))), []):
			var y: float = _plane_y(t2, Vector2(p.x, p.z))
			if is_finite(y):
				top = maxf(top, y)
		if not is_finite(top):
			continue                       # nothing overhead: a verge board
		if p.y - top > worst:
			worst = p.y - top
			at = p
	return [worst, at]


## Height of a triangle's plane at (x, z), or INF when (x, z) is outside it.
static func _plane_y(t: PackedVector3Array, p: Vector2) -> float:
	var a := Vector2(t[0].x, t[0].z)
	var b := Vector2(t[1].x, t[1].z)
	var c := Vector2(t[2].x, t[2].z)
	if not Geometry2D.point_is_inside_triangle(p, a, b, c):
		return INF
	var d: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-9:
		return INF
	var w0: float = ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
	var w1: float = ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
	return w0 * t[0].y + w1 * t[1].y + (1.0 - w0 - w1) * t[2].y


## Area of a triangle once flattened into plan.
static func _plan_area(t: PackedVector3Array) -> float:
	var a := Vector2(t[0].x, t[0].z)
	var b := Vector2(t[1].x, t[1].z)
	var c := Vector2(t[2].x, t[2].z)
	return absf((b - a).cross(c - a)) / 2.0


static func _tris(mesh: ArrayMesh, surface: int) -> Array:
	var arr: Array = mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var out: Array = []
	for i in range(0, v.size(), 3):
		out.append(PackedVector3Array([v[i], v[i + 1], v[i + 2]]))
	return out
