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
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	var report: Dictionary = family.quality_report(building) if family != null else {
		"failures": ["unsupported_family: No QA adapter exists for this family."], "warnings": []}
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
