extends RefCounted
## Full native family QA, never placement-only measurement or sampled QA.
## Exact public requests and native/QA source contents own every report.

const ROOT := "res://artifacts/native_family_qa_cache"
static var _source := ""


static func check(request: BuildingRequest) -> Dictionary:
	var source := source_hash()
	var payload := request.to_json()
	var path := ROOT.path_join((source + payload).sha256_text() + ".bin")
	if FileAccess.file_exists(path):
		var input := FileAccess.open(path, FileAccess.READ)
		var record: Variant = input.get_var(false) if input != null else null
		if valid_record(record, source, payload):
			print("NATIVE_QA_CACHE HIT kind=", request.kind, " seed=", request.seed)
			return record["report"]
		print("NATIVE_QA_CACHE REJECT kind=", request.kind, " seed=", request.seed)
	print("NATIVE_QA_CACHE MISS kind=", request.kind, " seed=", request.seed)
	var report := VillageQA._building_qa({"request": request})
	DirAccess.make_dir_recursive_absolute(ROOT)
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null:
		output.store_var({"source": source, "request": payload, "report": report,
			"checksum": var_to_bytes(report).hex_encode().sha256_text()})
	return report


static func valid_record(record: Variant, source: String, request: String) -> bool:
	if not record is Dictionary or record.get("source", "") != source \
			or record.get("request", "") != request: return false
	var report: Variant = record.get("report")
	if not report is Dictionary or not report.get("failures") is Array \
			or not report.get("warnings") is Array or not report.get("stats") is Dictionary:
		return false
	for key in ["failures", "warnings"]:
		for message in report[key]:
			if not message is String: return false
	if report.get("ok") != report["failures"].is_empty(): return false
	return record.get("checksum", "") == var_to_bytes(report).hex_encode().sha256_text()


static func source_hash() -> String:
	if not _source.is_empty(): return _source
	# The measurement source includes all native generators, builders, API and
	# family QA, the catalogue and engine version. VillageQA and this adapter
	# are additional dependencies because the measurement excludes village QA.
	_source = (preload("res://tests/fixtures/native_measurement_cache.gd").source_hash()
		+ FileAccess.get_file_as_string("res://qa/village_qa.gd")
		+ FileAccess.get_file_as_string("res://tests/fixtures/native_family_qa_cache.gd")).sha256_text()
	return _source
