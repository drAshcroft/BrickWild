class_name WindmillCheck
extends RefCounted
## Would this mill work, and does it know which kind of mill it is?
##
## Every rule here is a statement somebody who has looked at windmills would
## make out loud about one, and every one of them is measured against the mesh
## that was actually drawn rather than against the spec that asked for it:
##
##   STANDING    it stands on the ground, and it stands on something
##   ROTOR       the rotor's tips reach the span that was asked for
##   CLEARANCE   the rotor clears the ground it sweeps over. THE rule. A mill
##               whose sails drag in the grass is a broken mill, and this is
##               also the rule that decides how tall a post mill's post is
##   CAP_CLEAR   the sail plane stands in front of the cap rather than inside
##               it, so the rotor can turn at all
##   WINDING     something reaches out behind the mill to turn it, and a post
##               mill's tail carries the wheel that does the turning
##   ACCESS      a post mill's stair is a stair: risers a person steps, treads a
##               foot lands on, a landing at the door's own sill
##   ENTRY       a person walks in. From the ground outside, along the way
##               `WindmillGeometry.approach_path` names, every step up is one
##               a person takes, nothing blocks the body, and the walk ends on
##               the miller's floor. A door painted on a solid wall, a stair
##               with a missing tread, a door behind a wheel all fail here
##   GEAR        a windpump's rod runs from its crank to its pump
##   WHEEL       a polder mill's wheel stands in its own water and off its bed
##   ENVELOPE    the mesh is inside the box the spec promised
##   SOLID       five surfaces, and no zero-area triangles
##   FACING      every triangle winds the way its own normal says, and a
##               mill's front is its local -Z
##   COMPONENT   every named part in the log is in the mesh, and no others
##   OPENINGS    every door and window lies ON the wall it is cut in -- the
##               polygon the drum really is, leaning with its batter -- not on
##               the circle round it or the box round that
##   PROPORTION  a tower or smock mill's sails span at least
##               SPAN_PER_HEIGHT_MIN of its height; less reads as toy vanes
##   SWEPT       the DISC the rotor sweeps, not just its sails as drawn, clears
##               every wall, door, rail, deck, leg and boom of the body by
##               SWEPT_CLEAR. Only the shaft and gear that drive it may touch
##   TURNS       a post mill is one machine on one post: its boarded burr, deck
##               and roof are square to the plane its sails turn in, because
##               it is the burr that is turned into the wind and the sails turn
##               with it. A burr stood a few degrees off its own sails leans
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {..}}

## How far the drawn rotor may miss the span the spec promised, as a fraction.
## A member is a little longer than the gap it spans, so the mill's own
## geometry carries the tolerance.
const ROTOR_TOL := 0.03
## How deep in Z a mill's cloth may be. A mill's sails are a flat wheel; this
## is what catches a sail drawn as a slab lying on its face.
const CLOTH_DEPTH_MAX := 0.35
## How deep a member may sit below the ground before the mill is dug in.
const GROUND_TOL := 0.35
## The walker's own numbers, from the human walk rig (`visualqa/walk/walk_qa.gd`:
## STEP 0.4, RADIUS 0.28, BODY_H 1.75): the tallest step it will climb, the
## height of the body that must not meet a wall, and how far to either side of
## the line of the walk a person's shoulders reach.
const WALK_STEP := 0.4
const WALK_BODY := 1.75
const WALK_SIDE := 0.3
## The way in is sampled this finely along its length.
const WALK_SAMPLE := 0.1
## The tallest riser, and the shallowest tread, a stair may have.
const STAIR_RISE_MAX := 0.23
const STAIR_TREAD_MIN := 0.25

## How far an opening may stand off the wall it is cut in, and how far it may
## sink into it. An opening is lifted a centimetre or two off the masonry so
## the two surfaces cannot fight; one placed on the circle round a polygon
## drum, or held vertical against a battered one, stands off by ten.
const OPENING_PROUD_MAX := 0.045
const OPENING_SUNK_MAX := 0.004

## How far clear of every body part the rotor's swept disc must stand. A sail
## that grazes a rail is a sail that snaps it, and a sail that clears it by a
## finger is one a walker sees go through it.
const SWEPT_CLEAR := 0.2
## The parts that drive the rotor, and so legitimately reach into its hub: the
## shaft it turns on, the gear and rod it drives, the boom behind a fan.
const SWEPT_DRIVE: Array[String] = ["sail_", "whorl", "windshaft", "fan_", "star_wheel",
	"pinion", "crank_pin", "pump_rod", "vane_arm"]
## Grid step for sampling the volume of a body part.
const SWEPT_STEP := 0.25

const RULES: Array[StringName] = [&"standing", &"rotor", &"clearance",
	&"cap_clear", &"winding", &"access", &"entry", &"gear", &"wheel", &"envelope",
	&"solid", &"facing", &"component", &"openings", &"proportion", &"swept", &"turns"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(spec: WindmillSpec, mesh: ArrayMesh, builder: WindmillBuilder = null,
		overrides: Dictionary = {}) -> Dictionary:
	failures = []
	warnings = []
	stats = {}
	var m: Dictionary = measure(mesh, spec)
	# The surface-wide numbers are a fallback: they cannot tell a mill's SAILS
	# from its cap, which share a surface, so the component log measures the
	# rotor whenever the builder is there to hand.
	var points: Array[Vector3] = rotor_points(spec, builder)
	if not points.is_empty():
		var axle: Vector3 = WindmillGeometry.axle_point(spec)
		var reach := 0.0
		var low := INF
		for p in points:
			reach = maxf(reach, Vector2(p.x - axle.x, p.y - axle.y).length())
			low = minf(low, p.y)
		m["rotor_reach"] = reach
		m["rotor_low"] = low
	stats.merge({
		"type": spec.mill_type, "name": spec.variant_name,
		"tris": int(m["tris"]), "verts": int(m["verts"]),
		"surfaces": mesh.get_surface_count(),
		"lo": m["lo"], "hi": m["hi"],
		"rotor_reach": m["rotor_reach"], "rotor_low": m["rotor_low"],
	}, true)
	RuleSet.run(self, RULES, METHODS, overrides, [spec, mesh, m, builder],
		[], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


const METHODS := {}


func _fail(rule: StringName, why: String) -> void:
	failures.append("%s: %s" % [rule, why])


func _warn(rule: StringName, why: String) -> void:
	warnings.append("%s: %s" % [rule, why])


# ------------------------------------------------------------------ measures

## One walk of the vertices. `rotor_*` is the rotor's own reach, measured from
## the wind shaft, and `checksum` is positional rather than a count -- a sail
## that swings thirty degrees changes where everything is and nothing about how
## many triangles there are.
static func measure(mesh: ArrayMesh, spec: WindmillSpec = null) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var tris := 0
	var verts := 0
	var degenerate := 0
	var wound_ok := 0
	var wound_total := 0
	var salt: int = 0
	var axle: Vector3 = WindmillGeometry.axle_point(spec) if spec != null else Vector3.ZERO
	var rotor := rotor_surfaces(spec)
	var reach := 0.0
	var rotor_low := INF
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		verts += vs.size()
		var i := 0
		while i + 2 < vs.size():
			tris += 1
			var wound: Vector3 = (vs[i + 2] - vs[i]).cross(vs[i + 1] - vs[i])
			if wound.length_squared() < 1e-12:
				degenerate += 1
			else:
				wound_total += 1
				if i < ns.size() and wound.normalized().dot(ns[i]) > -0.2:
					wound_ok += 1
			i += 3
		for v in vs:
			lo = lo.min(v)
			hi = hi.max(v)
			salt = (salt + int(v.x * 100.0) * 2654435761
				+ int(v.y * 100.0) * 40503 + int(v.z * 100.0) * 22695477)
			if spec != null and s in rotor:
				reach = maxf(reach, Vector2(v.x - axle.x, v.y - axle.y).length())
				rotor_low = minf(rotor_low, v.y)
	return {"lo": lo, "hi": hi, "tris": tris, "verts": verts, "checksum": salt,
		"degenerate": degenerate, "rotor_reach": reach,
		"rotor_low": rotor_low if rotor_low < INF else 0.0,
		"facing": float(wound_ok) / maxf(1.0, float(wound_total))}


## The rotor's own points, off the log the emission wrote: a slab's own polygon
## for a mill's cloth, the blades' corners for a windpump's fan, and the wheel's
## own mass for a polder mill. `ComponentCheck` proves every one of those rows is
## in the mesh, so measuring them here is measuring the mesh -- and it is the
## only way to separate a mill's SAILS from its cap, which share a surface.
static func rotor_points(spec: WindmillSpec, builder: WindmillBuilder) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if builder == null:
		return out
	if spec.mill_type == &"paddle":
		var wheel: AABB = _masses(builder, ["wheel"])
		if wheel != AABB():
			for corner in _corners(wheel):
				out.append(corner)
		return out
	var role := "fan_blade" if spec.mill_type == &"windpump" else "sail_cloth"
	for row in builder.components(role):
		if String(row["form"]) == "slab":
			for p in row["points"]:
				out.append(p)
			continue
		# a box's own eight corners: its AABB's corners stand out past a blade
		# that is turned across the disc, and would read as a longer rotor
		for corner2 in _row_points(row, 99.0):
			out.append(corner2)
	return out


static func _corners(box: AABB) -> Array[Vector3]:
	return [box.position,
		Vector3(box.end.x, box.position.y, box.position.z),
		Vector3(box.position.x, box.end.y, box.position.z),
		Vector3(box.position.x, box.position.y, box.end.z),
		Vector3(box.end.x, box.end.y, box.position.z),
		Vector3(box.position.x, box.end.y, box.end.z),
		Vector3(box.end.x, box.position.y, box.end.z), box.end]


## Which surfaces carry this mill's rotor. It is the surface a person would say
## "the turning part" and it is not the same one on every mill: a windpump's
## fan is iron and a mill's sails are cloth.
static func rotor_surfaces(spec: WindmillSpec) -> Array[int]:
	if spec == null:
		return []
	if spec.mill_type == &"windpump" or spec.mill_type == &"paddle":
		return [WindmillBuilder.SURF_TRIM]
	return [WindmillBuilder.SURF_SAIL]


# --------------------------------------------------------------------- rules

## It stands on the ground, and it stands on something.
func _check_standing(spec: WindmillSpec, _mesh: ArrayMesh, m: Dictionary,
		builder: WindmillBuilder) -> void:
	var low: float = (m["lo"] as Vector3).y - WindmillGeometry.footing_y(spec)
	if low < -GROUND_TOL:
		_fail(&"standing", "the mill is dug %.2f m into the ground it stands on."
			% -low)
	var body: AABB = _masses(builder, ["tower", "burr", "smock_frame", "stump",
		"lattice", "post"])
	if body == AABB():
		_fail(&"standing", "no structural mass was logged for the body.")
		return
	if body.position.y > 0.06:
		_fail(&"standing", "the body starts %.2f m above the ground it stands on."
			% body.position.y)


## The rotor's tips reach the span that was asked for.
func _check_rotor(spec: WindmillSpec, _mesh: ArrayMesh, m: Dictionary,
		builder: WindmillBuilder) -> void:
	if spec.mill_type == &"paddle":
		return          # its rotor is a wheel in a race; `wheel` measures that
	var reach: float = float(m["rotor_reach"])
	if absf(reach - spec.sail_r) > ROTOR_TOL * maxf(spec.sail_r, 1.0):
		_fail(&"rotor", "the tips reach %.2f m from the shaft; the span asked for is %.2f m."
			% [reach, spec.sail_r * 2.0])
	var drawn: int = rotor_part_count(builder, spec)
	if drawn != spec.sails:
		_fail(&"rotor", "%d sails or blades were drawn for a rotor of %d."
			% [drawn, spec.sails])


## The rotor clears the ground it sweeps over.
func _check_clearance(spec: WindmillSpec, _mesh: ArrayMesh, m: Dictionary,
		_builder: WindmillBuilder) -> void:
	if spec.mill_type == &"paddle":
		return
	var clear: float = float(m["rotor_low"]) - WindmillGeometry.ground_under(spec)
	if clear < WindmillGeometry.TIP_CLEAR - ROTOR_TOL * maxf(spec.sail_r, 1.0):
		_fail(&"clearance", "the rotor passes %.2f m over the ground it turns above; a mill needs %.2f m or it drags."
			% [clear, WindmillGeometry.TIP_CLEAR])


## The sail plane stands in front of the cap, so the rotor can turn at all.
func _check_cap_clear(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if WindmillGeometry.cap_clearance(spec) == INF:
		return
	var gap: float = WindmillGeometry.cap_clearance(spec)
	if gap < WindmillGeometry.CAP_CLEAR - 0.001:
		_fail(&"cap_clear", "the sail plane stands %.2f m off the cap; it needs %.2f m."
			% [gap, WindmillGeometry.CAP_CLEAR])
		return
	var plane: float = WindmillGeometry.sail_plane(spec)
	for row in builder.component_log:
		if String(row["role"]) != "cap":
			continue
		var box: AABB = MassBuilder.component_aabb(row)
		if box.position.z < plane - 0.02:
			_fail(&"cap_clear", "the cap reaches %.2f m in front of the sail plane."
				% (plane - box.position.z))


## Something reaches out behind the mill to turn it.
func _check_winding(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if not WindmillGeometry.has_tail(spec):
		if spec.fantail and builder.components("fantail").is_empty():
			_fail(&"winding", "a mill that claims a fantail drew none, so nothing turns its cap.")
		return
	var tail: AABB = _masses(builder, ["tail"])
	if tail == AABB():
		_fail(&"winding", "a tail is promised and no tailpole was logged.")
		return
	if tail.end.z < spec.base_r * 1.2:
		_fail(&"winding", "the tail stops %.2f m behind the axis, inside the mill's own body."
			% tail.end.z)
	if spec.fantail and builder.components("fantail").is_empty():
		_fail(&"winding", "a fantail mill drew no fantail.")
	if spec.mill_type == &"post" and builder.components("winding_wheel").is_empty():
		_fail(&"winding", "a post mill's tail carries no winding wheel, so nothing turns it.")


## A post mill's stair is a stair: a landing level with the sill, treads at
## most a riser apart and deep enough for a foot, wide enough for a person.
func _check_access(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if not spec.ladder:
		return
	var treads: Array[Dictionary] = builder.components("stair_tread")
	var landing: Array[Dictionary] = builder.components("landing")
	if treads.is_empty() or landing.is_empty():
		_fail(&"access", "a post mill with a stair promised drew no treads or no landing.")
		return
	var sill: float = WindmillGeometry.floor_y(spec)
	var landing_top: float = MassBuilder.component_aabb(landing[0]).end.y
	if absf(landing_top - sill) > 0.03:
		_fail(&"access", "the landing stands %.2f m from the door sill's own height."
			% absf(landing_top - sill))
	var tops: Array[float] = [landing_top]
	var shallowest := INF
	var narrowest := INF
	for row in treads:
		var box: AABB = MassBuilder.component_aabb(row)
		tops.append(box.end.y)
		var size: Vector3 = row["size"]
		shallowest = minf(shallowest, size.z)
		narrowest = minf(narrowest, size.x)
	tops.sort()
	tops.reverse()
	var worst: float = tops[tops.size() - 1]        # the lowest tread above the ground
	for i in range(tops.size() - 1):
		worst = maxf(worst, tops[i] - tops[i + 1])
	if worst > STAIR_RISE_MAX:
		_fail(&"access", "the stair's tallest riser is %.2f m; a person steps %.2f m."
			% [worst, STAIR_RISE_MAX])
	if shallowest < STAIR_TREAD_MIN:
		_fail(&"access", "a tread is %.2f m deep; a foot needs %.2f m." % [shallowest,
			STAIR_TREAD_MIN])
	if narrowest < 0.9:
		_fail(&"access", "the stair is %.2f m wide; two shoulders and a hand want 0.9 m."
			% narrowest)
	stats["stair_riser"] = worst


## A person walks in. The way in is the one the geometry names
## (`WindmillGeometry.approach_path`), walked a step at a time on the mesh that
## was drawn: at each point the highest upward-facing surface within a step of
## where the last one was is the ground, a body's height of air must stand above
## it, and nothing may stand across the line between one point and the next.
## Three lines are walked, the middle one and one a shoulder to each side. The
## walk must end on the miller's own floor. Pinned by the 26 Oct walk: a tower
## with no way in, a smock door three metres up, a door behind the wheel.
func _check_entry(spec: WindmillSpec, mesh: ArrayMesh, _m: Dictionary,
		_builder: WindmillBuilder) -> void:
	if not WindmillGeometry.walkable(spec):
		return
	var path: Array[Vector3] = WindmillGeometry.approach_path(spec)
	if path.size() < 2:
		_fail(&"entry", "the mill names no way in.")
		return
	var lo := Vector3(INF, -1.0, INF)
	var hi := Vector3(-INF, WindmillGeometry.floor_y(spec) + WALK_BODY + 1.5, -INF)
	for p in path:
		lo.x = minf(lo.x, p.x - 1.0)
		lo.z = minf(lo.z, p.z - 1.0)
		hi.x = maxf(hi.x, p.x + 1.0)
		hi.z = maxf(hi.z, p.z + 1.0)
	var near: Array = _corridor_triangles(mesh, lo, hi)
	var line_count := 0
	for side in [0.0, -WALK_SIDE, WALK_SIDE]:
		var why: String = _walk_in(spec, path, near, side)
		line_count += 1
		if why != "":
			_fail(&"entry", "%s (walking %s)." % [why, "the middle" if side == 0.0
				else ("to the left" if side < 0.0 else "to the right")])
			return
	stats["entry_lines"] = line_count


## The triangles that stand within the corridor's box: [[a, b, c, normal.y], ...].
static func _corridor_triangles(mesh: ArrayMesh, lo: Vector3, hi: Vector3) -> Array:
	var out: Array = []
	for s in range(mesh.get_surface_count()):
		var vs: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var i := 0
		while i + 2 < vs.size():
			var a: Vector3 = vs[i]
			var b: Vector3 = vs[i + 1]
			var c: Vector3 = vs[i + 2]
			i += 3
			if maxf(a.x, maxf(b.x, c.x)) < lo.x or minf(a.x, minf(b.x, c.x)) > hi.x \
					or maxf(a.z, maxf(b.z, c.z)) < lo.z or minf(a.z, minf(b.z, c.z)) > hi.z \
					or maxf(a.y, maxf(b.y, c.y)) < lo.y or minf(a.y, minf(b.y, c.y)) > hi.y:
				continue
			# Godot's front faces are clockwise: the outward normal of (a, b, c)
			# is (c - a) x (b - a), and the floor is what faces up
			var n: Vector3 = (c - a).cross(b - a)
			if n.length_squared() < 1e-12:
				continue
			out.append([a, b, c, n.normalized().y])
	return out


## The walk along one line. "" when it reaches the floor, else why it did not.
func _walk_in(spec: WindmillSpec, path: Array[Vector3], tris: Array, side: float) -> String:
	var floor: float = WindmillGeometry.floor_y(spec)
	var y: float = NAN
	var travelled := 0.0
	var prev := Vector3.ZERO
	var first := true
	for k in range(path.size() - 1):
		var dir: Vector3 = path[k + 1] - path[k]
		var length: float = dir.length()
		if length < 0.001:
			continue
		dir /= length
		var lateral := Vector3(-dir.z, 0.0, dir.x) * side
		var count: int = int(ceil(length / WALK_SAMPLE))
		for j in range(count + (1 if k == path.size() - 2 else 0)):
			var here: Vector3 = path[k] + dir * minf(float(j) * WALK_SAMPLE, length) + lateral
			if first:
				y = _ground_at(tris, Vector3(here.x, 3.0, here.z), 3.5, 0.0)
				first = false
			else:
				y = _ground_at(tris, Vector3(here.x, y + WALK_STEP + 0.01, here.z),
					WALK_STEP * 2.0 + 0.02, y - WALK_STEP)
				if is_nan(y):
					return "there is no footing a step from the last, %.1f m along the way in" % travelled
				# the body: no part of the mill across the line from the last point
				for hy in [WALK_STEP + 0.05, 1.0, WALK_BODY - 0.15]:
					var a := Vector3(prev.x, prev.y + hy, prev.z)
					var b := Vector3(here.x, y + hy, here.z)
					for t in tris:
						if Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2]) != null:
							return "something stands across the way in, %.1f m along it, %.2f m up" % [travelled, y + hy]
				# and air over the head
				var up_from := Vector3(here.x, y + WALK_STEP + 0.05, here.z)
				var up_to := Vector3(here.x, y + WALK_BODY, here.z)
				for t2 in tris:
					if Geometry3D.segment_intersects_triangle(up_from, up_to, t2[0], t2[1], t2[2]) != null:
						return "a body does not fit under what stands over the way in, %.1f m along it, at (%.2f, %.2f, %.2f)" % [travelled, here.x, y, here.z]
			travelled += WALK_SAMPLE
			prev = Vector3(here.x, y, here.z)
	if is_nan(y) or absf(y - floor) > 0.15:
		return "the way in ends at %.2f m and the miller's floor stands at %.2f m" % [y, floor]
	return ""


## The highest ground within reach below `from`: an upward-facing triangle's
## surface under the point, or the level ground at 0, whichever is higher and
## not below `lowest`. NAN where there is none.
static func _ground_at(tris: Array, from: Vector3, reach: float, lowest: float) -> float:
	var best: float = 0.0 if (0.0 >= lowest and 0.0 <= from.y) else NAN
	var to := from + Vector3.DOWN * reach
	for t in tris:
		if float(t[3]) < 0.5:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, t[0], t[1], t[2])
		if hit == null:
			continue
		var hy: float = (hit as Vector3).y
		if hy < lowest:
			continue
		if is_nan(best) or hy > best:
			best = hy
	return best


## A windpump's rod runs from its crank down to its pump.
func _check_gear(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if not spec.cranked:
		return
	if builder.components("star_wheel").is_empty():
		_fail(&"gear", "a windpump with no star wheel between its fan and its pump.")
	var rod: AABB = _boxes(builder, "pump_rod")
	var pump: AABB = _masses(builder, ["pump"])
	if rod == AABB():
		_fail(&"gear", "no rod from the crank to the pump, so nothing is lifted.")
		return
	if pump != AABB() and rod.end.y < pump.end.y - 0.1:
		_fail(&"gear", "the pump rod stops %.2f m below the top of the pump it drives."
			% (pump.end.y - rod.end.y))


## A polder mill's wheel stands in its own water and off the bed of its race.
func _check_wheel(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if spec.mill_type != &"paddle":
		return
	var wheel: AABB = _masses(builder, ["wheel"])
	if wheel == AABB():
		return          # `rotor` already said a polder mill has no wheel
	var bed: float = -spec.race_depth
	var water: float = WindmillGeometry.water_level(spec)
	if wheel.position.y < bed - 0.01:
		_fail(&"wheel", "the wheel is cut into the bed of its own race by %.2f m."
			% (bed - wheel.position.y))
	if wheel.position.y > water:
		_fail(&"wheel", "the wheel clears the water by %.2f m, so the current has nothing to push."
			% (wheel.position.y - water))


## The mesh is inside the box the spec promised.
func _check_envelope(spec: WindmillSpec, mesh: ArrayMesh, _m: Dictionary,
		_builder: WindmillBuilder) -> void:
	var env: AABB = WindmillGeometry.envelope(spec)
	var box: AABB = mesh.get_aabb()
	if env.encloses(box):
		return
	_fail(&"envelope", "the mesh reaches x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f] and was promised x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f]."
		% [box.position.x, box.end.x, box.position.y, box.end.y,
			box.position.z, box.end.z, env.position.x, env.end.x,
			env.position.y, env.end.y, env.position.z, env.end.z])


## Five surfaces, and no zero-area triangles.
func _check_solid(spec: WindmillSpec, mesh: ArrayMesh, m: Dictionary,
		_builder: WindmillBuilder) -> void:
	if int(m["tris"]) == 0:
		_fail(&"solid", "the mill drew no triangles at all.")
	var surfaces: int = mesh.get_surface_count()
	if surfaces > WindmillGeometry.SURFACE_COUNT:
		_fail(&"solid", "%d surfaces; the family has %d." % [surfaces,
			WindmillGeometry.SURFACE_COUNT])
	if int(m["degenerate"]) > 0:
		_fail(&"solid", "%d of %d triangles have no area." % [int(m["degenerate"]),
			int(m["tris"])])


## Every triangle winds the way its own normal says, and the mill faces -Z.
func _check_facing(spec: WindmillSpec, _mesh: ArrayMesh, m: Dictionary,
		builder: WindmillBuilder) -> void:
	if float(m["facing"]) < 0.999:
		_fail(&"facing", "%.1f%% of the triangles face away from their own normal."
			% ((1.0 - float(m["facing"])) * 100.0))
	var door: Vector3 = WindmillGeometry.door_point(spec)
	if door.z > -0.01:
		_fail(&"facing", "the door is at z=%.2f; a mill's front is its local -Z." % door.z)
	if spec.mill_type in [&"tower", &"post", &"smock"]:
		var cloth: float = _cloth_depth(spec, builder)
		if cloth > CLOTH_DEPTH_MAX:
			_fail(&"facing", "the sails are %.2f m deep in Z; a mill's rotor is a flat wheel."
				% cloth)
	elif spec.mill_type == &"windpump":
		var vane: AABB = _boxes(builder, "vane_panel")
		var axle: Vector3 = WindmillGeometry.axle_point(spec)
		if vane != AABB() and vane.position.z < axle.z:
			_fail(&"facing", "the fan vane points into the wind, so the head can never find it.")


## Every named part in the log is in the mesh, and nothing else is.
func _check_component(spec: WindmillSpec, mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if builder == null:
		return
	var rep: Dictionary = ComponentCheck.check(builder, mesh)
	for f in rep["failures"]:
		_fail(&"component", String(f))


## Every door and window lies on the wall it is cut in. Measured on the logged
## slab's own corners -- which `component` proves are in the mesh -- against
## `WindmillGeometry.wall_distance`, the polygon the drum is drawn as.
func _check_openings(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if builder == null or spec.mill_type == &"windpump":
		return          # a lattice has no wall to cut an opening in
	var worst_out := 0.0
	var worst_in := 0.0
	var worst_role := ""
	var count := 0
	for row in builder.component_log:
		var role := String(row["role"])
		if role == "door_jamb" and String(row["form"]) == "box":
			# the doorway is cut, so the door is its frame: a jamb is centred on
			# the face it stands in
			count += 1
			var jd: float = WindmillGeometry.wall_distance(spec, (row["xf"] as Transform3D).origin)
			if jd > worst_out:
				worst_out = jd
				worst_role = role
			worst_in = minf(worst_in, jd)
			continue
		if role != "door" and role != "window":
			continue
		if String(row["form"]) != "slab":
			continue
		count += 1
		var depth: float = float(row.get("depth", 0.0)) * 0.5
		for p in row["points"]:
			var d: float = WindmillGeometry.wall_distance(spec, p)
			if d > worst_out:
				worst_out = d
				worst_role = role
			worst_in = minf(worst_in, d - depth)
	stats["opening_proud"] = worst_out
	if count == 0:
		_fail(&"openings", "the mill drew no door or window at all.")
		return
	if worst_out > OPENING_PROUD_MAX:
		_fail(&"openings", "a %s stands %.3f m off the wall it is cut in (allowed %.3f): it was placed on a bounding circle or box, not on the surface."
			% [worst_role, worst_out, OPENING_PROUD_MAX])
	if worst_in < -OPENING_SUNK_MAX:
		_fail(&"openings", "an opening is sunk %.3f m into the wall, where the masonry hides it."
			% -worst_in)


## A cap mill's sails are in proportion to the tower that carries them.
func _check_proportion(spec: WindmillSpec, _mesh: ArrayMesh, m: Dictionary,
		_builder: WindmillBuilder) -> void:
	if spec.mill_type != &"tower" and spec.mill_type != &"smock":
		return
	var tall: float = maxf(spec.curb_y, 0.01)
	var ratio: float = float(m["rotor_reach"]) * 2.0 / tall
	stats["span_per_height"] = ratio
	if ratio < WindmillGeometry.SPAN_PER_HEIGHT_MIN:
		_fail(&"proportion", "the sails span %.2f m on a %.2f m tower (%.2f of its height; at least %.2f): toy vanes on a tall drum."
			% [float(m["rotor_reach"]) * 2.0, tall, ratio, WindmillGeometry.SPAN_PER_HEIGHT_MIN])


## The rotor's swept disc clears the body. The rotor is a flat wheel of radius
## `sail_r` about the shaft; whatever lies inside that wheel, thickened by the
## depth of the sails and `SWEPT_CLEAR` each way, is in the sails' path as they
## turn -- whichever way they happen to be pointing in the pose drawn.
## Every logged body part is sampled (boxes through their volume, slabs and
## rings through their edges) plus the drum's own surface, which is not a
## component. A part that drives the rotor is exempt, and only that part.
## Every boarded part of a post mill's burr lies square to the sail plane
## (rotation about Y a multiple of a quarter turn; the unturned frame IS the
## sail plane's). Measured off the component log, on boxes and on slab edges.
func _check_turns(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if spec.mill_type != &"post" or builder == null:
		return
	var worst := 0.0
	var worst_role := ""
	for row in builder.component_log:
		var role := String(row["role"])
		if not role.begins_with("burr_") and role != "door_sill":
			continue
		var offs: Array[float] = []
		if row.has("xf"):
			var ax: Vector3 = (row["xf"] as Transform3D).basis * Vector3.RIGHT
			offs.append(ax.x)
			offs.append(ax.z)
		elif row.has("points"):
			var pts: PackedVector3Array = row["points"]
			for i in range(pts.size()):
				var e: Vector3 = pts[(i + 1) % pts.size()] - pts[i]
				if Vector2(e.x, e.z).length() > 0.05:
					offs.append(e.x)
					offs.append(e.z)
		else:
			continue
		for k in range(0, offs.size(), 2):
			var ang: float = atan2(offs[k + 1], offs[k])
			var off: float = absf(fposmod(ang + PI * 0.25, PI * 0.5) - PI * 0.25)
			if off > worst:
				worst = off
				worst_role = role
	stats["burr_skew"] = worst
	if worst > 0.03:
		_fail(&"turns", ("the %s stands %.1f degrees off the plane the sails turn in; a post "
			+ "mill's burr and its rotor are one machine.") % [worst_role, rad_to_deg(worst)])


func _check_swept(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if spec.mill_type == &"paddle" or builder == null:
		return
	var axle: Vector3 = WindmillGeometry.axle_point(spec)
	var normal: Vector3 = Vector3.BACK
	if spec.mill_type == &"windpump":
		normal = WindmillGeometry.head_basis(spec) * Vector3.BACK
	var lo := INF
	var hi := -INF
	for row in builder.component_log:
		var role := String(row["role"])
		if not (role.begins_with("sail_") or role == "fan_blade" or role == "fan_rim"):
			continue
		for p in _row_points(row, 99.0):
			var a: float = (p - axle).dot(normal)
			lo = minf(lo, a)
			hi = maxf(hi, a)
	if lo > hi:
		return
	var worst := INF
	var worst_role := ""
	for row in builder.component_log:
		var role2 := String(row["role"])
		if _is_drive(role2):
			continue
		for q in _row_points(row, SWEPT_STEP):
			var sep: float = _swept_gap(q, axle, normal, lo, hi, spec.sail_r)
			if sep < worst:
				worst = sep
				worst_role = role2
	if WindmillGeometry.is_round(spec) or spec.mill_type == &"smock":
		for k in range(13):
			var y: float = lerpf(WindmillGeometry.floor_y(spec), spec.curb_y, float(k) / 12.0)
			var radius: float = WindmillGeometry.radius_at(spec, y)
			for j in range(32):
				var ang: float = TAU * float(j) / 32.0
				var sep2: float = _swept_gap(Vector3(cos(ang) * radius, y, sin(ang) * radius),
					axle, normal, lo, hi, spec.sail_r)
				if sep2 < worst:
					worst = sep2
					worst_role = "drum"
	stats["swept_gap"] = worst
	if worst < SWEPT_CLEAR - 0.001:
		_fail(&"swept", "the rotor's disc comes within %.2f m of the %s; it needs %.2f m."
			% [worst, worst_role, SWEPT_CLEAR])


## How far `p` stands outside the rotor's slab: along the shaft past its sails,
## or out past the tips, whichever is the shorter way clear. Negative inside.
static func _swept_gap(p: Vector3, axle: Vector3, normal: Vector3, lo: float,
		hi: float, rim: float) -> float:
	var d: Vector3 = p - axle
	var a: float = d.dot(normal)
	var rr: float = sqrt(maxf(d.length_squared() - a * a, 0.0))
	return maxf(maxf(lo - a, a - hi), rr - rim)


static func _is_drive(role: String) -> bool:
	for prefix in SWEPT_DRIVE:
		if role.begins_with(prefix):
			return true
	return false


## Points on, and inside, what a logged component occupies: a box through its
## volume on a grid of about `step`, a slab through its polygon (both faces),
## a ring through its two edges. Anything the log has no shape for gives none.
static func _row_points(row: Dictionary, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var form := String(row["form"])
	if form == "box":
		var xf: Transform3D = row["xf"]
		var size: Vector3 = row["size"]
		var n := Vector3i(clampi(int(ceil(size.x / step)) + 1, 2, 24),
			clampi(int(ceil(size.y / step)) + 1, 2, 24),
			clampi(int(ceil(size.z / step)) + 1, 2, 24))
		for i in range(n.x):
			for j in range(n.y):
				for k in range(n.z):
					out.append(xf * Vector3(
						(float(i) / float(n.x - 1) - 0.5) * size.x,
						(float(j) / float(n.y - 1) - 0.5) * size.y,
						(float(k) / float(n.z - 1) - 0.5) * size.z))
	elif form == "slab":
		var pts: PackedVector3Array = row["points"]
		if pts.size() < 3:
			return out
		var axis := Vector3.UP
		if not bool(row["vertical"]):
			axis = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		var off: Vector3 = axis * (float(row["depth"]) * 0.5)
		var mid := Vector3.ZERO
		for p in pts:
			mid += p
		mid /= float(pts.size())
		for p2 in pts:
			for t in [0.0, 0.5, 1.0]:
				var on: Vector3 = mid.lerp(p2, t)
				out.append(on + off)
				out.append(on - off)
	elif form == "ring" and row.has("radius"):
		var radius: float = float(row["radius"])
		for k2 in range(25):
			var ang: float = float(row.get("start", 0.0)) + float(row["arc"]) * float(k2) / 24.0
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			for rad in [radius, radius - float(row["width"])]:
				for dy in [-1.0, 1.0]:
					out.append(dir * rad + Vector3(0.0, float(row["y"]) + dy * float(row["thickness"]) * 0.5, 0.0))
	return out


# ------------------------------------------------------------------ lookups

## The union of the logged masses named in `names`, from the emission itself.
##
## Neither of these can start from an EMPTY AABB and merge into it: `AABB.merge`
## takes the union of two boxes, and an empty box still sits at the ORIGIN, so
## the first merge drags the result back to zero and every measurement made
## from it is the origin. The flag is the whole fix.
static func _masses(builder: WindmillBuilder, names: Array) -> AABB:
	if builder == null:
		return AABB()
	var out := AABB()
	var found := false
	for row in builder.mass_log:
		if String(row["name"]) not in names:
			continue
		var box: AABB = (row["aabb"] as AABB).abs()
		out = box if not found else out.merge(box)
		found = true
	return out


## The union of the logged components with `role`.
static func _boxes(builder: WindmillBuilder, role: String) -> AABB:
	if builder == null:
		return AABB()
	var out := AABB()
	var found := false
	for row in builder.components(role):
		var box: AABB = MassBuilder.component_aabb(row)
		out = box if not found else out.merge(box)
		found = true
	return out


## How many sails -- or blades -- were actually drawn, counted off the log the
## emission wrote. A windpump's rotor is iron, so it has blades and no cloth.
static func rotor_part_count(builder: WindmillBuilder, spec: WindmillSpec) -> int:
	if builder == null:
		return 0
	return builder.components("fan_blade" if spec.mill_type == &"windpump"
		else "sail_cloth").size()


## How deep the mill's cloth sits in Z, measured on the cloth's own components.
## The cap shares the sail surface, so the rows are counted rather than the
## whole surface being measured.
static func _cloth_depth(spec: WindmillSpec, builder: WindmillBuilder) -> float:
	if builder == null:
		return 0.0
	var plane: float = WindmillGeometry.sail_plane(spec)
	var depth := 0.0
	for row in builder.components("sail_cloth"):
		depth = maxf(depth, absf(MassBuilder.component_aabb(row).get_center().z - plane))
	return depth