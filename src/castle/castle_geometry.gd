class_name CastleGeometry
extends RefCounted
## Single source of truth for a fortification's massing: where every structural
## volume sits, and the shared constants that decide it.
##
## Same contract as ChurchGeometry -- pure functions of an explicit spec, so the
## builder that emits the mesh and the checks that measure it can never derive
## different answers. Model axes:
##   +X = east, +Y = up, +Z = north (the back). The gate is always at -Z.
##
## The site rectangle (spec.width x spec.length) is the OUTER face of the outer
## enceinte AT WALL-TOP level. Two things deliberately reach beyond it:
##   * the batter (talus) at the wall foot, which spreads outward as it descends
##   * mural towers, which project outward from the wall they stud
## Both are what a castle looks like from outside, so plan_extent() reports them
## rather than the builder quietly clipping them.

# ---- joints, in metres ----
const RANGE_LAP := 0.4       # interior range lapping the wall it stands against
const WING_LAP := 0.4        # manor wing lapping the range it meets
const GATE_LAP := 0.3        # barbican lapping the gatehouse

# ---- proportions ----
const INNER_HEIGHT_RATIO := 1.3   # inner curtain height, x outer curtain height
const INNER_THICK_RATIO := 0.85   # inner curtain thickness, x outer thickness
const TOWER_CAP_RATIO := 0.9      # cone/pyramid rise, x tower diameter
const TOWER_BATTER_CAP := 0.35    # most a tower's foot may spread, x its half-size
const TENSHU_PLINTH := 0.42       # stone base of a tiered keep, x its height
const TENSHU_TIERS := 5           # storeys the timber tower steps down through
const MERLON_W := 0.65            # merlon width along the parapet
const MERLON_GAP := 0.55          # crenel (the gap) width
const PARAPET_RISE := 0.25        # wall-walk coping under the merlons
const GATE_DEPTH_MIN := 3.0
const MIN_WALL_RUN := 1.5         # shorter than this and a wall run is dropped
const BAILEY_CLEAR := 1.5         # air kept between interior ranges
const POLY_MIN_SIDES := 5         # fewest sides a polygonal enceinte may have
const POLY_MAX_SIDES := 8         # most; 8 is Castel del Monte
const WALL_STEP := 7.0            # metres of slanted curtain per logged box
const WALL_STEPS_MAX := 6
const OPENING_EPS := 0.02         # surface offset so openings do not z-fight

# ---- tiers ----
const HOUSE_ANNEXE_W := 0.5       # annexe width, x house width
const HOUSE_ANNEXE_L := 0.35      # annexe length, x house length
const MANOR_RANGE_DEPTH := 0.32   # main range depth along Z, x site length
const MANOR_WING_W := 0.25        # cross wing width, x site width
const CHIMNEY_W := 1.1
const CHIMNEY_RISE := 1.6         # stack standing proud of the ridge
const PORCH_DEPTH := 1.6


# ------------------------------------------------------------------- tiers

static func is_enclosed(spec: CastleSpec) -> bool:
	return spec.tier == &"castle" or spec.tier == &"fortress"


## Index of the innermost enceinte: 1 when there is an inner ward, else 0.
static func inner_ring(spec: CastleSpec) -> int:
	return 1 if spec.inner_ward else 0


## Every enceinte ring the design has, outermost first.
static func rings(spec: CastleSpec) -> Array[int]:
	var out: Array[int] = []
	if not is_enclosed(spec):
		return out
	out.append(0)
	if spec.inner_ward:
		out.append(1)
	return out


# --------------------------------------------------------------------- plan

## Sides of the enceinte. A rectangle IS the four-sided case, so everything
## below can be written once and asked for `n` rather than for "is it a rect".
static func plan_sides(spec: CastleSpec) -> int:
	if spec.plan_kind == &"polygon":
		return clampi(spec.sides, POLY_MIN_SIDES, POLY_MAX_SIDES)
	return 4


## True when the ring has slanted runs, i.e. when it is not the N = 4 case.
static func is_polygonal(spec: CastleSpec) -> bool:
	return plan_sides(spec) > 4


## The enceinte of ring `r` as a closed polygon in plan, at wall-top level:
## the OUTER face, wound counter-clockwise in (x, z) from the gate edge.
##
## Edge 0 is always the one facing -Z, so the gate is on it and its z is the
## site rectangle's own front. The polygon is a regular N-gon turned so that an
## edge (not a vertex) faces the gate, then stretched so its bounding box is
## exactly `enceinte_rect` -- which is what lets every rectangle-shaped rule in
## this file go on being true of a hexagon.
static func enceinte_polygon(spec: CastleSpec, r: int) -> PackedVector2Array:
	var rect: Rect2 = enceinte_rect(spec, r)
	var n: int = plan_sides(spec)
	if n <= 4:
		return PackedVector2Array([rect.position,
			Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
	var unit := PackedVector2Array()
	var a0: float = -PI / 2.0 - PI / float(n)
	for i in range(n):
		var a: float = a0 + TAU * float(i) / float(n)
		unit.append(Vector2(cos(a), sin(a)))
	var bb: Rect2 = polygon_bbox(unit)
	var c: Vector2 = bb.position + bb.size / 2.0
	var mid: Vector2 = rect.position + rect.size / 2.0
	var out := PackedVector2Array()
	for p in unit:
		out.append(mid + Vector2((p.x - c.x) / bb.size.x * rect.size.x,
			(p.y - c.y) / bb.size.y * rect.size.y))
	return out


static func polygon_bbox(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var bb := Rect2(poly[0], Vector2.ZERO)
	for i in range(1, poly.size()):
		bb = bb.expand(poly[i])
	return bb


## Outward unit normal of the edge a -> b of a counter-clockwise polygon.
static func edge_outward(a: Vector2, b: Vector2) -> Vector2:
	var e: Vector2 = b - a
	if e.length() < 0.000001:
		return Vector2(0.0, -1.0)
	return Vector2(e.y, -e.x).normalized()


## Every edge moved inward by `d`, vertices recomputed where the moved edges
## meet. Shrinking a polygon by scaling it instead is what would make a wall
## thicker on the diagonals than on the flats.
static func offset_polygon(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var n: int = poly.size()
	var out := PackedVector2Array()
	for i in range(n):
		var a0: Vector2 = poly[(i + n - 1) % n]
		var b0: Vector2 = poly[i]
		var a1: Vector2 = poly[i]
		var b1: Vector2 = poly[(i + 1) % n]
		var p0: Vector2 = a0 - edge_outward(a0, b0) * d
		var p1: Vector2 = a1 - edge_outward(a1, b1) * d
		var hit: Variant = Geometry2D.line_intersects_line(p0, b0 - a0, p1, b1 - a1)
		out.append(hit if hit != null else (p0 + p1) / 2.0)
	return out


## The innermost face of ring `r`: the ground a ward actually encloses.
static func inner_polygon(spec: CastleSpec, r: int) -> PackedVector2Array:
	return offset_polygon(enceinte_polygon(spec, r), wall_thickness(spec, r))


## Half-width of a convex, x-symmetric polygon at depth `z`.
static func poly_half_width(poly: PackedVector2Array, z: float) -> float:
	var best := -INF
	var n: int = poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if minf(a.y, b.y) - 0.0001 > z or maxf(a.y, b.y) + 0.0001 < z:
			continue
		if absf(b.y - a.y) < 0.0001:
			best = maxf(best, maxf(a.x, b.x))
		else:
			best = maxf(best, lerpf(a.x, b.x, (z - a.y) / (b.y - a.y)))
	return best if best > -INF else 0.0


## The z band over which a strip `2 * hx` wide stays inside the polygon.
static func poly_z_span(poly: PackedVector2Array, hx: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var n: int = poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		for sx in [-1.0, 1.0]:
			var x: float = sx * hx
			if absf(b.x - a.x) < 0.0001:
				if absf(a.x - x) < 0.0001:
					lo = minf(lo, minf(a.y, b.y))
					hi = maxf(hi, maxf(a.y, b.y))
				continue
			var t: float = (x - a.x) / (b.x - a.x)
			if t < -0.0001 or t > 1.0001:
				continue
			var z: float = lerpf(a.y, b.y, t)
			lo = minf(lo, z)
			hi = maxf(hi, z)
	if lo > hi:
		return Vector2.ZERO
	return Vector2(lo, hi)


## Largest axis-aligned rectangle inside a convex, x-symmetric polygon. Found
## by sweeping the half-width: for a convex shape the tallest strip of a given
## width is fixed, so the only free variable is the width itself.
static func max_inscribed_rect(poly: PackedVector2Array) -> Rect2:
	var bb: Rect2 = polygon_bbox(poly)
	var best := Rect2()
	var best_area := -1.0
	for i in range(1, 49):
		var hx: float = bb.size.x / 2.0 * float(i) / 49.0
		var span: Vector2 = poly_z_span(poly, hx)
		var area: float = 2.0 * hx * (span.y - span.x)
		if area > best_area:
			best_area = area
			best = Rect2(Vector2(-hx, span.x), Vector2(2.0 * hx, span.y - span.x))
	return best


## Shortest run of curtain in ring `r`. The generator sizes its towers against
## this: two vertex towers share every edge, and on an octagon an edge is under
## half the site width.
static func min_edge_length(spec: CastleSpec, r: int) -> float:
	var poly: PackedVector2Array = enceinte_polygon(spec, r)
	var out := INF
	for i in range(poly.size()):
		out = minf(out, poly[i].distance_to(poly[(i + 1) % poly.size()]))
	return out


## Length of the edge the gate goes through: the run facing -Z.
static func front_edge_length(spec: CastleSpec, r: int) -> float:
	var poly: PackedVector2Array = enceinte_polygon(spec, r)
	return poly[0].distance_to(poly[1])


## The edge whose midpoint lies furthest back. On an even-sided plan it is the
## flat opposite the gate; on an odd-sided one it is one of the two edges
## meeting at the back vertex.
static func back_edge_index(poly: PackedVector2Array) -> int:
	var best := -INF
	var idx := 0
	for i in range(poly.size()):
		var m: float = (poly[i].y + poly[(i + 1) % poly.size()].y) / 2.0
		if m > best:
			best = m
			idx = i
	return idx


## Every run of curtain in ring `r`, outer face first, as
##   {"name": StringName, "a": Vector2, "b": Vector2, "outward": Vector3,
##    "yaw": float, "length": float, "edge": int}
## `a` and `b` are the ends of the run's OUTER face at wall-top level. The gate
## splits the front edge in two, and a slanted edge is cut into a staircase of
## shorter runs: a diagonal wall's true AABB is a box far larger than the wall,
## and the massing rules measure AABBs.
static func wall_segments(spec: CastleSpec, r: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var poly: PackedVector2Array = enceinte_polygon(spec, r)
	var n: int = poly.size()
	var back_i: int = back_edge_index(poly)
	var gw: float = gate_width(spec, r)
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var base := "e%d" % i
		if i == 0:
			base = "front"
		elif i == back_i:
			base = "back"
		var runs: Array = [[a, b, base]]
		if i == 0 and gw > 0.0:
			runs = [[a, Vector2(-gw / 2.0, a.y), "front_left"],
				[Vector2(gw / 2.0, b.y), b, "front_right"]]
		for run in runs:
			var ra: Vector2 = run[0]
			var rb: Vector2 = run[1]
			var flat: bool = absf(ra.x - rb.x) < 0.001 or absf(ra.y - rb.y) < 0.001
			var run_len: float = ra.distance_to(rb)
			if run_len < MIN_WALL_RUN:
				continue
			var steps: int = 1 if flat else clampi(int(run_len / WALL_STEP) + 1,
				1, WALL_STEPS_MAX)
			for k in range(steps):
				var sa: Vector2 = ra.lerp(rb, float(k) / float(steps))
				var sb: Vector2 = ra.lerp(rb, float(k + 1) / float(steps))
				var o: Vector2 = edge_outward(ra, rb)
				out.append({
					"name": StringName(run[2] if k == 0 else "%s_s%d" % [run[2], k]),
					"a": sa, "b": sb, "outward": Vector3(o.x, 0.0, o.y),
					"yaw": atan2(o.x, o.y), "length": sa.distance_to(sb), "edge": i,
				})
	return out


## Centre of a run's base course: the widest the run ever is, with its INNER
## face pinned exactly where the wall-top face sits.
static func segment_base_center(spec: CastleSpec, r: int, seg: Dictionary) -> Vector3:
	var t: float = wall_thickness(spec, r)
	var tb: float = wall_base_thickness(spec, r)
	var o: Vector3 = seg["outward"]
	var m: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var d: float = tb / 2.0 - t
	return Vector3(m.x + o.x * d, 0.0, m.y + o.z * d)


## World AABB of a wall run, base course included -- what gets logged as its
## structural mass.
static func segment_aabb(spec: CastleSpec, r: int, seg: Dictionary) -> AABB:
	var c: Vector3 = segment_base_center(spec, r, seg)
	var tb: float = wall_base_thickness(spec, r)
	var yaw: float = seg["yaw"]
	var along: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw)) * (float(seg["length"]) / 2.0)
	var out: Vector3 = (seg["outward"] as Vector3) * (tb / 2.0)
	var lo := Vector3(INF, 0.0, INF)
	var hi := Vector3(-INF, wall_height(spec, r), -INF)
	for sa in [-1.0, 1.0]:
		for so in [-1.0, 1.0]:
			var p: Vector3 = c + along * sa + out * so
			lo.x = minf(lo.x, p.x)
			lo.z = minf(lo.z, p.z)
			hi.x = maxf(hi.x, p.x)
			hi.z = maxf(hi.z, p.z)
	return AABB(lo, hi - lo)


## Towers at the vertices of a polygonal enceinte. Their inner face is pinned to
## the wall's inner face, so the whole tower stands proud of the curtain the way
## a mural tower does. For N = 4 these ARE the corner towers.
static func vertex_tower_centers(spec: CastleSpec, r: int) -> Array[Vector3]:
	if not is_polygonal(spec):
		return corner_tower_centers(spec, r)
	var out: Array[Vector3] = []
	if not spec.corner_towers:
		return out
	var poly: PackedVector2Array = enceinte_polygon(spec, r)
	var n: int = poly.size()
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	for i in range(n):
		var v: Vector2 = poly[i]
		var n0: Vector2 = edge_outward(poly[(i + n - 1) % n], v)
		var n1: Vector2 = edge_outward(v, poly[(i + 1) % n])
		var bis: Vector2 = (n0 + n1).normalized()
		out.append(Vector3(v.x + bis.x * (s - t), 0.0, v.y + bis.y * (s - t)))
	return out


# ------------------------------------------------------------------- walls

## Plan rectangle of ring `r`, at wall-top level: position = (x0, z0).
static func enceinte_rect(spec: CastleSpec, r: int) -> Rect2:
	var site := Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))
	if r <= 0:
		return site
	return site.grow(-spec.ward_gap)


static func wall_height(spec: CastleSpec, r: int) -> float:
	return spec.height * (INNER_HEIGHT_RATIO if r > 0 else 1.0)


static func wall_thickness(spec: CastleSpec, r: int) -> float:
	return spec.wall_thickness * (INNER_THICK_RATIO if r > 0 else 1.0)


## How far the talus spreads outward at the foot of a mass `h` tall.
static func batter_spread(spec: CastleSpec, h: float) -> float:
	return h * spec.batter


## Thickness of a wall at its foot, batter included. The inner face is vertical
## at every height, so nothing inside the bailey has to know about the talus.
static func wall_base_thickness(spec: CastleSpec, r: int) -> float:
	return wall_thickness(spec, r) + batter_spread(spec, wall_height(spec, r))


## The gap the gatehouse occupies in the front wall of ring `r`.
static func gate_width(spec: CastleSpec, r: int) -> float:
	if not spec.gatehouse:
		return 0.0
	var gw: float = spec.gate_width
	if r > 0:
		gw *= 0.8
	return minf(gw, max_gate_width(spec, r))


## Widest gate this ring can carry and still leave a run of wall either side of
## it, clear of the corner towers.
static func max_gate_width(spec: CastleSpec, r: int) -> float:
	var run: float = enceinte_rect(spec, r).size.x
	if is_polygonal(spec):
		run = front_edge_length(spec, r)
	var corner: float = 2.0 * tower_base_half(spec, r) + MIN_WALL_RUN
	return maxf(run - 2.0 * corner, 2.0)


static func gate_depth(spec: CastleSpec, r: int) -> float:
	return maxf(spec.gate_depth, wall_thickness(spec, r) + GATE_DEPTH_MIN)


## A wall run as its BASE footprint -- the widest it ever is.
##   which: &"front_left", &"front_right", &"front", &"back", &"left", &"right"
## Front and back run the full width; the sides run between them, so abutting
## runs touch at their faces instead of interpenetrating at the corners.
static func wall_aabb(spec: CastleSpec, r: int, which: StringName) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var tb: float = wall_base_thickness(spec, r)
	var h: float = wall_height(spec, r)
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var z0: float = rect.position.y
	var z1: float = rect.end.y
	var gw: float = gate_width(spec, r)
	match which:
		&"front":
			return AABB(Vector3(x0, 0.0, z0 + t - tb), Vector3(rect.size.x, h, tb))
		&"front_left":
			return AABB(Vector3(x0, 0.0, z0 + t - tb),
				Vector3((x1 - x0 - gw) / 2.0, h, tb))
		&"front_right":
			return AABB(Vector3(x0 + (x1 - x0 + gw) / 2.0, 0.0, z0 + t - tb),
				Vector3((x1 - x0 - gw) / 2.0, h, tb))
		&"back":
			return AABB(Vector3(x0, 0.0, z1 - t), Vector3(rect.size.x, h, tb))
		&"left":
			return AABB(Vector3(x0 + t - tb, 0.0, z0 + t),
				Vector3(tb, h, rect.size.y - 2.0 * t))
		&"right":
			return AABB(Vector3(x1 - t, 0.0, z0 + t),
				Vector3(tb, h, rect.size.y - 2.0 * t))
	return AABB()


## Which wall runs ring `r` actually has: the front is split in two by a gate.
static func wall_names(spec: CastleSpec, r: int) -> Array[StringName]:
	if is_polygonal(spec):
		var poly_names: Array[StringName] = []
		for seg in wall_segments(spec, r):
			poly_names.append(seg["name"])
		return poly_names
	var out: Array[StringName] = [&"back", &"left", &"right"]
	if gate_width(spec, r) > 0.0:
		out.append(&"front_left")
		out.append(&"front_right")
	else:
		out.append(&"front")
	return out


# ------------------------------------------------------------------ towers

## Half-plan-size of a tower at its top: the radius of a drum, half the side of
## a square one.
static func tower_half(spec: CastleSpec, r: int) -> float:
	return spec.tower_size * (0.85 if r > 0 else 1.0)


static func tower_height(spec: CastleSpec, r: int) -> float:
	return spec.tower_height * (INNER_HEIGHT_RATIO if r > 0 else 1.0)


## Half-plan-size at the foot. The tower's inner face is pinned to the wall's
## inner face at the BASE, so the talus spreads outward into the open air and
## never intrudes on the bailey behind it.
##
## The spread is capped at a third of the tower: a wall is short and long, so
## the same batter that gives it a convincing talus turned a tall tower into a
## cooling tower, splayed twice as wide at the foot as at the parapet.
static func tower_base_half(spec: CastleSpec, r: int) -> float:
	var half: float = tower_half(spec, r)
	return half + minf(batter_spread(spec, tower_height(spec, r)), half * TOWER_BATTER_CAP)


## Number of sides the tower shell is revolved with. A square tower is a
## 4-segment revolve and a polygonal one an 8; keeping all three shapes on one
## primitive is why they cannot drift apart.
static func tower_sides(spec: CastleSpec) -> int:
	match spec.tower_shape:
		&"square":
			return 4
		&"polygonal":
			return 8
	return 12


## Rotation that puts a flat face outward rather than a corner.
static func tower_rotation(spec: CastleSpec) -> float:
	return PI / float(tower_sides(spec))


## Circumradius for a tower whose half-plan-size (apothem) is `half`.
static func tower_radius_for(spec: CastleSpec, half: float) -> float:
	return half / cos(PI / float(tower_sides(spec)))


## Corner towers of ring `r`, base centres, in the order SW, SE, NW, NE.
static func corner_tower_centers(spec: CastleSpec, r: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not spec.corner_towers:
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = (rect.end.x - t + s) if sx > 0.0 else (rect.position.x + t - s)
			var z: float = (rect.end.y - t + s) if sz > 0.0 else (rect.position.y + t - s)
			out.append(Vector3(x, 0.0, z))
	return out


## Mural towers studding the long walls between the corners, as
## {"pos": Vector3, "facing": Vector3}. Only the +/-X walls carry them: the back
## wall is where the keep stands and the front wall is where the gate is.
static func side_tower_slots(spec: CastleSpec, r: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if spec.side_towers <= 0 or is_polygonal(spec):
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	# keep clear of the corner towers at both ends of the run
	var margin: float = 2.0 * s + MIN_WALL_RUN
	var z0: float = rect.position.y + margin
	var z1: float = rect.end.y - margin
	if z1 - z0 < 2.0 * s:
		return out
	# Only as many as the run can actually carry. Spacing the requested count
	# evenly regardless is how six towers ended up sharing four towers' worth of
	# wall, each one buried in its neighbour.
	var pitch: float = 2.0 * s + MIN_WALL_RUN
	var n: int = mini(spec.side_towers, int((z1 - z0) / pitch) + 1)
	if n <= 0:
		return out
	for i in range(n):
		var f: float = 0.5 if n == 1 else float(i) / float(n - 1)
		var z: float = lerpf(z0, z1, f)
		for sx in [-1.0, 1.0]:
			var x: float = (rect.end.x - t + s) if sx > 0.0 else (rect.position.x + t - s)
			out.append({"pos": Vector3(x, 0.0, z), "facing": Vector3(sx, 0.0, 0.0)})
	return out


## Clear ground a second enceinte needs between it and the first: enough that
## the inner ring's towers, which project outward from their own wall, stop
## short of the outer ring's.
static func min_ward_gap(spec: CastleSpec) -> float:
	var base: float = _ward_gap_flat(spec)
	if not is_polygonal(spec):
		return base
	# The inner ring is the outer one scaled, so a vertex travels inward along
	# its own diagonal: widening the gap by a metre may move two facing towers
	# barely half of that apart on either axis. This solves, per vertex, the
	# gap at which the two towers' footprints finally clear each other -- the
	# rings' towers meeting in the middle of the ward is what the no-overlap
	# rule caught on a hexagon.
	var s0: float = tower_base_half(spec, 0)
	var s1: float = tower_base_half(spec, 1)
	# how much further out the outer ring's tower stands than the inner's
	var c: float = (s0 - wall_thickness(spec, 0)) - (s1 - wall_thickness(spec, 1))
	var want: float = s0 + s1 + 0.25
	var poly: PackedVector2Array = enceinte_polygon(spec, 0)
	var n: int = poly.size()
	var need := 0.0
	for i in range(n):
		var v: Vector2 = poly[i]
		var u := Vector2(v.x * 2.0 / maxf(spec.width, 0.001),
			v.y * 2.0 / maxf(spec.length, 0.001))
		var bis: Vector2 = (edge_outward(poly[(i + n - 1) % n], v)
			+ edge_outward(v, poly[(i + 1) % n])).normalized()
		# clearing on EITHER axis is enough to separate two boxes
		var g := INF
		for a in range(2):
			if absf(u[a]) < 0.001:
				continue
			g = minf(g, maxf((want - bis[a] * signf(u[a]) * c) / absf(u[a]), 0.0))
		if not is_inf(g):
			need = maxf(need, g)
	return maxf(base, need)


## The gap two axis-aligned rings need: the inner ring's towers project
## outward from their own wall and must stop short of the outer one's.
static func _ward_gap_flat(spec: CastleSpec) -> float:
	return 2.0 * tower_base_half(spec, 1) + wall_thickness(spec, 1) \
		- wall_thickness(spec, 0) + MIN_WALL_RUN


## Base footprint of a tower centred at `c`.
static func tower_aabb(spec: CastleSpec, r: int, c: Vector3) -> AABB:
	var s: float = tower_base_half(spec, r)
	return AABB(Vector3(c.x - s, 0.0, c.z - s),
		Vector3(s * 2.0, tower_height(spec, r), s * 2.0))


## Rise of whatever caps a tower, above its parapet.
static func tower_roof_rise(spec: CastleSpec, r: int) -> float:
	var d: float = tower_half(spec, r) * 2.0
	match spec.tower_roof:
		&"cone":
			return d * TOWER_CAP_RATIO * 1.4
		&"pyramid":
			return d * TOWER_CAP_RATIO * 0.8
		&"tiered":
			return d * TOWER_CAP_RATIO
	return PARAPET_RISE


# -------------------------------------------------------------------- gate

## The gatehouse block of ring `r`: it fills the gap in the front wall and
## reaches back into the ward, so the passage runs through solid building.
static func gatehouse_aabb(spec: CastleSpec, r: int) -> AABB:
	var gw: float = gate_width(spec, r)
	if gw <= 0.0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, r)
	var d: float = gate_depth(spec, r)
	return AABB(Vector3(-gw / 2.0, 0.0, rect.position.y),
		Vector3(gw, gate_height(spec, r), d))


static func gate_height(spec: CastleSpec, r: int) -> float:
	return wall_height(spec, r) * 1.25


## The twin drums flanking the passage, base centres.
static func gate_tower_centers(spec: CastleSpec, r: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not spec.gate_towers or gate_width(spec, r) <= 0.0:
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	var gw: float = gate_width(spec, r)
	var z: float = rect.position.y + t - s
	var gx: float = gw / 2.0 + s * 0.7
	if is_polygonal(spec):
		# A polygon's front edge is shorter than the site is wide, and it ends in
		# a vertex tower at each corner. Twin drums that will not fit between
		# those two and the passage are not built: a gatehouse buried in its own
		# corner tower is worse than a plain one.
		if gw < 1.2 * s:
			return out
		for v in vertex_tower_centers(spec, r):
			if absf(absf(v.x) - gx) < 2.0 * s and absf(v.z - z) < 2.0 * s:
				return out
	for sx in [-1.0, 1.0]:
		out.append(Vector3(sx * gx, 0.0, z))
	return out


## Outwork in front of the gate, lapping it so the two read as one defence.
static func barbican_aabb(spec: CastleSpec) -> AABB:
	if not spec.barbican or gate_width(spec, 0) <= 0.0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var gw: float = gate_width(spec, 0)
	var d: float = clampf(spec.length * 0.1, 4.0, 14.0)
	return AABB(Vector3(-gw * 0.42, 0.0, rect.position.y - d),
		Vector3(gw * 0.84, spec.height * 0.6, d + GATE_LAP))


## The walled causeway between the outer and inner gatehouses. Without it the
## inner ward would be a ring of masonry standing free inside another one --
## which is exactly what the no-gaps check is for.
static func gate_link_aabb(spec: CastleSpec, side: float) -> AABB:
	if not spec.inner_ward or gate_width(spec, 1) <= 0.0:
		return AABB()
	var z0: float = enceinte_rect(spec, 0).position.y + gate_depth(spec, 0)
	var z1: float = enceinte_rect(spec, 1).position.y
	if z1 - z0 < 0.5:
		return AABB()
	var gw: float = gate_width(spec, 1)
	# The two walls flank the passage, so each may be at most a third of it:
	# sized off the curtain alone they met in the middle and sealed the way in.
	var th: float = clampf(spec.wall_thickness * 0.7, 0.4, gw * 0.3)
	var x: float = side * (gw / 2.0 - th / 2.0)
	return AABB(Vector3(x - th / 2.0, 0.0, z0), Vector3(th, spec.height * 0.7, z1 - z0))


# ---------------------------------------------------------- ground inside

## The open ground inside the innermost enceinte: everything a bailey holds is
## placed relative to this. For an unenclosed tier it is the site itself.
static func bailey_rect(spec: CastleSpec) -> Rect2:
	if not is_enclosed(spec):
		return enceinte_rect(spec, 0)
	var r: int = inner_ring(spec)
	if is_polygonal(spec):
		return max_inscribed_rect(inner_polygon(spec, r))
	return enceinte_rect(spec, r).grow(-wall_thickness(spec, r))


## The deepest z a block `half_w` wide and centred on the axis can reach before
## it meets the inner face of the ward wall. On a rectangle that is simply the
## back of the bailey; on a polygon the back narrows, so a keep has to be told
## how wide it is before it can be told how far back it may stand.
static func ward_back_z(spec: CastleSpec, half_w: float) -> float:
	var b: Rect2 = bailey_rect(spec)
	if not is_enclosed(spec) or not is_polygonal(spec):
		return b.end.y
	var poly: PackedVector2Array = inner_polygon(spec, inner_ring(spec))
	var limit: float = polygon_bbox(poly).size.x / 2.0 - 0.01
	var span: Vector2 = poly_z_span(poly, minf(half_w, limit))
	return maxf(span.y, b.end.y)


## The x of the ward's side wall on `side`, over the z band [z0, z1]. A range
## built against a slanted wall has to follow that wall, not the bailey box.
static func ward_edge_x(spec: CastleSpec, side: float, z0: float, z1: float) -> float:
	var b: Rect2 = bailey_rect(spec)
	if not is_enclosed(spec) or not is_polygonal(spec):
		return b.end.x if side > 0.0 else b.position.x
	var poly: PackedVector2Array = inner_polygon(spec, inner_ring(spec))
	var hw: float = minf(poly_half_width(poly, z0), poly_half_width(poly, z1))
	return side * maxf(hw, b.size.x / 2.0)


# -------------------------------------------------------------------- keep

## The keep stands against the back wall of the bailey, lapping it.
static func keep_aabb(spec: CastleSpec) -> AABB:
	if not spec.keep:
		return AABB()
	var z1: float = ward_back_z(spec, spec.keep_w / 2.0) + RANGE_LAP
	return AABB(Vector3(-spec.keep_w / 2.0, 0.0, z1 - spec.keep_l),
		Vector3(spec.keep_w, spec.keep_height, spec.keep_l))


## Largest keep footprint the bailey can hold and still leave a courtyard.
static func max_keep_size(spec: CastleSpec) -> Vector2:
	var b: Rect2 = bailey_rect(spec)
	return Vector2(maxf(b.size.x - 2.0 * BAILEY_CLEAR, 2.0),
		maxf(b.size.y * 0.45, 2.0))


## The great hall range: against the west wall, running back to meet the keep,
## so every interior building is tied into the assembly.
static func hall_aabb(spec: CastleSpec) -> AABB:
	if not spec.hall:
		return AABB()
	if not is_enclosed(spec):
		return house_range_aabb(spec)
	var z1: float = interior_back_z(spec)
	var x0: float = ward_edge_x(spec, -1.0, z1 - spec.hall_l, z1) - RANGE_LAP
	return AABB(Vector3(x0, 0.0, z1 - spec.hall_l),
		Vector3(spec.hall_w, spec.hall_height, spec.hall_l))


## Mirror of the hall on the east side, half its length: the chapel range.
static func chapel_aabb(spec: CastleSpec) -> AABB:
	if not spec.chapel or not is_enclosed(spec):
		return AABB()
	var l: float = maxf(spec.hall_l * 0.55, 3.0)
	var z1: float = interior_back_z(spec)
	var x1: float = ward_edge_x(spec, 1.0, z1 - l, z1) + RANGE_LAP
	return AABB(Vector3(x1 - spec.hall_w, 0.0, z1 - l),
		Vector3(spec.hall_w, spec.hall_height * 0.85, l))


## The plane interior ranges start from: the keep's front face when there is a
## keep, otherwise the back of the bailey.
static func interior_back_z(spec: CastleSpec) -> float:
	if spec.keep:
		return keep_aabb(spec).position.z
	return bailey_rect(spec).end.y + RANGE_LAP


## Longest interior range the bailey can hold in front of the keep.
static func max_range_length(spec: CastleSpec) -> float:
	var b: Rect2 = bailey_rect(spec)
	var back: float = interior_back_z(spec)
	return maxf(back - b.position.y - BAILEY_CLEAR, 2.0)


# ---------------------------------------------------------- house and manor

## The single block a house is, or the main range across the back of a manor.
static func house_range_aabb(spec: CastleSpec) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, 0)
	if spec.tier == &"house":
		return AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, spec.height, rect.size.y))
	var d: float = manor_range_depth(spec)
	return AABB(Vector3(rect.position.x, 0.0, rect.end.y - d),
		Vector3(rect.size.x, spec.height, d))


static func manor_range_depth(spec: CastleSpec) -> float:
	return clampf(spec.length * MANOR_RANGE_DEPTH, 5.0, spec.length * 0.5)


static func manor_wing_width(spec: CastleSpec) -> float:
	return clampf(spec.width * MANOR_WING_W, 4.0, spec.width * 0.35)


## A cross wing running forward from the main range down one side of the court.
static func manor_wing_aabb(spec: CastleSpec, side: float) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, 0)
	var ww: float = manor_wing_width(spec)
	var z1: float = rect.end.y - manor_range_depth(spec) + WING_LAP
	var x: float = (rect.end.x - ww) if side > 0.0 else rect.position.x
	return AABB(Vector3(x, 0.0, rect.position.y),
		Vector3(ww, spec.height, z1 - rect.position.y))


## The lower front range that closes a courtyard manor's fourth side.
static func manor_front_range_aabb(spec: CastleSpec) -> AABB:
	if not spec.courtyard:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var ww: float = manor_wing_width(spec) if spec.wings > 0 else 0.0
	var d: float = clampf(spec.length * 0.16, 4.0, 12.0)
	return AABB(Vector3(rect.position.x + ww - WING_LAP, 0.0, rect.position.y),
		Vector3(rect.size.x - 2.0 * (ww - WING_LAP), spec.height * 0.75, d))


## Entrance block. A courtyard manor puts it through the front range; an open
## court puts a porch on the main range, facing the court.
static func porch_aabb(spec: CastleSpec) -> AABB:
	if is_enclosed(spec):
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var pw: float = clampf(spec.width * 0.18, 2.0, 6.0)
	if spec.tier == &"house":
		return AABB(Vector3(-pw / 2.0, 0.0, rect.position.y - PORCH_DEPTH),
			Vector3(pw, spec.height * 0.55, PORCH_DEPTH + WING_LAP))
	if spec.courtyard:
		var fr: AABB = manor_front_range_aabb(spec)
		return AABB(Vector3(-pw / 2.0, 0.0, fr.position.z - PORCH_DEPTH),
			Vector3(pw, spec.height * 0.9, PORCH_DEPTH + fr.size.z))
	var mr: AABB = house_range_aabb(spec)
	return AABB(Vector3(-pw / 2.0, 0.0, mr.position.z - PORCH_DEPTH),
		Vector3(pw, spec.height * 0.8, PORCH_DEPTH + WING_LAP))


## A service annexe off the front corner of a house. It sits at the front
## because the chimney stacks run up the back wall, and two masses fighting for
## the same corner is how a generator produces a house with a flue inside its
## pantry.
static func annexe_aabb(spec: CastleSpec) -> AABB:
	if spec.tier != &"house" or spec.wings <= 0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var aw: float = rect.size.x * HOUSE_ANNEXE_W
	var al: float = rect.size.y * HOUSE_ANNEXE_L
	return AABB(Vector3(rect.end.x - WING_LAP, 0.0, rect.position.y),
		Vector3(aw, spec.height * 0.7, al))


## Which sides a manor's cross wings stand on: one wing takes the west side.
static func wing_sides(spec: CastleSpec) -> Array[float]:
	var out: Array[float] = []
	if spec.wings <= 0:
		return out
	out.append(-1.0)
	if spec.wings >= 2:
		out.append(1.0)
	return out


## Towers at the front ends of a manor's cross wings -- the "castle" half of a
## fortified manor house like Stokesay.
static func manor_tower_centers(spec: CastleSpec) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if is_enclosed(spec) or not spec.corner_towers or spec.wings <= 0:
		return out
	var s: float = tower_base_half(spec, 0)
	for side in wing_sides(spec):
		var wing: AABB = manor_wing_aabb(spec, side)
		out.append(Vector3(wing.position.x + wing.size.x / 2.0, 0.0,
			wing.position.z + s * 0.6))
	return out


## How many stacks the back wall can carry without them touching. A stack is
## CHIMNEY_W across and wants that much air either side of it.
static func max_chimneys(spec: CastleSpec) -> int:
	var host: AABB = house_range_aabb(spec)
	var usable: float = host.size.x - 2.0 * CHIMNEY_W
	return maxi(int(usable / (CHIMNEY_W * 2.0)), 1)


## External chimney stacks. They run from the ground up the outer face of the
## block they serve, which is both what a stone stack does and what keeps every
## mass standing on the ground.
static func chimney_aabb(spec: CastleSpec, i: int) -> AABB:
	var host: AABB = house_range_aabb(spec)
	var n: int = maxi(spec.chimneys, 1)
	var f: float = (float(i) + 1.0) / (float(n) + 1.0)
	var x: float = lerpf(host.position.x + CHIMNEY_W,
		host.position.x + host.size.x - CHIMNEY_W, f)
	var top: float = host.size.y + roof_rise(spec, host) + CHIMNEY_RISE
	return AABB(Vector3(x - CHIMNEY_W / 2.0, 0.0,
		host.position.z + host.size.z - WING_LAP), Vector3(CHIMNEY_W, top, CHIMNEY_W))


## Ridge rise of the roof over a block, measured over its SHORT axis: a roof
## spans the short way, which is what makes a long range read as a range.
static func roof_rise(spec: CastleSpec, a: AABB) -> float:
	return minf(a.size.x, a.size.z) * spec.roof_pitch * 0.5


## True when the block's ridge runs along X rather than Z.
static func ridge_along_x(a: AABB) -> bool:
	return a.size.x > a.size.z


# ----------------------------------------------------------------- envelope

## Tallest point of the whole design.
static func total_height(spec: CastleSpec) -> float:
	var top: float = spec.height
	if is_enclosed(spec):
		for r in rings(spec):
			top = maxf(top, wall_height(spec, r) + PARAPET_RISE + spec.merlon_h)
			top = maxf(top, tower_height(spec, r) + tower_roof_rise(spec, r))
			if gate_width(spec, r) > 0.0:
				top = maxf(top, gate_height(spec, r) + PARAPET_RISE + spec.merlon_h)
	if spec.keep:
		top = maxf(top, spec.keep_height + roof_rise(spec, keep_aabb(spec)))
	for a in [house_range_aabb(spec), hall_aabb(spec), chapel_aabb(spec)]:
		if a.size.y > 0.0:
			top = maxf(top, a.size.y + roof_rise(spec, a))
	if spec.chimneys > 0 and not is_enclosed(spec):
		top = maxf(top, chimney_aabb(spec, 0).size.y)
	if not manor_tower_centers(spec).is_empty():
		top = maxf(top, tower_height(spec, 0) + tower_roof_rise(spec, 0))
	return top


## Everything the design covers in plan, batter and towers included.
static func plan_extent(spec: CastleSpec) -> Rect2:
	var e: Rect2 = enceinte_rect(spec, 0)
	if is_enclosed(spec):
		e = e.grow(batter_spread(spec, wall_height(spec, 0)))
		var s: float = tower_base_half(spec, 0)
		var spots: Array[Vector3] = vertex_tower_centers(spec, 0)
		spots.append_array(gate_tower_centers(spec, 0))
		for slot in side_tower_slots(spec, 0):
			spots.append(slot["pos"])
		for c in spots:
			e = e.expand(Vector2(c.x - s, c.z - s))
			e = e.expand(Vector2(c.x + s, c.z + s))
	var ms: float = tower_base_half(spec, 0)
	for c in manor_tower_centers(spec):
		e = e.expand(Vector2(c.x - ms, c.z - ms))
		e = e.expand(Vector2(c.x + ms, c.z + ms))
	for a in [barbican_aabb(spec), porch_aabb(spec), annexe_aabb(spec)]:
		if a.size.x <= 0.0:
			continue
		e = e.expand(Vector2(a.position.x, a.position.z))
		e = e.expand(Vector2(a.position.x + a.size.x, a.position.z + a.size.z))
	if spec.chimneys > 0 and not is_enclosed(spec):
		var ch: AABB = chimney_aabb(spec, 0)
		e = e.expand(Vector2(ch.position.x, ch.position.z + ch.size.z))
	return e
