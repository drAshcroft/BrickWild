class_name WorldArchetypeSuite
extends RefCounted
## The buildings of the wider world this generator is expected to build
## (WLD-000; WORLD_BUILDINGS 5), in the manner of the house archetype suite:
## each row is built at 70/100/140/190 % of its footprint, put through its
## own family check and through MassRules, and asked to CONTAIN what makes it
## that building -- by name, never by position.
##
## A row: {"key", "family", "kind", "width", "length", "height", "must":
## [StringName], "check": StringName (the check class), "about": String}.
## Every WLD family task adds its rows here and is green here.

const SCALES: Array[float] = [0.7, 1.0, 1.4, 1.9]
const TowerGenerator = preload("res://src/world/world_tower_house_generator.gd")
const PagodaGenerator = preload("res://src/world/pagoda_generator.gd")

const ARCHETYPES: Array[Dictionary] = [
	{"key": "hall_thousand_pillars", "family": &"mosque", "kind": &"hypostyle",
		"width": 90.0, "length": 60.0, "height": 12.0,
		"must": ["qibla_wall", "mihrab", "column", "sahn_floor", "minaret"],
		"check": &"qibla_check", "about": "Hall of a Thousand Pillars"},
	{"key": "temple_four_winds", "family": &"cruciform_temple", "kind": &"temple_of_four_winds",
		"width": 90.0, "length": 90.0, "height": 50.0,
		"must": ["hall_floor", "outer_ring", "inner_ring", "image", "sikhara"],
		"check": &"cruciform_check", "about": "four cardinal Buddhas and linked rings"},
	{"key": "great_hall_east", "family": &"timber_hall", "kind": &"great_hall",
		"width": 34.0, "length": 18.0, "height": 20.0,
		"must": ["platform", "column", "dais", "image", "roof"],
		"check": &"hall_check", "about": "seven-bay East hall"},
	{"key": "phoenix_pavilion", "family": &"timber_hall", "kind": &"phoenix_pavilion",
		"width": 60.0, "length": 12.0, "height": 14.0,
		"must": ["platform", "column", "dais", "image", "roof", "water", "wing"],
		"check": &"hall_check", "about": "Phoenix Hall with mirrored wings"},
	{"key": "port_tenement", "family": &"insula", "kind": &"port_tenement",
		"width": 30.0, "length": 20.0, "height": 18.0,
		"must": ["shop", "stair", "bedroom", "parlour"],
		"check": &"insula_check", "about": "five-storey port tenement with six flats"},
	{"key": "merchant_tower", "family": &"tower_house", "kind": &"merchant_tower",
		"width": 8.0, "length": 8.0, "height": 45.0,
		"must": ["hall", "platform", "storey_0"],
		"check": &"tower_check", "about": "Bologna tower house with a walkable roof deck"},
	{"key": "sultan_han", "family": &"caravanserai", "kind": &"sultan_han",
		"width": 70.0, "length": 55.0, "height": 12.0,
		"must": ["guest_room", "stable", "han_kiosk", "han_winter_dome"],
		"check": &"han_check", "about": "Sultan's Han with a flooded court and domed winter hall"},
	{"key": "steam_baths", "family": &"hammam", "kind": &"steam_baths",
		"width": 24.0, "length": 16.0, "height": 8.0,
		"must": ["changing", "cold", "warm", "hot", "dome", "oculus", "furnace"],
		"check": &"hammam_check", "about": "four-stage hammam with domed bathing rooms"},
	{"key": "nine_storey_pagoda", "family": &"pagoda", "kind": &"square_pagoda",
		"width": 30.0, "length": 30.0, "height": 65.0,
		"must": ["floor_0", "eave_tier", "mast", "finial"],
		"check": &"pagoda_check", "about": "Nine-Storey Pagoda"},
	{"key": "saints_mound", "family": &"stupa", "kind": &"saints_mound",
		"width": 40.0, "length": 40.0, "height": 17.0, "scales": [1.0],
		"must": ["stupa_dome", "ground_circumambulatory_ring", "drum_circumambulatory_ring",
			"stupa_harmika", "stupa_chatra_shaft", "stupa_torana_0"],
		"check": &"stupa_check", "about": "Sanchi-derived Saint's Mound"},
	{"key": "monks_cloister", "family": &"vihara", "kind": &"monks_cloister",
		"width": 50.0, "length": 40.0, "height": 5.0,
		"must": ["cell", "vihara_shrine", "verandah", "vihara_well"],
		"check": &"vihara_check", "about": "Vihara cells around the cloister court"},
	{"key": "merchants_haveli", "family": &"vastu", "kind": &"merchants_haveli",
		"width": 15.0, "length": 28.0, "height": 10.0,
		"must": ["kitchen", "vastu_main_hall", "vastu_well", "jharokha"],
		"check": &"vastu_check", "about": "Merchant's Haveli around a vastu light well"},
	{"key": "clan_ring", "family": &"tulou", "kind": &"clan_ring",
		"width": 60.0, "length": 60.0, "height": 15.0,
		"must": ["ancestral_hall", "gallery", "clan_room", "stair", "roof_ring"],
		"check": &"tulou_check", "about": "Hakka clan fortress with inward galleries"},
	{"key": "nagara_hundred_spires", "family": &"nagara", "kind": &"hundred_spires",
		"width": 31.0, "length": 20.0, "height": 31.0,
		"must": ["ardhamandapa", "mandapa", "mahamandapa", "garbhagriha", "plinth", "shikhara", "urushringa"],
		"check": &"shikhara_check", "about": "Spire of a Hundred Spires"},
	{"key": "quarried_temple", "family": &"rock_cut_temple", "kind": &"quarried_temple",
		"width": 82.0, "length": 46.0, "height": 30.0,
		"must": ["pit_wall", "gateway", "gallery_floor", "bridge", "nandi", "hall", "sanctum", "shikhara"],
		"check": &"cut_check", "about": "Quarried Temple below a pit-wall gallery"},
	{"key": "temple_mountain", "family": &"temple_mountain", "kind": &"angkor_mountain",
		"width": 200.0, "length": 200.0, "height": 60.0,
		"must": ["water", "causeway", "enclosure", "gopura", "tower_center"],
		"check": &"mountain_check", "about": "three raised rings, moat crossing and quincunx"},
	{"key": "queens_well", "family": &"stepwell", "kind": &"queens_well",
		"width": 65.0, "length": 20.0, "height": 28.0,
		"must": ["landing", "stair", "retaining_wall", "pavilion", "tank", "shaft", "water"],
		"check": &"vav_check", "about": "The Queen's Well descending through seven levels"},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("world archetype")
	for row in ARCHETYPES:
		var key: String = row["key"]
		var defects := 0
		for scale in row.get("scales", SCALES):
			var request := BuildingRequest.new()
			request.kind = &"world"
			request.seed = _seed_for(key, scale)
			request.style = row["family"]
			request.purpose = row["kind"]
			request.width = snappedf(float(row["width"]) * scale, 0.01)
			request.length = snappedf(float(row["length"]) * scale, 0.01)
			request.height = float(row["height"]) * scale if row["family"] == &"pagoda" else float(row["height"])
			if row["family"] == &"tulou":
				request.storeys = 4
			var building: GeneratedBuilding = BigGlade.generate(request)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
			var before: int = res.failures.size()
			if building == null or not building.is_ok():
				res.fail("%s: did not generate: %s" % [who, str(building.errors) if building != null else "null"])
				defects += 1
				continue
			for f in assert_contains(building, row.get("must", [])):
				res.fail("%s: %s" % [who, f])
			var mesh: ArrayMesh = BigGlade.build_mesh(building)
			if mesh == null:
				res.fail("%s: no family mesh" % who)
			else:
				NormalsSuite.check_mesh(res, mesh, who)
				if building.spec is TimberHallSpec:
					_opening_rays(res, building.spec as TimberHallSpec, mesh, who)
			for f2 in _family_check(building, row.get("check", &"")):
				res.fail("%s: %s" % [who, f2])
			if res.failures.size() > before:
				defects += 1
		res.note("  %-17s %d scales, %d defects -- %s" % [key, SCALES.size(), defects, String(row.get("about", ""))])
	if ARCHETYPES.is_empty():
		res.note("  0 archetypes")
	_negative_hall_fixtures(res)
	_negative_tower_fixtures(res)
	return res


static func run_nagara() -> SuiteResult:
	var res := SuiteResult.new("world Nagara archetype")
	var row: Dictionary = {}
	for candidate in ARCHETYPES:
		if candidate.get("key") == "nagara_hundred_spires":
			row = candidate
			break
	if row.is_empty():
		res.fail("Nagara archetype row is missing")
		return res
	for scale in SCALES:
		var request := BuildingRequest.new()
		request.kind = &"world"
		request.seed = _seed_for("nagara_hundred_spires", scale)
		request.style = row["family"]
		request.purpose = row["kind"]
		request.width = snappedf(float(row["width"]) * scale, 0.01)
		request.length = snappedf(float(row["length"]) * scale, 0.01)
		request.height = float(row["height"])
		var building: GeneratedBuilding = BigGlade.generate(request)
		res.checked += 1
		var who := "nagara_hundred_spires scale=%.2f" % scale
		if building == null or not building.is_ok():
			res.fail("%s: did not generate: %s" % [who,
				str(building.errors) if building != null else "null"])
			continue
		for failure in assert_contains(building, row["must"]):
			res.fail("%s: %s" % [who, failure])
		var mesh: ArrayMesh = BigGlade.build_mesh(building)
		if mesh == null:
			res.fail("%s: no Nagara family mesh" % who)
		else:
			NormalsSuite.check_mesh(res, mesh, who)
		for failure in _family_check(building, row["check"]):
			res.fail("%s: %s" % [who, failure])
	return res


static func run_tower_house() -> SuiteResult:
	var res := SuiteResult.new("world tower house")
	var row: Dictionary = ARCHETYPES.back()
	for scale in SCALES:
		var request := BuildingRequest.new()
		request.kind = &"world"
		request.seed = _seed_for("merchant_tower", scale)
		request.style = &"tower_house"
		request.purpose = &"merchant_tower"
		request.width = snappedf(float(row["width"]) * scale, 0.01)
		request.length = snappedf(float(row["length"]) * scale, 0.01)
		request.height = snappedf(float(row["height"]) * scale, 0.01)
		var building: GeneratedBuilding = BigGlade.generate(request)
		res.checked += 1
		var who := "merchant_tower scale=%.2f" % scale
		if building == null or not building.is_ok():
			res.fail("%s: did not generate: %s" % [who,
				str(building.errors) if building != null else "null"])
			continue
		var builder := CastleBuilder.new()
		var mesh := builder.build(building.spec as CastleSpec)
		if mesh == null:
			res.fail("%s: no castle tower mesh" % who)
		else:
			NormalsSuite.check_mesh(res, mesh, who)
		for f in TowerCheck.new().check(building.spec, builder)["failures"]:
			res.fail("%s: %s" % [who, str(f)])
		var doors: Array = builder.part_log.filter(func(part: Dictionary) -> bool:
			return part.get("opening_kind", "") == "door")
		if doors.size() != 1:
			res.fail("%s: expected one raised entrance" % who)
		elif float((doors[0]["pos"] as Vector3).y) - float((doors[0]["size"] as Vector3).y) * 0.5 < TowerCheck.LIFT_MIN:
			res.fail("%s: door sill is below the ladder reach" % who)
	res.checked += 1
	if WorldFamilies.kinds_of(&"tower_house") != [&"merchant_tower"]:
		res.fail("tower_house family does not publish merchant_tower")
	_negative_tower_fixtures(res)
	return res


static func _negative_hall_fixtures(res: SuiteResult) -> void:
	var broken_grid := TimberHallGenerator.generate(&"great_hall", 701, 34.0, 18.0, 20.0)
	broken_grid.columns[0]["pos"] = broken_grid.columns[0]["pos"] + Vector3(1.0, 0.0, 0.0)
	var broken_builder := TimberHallBuilder.new()
	broken_builder.build(broken_grid)
	var broken_report: Dictionary = HallCheck.check(broken_grid, broken_builder)
	res.checked += 1
	if not _has_failure(broken_report, "rings:"):
		res.fail("negative hall fixture: broken column mirror was accepted")
	var low_eaves := TimberHallGenerator.generate(&"great_hall", 702, 34.0, 18.0, 20.0)
	low_eaves.roof_overhang = 0.1
	var eaves_builder := TimberHallBuilder.new()
	eaves_builder.build(low_eaves)
	var eaves_report: Dictionary = HallCheck.check(low_eaves, eaves_builder)
	res.checked += 1
	if not _has_failure(eaves_report, "eaves:"):
		res.fail("negative hall fixture: undersized eaves were accepted")
	var dry_wing := TimberHallGenerator.generate(&"phoenix_pavilion", 703, 60.0, 12.0, 14.0)
	dry_wing.water = Rect2(Vector2(-2.0, -1.0), Vector2(4.0, 2.0))
	var wing_builder := TimberHallBuilder.new()
	wing_builder.build(dry_wing)
	var wing_report: Dictionary = HallCheck.check(dry_wing, wing_builder)
	res.checked += 1
	if not _has_failure(wing_report, "wings:"):
		res.fail("negative hall fixture: undersized Phoenix water was accepted")
	var buried_water := TimberHallGenerator.generate(&"phoenix_pavilion", 706, 60.0, 12.0, 14.0)
	buried_water.water = Rect2(Vector2(-40.0, -7.0), Vector2(80.0, 5.0))
	var buried_builder := TimberHallBuilder.new()
	buried_builder.build(buried_water)
	var buried_report: Dictionary = HallCheck.check(buried_water, buried_builder)
	res.checked += 1
	if buried_report["failures"].is_empty():
		res.fail("negative hall fixture: buried/overlapping Phoenix water was accepted")
	var blocked := TimberHallGenerator.generate(&"great_hall", 704, 34.0, 18.0, 20.0)
	for c in blocked.columns:
		c["radius"] = 4.0
	var blocked_builder := TimberHallBuilder.new()
	blocked_builder.build(blocked)
	var blocked_report: Dictionary = HallCheck.check(blocked, blocked_builder)
	res.checked += 1
	if not _has_failure(blocked_report, "clear:"):
		res.fail("negative hall fixture: blocked standable area was accepted")
	var no_brackets := TimberHallGenerator.generate(&"great_hall", 705, 34.0, 18.0, 20.0)
	var no_bracket_builder := TimberHallBuilder.new()
	no_bracket_builder.build(no_brackets)
	no_bracket_builder.part_log = no_bracket_builder.part_log.filter(func(part): return part["kind"] != "bracket")
	var bracket_report: Dictionary = HallCheck.check(no_brackets, no_bracket_builder)
	res.checked += 1
	if not _has_failure(bracket_report, "brackets:"):
		res.fail("negative hall fixture: missing bracket sets were accepted")


static func _negative_tower_fixtures(res: SuiteResult) -> void:
	var spec := TowerGenerator.generate(&"merchant_tower", 701,
		8.0, 8.0, 45.0)
	var squat := CastleBuilder.new()
	squat.build(spec)
	for mass in squat.mass_log:
		if mass["name"] == "hall":
			var a: AABB = mass["aabb"]
			mass["aabb"] = AABB(a.position, Vector3(a.size.x, a.size.x * 2.0, a.size.z))
	_expect_tower_rule(res, "slender", TowerCheck.new().check(spec, squat))

	var low_door := CastleBuilder.new()
	low_door.build(spec)
	for part in low_door.part_log:
		if String(part.get("opening_kind", "")) == "door":
			var p: Vector3 = part["pos"]
			var size: Vector3 = part["size"]
			part["pos"] = Vector3(p.x, size.y * 0.5 + 0.5, p.z)
			break
	_expect_tower_rule(res, "lift", TowerCheck.new().check(spec, low_door))

	var missing_room := CastleBuilder.new()
	missing_room.build(spec)
	var room_plan: HousePlan = missing_room.interiors[0]["plan"]
	room_plan.rooms.pop_back()
	_expect_tower_rule(res, "stack", TowerCheck.new().check(spec, missing_room))
	var extra_room := CastleBuilder.new()
	extra_room.build(spec)
	var extra_plan: HousePlan = extra_room.interiors[0]["plan"]
	var duplicate := extra_plan.rooms[1].duplicate(true)
	extra_plan.rooms.append(duplicate)
	_expect_tower_rule(res, "stack", TowerCheck.new().check(spec, extra_room))

	var missing_stair := CastleBuilder.new()
	missing_stair.build(spec)
	var stair_plan: HousePlan = missing_stair.interiors[0]["plan"]
	for stair_i in range(stair_plan.stairs.size()):
		if int(stair_plan.stairs[stair_i].get("to_storey", -1)) == spec.tower_storeys:
			stair_plan.stairs.remove_at(stair_i)
			break
	_expect_tower_rule(res, "stack", TowerCheck.new().check(spec, missing_stair))

	var thin_foot := CastleBuilder.new()
	thin_foot.build(spec)
	var top_width := 0.0
	for top_mass in thin_foot.mass_log:
		if String(top_mass["name"]).begins_with("storey_"):
			top_width = (top_mass["aabb"] as AABB).size.x
	for foot_mass in thin_foot.mass_log:
		if foot_mass["name"] == "storey_0":
			var a2: AABB = foot_mass["aabb"]
			foot_mass["aabb"] = AABB(Vector3(a2.position.x + (a2.size.x - top_width) * 0.5,
				a2.position.y, a2.position.z + (a2.size.z - top_width) * 0.5),
				Vector3(top_width, a2.size.y, top_width))
			break
	_expect_tower_rule(res, "foot", TowerCheck.new().check(spec, thin_foot))

	var gap := CastleBuilder.new()
	gap.build(spec)
	gap.mass_log.append({"name": "detached_fixture", "aabb": AABB(Vector3(100, 100, 100), Vector3.ONE)})
	_expect_tower_rule(res, "no_gaps", TowerCheck.new().check(spec, gap))

	var ungrounded := CastleBuilder.new()
	ungrounded.build(spec)
	ungrounded.mass_log.append({"name": "floating_fixture", "aabb": AABB(Vector3(0, 1, 0), Vector3.ONE)})
	_expect_tower_rule(res, "size_match", TowerCheck.new().check(spec, ungrounded))


static func _expect_tower_rule(res: SuiteResult, rule: String, report: Dictionary) -> void:
	res.checked += 1
	for failure in report.get("failures", []):
		if String(failure).begins_with(rule + ":"):
			return
	res.fail("negative tower fixture %s was accepted" % rule)


static func _has_failure(report: Dictionary, prefix: String) -> bool:
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix):
			return true
	return false


static func _opening_rays(res: SuiteResult, spec: TimberHallSpec, mesh: ArrayMesh, where: String) -> void:
	var h := TimberHallGeometry.hall_rect(spec)
	var door_origin := Vector3(0.0, spec.platform_h + 2.0, h.position.y - 1.0)
	res.checked += 1
	if _ray_hits_mesh(mesh, door_origin, Vector3.BACK, 2.5):
		res.fail("%s: authored door ray is filled" % where)
	var w: Dictionary = spec.windows[0]
	var wp: Vector3 = w["pos"]
	var wn: Vector3 = w["normal"]
	var window_origin := wp + wn
	res.checked += 1
	if _ray_hits_mesh(mesh, window_origin, -wn, 2.5):
		res.fail("%s: authored window ray is filled" % where)
	var filled_door := TimberHallBuilder.new()
	var filled_mesh := filled_door.build(spec, true, true)
	res.checked += 1
	if not _ray_hits_mesh(filled_mesh, door_origin, Vector3.BACK, 2.5):
		res.fail("%s: filled-door negative control was not detected" % where)
	var filled_window_spec := TimberHallGenerator.generate(spec.kind, spec.seed, spec.width, spec.length, spec.height)
	filled_window_spec.windows.clear()
	var filled_window := TimberHallBuilder.new()
	var filled_window_mesh := filled_window.build(filled_window_spec)
	res.checked += 1
	if not _ray_hits_mesh(filled_window_mesh, window_origin, -wn, 2.5):
		res.fail("%s: filled-window negative control was not detected" % where)


static func _ray_hits_mesh(mesh: ArrayMesh, origin: Vector3, direction: Vector3, max_distance: float) -> bool:
	var d := direction.normalized()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for i in range(triangle_count):
			var ia := indices[i * 3] if not indices.is_empty() else i * 3
			var ib := indices[i * 3 + 1] if not indices.is_empty() else i * 3 + 1
			var ic := indices[i * 3 + 2] if not indices.is_empty() else i * 3 + 2
			var a: Vector3 = vertices[ia]
			var b: Vector3 = vertices[ib]
			var c: Vector3 = vertices[ic]
			var edge1 := b - a
			var edge2 := c - a
			var pvec := d.cross(edge2)
			var det := edge1.dot(pvec)
			if absf(det) < 0.000001:
				continue
			var inv_det := 1.0 / det
			var tvec := origin - a
			var u := tvec.dot(pvec) * inv_det
			if u < 0.0 or u > 1.0:
				continue
			var qvec := tvec.cross(edge1)
			var v := d.dot(qvec) * inv_det
			if v < 0.0 or u + v > 1.0:
				continue
			var t := edge2.dot(qvec) * inv_det
			if t >= 0.0 and t <= max_distance:
				return true
	return false


static func _seed_for(key: String, scale: float) -> int:
	return 51000 + absi(key.hash()) % 900 + int(scale * 100.0)


## Does the building contain everything in `must`, by name? A name is looked
## for among the mass log's kinds (mass names, by prefix), the plan's room
## kinds and the furniture's categories -- never a position.
static func assert_contains(building: GeneratedBuilding, must: Array) -> Array[String]:
	var out: Array[String] = []
	var names := {}
	var mesh_builder = _builder_for(building)
	if mesh_builder != null:
		for m in mesh_builder.mass_log:
			var nm: String = m["name"]
			names[nm] = true
			var stem: String = nm
			while stem.length() > 0 and (stem[-1].is_valid_int() or stem.ends_with("_")):
				stem = stem.substr(0, stem.length() - 1)
			names[stem] = true
	if building.plan != null:
		for i in range(building.plan.room_count()):
			names[String(building.plan.kind_of(i))] = true
			var role := String(building.plan.rooms[i].get("role", ""))
			if not role.is_empty():
				names[role] = true
		for opening in building.plan.roof_openings:
			names[String(opening.get("kind", ""))] = true
		for p in building.plan.furniture:
			names[PropCatalog.category(p["key"])] = true
	for want in must:
		var w: String = String(want)
		var found: bool = names.has(w)
		if not found:
			for n in names:
				if String(n).begins_with(w):
					found = true
					break
		if not found:
			out.append("contains: no %s anywhere in the building" % w)
	return out


## The family's own check, by class name, plus MassRules over the masses.
static func _family_check(building: GeneratedBuilding, check: StringName) -> Array[String]:
	var out: Array[String] = []
	var mesh_builder = _builder_for(building)
	if mesh_builder != null and not mesh_builder.mass_log.is_empty() \
			and (building.plan == null or building.plan.world_family != &"temple_mountain"):
		var anchor: String = mesh_builder.mass_log[0]["name"]
		var free_masses: Array[String] = []
		if building.plan != null and building.plan.world_family == &"mosque":
			free_masses.assign(["sahn_floor", "fountain", "minaret"])
		elif building.plan != null and building.plan.world_family == &"tulou":
			free_masses.assign(["stair", "ancestral_hall"])
		elif building.plan != null and building.plan.world_subkind == &"sultan_han":
			free_masses.append("han_kiosk")
		elif building.plan != null and building.plan.world_family == &"pagoda":
			free_masses.append("eave_tier")
		elif building.spec is StupaSpec:
			free_masses.append("stupa_")
		elif building.plan != null and building.plan.world_subkind == &"monks_cloister":
			free_masses.append("vihara_well")
		elif building.plan != null and building.plan.world_family == &"vastu":
			free_masses.assign(["vastu_well", "jharokha"])
		elif building.plan != null and building.plan.world_family == &"stepwell":
			free_masses.assign(["pavilion", "tank", "shaft", "water"])
		elif building.plan != null and building.plan.world_family == &"rock_cut_temple":
			free_masses.assign(["gateway", "gallery", "bridge"])
		for f in MassRules.gaps(mesh_builder.mass_log, anchor, free_masses)["failures"]:
			out.append(str(f))
	if check == &"":
		return out
	if check == &"cruciform_check" and building.plan != null:
		var cruciform_builder := CruciformBuilder.new()
		cruciform_builder.build(building.plan)
		out.append_array(CruciformCheck.check(building.plan, cruciform_builder).get("failures", []))
		return out
	if check == &"shikhara_check" and building.plan != null:
		var nagara_builder := NagaraBuilder.new()
		nagara_builder.build(building.plan)
		out.append_array(ShikharaCheck.check(building.plan, nagara_builder).get("failures", []))
		return out
	if check == &"mountain_check" and building.plan != null:
		var mountain_builder := MountainBuilder.new()
		var mesh := mountain_builder.build(building.plan)
		if mesh == null or mesh.get_surface_count() == 0:
			out.append("mountain: no emitted mesh")
		out.append_array(MountainCheck.new().check_mountain(building.plan, mountain_builder).get("failures", []))
		return out
	var script = load("res://qa/%s.gd" % String(check).to_snake_case())
	if script == null:
		out.append("check: no qa/%s.gd" % String(check).to_snake_case())
		return out
	var checker = script.new()
	var rep: Dictionary
	if building.plan != null and check in [&"cut_check", &"hammam_check", &"pagoda_check", &"shikhara_check", &"vav_check", &"vastu_check"]:
		rep = checker.check(building.plan, mesh_builder)
	elif building.plan != null and check == &"tulou_check":
		rep = checker.check(building.plan, mesh_builder)
	elif building.plan != null:
		rep = checker.check(building.plan)
	else:
		rep = checker.check(building.spec, mesh_builder)
	for f2 in rep.get("failures", []):
		out.append(str(f2))
	return out


## A builder that has been through the building, so its mass log is filled.
static func _builder_for(building: GeneratedBuilding):
	if building.plan != null:
		if building.plan.world_family == &"temple_mountain":
			var mountain := MountainBuilder.new()
			mountain.build(building.plan)
			return mountain
		if building.plan.world_family == &"cruciform_temple":
			var cruciform := CruciformBuilder.new()
			cruciform.build(building.plan)
			return cruciform
		if building.plan.world_family == &"mosque":
			var mb := MosqueBuilder.new()
			mb.build(building.plan)
			return mb
		if building.plan.world_family == &"hammam":
			var hammam_builder := HammamBuilder.new()
			hammam_builder.build(building.plan)
			return hammam_builder
		if building.plan.world_family == &"pagoda":
			var pb := PagodaBuilder.new()
			pb.build(building.plan)
			return pb
		if building.plan.world_family == &"tulou":
			var tulou_builder := TulouBuilder.new()
			tulou_builder.build(building.plan)
			return tulou_builder
		if building.plan.world_family == &"nagara":
			var nb := NagaraBuilder.new()
			nb.build(building.plan)
			return nb
		if building.plan.world_family == &"rock_cut_temple":
			var cut_builder := CutTempleBuilder.new()
			cut_builder.build(building.plan)
			return cut_builder
		if building.plan.world_family == &"stepwell":
			var vb := VavBuilder.new()
			vb.build(building.plan)
			return vb
		var hb := HouseBuilder.new()
		hb.build(building.plan)
		return hb
	if building.spec is CastleSpec:
		var cb := CastleBuilder.new()
		cb.build(building.spec)
		return cb
	if building.spec is TempleSpec:
		var tb := TempleBuilder.new()
		tb.build(building.spec)
		return tb
	if building.spec is ChurchSpec:
		var chb := ChurchBuilder.new()
		chb.build(building.spec)
		return chb
	if building.spec is TimberHallSpec:
		var thb := TimberHallBuilder.new()
		thb.build(building.spec)
		return thb
	if building.spec is StupaSpec:
		var sb := StupaBuilder.new()
		sb.build(building.spec)
		return sb
	return null
