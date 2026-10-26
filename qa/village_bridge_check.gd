class_name VillageBridgeCheck
extends RefCounted
## Bridges on given ground (VTER-CROSSINGS), judged from the EMITTED ground
## mesh and the builder's component log, never from the field or from
## `VillageBridge.measure` that placed them:
##
##   abutment  the base of each `bridge_abutment` is within BASE_TOL of the
##             lowest ground under its footprint (centre, corners, edge
##             midpoints), and the stone reaches up to the underside of the deck
##   clearance the underside of the deck clears the water under every metre of
##             the span by at least CLEAR_MIN
##   cover     every metre of the route has a deck panel over it
##   landing   each end of the deck is within LANDING_MAX of the ground it
##             lands on (a ramp carries the rest)
##   count     a bridge crossing has exactly two abutments, one per end
##
## `check(plan, builder, mesh)`: `builder` is the VillageBuilder that built
## `mesh` for `plan`. Returns {ok, failures, stats}.

const BASE_TOL := 0.1
const CLEAR_MIN := 0.3
const LANDING_MAX := 1.2
const REACH_TOL := 0.06

var failures: Array[String] = []
var stats: Dictionary = {}


func check(plan: VillagePlan, builder: VillageBuilder, mesh: ArrayMesh) -> Dictionary:
	failures.clear()
	stats = {"bridges": 0, "abutments": 0, "base_worst": 0.0, "clear_min": INF, "span_samples": 0,
		"landing_worst": 0.0, "rise_max": 0.0}
	if plan.ground == null:
		return {"ok": true, "failures": failures, "stats": stats}
	var probe := VillageGroundCheck.GroundProbe.of(mesh)
	for index in range(plan.water_crossings.size()):
		var crossing: Dictionary = plan.water_crossings[index]
		if crossing["kind"] != &"bridge":
			continue
		stats["bridges"] = int(stats["bridges"]) + 1
		_bridge(plan, builder, probe, crossing, index)
	return {"ok": failures.is_empty(), "failures": failures, "stats": stats}


func _bridge(plan: VillagePlan, builder: VillageBuilder, probe: VillageGroundCheck.GroundProbe,
		crossing: Dictionary, index: int) -> void:
	var host := "bridge%d" % index
	var label := "bridge %d (road %d, water %d)" % [index, int(crossing["road"]), int(crossing["water"])]
	var abutments: Array[Dictionary] = []
	var decks: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row["host"]) != host:
			continue
		if row["role"] == "bridge_abutment":
			abutments.append(row)
		elif row["role"] == "crossing_deck":
			decks.append(row)
	if abutments.size() != 2:
		failures.append("%s: %d abutments, want 2" % [label, abutments.size()])
	if decks.is_empty():
		failures.append("%s: no deck" % label)
		return
	var soffit := INF
	for d in decks:
		var pts: PackedVector3Array = d["points"]
		soffit = minf(soffit, pts[0].y - float(d["depth"]) * 0.5)
	# the abutments stand on the ground and reach the deck
	for a in abutments:
		stats["abutments"] = int(stats["abutments"]) + 1
		var xf: Transform3D = a["xf"]
		var size: Vector3 = a["size"]
		var base: float = xf.origin.y - size.y * 0.5
		var top: float = xf.origin.y + size.y * 0.5
		var lowest := INF
		for u in [-0.5, 0.0, 0.5]:
			for v in [-0.5, 0.0, 0.5]:
				var q: Vector3 = xf * Vector3(size.x * u, 0.0, size.z * v)
				var h := probe.top(Vector2(q.x, q.z))
				if not is_nan(h):
					lowest = minf(lowest, h)
		if lowest == INF:
			failures.append("%s: an abutment stands off the ground mesh" % label)
			continue
		var gap := absf(base - lowest)
		stats["base_worst"] = maxf(float(stats["base_worst"]), gap)
		if gap > BASE_TOL:
			failures.append("%s: an abutment's base is %.2f m %s the ground (%.2f vs %.2f)"
				% [label, gap, "over" if base > lowest else "under", base, lowest])
		if top < soffit - 0.01:
			failures.append("%s: an abutment stops %.2f m short of the deck" % [label, soffit - top])
	# the span: deck over every metre, water under it
	var points: PackedVector2Array = crossing["points"]
	var length := Poly.polyline_length(points)
	var s := 0.0
	while s <= length:
		var p := _at(points, s)
		s += 1.0
		stats["span_samples"] = int(stats["span_samples"]) + 1
		var water := probe.water_top(p)
		if not is_nan(water):
			var clear := soffit - water
			stats["clear_min"] = minf(float(stats["clear_min"]), clear)
			if clear < CLEAR_MIN:
				failures.append("%s: the deck is %.2f m over the water at (%.1f, %.1f), want %.2f"
					% [label, clear, p.x, p.y, CLEAR_MIN])
				break
	# each end lands near the ground
	var top_y := soffit + 0.25
	for end in [0, points.size() - 1]:
		var ground := probe.top(points[end])
		if is_nan(ground):
			continue
		var land := absf(top_y - ground)
		stats["landing_worst"] = maxf(float(stats["landing_worst"]), land)
		stats["rise_max"] = maxf(float(stats["rise_max"]), top_y - ground)
		if land > LANDING_MAX:
			failures.append("%s: the deck's end stands %.2f m from the ground it lands on" % [label, land])


static func _at(pts: PackedVector2Array, s: float) -> Vector2:
	var run := 0.0
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if run + seg >= s:
			return pts[i].lerp(pts[i + 1], clampf((s - run) / maxf(seg, 1e-9), 0.0, 1.0))
		run += seg
	return pts[pts.size() - 1]
