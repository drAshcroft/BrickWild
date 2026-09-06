class_name VillageCheckSuite
extends RefCounted
## VIL-006..009: the four village checks. Every rule is shown to fire on a
## plan built (or tampered with) to break exactly it, and then the checks
## run over a sweep of street and green villages, which must be clean.
##
## The tampering is done on real planned villages rather than on plans made
## up from nothing, because a village plan has a lot of parts and a hand-made
## one that breaks rule X tends to break rules Y and Z as well; starting from
## a clean plan and moving one thing keeps each fixture about one sentence.

const SWEEP_SEEDS := 12


static func run() -> SuiteResult:
	var res := SuiteResult.new("vcheck")
	var base: VillagePlan = _plan(9101, 40, &"farming", 0.3)
	if base.buildings.is_empty():
		res.fail("the base village planned no buildings; nothing to check against")
		return res
	_scale_fixtures(res, base)
	_road_fixtures(res, base)
	_lot_fixtures(res, base)
	_place_fixtures(res, base)
	_dress_fixtures(res, base)
	_nav_fixtures(res, base)
	_sweep(res)
	return res


static func _spec(p_seed: int, population: int, purpose: StringName, wealth: float) -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.population = population
	spec.culture = &"english"
	spec.purpose = purpose
	spec.wealth = wealth
	spec.enclosure = &"none"
	spec.water = &"none"
	spec.generate(p_seed)
	return spec


static func _plan(p_seed: int, population: int, purpose: StringName, wealth: float) -> VillagePlan:
	return VillageLotPlanner.plan(_spec(p_seed, population, purpose, wealth))


## A fresh copy of a plan to tamper with: the lists are duplicated deep
## enough that moving a building in the copy leaves the original alone.
static func _copy(plan: VillagePlan) -> VillagePlan:
	var out := VillagePlan.new(plan.spec)
	out.site = plan.site
	out.landmark_site = plan.landmark_site.duplicate(true)
	out.roads = plan.roads.duplicate(true)
	out.lots = plan.lots.duplicate(true)
	out.buildings = []
	for b in plan.buildings:
		var c: Dictionary = b.duplicate()
		c["placement"] = (b["placement"] as Dictionary).duplicate()
		out.buildings.append(c)
	out.commons = plan.commons.duplicate(true)
	out.enclosure = plan.enclosure.duplicate()
	out.gate_crossings = plan.gate_crossings.duplicate(true)
	out.water = plan.water.duplicate(true)
	out.fields = plan.fields.duplicate(true)
	out.props = plan.props.duplicate(true)
	out.plants = plan.plants.duplicate(true)
	return out


static func _expect(res: SuiteResult, what: String, rep: Dictionary, prefix: String) -> void:
	res.checked += 1
	for f in rep["failures"]:
		if str(f).begins_with(prefix + ":"):
			return
	res.fail("%s: the %s rule did not fire: %s" % [what, prefix, str(rep["failures"])])


static func _clean(res: SuiteResult, what: String, rep: Dictionary) -> void:
	res.checked += 1
	for f in rep["failures"]:
		res.fail("%s (should pass): %s" % [what, str(f)])


## Move building `i` so its front is at `pos` looking along `dir`.
static func _move(plan: VillagePlan, i: int, pos: Vector2, dir: Vector2) -> void:
	var b: Dictionary = plan.buildings[i]
	var yaw: float = atan2(-dir.x, -dir.y)
	var basis := Basis(Vector3.UP, yaw)
	var fp: Rect2 = b["placement"]["footprint"]
	var local := Vector3(fp.position.x + fp.size.x / 2.0, 0.0, fp.position.y)
	var origin: Vector3 = Vector3(pos.x, 0.0, pos.y) - basis * local
	b["transform"] = Transform3D(basis, origin)
	b["door"] = b["transform"] * (b["placement"]["door"] as Vector3)


# ------------------------------------------------------------------ 9.1

static func _scale_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "scale on a planned village", VillageScaleCheck.new().check(base))
	# housed: strike half the houses
	var p := _copy(base)
	var houses: Array[int] = p.buildings_of_kind(&"house")
	for k in range(houses.size() / 2 + 1):
		p.buildings.remove_at(p.buildings_of_kind(&"house")[0])
	_expect(res, "housed fixture", VillageScaleCheck.new().check(p), "housed")
	# not a city: a site 500 m across
	var p2 := _copy(base)
	p2.site = Rect2(Vector2(-250, -250), Vector2(500, 500))
	_expect(res, "not_a_city fixture", VillageScaleCheck.new().check(p2), "not_a_city")
	# earned: a guildhall in a village of forty
	var p3 := _copy(base)
	var hall: Dictionary = p3.buildings[0].duplicate()
	hall["request"] = BuildingRequest.shop(1, &"guildhall")
	hall["kind"] = &"shop"
	p3.buildings.append(hall)
	_expect(res, "earned fixture", VillageScaleCheck.new().check(p3), "earned")
	# density: the same houses on a site three times the size
	var p4 := _copy(base)
	p4.site = Rect2(base.site.position * 3.0, base.site.size * 3.0)
	_expect(res, "density fixture", VillageScaleCheck.new().check(p4), "density")
	# pure: a plan that is not what its spec plans
	var p5 := _copy(base)
	p5.buildings.remove_at(0)
	_expect(res, "pure fixture", VillageScaleCheck.new().check(p5), "pure")


# ------------------------------------------------------------------ 9.2

static func _road_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "roads on a planned village", VillageRoadCheck.new().check(base))
	var w: float = VillageSitePlanner.ROAD_CLASSES[&"street"]["width"]
	# connected: a street joined to nothing
	var p := _copy(base)
	var corner: Vector2 = base.site.position + Vector2(4.0, 4.0)
	p.roads.append({"points": PackedVector2Array([corner, corner + Vector2(0.0, 8.0)]),
		"class": &"street", "width": w, "verge": 1.0, "surface": "dirt"})
	_expect(res, "connected fixture", VillageRoadCheck.new().check(p), "connected")
	# through: a through road that turns back to the side it came in on
	var p2 := _copy(base)
	var pts: PackedVector2Array = p2.roads[0]["points"]
	pts[pts.size() - 1] = Vector2(p2.site.position.x, pts[pts.size() - 1].y + 20.0)
	p2.roads[0]["points"] = pts
	_expect(res, "through fixture", VillageRoadCheck.new().check(p2), "through")
	# hierarchy: a lane that starts and ends on nothing
	var p3 := _copy(base)
	var mid: Vector2 = base.site.get_center() + Vector2(0.0, -30.0)
	p3.roads.append({"points": PackedVector2Array([mid, mid + Vector2(15.0, 0.0)]),
		"class": &"lane", "width": 2.5, "verge": 0.5, "surface": "dirt"})
	_expect(res, "hierarchy fixture", VillageRoadCheck.new().check(p3), "hierarchy")
	# dead ends: a street that stops in a field
	var p4 := _copy(base)
	var through: PackedVector2Array = base.roads[0]["points"]
	var start: Vector2 = through[through.size() / 2]
	p4.roads.append({"points": PackedVector2Array([start, start + Vector2(0.0, -25.0)]),
		"class": &"street", "width": w, "verge": 1.0, "surface": "dirt"})
	_expect(res, "dead_ends fixture", VillageRoadCheck.new().check(p4), "dead_ends")
	# width: a through road at half width
	var p5 := _copy(base)
	p5.roads[0]["width"] = 3.0
	_expect(res, "width fixture", VillageRoadCheck.new().check(p5), "width")
	# bends: a kink of ninety degrees in the through road
	var p6 := _copy(base)
	var kinked: PackedVector2Array = p6.roads[0]["points"]
	var k: int = kinked.size() / 2
	kinked[k] = kinked[k] + Vector2(0.0, 12.0)
	p6.roads[0]["points"] = kinked
	_expect(res, "bends fixture", VillageRoadCheck.new().check(p6), "bends")
	# junctions: two streets off one point at ten degrees
	var p7 := _copy(base)
	var j: Vector2 = through[through.size() / 2]
	p7.roads.append({"points": PackedVector2Array([j, j + Vector2(20.0, 20.0)]),
		"class": &"street", "width": w, "verge": 1.0, "surface": "dirt"})
	p7.roads.append({"points": PackedVector2Array([j, j + Vector2(20.0, 16.0)]),
		"class": &"street", "width": w, "verge": 1.0, "surface": "dirt"})
	_expect(res, "junctions fixture", VillageRoadCheck.new().check(p7), "junctions")
	# clear: a house moved onto the through road
	var p8 := _copy(base)
	_move(p8, p8.buildings_of_kind(&"house")[0], through[through.size() / 2], Vector2(0, -1))
	_expect(res, "clear fixture", VillageRoadCheck.new().check(p8), "clear")
	# crossings: a stream across the through road with no bridge
	var p9 := _copy(base)
	var cx: float = through[through.size() / 2].x
	p9.water.append({"poly": PackedVector2Array([Vector2(cx - 3, p9.site.position.y), Vector2(cx + 3, p9.site.position.y),
		Vector2(cx + 3, p9.site.end.y), Vector2(cx - 3, p9.site.end.y)]), "kind": &"stream"})
	_expect(res, "crossings fixture", VillageRoadCheck.new().check(p9), "crossings")
	# gates: an enclosure the through road crosses with no gate
	var p10 := _copy(base)
	p10.enclosure = Poly.from_rect(p10.site.grow(-5.0))
	_expect(res, "gates fixture", VillageRoadCheck.new().check(p10), "gates")


# ------------------------------------------------------------------ 9.3

static func _lot_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "lots on a planned village", VillageLotCheck.new().check(base))
	var houses: Array[int] = base.buildings_of_kind(&"house")
	var h0: int = houses[0]
	var lot0: int = int(base.buildings[h0]["lot"])
	# tiling: a lot copied onto its neighbour
	var p := _copy(base)
	p.lots.append(p.lots[lot0].duplicate(true))
	_expect(res, "tiling fixture", VillageLotCheck.new().check(p), "tiling")
	# frontage: a lot's front edge slid off its road
	var p2 := _copy(base)
	var front: PackedVector2Array = p2.lots[lot0]["front"]
	p2.lots[lot0]["front"] = PackedVector2Array([front[0] + Vector2(0.0, 3.0), front[1] + Vector2(0.0, 3.0)])
	_expect(res, "frontage fixture", VillageLotCheck.new().check(p2), "frontage")
	# faces the road: a house turned side-on to its street
	var p3 := _copy(base)
	var b3: Dictionary = p3.buildings[h0]
	var fwd: Vector2 = VillageMeasure.front_dir(b3)
	_move(p3, h0, VillageMeasure.front_mid(b3), Vector2(-fwd.y, fwd.x))
	_expect(res, "faces_road fixture", VillageLotCheck.new().check(p3), "faces_road")
	# setback: a cottage pushed twenty metres back from its road
	var p4 := _copy(base)
	var b4: Dictionary = p4.buildings[h0]
	_move(p4, h0, VillageMeasure.front_mid(b4) - VillageMeasure.front_dir(b4) * 20.0, VillageMeasure.front_dir(b4))
	_expect(res, "setback fixture", VillageLotCheck.new().check(p4), "setback")
	# fit: a house slid sideways off its lot
	var p5 := _copy(base)
	var b5: Dictionary = p5.buildings[h0]
	var f5: Vector2 = VillageMeasure.front_dir(b5)
	_move(p5, h0, VillageMeasure.front_mid(b5) + Vector2(-f5.y, f5.x) * 8.0, f5)
	_expect(res, "fit fixture", VillageLotCheck.new().check(p5), "fit")
	# fire gap: two houses standing in one spot
	var p6 := _copy(base)
	if houses.size() >= 2:
		var b6: Dictionary = p6.buildings[houses[1]]
		_move(p6, houses[1], VillageMeasure.front_mid(p6.buildings[h0]) + Vector2(0.5, 0.0), VillageMeasure.front_dir(p6.buildings[h0]))
		_expect(res, "fire_gap fixture", VillageLotCheck.new().check(p6), "fire_gap")
	# back to front: a house set down four metres behind another, looking at its back
	var p7 := _copy(base)
	if houses.size() >= 2:
		var a7: Dictionary = p7.buildings[h0]
		var fa: Vector2 = VillageMeasure.front_dir(a7)
		var fp: Rect2 = a7["placement"]["footprint"]
		var behind: Vector2 = VillageMeasure.front_mid(a7) - fa * (fp.size.y + 4.0)
		_move(p7, houses[1], behind + fa * 0.0, fa)
		_expect(res, "back_to_front fixture", VillageLotCheck.new().check(p7), "back_to_front")
	# variety: every house the same house
	var p8 := _copy(base)
	if houses.size() >= 2:
		var first: Dictionary = p8.buildings[h0]
		for i in houses:
			p8.buildings[i]["request"] = first["request"]
			p8.buildings[i]["placement"] = first["placement"]
		# and two of them side by side
		var f8: Vector2 = VillageMeasure.front_dir(first)
		_move(p8, houses[1], VillageMeasure.front_mid(first) + Vector2(-f8.y, f8.x) * 14.0, f8)
		_expect(res, "variety fixture", VillageLotCheck.new().check(p8), "variety")


# ------------------------------------------------------------------ 9.4

static func _place_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "places on a planned village", VillagePlaceCheck.new().check(base))
	var houses: Array[int] = base.buildings_of_kind(&"house")
	var cc: Vector2 = VillageMeasure.common_centre(base)
	# common: a house on the common
	var p := _copy(base)
	_move(p, houses[0], cc, Vector2(0, -1))
	_expect(res, "common fixture", VillagePlaceCheck.new().check(p), "common")
	# landmark: a house taller than the church
	var p2 := _copy(base)
	var church: Array[int] = p2.buildings_of_kind(&"church")
	if not church.is_empty():
		var pl: Dictionary = p2.buildings[houses[0]]["placement"]
		var bounds: AABB = pl["bounds"]
		pl["bounds"] = AABB(bounds.position, Vector3(bounds.size.x, 60.0, bounds.size.z))
		_expect(res, "landmark fixture", VillagePlaceCheck.new().check(p2), "landmark")
	# well: a well against a house
	var p3 := _copy(base)
	p3.props.append({"key": "Well", "pos": VillageMeasure.front_mid(p3.buildings[houses[0]]) + Vector2(0.0, -1.0),
		"yaw": 0.0, "host": -1, "zone": Rect2()})
	_expect(res, "well fixture", VillagePlaceCheck.new().check(p3), "well")
	# tavern: a tavern hidden at the back of a lane, far from the gates
	var p4 := _copy(base)
	var tav: Dictionary = p4.buildings[houses[0]].duplicate()
	tav["request"] = BuildingRequest.shop(2, &"tavern")
	tav["kind"] = &"shop"
	tav["class"] = &"shop"
	var lane_lot := -1
	for li in range(p4.lots.size()):
		if p4.roads[int(p4.lots[li]["road"])]["class"] == &"lane":
			lane_lot = li
	if lane_lot >= 0:
		tav["lot"] = lane_lot
		p4.buildings.append(tav)
		_move(p4, p4.buildings.size() - 1, cc + Vector2(0.0, 40.0), Vector2(0, 1))
		_expect(res, "tavern fixture", VillagePlaceCheck.new().check(p4), "tavern")
	# stable: a stable forty metres from its inn
	var p5 := _copy(base)
	var inn: Dictionary = p5.buildings[houses[0]].duplicate()
	inn["request"] = BuildingRequest.shop(3, &"inn")
	inn["kind"] = &"shop"
	var stable: Dictionary = inn.duplicate()
	stable["request"] = BuildingRequest.shop(4, &"stable")
	p5.buildings.append(inn)
	p5.buildings.append(stable)
	_move(p5, p5.buildings.size() - 1, cc + Vector2(45.0, 0.0), Vector2(0, -1))
	_expect(res, "stable fixture", VillagePlaceCheck.new().check(p5), "stable")
	# smithy: a smithy right against the church, upwind
	var p6 := _copy(base)
	var smith: Dictionary = p6.buildings[houses[0]].duplicate()
	smith["request"] = BuildingRequest.shop(5, &"blacksmith")
	smith["kind"] = &"shop"
	p6.buildings.append(smith)
	_move(p6, p6.buildings.size() - 1, cc + Vector2(-40.0, 0.0), Vector2(0, -1))
	_expect(res, "smithy fixture", VillagePlaceCheck.new().check(p6), "smithy")
	# mill: water on the site and a bakery that does not touch it
	var p7 := _copy(base)
	p7.spec.water = &"stream"
	var mill: Dictionary = p7.buildings[houses[0]].duplicate()
	mill["request"] = BuildingRequest.shop(6, &"bakery")
	mill["kind"] = &"shop"
	p7.buildings.append(mill)
	p7.water.append({"poly": Poly.from_rect(Rect2(p7.site.position, Vector2(6.0, 6.0))), "kind": &"stream"})
	_expect(res, "mill fixture", VillagePlaceCheck.new().check(p7), "mill")
	p7.spec.water = &"none"
	# market: two stall rows a metre apart
	var p8 := _copy(base)
	for i in range(3):
		p8.props.append({"key": "Stall_Empty", "pos": cc + Vector2(float(i) * 2.5, -2.0), "yaw": 0.0, "host": -1, "zone": Rect2()})
		p8.props.append({"key": "Stall_Empty", "pos": cc + Vector2(float(i) * 2.5, -1.0), "yaw": 0.0, "host": -1, "zone": Rect2()})
	_expect(res, "market fixture", VillagePlaceCheck.new().check(p8), "market")
	# civic: a town hall at the far corner of the site
	var p9 := _copy(base)
	var civic: Dictionary = p9.buildings[houses[0]].duplicate()
	civic["request"] = BuildingRequest.shop(7, &"town_hall")
	civic["kind"] = &"shop"
	p9.buildings.append(civic)
	_move(p9, p9.buildings.size() - 1, p9.site.end - Vector2(12.0, 12.0), Vector2(0, -1))
	_expect(res, "civic fixture", VillagePlaceCheck.new().check(p9), "civic")
	# manor: a keep with its back to the common, among the houses
	var p10 := _copy(base)
	var manor: Dictionary = p10.buildings[houses[0]].duplicate()
	manor["request"] = BuildingRequest.castle(8)
	manor["kind"] = &"castle"
	manor["class"] = &"manor"
	p10.buildings.append(manor)
	_move(p10, p10.buildings.size() - 1, VillageMeasure.front_mid(p10.buildings[houses[0]]) + Vector2(1.0, 0.0), Vector2(0, 1))
	_expect(res, "manor fixture", VillagePlaceCheck.new().check(p10), "manor")
	# churchyard: houses on three sides of the church
	var p11 := _copy(base)
	if not church.is_empty() and houses.size() >= 3:
		var cb: Dictionary = p11.buildings[church[0]]
		var ccen: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(cb))
		var fp: Rect2 = cb["placement"]["footprint"]
		var k := 0
		for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]:
			var off: float = (fp.size.x if absf(dir.x) > 0.5 else fp.size.y) / 2.0 + 1.5
			_move(p11, houses[k], ccen + dir * off, -dir)
			k += 1
		_expect(res, "churchyard fixture", VillagePlaceCheck.new().check(p11), "churchyard")
	# gradient: the biggest houses furthest from the common
	var p12 := _copy(base)
	if houses.size() >= 5:
		# The rule measures the houses free to stand round the common, which
		# is every house but a farm -- a farm answers to `farms outside`
		# instead. A farming village is mostly farms, so the fixture makes
		# these ordinary houses first; otherwise it is holding out a set the
		# rule does not look at and calling the silence a pass.
		# a DETACHED request: `_copy` shares them with the base plan, and
		# every fixture after this one is built from that same base
		for i in houses:
			var detached: BuildingRequest = (p12.buildings[i]["request"] as BuildingRequest).copy()
			detached.purpose = &"none"
			p12.buildings[i]["request"] = detached
		var order: Array = houses.duplicate()
		order.sort_custom(func(a, b) -> bool:
			return VillageMeasure.centre(VillageMeasure.footprint_poly(p12.buildings[a])).distance_to(cc) \
				< VillageMeasure.centre(VillageMeasure.footprint_poly(p12.buildings[b])).distance_to(cc))
		for i in range(order.size()):
			var pl2: Dictionary = (p12.buildings[order[i]]["placement"] as Dictionary).duplicate()
			var side: float = 6.0 + float(i) * 0.5
			pl2["footprint"] = Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side))
			p12.buildings[order[i]]["placement"] = pl2
		_expect(res, "gradient fixture", VillagePlaceCheck.new().check(p12), "gradient")
	# farms: a farm in the middle of the village
	var p13 := _copy(base)
	var farm := -1
	for i in houses:
		if (p13.buildings[i]["request"] as BuildingRequest).purpose == &"farmer":
			farm = i
	if farm >= 0:
		_move(p13, farm, cc + Vector2(0.0, 0.0), Vector2(0, -1))
		p13.site = p13.site.grow(60.0)
		_expect(res, "farms fixture", VillagePlaceCheck.new().check(p13), "farms")


# ------------------------------------------------------------------ 9.6

## VIL-015: every DressCheck rule shown to fire on a plan built to break it.
##
## Each fixture moves ONE piece of dressing on a copy of a real village, the
## same way the place fixtures move one building. The rules about things the
## planner does not lay yet -- fences, fields -- are given the thing by hand,
## which is the only way to see them fire at all.
static func _dress_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "dressing on a planned village", VillageDressCheck.new().check(base))
	var far: Vector2 = base.site.position + Vector2(1.0, 1.0)

	# host: a barrel belonging to a building, out in the fields
	var p := _copy(base)
	p.props = [{"key": "Barrel", "pos": far, "yaw": 0.0, "host": 0,
		"rect": Rect2(far - Vector2(0.35, 0.35), Vector2(0.7, 0.7)), "zone": Rect2()}]
	_expect(res, "dress host fixture", VillageDressCheck.new().check(p), "host")

	# doorways: a barrel on somebody's threshold
	var p2 := _copy(base)
	var door: Vector2 = VillageMeasure.door(base.buildings[0])
	p2.props = [{"key": "Barrel", "pos": door, "yaw": 0.0, "host": 0,
		"rect": Rect2(door - Vector2(0.35, 0.35), Vector2(0.7, 0.7)), "zone": Rect2()}]
	p2.plants = []
	_expect(res, "dress doorways fixture", VillageDressCheck.new().check(p2), "doorways")

	# road: a barrel on the carriageway
	var p3 := _copy(base)
	var pts: PackedVector2Array = base.roads[0]["points"]
	var on_road: Vector2 = pts[pts.size() / 2]
	p3.props = [{"key": "Barrel", "pos": on_road, "yaw": 0.0, "host": -1,
		"rect": Rect2(on_road - Vector2(0.35, 0.35), Vector2(0.7, 0.7)),
		"zone": Rect2(on_road - Vector2(0.5, 0.5), Vector2(1.0, 1.0))}]
	p3.plants = []
	_expect(res, "dress road fixture", VillageDressCheck.new().check(p3), "road")

	# canopies: a tree growing out of a house
	var p4 := _copy(base)
	var mid: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(base.buildings[0]))
	p4.props = []
	p4.plants = [{"key": "Wild_CommonTree_1", "pos": mid, "canopy": 2.5,
		"trunk": 0.7, "yaw": 0.0}]
	_expect(res, "dress canopies fixture", VillageDressCheck.new().check(p4), "canopies")

	# green: a wood on the common
	var common: PackedVector2Array = VillageMeasure.common_poly(base)
	if not common.is_empty():
		var p5 := _copy(base)
		var c: Vector2 = VillageMeasure.centre(common)
		p5.props = []
		p5.plants = []
		for k in range(GREEN_TREES + 1):
			p5.plants.append({"key": "Wild_CommonTree_1", "pos": c + Vector2(float(k) * 0.5, 0.0),
				"canopy": 2.5, "trunk": 0.7, "yaw": 0.0})
		_expect(res, "dress green fixture", VillageDressCheck.new().check(p5), "green")

	# culture: a pine in an english village
	var p6 := _copy(base)
	p6.props = []
	p6.plants = [{"key": "Wild_Pine_1", "pos": far, "canopy": 2.6, "trunk": 1.2, "yaw": 0.0}]
	_expect(res, "dress culture fixture", VillageDressCheck.new().check(p6), "culture")

	# fields: a strip field inside the village
	var p7 := _copy(base)
	p7.props = []
	p7.plants = []
	p7.enclosure = Poly.from_rect(base.site.grow(-10.0))
	p7.fields = [{"kind": &"field", "poly": Poly.from_rect(
		Rect2(base.site.get_center() - Vector2(6.0, 6.0), Vector2(12.0, 12.0)))}]
	_expect(res, "dress fields fixture", VillageDressCheck.new().check(p7), "fields")

	# fences: a rail out in the middle of nowhere
	var p8 := _copy(base)
	p8.plants = []
	p8.props = []
	for k in range(5):
		var at: Vector2 = base.site.get_center() + Vector2(float(k) * 0.3, 0.0)
		p8.props.append({"key": "Dungeon_Rail_Straight", "pos": at, "yaw": 0.0,
			"host": -1, "rect": Rect2(at - Vector2(0.5, 0.1), Vector2(1.0, 0.2)),
			"zone": Rect2()})
	_expect(res, "dress fences fixture", VillageDressCheck.new().check(p8), "fences")


## The most trees DressCheck allows on a common, read from the check so the
## fixture cannot drift away from the rule it is proving.
const GREEN_TREES := VillageDressCheck.GREEN_TREES_MAX


# ------------------------------------------------------------------ 9.5

## VIL-016: every VillageNavCheck rule shown to fire on a plan built to break
## it. One wall of props across the thing the rule is about, each time.
static func _nav_fixtures(res: SuiteResult, base: VillagePlan) -> void:
	_clean(res, "walking a planned village", VillageNavCheck.new().check(base))

	# arrive: wall a building in completely -- a closed ring of crates round
	# its own bounds, which is the only way to be sure there is no way round
	var p := _copy(base)
	var walled: Rect2 = Poly.bounding_rect(
		VillageMeasure.bounds_poly(base.buildings[1])).grow(1.4)
	p.props = []
	var step := 0.8
	var x: float = walled.position.x
	while x <= walled.end.x:
		p.props.append(_block(Vector2(x, walled.position.y), 1.6))
		p.props.append(_block(Vector2(x, walled.end.y), 1.6))
		x += step
	var y0: float = walled.position.y
	while y0 <= walled.end.y:
		p.props.append(_block(Vector2(walled.position.x, y0), 1.6))
		p.props.append(_block(Vector2(walled.end.x, y0), 1.6))
		y0 += step
	_expect(res, "nav arrive fixture", VillageNavCheck.new().check(p), "arrive")

	# road: a wall of crates across the through road
	var p2 := _copy(base)
	var pts: PackedVector2Array = base.roads[0]["points"]
	var mid: Vector2 = pts[pts.size() / 2]
	var dir: Vector2 = (pts[pts.size() / 2 + 1] - mid).normalized()
	var across := Vector2(-dir.y, dir.x)
	p2.props = []
	for k3 in range(-9, 10):
		p2.props.append(_block(mid + across * (float(k3) * 0.8), 1.6))
	_expect(res, "nav road fixture", VillageNavCheck.new().check(p2), "road_open")

	# common: pave the common with crates
	var common: PackedVector2Array = VillageMeasure.common_poly(base)
	if not common.is_empty():
		var p3 := _copy(base)
		var rect: Rect2 = Poly.bounding_rect(common)
		p3.props = []
		var cx: float = rect.position.x
		while cx <= rect.end.x:
			var cy: float = rect.position.y
			while cy <= rect.end.y:
				p3.props.append(_block(Vector2(cx, cy), 1.6))
				cy += 1.2
			cx += 1.2
		_expect(res, "nav common fixture", VillageNavCheck.new().check(p3), "common")


## One crate-sized obstruction, in the shape the nav check reads.
static func _block(at: Vector2, side: float) -> Dictionary:
	return {"key": "Crate_Wooden", "pos": at, "yaw": 0.0, "host": -1,
		"rect": Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)),
		"zone": Rect2()}


# ------------------------------------------------------------------ sweep

## Rules the two planners do not yet reliably satisfy on a grown farming
## site, and the follow-up that would: they are counted and printed here,
## and fail a fixture but not the sweep, so the check keeps measuring them
## without pretending the planner meets them (VILLAGES 9, 12).
## The arrangement pass (VIL-012) settled `density` and `common` -- both are
## gone from this list -- and took `gradient` from seven villages in
## twenty-four to one and `tavern` from nine to three. What is left is what
## the planner still cannot always do:
const PLANNER_FOLLOW_UPS := {
	"tavern": "the tavern takes the upwind gate and the smithy the downwind edge; on a short through road one of them loses (VIL-004 follow-up)",
	"gradient": "big lots do not always fit nearest the common (VIL-004 follow-up)",
	"smithy": "through-road frontage runs out on a small site (VIL-003 follow-up)",
	"landmark": "no view corridor is kept from the gates (VIL-003 follow-up)",
	# A farm can only be within thirty metres of the edge on a field track or
	# at the very end of the through road, and a village with more farms than
	# track frontage runs out of both. VIL-012 took this from every farm in a
	# farming village to the last one or two in three villages of twenty-four;
	# closing it wants tracks on both sides of the road, which is VIL-003's.
	"farms": "the last farm or two run out of field-track frontage (VIL-003 follow-up)",
	# The three the DRESSER does not yet reliably satisfy (VIL-013). Each has
	# a fixture that fires, and each is counted here rather than quieted.
	"use": "the well and the benches on a small common are ringed by their own footprints (VIL-013 follow-up)",
	"edge": "the edge band cannot always find planting ground round a stretched site (VIL-013 follow-up)",
	"road_open": "the through road is measured pinched where the common now abuts it (VIL-016 follow-up)",
}

static func _sweep(res: SuiteResult) -> void:
	var bad := 0
	var reported := 0
	var pending := {}
	var cases := [
		{"population": 26, "purpose": &"mining", "wealth": 0.2},
		{"population": 40, "purpose": &"farming", "wealth": 0.3},
	]
	for c in cases:
		for s in range(SWEEP_SEEDS):
			var plan: VillagePlan = _plan(9200 + s, int(c["population"]), c["purpose"], float(c["wealth"]))
			res.checked += 1
			var rep: Dictionary = VillageQA.new().check(plan, {}, false)
			var hard := false
			for f in rep["failures"]:
				var rule: String = str(f).split(":")[0]
				if PLANNER_FOLLOW_UPS.has(rule):
					pending[rule] = int(pending.get(rule, 0)) + 1
					continue
				hard = true
				if reported < 12:
					res.fail("seed %d pop %d: %s" % [9200 + s, int(c["population"]), str(f)])
					reported += 1
			if hard:
				bad += 1
	res.note("village checks: %d villages, %d with failures" % [cases.size() * SWEEP_SEEDS, bad])
	for rule in pending:
		res.warn("village checks: %s fails in %d of %d villages -- %s"
			% [rule, int(pending[rule]), cases.size() * SWEEP_SEEDS, String(PLANNER_FOLLOW_UPS[rule])])
