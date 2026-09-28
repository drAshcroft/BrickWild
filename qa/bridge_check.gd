class_name BridgeCheck
extends RefCounted
## Would this bridge carry a load, and does it know what it is?
##
## `MassingCheck` asks whether a building stands up. This asks whether a span
## crosses, and every rule is a statement somebody who has looked at bridges
## would make out loud about one:
##
##   SPAN        the deck runs the whole way, with no hole in it
##   LEVEL       the deck is where it was put, and it is as wide as it was asked
##               to be
##   SUPPORTED   every station of the deck has something underneath it. THE rule.
##               A deck that touches an abutment at both ends and nothing in
##               between is a plank with ambition, and no amount of looking at
##               the picture says so as plainly as walking along it
##   ABUTMENT    both ends land in the bank they are supposed to land in
##   CHANNEL     the water between the innermost piers is open
##   ENVELOPE    the mesh is inside the box the spec promised
##   SOLID       four surfaces, no zero-area triangles
##   FACING      every triangle winds the way its own normal says
##   MECHANISM   a movable bridge carries a mechanism, and it is the right one
##   LANTERN     a covered bridge has lamps; nothing else has
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {..}}

## How far the mesh may sit outside the promised envelope before it is a
## failure. The same `DRAW_ALLOWANCE` the post-condition fit uses -- a rule with
## one tolerance and a promise with another fails on the difference.
const ENVELOPE_TOL := 0.01
## How much of the deck may be unsupported before the load path is a lie.
const SUPPORT_TOL := 0.02
## A deck has to clear the water by something you could see under.
const CLEAR_MIN := 0.2

const RULES: Array[StringName] = [&"span", &"level", &"supported", &"abutment",
	&"channel", &"envelope", &"solid", &"facing", &"mechanism", &"lantern"]

const METHODS := {
	&"span": "_check_span", &"level": "_check_level",
	&"supported": "_check_supported", &"abutment": "_check_abutment",
	&"channel": "_check_channel", &"envelope": "_check_envelope",
	&"solid": "_check_solid", &"facing": "_check_facing",
	&"mechanism": "_check_mechanism", &"lantern": "_check_lantern",
}

## The load path as a union of x ranges, from the SPEC -- not from the mesh.
## Re-deriving "what holds this up" from geometry would be the check agreeing
## with itself about the same list the builder drew from.
static func carried_spans(spec: BridgeSpec) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	for m in spec.members:
		var c: PackedFloat32Array = m.get("carries", PackedFloat32Array())
		if c.size() == 2 and c[1] > c[0]:
			out.append(c)
	for p in spec.piers:
		# A support carries the width of itself, at the least.
		out.append(PackedFloat32Array([float(p["x"]) - float(p["w"]) * 0.5,
			float(p["x"]) + float(p["w"]) * 0.5]))
	return out


var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(spec: BridgeSpec, mesh: ArrayMesh, builder: BridgeBuilder = null,
		overrides: Dictionary = {}) -> Dictionary:
	failures = []
	warnings = []
	stats = {}
	for problem in BridgeGeometry.validate(spec):
		failures.append("spec: " + problem)
	var m: Dictionary = measure(mesh)
	stats.merge({
		"tris": int(m["tris"]), "verts": int(m["verts"]),
		"surfaces": mesh.get_surface_count(),
		"lo": m["lo"], "hi": m["hi"],
		"channel": BridgeGeometry.channel_width(spec),
	}, true)
	RuleSet.run(self, RULES, METHODS, overrides,
		[spec, mesh, m, builder], [], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


## The mesh's own x extent, for the rules that run without a builder.
static func lo_x_fallback(m: Dictionary) -> float:
	return (m["lo"] as Vector3).x


func _fail(rule: StringName, why: String) -> void:
	failures.append("%s: %s" % [rule, why])


func _warn(rule: StringName, why: String) -> void:
	warnings.append("%s: %s" % [rule, why])


# ------------------------------------------------------------------ measures

## One walk of the vertices, for every rule that needs a number.
static func measure(mesh: ArrayMesh) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var tris := 0
	var verts := 0
	var degenerate := 0
	var wound_ok := 0
	var wound_total := 0
	# A positional CHECKSUM, not a count. Two different bridges share a
	# triangle count constantly -- a pier moved forty centimetres changes where
	# everything is and changes nothing about how many triangles there are --
	# and keying "is this a stamp" on counts reported six seeds of a stone
	# bridge as one bridge. This is the same correction the tree family needed
	# for the same reason.
	var salt: int = 0
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
				+ int(v.y * 100.0) * 40503
				+ int(v.z * 100.0) * 22695477)
	return {"lo": lo, "hi": hi, "tris": tris, "verts": verts, "checksum": salt,
		"degenerate": degenerate,
		"facing": float(wound_ok) / maxf(1.0, float(wound_total))}


# ---------------------------------------------------------------------- rules

## SPAN -- the deck runs the whole way, with no hole in it.
func _check_span(spec: BridgeSpec, _mesh: ArrayMesh, m: Dictionary, b: BridgeBuilder) -> void:
	var hi: Vector3 = m["hi"]
	if b != null and b.deck_log.is_empty():
		_fail(&"span", "no deck was laid across the span")
		return
	if b != null and b.deck_log.size() > 1:
		var covered: float = 0.0
		for s in b.deck_log:
			covered += (s["carries"] as PackedFloat32Array)[1] \
				- (s["carries"] as PackedFloat32Array)[0]
		# The DECK's length, not the mesh's: the wing walls splay back into
		# the bank and are legitimately longer than the span they carry, so
		# measuring the whole mesh against the span credits the bridge with
		# reaching further than it does.
		if covered < spec.span * 0.99:
			_fail(&"span", "the deck is laid for %.1f m of a %.1f m span; there is a hole in it"
				% [covered, spec.span])
		stats["deck_len"] = covered
	elif hi.x - lo_x_fallback(m) < spec.span * 0.98:
		_fail(&"span", "the structure is %.1f m end to end against a %.1f m span"
			% [hi.x - lo_x_fallback(m), spec.span])


## LEVEL -- the deck is where it was put, and as wide as it was asked to be.
func _check_level(spec: BridgeSpec, _mesh: ArrayMesh, m: Dictionary, b: BridgeBuilder) -> void:
	if b == null or b.deck_log.is_empty():
		_fail(&"level", "no deck was laid")
		return
	for s in b.deck_log:
		var a: Vector3 = s["a"]
		var want: float = BridgeGeometry.deck_height_at(spec, a.x)
		if absf(a.y - want) > 0.06:
			_fail(&"level", "the deck at x=%.1f is at %.2f m; the profile says %.2f"
				% [a.x, a.y, want])
			return


## SUPPORTED -- every station of the deck has something under it. THE rule.
##
## The spec's members each declare the x RANGE they are responsible for, and a
## bridge with a ten-metre gap in that union is a cantilever nobody asked for.
## This is measured on the union, not on the picture, because a cantilever looks
## exactly like a supported span from the bank.
func _check_supported(spec: BridgeSpec, _mesh: ArrayMesh, m: Dictionary, _b: BridgeBuilder) -> void:
	var spans: Array[PackedFloat32Array] = carried_spans(spec)
	if spans.is_empty():
		_fail(&"supported", "nothing declares what it is holding up")
		return
	spans.sort_custom(func(a: PackedFloat32Array, b: PackedFloat32Array):
		return a[0] < b[0])
	var half: float = spec.span * 0.5
	var reach: float = -half
	var worst: float = 0.0
	var at: float = 0.0
	for s in spans:
		if s[0] > reach:
			var gap: float = s[0] - reach
			if gap > worst:
				worst = gap
				at = reach
		reach = maxf(reach, s[1])
	var tail: float = half - reach
	if tail > worst:
		worst = tail
		at = reach
	var loose: float = maxf(worst, 0.0) / maxf(spec.span, 0.01)
	stats["unsupported"] = loose
	if loose > SUPPORT_TOL:
		_fail(&"supported", "%.0f%% of the span is a cantilever; %.1f m at x=%.1f has nothing under it"
			% [100.0 * loose, worst, at])


## ABUTMENT -- both ends land in the bank they are supposed to land in.
##
## Measured against `bank_height_at`, the same function the footings were
## computed from and the site is built from. A bridge whose abutment stops
## above the ground is hovering, and no amount of good masonry fixes it.
func _check_abutment(spec: BridgeSpec, _mesh: ArrayMesh, _m: Dictionary, b: BridgeBuilder) -> void:
	if b == null:
		return
	var ends := 0
	for p in b.pier_log:
		if p["kind"] != &"abutment":
			continue
		ends += 1
		var x: float = p["x"]
		var ground: float = BridgeGeometry.bank_height_at(spec, x)
		if float(p["bottom"]) > ground - 0.1:
			_fail(&"abutment", "the abutment at x=%.1f stops at %.2f m and the bank is at %.2f"
				% [x, float(p["bottom"]), ground])
	if ends < 2:
		_fail(&"abutment", "%d abutment(s); a span needs two" % ends)


## CHANNEL -- the water between the innermost piers is open.
func _check_channel(spec: BridgeSpec, _mesh: ArrayMesh, _m: Dictionary, _b: BridgeBuilder) -> void:
	var w: float = float(stats.get("channel", 0.0))
	if BridgeGeometry.is_over_water(spec, 0.0) and w <= 0.1:
		_fail(&"channel", "there is no water between the piers; the channel is closed")
	stats["channel_w"] = w


## ENVELOPE -- the mesh is inside the box the spec promised.
func _check_envelope(spec: BridgeSpec, _mesh: ArrayMesh, m: Dictionary, _b: BridgeBuilder) -> void:
	var want: AABB = BridgeGeometry.expected_extent(spec)
	var lo: Vector3 = m["lo"]
	var hi: Vector3 = m["hi"]
	for axis in range(3):
		var over: float = 0.0
		if lo[axis] < want.position[axis]:
			over = want.position[axis] - lo[axis]
		if hi[axis] > want.end[axis]:
			over = maxf(over, hi[axis] - want.end[axis])
		# A small ABSOLUTE tolerance on top of a fit that aims at the box
		# exactly. Scaling the rule's tolerance with the box made a long bridge
		# fail by four metres over the same relative error a short one passed.
		if over > maxf(0.3, want.size[axis] * ENVELOPE_TOL):
			_fail(&"envelope", "over the %s by %.2f m; the box is %.2f m"
				% [["length", "height", "width"][axis], over, want.size[axis]])


## SOLID -- the surface contract and no zero-area triangles.
func _check_solid(_spec: BridgeSpec, mesh: ArrayMesh, m: Dictionary, _b: BridgeBuilder) -> void:
	if mesh.get_surface_count() > BridgeSpec.SURFACE_COUNT:
		_fail(&"solid", "%d surfaces; the palette has %d"
			% [mesh.get_surface_count(), BridgeSpec.SURFACE_COUNT])
	if int(m["degenerate"]) > 0:
		_fail(&"solid", "%d zero-area triangles" % int(m["degenerate"]))
	if int(m["tris"]) < 24:
		_fail(&"solid", "only %d triangles: that is not a bridge" % int(m["tris"]))


## FACING -- every triangle winds the way its own normal says.
func _check_facing(_spec: BridgeSpec, _mesh: ArrayMesh, m: Dictionary, _b: BridgeBuilder) -> void:
	if float(m["facing"]) < 0.99:
		_fail(&"facing", "%.0f%% of faces wind against their own normal"
			% (100.0 * float(m["facing"])))


## MECHANISM -- a movable bridge carries a mechanism, and it is the right one.
func _check_mechanism(spec: BridgeSpec, _mesh: ArrayMesh, _m: Dictionary, _b: BridgeBuilder) -> void:
	if spec.kind != &"mobile":
		return
	var roles: Array[StringName] = []
	for member in spec.members:
		roles.append(member["role"])
	var want: StringName = {
		&"lift": &"lift_rope", &"swing": &"swing_boom",
		&"pontoon": &"float", &"drawbridge": &"leaf",
	}.get(spec.motion, &"lift_rope")
	if roles.has(want):
		return
	# Pontoons live on the PIERS, not in the member list, so they are excused.
	if spec.motion == &"pontoon":
		for p in spec.piers:
			if p["kind"] == &"pontoon":
				return
	_fail(&"mechanism", "a %s bridge carries no %s; it does not move"
		% [spec.motion, want])


## LANTERN -- a covered bridge has lamps; nothing else has. The one reason the
## kind is worth having is that it is a bridge you can see at night.
func _check_lantern(spec: BridgeSpec, _mesh: ArrayMesh, _m: Dictionary, _b: BridgeBuilder) -> void:
	if spec.kind == &"covered" and spec.glow.is_empty():
		_fail(&"lantern", "a covered bridge with no lantern is a shed over a river")
	elif spec.kind != &"covered" and not spec.glow.is_empty():
		_warn(&"lantern", "a %s bridge carries %d lamps" % [spec.kind, spec.glow.size()])
