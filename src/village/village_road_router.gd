class_name VillageRoadRouter
extends RefCounted
## Roads laid by grade on the given ground (VTER-ROADS, docs/VILLAGE_TERRAIN.md).
##
## Only ever called with terrain. A plan without ground never reaches this
## file, which is how the flat planner stays byte-identical.
##
## Two tools:
##
## * `route_across` -- the through road. A least-cost path from one edge of
##   the site to the opposite edge, MONOTONE along the road's own axis, found
##   by dynamic programming over columns ~10 m apart. The state is the
##   lateral offset AND the heading of the incoming segment, and a step may
##   change the heading by one notch only (1 m of offset per column, under
##   6 degrees), so §5's bend rule (25 degrees per 20 m, radius >= 3 widths)
##   holds by construction and there is no staircase to smooth away. The
##   cost is length, grade (soft below the cap, prohibitive above it), wet
##   ground, turning, and distance from the form's own seeded bow -- so on
##   gentle ground the road is the flat planner's road, and on a hillside it
##   is the contour line nearest to it. Monotone along the axis is what every
##   form planner assumes (`_vertex_near_x`, `_polyline_y_at_x`); the siting
##   turns the site so that axis is the contour, which is why a monotone
##   road is enough.
## * `grade_of` -- the grade a road actually has: `VillageTerrain.profile`
##   on its final points, the measurement the acceptance uses.

const COLUMN_M := 10.0          ## columns along the axis (THROUGH_SAMPLE_M)
const OFFSET_STEP_M := 1.0      ## lateral lattice: a heading notch of 1 m per 10 m, under 6 degrees
const HEADINGS := 10            ## +-10 notches of 1 m per 10 m: up to 45 degrees off the axis
const ROUTE_MARGIN := 0.9       ## route to this share of the cap: the grade is re-measured on the final line
const W_GRADE := 25.0           ## per unit grade per metre: a 10 % grade costs 2.5 m per metre
const W_OVER := 4000.0          ## per unit grade above the cap per metre: never, if there is any other way
const W_WET := 500.0            ## per metre of road on standing water
const W_DEVIATE := 0.35         ## per metre off the seeded bow, per column
const W_TURN := 3.0             ## per notch of heading change


## The road from the column at `xs[0]` to the column at `xs[-1]`, one vertex
## per column. `height` is `func(along, across) -> float`; `seed` the form's
## own offsets per column (the flat road); offsets stay inside [lo, hi].
## `wet_level` NAN for no standing water. Returns the offsets per column.
static func route_across(height: Callable, xs: PackedFloat64Array, seed: PackedFloat64Array,
		lo: float, hi: float, cap: float, wet_level := NAN, pin := -1, pin_at := 0.0) -> PackedFloat64Array:
	var n := xs.size()
	var ny := int(floor((hi - lo) / OFFSET_STEP_M)) + 1
	if n < 2 or ny < 1:
		return seed
	var nk := HEADINGS * 2 + 1
	var limit := cap * ROUTE_MARGIN
	# heights at the lattice nodes and at the half-column, half-offset mids
	var node := PackedFloat64Array()
	node.resize(n * ny)
	for i in range(n):
		for j in range(ny):
			node[i * ny + j] = float(height.call(xs[i], lo + j * OFFSET_STEP_M))
	var nm := 2 * ny - 1
	var mid := PackedFloat64Array()
	mid.resize((n - 1) * nm)
	for i in range(n - 1):
		var xm := (xs[i] + xs[i + 1]) * 0.5
		for m in range(nm):
			mid[i * nm + m] = float(height.call(xm, lo + m * OFFSET_STEP_M * 0.5))
	var big := 1e18
	var cost := PackedFloat64Array()
	cost.resize(ny * nk)
	for j in range(ny):
		for k in range(nk):
			# the first column: any offset, any heading, paid only for leaving the bow
			cost[j * nk + k] = W_DEVIATE * absf(lo + j * OFFSET_STEP_M - seed[0]) * 3.0
	var pin_j := int(round((pin_at - lo) / OFFSET_STEP_M)) if pin >= 0 else -1
	if pin == 0:
		_pin(cost, pin_j, nk, big)
	var back: Array[PackedInt32Array] = []
	for i in range(n - 1):
		var dx := xs[i + 1] - xs[i]
		var nxt := PackedFloat64Array()
		nxt.resize(ny * nk)
		nxt.fill(big)
		var from := PackedInt32Array()
		from.resize(ny * nk)
		from.fill(-1)
		for j in range(ny):
			var ha := node[i * ny + j]
			for k in range(nk):
				var c0 := cost[j * nk + k]
				if c0 >= big:
					continue
				for dk in range(-1, 2):
					var k2: int = k + dk
					if k2 < 0 or k2 >= nk:
						continue
					var step := k2 - HEADINGS
					var j2 := j + step
					if j2 < 0 or j2 >= ny:
						continue
					var dy := step * OFFSET_STEP_M
					var length := sqrt(dx * dx + dy * dy)
					var hm := mid[i * nm + 2 * j + step]
					var hb := node[(i + 1) * ny + j2]
					var g := maxf(absf(hm - ha), absf(hb - hm)) / (length * 0.5)
					var c := c0 + length * (1.0 + W_GRADE * g) + W_TURN * absf(dk)
					if g > limit:
						c += W_OVER * (g - limit) * length
					if not is_nan(wet_level) and (hb <= wet_level or hm <= wet_level):
						c += W_WET * length
					c += W_DEVIATE * absf(lo + j2 * OFFSET_STEP_M - seed[i + 1]) * dx / COLUMN_M
					var s := j2 * nk + k2
					if c < nxt[s]:
						nxt[s] = c
						from[s] = j * nk + k
		back.append(from)
		cost = nxt
		if pin == i + 1:
			_pin(cost, pin_j, nk, big)
	# the cheapest end, ties to the lowest index (deterministic)
	var best := -1
	var best_c := big
	for s in range(ny * nk):
		if cost[s] < best_c:
			best_c = cost[s]
			best = s
	var out := PackedFloat64Array()
	out.resize(n)
	if best < 0:
		return seed
	var s2 := best
	for i in range(n - 1, -1, -1):
		out[i] = lo + (s2 / nk) * OFFSET_STEP_M
		if i > 0:
			s2 = back[i - 1][s2]
	return out


## Every state of a column off the pinned offset becomes unreachable.
static func _pin(cost: PackedFloat64Array, pin_j: int, nk: int, big: float) -> void:
	for s in range(cost.size()):
		if s / nk != pin_j:
			cost[s] = big


## The steepest grade along a polyline on `ground`, sampled at the grid's
## own cell as `VillageTerrain.profile` does.
static func grade_of(ground: VillageTerrain, points: PackedVector2Array) -> float:
	if ground == null or points.size() < 2:
		return 0.0
	return float(ground.profile(points)["grade_max"])
