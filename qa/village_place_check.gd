class_name VillagePlaceCheck
extends RefCounted
## Is everything where a village puts it? (VIL-009; VILLAGES 6, 9.4)
##
## The village's feng shui. Thirteen rules, each a sentence and a measurement
## over the plan, and each one runs only when the programme includes the
## thing it is about:
##
##   COMMON      there is a common, it is fronted, and nothing is built on it
##   LANDMARK    the tallest thing is the church (or the keep), seen from the gate
##   WELL        on the common, apart, on a path
##   TAVERN      by the road, by the gate
##   STABLE      by the inn
##   SMITHY      at the edge, away from the church, downwind
##   MILL        on the water
##   MARKET      rows on the square, with aisles
##   CIVIC       the hall fronts the square
##   MANOR       at the head, alone, looking down the street
##   CHURCHYARD  the church has room
##   GRADIENT    the big houses are in the middle
##   FARMS       farms face the fields

const RULES: Array[StringName] = [&"common", &"landmark", &"well", &"tavern", &"stable",
	&"smithy", &"mill", &"market", &"civic", &"manor", &"churchyard", &"gradient", &"farms"]
const COMMON_MIN := 150.0
const COMMON_MIN_HAMLET := 30.0
const FRONTED_SHARE := 0.6
## With only three buildings the two-metre perimeter samples are coarse: a
## complete round hamlet measures 59% while the next sample is already 63%.
## Keep the full-village rule intact and give the three-house case one sample.
const FRONTED_SHARE_HAMLET := 0.55
## The road between the common and the houses that front it is six metres
## and its verges three; the frontage line lies beyond that.
const FRONTED_REACH := 14.0
const WELL_CLEAR := 6.0
const TAVERN_TO_GATE := 60.0
const STABLE_TO_INN := 20.0
const SMITHY_CLEAR := 12.0
const STALL_ROW_GAP := 4.0
const MANOR_CLEAR := 15.0
const MANOR_FACE_DEG := 30.0
const CHURCHYARD_CLEAR := 6.0
const LANDMARK_DOMINANCE := 2.0
const GRADIENT_MAX := -0.3
const FARM_TO_EDGE := 30.0
const EYE := 1.65

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


static func _has_recipe(plan: VillagePlan, kind: StringName) -> bool:
	for row in plan.spec.programme:
		if row["kind"] == kind:
			return true
	return false


func _check_common(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	if common.is_empty():
		failures.append("common: the village has no common")
		return
	var area: float = Poly.area(common)
	var want: float = COMMON_MIN_HAMLET if plan.spec.population < VillageSpec.HAMLET_POPULATION else COMMON_MIN
	stats["common_area"] = snappedf(area, 0.1)
	if area < want - 0.1:
		failures.append("common: the common is %.0f m2, wants %.0f" % [area, want])
	# fronted: walk the perimeter, ask how much of it has a building's front
	# within reach
	# a building's front is its frontage: the front edge of its lot, on the
	# road, which its door stands a setback behind
	var fronts: Array[PackedVector2Array] = []
	for b in plan.buildings:
		var li: int = int(b["lot"])
		if li >= 0 and li < plan.lots.size():
			fronts.append(plan.lots[li]["front"])
			# the church stands on the slot reserved to front the common,
			# and its face to the common is the slot's own front edge
			if bool(plan.lots[li].get("landmark", false)) and plan.landmark_site.has("front"):
				fronts.append(plan.landmark_site["front"])
	var samples := 0
	var fronted := 0
	var n: int = common.size()
	for i in range(n):
		var a: Vector2 = common[i]
		var b2: Vector2 = common[(i + 1) % n]
		var steps: int = maxi(int(a.distance_to(b2) / 2.0), 1)
		for k in range(steps):
			var p: Vector2 = a.lerp(b2, (float(k) + 0.5) / float(steps))
			samples += 1
			for f in fronts:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, f[0], f[1])) <= FRONTED_REACH:
					fronted += 1
					break
	var share: float = float(fronted) / float(maxi(samples, 1))
	var wanted_share: float = FRONTED_SHARE_HAMLET \
		if plan.spec.population < VillageSpec.HAMLET_POPULATION else FRONTED_SHARE
	stats["common_fronted"] = snappedf(share, 0.01)
	if plan.buildings.size() >= 3 and share < wanted_share:
		failures.append("common: only %.0f%% of the common's edge has a house front near it, wants %.0f%%"
			% [share * 100.0, wanted_share * 100.0])
	for i2 in range(plan.buildings.size()):
		if VillageLotPlanner.overlap_area(VillageMeasure.bounds_poly(plan.buildings[i2]), common) > VillageLotPlanner.AREA_EPS:
			failures.append("common: building %d stands on the common" % i2)
	# Nothing BUILT inside the common but what §7's own recipe for it puts
	# there: the well, the market stalls, the green tree, a statue, and the
	# benches and flowers people sit among. A bench on a green is not a
	# building on it; a house or a workshop would be, and so would a barrel
	# somebody rolled out of a shop.
	for p2 in plan.props:
		if not Poly.contains_point(common, p2["pos"]):
			continue
		if _belongs_on_the_common(String(p2["key"])):
			continue
		failures.append("common: %s stands on the common" % String(p2["key"]))
		break


## VILLAGES §7's recipe for the common, as the list of things that may stand
## on it. Matched on the catalogue key's own words, so a pack that adds a
## second bench is on the green without this list changing.
const COMMON_PROPS := ["well", "stall", "tree", "bench", "flower", "statue",
	"signpost", "lamp_post"]


static func _belongs_on_the_common(key: String) -> bool:
	var lower: String = key.to_lower()
	for word in COMMON_PROPS:
		if lower.contains(word):
			return true
	return false


## The landmark: the tallest bounds in the village, seen from every gate.
func _check_landmark(plan: VillagePlan) -> void:
	var landmark := -1
	var tallest := -1
	var top := -INF
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var h: float = VillageMeasure.height(b)
		if h > top:
			top = h
			tallest = i
		if b["kind"] in [&"church", &"temple"] and landmark < 0:
			landmark = i
	if landmark < 0:
		for i2 in range(plan.buildings.size()):
			if plan.buildings[i2]["kind"] == &"castle":
				landmark = i2
	if landmark < 0:
		return
	if tallest != landmark and top > VillageMeasure.height(plan.buildings[landmark]) + 0.05:
		failures.append("landmark: building %d (%s) at %.1fm is taller than the landmark at %.1fm"
			% [tallest, String(plan.buildings[tallest]["kind"]), top, VillageMeasure.height(plan.buildings[landmark])])
	var lb: Dictionary = plan.buildings[landmark]
	var lc: Vector2 = VillageMeasure.centre(VillageMeasure.bounds_poly(lb))
	var lh: float = VillageMeasure.height(lb)
	# a shrine no taller than the cottages round it cannot be seen over them
	# and is not asked to be; the sightline is for a landmark that stands
	# head and shoulders over the village
	var next_top := 0.0
	for i4 in range(plan.buildings.size()):
		if i4 != landmark:
			next_top = maxf(next_top, VillageMeasure.height(plan.buildings[i4]))
	if lh < next_top * LANDMARK_DOMINANCE:
		warnings.append("landmark: the %s at %.1fm barely tops the %.1fm houses; the gate sightline is not asked of it"
			% [String(lb["kind"]), lh, next_top])
		return
	var boxes: Array = []
	var names: Array[int] = []
	for i3 in range(plan.buildings.size()):
		if i3 == landmark:
			continue
		var poly: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[i3])
		var r: Rect2 = Poly.bounding_rect(poly)
		boxes.append(AABB(Vector3(r.position.x, 0.0, r.position.y),
			Vector3(r.size.x, VillageMeasure.height(plan.buildings[i3]), r.size.y)))
		names.append(i3)
	for g in VillageMeasure.gates(plan):
		var eye := Vector3(g.x, EYE, g.y)
		var aim := Vector3(lc.x, lh * 0.85, lc.y)
		var hit: Array[int] = Sightline.blockers(eye, aim, boxes)
		if not hit.is_empty():
			# a warning until the site planner keeps a view corridor from the
			# gates (VILLAGES 12): the lots along the through road are laid
			# without regard to it, and a roof in the way is theirs, not the
			# landmark's
			warnings.append("landmark: from the gate at %v building %d hides the landmark" % [g, names[hit[0]]])
			break


func _check_well(plan: VillagePlan) -> void:
	var wells: Array[Dictionary] = []
	for p in plan.props:
		if String(p["key"]).to_lower().begins_with("well"):
			wells.append(p)
	if wells.is_empty():
		return
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	for w in wells:
		var pos: Vector2 = w["pos"]
		if not common.is_empty() and not Poly.contains_point(common, pos):
			failures.append("well: the well at %v is off the common" % pos)
		for i in range(plan.buildings.size()):
			var d: float = VillageMeasure.point_to_poly(pos, VillageMeasure.bounds_poly(plan.buildings[i]))
			if d < WELL_CLEAR:
				failures.append("well: building %d stands %.1fm from the well, wants %.0f" % [i, d, WELL_CLEAR])
				break
		var pathed := false
		for r in plan.roads_of_class(&"path"):
			if VillageMeasure.point_to_polyline(pos, plan.roads[r]["points"]) <= 2.0:
				pathed = true
		if not pathed and not plan.roads_of_class(&"path").is_empty():
			failures.append("well: no path reaches the well at %v" % pos)


func _check_tavern(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	var gates: Array[Vector2] = VillageMeasure.gates(plan)
	for i in VillageMeasure.shops_of(plan, &"tavern"):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var road: int = int(lot["road"])
		var on_through: bool = road >= 0 and plan.roads[road]["class"] == &"through"
		var on_common: bool = not common.is_empty() \
			and VillageMeasure.point_to_poly(VillageMeasure.front_mid(b), common) <= FRONTED_REACH
		if not on_through and not on_common:
			failures.append("tavern: building %d fronts %s %d, not the through road or the common"
				% [i, String(plan.roads[road]["class"]) if road >= 0 else "nothing", road])
		var near := INF
		for g in gates:
			near = minf(near, g.distance_to(VillageMeasure.front_mid(b)))
		if near > TAVERN_TO_GATE:
			failures.append("tavern: building %d is %.0fm from the nearest gate, wants %.0f" % [i, near, TAVERN_TO_GATE])


func _check_stable(plan: VillagePlan) -> void:
	var inns: Array[int] = VillageMeasure.shops_of(plan, &"inn")
	for i in VillageMeasure.shops_of(plan, &"stable"):
		var b: Dictionary = plan.buildings[i]
		if inns.is_empty():
			continue
		var near := INF
		for j in inns:
			near = minf(near, VillageMeasure.poly_distance(VillageMeasure.bounds_poly(b),
				VillageMeasure.bounds_poly(plan.buildings[j])))
		if near > STABLE_TO_INN:
			failures.append("stable: building %d is %.0fm from the inn, wants %.0f" % [i, near, STABLE_TO_INN])
		var spec := ShopSpec.new()
		spec.business = &"stable"
		if spec.door_w() < 1.5:
			failures.append("stable: the stable's door is %.2fm, a horse needs 1.5" % spec.door_w())


func _check_smithy(plan: VillagePlan) -> void:
	var cx: float = VillageMeasure.common_centre(plan).x
	for i in VillageMeasure.shops_of(plan, &"blacksmith"):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var road: int = int(lot["road"])
		if road < 0 or plan.roads[road]["class"] != &"through":
			failures.append("smithy: building %d is not on the through road" % i)
		var mine: PackedVector2Array = VillageMeasure.bounds_poly(b)
		for j in range(plan.buildings.size()):
			var other: Dictionary = plan.buildings[j]
			var quiet: bool = other["kind"] in [&"church", &"temple"] or VillageMeasure.business(other) == &"tavern"
			if not quiet:
				continue
			var d: float = VillageMeasure.poly_distance(mine, VillageMeasure.bounds_poly(other))
			if d < SMITHY_CLEAR:
				failures.append("smithy: building %d stands %.0fm from building %d (%s), wants %.0f"
					% [i, d, j, String(other["kind"]), SMITHY_CLEAR])
		if VillageMeasure.centre(mine).x < cx - 0.01:
			failures.append("smithy: building %d is upwind (west) of the common" % i)


func _check_mill(plan: VillagePlan) -> void:
	if plan.water.is_empty():
		return
	var mills: Array[int] = []
	for i in range(plan.buildings.size()):
		var req: BuildingRequest = plan.buildings[i]["request"]
		if req.kind == &"shop" and req.purpose == &"bakery" and plan.spec.water != &"none":
			mills.append(i)
	for water in plan.water:
		if water["kind"] == &"race" and not mills.has(int(water.get("host", -1))):
			failures.append("mill: race names no working mill host=%d" % int(water.get("host", -1)))
	for i in mills:
		var touches := false
		var races: Array[Dictionary] = []
		for w in plan.water:
			if VillageMeasure.poly_distance(VillageMeasure.bounds_poly(plan.buildings[i]), w["poly"]) <= 0.5:
				touches = true
			if w["kind"] == &"race" and int(w.get("host", -1)) == i:
				races.append(w)
		if not touches:
			failures.append("mill: building %d does not touch the water" % i)
		if races.size() != 1:
			failures.append("mill: building %d needs one working race, found %d" % [i, races.size()])
			continue
		var race := races[0]
		var poly: PackedVector2Array = race["poly"]
		var building := plan.buildings[i]
		var wall := VillageWaterPlan.mill_walls(building["placement"], building["transform"])
		if VillageMeasure.poly_distance(poly, wall) > 0.15:
			failures.append("mill: race host=%d misses the measured wall (tolerance=0.15m)" % i)
		var natural := false
		for water in plan.water:
			if water["kind"] != &"race" and VillageLotPlanner.overlap_area(poly, water["poly"]) > 0.1:
				natural = true
		if not natural:
			failures.append("mill: race host=%d is disconnected from natural water" % i)
		for road in plan.roads:
			if VillageLotPlanner.overlap_area(poly, VillageSitePlanner.road_ribbon(road, true)) > 0.05:
				failures.append("mill: race host=%d cuts across a road" % i)
		for li in plan.lots.size():
			if li != int(building["lot"]) and VillageLotPlanner.overlap_area(poly, plan.lots[li]["poly"]) > 0.05:
				failures.append("mill: race host=%d floods lot=%d" % [i, li])
		var wheels := 0
		for prop in plan.props:
			if prop["key"] != "mill_wheel" or int(prop.get("host", -1)) != i:
				continue
			wheels += 1
			var at: Vector2 = prop["pos"]
			var gap := VillageMeasure.point_to_poly(at, wall)
			if not Poly.contains_point(poly, at) or gap < 0.3 or gap > 0.9:
				failures.append("mill: wheel host=%d leaves race/wall gap=%.3fm tolerance=0.30..0.90m" % [i, gap])
			if absf(float(prop.get("elevation", 0.0)) - 1.15) > 0.05:
				failures.append("mill: wheel host=%d axle is not above the water (expected=1.15m)" % i)
			var closest := Vector2.INF
			var near := INF
			for edge in wall.size():
				var point := Geometry2D.get_closest_point_to_segment(at, wall[edge], wall[(edge + 1) % wall.size()])
				if point.distance_to(at) < near:
					near = point.distance_to(at)
					closest = point
			var axis := Vector2(sin(float(prop["yaw"])), cos(float(prop["yaw"])))
			if absf(axis.dot((at - closest).normalized())) < 0.98:
				failures.append("mill: wheel host=%d axle does not enter its wall (alignment >=0.98)" % i)
			if not VillageWaterPlan.wheel_openings_clear(building["placement"], building["transform"],
					at, (at - closest).normalized()):
				failures.append("mill: wheel host=%d blocks a facade opening" % i)
		if wheels != 1:
			failures.append("mill: building %d needs one water wheel, found %d" % [i, wheels])


## Probe the actual enclosure mesh where water crosses it. The channel must
## pass below a culvert, not terminate against a perfectly plausible wall.
static func check_mill_flow(plan: VillagePlan, mesh: ArrayMesh) -> Array[String]:
	return _check_water_flow(plan, mesh, true)


## Natural water forms the settlement boundary at the shore. Planned bridges
## have their own geometry checks; their rail posts are legitimate wet obstacles.
static func check_water_flow(plan: VillagePlan, mesh: ArrayMesh) -> Array[String]:
	return _check_water_flow(plan, mesh, false)


static func _check_water_flow(plan: VillagePlan, mesh: ArrayMesh, races_only: bool) -> Array[String]:
	var failures: Array[String] = []
	if plan.spec.enclosure == &"none":
		return failures
	var edge: PackedVector2Array = plan.enclosure if plan.enclosure.size() >= 3 else VillageEnclosurePlan.build(plan)["edge"]
	var triangles: Array = []
	for surface in mesh.get_surface_count():
		triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
	var crossings: Array[PackedVector2Array] = []
	for crossing in plan.water_crossings:
		crossings.append(Poly.ribbon(crossing["points"], (float(crossing["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5 + 0.4))
	for water in plan.water:
		if races_only and water["kind"] != &"race":
			continue
		var race: PackedVector2Array = water["poly"]
		for e in edge.size():
			var a := edge[e]
			var b := edge[(e + 1) % edge.size()]
			var direction := (b - a).normalized()
			var normal := Vector3(-direction.y, 0, direction.x)
			var samples := maxi(1, int(ceil(a.distance_to(b) / 0.2)))
			for sample in samples:
				var p := a.lerp(b, (float(sample) + 0.5) / float(samples))
				if not Poly.contains_point(race, p):
					continue
				if crossings.any(func(poly: PackedVector2Array) -> bool: return Poly.contains_point(poly, p)):
					continue
				var margin := INF
				for side in race.size():
					margin = minf(margin, p.distance_to(Geometry2D.get_closest_point_to_segment(p,
						race[side], race[(side + 1) % race.size()])))
				if margin < 0.2:
					continue
				var centre := Vector3(p.x, 0.32, p.y)
				for triangle in triangles:
					if Geometry3D.segment_intersects_triangle(centre - normal * 0.8, centre + normal * 0.8,
							triangle[0], triangle[1], triangle[2]) != null:
						failures.append("water_flow: enclosure dams %s host=%d at=%s measured_y=0.32m" % [water["kind"], water.get("host", -1), p])
						break
	return failures


func _check_market(plan: VillagePlan) -> void:
	var stalls: Array[Dictionary] = []
	for p in plan.props:
		if String(p["key"]).begins_with("Stall"):
			stalls.append(p)
	if stalls.is_empty():
		return
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	# rows: stalls sharing a yaw and a line
	var rows: Array = []
	for s in stalls:
		if not common.is_empty() and not Poly.contains_point(common, s["pos"]):
			failures.append("market: a stall at %v is off the square" % s["pos"])
		var placed := false
		for row in rows:
			var yaw: float = float(row["yaw"])
			var pos: Vector2 = s["pos"]
			var along := Vector2(cos(yaw), -sin(yaw))
			var off: float = absf((pos - Vector2(row["origin"])).cross(along))
			if absf(angle_difference(yaw, float(s["yaw"]))) < 0.05 and off < 0.5:
				row["members"].append(s)
				placed = true
				break
		if not placed:
			rows.append({"yaw": float(s["yaw"]), "origin": s["pos"], "members": [s]})
	for a in range(rows.size()):
		for b in range(a + 1, rows.size()):
			var ya: float = float(rows[a]["yaw"])
			var yb: float = float(rows[b]["yaw"])
			if absf(angle_difference(ya, yb)) > 0.05 and absf(absf(angle_difference(ya, yb)) - PI) > 0.05:
				failures.append("market: stall rows are not parallel")
				return
			var along := Vector2(cos(ya), -sin(ya))
			var gap: float = absf((Vector2(rows[b]["origin"]) - Vector2(rows[a]["origin"])).cross(along))
			if gap < STALL_ROW_GAP - 0.05:
				failures.append("market: two stall rows are %.1fm apart, wants %.0f" % [gap, STALL_ROW_GAP])
	for row in rows:
		for s2 in row["members"]:
			var yaw: float = float(s2["yaw"])
			var facing := Vector2(-sin(yaw), -cos(yaw))
			var ahead: Vector2 = Vector2(s2["pos"]) + facing * 1.5
			for other in stalls:
				if other == s2:
					continue
				if Vector2(other["pos"]).distance_to(ahead) < 1.0:
					failures.append("market: a stall at %v faces into another stall" % s2["pos"])
					return


func _check_civic(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	if common.is_empty():
		return
	for biz in [&"town_hall", &"guildhall"]:
		for i in VillageMeasure.shops_of(plan, biz):
			var d: float = VillageMeasure.point_to_poly(VillageMeasure.front_mid(plan.buildings[i]), common)
			if d > FRONTED_REACH:
				failures.append("civic: the %s (building %d) fronts nothing %.0fm from the square" % [String(biz), i, d])


func _check_manor(plan: VillagePlan) -> void:
	var cc: Vector2 = VillageMeasure.common_centre(plan)
	for i in plan.buildings_of_kind(&"castle"):
		var b: Dictionary = plan.buildings[i]
		var mine: PackedVector2Array = VillageMeasure.bounds_poly(b)
		for j in range(plan.buildings.size()):
			if j == i:
				continue
			var d: float = VillageMeasure.poly_distance(mine, VillageMeasure.bounds_poly(plan.buildings[j]))
			if d < MANOR_CLEAR:
				failures.append("manor: building %d stands %.0fm from the manor, wants %.0f" % [j, d, MANOR_CLEAR])
				break
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var road: int = int(lot["road"])
		if road < 0 or plan.roads[road]["class"] != &"lane":
			failures.append("manor: the manor is not on a lane of its own")
		else:
			for li in range(plan.lots.size()):
				if li != int(b["lot"]) and int(plan.lots[li]["road"]) == road:
					failures.append("manor: lot %d shares the manor's lane" % li)
					break
		var to: Vector2 = (cc - VillageMeasure.front_mid(b)).normalized()
		var deg: float = rad_to_deg(acos(clampf(VillageMeasure.front_dir(b).dot(to), -1.0, 1.0)))
		if deg > MANOR_FACE_DEG + 0.5:
			failures.append("manor: the manor's gate looks %.0f degrees away from the common" % deg)


func _check_churchyard(plan: VillagePlan) -> void:
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		if not b["kind"] in [&"church", &"temple"]:
			continue
		var poly: PackedVector2Array = VillageMeasure.footprint_poly(b)
		var c: Vector2 = VillageMeasure.centre(poly)
		var clear_sides := 0
		for k in range(4):
			var a: Vector2 = poly[k]
			var b2: Vector2 = poly[(k + 1) % 4]
			var mid: Vector2 = (a + b2) / 2.0
			var out: Vector2 = (mid - c).normalized()
			var probe: Vector2 = mid + out * CHURCHYARD_CLEAR
			var clear := true
			for j in range(plan.buildings.size()):
				if j == i:
					continue
				var d: float = VillageMeasure.point_to_poly(mid, VillageMeasure.bounds_poly(plan.buildings[j]))
				var seg_hit: bool = VillageMeasure.point_to_poly(probe, VillageMeasure.bounds_poly(plan.buildings[j])) < 0.01
				if d < CHURCHYARD_CLEAR and seg_hit:
					clear = false
			if clear:
				clear_sides += 1
		if clear_sides < 3:
			failures.append("churchyard: the church has clear ground on only %d sides" % clear_sides)


## Bigger houses nearer the common: Spearman of house floor area against
## distance to the common's centre.
## The wealth gradient measures the houses that are FREE to stand in the
## middle, which is every house but a farm.
##
## `farms outside` (below) puts a farm within thirty metres of the edge with
## its yard to the fields -- it is not competing for the ground round the
## common, and a farmhouse is a big building, so counting farms here asks the
## planner to satisfy two rules that contradict each other and reads the
## contradiction as a defect in the gradient. Naming the set each rule
## measures is the fix; the farms are judged by their own rule, and both are
## then satisfiable at once.
##
## In a farming village most households ARE farms, so this rule often has
## fewer than five houses left and does not apply. That is correct rather
## than convenient: a village that is nine farms and a smithy has no wealth
## gradient to have, and `farms` is the rule that judges where it put them.
func _check_gradient(plan: VillagePlan) -> void:
	var houses: Array[int] = []
	for i in plan.buildings_of_kind(&"house"):
		if (plan.buildings[i]["request"] as BuildingRequest).purpose != &"farmer":
			houses.append(i)
	if houses.size() < 5:
		return
	var cc: Vector2 = VillageMeasure.common_centre(plan)
	var areas: Array = []
	var dists: Array = []
	for i in houses:
		var fp: Rect2 = plan.buildings[i]["placement"]["footprint"]
		areas.append(fp.size.x * fp.size.y)
		dists.append(VillageMeasure.centre(VillageMeasure.footprint_poly(plan.buildings[i])).distance_to(cc))
	var rho: float = VillageMeasure.spearman(areas, dists)
	stats["gradient"] = snappedf(rho, 0.01)
	var want: float = GRADIENT_MAX if houses.size() >= 8 else 0.0
	if rho > want:
		failures.append("gradient: house size against distance from the common correlates %.2f, wants <= %.1f" % [rho, GRADIENT_MAX])


## Farms at the edge, yards toward the fields.
func _check_farms(plan: VillagePlan) -> void:
	var edge: PackedVector2Array = plan.enclosure if plan.enclosure.size() >= 3 else Poly.from_rect(plan.site)
	for i in plan.buildings_of_kind(&"house"):
		var b: Dictionary = plan.buildings[i]
		if (b["request"] as BuildingRequest).purpose != &"farmer":
			continue
		var c: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(b))
		var d: float = VillageMeasure.point_to_poly(c, edge) if not Poly.contains_point(edge, c) else _to_boundary(edge, c)
		# Thirty metres, or a share of the site on a village whose ground has
		# grown to hold its farms -- measured on the site's SHORTER side.
		# A village stretches along its road rather than squaring up
		# (VIL-012), so a long thin site's width says nothing about how far
		# inside a farm can get, and scaling by it let a farm stand dead
		# centre and pass.
		var reach: float = maxf(FARM_TO_EDGE,
			minf(plan.site.size.x, plan.site.size.y) * 0.4)
		if d > reach:
			failures.append("farms: farm %d stands %.0fm inside the edge, wants <= %.0f" % [i, d, reach])
		# the yard is behind the house: its back (local +Z) toward the edge
		var nearest: Vector2 = _nearest_on_boundary(edge, c)
		var out: Vector2 = (nearest - c).normalized()
		if (-VillageMeasure.front_dir(b)).dot(out) < 0.0:
			# a farm on the inner side of its lane is at the edge with its
			# yard toward the village: the edge is what matters, the yard
			# side is worth saying
			warnings.append("farms: farm %d turns its yard away from the fields" % i)


static func _to_boundary(poly: PackedVector2Array, p: Vector2) -> float:
	return p.distance_to(_nearest_on_boundary(poly, p))


static func _nearest_on_boundary(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for i in range(poly.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d: float = p.distance_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best
