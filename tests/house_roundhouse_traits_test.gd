extends SceneTree
## HS-ROUNDHOUSE: the `roundhouse` style (formerly `mud_hut`), measured from the
## plan, mass_log and component_log (HouseTraitMeasure) on the style's three
## frozen requests (tests/fixtures/family_style_requests.json, house/roundhouse/*,
## the style's 8 x 10 m default), each trait with a negative control that removes
## it and must be noticed.
##   (1) ONE ROUND ROOM, THICK WALLS: a single room whose outline is a regular
##       polygon, a ring of wall masses all one distance from the middle, and a
##       door reveal at least 0.35 m deep
##   (2) A CONICAL THATCH ROOF with a vent at the apex: twelve facets from an
##       even eave to a point, thatch, a hole cut at the apex with a collar round
##       it and a hat over it that leaves a gap for the smoke
##   (3) A CENTRAL HEARTH: a kerb of stones on the middle of the floor under the
##       vent, no fireplace in a wall and no chimney; and a bed at the wall
##   (4) THE NAME: the published style is `roundhouse`; `mud_hut` is an alias that
##       builds the very same house, through the spec and through the public API
## The round room also has to pass the house harness (plan, furnishing, walking).
##   godot --headless --path . --script res://tests/house_roundhouse_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const REVEAL_MIN := 0.35
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/roundhouse requests, found %d" % cases.size())
	var seeds: Array[int] = []
	for c in cases:
		seeds.append(int(c["request"]["seed"]))
		_check_case(c)
	seeds.sort()
	_expect(seeds == [1, 8102, 21325], "the frozen seeds are 1, 8102 and 21325 (%s)" % [seeds])
	_check_identity()
	for f in failures:
		printerr("FAIL " + f)
	print("HS-ROUNDHOUSE: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/roundhouse/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary, style: StringName = &"") -> HouseSpec:
	return HouseTraitMeasure.make_spec(style if style != &"" else StringName(req["style"]),
		float(req["width"]), float(req["length"]), float(req["height"]), int(req["storeys"]))


## furnished, because the bed is part of the plan
func _measure(req: Dictionary, sd: int, tweak := Callable()) -> Dictionary:
	return HouseTraitMeasure.measure(_spec_of(req), sd, tweak, true)


func _check_identity() -> void:
	_expect(HouseSpec.STYLES.has(&"roundhouse"), "the published style key is `roundhouse`")
	_expect(not HouseSpec.STYLES.has(&"mud_hut"), "`mud_hut` is no longer a style row of its own")
	_expect(str(HouseSpec.STYLES[&"roundhouse"]["label"]) == "Roundhouse",
		"the label is Roundhouse (%s)" % HouseSpec.STYLES[&"roundhouse"]["label"])
	_expect(HouseSpec.canonical_style(&"mud_hut") == &"roundhouse", "mud_hut resolves to roundhouse")
	_expect(HouseSpec.canonical_style(&"cottage") == &"cottage", "any other style resolves to itself")
	var ids: Array = []
	for row in BuildingLibrary.options(&"house", &"style"):
		ids.append(row["id"])
	_expect(ids.has(&"roundhouse") and not ids.has(&"mud_hut"),
		"the published house styles list roundhouse, not mud_hut")
	var old := BuildingRequest.house(8102, &"mud_hut")
	var errors := BuildingLibrary.validate(old)
	_expect(errors.is_empty(), "a saved request that says mud_hut still validates (%s)" % [errors])
	_expect(BuildingLibrary.validate(BuildingRequest.house(8102, &"no_such_hut")).size() > 0,
		"control: an unknown style is still refused")
	# the same house, vertex for vertex, through the public path
	var a := BrickWild.generate(BuildingRequest.house(8102, &"mud_hut"))
	var b := BrickWild.generate(BuildingRequest.house(8102, &"roundhouse"))
	_expect(a.is_ok() and b.is_ok(), "both spellings generate")
	if a.is_ok() and b.is_ok():
		_expect(a.spec.style == &"roundhouse" and b.spec.style == &"roundhouse",
			"the alias is resolved to roundhouse (%s, %s)" % [a.spec.style, b.spec.style])
		_expect(_digest(BrickWild.build_mesh(a)) == _digest(BrickWild.build_mesh(b)),
			"mud_hut and roundhouse build the same mesh")
		_expect(str(a.plan.rooms) == str(b.plan.rooms) and str(a.plan.furniture) == str(b.plan.furniture),
			"mud_hut and roundhouse plan the same rooms and furniture")
	var control := BrickWild.generate(BuildingRequest.house(8102, &"cottage"))
	if control.is_ok() and a.is_ok():
		_expect(_digest(BrickWild.build_mesh(control)) != _digest(BrickWild.build_mesh(a)),
			"control: a cottage is not the same mesh")


static func _digest(mesh: ArrayMesh) -> int:
	var h := 17
	for s in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		h = (h * 31 + v.size()) & 0x7fffffff
		for p in v:
			h = (h * 31 + int(roundf(p.x * 1000.0)) * 7 + int(roundf(p.y * 1000.0)) * 13
				+ int(roundf(p.z * 1000.0)) * 17) & 0x7fffffff
	return h


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var sd := int(req["seed"])
	var id := str(c["id"])
	var m := _measure(req, sd)
	# (1) one round room, thick walls
	_expect(m["round_hut"], "%s is a round hut" % id)
	_expect(m["round_rooms"] == 1, "%s has ONE room (%d)" % [id, m["round_rooms"]])
	_expect(m["round_sides"] >= 12 and m["round_ratio"] >= 0.99,
		"%s room is a regular polygon of %d sides, ratio %.3f" % [id, m["round_sides"], m["round_ratio"]])
	_expect(m["round_wall_runs"] >= 12 and m["round_wall_ratio"] >= 0.95,
		"%s wall ring: %d masses, evenness %.3f" % [id, m["round_wall_runs"], m["round_wall_ratio"]])
	_expect(m["door_count"] == 1, "%s has one door (%d)" % [id, m["door_count"]])
	_expect(m["door_reveal"] >= REVEAL_MIN, "%s door reveal is %.2f m deep" % [id, m["door_reveal"]])
	# (2) the cone and its vent
	_expect(m["cone_thatch"], "%s roof is thatch" % id)
	_expect(m["cone_faces"] == RoofShape.ROUND_CONE_SIDES, "%s roof is %d facets (%d)" % [id, RoofShape.ROUND_CONE_SIDES, m["cone_faces"]])
	_expect(m["cone_eave_ratio"] >= 0.97, "%s eave is an even ring (%.3f)" % [id, m["cone_eave_ratio"]])
	_expect(m["cone_apex_off"] <= HouseRound.VENT_R + 0.1, "%s roof comes to a point over the middle (%.2f m off)" % [id, m["cone_apex_off"]])
	_expect(m["cone_pitch_deg"] >= 35.0 and m["cone_pitch_deg"] <= 70.0, "%s cone pitch is %.0f degrees" % [id, m["cone_pitch_deg"]])
	_expect(m["vent_cut"], "%s has a vent cut in the roof" % id)
	_expect(m["vent_off"] <= 0.05 and m["vent_high"], "%s vent is at the apex (%.2f m off the middle)" % [id, m["vent_off"]])
	_expect(m["vent_area"] >= 0.3, "%s vent is %.2f m2" % [id, m["vent_area"]])
	_expect(m["vent_collar"] >= 6 and m["vent_collar_ring"] >= 0.95, "%s vent has a collar of %d bundles, evenness %.3f" % [id, m["vent_collar"], m["vent_collar_ring"]])
	_expect(m["vent_hat"] >= 6 and m["vent_hat_clear"], "%s vent has a hat (%d facets) that leaves a gap" % [id, m["vent_hat"]])
	# (3) the central hearth, and a bed at the wall
	_expect(m["hearth_kerb"] == 4, "%s fire has a kerb of 4 stones (%d)" % [id, m["hearth_kerb"]])
	_expect(m["hearth_dist"] <= 0.15, "%s fire is %.2f m from the middle of the floor" % [id, m["hearth_dist"]])
	_expect(m["hearth_under_vent"], "%s fire is under the vent" % id)
	_expect(not m["wall_hearth"] and not m["chimney_stack"], "%s has no wall fireplace and no chimney" % id)
	_expect(m["bed_count"] >= 1 and m["bed_at_wall"], "%s has a bed %.2f m from the wall (%d)" % [id, m["bed_gap"], m["bed_count"]])
	_expect(m["bed_clear_of_fire"], "%s bed is clear of the fire" % id)

	# Negative controls: each removal must be seen by the same measure.
	var no_outline := func(plan: HousePlan) -> void:
		plan.rooms[0].erase("outline")
	var mo := _measure(req, sd, no_outline)
	_expect(mo["round_sides"] == 0 and mo["round_ratio"] == 0.0 and mo["round_wall_runs"] <= 4,
		"%s control: a room with no outline is noticed (%d sides, %d wall masses)" % [id, mo["round_sides"], mo["round_wall_runs"]])
	_expect(mo["round_wall_runs"] == 4,
		"%s control: a square shell is four wall masses, not a ring (%d)" % [id, mo["round_wall_runs"]])
	var two_rooms := func(plan: HousePlan) -> void:
		var second: Dictionary = plan.rooms[0].duplicate(true)
		second["kind"] = &"store"
		plan.rooms.append(second)
	_expect(_measure(req, sd, two_rooms)["round_rooms"] == 2, "%s control: a second room is noticed" % id)
	var thin := func(plan: HousePlan) -> void:
		plan.spec.wall_thickness_override = 0.2
		plan.rooms[0]["wall_thickness"] = 0.2
	var mt := _measure(req, sd, thin)
	_expect(mt["door_reveal"] < REVEAL_MIN, "%s control: a thin wall has a shallow reveal (%.2f m)" % [id, mt["door_reveal"]])
	var gable := func(plan: HousePlan) -> void:
		plan.spec.roof_type = &"gable"
	var mg := _measure(req, sd, gable)
	_expect(mg["cone_faces"] != RoofShape.ROUND_CONE_SIDES, "%s control: a gable roof is not a cone (%d faces)" % [id, mg["cone_faces"]])
	var shingle := func(plan: HousePlan) -> void:
		plan.spec.roof_material = &"shingle"
	_expect(not _measure(req, sd, shingle)["cone_thatch"], "%s control: a shingle roof is not thatch" % id)
	var no_vent := func(plan: HousePlan) -> void:
		plan.roundhouse["vent"] = false
	var mv := _measure(req, sd, no_vent)
	_expect(not mv["vent_cut"] and mv["vent_collar"] == 0 and mv["vent_hat"] == 0 and not mv["vent_hat_clear"],
		"%s control: no vent, no collar, no hat" % id)
	_expect(mv["cone_faces"] == RoofShape.ROUND_CONE_SIDES and mv["hearth_kerb"] == 4,
		"%s control: the vent removed takes nothing else" % id)
	var kerb_at_wall := func(plan: HousePlan) -> void:
		plan.roundhouse["hearth"] = Rect2(Vector2(2.0, -0.6), Vector2(1.2, 1.2))
	var mk := _measure(req, sd, kerb_at_wall)
	_expect(mk["hearth_dist"] > 1.5 and not mk["hearth_under_vent"], "%s control: a fire by the wall is not central (%.2f m)" % [id, mk["hearth_dist"]])
	var no_kerb := func(plan: HousePlan) -> void:
		plan.roundhouse.erase("hearth")
	_expect(_measure(req, sd, no_kerb)["hearth_kerb"] == 0, "%s control: no hearth, no kerb" % id)
	var fireplace := func(plan: HousePlan) -> void:
		plan.hearth = {"room": 0, "wall": 1}
	_expect(_measure(req, sd, fireplace)["wall_hearth"], "%s control: a wall hearth is noticed" % id)
	var no_bed := func(plan: HousePlan) -> void:
		for i in range(plan.furniture.size() - 1, -1, -1):
			if str(plan.furniture[i].get("cat", "")) == "bed":
				plan.furniture.remove_at(i)
	var mn := _measure(req, sd, no_bed)
	_expect(mn["bed_count"] == 0 and not mn["bed_at_wall"], "%s control: no bed is noticed" % id)
	var bed_adrift := func(plan: HousePlan) -> void:
		for f in plan.furniture:
			if str(f.get("cat", "")) == "bed":
				f["rect"] = Rect2(Vector2(-0.9, -1.2), Rect2(f["rect"]).size)
	var ma := _measure(req, sd, bed_adrift)
	_expect(not ma["bed_at_wall"] and ma["bed_gap"] > 0.15, "%s control: a bed in the middle of the floor is not at the wall (%.2f m)" % [id, ma["bed_gap"]])
	# a cottage is none of this (the measure does not read it onto another style)
	var cottage := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"cottage",
		float(req["width"]), float(req["length"]), float(req["height"]), 1), sd, Callable(), true)
	_expect(not cottage["round_hut"] and cottage["round_sides"] == 0 and cottage["vent_cut"] == false
		and cottage["hearth_kerb"] == 0, "%s control: a cottage is not a round hut" % id)

	# the house harness reads a round room correctly: plan, furnishing, walking, shell
	_check_harness(id, req, sd)


func _check_harness(id: String, req: Dictionary, sd: int) -> void:
	var plan := HouseGenerator.generate(_spec_of(req), sd, true)
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var report: Dictionary = HouseQA.new().check(plan, builder)
	_expect(report["ok"], "%s passes the house harness (%s)" % [id, report["failures"]])
	var nav := HouseNavCheck.new()
	var res: Dictionary = nav.check(plan)
	_expect(res["failures"].is_empty(), "%s nav check passes (%s)" % [id, res["failures"]])
	# the walk grid is the circle, not the square round it
	var floor_area := HouseGeometry.room_area(plan, 0)
	var square := HouseGeometry.room_floor_rect(plan, 0)
	_expect(floor_area < square.size.x * square.size.y * 0.9,
		"%s floor is %.1f m2, a disc and not its %.1f m2 box" % [id, floor_area, square.size.x * square.size.y])
	var walkable := float(res["stats"].get("walkable_area", res["stats"].get("walkable_m2", -1.0)))
	if walkable >= 0.0:
		_expect(walkable < floor_area and walkable > floor_area * 0.35,
			"%s walkable floor %.1f m2 lies inside the %.1f m2 room" % [id, walkable, floor_area])
	# every piece of furniture stands inside the round room
	var inside := true
	for f in plan.furniture:
		if bool(f.get("mounted", false)) or int(f.get("host", -1)) >= 0:
			continue
		if not HouseFurnishGeometry.inside_candidate(plan, 0, f):
			inside = false
	_expect(inside, "%s every floor piece stands inside the outline" % id)
	# the plinth and its moulding stand proud of the wall; each ring run is carried
	# past its ends for THAT thickness, so the outer faces meet at every facet joint
	# (a carry set for the wall alone leaves a step of 4 mm to 1 cm)
	var steps_ok := true
	var worst := 0.0
	var thick_wall := HouseGeometry.wall_thickness(plan.spec)
	for run in HouseGeometry.shell_runs(plan, 0):
		for proud in [HouseGeometry.PLINTH_EXTRA * 2.0, HouseGeometry.PLINTH_EXTRA * 2.0 + 0.04]:
			var tp: float = thick_wall + proud
			# the carry that makes the OUTER face meet the next run's grows with the
			# thickness: carry(tp) / carry(wall) = tp / wall
			var want := float(run.get("ext", 0.0)) * tp / thick_wall
			var miss := absf(HouseBuilder._corner_ext(run, tp) - want)
			worst = maxf(worst, miss)
			steps_ok = steps_ok and miss < 0.0001
	_expect(steps_ok, "%s plinth courses meet at every facet joint (worst miss %.4f m)" % [id, worst])
	# the nav check does see an obstruction: a table across the door shuts the room
	var blocked := HouseGenerator.generate(_spec_of(req), sd, true)
	var door: Dictionary = blocked.doors[0]
	var across := {"key": "Table_Large", "cat": "table", "room": 0, "storey": 0, "mounted": false, "host": -1,
		"rect": Rect2(Vector2(door["pos"]) + Vector2(-2.0, 0.0), Vector2(4.0, 1.2)),
		"pos": Vector3(float(door["pos"].x), 0.12, float(door["pos"].y) + 0.6), "yaw": 0.0, "scale": 1.0}
	blocked.furniture.append(across)
	var shut: Dictionary = HouseNavCheck.new().check(blocked)
	_expect(not shut["failures"].is_empty() or not shut["warnings"].is_empty(),
		"%s control: a table across the door is noticed by the nav check" % id)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
