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

static func run() -> SuiteResult:
	return _run_selected(_requested_row())


## Bounded VIL-020 entry point used by run_all's named row lanes.  Keeping
## this selector in the suite means a single Thorpe/Strand/Lord row still uses
## the exact canonical 3-seed x 3-scale matrix and strict failure accounting.
static func run_row(key: StringName) -> SuiteResult:
	return _run_selected(key)


## Semantic controls for spatial archetype predicates, independent of the
## expensive native-building matrix. A building "on" a common fronts it;
## putting its centre inside the common contradicts the no-building rule.
static func run_contracts() -> SuiteResult:
	var res := SuiteResult.new("village archetype contracts")
	var plan := VillagePlan.new(VillageSpec.new(42))
	plan.commons.append({"kind": &"common", "poly": Poly.from_rect(Rect2(-10.0, -10.0, 20.0, 20.0))})
	plan.lots.append({"front": PackedVector2Array([Vector2(-6.0, 12.0), Vector2(6.0, 12.0)])})
	var building := {"request": BigGlade.default_request(&"temple", 42), "lot": 0,
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 20.0)),
		"placement": {"footprint": Rect2(-4.0, -5.0, 8.0, 10.0),
			"bounds": AABB(Vector3(-4.0, 0.0, -5.0), Vector3(8.0, 8.0, 10.0)),
			"front": Vector3(0.0, 0.0, -1.0), "door": Vector3(0.0, 1.0, -5.0)}}
	plan.buildings.append(building)
	res.checked += 1
	if not _temple_on_common(plan): res.fail("temple fronting a clear common is not recognised")
	building["transform"] = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, 20.0))
	res.checked += 1
	if _temple_on_common(plan): res.fail("temple facing away from common escaped frontage QA")
	building["transform"] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 10.0))
	res.checked += 1
	if _temple_on_common(plan): res.fail("temple standing inside common escaped frontage QA")
	building["transform"] = Transform3D(Basis.IDENTITY, Vector3(100.0, 0.0, 20.0))
	res.checked += 1
	if _temple_on_common(plan): res.fail("remote temple with stale nearby frontage escaped QA")
	var orchard := VillagePlan.new(VillageSpec.new(43))
	var farm := BuildingRequest.house(43, &"farmhouse", &"farmer", 10, 14, 2.7)
	orchard.buildings.append({"request": farm, "lot": 0})
	orchard.lots.append({"poly": Poly.from_rect(Rect2(-15, -15, 30, 30))})
	for x in [-5.0, 0.0, 5.0]:
		orchard.plants.append({"key": "Wild_CommonTree_1", "pos": Vector2(x, 8), "host": 0, "row": "orchard:0"})
	res.checked += 1
	if not _has_orchard(orchard): res.fail("actual farm tree row was not recognised as orchard")
	orchard.plants[-1]["pos"] += Vector2(0, 3)
	res.checked += 1
	if _has_orchard(orchard): res.fail("scattered trees passed as an orchard row")
	orchard.plants[-1]["pos"] = orchard.plants[0]["pos"]
	res.checked += 1
	if _has_orchard(orchard): res.fail("two distinct trees passed as an orchard")
	var blight := VillagePlan.new(VillageSpec.new(44))
	blight.plants.append({"key": "Nature_DeadTree_1", "pos": Vector2.ZERO})
	blight.plants.append({"key": "Wild_Mushroom_Common", "pos": Vector2.ONE})
	res.checked += 1
	if not _has_plant_category(blight, "dead_tree") or not _has_plant_category(blight, "mushroom") or _has_plant_category(blight, "tree"):
		res.fail("blight plant categories do not match actual catalogue models")
	blight.plants.append({"key": "Wild_TwistedTree_1", "pos": Vector2(3, 0)})
	res.checked += 1
	if not _has_plant_category(blight, "tree"): res.fail("living twisted tree escaped blight no-green rule")
	return res


static func _run_selected(requested: StringName) -> SuiteResult:
	var res := SuiteResult.new("village archetype")
	for row in ARCHETYPES:
		if requested != &"" and row["key"] != requested:
			continue
		var row_failures := 0
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
					var message := "%s: QA: %s" % [who, String(failure)]
					res.fail(message)
					print("VIL020 FAIL ", message)
				for failure2 in _must_failures(row, plan, scale):
					var message2 := "%s: %s" % [who, failure2]
					res.fail(message2)
					print("VIL020 FAIL ", message2)
				if res.failures.size() > before:
					row_failures += 1
				print("VIL020 DONE ", who, " defects=", res.failures.size() - before)
		res.note("  %s: %d cases, %d defects" % [String(row["key"]), 9, row_failures])
	return res


static func _requested_row() -> StringName:
	for arg in OS.get_cmdline_args():
		var text := String(arg)
		if text.begins_with("--row="):
			return StringName(text.substr(6))
	return &""


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
				if not _has_orchard(plan): out.append("needs an orchard")
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
				if not plan.water.any(func(w: Dictionary) -> bool:
					return w["kind"] == &"race" and (w["poly"] as PackedVector2Array).size() >= 3):
					out.append("needs a mill race")
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
				if not _has_plant_category(plan, "dead_tree"): out.append("needs dead trees")
			&"mushrooms":
				if not _has_plant_category(plan, "mushroom"): out.append("needs mushrooms")
			&"ruin":
				if not _has_prop(plan, "wall_broken"): out.append("needs a ruin")
			&"no_green":
				if _has_plant_category(plan, "tree"): out.append("must contain no green tree")
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


static func _has_plant_category(plan: VillagePlan, category: String) -> bool:
	return plan.plants.any(func(p): return PropCatalog.category(p["key"]) == category)


## An orchard is an actual row of at least three living trees on a farm,
## not a prop whose name happens to contain the word orchard.
static func _has_orchard(plan: VillagePlan) -> bool:
	var rows := {}
	for tree in plan.plants:
		var host := int(tree.get("host", -1))
		if host < 0 or host >= plan.buildings.size() or PropCatalog.category(tree["key"]) != "tree":
			continue
		if (plan.buildings[host]["request"] as BuildingRequest).purpose != &"farmer":
			continue
		var lot := plan.lot_of_building(host)
		if lot < 0 or not Poly.contains_point(plan.lots[lot]["poly"], tree["pos"]):
			continue
		var row := String(tree.get("row", ""))
		if not row.begins_with("orchard:"):
			continue
		if not rows.has(row): rows[row] = []
		rows[row].append(Vector2(tree["pos"]))
	for points in rows.values():
		if points.size() < 3: continue
		var direction: Vector2 = (points[1] - points[0]).normalized()
		if points[0].distance_to(points[1]) < 2.0: continue
		var aligned := 2
		for i in range(2, points.size()):
			if points[i].distance_to(points[0]) >= 2.0 and points[i].distance_to(points[1]) >= 2.0 and absf((Vector2(points[i]) - points[0]).cross(direction)) < 0.1:
				aligned += 1
		if aligned >= 3: return true
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
	if not _has_purpose(plan, &"bakery") or not _has_prop(plan, "mill_wheel"):
		return false
	# A working mill stands on dry walls beside its wheel and race. Requiring
	# its root inside the river put the entire building under water; named
	# decorative props alone also cannot establish that hydraulic connection.
	var check := VillagePlaceCheck.new()
	check._check_mill(plan)
	return check.failures.is_empty() and plan.water.any(func(w: Dictionary) -> bool:
		return w["kind"] == &"race")


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
			if String(p["key"]) != "adit" or not bool(p.get("built", false)): continue
			var at: Vector2 = p["pos"]
			if at.distance_to(points[points.size() - 1]) > 18.0: continue
			var yaw: float = p["yaw"]
			var facing := Vector2(-sin(yaw), -cos(yaw))
			var near := Geometry2D.get_closest_point_to_segment(at, points[points.size() - 2], points[points.size() - 1])
			if facing.dot((near - at).normalized()) < cos(deg_to_rad(30.0)): continue
			var kit := PropKit.new(MeshKit.new(4), 0, 1, 2, 3)
			var box: AABB = kit.adit(Vector3(at.x, 0.0, at.y), yaw)
			var actual := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
			if not plan.site.encloses(actual) or not actual.is_equal_approx(p.get("rect", Rect2())): continue
			var blocked := false
			for edge in plan.enclosure.size():
				for run in VillageBuilder._minus_gates(plan.enclosure[edge], plan.enclosure[(edge + 1) % plan.enclosure.size()], plan.gate_crossings):
					var wall := Poly.ribbon(PackedVector2Array([run[0], run[1]]), VillageBuilder.WALL_THICK * 0.5)
					blocked = blocked or VillageLotPlanner.overlap_area(Poly.from_rect(actual), wall) > VillageLotPlanner.AREA_EPS
			if blocked: continue
			var wet := false
			for water in plan.water:
				wet = wet or VillageLotPlanner.overlap_area(Poly.from_rect(actual), water["poly"]) > VillageLotPlanner.AREA_EPS
			if wet: continue
			var grid := VillageNavCheck.build_grid(plan)
			if not grid.flood_from(near, 3.0): continue
			# Reach the timber mouth itself, not merely the front of a spoil
			# pile at the corner of the prop's much larger measured envelope.
			if grid.reached(Rect2(at - Vector2.ONE * 0.1, Vector2.ONE * 0.2), 0.25): return true
	return false


static func _temple_on_common(plan: VillagePlan) -> bool:
	for b in plan.buildings:
		if (b["request"] as BuildingRequest).kind != &"temple": continue
		var front: PackedVector2Array = plan.lots[int(b["lot"])]["front"]
		var at: Vector2 = VillageMeasure.front_mid(b)
		for common in plan.commons:
			var poly: PackedVector2Array = common["poly"]
			if VillageLotPlanner.overlap_area(VillageMeasure.bounds_poly(b), poly) > VillageLotPlanner.AREA_EPS:
				continue
			var front_distance := INF
			for point in poly:
				front_distance = minf(front_distance,
					point.distance_to(Geometry2D.get_closest_point_to_segment(point, front[0], front[1])))
			if front_distance > VillagePlaceCheck.FRONTED_REACH: continue
			var reach: float = VillagePlaceCheck.FRONTED_REACH + VillageLotPlanner.LOT_RULES[&"church"]["set_max"]
			if VillageMeasure.point_to_poly(at, poly) > reach: continue
			var toward: Vector2 = (VillageMeasure.centre(poly) - at).normalized()
			if VillageMeasure.front_dir(b).dot(toward) >= cos(deg_to_rad(30.0)):
				return true
	return false


static func _manor_at_lane_head(plan: VillagePlan) -> bool:
	for b in plan.buildings:
		var request: BuildingRequest = b["request"]
		if request.kind != &"castle": continue
		var native := BigGlade.generate(request)
		if not native.is_ok() or not native.spec is CastleSpec or (native.spec as CastleSpec).tier != &"manor":
			continue
		var lot_index: int = int(b["lot"])
		var lot: Dictionary = plan.lots[lot_index]
		var road_index: int = int(lot["road"])
		if road_index < 0 or road_index >= plan.roads.size(): continue
		var road: Dictionary = plan.roads[road_index]
		if road["class"] != &"lane": continue
		var shared := false
		for i in range(plan.lots.size()):
			if i != lot_index and int(plan.lots[i]["road"]) == road_index: shared = true
		if shared: continue
		# The arrival is the LOT frontage. A manor's real porch and its origin
		# stand well behind the mandatory 20m forecourt, so origin-distance is
		# not a test of whether a carriage lane reaches this estate.
		var front: PackedVector2Array = lot["front"]
		var points: PackedVector2Array = road["points"]
		var end: Vector2 = points[points.size() - 1]
		var clearance: float = float(road["width"]) * 0.5 + float(road["verge"]) + 1.0
		if end.distance_to(Geometry2D.get_closest_point_to_segment(end, front[0], front[1])) <= clearance:
			return true
	return false


static func _has_prop(plan: VillagePlan, needle: String) -> bool:
	for p in plan.props:
		if String(p["key"]).to_lower().contains(needle): return true
	return false


static func _seed_for(key: StringName, index: int, scale: float) -> int:
	return absi(hash("village-archetype|%s|%d|%.1f" % [String(key), index, scale]))
