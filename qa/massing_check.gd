class_name MassingCheck
extends RefCounted
## Correctness checks over a CHURCH's structural masses.
##
## The three structural rules themselves live in MassRules, which the castle
## checker uses too. What belongs here is only what is specific to a church:
## its joint table, and the dimensions its spec asked for.
##
##   NO GAPS     every mass touches the assembly; nothing floats     (MassRules)
##   NO OVERLAP  only designed joints interpenetrate, only that deep (MassRules)
##   SIZE MATCH  emitted masses match the dimensions the spec asked for
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
## Mass name prefixes that fold to a family for the joint table.
const FAMILIES := ["aisle", "chapel", "flyer_pier", "flyer_arch", "tower", "tribune"]
## Masses carried on the walls below them rather than standing on the ground.
const CARRIED := ["dome_drum", "pendentive", "flyer_arch"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


## Designed interpenetration per joint, in metres of penetration depth.
## A pair absent from this table is expected NOT to overlap at all.
## INF marks a crossing that is meant to pass fully through.
static func _allowance(spec: ChurchSpec, a: String, b: String) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	match key:
		# --- crossings and enclosures: designed to pass through one another ---
		"nave|transept":
			return INF                        # the crossing, by definition
		"crossing_tower|nave", "crossing_tower|transept":
			return INF                        # a lantern stands ON the crossing
		"dome_drum|nave", "dome_drum|transept":
			return INF                        # so does a dome
		"dome_drum|pendentive", "nave|pendentive", "pendentive|transept":
			return INF                        # the course the drum is carried on
		"aisle|pendentive", "apse|pendentive", "chapel|pendentive":
			return INF
		"aisle|dome_drum", "apse|dome_drum", "chapel|dome_drum":
			return INF                        # the dome oversails them
		"crossing_tower|dome_drum":
			return INF                        # generator never emits both

		# --- hero landmarks (spec.hero) ---
		"crossing_octagon|nave", "aisle|crossing_octagon":
			return INF                        # the nave and aisles run into the octagon
		"crossing_octagon|dome_drum", "crossing_octagon|pendentive":
			return INF                        # the drum stands on it
		"crossing_octagon|tribune":
			return INF                        # a tribune is buried in the face it opens off
		"dome_drum|tribune", "pendentive|tribune", "nave|tribune", "aisle|tribune":
			return 0.0                        # tribunes stand clear of everything else
		"nave|podium", "narthex|podium", "chapel|podium", "pendentive|podium", "dome_drum|podium":
			return INF                        # St Basil's podium is under the whole cluster
		"flyer_arch|flyer_pier", "flyer_arch|nave", "aisle|flyer_arch":
			return INF                        # the flyer lands on the wall it braces
		"flyer_arch|transept", "flyer_pier|transept":
			return INF                        # the bay next to the crossing
		"ambulatory|apse":
			return INF                        # the ambulatory wraps the apse
		"narthex|tower", "narthex|tower_pair":
			return INF                        # west towers stand in the narthex bay

		# --- abutments: joined, but only as deep as the joint declares ---
		"nave|tower":
			return ChurchGeometry.TOWER_EMBED
		"apse|nave":
			return ChurchGeometry.APSE_EMBED
		"ambulatory|nave", "ambulatory|transept":
			return ChurchGeometry.APSE_EMBED
		"narthex|nave":
			return ChurchGeometry.TOWER_EMBED
		"aisle|nave":
			return ChurchGeometry.AISLE_LAP
		"aisle|ambulatory":
			return ChurchGeometry.APSE_EMBED  # the ambulatory continues the aisle
		"aisle|aisle":
			return ChurchGeometry.AISLE_LAP   # each ring laps the one inside it
		"aisle|narthex":
			return ChurchGeometry.AISLE_LAP
		"ambulatory|chapel", "apse|chapel":
			# An alcove is carved INTO the hemicycle it opens off, and both are
			# curved, so their axis-aligned boxes overlap far more than the
			# masonry does. Depth here is meaningless; that the chapel reaches
			# its host at all is checked by the no-gaps pass.
			return INF

		# --- everything else in this list must not touch at all ---
		"aisle|transept", "aisle|tower":
			return 0.0                        # aisles are placed to clear both
		"apse|transept":
			return 0.0                        # apse springs from the east wall
		"apse|tower", "tower|transept":
			return 0.0                        # opposite ends of the church
		"chapel|chapel":
			return 0.0                        # alcoves must not collide
		"chapel|narthex":
			# a clustered ring is fanned round the porch's flank and may graze it
			return INF if spec.chapel_arrangement == &"cluster" else 0.0
		"chapel|nave", "chapel|transept", "aisle|chapel":
			# A clustered ring is set INTO the central mass, so its boxes
			# overlap by design. A chevet chapel stands off in the apse and
			# must not reach the nave at all.
			return INF if spec.chapel_arrangement == &"cluster" else 0.0
		"tower|tower":
			return 0.0                        # twin towers stand clear of each other
	return 0.0


func check(spec: ChurchSpec, builder: ChurchBuilder) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	if masses.is_empty():
		failures.append("massing: builder logged no structural masses")
		return _report()

	var g: Dictionary = MassRules.gaps(masses, "nave")
	_add(g["failures"])
	stats["masses_joined"] = g["joined"]

	var o: Dictionary = MassRules.overlaps(masses,
		func(a: String, b: String) -> float: return _allowance(spec, a, b), FAMILIES)
	_add(o["failures"])
	stats["worst_penetration"] = o["worst"]

	_add(MassRules.grounded(masses, CARRIED))
	_check_size_match(spec, builder, masses)
	return _report()


func _add(msgs) -> void:
	for m in msgs:
		failures.append(str(m))


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


# ------------------------------------------------------------ size match

## The emitted masses must have the dimensions the spec asked for.
func _check_size_match(spec: ChurchSpec, builder: ChurchBuilder,
		masses: Array[Dictionary]) -> void:
	var by_name := {}
	for m in masses:
		by_name[m["name"]] = m["aabb"]

	if by_name.has("nave"):
		var nave: AABB = by_name["nave"]
		_expect("nave width", nave.size.x, spec.width)
		_expect("nave height", nave.size.y, spec.height)
		_expect("nave length", nave.size.z, spec.length)

	if spec.tower:
		for side in ChurchGeometry.west_tower_sides(spec):
			var key: String = "tower"
			if spec.west_towers >= 2:
				key = "tower_%s" % ("left" if side < 0.0 else "right")
			if by_name.has(key):
				var t: AABB = by_name[key]
				_expect("%s width" % key, t.size.x, spec.tower_width)
				_expect("%s depth" % key, t.size.z, spec.tower_width)
				_expect("%s height" % key, t.size.y, spec.tower_height)

	if spec.apse and by_name.has("apse"):
		var a: AABB = by_name["apse"]
		_expect("apse span", a.size.x, spec.apse_radius * 2.0)
		_expect("apse projection", a.size.z, spec.apse_radius)

	if spec.transept and by_name.has("transept"):
		_expect("transept span", by_name["transept"].size.x, spec.transept_len)

	for ring in range(spec.aisles):
		for side_name in ["left", "right"]:
			var k: String = "aisle_%s_%d" % [side_name, ring]
			if by_name.has(k):
				_expect("%s width" % k, by_name[k].size.x, spec.aisle_width)

	# A half-drum's AABB spans 2r across its face and r along it, so the exact
	# span depends on which way the alcove points. Bound it instead.
	for i in range(spec.radiating_chapels):
		var ck: String = "chapel_%d" % i
		if by_name.has(ck):
			var cb: AABB = by_name[ck]
			var longest: float = maxf(cb.size.x, cb.size.z)
			if longest > spec.chapel_radius * 2.0 + TOL:
				failures.append("size_match: %s spans %.2fm, wider than its %.2fm drum"
					% [ck, longest, spec.chapel_radius * 2.0])
			if longest < spec.chapel_radius - TOL:
				failures.append("size_match: %s spans only %.2fm for a %.2fm radius"
					% [ck, longest, spec.chapel_radius])

	if spec.dome and by_name.has("dome_drum"):
		_expect("dome span", by_name["dome_drum"].size.x, spec.dome_radius * 2.0)
		_expect("dome drum height", by_name["dome_drum"].size.y, spec.dome_drum_height)

	if spec.crossing_tower and by_name.has("crossing_tower"):
		var tower: AABB = by_name["crossing_tower"]
		var expected_tower: AABB = ChurchGeometry.crossing_tower_aabb(spec)
		_expect("crossing tower bearing elevation", tower.position.y, expected_tower.position.y)
		_expect("crossing tower wall height above bearing", tower.size.y, expected_tower.size.y)
		_expect("crossing tower top elevation", tower.end.y, expected_tower.end.y)


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > TOL:
		failures.append("size_match: %s is %.2fm, spec asked for %.2fm" % [what, got, want])
