extends RefCounted
## A castle on falling ground (VTER-CASTLE-SLOPE): the platform it stands on.
##
## The site model is GroundFall's: local y = 0 is the ground at the uphill-most
## point of the requested width x length, the ground falls linearly across it
## and on downhill beyond, and is cut level uphill. Nothing above y = 0 moves.
## Every logged mass of a Norman castle stands at y = 0, so without this the
## downhill wall foot is in the air.
##
## The answer, per part:
##   * curtain and towers -- a stepped TALUS (`talus_course`), the revetment
##     a castle on a slope is built on: SLOPE_WALL_T thick at the top, each
##     0.30 m course below set out SLOPE_TALUS further, its foot on the ground.
##     It runs round the union of every part that stands on the ground, each
##     grown by SLOPE_SETOUT, so on a walled castle it follows the curtain's
##     battered foot and wraps each tower, gatehouse and barbican.
##   * the bailey -- FILLED to the castle's ground and paved (`platform_paving`)
##     behind the revetment: a terrace, retaining wall and fill. A ward that
##     followed the slope would put every range, keep, stair and yard building
##     on a different level; the castle geometry has one ground per ward.
##   * keep, hall, chapel, yard buildings -- on the filled bailey: the keep's
##     plinth is the terrace it stands on.
##   * an unwalled castle (house, manor, tower house) -- a terrace: the convex
##     hull of its parts, so the forecourt between the wings is paved too.
##   * the entrance -- a flight from the platform's edge in front of the gate
##     or porch down to the ground (GroundFall.plan_flight, `entry_landing` and
##     `entry_step`, host `entry_gate`), with the platform kept SLOPE_APPROACH
##     deep in front of the entrance so the gate is reached on the level.
##
## Flat ground emits nothing and touches no log, which is what keeps every
## flat castle vertex-identical.

const ROLE_TALUS := "talus_course"
const ROLE_PAVING := "platform_paving"
const CIRCLE_SIDES := 16
## A polygonal tower's AABB half-size is at least cos(pi/8) of its corner
## radius; a circle this much wider than the AABB holds any of them.
const CIRCLE_COVER := 1.09
const MAX_COURSES := 80


## Emit the platform under `b`, a CastleBuilder that has just built `b.spec`.
static func emit(b: CastleBuilder) -> void:
	var g := CastleGeometry.slope_ground(b.spec)
	if g == null:
		return
	var unsupported := CastleGeometry.slope_unsupported(b.spec)
	if not unsupported.is_empty():
		# BuildingLibrary.validate refuses these; a spec built by hand is told
		push_error("CastleSlope: %s" % unsupported)
		return
	var poly := outline(b)
	if poly.size() < 3:
		return
	b.slope_outline = poly
	b.tag("platform")
	_talus(b, g, poly)
	b.host("platform", 0)
	_paving(b, poly)
	b.host_end()
	var flight := _flight(b, g, poly)
	b.slope_flight = flight
	if not flight.is_empty():
		b.host("entry_gate", 0)
		g.emit_flight(b, flight, CastleBuilder.SURF_STONE, CastleGeometry.SLOPE_TOP)
		b.host_end()


# ---------------------------------------------------------------- outline

## The platform's outline in plan: the union of every grounded part's
## footprint grown by SLOPE_SETOUT (or their convex hull; see slope_hull).
static func outline(b: CastleBuilder) -> PackedVector2Array:
	var shapes := footprints(b)
	var points := PackedVector2Array()
	for s in shapes:
		points.append_array(s)
	if points.size() < 3:
		return PackedVector2Array()
	if CastleGeometry.slope_hull(b.spec):
		return _clean(_hull(points))
	var outers := _union(shapes)
	if outers.size() != 1:
		# parts that do not touch: one terrace under all of them
		return _clean(_hull(points))
	return _clean(outers[0])


## Every footprint the platform must carry, already grown by SLOPE_SETOUT.
static func footprints(b: CastleBuilder) -> Array[PackedVector2Array]:
	var spec: CastleSpec = b.spec
	var grow: float = CastleGeometry.SLOPE_SETOUT
	var out: Array[PackedVector2Array] = []
	var enclosed := CastleGeometry.is_enclosed(spec)
	var by_polygon := enclosed and not spec.curved_edges
	if enclosed:
		# the curtain's battered foot, as the enceinte polygon set out
		var spread: float = CastleGeometry.batter_spread(spec, CastleGeometry.wall_height(spec, 0))
		out.append(CastleGeometry.offset_polygon(CastleGeometry.enceinte_polygon(spec, 0),
			-(spread + grow)))
	for m in b.mass_log:
		if m.has("ground"):
			continue    # stands on a raised ground of its own (a terraced inner ward)
		var a: AABB = m["aabb"]
		if a.position.y > 0.05 or a.size.x <= 0.001 or a.size.z <= 0.001:
			continue
		var nm: String = m["name"]
		# a slanted curtain is logged as boxes whose AABBs overreach it; the
		# polygon above is its true foot
		if by_polygon and nm.begins_with("wall_") and not nm.begins_with("wall_stair"):
			continue
		var round_tower: bool = nm.begins_with("tower_") and spec.tower_shape != &"square"
		if round_tower or nm == "motte":
			var r: float = maxf(a.size.x, a.size.z) * 0.5 * CIRCLE_COVER + grow
			out.append(_circle(Vector2(a.get_center().x, a.get_center().z), r))
		else:
			out.append(_rect(Rect2(a.position.x, a.position.z, a.size.x, a.size.z).grow(grow)))
	# steps and boxes logged only as parts: a tower house's approach stair,
	# a forebuilding's treads, the motte's steps
	for p in b.part_log:
		var kind: String = p["kind"]
		if kind != "box" and not kind.ends_with("_step"):
			continue
		var size: Vector3 = p["size"]
		var pos: Vector3 = p["pos"]
		if size.x <= 0.001 or size.z <= 0.001 or pos.y - size.y * 0.5 > 0.05:
			continue
		out.append(_box(pos, size, float(p.get("rot_y", 0.0)), grow))
	# the yard's fittings and props stand on the ground too
	for p in b.prop_log:
		var at: Vector3 = p["pos"]
		if at.y > 0.05:
			continue
		var r2: Variant = p.get("rect")
		if r2 is Rect2 and (r2 as Rect2).has_area():
			out.append(_rect((r2 as Rect2).grow(grow)))
		else:
			out.append(_rect(Rect2(Vector2(at.x, at.z) - Vector2.ONE * 0.5, Vector2.ONE).grow(grow)))
	# level ground in front of the entrance
	var e := CastleGeometry.slope_entry(spec)
	var front: float = e["front"]
	if is_finite(front):
		var w: float = float(e["width"]) + 1.0
		out.append(_rect(Rect2(float(e["x"]) - w * 0.5, front - CastleGeometry.SLOPE_APPROACH,
			w, CastleGeometry.SLOPE_APPROACH + 0.5)))
	return out


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)])


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	# circumscribe: the polygon's flats are at r
	var rr: float = r / cos(PI / float(CIRCLE_SIDES))
	for i in CIRCLE_SIDES:
		var t: float = TAU * (float(i) + 0.5) / float(CIRCLE_SIDES)
		out.append(c + Vector2(cos(t), sin(t)) * rr)
	return out


static func _box(pos: Vector3, size: Vector3, rot_y: float, grow: float) -> PackedVector2Array:
	var basis := Basis(Vector3.UP, rot_y)
	var hx: float = size.x * 0.5 + grow
	var hz: float = size.z * 0.5 + grow
	var out := PackedVector2Array()
	for c in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		var w: Vector3 = pos + basis * c
		out.append(Vector2(w.x, w.z))
	return out


static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var h := Geometry2D.convex_hull(points)
	if h.size() > 1 and h[0].distance_to(h[h.size() - 1]) < 1e-6:
		h.remove_at(h.size() - 1)
	return h


## Merge the shapes into their outer boundaries; holes are dropped (filled).
static func _union(shapes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var outers: Array[PackedVector2Array] = []
	var boxes: Array[Rect2] = []
	for s in shapes:
		if s.size() < 3:
			continue
		var cur: PackedVector2Array = s
		var cur_box := _bbox(cur)
		var i := 0
		while i < outers.size():
			if not cur_box.grow(0.01).intersects(boxes[i]):
				i += 1
				continue
			var merged := _merge(cur, outers[i])
			if merged.is_empty():
				i += 1
				continue
			cur = merged
			cur_box = _bbox(cur)
			outers.remove_at(i)
			boxes.remove_at(i)
			i = 0
		outers.append(cur)
		boxes.append(cur_box)
	return outers


## The outer boundary of a ∪ b when they overlap, else empty.
static func _merge(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var res: Array[PackedVector2Array] = Geometry2D.merge_polygons(a, b)
	if res.size() == 1:
		return res[0]
	# one polygon holding every other one is the boundary, the rest holes
	for i in res.size():
		var holds := true
		for j in res.size():
			if j != i and not Geometry2D.is_point_in_polygon(res[j][0], res[i]):
				holds = false
				break
		if holds:
			return res[i]
	return PackedVector2Array()


static func _bbox(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r


## Drop repeated and collinear points.
static func _clean(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	var changed := true
	while changed and out.size() > 3:
		changed = false
		for i in out.size():
			var a: Vector2 = out[(i + out.size() - 1) % out.size()]
			var v: Vector2 = out[i]
			var c: Vector2 = out[(i + 1) % out.size()]
			if v.distance_to(a) < 0.02 or absf((v - a).cross(c - v)) < 1e-5 * maxf((v - a).length() * (c - v).length(), 1e-6):
				out.remove_at(i)
				changed = true
				break
	return out


static func signed_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return s * 0.5


## Outward normal of edge i of `poly` (orientation `sgn` = sign of its area).
static func edge_normal(poly: PackedVector2Array, i: int, sgn: float) -> Vector2:
	var d: Vector2 = (poly[(i + 1) % poly.size()] - poly[i]).normalized()
	# for a positively wound polygon the interior is on the left (+cross)
	return Vector2(d.y, -d.x) * sgn


# ------------------------------------------------------------------ talus

static func _talus(b: CastleBuilder, g: GroundFall, poly: PackedVector2Array) -> void:
	var n := poly.size()
	var sgn: float = signf(signed_area(poly))
	var top: float = CastleGeometry.SLOPE_TOP
	var t: float = CastleGeometry.SLOPE_WALL_T
	for i in n:
		var a: Vector2 = poly[i]
		var c: Vector2 = poly[(i + 1) % n]
		var length := a.distance_to(c)
		if length < 0.01:
			continue
		var along: Vector2 = (c - a) / length
		var nrm := edge_normal(poly, i, sgn)
		# how far past each end a set-out course must run to close a convex corner
		var tan_a := _corner_tan(poly, i, sgn)
		var tan_c := _corner_tan(poly, (i + 1) % n, sgn)
		# one host per run of the outline, so a part can be traced to its edge
		b.host(talus_host(i), 0)
		for k in MAX_COURSES:
			var s: float = CastleGeometry.SLOPE_TALUS * float(k)
			var thick: float = t + s
			var off: float = (s - t) * 0.5
			var from: Vector2 = a + nrm * off - along * (s * tan_a + (0.005 if k > 0 else 0.0))
			var to: Vector2 = c + nrm * off + along * (s * tan_c + (0.005 if k > 0 else 0.0))
			var g0: float = g.ground_lo(from, nrm, thick, false)
			var g1: float = g.ground_lo(to, nrm, thick, false)
			var hi: float = top - GroundFall.COURSE * float(k)
			if hi <= minf(g0, g1) + 0.005:
				break
			var band := GroundFall._clip_band(from, to, g0, g1, hi - GroundFall.COURSE, hi)
			if band.size() >= 3:
				b.component_slab(ROLE_TALUS, band, thick, CastleBuilder.SURF_STONE, false)
		b.host_end()


## The component host of the talus under edge `i` of the outline.
static func talus_host(i: int) -> String:
	return "talus_%d" % i


## tan(turn / 2) at vertex `v` when it is convex, 0 when it is reflex (a
## reflex corner's courses overlap inside the platform on their own).
static func _corner_tan(poly: PackedVector2Array, v: int, sgn: float) -> float:
	var n := poly.size()
	var p: Vector2 = poly[(v + n - 1) % n]
	var q: Vector2 = poly[v]
	var r: Vector2 = poly[(v + 1) % n]
	var d0 := (q - p).normalized()
	var d1 := (r - q).normalized()
	if d0.cross(d1) * sgn <= 0.0:
		return 0.0
	var turn := acos(clampf(d0.dot(d1), -1.0, 1.0))
	return minf(tan(turn * 0.5), 2.0)


# ----------------------------------------------------------------- paving

static func _paving(b: CastleBuilder, poly: PackedVector2Array) -> void:
	var y: float = CastleGeometry.SLOPE_TOP - CastleGeometry.SLOPE_PAVING_T * 0.5
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly,
		-CastleGeometry.SLOPE_WALL_T, Geometry2D.JOIN_MITER)
	for piece in inner:
		if piece.size() < 3:
			continue
		# a hole of the offset is not paved (offsetting a simple polygon inward
		# gives none, but be sure)
		if signf(signed_area(piece)) != signf(signed_area(poly)):
			continue
		for convex in Geometry2D.decompose_polygon_in_convex(piece):
			if convex.size() < 3:
				continue
			var pts := PackedVector3Array()
			for p2 in convex:
				pts.append(Vector3(p2.x, y, p2.y))
			b.component_slab(ROLE_PAVING, pts, CastleGeometry.SLOPE_PAVING_T,
				CastleBuilder.SURF_STONE, true)


# ----------------------------------------------------------------- flight

## The platform's front edge in front of the entrance: the lowest plan z at
## which the line x = entry crosses the outline.
static func entry_edge(spec: CastleSpec, poly: PackedVector2Array) -> Vector2:
	var x: float = CastleGeometry.slope_entry(spec)["x"]
	var front := INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var c: Vector2 = poly[(i + 1) % poly.size()]
		if absf(c.x - a.x) < 1e-6 or (a.x - x) * (c.x - x) > 0.0:
			continue
		front = minf(front, lerpf(a.y, c.y, (x - a.x) / (c.x - a.x)))
	return Vector2(x, front)


static func _flight(b: CastleBuilder, g: GroundFall, poly: PackedVector2Array) -> Dictionary:
	var spec: CastleSpec = b.spec
	var outer := entry_edge(spec, poly)
	if not is_finite(outer.y):
		return {}
	var e := CastleGeometry.slope_entry(spec)
	var door_w: float = maxf(float(e["width"]), 1.4)
	var normal := Vector2(0.0, -1.0)
	# the flight keeps off the platform: every convex piece of it but the one
	# the entrance opens from
	var blocked: Array[Rect2] = []
	var probe := outer + normal * 0.5
	for piece in Geometry2D.decompose_polygon_in_convex(poly):
		if piece.size() < 3:
			continue
		var r := _bbox(piece)
		if r.grow(0.3).has_point(probe) or r.grow(0.3).has_point(outer - normal * 0.3):
			continue
		blocked.append(r.grow(-0.01))
	return g.plan_flight(outer, normal, door_w, CastleGeometry.SLOPE_TOP, Rect2(), blocked)
