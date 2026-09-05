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

const ARCHETYPES: Array[Dictionary] = []


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
			for f2 in _family_check(building, row.get("check", &"")):
				res.fail("%s: %s" % [who, f2])
			if res.failures.size() > before:
				defects += 1
		res.note("  %-17s %d scales, %d defects -- %s" % [key, SCALES.size(), defects, String(row.get("about", ""))])
	if ARCHETYPES.is_empty():
		res.note("  0 archetypes")
	return res


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
	return null
