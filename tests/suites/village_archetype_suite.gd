class_name VillageArchetypeSuite
extends RefCounted
## VIL-020: the twelve documented village archetypes. Every row is exercised
## at three deterministic seeds and 70/100/140 percent of its population.

const SCALES: Array[float] = [0.7, 1.0, 1.4]

const ARCHETYPES: Array[Dictionary] = [
	{"key": &"thorpe", "people": 18, "culture": &"english", "purpose": &"farming", "water": &"none", "edge": &"hedge", "must": [&"houses4", &"well", &"fields", &"no_shop"]},
	{"key": &"green_village", "people": 80, "culture": &"english", "purpose": &"farming", "water": &"pond", "edge": &"hedge", "must": [&"green", &"church", &"smithy", &"tavern", &"farm", &"orchard"]},
	{"key": &"ford", "people": 60, "culture": &"frankish", "purpose": &"crossroads", "water": &"stream", "edge": &"none", "must": [&"bridge", &"tavern", &"smithy"]},
	{"key": &"mill_village", "people": 120, "culture": &"frankish", "purpose": &"mill", "water": &"river", "edge": &"hedge", "must": [&"mill", &"race", &"bakery", &"inn_stable", &"store"]},
	{"key": &"strand", "people": 45, "culture": &"norse", "purpose": &"fishing", "water": &"coast", "edge": &"none", "must": [&"row", &"road", &"racks_boats"]},
	{"key": &"pine_hold", "people": 70, "culture": &"alpine", "purpose": &"forest", "water": &"stream", "edge": &"palisade", "must": [&"palisade2", &"carpenter", &"double_trees"]},
	{"key": &"mine_camp", "people": 70, "culture": &"norse", "purpose": &"mining", "water": &"none", "edge": &"palisade", "must": [&"adit", &"smithy", &"no_farms"]},
	{"key": &"pilgrims_rest", "people": 80, "culture": &"eastern", "purpose": &"pilgrim", "water": &"none", "edge": &"none", "must": [&"temple", &"inn", &"market"]},
	{"key": &"lords_village", "people": 150, "culture": &"english", "purpose": &"garrison", "water": &"none", "edge": &"wall", "must": [&"manor", &"church", &"wall_gates"]},
	{"key": &"market_town", "people": 300, "culture": &"frankish", "purpose": &"market", "water": &"river", "edge": &"wall", "must": [&"square8", &"town_hall", &"guildhall", &"two_taverns", &"bridge", &"wall"]},
	{"key": &"blight", "people": 40, "culture": &"blighted", "purpose": &"forest", "water": &"pond", "edge": &"none", "must": [&"temple", &"dead_trees", &"mushrooms", &"ruin", &"no_green"]},
	{"key": &"cap", "people": 500, "culture": &"frankish", "purpose": &"market", "water": &"river", "edge": &"wall", "must": [&"top_envelope", &"buildings140"]},
]

## Only blockers with an active implementation gap are excused. A passing row
## is reported so it can be removed from this map immediately.
const EXPECTED_FAIL: Dictionary = {
	&"green_village": "VIL-018 pond generation before lots",
	&"ford": "VIL-018 stream/ford generation before lots",
	&"mill_village": "VIL-018 river/mill race generation",
	&"pine_hold": "VIL-018 stream generation and palisade gates",
	&"market_town": "VIL-017 market form/road layout and VIL-018 river crossing integration",
	&"blight": "VIL-020 ruin/mushroom programme rows",
	&"cap": "VIL-017 top-envelope form/road layout and VIL-018 river integration",
}


static func run() -> SuiteResult:
	return _run_selected(_requested_row())


## Bounded VIL-020 entry point used by run_all's named row lanes.  Keeping
## this selector in the suite means a single Thorpe/Strand/Lord row still uses
## the exact canonical 3-seed x 3-scale matrix and XFAIL accounting.
static func run_row(key: StringName) -> SuiteResult:
	return _run_selected(key)


static func _run_selected(requested: StringName) -> SuiteResult:
	var res := SuiteResult.new("village archetype")
	for row in ARCHETYPES:
		if requested != &"" and row["key"] != requested:
			continue
		var row_failures := 0
		var xfails := 0
		for seed_index in range(3):
			for scale in SCALES:
				var people: int = maxi(12, int(round(float(row["people"]) * scale)))
				var spec := VillageSpec.new(_seed_for(row["key"], seed_index, scale))
				spec.population = people
				spec.culture = row["culture"]
				spec.purpose = row["purpose"]
				spec.water = row["water"]
				spec.enclosure = row["edge"]
				spec.wealth = 0.6
				spec.generate(spec.seed)
				print("VIL020 START ", String(row["key"]), " seed=", seed_index, " scale=", scale)
				var plan := VillageLotPlanner.plan(spec)
				res.checked += 1
				var who := "%s seed=%d scale=%.1f" % [String(row["key"]), seed_index, scale]
				var before := res.failures.size()
				var qa: Dictionary = VillageQA.new().check(plan, {}, false)
				for failure in qa["failures"]:
					if _expected_failure(row, String(failure)):
						xfails += 1
					else:
						var message := "%s: QA: %s" % [who, String(failure)]
						res.fail(message)
						print("VIL020 FAIL ", message)
				for failure2 in _must_failures(row, plan, scale):
					if _expected_failure(row, failure2):
						xfails += 1
					else:
						var message2 := "%s: %s" % [who, failure2]
						res.fail(message2)
						print("VIL020 FAIL ", message2)
				if res.failures.size() > before:
					row_failures += 1
				print("VIL020 DONE ", who, " defects=", res.failures.size() - before,
					" xfails=", xfails)
		if EXPECTED_FAIL.has(row["key"]):
			res.note("  %s: %d cases, %d defects, %d XFAIL; expected blocker: %s" %
				[String(row["key"]), 9, row_failures, xfails, String(EXPECTED_FAIL[row["key"]])])
			if xfails == 0:
				res.warn("  %s: XPASS -- remove from EXPECTED_FAIL after review" % String(row["key"]))
		else:
			res.note("  %s: %d cases, %d defects" % [String(row["key"]), 9, row_failures])
	return res


static func _requested_row() -> StringName:
	for arg in OS.get_cmdline_args():
		var text := String(arg)
		if text.begins_with("--row="):
			return StringName(text.substr(6))
	return &""


static func _expected_failure(row: Dictionary, failure: String) -> bool:
	if not EXPECTED_FAIL.has(row["key"]):
		return false
	var patterns: Dictionary = {
		&"green_village": ["pond", "orchard"], &"ford": ["stream", "ford", "bridge"],
		&"mill_village": ["river", "race", "mill"], &"pine_hold": ["stream", "palisade", "gate"],
		&"market_town": ["river", "bridge", "road", "lot", "place", "form"], &"blight": ["ruin", "mushroom", "dead tree", "green tree"],
		&"cap": ["river", "bridge", "road", "lot", "place", "form", "density"]}
	for pattern in patterns.get(row["key"], []):
		if failure.to_lower().contains(pattern):
			return true
	return false


static func _must_failures(row: Dictionary, plan: VillagePlan, scale: float) -> Array[String]:
	var out: Array[String] = []
	var must: Array = row["must"]
	var houses := 0
	var shops := 0
	var church := false
	var smithy := false
	var tavern := 0
	var farmer := false
	var temple := false
	var carpenter := false
	var manor := false
	var adit := false
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		if req.kind == &"house":
			houses += 1
			farmer = farmer or req.purpose == &"farmer"
		elif req.kind == &"shop":
			shops += 1
			smithy = smithy or req.purpose == &"blacksmith"
			carpenter = carpenter or req.purpose == &"carpenter"
			tavern += 1 if req.purpose in [&"tavern", &"inn"] else 0
		elif req.kind == &"church":
			church = true
		elif req.kind == &"temple":
			temple = true
		elif req.kind == &"castle":
			manor = true
	for p in plan.props:
		adit = adit or String(p["key"]).to_lower().contains("adit")
	for need in must:
		match need:
			&"houses4":
				var wanted: int = 3 if scale < 1.0 else 4
				if houses < wanted: out.append("needs %d houses at %.1f scale, got %d" % [wanted, scale, houses])
			&"no_shop":
				if shops > 0: out.append("must contain no shop")
			&"well":
				if not _has_prop(plan, "well"): out.append("needs a well")
			&"fields":
				if plan.fields.is_empty(): out.append("needs fields")
			&"green":
				if plan.commons.is_empty(): out.append("needs a green")
			&"church":
				if not church: out.append("needs a church")
			&"smithy":
				if not smithy: out.append("needs a smithy")
			&"tavern":
				if tavern < 1: out.append("needs a tavern")
				elif row["key"] == &"ford" and not _ford_tavern_ok(plan): out.append("needs tavern on through road within 60m of bridge")
			&"farm":
				if not farmer: out.append("needs a farm")
			&"orchard":
				if not _has_plan_or_prop(plan, "orchard"): out.append("needs an orchard")
			&"temple":
				if not temple: out.append("needs a temple")
				elif row["key"] == &"pilgrims_rest" and not _temple_on_common(plan): out.append("needs temple on common")
			&"carpenter":
				if not carpenter: out.append("needs a carpenter")
			&"manor":
				if not manor: out.append("needs a manor-tier castle")
				elif row["key"] == &"lords_village" and not _manor_at_lane_head(plan): out.append("needs manor-tier castle at lane head")
			&"bridge":
				if _crossing_count(plan) == 0: out.append("needs a bridge crossing")
			&"race":
				if not _has_prop(plan, "race"): out.append("needs a mill race")
			&"bakery":
				if not _has_purpose(plan, &"bakery"): out.append("needs a bakery")
			&"mill":
				if not _mill_on_water(plan): out.append("needs a mill on water")
			&"inn_stable":
				if not (_has_purpose(plan, &"inn") and _has_purpose(plan, &"stable")): out.append("needs inn and stable")
			&"store":
				if not _has_purpose(plan, &"general_store"): out.append("needs a store")
			&"inn":
				if not _has_purpose(plan, &"inn"): out.append("needs an inn")
			&"market":
				if _count_props(plan, "stall") < 1: out.append("needs a market")
			&"row":
				if not _strand_row(plan): out.append("needs one row of houses")
			&"road":
				if not _strand_row(plan): out.append("needs a road behind the row")
			&"racks_boats":
				if not _strand_props_front(plan): out.append("needs racks and boats in front")
			&"palisade2":
				if not _emitted_edge(plan, "palisade") or _derived_gate_count(plan) < 2: out.append("needs a palisade with two gates")
			&"double_trees":
				if _tree_count(plan) < maxi(2, plan.buildings.size() * 2): out.append("needs double-density trees")
			&"adit":
				if not adit or not _adit_at_through_end(plan): out.append("needs an adit at through-road end")
			&"wall_gates":
				if not _emitted_edge(plan, "wall") or _derived_gate_count(plan) == 0: out.append("needs wall gates")
			&"square8":
				if not _has_common_kind(plan, &"square") or _count_props(plan, "stall") < 8: out.append("needs square with 8 stalls")
			&"town_hall":
				if not _has_purpose(plan, &"town_hall"): out.append("needs a town hall")
			&"guildhall":
				if not _has_purpose(plan, &"guildhall"): out.append("needs a guildhall")
			&"two_taverns":
				if tavern < 2: out.append("needs two taverns")
			&"wall":
				if not _emitted_edge(plan, "wall"): out.append("needs a wall")
			&"dead_trees":
				if not _has_prop(plan, "dead"): out.append("needs dead trees")
			&"mushrooms":
				if not _has_prop(plan, "mushroom"): out.append("needs mushrooms")
			&"ruin":
				if not _has_prop(plan, "wall_broken"): out.append("needs a ruin")
			&"no_green":
				if _has_tree(plan, "common") or _has_prop(plan, "common tree"): out.append("must contain no green tree")
			&"top_envelope":
				if plan.buildings.is_empty() or plan.spec.population > 500 \
					or plan.site.size.x > 400.0 or plan.site.size.y > 400.0:
					out.append("top envelope is outside population/site bounds")
			&"buildings140":
				if plan.buildings.is_empty() or plan.buildings.size() > 140: out.append("buildings exceed 140 or none were housed")
			&"no_farms":
				if farmer: out.append("must contain no farms")
			_:
				out.append("unknown must token %s" % String(need))
	return out


static func _has_purpose(plan: VillagePlan, purpose: StringName) -> bool:
	for b in plan.buildings:
		if (b["request"] as BuildingRequest).purpose == purpose: return true
	return false


static func _has_plan_or_prop(plan: VillagePlan, needle: String) -> bool:
	for b in plan.buildings:
		if String((b["request"] as BuildingRequest).purpose).to_lower().contains(needle): return true
	return _has_prop(plan, needle)


static func _count_props(plan: VillagePlan, needle: String) -> int:
	var count := 0
	for p in plan.props:
		if String(p["key"]).to_lower().contains(needle): count += 1
	return count


static func _derived_gate_count(plan: VillagePlan) -> int:
	return (VillageEnclosurePlan.build(plan)["gates"] as Array).size()


static func _emitted_edge(plan: VillagePlan, kind: String) -> bool:
	if plan.spec.enclosure != StringName(kind):
		return false
	var builder := VillageBuilder.new()
	builder.build(plan)
	for mass in builder.mass_log:
		var name: String = String(mass.get("name", ""))
		if kind == "wall" and name.begins_with("wall"):
			return true
		if kind == "palisade" and name.begins_with("palisade"):
			return true
		if kind == "hedge" and name.begins_with("hedge"):
			return true
	return false


static func _strand_row(plan: VillagePlan) -> bool:
	if plan.roads.is_empty() or plan.water.is_empty():
		return false
	var road_index := -1
	var row_count := 0
	for building in plan.buildings:
		var lot_index: int = int(building["lot"])
		if lot_index < 0 or lot_index >= plan.lots.size():
			continue
		var lot_road: int = int(plan.lots[lot_index].get("road", -1))
		if lot_road < 0:
			continue
		if road_index < 0:
			road_index = lot_road
		if lot_road == road_index:
			row_count += 1
	if row_count < 2:
		return false
	# A strand row must have coast on the far side of its frontage road, not
	# merely any water somewhere on the plan.
	var coast: PackedVector2Array = plan.water[0]["poly"]
	var road_points: PackedVector2Array = plan.roads[road_index]["points"]
	for point in road_points:
		if VillageMeasure.point_to_poly(point, coast) < 2.0:
			return false
	return true


static func _has_common_kind(plan: VillagePlan, kind: StringName) -> bool:
	for common in plan.commons:
		if common.get("kind", &"") == kind: return true
	return false


static func _tree_count(plan: VillagePlan) -> int:
	var count := 0
	for tree in plan.plants:
		if float(tree.get("canopy", 0.0)) >= 1.0: count += 1
	return count


static func _has_tree(plan: VillagePlan, needle: String) -> bool:
	for tree in plan.plants:
		if String(tree["key"]).to_lower().contains(needle): return true
	return false


static func _crossing_count(plan: VillagePlan) -> int:
	var count := 0
	for road in plan.roads:
		var points: PackedVector2Array = road["points"]
		for i in range(points.size() - 1):
			for water in plan.water:
				var poly: PackedVector2Array = water["poly"]
				var hits := 0
				for e in range(poly.size()):
					if Geometry2D.segment_intersects_segment(points[i], points[i + 1], poly[e], poly[(e + 1) % poly.size()]) != null:
						hits += 1
				if hits >= 2: count += 1
	return count


static func _ford_tavern_ok(plan: VillagePlan) -> bool:
	var bridge_points: Array[Vector2] = []
	for point in _crossing_points(plan): bridge_points.append(point)
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		if req.purpose not in [&"tavern", &"inn"]: continue
		var at := Vector2((b["transform"] as Transform3D).origin.x, (b["transform"] as Transform3D).origin.z)
		for road in plan.roads:
			if road["class"] != &"through": continue
			if _point_to_polyline(at, road["points"]) <= 8.0:
				for bridge in bridge_points:
					if at.distance_to(bridge) <= 60.0: return true
	return false


static func _crossing_points(plan: VillagePlan) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for road in plan.roads:
		var points: PackedVector2Array = road["points"]
		for i in range(points.size() - 1):
			for water in plan.water:
				var hits: Array[Vector2] = []
				var poly: PackedVector2Array = water["poly"]
				for e in range(poly.size()):
					var hit: Variant = Geometry2D.segment_intersects_segment(points[i], points[i + 1], poly[e], poly[(e + 1) % poly.size()])
					if hit != null: hits.append(Vector2(hit))
				if hits.size() >= 2: out.append((hits[0] + hits[1]) * 0.5)
	return out


static func _point_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for i in range(points.size() - 1):
		var edge := points[i + 1] - points[i]
		var t := clampf((point - points[i]).dot(edge) / maxf(edge.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, point.distance_to(points[i] + edge * t))
	return best


static func _mill_on_water(plan: VillagePlan) -> bool:
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		if req.purpose != &"mill": continue
		var at := Vector2((b["transform"] as Transform3D).origin.x, (b["transform"] as Transform3D).origin.z)
		for water in plan.water:
			if Poly.contains_point(water["poly"], at): return true
	return _has_prop(plan, "mill") and _has_prop(plan, "race") and not plan.water.is_empty()


static func _strand_props_front(plan: VillagePlan) -> bool:
	var rack := false
	var boat := false
	for p in plan.props:
		var key := String(p["key"]).to_lower()
		var near_coast := false
		for water in plan.water:
			near_coast = near_coast or VillageMeasure.point_to_poly(p["pos"], water["poly"]) <= 18.0
		if near_coast and key.contains("rack"): rack = true
		if near_coast and key.contains("boat"): boat = true
	return rack and boat


static func _adit_at_through_end(plan: VillagePlan) -> bool:
	for road in plan.roads:
		if road["class"] != &"through": continue
		var points: PackedVector2Array = road["points"]
		for p in plan.props:
			if String(p["key"]).to_lower().contains("adit") and Vector2(p["pos"]).distance_to(points[points.size() - 1]) <= 18.0: return true
	return false


static func _temple_on_common(plan: VillagePlan) -> bool:
	for b in plan.buildings:
		if (b["request"] as BuildingRequest).kind != &"temple": continue
		var at := Vector2((b["transform"] as Transform3D).origin.x, (b["transform"] as Transform3D).origin.z)
		for common in plan.commons:
			if Poly.contains_point(common["poly"], at): return true
	return false


static func _manor_at_lane_head(plan: VillagePlan) -> bool:
	for b in plan.buildings:
		if (b["request"] as BuildingRequest).kind != &"castle": continue
		var at := Vector2((b["transform"] as Transform3D).origin.x, (b["transform"] as Transform3D).origin.z)
		for road in plan.roads:
			if road["class"] != &"lane": continue
			var points: PackedVector2Array = road["points"]
			if at.distance_to(points[0]) <= 12.0 or at.distance_to(points[points.size() - 1]) <= 12.0: return true
	return false


static func _has_prop(plan: VillagePlan, needle: String) -> bool:
	for p in plan.props:
		if String(p["key"]).to_lower().contains(needle): return true
	return false


static func _seed_for(key: StringName, index: int, scale: float) -> int:
	return absi(hash("village-archetype|%s|%d|%.1f" % [String(key), index, scale]))
