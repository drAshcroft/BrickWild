extends RefCounted
## Focused pure-plan contract for CAS-006 tower houses.
##
## This suite intentionally stops before CastleBuilder integration: it proves
## the plan is derived from tower geometry, while the later builder suite proves
## that the same records are emitted as stone.

const TowerPlan = preload("res://src/castle/castle_tower_plan.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle tower plan")
	for row in [
		{"name": "bologna", "style": &"norman", "w": 8.0, "l": 8.0, "h": 45.0,
			"seed": 8803, "jog": &"l"},
		{"name": "scottish", "style": &"norman", "w": 14.0, "l": 12.0, "h": 34.0,
			"seed": 8804, "jog": &"z"},
		{"name": "wizard oval", "style": &"wizard", "w": 9.0, "l": 9.0, "h": 42.0,
			"seed": 12012, "jog": &"none"},
	]:
		var spec := _spec(row)
		var plan: HousePlan = TowerPlan.generate(spec, false)
		var who: String = String(row["name"])
		res.checked += 1
		_expect(res, plan.spec != null, who + ": no tower plan")
		if plan.spec == null:
			continue
		_expect(res, plan.rooms.size() == spec.tower_storeys + 1,
			who + ": enclosed floors and the roof deck need %d rooms" % (spec.tower_storeys + 1))
		_expect(res, plan.doors.size() == 1, who + ": expected one exterior door")
		_expect(res, plan.stairs.size() == spec.tower_storeys,
			who + ": stair chain does not reach the roof platform")
		_check_storeys(res, who, spec, plan)
		_check_door(res, who, spec, plan)
		_check_windows(res, who, spec, plan)
		_check_stairs(res, who, plan)
		_check_jogs(res, who, spec, plan)
		_negative_aabb(res, who, spec, plan)
		_negative_opening(res, who, plan)
		_negative_landing(res, who, plan)
		_check_emitted_door(res, who, spec)
	_narrow_wizard_fixture(res)
	return res


## The exhaustive voxel fixture is a 9 x 9 x 42 wizard with no forced plan
## override. Keep its narrow-shaft door contract explicit in this fast suite.
static func _narrow_wizard_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"wizard"
	spec.width = 9.0
	spec.length = 9.0
	spec.height = 42.0
	spec.tier_override = &"house"
	CastleGenerator.generate(spec, 12012)
	var plan: HousePlan = TowerPlan.generate(spec, true)
	var who := "wizard 9x9x42 seed=12012"
	_expect(res, plan.spec != null, who + ": no narrow tower plan")
	if plan.spec == null:
		return
	_expect(res, TowerPlan.oval_sides(spec) == 12,
		who + ": narrow shaft did not select its wider entrance facet")
	_expect(res, plan.outline_of(0).size() == 12,
		who + ": plan outline disagrees with narrow emitted drum")
	_expect(res, not plan.doors.is_empty() \
		and float(plan.doors[0].get("width", 0.0)) >= HouseGeometry.DOOR_W,
		who + ": raised entrance is below the standard door width")
	_expect(res, plan.stairs.size() == plan.room_count() - 1,
		who + ": stair chain does not reach every upper level")
	_check_stairs(res, who, plan)
	var has_hearth := false
	for prop in plan.furniture:
		has_hearth = has_hearth or PropCatalog.category(String(prop["key"])) == "hearth"
	_expect(res, not has_hearth, who + ": unvented castle shaft received a house hearth prop")
	var qa := HouseQA.new().check(plan, null)
	_expect(res, qa.failures.is_empty(), who + ": house QA: " + str(qa.failures))
	var builder := CastleBuilder.new()
	builder.build(spec)
	var emitted := builder.part_log.filter(func(part: Dictionary) -> bool:
		return String(part.get("tag", "")) == "tower_house" \
			and String(part.get("opening_kind", "")) == "door")
	_expect(res, emitted.size() == 1, who + ": planned door did not emit one aperture")
	if emitted.size() == 1:
		_expect(res, float(emitted[0].get("size", Vector3.ZERO).x) >= HouseGeometry.DOOR_W,
			who + ": emitted door fell below the standard width")


static func _spec(row: Dictionary) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = row["style"]
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	spec.tier_override = &"house"
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, int(row["seed"]))
	spec.jog = row["jog"]
	CastleGenerator.refit(spec)
	return spec


static func _check_storeys(res: SuiteResult, who: String, spec: CastleSpec,
		plan: HousePlan) -> void:
	for level in range(plan.rooms.size()):
		var room: Dictionary = plan.rooms[level]
		var deck := level == spec.tower_storeys
		var actual: AABB = CastleGeometry.tower_platform_aabb(spec) if deck \
			else CastleGeometry.tower_storey_aabb(spec, level)
		var thickness := 0.3 if deck else CastleGeometry.tower_wall_thickness(spec, level)
		_expect(res, room.get("outer_aabb", AABB()) == actual,
			who + ": storey %d did not retain tower_storey_aabb" % level)
		_expect(res, is_equal_approx(float(room.get("wall_thickness", -1.0)), thickness),
			who + ": storey %d lost tapered wall thickness" % level)
		var outline: PackedVector2Array = room["outline"]
		_expect(res, outline.size() == (TowerPlan.oval_sides(spec) if spec.style == &"wizard" else 4),
			who + ": storey %d outline has %d facets" % [level, outline.size()])
		for point in outline:
			_expect(res, absf(point.x) <= actual.size.x * 0.5 + 0.01
				and absf(point.y) <= actual.size.z * 0.5 + 0.01,
				who + ": storey %d clear outline escapes outer footprint" % level)


static func _check_door(res: SuiteResult, who: String, spec: CastleSpec,
		plan: HousePlan) -> void:
	if plan.doors.is_empty():
		return
	var door: Dictionary = plan.doors[0]
	var sill := CastleGeometry.tower_door_sill(spec)
	var level := int(door["storey"])
	var expected_level := clampi(int(floor(sill / CastleGeometry.tower_storey_height(spec))),
		0, spec.tower_storeys - 1)
	_expect(res, level == expected_level, who + ": door is on storey %d, expected %d" % [level, expected_level])
	_expect(res, is_equal_approx(float(door["sill"]) + level * CastleGeometry.tower_storey_height(spec), sill),
		who + ": door sill is not tower_door_sill")
	_expect(res, Vector2(door["normal"]).dot(Vector2(0, -1)) > 0.98,
		who + ": door does not face the front")
	var outline: PackedVector2Array = plan.outline_of(level)
	_expect(res, _edge_distance(Vector2(door["pos"]), outline) < 0.03,
		who + ": raised door is not on the actual floor outline")
	var facet := false
	for wall in HouseGeometry.room_walls(plan, level):
		if (-Vector2(wall["normal"])).dot(Vector2(door["normal"])) > 0.999 \
				and _point_on_segment(Vector2(door["pos"]), Vector2(wall["from"]),
				Vector2(wall["to"])):
			facet = true
	_expect(res, facet, who + ": raised door normal is not its exact wall facet")
	_expect(res, float(door["sill"]) >= 2.0 - 0.001,
		who + ": door is not raised")
	if spec.style == &"wizard" and maxf(spec.width, spec.length) <= 10.0:
		_expect(res, float(door["width"]) >= HouseGeometry.DOOR_W - 0.001,
			who + ": narrow wizard entrance is below the human-width door standard")


static func _check_emitted_door(res: SuiteResult, who: String, spec: CastleSpec) -> void:
	if spec.style != &"wizard":
		return
	var builder := CastleBuilder.new()
	builder.build(spec)
	var doors: Array = builder.part_log.filter(func(part: Dictionary) -> bool:
		return String(part.get("tag", "")) == "tower_house" \
			and String(part.get("opening_kind", "")) == "door")
	_expect(res, doors.size() == 1,
		who + ": wizard planned door did not emit exactly one actual aperture")
	if TowerPlan.oval_sides(spec) == TowerPlan.NARROW_OVAL_SIDES and doors.size() == 1:
		_expect(res, float(doors[0].get("size", Vector3.ZERO).x) >= HouseGeometry.DOOR_W,
			who + ": emitted narrow-shaft door is below the human-width standard")


static func _check_windows(res: SuiteResult, who: String, spec: CastleSpec,
		plan: HousePlan) -> void:
	for win in plan.windows:
		var level := int(win["storey"])
		_expect(res, level > 0, who + ": window on blind foot storey")
		_expect(res, _edge_distance(Vector2(win["pos"]), plan.outline_of(level)) < 0.03,
			who + ": window is off its polygon wall surface")
		var outward := Vector2(win["normal"])
		_expect(res, outward.length() > 0.9, who + ": window has invalid normal")
		var walls := HouseGeometry.room_walls(plan, level)
		var found := false
		for wall in walls:
			var n := -Vector2(wall["normal"])
			if n.dot(outward) > 0.98 and _point_on_segment(Vector2(win["pos"]),
				Vector2(wall["from"]), Vector2(wall["to"])):
				found = true
		_expect(res, found, who + ": window normal does not agree with an actual wall edge")


static func _check_stairs(res: SuiteResult, who: String, plan: HousePlan) -> void:
	for stair in plan.stairs:
		var a := int(stair["a"])
		var b := int(stair["b"])
		_expect(res, b == a + 1, who + ": stair does not join adjacent floors")
		_expect(res, _rect_inside(stair["lower_rect"], plan.outline_of(a)),
			who + ": lower stair landing escapes room %d" % a)
		_expect(res, _rect_inside(stair["upper_rect"], plan.outline_of(b)),
			who + ": upper stair landing escapes room %d" % b)
	for i in range(plan.stairs.size() - 1):
		var upper := Rect2(plan.stairs[i]["upper_rect"])
		var next_lower := Rect2(plan.stairs[i + 1]["lower_rect"])
		_expect(res, not upper.intersects(next_lower, true),
			who + ": adjacent stair flights overlap at storey %d" % (i + 1))


static func _check_jogs(res: SuiteResult, who: String, spec: CastleSpec,
		plan: HousePlan) -> void:
	# The shaft's own plan no longer carries jog omissions: each jog is a
	# separate occupied block (CastleManorPlan.jog_records), checked here to
	# exist with the floors, door and windows a block of its size can hold.
	var count := CastleGeometry.tower_jog_aabbs(spec).size()
	_expect(res, plan.exterior_omissions.is_empty(),
		who + ": the shaft plan still lists jog omissions %s" % [plan.exterior_omissions])
	var rows: Dictionary = preload("res://src/castle/castle_manor_plan.gd").jog_records(spec)
	_expect(res, rows.size() == count,
		who + ": %d of %d jogs have an occupied plan" % [rows.size(), count])
	for index in range(count):
		var id := "wing_jog_%d" % index
		_expect(res, rows.has(id), who + ": no occupied plan for jog %d" % index)
		if not rows.has(id):
			continue
		var jog: HousePlan = rows[id].plan
		_expect(res, jog.entrance() >= 0, who + ": jog %d has no way in" % index)
		var report := HouseQA.new().check(jog, null)
		_expect(res, report.ok, who + ": jog %d plan: %s" % [index, report.failures])


## A rectangular/AABB substitution is not an acceptable tower floor.  The
## tapered storeys must each retain their own expected clear footprint.
static func _negative_aabb(res: SuiteResult, who: String, spec: CastleSpec,
		plan: HousePlan) -> void:
	if plan.rooms.size() < 2:
		return
	# Rectangular tower interiors legitimately have rectangular clear outlines;
	# the applicable negative fixture is the wizard oval, whose AABB corners are
	# outside the shell.
	if spec.style != &"wizard":
		return
	var bad := plan.rooms[0]["outline"] as PackedVector2Array
	var top := plan.rooms[spec.tower_storeys - 1]["outline"] as PackedVector2Array
	var differs := _bounds(bad) != _bounds(top)
	# The oval negative is the AABB's corner, which lies outside the shell.
	var box := _bounds(top)
	differs = not Poly.contains_point(top, box.position, 0.001)
	_expect(res, differs, who + ": AABB substitution was not rejected")


static func _negative_opening(res: SuiteResult, who: String, plan: HousePlan) -> void:
	if plan.windows.is_empty():
		return
	var moved := Vector2(plan.windows[0]["pos"]) + Vector2(0.7, 0.7)
	_expect(res, _edge_distance(moved, plan.outline_of(int(plan.windows[0]["storey"]))) >= 0.03,
		who + ": off-surface opening negative control did not fail")


static func _negative_landing(res: SuiteResult, who: String, plan: HousePlan) -> void:
	if plan.stairs.is_empty():
		return
	var stair: Dictionary = plan.stairs[0]
	var bad: Rect2 = Rect2(stair["lower_rect"])
	bad.position += Vector2(100, 100)
	_expect(res, not _rect_inside(bad, plan.outline_of(int(stair["a"]))),
		who + ": invalid landing negative control did not fail")


static func _rect_inside(rect: Rect2, outline: PackedVector2Array) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(outline, point, 0.02):
			return false
	return true


static func _edge_distance(point: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in range(outline.size()):
		best = minf(best, _segment_distance(point, outline[i], outline[(i + 1) % outline.size()]))
	return best


static func _point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return _segment_distance(point, a, b) < 0.03


static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var d := b - a
	var t := clampf((point - a).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + d * t)


static func _bounds(poly: PackedVector2Array) -> Rect2:
	return Poly.bounding_rect(poly)


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
