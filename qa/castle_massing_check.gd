class_name CastleMassingCheck
extends RefCounted
## Correctness checks over a CASTLE's structural masses. The three structural
## rules come from MassRules; what lives here is the castle's joint table, the
## dimensions its spec asked for, and the one rule a fortification adds:
##
##   ENCLOSED    a walled tier must actually be walled -- four runs of curtain,
##               a gate through them, and every ward tied to the one outside it
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
## Mass name prefixes that fold to a family for the joint table below.
const FAMILIES := ["wall", "tower", "gate", "barbican", "keep", "hall", "chapel",
	"wing", "range", "porch", "chimney", "annexe", "link"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


## Designed interpenetration per joint, in metres of penetration depth. A pair
## absent from this table is expected NOT to overlap at all; INF marks a
## crossing meant to pass fully through.
static func _allowance(a: String, b: String) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	match key:
		# --- the enceinte: walls die into the towers and gate that stud them ---
		"tower|wall", "gate|wall", "gate|tower":
			return INF
		"barbican|gate", "barbican|tower":
			return INF                        # the outwork ties into the gate
		"gate|link", "link|tower", "link|wall":
			return INF                        # the causeway lands on both gates

		# --- ranges built against a curtain lap it, and its towers with it ---
		"keep|wall", "hall|wall", "chapel|wall":
			return CastleGeometry.RANGE_LAP
		"keep|tower", "hall|tower", "chapel|tower":
			return CastleGeometry.RANGE_LAP

		# --- house and manor: one range laps the next ---
		"hall|wing", "range|wing", "annexe|hall", "chimney|hall", "hall|porch":
			return CastleGeometry.WING_LAP
		"hall|range", "chimney|range", "annexe|wing":
			return CastleGeometry.WING_LAP
		"porch|range", "porch|wing":
			return INF                        # the passage runs through the range
		"hall|tower", "tower|wing", "range|tower":
			return INF                        # a manor tower is built into its range

		# --- everything below must stand clear ---
		"wall|wall":
			return 0.0                        # runs meet at their faces
		"tower|tower":
			return 0.0                        # towers must not collide
		"gate|gate":
			return 0.0                        # outer and inner gatehouses are apart
		"hall|keep", "chapel|keep", "chapel|hall":
			return 0.0                        # ranges touch, they do not merge
		"link|link", "wing|wing":
			return 0.0
	return 0.0


func check(spec: CastleSpec, builder: CastleBuilder) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	stats["tier"] = String(spec.tier)
	if masses.is_empty():
		failures.append("massing: builder logged no structural masses")
		return _report()

	var g: Dictionary = MassRules.gaps(masses, _anchor(spec))
	_add(g["failures"])
	stats["masses_joined"] = g["joined"]

	var o: Dictionary = MassRules.overlaps(masses,
		func(a: String, b: String) -> float: return _allowance(a, b), FAMILIES)
	_add(o["failures"])
	stats["worst_penetration"] = o["worst"]

	_add(MassRules.grounded(masses, []))
	_check_size_match(spec, builder, masses)
	_check_enclosure(spec, builder)
	return _report()


## The mass everything else must be reachable from. A walled tier is anchored
## on its outer curtain; an unwalled one on the hall, which IS the building.
static func _anchor(spec: CastleSpec) -> String:
	return "wall_0_back" if CastleGeometry.is_enclosed(spec) else "hall"


func _add(msgs) -> void:
	for m in msgs:
		failures.append(str(m))


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


# ------------------------------------------------------------- size match

## The emitted masses must have the dimensions the spec and the tier asked for.
func _check_size_match(spec: CastleSpec, builder: CastleBuilder,
		masses: Array[Dictionary]) -> void:
	var by_name := {}
	for m in masses:
		by_name[m["name"]] = m["aabb"]

	if spec.keep and by_name.has("keep"):
		var k: AABB = by_name["keep"]
		_expect("keep width", k.size.x, spec.keep_w)
		_expect("keep depth", k.size.z, spec.keep_l)
		_expect("keep height", k.size.y, spec.keep_height)

	if CastleGeometry.is_enclosed(spec):
		for r in CastleGeometry.rings(spec):
			var h: float = CastleGeometry.wall_height(spec, r)
			for which in CastleGeometry.wall_names(spec, r):
				var key: String = "wall_%d_%s" % [r, String(which)]
				if by_name.has(key):
					_expect("%s height" % key, by_name[key].size.y, h)
			var th: float = CastleGeometry.tower_height(spec, r)
			var s2: float = CastleGeometry.tower_base_half(spec, r) * 2.0
			for m2 in masses:
				var nm: String = m2["name"]
				if not nm.begins_with("tower_%d" % r):
					continue
				var a: AABB = m2["aabb"]
				_expect("%s height" % nm, a.size.y, th)
				_expect("%s plan" % nm, a.size.x, s2)
	else:
		var host: AABB = CastleGeometry.house_range_aabb(spec)
		if by_name.has("hall"):
			_expect("hall width", by_name["hall"].size.x, host.size.x)
			_expect("hall height", by_name["hall"].size.y, spec.height)

	# The footprint the user asked for is the one the design must occupy: the
	# enceinte (or the house block) spans the whole site, no more and no less.
	var span := AABB()
	var first := true
	for m3 in masses:
		var b: AABB = m3["aabb"]
		span = b if first else span.merge(b)
		first = false
	stats["plan"] = "%.1f x %.1f" % [span.size.x, span.size.z]
	var want: Rect2 = CastleGeometry.plan_extent(spec)
	if span.size.x > want.size.x + TOL or span.size.z > want.size.y + TOL:
		failures.append("size_match: masses span %.2f x %.2fm, past the %.2f x %.2fm the plan allows"
			% [span.size.x, span.size.z, want.size.x, want.size.y])


# --------------------------------------------------------------- enclosure

## A castle is a wall with something inside it. This is the rule that catches a
## "castle" that generated as four towers and a keep standing in open ground.
func _check_enclosure(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec):
		if not builder.has_mass("hall"):
			failures.append("enclosed: a %s must have a hall block" % String(spec.tier))
		return
	for r in CastleGeometry.rings(spec):
		var runs := 0
		for which in CastleGeometry.wall_names(spec, r):
			if builder.has_mass("wall_%d_%s" % [r, String(which)]):
				runs += 1
		if runs < 4:
			failures.append("enclosed: ring %d has %d wall runs, not a closed circuit" % [r, runs])
		if spec.gatehouse and not builder.has_mass("gate_%d" % r):
			failures.append("enclosed: ring %d has no gatehouse to get in by" % r)
	if spec.inner_ward:
		if not (builder.has_mass("link_left") or builder.has_mass("link_right")):
			failures.append("enclosed: inner ward has no causeway joining it to the outer gate")


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > TOL:
		failures.append("size_match: %s is %.2fm, spec asked for %.2fm" % [what, got, want])
