class_name GroundFall
extends RefCounted
## The ground a building stands on when it is not flat (VTER-HOUSE-SLOPE).
##
## A building is asked for with two numbers (`BuildingRequest.ground_fall_m`
## and `ground_downhill_deg`): how far the ground falls across its footprint,
## and which way. This is the one place that turns them into a ground the
## builders can meet, and into the parts they meet it with.
##
## THE SITE MODEL. Building-local frame, +X right, +Y up, front = -Z.
##   * The footprint is the requested width x length rectangle centred on the
##     origin (for a house that is exactly `HouseGeometry.site_rect`).
##   * y = 0 is the ground at the footprint's UPHILL-most point, and the
##     building's own floor stays where it always was. Nothing above y = 0
##     moves: a sloping building is the flat building plus what stands under it.
##   * The ground is a plane falling linearly from 0 at the uphill-most point
##     of the footprint to -fall at the downhill-most point, and on downhill
##     past the footprint at the same gradient.
##   * Uphill of the footprint the site is CUT LEVEL at y = 0 (the yard is dug
##     to the floor), so `ground_y` never rises above 0. A village laying the
##     building on real terrain places its origin at the uphill ground.
##   * `downhill_deg` is measured in plan, clockwise seen from above with the
##     front at the top: 0 = downhill toward the front (-Z), 90 = toward +X,
##     180 = toward the back (+Z), 270 = toward -X.
##
## THE PARTS. Every part is a vertical prism whose bottom follows the ground
## (the lower of its two faces), built as stacked COURSES of `COURSE` metres:
## a foundation never floats and never needs a slab hung in the air. The
## steps from a door down to the ground are planned here too, so the builder,
## the walk export and the slope suite all read one flight.

## One masonry course of a stepped foundation, metres.
const COURSE := 0.30
## Steepest rise between two treads a walker is asked to take.
const RISER := 0.17
const TREAD := 0.30
const FLIGHT_W := 1.0
const LANDING_DEPTH := 1.0
const LANDING_EXTRA := 0.30   # each side of the door leaf
## Never more steps than this in one flight; a longer one is infeasible.
const MAX_STEPS := 40
## Below this a fall is flat: no part is emitted and nothing moves.
const FLAT := 0.005
## A building refuses ground steeper than 1 in 2 across its footprint.
const MAX_GRADIENT := 0.5
## Fall bands (metres) for the plan families: up to PLINTH_MAX a stepped
## plinth, to one storey a raised floor, to two a bank storey (HouseSlope).
const PLINTH_MAX := 1.2

var fall := 0.0
var downhill_deg := 0.0
var dir := Vector2(0.0, -1.0)
var footprint := Rect2()
var _s0 := 0.0
var _s1 := 1.0


## Null when the ground is flat: callers test for null and emit nothing, which
## is what keeps every flat building byte-identical.
static func make(p_fall: float, p_deg: float, p_footprint: Rect2) -> GroundFall:
	if not is_finite(p_fall) or p_fall <= FLAT or p_footprint.size.x <= 0.0 \
			or p_footprint.size.y <= 0.0:
		return null
	var g := GroundFall.new()
	g.fall = p_fall
	g.downhill_deg = p_deg
	g.dir = downhill_vector(p_deg)
	g.footprint = p_footprint
	var lo := INF
	var hi := -INF
	for c in corners(p_footprint):
		var s: float = c.dot(g.dir)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	if hi - lo < 1e-6:
		return null
	g._s0 = lo
	g._s1 = hi
	return g


## The ground of a spec that carries `ground_fall` / `ground_downhill_deg`
## (HouseSpec, ShopSpec, ChurchSpec), over its own requested rectangle.
static func of_spec(spec: Object) -> GroundFall:
	if spec == null:
		return null
	var f: Variant = spec.get("ground_fall")
	if f == null or float(f) <= FLAT:
		return null
	var w := float(spec.get("width"))
	var l := float(spec.get("length"))
	return make(float(f), float(spec.get("ground_downhill_deg")),
		Rect2(Vector2(-w * 0.5, -l * 0.5), Vector2(w, l)))


static func downhill_vector(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r), -cos(r))


static func corners(r: Rect2) -> Array[Vector2]:
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]


## The span of a w x l rectangle along a downhill direction.
static func extent(w: float, l: float, deg: float) -> float:
	var d := downhill_vector(deg)
	return absf(d.x) * w + absf(d.y) * l


## The reason a fall cannot be built, or "" when it can. `max_fall` is the
## family's own ceiling (two storeys for a house, a terrace for a church).
static func refusal(p_fall: float, w: float, l: float, deg: float, max_fall: float) -> String:
	if not is_finite(p_fall) or p_fall < 0.0:
		return "ground_fall_m must be a finite number of metres, 0 or more."
	if not is_finite(deg):
		return "ground_downhill_deg must be a finite angle in degrees."
	if p_fall <= FLAT:
		return ""
	if p_fall > max_fall + 1e-6:
		return "a fall of %.2f m is more than this building can stand on (%.2f m at most)." % [p_fall, max_fall]
	var span := extent(w, l, deg)
	if span > 0.0 and p_fall / span > MAX_GRADIENT + 1e-6:
		return "a fall of %.2f m across %.2f m is steeper than 1 in 2." % [p_fall, span]
	return ""


## Ground height at a plan point: 0 uphill of the footprint, the plane across
## it, and still falling beyond it downhill.
func ground_y(p: Vector2) -> float:
	return minf(0.0, plane_y(p))


## The falling plane itself, unclamped: above 0 uphill of the footprint. A
## part whose top is at or below 0 is clipped against this, because it is
## linear along a run and the cut ground uphill is above such a top anyway.
func plane_y(p: Vector2) -> float:
	var t: float = (p.dot(dir) - _s0) / (_s1 - _s0)
	return -fall * t


## Metres of fall per metre of plan.
func gradient() -> float:
	return fall / (_s1 - _s0)


## The lower of the ground under the two faces of a prism `thick` wide whose
## centre plane runs through `p` with horizontal normal `n`.
func ground_lo(p: Vector2, n: Vector2, thick: float, clamped := true) -> float:
	var h := n * (thick * 0.5)
	if not clamped:
		return minf(plane_y(p + h), plane_y(p - h))
	return minf(ground_y(p + h), ground_y(p - h))


# ---------------------------------------------------------------- the parts

## The coursed prism under one straight run: along `from`->`to` (the centre
## line), `thick` across, from `top_y` down to the ground. Returns the course
## polygons as {"points": PackedVector3Array (centre plane), "depth": thick}
## -- each convex, so MeshKit.slab_poly can fan it -- lowest course last.
func coursed_prism(from: Vector2, to: Vector2, thick: float, top_y: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seg := to - from
	var length := seg.length()
	if length < 0.01:
		return out
	var along := seg / length
	var n := Vector2(-along.y, along.x)
	var g0 := ground_lo(from, n, thick, false)
	var g1 := ground_lo(to, n, thick, false)
	var deepest := minf(g0, g1)
	if top_y - deepest < 0.01:
		return out
	var k := 0
	while true:
		var band_top: float = top_y - COURSE * k
		var band_bot: float = band_top - COURSE
		if band_top <= deepest + 0.005:
			break
		var poly := _clip_band(from, to, g0, g1, band_bot, band_top)
		if poly.size() >= 3:
			out.append({"points": poly, "depth": thick})
		k += 1
		if k > 64:
			break
	return out


## The part of the band y in [lo, hi] above the ground line g(t) = lerp(g0,
## g1, t) along from->to, as a convex polygon in the vertical centre plane:
## the band's rectangle in (t, y), clipped by the half-plane y >= g(t).
static func _clip_band(from: Vector2, to: Vector2, g0: float, g1: float,
		lo: float, hi: float) -> PackedVector3Array:
	var rect: Array[Vector2] = [Vector2(0.0, lo), Vector2(1.0, lo),
		Vector2(1.0, hi), Vector2(0.0, hi)]
	var kept: Array[Vector2] = []
	for i in rect.size():
		var p: Vector2 = rect[i]
		var q: Vector2 = rect[(i + 1) % rect.size()]
		var dp: float = p.y - lerpf(g0, g1, p.x)
		var dq: float = q.y - lerpf(g0, g1, q.x)
		if dp >= 0.0:
			kept.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			var t: float = dp / (dp - dq)
			kept.append(p.lerp(q, t))
	var poly := PackedVector3Array()
	for k in kept:
		var p2: Vector2 = from.lerp(to, k.x)
		var v := Vector3(p2.x, k.y, p2.y)
		if poly.is_empty() or poly[poly.size() - 1].distance_to(v) > 1e-5:
			poly.append(v)
	if poly.size() > 1 and poly[0].distance_to(poly[poly.size() - 1]) < 1e-5:
		poly.remove_at(poly.size() - 1)
	# a sliver thinner than a millimetre is not a course
	var ylo := INF
	var yhi := -INF
	for v in poly:
		ylo = minf(ylo, v.y)
		yhi = maxf(yhi, v.y)
	if poly.size() < 3 or yhi - ylo < 0.001:
		return PackedVector3Array()
	return poly


# --------------------------------------------------------------- the flights

## The way from one door down to the ground: a landing at the threshold, then
## a straight flight. Returns {} when the threshold is within one riser of the
## ground (nothing to build), else
##   {"landing": {"centre": Vector2, "axis": Vector2, "length", "width", "top"},
##    "steps": [{"centre": Vector2, "axis": Vector2 (travel), "length" (tread),
##               "width", "top"}],
##    "direction": &"out" | &"left" | &"right" (along the wall, as seen by
##        someone outside facing the door), "rise": float,
##    "route": [Vector3] from the threshold to the foot on the ground,
##    "foot": Vector3, "feasible": bool}
##
## `outer` is the door's centre on the wall's OUTER face, `normal` outward,
## `door_w` the leaf, `threshold` the floor the door opens onto. `apron` is an
## existing deck in front of the door (a porch or veranda) in plan, or an
## empty Rect2: then that deck is the landing and only its support is added.
## `blocked` are plan rectangles a flight must not cross (the footprint, a
## chimney stack, another door's way out). Three directions are tried --
## straight out, and along the wall either way -- and the shortest feasible
## one wins, ties to straight out.
func plan_flight(outer: Vector2, normal: Vector2, door_w: float, threshold: float,
		apron: Rect2, blocked: Array[Rect2]) -> Dictionary:
	normal = normal.normalized()
	var across := Vector2(-normal.y, normal.x)
	var land_w: float = door_w + LANDING_EXTRA * 2.0
	var land_d: float = LANDING_DEPTH
	var land_c: Vector2 = outer + normal * (land_d * 0.5)
	if apron.has_area():
		# the deck's reach in front of the wall and its width across the door
		var reach := 0.0
		var half := 0.0
		for c in corners(apron):
			reach = maxf(reach, (c - outer).dot(normal))
			half = maxf(half, absf((c - outer).dot(across)))
		land_d = maxf(reach, 0.3)
		land_w = half * 2.0
		land_c = outer + normal * (land_d * 0.5)
	var landing := {"centre": land_c, "axis": normal, "length": land_d,
		"width": land_w, "top": threshold, "apron": apron.has_area()}
	var best := {}
	for option in [[&"out", normal], [&"left", across], [&"right", -across]]:
		var d: Vector2 = option[1]
		var start: Vector2
		var strip: float = FLIGHT_W
		if option[0] == &"out":
			start = outer + normal * land_d
		else:
			# along the wall, hugging it: the flight's strip is the landing's
			# first metre in front of the wall
			strip = minf(FLIGHT_W, land_d)
			start = outer + d * (land_w * 0.5) + normal * (strip * 0.5)
		var f := _march(start, d, threshold, strip, blocked)
		if f.is_empty():
			continue
		f["direction"] = option[0]
		if best.is_empty() or f["steps"].size() < best["steps"].size():
			best = f
	var landing_ground := ground_lo(land_c, across, land_w)
	landing_ground = minf(landing_ground, ground_lo(land_c, normal, land_d))
	if best.is_empty():
		# no direction is clear: go straight out regardless, and say so
		best = _march(outer + normal * land_d, normal, threshold, FLIGHT_W, [])
		if best.is_empty():
			return {}
		best["direction"] = &"out"
		best["feasible"] = false
	else:
		best["feasible"] = true
	if best["steps"].is_empty() and threshold - landing_ground <= RISER + 0.01 \
			and not apron.has_area():
		return {}
	best["landing"] = landing
	best["rise"] = threshold - float(best["foot"].y)
	var route: Array[Vector3] = [Vector3(outer.x, threshold, outer.y),
		Vector3(land_c.x, threshold, land_c.y)]
	for s in best["steps"]:
		var c: Vector2 = s["centre"]
		route.append(Vector3(c.x, float(s["top"]), c.y))
	route.append(best["foot"])
	best["route"] = route
	return best


## Walk a flight from `start` (at the landing's edge) along `d`, one riser per
## tread, until the ground is within a riser. {} if it would not get there.
func _march(start: Vector2, d: Vector2, top: float, width: float,
		blocked: Array[Rect2]) -> Dictionary:
	var steps: Array[Dictionary] = []
	var y := top
	var pos := start
	var across := Vector2(-d.y, d.x)
	for k in range(MAX_STEPS + 1):
		var g_here: float = ground_lo(pos, across, width)
		if y - g_here <= RISER + 0.01:
			var stand: Vector2 = pos + d * 0.15
			return {"steps": steps, "foot": Vector3(stand.x, ground_y(stand), stand.y)}
		if k == MAX_STEPS:
			return {}
		var centre: Vector2 = pos + d * (TREAD * 0.5)
		var rect := _plan_rect(centre, d, TREAD, width)
		for b in blocked:
			if b.grow(-0.01).intersects(rect):
				return {}
		y -= RISER
		steps.append({"centre": centre, "axis": d, "length": TREAD, "width": width, "top": y})
		pos += d * TREAD
	return {}


static func _plan_rect(centre: Vector2, axis: Vector2, length: float, width: float) -> Rect2:
	var across := Vector2(-axis.y, axis.x)
	var r := Rect2(centre, Vector2.ZERO)
	for su in [-0.5, 0.5]:
		for sv in [-0.5, 0.5]:
			r = r.expand(centre + axis * (length * su) + across * (width * sv))
	return r


## Plan rectangles a flight covers, landing included: for another door's
## flight to keep out of.
static func flight_rects(flight: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if flight.is_empty():
		return out
	var l: Dictionary = flight["landing"]
	out.append(_plan_rect(l["centre"], l["axis"], float(l["length"]), float(l["width"])))
	for s in flight["steps"]:
		out.append(_plan_rect(s["centre"], s["axis"], float(s["length"]), float(s["width"])))
	return out


## Emit one flight through `builder` as named components on `host_name`:
## the landing's support (`entry_landing`), then one `entry_step` per tread,
## each a coursed prism down to the ground. `deck_top` is where the landing
## support stops: the threshold when the landing is ours, the underside of an
## existing porch or veranda deck when it is not.
func emit_flight(builder: MassBuilder, flight: Dictionary, surf: int,
		deck_top: float) -> void:
	if flight.is_empty():
		return
	var l: Dictionary = flight["landing"]
	var top: float = float(l["top"]) if not bool(l["apron"]) else deck_top
	_emit_prism(builder, "entry_landing", l["centre"], l["axis"], float(l["length"]),
		float(l["width"]), top, surf)
	for s in flight["steps"]:
		_emit_prism(builder, "entry_step", s["centre"], s["axis"], float(s["length"]),
			float(s["width"]), float(s["top"]), surf)


## A prism `length` along `axis`, `width` across it, from `top` to the ground,
## coursed, as component slabs.
##
## The prism is coursed along whichever of its two plan axes the ground falls
## along more, so the bottom follows the slope and only the other, gentler
## axis is levelled (buried on its uphill face, never hung in the air).
func emit_block(builder: MassBuilder, role: String, centre: Vector2, axis: Vector2,
		length: float, width: float, top: float, surf: int) -> void:
	_emit_prism(builder, role, centre, axis, length, width, top, surf)


func _emit_prism(builder: MassBuilder, role: String, centre: Vector2, axis: Vector2,
		length: float, width: float, top: float, surf: int) -> void:
	axis = axis.normalized()
	var across := Vector2(-axis.y, axis.x)
	if absf(dir.dot(across)) * width > absf(dir.dot(axis)) * length + 1e-6:
		var swap := length
		length = width
		width = swap
		axis = across
	var a := centre - axis * (length * 0.5)
	var b := centre + axis * (length * 0.5)
	for course in coursed_prism(a, b, width, top):
		builder.component_slab(role, course["points"], float(course["depth"]), surf, false)


## Emit the coursed foundation under one wall run.
## The run is carried `ext` past each end so two runs close their corner.
func emit_run(builder: MassBuilder, role: String, from: Vector2, to: Vector2,
		thick: float, top_y: float, surf: int, ext := 0.0) -> void:
	var along := (to - from).normalized()
	from -= along * ext
	to += along * ext
	for course in coursed_prism(from, to, thick, top_y):
		builder.component_slab(role, course["points"], float(course["depth"]), surf, false)
