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

const ARCHETYPES: Array[Dictionary] = [
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
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("world archetype")
	for row in ARCHETYPES:
		var key: String = row["key"]
		var defects := 0
		for scale in SCALES:
			var request := BuildingRequest.new()
			request.kind = &"world"
			request.seed = _seed_for(key, scale)
			request.style = row["family"]
			request.purpose = row["kind"]
			request.width = float(row["width"]) * scale
			request.length = float(row["length"]) * scale
			request.height = float(row["height"])
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
	if mesh_builder != null and not mesh_builder.mass_log.is_empty():
		var anchor: String = mesh_builder.mass_log[0]["name"]
		for f in MassRules.gaps(mesh_builder.mass_log, anchor)["failures"]:
			out.append(str(f))
	if check == &"":
		return out
	var script = load("res://qa/%s.gd" % String(check).to_snake_case())
	if script == null:
		out.append("check: no qa/%s.gd" % String(check).to_snake_case())
		return out
	var checker = script.new()
	var rep: Dictionary = checker.check(building.plan) if building.plan != null \
		else checker.check(building.spec, mesh_builder)
	for f2 in rep.get("failures", []):
		out.append(str(f2))
	return out


## A builder that has been through the building, so its mass log is filled.
static func _builder_for(building: GeneratedBuilding):
	if building.plan != null:
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
	return null
