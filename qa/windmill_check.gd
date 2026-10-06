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
##   ACCESS      a post mill's ladder reaches its own door and stands clear of
##               the sails that pass it
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
## A ladder this close to the sails' own breadth is a ladder the sails hit.
const LADDER_TOL := 0.06

## How far an opening may stand off the wall it is cut in, and how far it may
## sink into it. An opening is lifted a centimetre or two off the masonry so
## the two surfaces cannot fight; one placed on the circle round a polygon
## drum, or held vertical against a battered one, stands off by ten.
const OPENING_PROUD_MAX := 0.045
const OPENING_SUNK_MAX := 0.004

const RULES: Array[StringName] = [&"standing", &"rotor", &"clearance",
	&"cap_clear", &"winding", &"access", &"gear", &"wheel", &"envelope",
	&"solid", &"facing", &"component", &"openings", &"proportion"]

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
		for corner2 in _corners(MassBuilder.component_aabb(row)):
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


## A post mill's ladder reaches its own door and stands clear of the sails.
func _check_access(spec: WindmillSpec, _mesh: ArrayMesh, _m: Dictionary,
		builder: WindmillBuilder) -> void:
	if not spec.ladder:
		return
	var ladder: AABB = _masses(builder, ["ladder"])
	if ladder == AABB():
		_fail(&"access", "a post mill with a ladder promised drew no ladder.")
		return
	# A stock ladder has two ends and both matter. Its FOOT stands well outside
	# the sails, because a miller who climbed into them would not come back; its
	# TOP is in the burr's own wall at the door. So it leans across in plan, and
	# checking its nearest point -- which is the one at the door -- proves
	# nothing at all about the sails.
	var sill: float = WindmillGeometry.floor_y(spec)
	if ladder.end.y < sill - 0.15:
		_fail(&"access", "the stock ladder stops %.2f m below the door sill."
			% (sill - ladder.end.y))
	var foot: float = maxf(absf(ladder.position.x), absf(ladder.end.x))
	var sweep: float = spec.stage_r + spec.sail_width * 0.5
	if foot < sweep - LADDER_TOL:
		_fail(&"access", "the ladder's foot stands %.2f m off the axis and the sails sweep to %.2f m."
			% [foot, sweep])
	var head: float = minf(absf(ladder.position.x), absf(ladder.end.x))
	if head > spec.base_r + spec.ladder_w:
		_fail(&"access", "the ladder's top stops %.2f m off the axis, short of the burr it is for."
			% head)


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