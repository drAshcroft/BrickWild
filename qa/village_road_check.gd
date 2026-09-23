class_name VillageRoadCheck
extends RefCounted
## Do the roads make sense? (VIL-007; VILLAGES 9.2)
##
##   CONNECTED   you can drive from any road to any other
##   THROUGH     the through road comes in one side and goes out another,
##               and passes the common
##   HIERARCHY   lanes join streets, streets join the through road
##   DEAD_ENDS   a road goes somewhere: a dead end is a short lane at a lot
##   WIDTH       a road is as wide as its class
##   BENDS       roads curve, they do not kink
##   JUNCTIONS   roads meet at angles you can turn through, apart
##   CLEAR       nothing stands in the road
##   CROSSINGS   water is crossed by a bridge or a ford, on the road
##   GATES       roads cross the edge only at gates
##
## Every rule is a sentence and a measurement over the plan's polylines and
## polygons alone. `ascii_map()` draws the roads as `=`.

const RULES: Array[StringName] = [&"connected", &"through", &"hierarchy", &"dead_ends",
	&"width", &"bends", &"junctions", &"clear", &"crossings", &"gates"]
const THROUGH_TO_COMMON := 15.0
const DEAD_END_MAX := 40.0
const WIDTH_TOL := 0.05
const BEND_DEG_PER_20M := 25.0
const BEND_RADIUS_X_WIDTH := 3.0
const JUNCTION_MIN_DEG := 30.0
const JUNCTION_APART := 8.0
const ON_ROAD_EPS := 0.6

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}
var _plan: VillagePlan


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	_plan = plan
	stats["roads"] = plan.roads.size()
	if plan.roads.is_empty():
		failures.append("connected: the village has no roads")
		return _report()
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


func _check_connected(plan: VillagePlan) -> void:
	var parts: int = VillageSitePlanner.road_components(plan)
	stats["road_components"] = parts
	if parts != 1:
		failures.append("connected: the roads are %d separate networks" % parts)


func _check_through(plan: VillagePlan) -> void:
	var through: Array[int] = plan.roads_of_class(&"through")
	if through.is_empty() or through.size() > 2:
		failures.append("through: %d through roads; a village has one, or two at a crossroads" % through.size())
		return
	for r in through:
		var pts: PackedVector2Array = plan.roads[r]["points"]
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[pts.size() - 1]
		var sa: int = VillageMeasure.boundary_side(plan.site, a)
		var sb: int = VillageMeasure.boundary_side(plan.site, b)
		if sa < 0 or sb < 0:
			failures.append("through: road %d does not reach the edge of the site at both ends" % r)
		elif sa == sb:
			failures.append("through: road %d comes in and goes out on the same side" % r)
		var common: PackedVector2Array = VillageMeasure.common_poly(plan)
		if not common.is_empty():
			var near := INF
			for p in common:
				near = minf(near, VillageMeasure.point_to_polyline(p, pts))
			if near > THROUGH_TO_COMMON:
				failures.append("through: road %d passes %.0fm from the common, wants %.0f" % [r, near, THROUGH_TO_COMMON])


## Where an endpoint of `road` lands: on another road of one of `classes`,
## at a lot's front, on the boundary, or nowhere.
func _endpoint_on(plan: VillagePlan, road: int, p: Vector2, classes: Array) -> bool:
	for j in range(plan.roads.size()):
		if j == road:
			continue
		if not (plan.roads[j]["class"] in classes):
			continue
		if VillageMeasure.point_to_polyline(p, plan.roads[j]["points"]) <= ON_ROAD_EPS + float(plan.roads[j]["width"]) / 2.0:
			return true
	return false


func _endpoint_at_lot(plan: VillagePlan, road: int, p: Vector2) -> bool:
	for lot in plan.lots:
		if int(lot["road"]) != road:
			continue
		var front: PackedVector2Array = lot["front"]
		var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, front[0], front[1]))
		if d <= float(plan.roads[road]["width"]) / 2.0 + float(plan.roads[road]["verge"]) + 1.0:
			return true
	return false


## A round village's single civic lane deliberately terminates inside its
## common.  It is not a forgotten cul-de-sac: the common is the destination
## and the form's defining road count is exactly one lane in.
func _endpoint_on_common(plan: VillagePlan, p: Vector2) -> bool:
	for common in plan.commons:
		if Poly.contains_point(common["poly"], p) \
			or VillageMeasure.point_to_poly(p, common["poly"]) <= 0.75:
			return true
	return false


func _check_hierarchy(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		var cls: StringName = road["class"]
		for p in [pts[0], pts[pts.size() - 1]]:
			match cls:
				&"lane":
					if not _endpoint_on(plan, r, p, [&"street", &"through"]) \
						and not _endpoint_at_lot(plan, r, p) \
						and not _endpoint_on_common(plan, p):
						failures.append("hierarchy: lane %d ends at %v on nothing -- a lane joins a street or ends at a lot" % [r, p])
				&"street":
					if not _endpoint_on(plan, r, p, [&"street", &"through"]):
						failures.append("hierarchy: street %d ends at %v off the through road and every street" % [r, p])


func _check_dead_ends(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		var cls: StringName = road["class"]
		for p in [pts[0], pts[pts.size() - 1]]:
			if VillageMeasure.on_boundary(plan.site, p):
				continue
			if _endpoint_on(plan, r, p, [&"through", &"street", &"lane", &"track", &"path"]):
				continue
			if cls in [&"lane", &"path"] and _endpoint_on_common(plan, p):
				continue
			# a dead end: only a short lane ending at a lot may
			if cls != &"lane":
				failures.append("dead_ends: %s %d dead-ends at %v" % [String(cls), r, p])
			elif not _endpoint_at_lot(plan, r, p):
				failures.append("dead_ends: lane %d dead-ends at %v with no lot at its end" % [r, p])
			elif Poly.polyline_length(pts) > DEAD_END_MAX:
				failures.append("dead_ends: lane %d is %.0fm long for a dead end, wants <= %.0f"
					% [r, Poly.polyline_length(pts), DEAD_END_MAX])


func _check_width(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var want: float = float(VillageSitePlanner.ROAD_CLASSES[road["class"]]["width"])
		var got: float = float(road["width"])
		if absf(got - want) > want * WIDTH_TOL:
			failures.append("width: %s %d is %.2fm wide, its class is %.2f" % [String(road["class"]), r, got, want])
		# and the ribbon really is that wide: the offset of each edge from
		# the centreline
		var ribbon: PackedVector2Array = VillageSitePlanner.road_ribbon(road, false)
		var pts: PackedVector2Array = road["points"]
		var worst := 0.0
		for v in ribbon:
			worst = maxf(worst, absf(VillageMeasure.point_to_polyline(v, pts) - got / 2.0))
		if worst > got * WIDTH_TOL + 0.05:
			failures.append("width: %s %d's ribbon strays %.2fm from its own width" % [String(road["class"]), r, worst])


func _check_bends(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		var width: float = float(road["width"])
		var turns: PackedFloat32Array = Poly.turns(pts)
		for i in range(1, pts.size() - 1):
			var run: float = (pts[i].distance_to(pts[i - 1]) + pts[i].distance_to(pts[i + 1])) / 2.0
			var deg: float = rad_to_deg(absf(turns[i - 1]))
			var per20: float = deg * 20.0 / maxf(run, 0.01)
			if deg > 1.0 and per20 > BEND_DEG_PER_20M + 0.5:
				failures.append("bends: %s %d turns %.0f degrees in %.0fm at %v" % [String(road["class"]), r, deg, run, pts[i]])
				break
			var radius: float = Poly.bend_radius(pts[i - 1], pts[i], pts[i + 1])
			if deg > 1.0 and radius < BEND_RADIUS_X_WIDTH * width - 0.05:
				failures.append("bends: %s %d bends at a %.0fm radius at %v, wants %.0f" % [String(road["class"]), r, radius, pts[i], BEND_RADIUS_X_WIDTH * width])
				break


func _check_junctions(plan: VillagePlan) -> void:
	var junctions: Array[Dictionary] = VillageSitePlanner.junctions(plan)
	stats["junctions"] = junctions.size()
	var square := PackedVector2Array()
	for c in plan.commons:
		if c["kind"] == &"square":
			square = c["poly"]
	for k in range(junctions.size()):
		var j: Dictionary = junctions[k]
		var dirs: Array = j["dirs"]
		var smallest := 180.0
		for a in range(dirs.size()):
			for b in range(a + 1, dirs.size()):
				var ang: float = rad_to_deg(absf((dirs[a] as Vector2).angle_to(dirs[b])))
				if ang > 0.5:
					smallest = minf(smallest, ang)
		if smallest < JUNCTION_MIN_DEG - 0.5:
			failures.append("junctions: roads meet at %.0f degrees at %v" % [smallest, j["pos"]])
		for k2 in range(k + 1, junctions.size()):
			var d: float = (j["pos"] as Vector2).distance_to(junctions[k2]["pos"])
			if d < JUNCTION_APART - 0.05:
				if not square.is_empty() and Poly.contains_point(Poly.offset(square, 2.0), j["pos"]):
					continue
				failures.append("junctions: two junctions %.1fm apart at %v" % [d, j["pos"]])


## Nothing stands in the road: no building's walls in a road grown by its
## verge, no eaves over the carriageway, no lot, prop or trunk in it.
func _check_clear(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var verged: PackedVector2Array = VillageSitePlanner.road_ribbon(road, true)
		var way: PackedVector2Array = VillageSitePlanner.road_ribbon(road, false)
		for i in range(plan.buildings.size()):
			var b: Dictionary = plan.buildings[i]
			if VillageLotPlanner.overlap_area(VillageMeasure.footprint_poly(b), verged) > VillageLotPlanner.AREA_EPS:
				failures.append("clear: building %d stands in %s %d" % [i, String(road["class"]), r])
			elif VillageLotPlanner.overlap_area(VillageMeasure.bounds_poly(b), way) > VillageLotPlanner.AREA_EPS:
				failures.append("clear: building %d's eaves hang over %s %d" % [i, String(road["class"]), r])
		for li in range(plan.lots.size()):
			if VillageLotPlanner.overlap_area(plan.lots[li]["poly"], verged) > VillageLotPlanner.AREA_EPS:
				failures.append("clear: lot %d is cut into %s %d" % [li, String(road["class"]), r])
		for p in plan.props:
			var zone: Rect2 = p.get("zone", Rect2())
			var foot: PackedVector2Array = Poly.from_rect(zone) if zone.size.x > 0.0 \
				else Poly.from_rect(Rect2(Vector2(p["pos"]) - Vector2(0.25, 0.25), Vector2(0.5, 0.5)))
			if VillageLotPlanner.overlap_area(foot, verged) > VillageLotPlanner.AREA_EPS:
				failures.append("clear: %s stands in %s %d" % [String(p["key"]), String(road["class"]), r])
				break
		for t in plan.plants:
			var trunk: float = float(t.get("trunk", 0.0))
			if trunk <= 0.0:
				continue
			if Poly.contains_point(verged, t["pos"]):
				failures.append("clear: a %s trunk stands in %s %d" % [String(t["key"]), String(road["class"]), r])
				break


## Independently subtract the recorded decks from the actual wet road area.
## A centre point alone cannot prove that a wide or curved road is carried.
func _check_crossings(plan: VillagePlan) -> void:
	var decks: Array[Dictionary] = []
	for index in plan.water_crossings.size():
		var crossing: Dictionary = plan.water_crossings[index]
		var r := int(crossing.get("road", -1))
		var w := int(crossing.get("water", -1))
		if r < 0 or r >= plan.roads.size() or w < 0 or w >= plan.water.size():
			failures.append("crossings: crossing %d has stale road/water indices" % index)
			continue
		var expected := &"ford" if plan.water[w]["kind"] == &"stream" else &"bridge"
		var points: PackedVector2Array = crossing.get("points", PackedVector2Array())
		var width := float(crossing.get("width", 0.0))
		if crossing.get("kind") != expected or points.size() < 2 or width + 0.01 < float(plan.roads[r]["width"]):
			failures.append("crossings: crossing %d has an invalid kind, route or width" % index)
			continue
		var on_road := true
		for i in range(points.size() - 1):
			for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
				if VillageMeasure.point_to_polyline(points[i].lerp(points[i + 1], t), plan.roads[r]["points"]) > 0.1:
					on_road = false
		if not on_road:
			failures.append("crossings: crossing %d leaves its road" % index)
			continue
		decks.append({"road": r, "water": w, "poly": Poly.ribbon(points, width * 0.5 + 0.4)})
	for w in plan.water.size():
		for r in plan.roads.size():
			var road: Dictionary = plan.roads[r]
			var remaining: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
				VillageSitePlanner.road_ribbon(road, false), plan.water[w]["poly"])
			for deck in decks:
				if deck["road"] != r or deck["water"] != w:
					continue
				var next: Array[PackedVector2Array] = []
				for piece in remaining:
					next.append_array(Geometry2D.clip_polygons(piece, deck["poly"]))
				remaining = next
			var uncovered := 0.0
			for piece in remaining:
				uncovered += Poly.area(piece)
			if uncovered > 0.05:
				failures.append("crossings: %s %d has %.2fm2 of %s without a bridge or ford"
					% [road["class"], r, uncovered, plan.water[w]["kind"]])


## Roads cross the enclosure only at gates, and every gate is where a road
## crosses.
func _check_gates(plan: VillagePlan) -> void:
	if plan.enclosure.size() < 3:
		if plan.spec.enclosure != &"none" and not plan.lots.is_empty():
			failures.append("gates: enclosed settlement has no persistent boundary")
		return
	failures.append_array(VillageEnclosureCheck.gate_faults(plan, plan.enclosure, plan.gate_crossings))
	if plan.spec.enclosure != &"none" and not plan.buildings.is_empty() and plan.gate_crossings.is_empty():
		failures.append("gates: enclosed settlement has no road entrance")


## The plan as a picture: `=` road, `.` common, `#` building, `~` water,
## `|` enclosure, `G` gate.
func ascii_map(cell := 4.0) -> String:
	var plan: VillagePlan = _plan
	var w: int = maxi(int(plan.site.size.x / cell), 1)
	var h: int = maxi(int(plan.site.size.y / cell), 1)
	var rows: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(" ")
		rows.append(row)
	var put := func(p: Vector2, ch: String) -> void:
		var cx: int = int((p.x - plan.site.position.x) / cell)
		var cy: int = int((p.y - plan.site.position.y) / cell)
		if cx >= 0 and cx < w and cy >= 0 and cy < h:
			rows[cy][cx] = ch
	for y in range(h):
		for x in range(w):
			var p := plan.site.position + Vector2((float(x) + 0.5) * cell, (float(y) + 0.5) * cell)
			for c in plan.commons:
				if Poly.contains_point(c["poly"], p):
					rows[y][x] = "."
			for wa in plan.water:
				if Poly.contains_point(wa["poly"], p):
					rows[y][x] = "~"
			for b in plan.buildings:
				if Poly.contains_point(VillageMeasure.bounds_poly(b), p):
					rows[y][x] = "#"
	for road in plan.roads:
		var pts: PackedVector2Array = road["points"]
		for i in range(pts.size() - 1):
			var n: int = maxi(int(pts[i].distance_to(pts[i + 1]) / (cell * 0.5)), 1)
			for k in range(n + 1):
				put.call(pts[i].lerp(pts[i + 1], float(k) / float(n)), "=")
	for i in range(plan.enclosure.size()):
		var a: Vector2 = plan.enclosure[i]
		var b: Vector2 = plan.enclosure[(i + 1) % plan.enclosure.size()]
		var n2: int = maxi(int(a.distance_to(b) / (cell * 0.5)), 1)
		for k in range(n2 + 1):
			put.call(a.lerp(b, float(k) / float(n2)), "|")
	for g in plan.gate_crossings:
		put.call(g["pos"], "G")
	var out := ""
	for y in range(h - 1, -1, -1):
		out += "".join(rows[y]) + "\n"
	return out
