class_name MassingCheck
extends RefCounted
## Correctness checks over a church's structural masses.
##
## Three properties, all measured from the geometry the builder actually
## emitted (via ChurchBuilder.mass_log) rather than re-derived from the spec.
## Re-deriving is what made the older parts_join check a tautology: it compared
## a formula against itself and could never fail.
##
##   NO GAPS     every mass touches the assembly; nothing floats
##   NO OVERLAP  masses interpenetrate only at joints designed to, and only
##               as deep as that joint declares
##   SIZE MATCH  emitted masses match the dimensions the spec asked for
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := 0.05          # metres of slack on every comparison
const JOIN_TOL := 0.02     # max separation still counted as "touching"

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


## Designed interpenetration per joint, in metres of penetration depth.
## A pair absent from this table is expected NOT to overlap at all.
## INF marks a crossing that is meant to pass fully through.
static func _allowance(a: String, b: String) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	match key:
		"nave|transept":
			return INF                        # the crossing, by definition
		"nave|tower":
			return ChurchGeometry.TOWER_EMBED
		"apse|nave":
			return ChurchGeometry.APSE_EMBED
		"aisle|nave":
			return ChurchGeometry.AISLE_LAP    # aisle wall laps the nave wall
		"aisle|transept", "aisle|tower":
			return 0.0                        # aisles are placed to clear both
		"apse|transept":
			return 0.0                        # apse springs from the east wall
		"apse|tower", "tower|transept":
			return 0.0                        # opposite ends of the church
	return 0.0


static func _family(n: String) -> String:
	return "aisle" if n.begins_with("aisle") else n


## Separation between two AABBs: 0 if they touch or overlap, else the gap.
static func _separation(a: AABB, b: AABB) -> float:
	var s := 0.0
	for axis in range(3):
		var lo: float = maxf(a.position[axis], b.position[axis])
		var hi: float = minf(a.position[axis] + a.size[axis], b.position[axis] + b.size[axis])
		s = maxf(s, lo - hi)
	return maxf(s, 0.0)


## Penetration depth of two overlapping AABBs: the shallowest axis of overlap.
## Zero when they merely touch or are apart.
static func _penetration(a: AABB, b: AABB) -> float:
	var d := INF
	for axis in range(3):
		var lo: float = maxf(a.position[axis], b.position[axis])
		var hi: float = minf(a.position[axis] + a.size[axis], b.position[axis] + b.size[axis])
		if hi <= lo:
			return 0.0
		d = minf(d, hi - lo)
	return d


func check(spec: ChurchSpec, builder: ChurchBuilder) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	if masses.is_empty():
		failures.append("massing: builder logged no structural masses")
		return _report()

	_check_no_gaps(masses)
	_check_no_overlap(masses)
	_check_size_match(spec, builder, masses)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


# --------------------------------------------------------------- no gaps

## Every mass must be reachable from the nave through touching neighbours.
## A detached mass is reported with the size of its gap.
func _check_no_gaps(masses: Array[Dictionary]) -> void:
	var n: int = masses.size()
	var start := -1
	for i in range(n):
		if masses[i]["name"] == "nave":
			start = i
			break
	if start < 0:
		failures.append("no_gaps: no nave mass to anchor the assembly")
		return

	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		for j in range(n):
			if seen.has(j):
				continue
			if _separation(masses[cur]["aabb"], masses[j]["aabb"]) <= JOIN_TOL:
				seen[j] = true
				stack.append(j)

	stats["masses_joined"] = seen.size()
	for i in range(n):
		if seen.has(i):
			continue
		# nearest neighbour, to describe the gap usefully
		var best := INF
		var near := ""
		for j in range(n):
			if i == j:
				continue
			var s: float = _separation(masses[i]["aabb"], masses[j]["aabb"])
			if s < best:
				best = s
				near = masses[j]["name"]
		failures.append("no_gaps: %s floats free -- nearest mass (%s) is %.2fm away"
			% [masses[i]["name"], near, best])


# ------------------------------------------------------------ no overlap

## Masses may interpenetrate only where a joint declares it, and only that deep.
func _check_no_overlap(masses: Array[Dictionary]) -> void:
	var n: int = masses.size()
	var worst := 0.0
	for i in range(n):
		for j in range(i + 1, n):
			var an: String = masses[i]["name"]
			var bn: String = masses[j]["name"]
			var allowed: float = _allowance(_family(an), _family(bn))
			if is_inf(allowed):
				continue
			var pen: float = _penetration(masses[i]["aabb"], masses[j]["aabb"])
			if pen <= 0.0:
				continue
			worst = maxf(worst, pen)
			if pen > allowed + TOL:
				if allowed <= 0.0:
					failures.append("no_overlap: %s and %s interpenetrate %.2fm; they must not touch"
						% [an, bn, pen])
				else:
					failures.append("no_overlap: %s into %s by %.2fm, joint allows %.2fm"
						% [an, bn, pen, allowed])
	stats["worst_penetration"] = snappedf(worst, 0.01)


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

	if spec.tower and by_name.has("tower"):
		var t: AABB = by_name["tower"]
		_expect("tower width", t.size.x, spec.tower_width)
		_expect("tower depth", t.size.z, spec.tower_width)
		_expect("tower height", t.size.y, spec.tower_height)

	if spec.apse and by_name.has("apse"):
		var a: AABB = by_name["apse"]
		_expect("apse span", a.size.x, spec.apse_radius * 2.0)
		_expect("apse projection", a.size.z, spec.apse_radius)

	if spec.transept and by_name.has("transept"):
		var tr: AABB = by_name["transept"]
		_expect("transept span", tr.size.x, spec.transept_len)

	if spec.aisles > 0:
		for side in ["aisle_left", "aisle_right"]:
			if by_name.has(side):
				_expect("%s width" % side, by_name[side].size.x, spec.aisle_width)

	# every mass must stand on the ground plane, not hover above it
	for m in masses:
		var y0: float = m["aabb"].position.y
		if y0 > TOL:
			failures.append("size_match: %s floats %.2fm above ground" % [m["name"], y0])


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > TOL:
		failures.append("size_match: %s is %.2fm, spec asked for %.2fm" % [what, got, want])
