class_name MassRules
extends RefCounted
## The three structural properties every building in this project must have,
## measured over a builder's mass_log rather than re-derived from its spec.
##
##   NO GAPS     every mass touches the assembly; nothing floats
##   NO OVERLAP  masses interpenetrate only at joints designed to, and only as
##               deep as that joint declares
##   GROUNDED    every mass stands on the ground, unless it is carried by one
##               that does
##
## What differs between a church and a castle is the joint table, not the rules,
## so the table arrives as a Callable and the rules live here once. Re-deriving
## geometry inside a check is what made the old parts_join test a tautology: it
## compared a formula against itself and could never fail.

const TOL := 0.05          # metres of slack on every comparison
const JOIN_TOL := 0.02     # max separation still counted as "touching"


## Separation between two AABBs: 0 if they touch or overlap, else the gap.
static func separation(a: AABB, b: AABB) -> float:
	var s := 0.0
	for axis in range(3):
		var lo: float = maxf(a.position[axis], b.position[axis])
		var hi: float = minf(a.position[axis] + a.size[axis], b.position[axis] + b.size[axis])
		s = maxf(s, lo - hi)
	return maxf(s, 0.0)


## Penetration depth of two overlapping AABBs: the shallowest axis of overlap.
## Zero when they merely touch or are apart.
static func penetration(a: AABB, b: AABB) -> float:
	var d := INF
	for axis in range(3):
		var lo: float = maxf(a.position[axis], b.position[axis])
		var hi: float = minf(a.position[axis] + a.size[axis], b.position[axis] + b.size[axis])
		if hi <= lo:
			return 0.0
		d = minf(d, hi - lo)
	return d


## Masses are named per instance (aisle_left_1, tower_0_corner_3); the joint
## tables are keyed by family, so the instance name is folded to its prefix.
static func family(n: String, prefixes: Array) -> String:
	for prefix in prefixes:
		if n.begins_with(prefix):
			return prefix
	return n


## Every mass must be reachable from `anchor` through touching neighbours.
## Returns {"failures": [...], "joined": int}.
static func gaps(masses: Array[Dictionary], anchor: String) -> Dictionary:
	var failures: Array[String] = []
	var n: int = masses.size()
	var start := -1
	for i in range(n):
		if masses[i]["name"] == anchor:
			start = i
			break
	if start < 0:
		failures.append("no_gaps: no %s mass to anchor the assembly" % anchor)
		return {"failures": failures, "joined": 0}

	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		for j in range(n):
			if seen.has(j):
				continue
			if separation(masses[cur]["aabb"], masses[j]["aabb"]) <= JOIN_TOL:
				seen[j] = true
				stack.append(j)

	for i in range(n):
		if seen.has(i):
			continue
		# nearest neighbour, to describe the gap usefully
		var best := INF
		var near := ""
		for j in range(n):
			if i == j:
				continue
			var s: float = separation(masses[i]["aabb"], masses[j]["aabb"])
			if s < best:
				best = s
				near = masses[j]["name"]
		failures.append("no_gaps: %s floats free -- nearest mass (%s) is %.2fm away"
			% [masses[i]["name"], near, best])
	return {"failures": failures, "joined": seen.size()}


## Masses may interpenetrate only where a joint declares it, and only that deep.
## `allow` takes two family names and returns the permitted depth in metres;
## INF marks a crossing meant to pass fully through.
## Returns {"failures": [...], "worst": float}.
static func overlaps(masses: Array[Dictionary], allow: Callable,
		prefixes: Array) -> Dictionary:
	var failures: Array[String] = []
	var n: int = masses.size()
	var worst := 0.0
	for i in range(n):
		for j in range(i + 1, n):
			var an: String = masses[i]["name"]
			var bn: String = masses[j]["name"]
			# two masses below ground are earth against earth (INT-016); a
			# mass above ground may reach into one below only if it is a
			# stair, which is what a stair down to a cellar does
			var neg_i: bool = is_negative(masses[i])
			var neg_j: bool = is_negative(masses[j])
			if neg_i and neg_j:
				continue
			var allowed: float = allow.call(family(an, prefixes), family(bn, prefixes))
			if neg_i != neg_j:
				var above: String = bn if neg_i else an
				allowed = INF if above.begins_with("stair") else 0.0
			if is_inf(allowed):
				continue
			var pen: float = penetration(masses[i]["aabb"], masses[j]["aabb"])
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
	return {"failures": failures, "worst": snappedf(worst, 0.01)}


## Every mass stands on the ground, except those whose names begin with one
## of `carried` -- the members held up by the walls below them, which is the
## whole point of a dome or a flyer arch.
##
## The ground is `ground_y` for the building (0 for every caller that has
## not said otherwise), or the mass's own `ground` field when it carries one
## (INT-016): a cellar's walls stand on the floor of the pit they are dug in,
## a terrace's on the terrace. A mass is grounded when its base is within
## tolerance of its own ground level.
static func grounded(masses: Array[Dictionary], carried: Array, ground_y := 0.0) -> Array[String]:
	var failures: Array[String] = []
	for m in masses:
		var nm: String = m["name"]
		var exempt := false
		for c in carried:
			if nm.begins_with(c):
				exempt = true
				break
		if exempt:
			continue
		var y0: float = (m["aabb"] as AABB).position.y
		var floor_y: float = float(m.get("ground", ground_y))
		if y0 > floor_y + TOL:
			failures.append("size_match: %s floats %.2fm above ground" % [nm, y0 - floor_y])
	return failures


## A mass dug below the ground plane: its top is at or under the ground.
static func is_negative(m: Dictionary) -> bool:
	var a: AABB = m["aabb"]
	return a.position.y + a.size.y <= TOL
