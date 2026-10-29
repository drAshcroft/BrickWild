class_name VillageCapacity
extends RefCounted
## A cheap, CONSERVATIVE answer to "can this ground hold this programme at all?"
## (BG-012-EARLY-REFUSE, docs/VILLAGE_TERRAIN.md "Refusing early").
##
## The lot planner finds out that a city does not fit by trying: a retry
## ladder of site widths and lanes, each a full re-plan, 43 minutes on a
## 720 m grid that was mostly lake and escarpment. This asks first, from the
## measured footprints and the ground alone, in milliseconds.
##
## It may never refuse a programme that would have fitted, so every number is
## an UPPER bound on the room and a LOWER bound on the need:
##
##   room   the nodes of the largest site the planner can ever lay (the
##          first site merged with a SITE_MAX_SIDE square about the origin,
##          at NODE_M), less the ground EVERY lot refuses: `wet` (a lot whose
##          centre or edge stands at or under the water level, `ground_clear`)
##          and, for the lot classes that are not terraced, `cliff` (steeper
##          than PATH_MAX, also past GroundFall.MAX_GRADIENT). A node is
##          removed only when it AND its eight neighbours are bad, so a thin
##          fringe, a gap between samples, a lot that merely touches bad
##          ground, all stay in.
##   need   the sum of the walls' footprints (buildings cannot overlap), and
##          for each building a clear disc of its shorter side: the rectangle
##          holds that disc, so it must find that much clear ground, less
##          CLEAR_SLACK_NODES of margin for the sampling.
##
## A seat (castle) or a church is TERRACED: its lot is judged on wet ground
## only, the cliff rule does not apply to it. `steep` (PLOT_MAX..PATH_MAX, a
## stepped plinth) removes nothing; it is reported so a refusal can say how
## much of what is left is a hillside.

const NODE_M := 5.0
const MARGIN_M := 13.0              ## HIGH_SIDE_GROW_M and the lot margin
const CLEAR_SLACK_NODES := 2.0
## Forms whose houses stand on or in the water, or whose frame is not the
## sited view: the estimate says nothing about them.
const SKIP_FORMS: Array[StringName] = [&"water"]
## Lot classes that stand on a terrace and are judged on wet ground only.
const TERRACED: Array[StringName] = [&"manor", &"church"]


## {} when the estimate does not apply; else
## {"refuse": bool, "reason": String, "rules": [{"rule", "removed_m2", "share"}],
##  "envelope_m2", "usable_m2", "usable_walled_m2", "need_m2", "need_walled_m2",
##  "steep_m2", "limiting": {...}}
static func estimate(plan: VillagePlan, jobs: Array[Dictionary]) -> Dictionary:
	if plan == null or plan.ground == null or jobs.is_empty() or plan.spec == null:
		return {}
	if plan.spec.form in SKIP_FORMS:
		return {}
	var g: VillageTerrain = plan.ground
	var envelope: Rect2 = plan.site.merge(Rect2(
		Vector2.ONE * -(VillageSitePlanner.SITE_MAX_SIDE * 0.5 + MARGIN_M),
		Vector2.ONE * (VillageSitePlanner.SITE_MAX_SIDE + 2.0 * MARGIN_M)))
	var nx := int(ceil(envelope.size.x / NODE_M)) + 1
	var ny := int(ceil(envelope.size.y / NODE_M)) + 1
	var wet := PackedByteArray()
	var cliff := PackedByteArray()
	var steep_n := 0
	wet.resize(nx * ny)
	cliff.resize(nx * ny)
	var wl: float = g.water_level_m
	for j in range(ny):
		for i in range(nx):
			var p := envelope.position + Vector2(i, j) * NODE_M
			var k := j * nx + i
			if not is_nan(wl) and g.height_at(p) <= wl:
				wet[k] = 1
				continue
			var s := g.slope_at(p)
			if s > VillageSiteAnalysis.PATH_MAX:
				cliff[k] = 1
			elif s > VillageSiteAnalysis.PLOT_MAX:
				steep_n += 1
	# a node is out only when its whole neighbourhood is
	var wet_core := _core(wet, nx, ny)
	var bad_core := _core(_either(wet, cliff), nx, ny)
	var node_m2 := NODE_M * NODE_M
	var envelope_m2 := float(nx * ny) * node_m2
	var wet_m2 := float(_count(wet_core)) * node_m2
	var bad_m2 := float(_count(bad_core)) * node_m2
	var usable_m2 := envelope_m2 - wet_m2
	var usable_walled_m2 := envelope_m2 - bad_m2
	# the need
	var need := 0.0
	var need_walled := 0.0
	var worst := {}
	var worst_gap := 0.0
	var field_cache := {}
	for job in jobs:
		var fp: Rect2 = job["footprint"]
		var area := fp.size.x * fp.size.y
		var terraced: bool = (job["class"] as StringName) in TERRACED
		need += area
		if not terraced:
			need_walled += area
		var want_m := minf(fp.size.x, fp.size.y) * 0.5 - CLEAR_SLACK_NODES * NODE_M
		if want_m <= 0.0:
			continue
		var key := 1 if terraced else 0
		if not field_cache.has(key):
			field_cache[key] = _clear_m(wet_core if terraced else bad_core, nx, ny)
		var have: float = field_cache[key]
		var gap := want_m - have
		if gap > worst_gap:
			worst_gap = gap
			worst = {"building": _label(job), "needs_clear_radius_m": snappedf(want_m, 0.1),
				"best_clear_radius_m": snappedf(have, 0.1), "terraced": terraced}
	var refuse := false
	var why := ""
	if need > usable_m2:
		refuse = true
		why = "the programme's walls cover %.0f m2 and the ground within the largest site is dry for only %.0f m2" % [need, usable_m2]
	elif need_walled > usable_walled_m2:
		refuse = true
		why = "the houses and shops need %.0f m2 and only %.0f m2 of the largest site is dry and under %d %%" % [
			need_walled, usable_walled_m2, int(VillageSiteAnalysis.PATH_MAX * 100.0)]
	elif not worst.is_empty():
		refuse = true
		why = "%s needs a clear disc of %.1f m radius and the ground has %.1f m at most" % [
			worst["building"], worst["needs_clear_radius_m"], worst["best_clear_radius_m"]]
	return {
		"refuse": refuse,
		"reason": why,
		"rules": [
			_rule("wet", wet_m2, envelope_m2),
			_rule("cliff", maxf(0.0, bad_m2 - wet_m2), envelope_m2),
		],
		"steep_m2": snappedf(float(steep_n) * node_m2, 1.0),
		"envelope_m2": snappedf(envelope_m2, 1.0),
		"usable_m2": snappedf(usable_m2, 1.0),
		"usable_walled_m2": snappedf(usable_walled_m2, 1.0),
		"need_m2": snappedf(need, 1.0),
		"need_walled_m2": snappedf(need_walled, 1.0),
		"limiting": worst,
		"node_m": NODE_M,
	}


static func _rule(rule: String, m2: float, envelope_m2: float) -> Dictionary:
	return {"rule": rule, "removed_m2": snappedf(m2, 1.0),
		"share": snappedf(m2 / maxf(envelope_m2, 1.0), 0.001)}


static func _label(job: Dictionary) -> String:
	var request: BuildingRequest = job["request"]
	return "%s/%s" % [request.kind, request.purpose] if request.purpose != &"" else String(request.kind)


static func _either(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(a.size())
	for k in range(a.size()):
		out[k] = 1 if (a[k] != 0 or b[k] != 0) else 0
	return out


static func _count(m: PackedByteArray) -> int:
	var n := 0
	for v in m:
		n += 1 if v != 0 else 0
	return n


## The nodes whose 3 x 3 neighbourhood is all set. Past the grid's edge the
## neighbourhood is the edge itself: the envelope is the whole of the room, so
## its rim is not extra ground.
static func _core(m: PackedByteArray, nx: int, ny: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for j in range(ny):
		for i in range(nx):
			var all := true
			for dj in [-1, 0, 1]:
				var jj := clampi(j + dj, 0, ny - 1)
				for di in [-1, 0, 1]:
					if m[jj * nx + clampi(i + di, 0, nx - 1)] == 0:
						all = false
						break
				if not all:
					break
			out[j * nx + i] = 1 if all else 0
	return out


## The radius, in metres, of the largest disc of nodes that are not set: the
## chamfer distance from the nearest set node, to the grid's edge as well.
static func _clear_m(bad: PackedByteArray, nx: int, ny: int) -> float:
	var inf := 1.0e9
	var d := PackedFloat32Array()
	d.resize(nx * ny)
	for k in range(d.size()):
		d[k] = 0.0 if bad[k] != 0 else inf
	var diag := 1.41421356
	for j in range(ny):
		for i in range(nx):
			var k := j * nx + i
			var v := d[k]
			if i > 0:
				v = minf(v, d[k - 1] + 1.0)
			if j > 0:
				v = minf(v, d[k - nx] + 1.0)
				if i > 0:
					v = minf(v, d[k - nx - 1] + diag)
				if i < nx - 1:
					v = minf(v, d[k - nx + 1] + diag)
			d[k] = v
	var best := 0.0
	for j in range(ny - 1, -1, -1):
		for i in range(nx - 1, -1, -1):
			var k := j * nx + i
			var v := d[k]
			if i < nx - 1:
				v = minf(v, d[k + 1] + 1.0)
			if j < ny - 1:
				v = minf(v, d[k + nx] + 1.0)
				if i < nx - 1:
					v = minf(v, d[k + nx + 1] + diag)
				if i > 0:
					v = minf(v, d[k + nx - 1] + diag)
			d[k] = v
			best = maxf(best, v)
	# a ground with nothing bad at all has no limit
	return minf(best, inf) * NODE_M
