class_name BuildingResult
extends RefCounted
## Detached consumer diagnostics. Builder instances and mutable logs stay local.

static func check(building) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if building == null or not building.is_ok():
		var errors: Array = building.errors if building != null else [{
			"code": "building_required", "field": "building", "message": "A valid building is required."}]
		for error in errors:
			var row: Dictionary = error.duplicate(true)
			row["severity"] = "error"
			diagnostics.append(row)
		return {"api_version": BigGlade.API_VERSION, "ok": false,
			"diagnostics": diagnostics, "stats": {}}
	var report: Dictionary
	if building.village != null:
		report = VillageQA.new().check(building.village)
	elif building.plan != null:
		if building.spec is HotelSpec:
			var builder := HotelBuilder.new()
			builder.build(building.plan)
			report = HotelQA.new().check(building.plan, builder)
		else:
			var builder := HouseBuilder.new()
			builder.build(building.plan)
			report = HouseQA.new().check(building.plan, builder)
			if not building.plan.courts.is_empty():
				var court: Dictionary = CourtCheck.new().check(building.plan)
				report["failures"].append_array(court["failures"])
				report["warnings"].append_array(court["warnings"])
	elif building.spec is ChurchSpec:
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(building.spec)
		report = BlueprintQA.new().check(building.spec, mesh, builder)
	elif building.spec is CastleSpec:
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(building.spec)
		report = CastleQA.new().check(building.spec, mesh, builder)
	elif building.spec is TempleSpec:
		var builder := TempleBuilder.new()
		builder.build(building.spec)
		report = TempleQA.new().check(building.spec, builder)
	elif building.spec is TimberHallSpec:
		var builder := TimberHallBuilder.new()
		builder.build(building.spec)
		report = HallCheck.check(building.spec, builder)
	else:
		report = {"failures": ["unsupported_family: No QA adapter exists for this family."], "warnings": []}
	for severity in ["error", "warning"]:
		for message in report.get("failures" if severity == "error" else "warnings", []):
			var text := str(message)
			var rule := text.get_slice(":", 0).strip_edges() if ":" in text else "quality"
			diagnostics.append({"severity": severity, "code": rule,
				"field": "building", "message": text})
	return {"api_version": BigGlade.API_VERSION,
		"ok": report.get("failures", []).is_empty(),
		"kind": String(building.request.kind), "seed": str(building.request.seed),
		"diagnostics": diagnostics, "stats": BuildingDocument._plain(report.get("stats", {}))}
