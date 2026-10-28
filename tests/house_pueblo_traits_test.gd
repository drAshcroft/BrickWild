extends SceneTree
## HS-PUEBLO: the `pueblo` style as a stepped adobe house, measured from the plan,
## mass_log and component_log (HouseTraitMeasure) on the style's three frozen
## requests (tests/fixtures/family_style_requests.json, house/pueblo/*: 8 x 10 m,
## three storeys), each trait with a negative control that removes it and must be
## noticed.
##   (1) stepped levels: each upper storey is set back from the one below, its rooms
##       inside the clear floor below and smaller
##   (2) a ladder reaches every terrace, the terraces are walkable in the nav check
##       and the upper rooms are reached by them
##   (3) vigas project from every wall, under the roof or terrace they carry
##   (4) small doors and windows in the thick adobe wall; flat earth roofs behind
##       parapets
##   (5) a footprint too small to step is not stepped, and a house with a trade is left
##       to the ordinary planner
##   godot --headless --path . --script res://tests/house_pueblo_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const Exporter = preload("res://tools/export_building_plan.gd")
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/pueblo requests, found %d" % cases.size())
	var seeds: Array[int] = []
	for c in cases:
		seeds.append(int(c["request"]["seed"]))
		_check_case(c)
	seeds.sort()
	_expect(seeds == [1, 8102, 21325], "the frozen seeds are 1, 8102 and 21325 (%s)" % [seeds])
	_check_scope()
	_check_public(cases[1])
	for f in failures:
		printerr("FAIL " + f)
	print("HS-PUEBLO: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/pueblo/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]))


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var sd := int(req["seed"])
	var id := str(c["id"])
	_expect(int(req["storeys"]) == 3 and float(req["width"]) == 8.0 and float(req["length"]) == 10.0,
		"%s is the default size, three storeys" % id)
	var m := HouseTraitMeasure.measure(_spec_of(req), sd)
	_expect(m["pueblo"] and m["storeys"] == 3, "%s is a stepped pueblo of three storeys (%d)" % [id, m["storeys"]])
	# (1) stepped levels
	_expect(m["tier_count"] == 3, "%s has three storeys of wall (%d)" % [id, m["tier_count"]])
	_expect(m["tier_inside"], "%s: each storey stands inside the one below" % id)
	_expect(m["tier_front_step"] >= 2.0, "%s: each front stands back %.2f m from the one below" % [id, m["tier_front_step"]])
	_expect(m["tier_side_step"] >= 1.0, "%s: each storey is drawn in %.2f m on a side" % [id, m["tier_side_step"]])
	_expect(m["tier_area_ratio"] <= 0.8, "%s: each storey is %.0f%% of the one below" % [id, m["tier_area_ratio"] * 100.0])
	_expect(m["tier_set_back"], "%s is set back storey by storey" % id)
	_expect(m["upper_rooms"] == 2 and m["upper_rooms_set_back"], "%s: two upper rooms, inside and smaller than the floor below (%d)" % [id, m["upper_rooms"]])
	# (2) ladders and walkable roofs
	_expect(m["terrace_levels"] == 3, "%s has a terrace on three roofs (%d)" % [id, m["terrace_levels"]])
	_expect(m["ladder_count"] == 3 and m["ladders_reach_all"], "%s: a ladder reaches each of the three terraces (%d)" % [id, m["ladder_count"]])
	_expect(m["ladder_climbable"], "%s: every ladder has six rungs or more, a third of a metre apart or less" % id)
	_expect(m["ladder_on_wall"] and m["ladder_clear"], "%s: each ladder leans on its wall and stands across no opening" % id)
	_expect(m["ladder_head_open"], "%s: the parapet is open at the head of each ladder" % id)
	_expect(m["terraces_decked"], "%s: earth under every terrace" % id)
	_expect(m["nav_ok"], "%s: the nav check passes" % id)
	_expect(m["terraces_walkable"], "%s: every terrace is walked (%.0f%% of its floor)" % [id, m["terrace_walk_share"] * 100.0])
	_expect(m["upper_rooms_reached"] and m["terrace_doors"] == 2, "%s: both upper rooms are reached, each by a door onto its terrace (%d)" % [id, m["terrace_doors"]])
	# (3) vigas
	_expect(m["viga_count"] >= 40, "%s has vigas (%d)" % [id, m["viga_count"]])
	_expect(m["viga_tiers"] == 3, "%s: vigas on all three storeys (%d)" % [id, m["viga_tiers"]])
	_expect(m["viga_walls"] >= 12, "%s: vigas on %d of 12 walls" % [id, m["viga_walls"]])
	_expect(m["viga_reach"] >= 0.45, "%s: vigas project %.2f m" % [id, m["viga_reach"]])
	_expect(m["viga_section"] >= 0.12 and m["viga_section"] <= 0.25, "%s: a viga is %.2f m across" % [id, m["viga_section"]])
	_expect(m["viga_wood"] and m["viga_inside"], "%s: vigas are wood and run into the wall" % id)
	_expect(m["viga_clear"], "%s: no viga crosses an opening or a ladder" % id)
	_expect(m["viga_below"] >= 0.3, "%s: vigas stand %.2f m under the roof surface and its parapet" % [id, m["viga_below"]])
	_expect(m["viga_gap_min"] >= 0.8 and m["viga_gap_max"] <= 3.1, "%s: vigas %.2f to %.2f m apart" % [id, m["viga_gap_min"], m["viga_gap_max"]])
	# (4) small deep openings, flat parapeted roofs
	_expect(m["small_openings"], "%s: small openings" % id)
	_expect(m["door_w_max"] <= 0.85 and m["door_h_max"] <= 1.85, "%s: doors %.2f m wide, %.2f m high at most" % [id, m["door_w_max"], m["door_h_max"]])
	_expect(m["win_area_max"] <= 0.5 and m["win_sill_min"] >= 1.0, "%s: windows %.2f m2 at most, sills %.2f m and up" % [id, m["win_area_max"], m["win_sill_min"]])
	_expect(m["opening_share"] <= 0.08, "%s: openings are %.1f%% of the wall" % [id, m["opening_share"] * 100.0])
	_expect(m["wall_thick"] >= 0.6 and m["reveal_min"] >= 0.6, "%s: walls %.2f m thick, reveals %.2f m deep" % [id, m["wall_thick"], m["reveal_min"]])
	_expect(m["banco_walls"], "%s: walls are unrendered adobe" % id)
	_expect(m["roof_flat"] and m["roof_earth"], "%s: the roof is level earth (%.1f degrees)" % [id, m["roof_angle_deg"]])
	_expect(m["parapet_each_terrace"] and m["parapet_h"] >= 0.5, "%s: a parapet %.2f m high on every terrace" % [id, m["parapet_h"]])

	# Negative controls: each removal must be seen by the same measure.
	var flat := func(plan: HousePlan) -> void:
		plan.spec.terraced = false
	var mf := HouseTraitMeasure.measure(_spec_of(req), sd, flat)
	_expect(not mf["tier_set_back"] and mf["tier_front_step"] < 0.5,
		"%s control: upper walls on the whole footprint are not set back (%.2f m)" % [id, mf["tier_front_step"]])
	var no_ladder_mesh := func(plan: HousePlan) -> void:
		plan.spec.pueblo_skip = PackedStringArray(["ladder"])
	var ml := HouseTraitMeasure.measure(_spec_of(req), sd, no_ladder_mesh)
	_expect(ml["ladder_count"] == 0 and not ml["ladders_reach_all"] and ml["viga_count"] > 0 and ml["tier_set_back"],
		"%s control: ladders left out of the mesh are noticed, nothing else" % id)
	var no_ladder_plan := func(plan: HousePlan) -> void:
		plan.ladders.clear()
	var mp := HouseTraitMeasure.measure(_spec_of(req), sd, no_ladder_plan)
	_expect(not mp["nav_ok"] and not mp["upper_rooms_reached"] and not mp["terraces_walkable"],
		"%s control: with no ladder the terraces and the rooms on them are not reached" % id)
	var no_gap := func(plan: HousePlan) -> void:
		plan.spec.pueblo_skip = PackedStringArray(["gap"])
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, no_gap)["ladder_head_open"],
		"%s control: a parapet across the head of a ladder is noticed" % id)
	var no_deck := func(plan: HousePlan) -> void:
		plan.spec.pueblo_skip = PackedStringArray(["terrace"])
	var md := HouseTraitMeasure.measure(_spec_of(req), sd, no_deck)
	_expect(not md["terraces_decked"] and not md["parapet_each_terrace"],
		"%s control: terraces with no deck and no parapet are noticed" % id)
	var no_viga := func(plan: HousePlan) -> void:
		plan.spec.pueblo_skip = PackedStringArray(["viga"])
	var mv := HouseTraitMeasure.measure(_spec_of(req), sd, no_viga)
	_expect(mv["viga_count"] == 0 and mv["viga_tiers"] == 0 and not mv["viga_wood"] and mv["ladder_count"] == 3,
		"%s control: vigas removed, nothing else" % id)
	var no_parapet := func(plan: HousePlan) -> void:
		plan.spec.pueblo_skip = PackedStringArray(["parapet"])
	var mq := HouseTraitMeasure.measure(_spec_of(req), sd, no_parapet)
	_expect(not mq["parapet_each_terrace"] and mq["parapet_h"] == 0.0 and mq["terraces_decked"],
		"%s control: parapets removed, nothing else" % id)
	var ordinary := func(plan: HousePlan) -> void:
		for w in plan.windows:
			w["width"] = 0.95
			w["sill"] = 0.95
			w["head"] = 2.0
		for d in plan.doors:
			d["width"] = 0.95
			d["head"] = 2.22
	var mo := HouseTraitMeasure.measure(_spec_of(req), sd, ordinary)
	_expect(not mo["small_openings"] and mo["win_area_max"] > 0.5 and mo["door_h_max"] > 2.0,
		"%s control: ordinary-sized openings are noticed (window %.2f m2, door %.2f m)" % [id, mo["win_area_max"], mo["door_h_max"]])
	var gable := func(plan: HousePlan) -> void:
		plan.spec.roof_type = &"gable"
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, gable)["roof_flat"],
		"%s control: a gable roof is not flat" % id)
	var thin := func(plan: HousePlan) -> void:
		plan.spec.wall_thickness_override = 0.2
	var mt := HouseTraitMeasure.measure(_spec_of(req), sd, thin)
	_expect(mt["wall_thick"] < 0.6, "%s control: a thin wall is noticed (%.2f m)" % [id, mt["wall_thick"]])
	# a Mediterranean house of the same size is none of this
	var med := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"mediterranean",
		float(req["width"]), float(req["length"]), float(req["height"]), 3), sd)
	_expect(not med.get("pueblo", false) and not med.get("tier_set_back", false) and int(med.get("viga_count", 0)) == 0,
		"%s control: a mediterranean house is not stepped and has no vigas" % id)


## What stays as it was: a footprint too small to step, and a pueblo with a trade.
func _check_scope() -> void:
	# two storeys asked, two storeys given; one asked, two given; three asked on a footprint that
	# will carry three
	for pair in [[1, 2], [2, 2], [3, 3]]:
		var m := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"pueblo", 8.0, 10.0, 2.6, int(pair[0])), 8102)
		_expect(m["storeys"] == int(pair[1]) and m["tier_set_back"] and m["nav_ok"] and m["ladders_reach_all"],
			"storeys %d asked: %d given, set back, walkable, laddered (%d)" % [int(pair[0]), int(pair[1]), m["storeys"]])
	# a large footprint cuts each upper storey into several rooms, each reached through the
	# one the terrace opens into, and still walks
	var big := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"pueblo", 15.2, 19.0, 2.6, 3), 8102)
	_expect(big["storeys"] == 3 and big["upper_rooms"] >= 6 and big["upper_rooms_set_back"] and big["upper_rooms_reached"]
			and big["nav_ok"] and big["tier_set_back"] and big["ladders_reach_all"] and big["terraces_walkable"],
		"a 15.2 x 19 m pueblo: three storeys, %d upper rooms, all reached, set back, laddered and walkable" % big["upper_rooms"])
	# a footprint that cannot step three times is given two
	var narrow := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"pueblo", 7.0, 8.0, 2.6, 3), 8102)
	_expect(narrow["storeys"] == 2 and narrow["tier_set_back"] and narrow["nav_ok"],
		"a 7 x 8 m pueblo asked for three storeys is given two (%d)" % narrow["storeys"])
	# a footprint that cannot step at all is a plain one-storey pueblo, still with small openings
	var tiny := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"pueblo", 5.0, 6.0, 2.6, 2), 8102)
	_expect(not tiny["tier_set_back"] and tiny["storeys"] <= 2 and tiny["ladder_count"] == 0 and tiny["small_openings"] and tiny["roof_flat"],
		"a 5 x 6 m pueblo is not stepped (%d storeys), but has small openings and a flat roof" % tiny["storeys"])
	# a trade house is the ordinary planner's
	var smith_spec := HouseTraitMeasure.make_spec(&"pueblo", 8.0, 10.0, 2.6, 2)
	smith_spec.trade = &"smith"
	var smith := HouseTraitMeasure.measure(smith_spec, 8102)
	_expect(not smith["pueblo"] and smith["ladder_count"] == 0,
		"a smith's pueblo is not stepped and has no ladders")
	# ...but it is still a pueblo: beam ends the size of a beam stand out of its walls,
	# so it is not read as the Sahel's house (HS-PUEBLO-RESIDUE)
	_expect(smith["viga_count"] >= 12 and smith["viga_section"] >= 0.12 and smith["viga_walls"] >= 4,
		"a smith's pueblo has vigas (%d, %.2f m across, on %d walls)" % [smith["viga_count"], smith["viga_section"], smith["viga_walls"]])
	var smith_sahel_spec := HouseTraitMeasure.make_spec(&"african", 8.0, 10.0, 2.6, 2)
	smith_sahel_spec.trade = &"smith"
	_expect(HouseTraitMeasure.measure(smith_sahel_spec, 8102)["viga_count"] == 0,
		"control: a smith's Sahel house has no vigas")
	# the key and the label stay
	_expect(HouseSpec.STYLES.has(&"pueblo") and str(HouseSpec.STYLES[&"pueblo"]["label"]) == "Pueblo Adobe House",
		"the style key stays `pueblo`, the label `Pueblo Adobe House`")


## The published paths: the walk (a ladder is a link), the plan export (a ladder is a way
## up) and the footprint (the ground storey's, not the top storey's).
func _check_public(c: Dictionary) -> void:
	var id := str(c["id"])
	var req := BuildingRequest.from_dict(c["request"])
	var building: GeneratedBuilding = BrickWild.generate(req)
	_expect(building.is_ok() and building.plan != null, "%s generates through the public path" % id)
	if not building.is_ok():
		return
	var nav: Dictionary = BrickWild.navigation(building)
	var links: Array = (nav["stairs"] as Array).filter(func(s: Dictionary) -> bool: return bool(s.get("ladder", false)))
	_expect(nav["supported"] and nav["storeys"].size() == 4 and links.size() == 3,
		"%s: the published walk has 4 storeys (three rooms and the top roof) and 3 ladder links (%d, %d)" % [id, nav["storeys"].size(), links.size()])
	var linked := true
	for l in links:
		linked = linked and bool(l["linked"]) and int(l["to_storey"]) == int(l["from_storey"]) + 1
	_expect(linked, "%s: every ladder link joins two adjacent storeys, both ends on the mesh" % id)
	var foot: Rect2 = BuildingFamilyAdapter.for_building(building).footprint(building)
	var ground := HouseGeometry.interior_rect(building.plan.spec)
	_expect(foot.is_equal_approx(ground), "%s: the footprint is the ground storey's (%s)" % [id, foot])
	var rect := HouseGeometry.site_rect(building.plan.spec)
	var record := {"building_id": "site:pueblo/b-000", "kind": "house", "request": req.to_dict(),
		"rect_m": Exporter._rect(rect),
		"transform": {"origin": [0, 0, 0], "basis": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}
	var site := {"schema": "dmv.site.plan", "schema_version": 1, "buildings": [record]}
	var out: Dictionary = Exporter.building_plan(site, "site:pueblo/b-000")
	_expect(not out.has("errors"), "%s: the plan exports with every room reached from outside (%s)" % [id, str(out.get("errors", []))])
	if not out.has("errors"):
		var ladders: Array = (out["stairs"] as Array).filter(func(s: Dictionary) -> bool: return s.get("kind", "") == "ladder")
		_expect(ladders.size() == 2, "%s: two ladders are exported as the ways up to the two upper rooms (%d)" % [id, ladders.size()])


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
