extends RefCounted
## A castle on falling ground (VTER-CASTLE-SLOPE). The village's own castles
## -- the seat a village of 200 asks for (norman 40 x 50: the MANOR tier), the
## hold below that (12 x 14: the house tier) -- and a larger form (norman
## 60 x 90, the castle tier: a motte and bailey), at falls 1.0, 2.5 and 4.0 m,
## downhill toward the gate (front-to-back) and sideways (toward +X).
##
##   the contract: a castle request takes a fall; over CastleGeometry.
##     SLOPE_MAX_FALL it is REFUSED with `ground_too_steep` (the failure
##     control), a sky citadel refuses any fall, and fall 0 is the flat castle
##     vertex for vertex
##   the flat castle is all still there, triangle for triangle: the slope only
##     adds what stands under it
##   nothing hangs: every grounded vertex of the flat castle and every prop
##     stands inside the platform's outline, and at every point along the
##     outline the revetment reaches down to the ground
##   the downhill foot meets the ground: on each downhill-facing edge of the
##     platform the lowest vertex is within 0.05 m of the ground line
##   nothing is buried deeper than the paving uphill, or than the talus's own
##     width of slope anywhere
##   component_check: every logged part is in the mesh
##   the entrance is reachable from the ground: a flight GroundFall's rules
##     accept from the platform's edge in front of the gate or porch, level
##     platform from there to the entrance, and the castle's own walk
##     (CastleQA.lords_walk, where it applies) finds no fault the flat castle
##     does not have

const CastleSlope = preload("res://src/castle/castle_slope.gd")
const FALLS := [1.0, 2.5, 4.0]
const DIRECTIONS := {"front-to-back": 0.0, "sideways": 90.0}
const EDGE_TOL := 0.05
const CASES := [
	{"name": "manor norman 40x50", "style": &"norman", "seed": 4242, "w": 40.0, "l": 50.0, "h": 10.0},
	{"name": "hold norman 12x14", "style": &"norman", "seed": 4242, "w": 12.0, "l": 14.0, "h": 8.0},
	{"name": "castle norman 60x90", "style": &"norman", "seed": 4242, "w": 60.0, "l": 90.0, "h": 18.0},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("cslope")
	_contract(res)
	for c in CASES:
		_family(res, c)
	return res


static func _request(c: Dictionary) -> BuildingRequest:
	return BuildingRequest.castle(int(c["seed"]), c["style"], float(c["w"]), float(c["l"]),
		float(c["h"]))


# ------------------------------------------------------------- the contract

static func _contract(res: SuiteResult) -> void:
	var c: Dictionary = CASES[0]
	var ok := _request(c)
	ok.ground_fall_m = 2.5
	res.checked += 1
	if not BuildingLibrary.validate(ok).is_empty():
		res.fail("contract: a castle on a 2.5 m fall was refused: %s" % [BuildingLibrary.validate(ok)])
	# the failure control: over the maximum is refused, with its reason
	var steep := _request(c)
	steep.ground_fall_m = CastleGeometry.SLOPE_MAX_FALL + 1.0
	steep.ground_downhill_deg = 90.0
	var made := BrickWild.generate(steep)
	res.checked += 1
	if made.is_ok() or not _has_code(made.errors, &"ground_too_steep"):
		res.fail("contract: a %.1f m fall under a castle must be refused with ground_too_steep, got %s"
			% [steep.ground_fall_m, made.errors])
	else:
		res.note("castle at %.1f m refused: %s" % [steep.ground_fall_m, made.errors[0]["message"]])
	# steeper than 1 in 2 across a small hold
	var hold := _request(CASES[1])
	hold.ground_fall_m = 6.5
	hold.ground_downhill_deg = 90.0
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(hold), &"ground_too_steep"):
		res.fail("contract: 6.5 m across a 12 m hold is steeper than 1 in 2 and must be refused")
	var sky := BuildingRequest.castle(5, &"sky", 60.0, 90.0, 18.0)
	sky.ground_fall_m = 1.0
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(sky), &"unsupported_option"):
		res.fail("contract: a sky citadel must refuse ground_fall_m (unsupported_option)")


static func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if StringName(e.get("code", "")) == code:
			return true
	return false


# -------------------------------------------------------------- the family

static func _family(res: SuiteResult, c: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var flat := _build(_request(c))
	if flat.is_empty():
		res.fail("%s: flat request did not generate" % c["name"])
		return
	flat["walk"] = CastleQA.lords_walk(flat["building"].spec, flat["builder"], flat["mesh"])
	res.note("%s: tier %s, plan %s, flat build %d ms" % [c["name"], flat["building"].spec.tier,
		flat["building"].spec.plan_kind, Time.get_ticks_msec() - t0])
	if c == CASES[1]:
		# fall 0 with a direction set is the flat castle, vertex for vertex
		var zero_req := _request(c)
		zero_req.ground_fall_m = 0.0
		zero_req.ground_downhill_deg = 90.0
		var zero := _build(zero_req)
		res.checked += 1
		if zero.is_empty() or not _same_mesh(flat["mesh"], zero["mesh"]):
			res.fail("%s: fall 0 is not vertex-identical to a request without the field" % c["name"])
	for dname in DIRECTIONS:
		for fall in FALLS:
			var req := _request(c)
			req.ground_fall_m = fall
			req.ground_downhill_deg = DIRECTIONS[dname]
			var label := "%s %s %.1f m" % [c["name"], dname, fall]
			t0 = Time.get_ticks_msec()
			var built := _build(req)
			res.checked += 1
			if built.is_empty():
				res.fail("%s: did not generate" % label)
				continue
			_case(res, label, built, flat)
			res.note("%s: %d ms" % [label, Time.get_ticks_msec() - t0])


static func _build(req: BuildingRequest) -> Dictionary:
	var made := BrickWild.generate(req)
	if not made.is_ok():
		return {}
	var cb := CastleBuilder.new()
	return {"building": made, "builder": cb, "mesh": cb.build(made.spec)}


static func _case(res: SuiteResult, label: String, built: Dictionary, flat: Dictionary) -> void:
	var spec: CastleSpec = built["building"].spec
	var mesh: ArrayMesh = built["mesh"]
	var b: CastleBuilder = built["builder"]
	var g := CastleGeometry.slope_ground(spec)
	res.checked += 1
	if g == null:
		res.fail("%s: the spec did not receive the ground" % label)
		return
	var poly: PackedVector2Array = b.slope_outline
	res.checked += 1
	if poly.size() < 3:
		res.fail("%s: no platform outline" % label)
		return

	# 1. the flat castle is all still there
	res.checked += 1
	var missing := 0
	for s in mesh.get_surface_count():
		if s >= flat["mesh"].get_surface_count():
			break
		var want := ComponentCheck._triangle_vertices(flat["mesh"].surface_get_arrays(s))
		var have := ComponentCheck._triangle_vertices(mesh.surface_get_arrays(s))
		missing += ComponentCheck.missing_triangles(have, want)
	if missing > 0:
		res.fail("%s: %d triangles of the flat castle are gone" % [label, missing])

	# 2. everything that stood on the ground stands on the platform
	var outside := 0
	var outside_at := Vector3.ZERO
	for s in flat["mesh"].get_surface_count():
		for v in flat["mesh"].surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.y > 0.01:
				continue
			if not _inside(poly, Vector2(v.x, v.z), 0.02):
				outside += 1
				outside_at = v
	for p in b.prop_log:
		var at: Vector3 = p["pos"]
		if at.y <= 0.05 and not _inside(poly, Vector2(at.x, at.z), 0.02):
			outside += 1
			outside_at = at
	res.checked += 1
	if outside > 0:
		res.fail("%s: %d grounded vertices or props stand off the platform (e.g. %s)"
			% [label, outside, outside_at])

	# 3. along the whole outline the revetment reaches the ground
	var low := _low_triangles(mesh)
	var sgn: float = signf(CastleSlope.signed_area(poly))
	var hanging := 0
	var hang_at := Vector2.ZERO
	var hang_gap := 0.0
	var samples := 0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var cc: Vector2 = poly[(i + 1) % poly.size()]
		var n := _edge_normal(poly, i, sgn)
		var steps := maxi(1, int(ceil(a.distance_to(cc) / 1.0)))
		for k in range(steps + 1):
			var p: Vector2 = a.lerp(cc, float(k) / float(steps)) - n * 0.05
			var gy := g.ground_y(p)
			if gy >= CastleGeometry.SLOPE_TOP - 0.05:
				continue
			samples += 1
			var bottom := _lowest_at(low, p)
			if bottom > gy + EDGE_TOL:
				hanging += 1
				if bottom - gy > hang_gap:
					hang_gap = bottom - gy
					hang_at = p
	res.checked += 1
	if hanging > 0:
		res.fail("%s: the revetment stops %.3f m above the ground at %s (%d of %d points)"
			% [label, hang_gap, hang_at, hanging, samples])

	# 4. each downhill edge's lowest vertex is on the ground line: the outer
	#    (downhill) face of that edge's own courses, as logged and -- by
	#    component_check below -- as emitted
	var talus: Array[Dictionary] = b.components(CastleSlope.ROLE_TALUS)
	var downhill_edges := 0
	var bad_edges := PackedStringArray()
	for i in poly.size():
		var a: Vector2 = poly[i]
		var cc: Vector2 = poly[(i + 1) % poly.size()]
		var n := _edge_normal(poly, i, sgn)
		if a.distance_to(cc) < 1.0 or n.dot(g.dir) < 0.5:
			continue
		var low_y := INF
		var gap := INF
		for v in _outer_foot(b.components_of(CastleSlope.talus_host(i)), n):
			if v.y < low_y - 0.001:
				low_y = v.y
				gap = absf(v.y - g.ground_y(Vector2(v.x, v.z)))
			elif absf(v.y - low_y) <= 0.001:
				gap = minf(gap, absf(v.y - g.ground_y(Vector2(v.x, v.z))))
		if not is_finite(low_y):
			if g.ground_y((a + cc) * 0.5) < CastleGeometry.SLOPE_TOP - 0.1:
				bad_edges.append("edge %d has no foot" % i)
			continue
		downhill_edges += 1
		if gap > EDGE_TOL:
			bad_edges.append("edge %d lowest vertex %.3f m from the ground" % [i, gap])
	res.checked += 1
	if not bad_edges.is_empty():
		res.fail("%s: downhill foot: %s" % [label, ", ".join(bad_edges)])
	if downhill_edges == 0:
		res.fail("%s: no downhill edge of the platform was measured" % label)

	# 5. nothing buried too deep
	var reach: float = CastleGeometry.SLOPE_WALL_T + CastleGeometry.SLOPE_TALUS \
		* (g.fall * 2.0 / GroundFall.COURSE + 2.0)
	var tol: float = 0.16 + g.gradient() * reach
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var uphill_worst := 0.0
	for s in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p := Vector2(v.x, v.z)
			var gy := g.ground_y(p)
			var under: float = gy - v.y
			if under > worst:
				worst = under
				worst_at = v
			if gy >= -0.05 and _inside(poly, p, -0.01):
				uphill_worst = maxf(uphill_worst, under)
	res.checked += 2
	if worst > tol:
		res.fail("%s: geometry %.3f m under the ground at %s (allowed %.3f)" % [label, worst, worst_at, tol])
	if uphill_worst > CastleGeometry.SLOPE_PAVING_T + 0.05:
		res.fail("%s: geometry %.3f m under the ground on the uphill side" % [label, uphill_worst])

	# 6. every logged part is in the mesh
	var comp := ComponentCheck.check(b, mesh)
	res.checked += 2
	if not comp["ok"]:
		res.fail("%s: component_check: %s" % [label, comp["failures"]])
	if talus.is_empty() or b.components(CastleSlope.ROLE_PAVING).is_empty():
		res.fail("%s: no talus or no paving was emitted" % label)

	# 7. the entrance is reachable from the ground
	_entrance(res, label, g, b, spec, poly)
	var walk := CastleQA.lords_walk(spec, b, mesh)
	res.checked += 1
	var known: Array = flat["walk"].get("failures", [])
	var fresh: Array = []
	for f in walk.get("failures", []):
		if f not in known:
			fresh.append(f)
	if not fresh.is_empty():
		res.fail("%s: lords_walk: %s" % [label, fresh])


static func _entrance(res: SuiteResult, label: String, g: GroundFall, b: CastleBuilder,
		spec: CastleSpec, poly: PackedVector2Array) -> void:
	var edge := CastleSlope.entry_edge(spec, poly)
	var rise: float = CastleGeometry.SLOPE_TOP - g.ground_y(edge + Vector2(0.0, -0.5))
	res.checked += 1
	if rise > GroundFall.RISER + 0.02:
		var f: Dictionary = b.slope_flight
		if f.is_empty():
			res.fail("%s: the platform is %.2f m above the ground at the entrance with no steps" % [label, rise])
			return
		var faults := HouseSlope.flight_faults(g, f)
		if not bool(f["feasible"]):
			faults.append("no clear direction for the flight")
		if not faults.is_empty():
			res.fail("%s: entrance flight: %s" % [label, ", ".join(faults)])
		res.checked += 1
		if b.components_of("entry_gate").size() < (f["steps"] as Array).size():
			res.fail("%s: the entrance flight's steps were not all emitted" % label)
		res.note("%s: entrance rise %.2f m, %d steps %s" % [label, rise,
			(f["steps"] as Array).size(), f["direction"]])
	# level platform from the flight's head to the entrance itself
	var e := CastleGeometry.slope_entry(spec)
	var front: float = e["front"]
	res.checked += 1
	if is_finite(front):
		var to := Vector2(float(e["x"]), front + 0.1)
		for k in range(11):
			var p: Vector2 = (edge + Vector2(0.0, 0.05)).lerp(to, float(k) / 10.0)
			if not _inside(poly, p, 0.0):
				res.fail("%s: the way from the platform's edge to the entrance leaves the platform at %s"
					% [label, p])
				break


# ------------------------------------------------------------------ helpers

static func _edge_normal(poly: PackedVector2Array, i: int, sgn: float) -> Vector2:
	return CastleSlope.edge_normal(poly, i, sgn)


## Inside `poly`, or within `tol` of its boundary (negative: that far inside).
static func _inside(poly: PackedVector2Array, p: Vector2, tol: float) -> bool:
	var inside := Geometry2D.is_point_in_polygon(p, poly)
	var d := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		d = minf(d, q.distance_to(p))
	if tol >= 0.0:
		return inside or d <= tol
	return inside and d >= -tol


## Triangles wholly under the castle's own ground: the platform and flights.
static func _low_triangles(mesh: ArrayMesh) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for s in mesh.get_surface_count():
		var tv := ComponentCheck._triangle_vertices(mesh.surface_get_arrays(s))
		for i in range(0, tv.size() - 2, 3):
			if tv[i].y < -0.02 and tv[i + 1].y < -0.02 and tv[i + 2].y < -0.02:
				out.append(PackedVector3Array([tv[i], tv[i + 1], tv[i + 2]]))
	return out


## The lowest height at which a vertical line through `p` meets the triangles.
static func _lowest_at(tris: Array[PackedVector3Array], p: Vector2) -> float:
	var low := INF
	for t in tris:
		var a := Vector2(t[0].x, t[0].z)
		var bb := Vector2(t[1].x, t[1].z)
		var c := Vector2(t[2].x, t[2].z)
		var den := (bb - a).cross(c - a)
		if absf(den) < 1e-9:
			continue
		var u := (p - a).cross(c - a) / den
		var w := (bb - a).cross(p - a) / den
		if u < -1e-4 or w < -1e-4 or u + w > 1.0 + 1e-4:
			continue
		low = minf(low, t[0].y + u * (t[1].y - t[0].y) + w * (t[2].y - t[0].y))
	return low


## The outer-face vertices of an edge's courses: each logged slab's centre
## polygon carried half its depth out along the edge's outward normal.
static func _outer_foot(rows: Array[Dictionary], n: Vector2) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n3 := Vector3(n.x, 0.0, n.y)
	for row in rows:
		if String(row.get("role", "")) != CastleSlope.ROLE_TALUS:
			continue
		var half: float = float(row["depth"]) * 0.5
		for p in row["points"]:
			out.append(p + n3 * half)
	return out


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var x: Array = a.surface_get_arrays(s)
		var y: Array = b.surface_get_arrays(s)
		if x[Mesh.ARRAY_VERTEX] != y[Mesh.ARRAY_VERTEX]:
			return false
		if x[Mesh.ARRAY_INDEX] != y[Mesh.ARRAY_INDEX]:
			return false
	return true
