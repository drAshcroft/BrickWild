class_name VillageLotCheck
extends RefCounted
## Do the houses sit on the street? (VIL-008; VILLAGES 9.3)
##
##   TILING         lots do not overlap each other, the roads, the common or
##                  the water
##   FRONTAGE       every lot has a road: a front edge on a road edge, long
##                  enough for the building and a metre
##   FACES_ROAD     the house looks at the street
##   SETBACK        the door is a few steps from the road, by its kind
##   FIT            the building is on its lot, with the fire gap as margin
##   FIRE_GAP       neighbours do not touch, terraces excepted where allowed
##   BACK_TO_FRONT  no house stares at a blank wall
##   VARIETY        no two neighbours are the same house, and no style owns
##                  the village
##
## Every number is read off the plan and the measured `placement()` the plan
## carries, never off the requested envelope.

const RULES: Array[StringName] = [&"tiling", &"frontage", &"faces_road", &"setback",
	&"fit", &"fire_gap", &"back_to_front", &"variety"]
const COLLINEAR_EPS := 0.1
const FRONT_SLACK := 1.0
const FACE_DEG := 15.0
const BAND_SLACK := 0.05
const BACK_TO_FRONT_M := 8.0
const STYLE_SHARE_MAX := 0.45
const NEIGHBOUR_M := 12.0
const MIXING_WEALTH := 0.55

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["lots"] = plan.lots.size()
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


func _check_tiling(plan: VillagePlan) -> void:
	for i in range(plan.lots.size()):
		var a: PackedVector2Array = plan.lots[i]["poly"]
		for j in range(i + 1, plan.lots.size()):
			if VillageLotPlanner.overlap_area(a, plan.lots[j]["poly"]) > VillageLotPlanner.AREA_EPS:
				failures.append("tiling: lots %d and %d overlap" % [i, j])
		for r in range(plan.roads.size()):
			if VillageLotPlanner.overlap_area(a, VillageSitePlanner.road_ribbon(plan.roads[r], true)) > VillageLotPlanner.AREA_EPS:
				failures.append("tiling: lot %d is cut into %s %d" % [i, String(plan.roads[r]["class"]), r])
		for c in plan.commons:
			if VillageLotPlanner.overlap_area(a, c["poly"]) > VillageLotPlanner.AREA_EPS:
				failures.append("tiling: lot %d is cut into the %s" % [i, String(c["kind"])])
		for w in plan.water:
			if VillageLotPlanner.overlap_area(a, w["poly"]) > VillageLotPlanner.AREA_EPS:
				failures.append("tiling: lot %d is cut into the %s" % [i, String(w["kind"])])


func _check_frontage(plan: VillagePlan) -> void:
	var edges: Array[Dictionary] = VillageLotPlanner.road_edges(plan)
	for i in range(plan.lots.size()):
		var lot: Dictionary = plan.lots[i]
		var front: PackedVector2Array = lot["front"]
		var road: int = int(lot["road"])
		if road < 0 or road >= plan.roads.size():
			failures.append("frontage: lot %d has no road" % i)
			continue
		var on := false
		for e in edges:
			if int(e["road"]) != road:
				continue
			if VillageLotPlanner.distance_to_edge_line(e, front[0]) <= COLLINEAR_EPS \
					and VillageLotPlanner.distance_to_edge_line(e, front[1]) <= COLLINEAR_EPS:
				on = true
		if not on:
			failures.append("frontage: lot %d's front edge is not on the edge of %s %d" % [i, String(plan.roads[road]["class"]), road])
		var b: int = _building_on(plan, i)
		if b >= 0:
			var fp: Rect2 = plan.buildings[b]["placement"]["footprint"]
			var have: float = front[0].distance_to(front[1])
			if have < fp.size.x + FRONT_SLACK - 0.01:
				failures.append("frontage: lot %d's front is %.1fm for a %.1fm building" % [i, have, fp.size.x])


static func _building_on(plan: VillagePlan, lot: int) -> int:
	for i in range(plan.buildings.size()):
		if int(plan.buildings[i]["lot"]) == lot:
			return i
	return -1


## The lot's inward normal: from the front edge into the lot.
static func _inward(lot: Dictionary) -> Vector2:
	var front: PackedVector2Array = lot["front"]
	var poly: PackedVector2Array = lot["poly"]
	var d: Vector2 = (front[1] - front[0]).normalized()
	var n := Vector2(-d.y, d.x)
	var mid: Vector2 = (front[0] + front[1]) / 2.0
	if not Poly.contains_point(poly, mid + n * 0.5) and Poly.contains_point(poly, mid - n * 0.5):
		n = -n
	return n


func _check_faces_road(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var toward_road: Vector2 = -_inward(lot)
		var deg: float = rad_to_deg(acos(clampf(VillageMeasure.front_dir(b).dot(toward_road), -1.0, 1.0)))
		if deg > FACE_DEG + 0.5:
			failures.append("faces_road: building %d looks %.0f degrees away from its road" % [i, deg])


func _check_setback(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var front: PackedVector2Array = lot["front"]
		var rule: Dictionary = VillageLotPlanner.LOT_RULES.get(b["class"], VillageLotPlanner.LOT_RULES[&"cottage"])
		var door: Vector2 = VillageMeasure.door(b)
		var d: Vector2 = (front[1] - front[0]).normalized()
		var dist: float = absf(d.cross(door - front[0]))
		if dist < float(rule["set_min"]) - BAND_SLACK or dist > float(rule["set_max"]) + BAND_SLACK:
			failures.append("setback: building %d's door is %.1fm from the road; a %s stands %.1f-%.1fm back"
				% [i, dist, String(b["class"]), float(rule["set_min"]), float(rule["set_max"])])


func _check_fit(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var lot: PackedVector2Array = plan.lots[int(b["lot"])]["poly"]
		var gap: float = VillageLotPlanner.fire_gap(b["class"], plan.spec)
		if not VillageLotPlanner._poly_contains(lot, VillageMeasure.footprint_poly(b)):
			failures.append("fit: building %d's walls stand off its lot" % i)
		elif not VillageLotPlanner._poly_contains(Poly.offset(lot, gap + 0.05), VillageMeasure.bounds_poly(b)):
			failures.append("fit: building %d's eaves reach more than a fire gap past its lot" % i)


func _check_fire_gap(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var a: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[i])
		for j in range(i + 1, plan.buildings.size()):
			var want: float = maxf(VillageLotPlanner.fire_gap(plan.buildings[i]["class"], plan.spec),
				VillageLotPlanner.fire_gap(plan.buildings[j]["class"], plan.spec))
			var d: float = VillageMeasure.poly_distance(a, VillageMeasure.bounds_poly(plan.buildings[j]))
			if d < want - 0.01:
				failures.append("fire_gap: buildings %d and %d stand %.1fm apart, want %.1f" % [i, j, d, want])


## A's front looks at B's back from close by.
func _check_back_to_front(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var a: Dictionary = plan.buildings[i]
		var af: Vector2 = VillageMeasure.front_dir(a)
		var ac: Vector2 = VillageMeasure.front_mid(a)
		for j in range(plan.buildings.size()):
			if i == j:
				continue
			var b: Dictionary = plan.buildings[j]
			var bc: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(b))
			var to: Vector2 = bc - ac
			var d: float = VillageMeasure.poly_distance(VillageMeasure.footprint_poly(a), VillageMeasure.footprint_poly(b))
			if d >= BACK_TO_FRONT_M or to.length() < 0.01:
				continue
			if af.dot(to.normalized()) < 0.7:
				continue      # B is not in front of A
			if VillageMeasure.front_dir(b).dot(to.normalized()) > 0.7:
				failures.append("back_to_front: building %d stares at the back of building %d %.1fm away" % [i, j, d])


## Neighbours differ, and no one style owns the village.
func _check_variety(plan: VillagePlan) -> void:
	var houses: Array[int] = plan.buildings_of_kind(&"house")
	for i in houses:
		var a: Dictionary = plan.buildings[i]
		for j in houses:
			if j <= i:
				continue
			var b: Dictionary = plan.buildings[j]
			if VillageMeasure.poly_distance(VillageMeasure.bounds_poly(a), VillageMeasure.bounds_poly(b)) > NEIGHBOUR_M:
				continue
			if _same_house(a, b):
				failures.append("variety: houses %d and %d are the same house side by side" % [i, j])
	var styles := {}
	for i2 in houses:
		var st: StringName = (plan.buildings[i2]["request"] as BuildingRequest).style
		styles[st] = int(styles.get(st, 0)) + 1
	# the programmer moves houses from cottage to townhouse with wealth, so
	# below the middle of the band the majority style is the village's
	# style by design; only a village rich enough to mix is held to a share
	for st in styles:
		var share: float = float(styles[st]) / float(maxi(houses.size(), 1))
		stats["style_" + String(st)] = styles[st]
		if houses.size() >= 5 and share > STYLE_SHARE_MAX and plan.spec.form != &"planted" \
				and styles.size() > 1 and plan.spec.wealth >= MIXING_WEALTH:
			failures.append("variety: %.0f%% of the houses are %s" % [share * 100.0, String(st)])


static func _same_house(a: Dictionary, b: Dictionary) -> bool:
	var ra: BuildingRequest = a["request"]
	var rb: BuildingRequest = b["request"]
	if ra.seed != rb.seed:
		return false
	var fa: Rect2 = a["placement"]["footprint"]
	var fb: Rect2 = b["placement"]["footprint"]
	return ra.style == rb.style and ra.storeys == rb.storeys \
		and snappedf(fa.size.x, 0.5) == snappedf(fb.size.x, 0.5) \
		and snappedf(fa.size.y, 0.5) == snappedf(fb.size.y, 0.5)
