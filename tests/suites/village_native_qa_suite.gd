extends RefCounted
## Two bounded native fixtures protect the family dispatch that placement
## measurements cannot replace. Broken derived geometry is checked directly
## so regeneration cannot silently repair either negative control.
const NativeQA = preload("res://tests/fixtures/native_family_qa_cache.gd")

static func run() -> SuiteResult:
	var res := SuiteResult.new("village native family QA")
	var church_request := BuildingRequest.church(11, &"romanesque", 8, 12, 8)
	var church := BrickWild.generate(church_request)
	_expect(res, church.is_ok(), "native church fixture did not generate")
	if church.is_ok():
		var report := NativeQA.check(church_request)
		_expect(res, var_to_bytes(report) == var_to_bytes(NativeQA.check(church_request)),
			"exact church QA cache hit changed its native report")
		_expect(res, report["failures"].is_empty(), "native church: " + "; ".join(report["failures"]))
		_expect(res, report["stats"].has("voxels_solid") and report["stats"].has("bbox"),
			"village church skipped BlueprintQA")
		var spec := church.spec as ChurchSpec
		spec.tower = true
		spec.tower_width = spec.width + 1.0
		var broken := VillageQA._native_qa(church)
		_expect(res, broken["failures"].any(func(failure: String) -> bool:
			return failure.begins_with("proportions: tower wider than nave")),
			"church's physically overwide tower escaped native QA dispatch")
	var castle_request := BuildingRequest.castle(11, &"norman", 50, 50, 10)
	var castle := BrickWild.generate(castle_request)
	_expect(res, castle.is_ok(), "native castle fixture did not generate")
	if castle.is_ok():
		var report := NativeQA.check(castle_request)
		_expect(res, var_to_bytes(report) == var_to_bytes(NativeQA.check(castle_request)),
			"exact castle QA cache hit changed its native report")
		_expect(res, report["failures"].is_empty(), "native castle: " + "; ".join(report["failures"]))
		_expect(res, report["stats"].has("voxels_solid") and report["stats"].has("interior_buildings"),
			"village castle skipped CastleQA voxel/interior checks")
		var spec := castle.spec as CastleSpec
		spec.gatehouse = false
		var broken := VillageQA._native_qa(castle)
		_expect(res, broken["failures"].any(func(failure: String) -> bool:
			return failure.begins_with("gate_access:")),
			"castle with no physical outer gate escaped native access QA dispatch: " + "; ".join(broken["failures"]))
	_check_cache_controls(res)
	return res


static func _check_cache_controls(res: SuiteResult) -> void:
	var report := {"ok": false, "failures": ["physical defect"], "warnings": [], "stats": {}}
	var record := {"source": "native-source", "request": "exact-request", "report": report,
		"checksum": var_to_bytes(report).hex_encode().sha256_text()}
	_expect(res, NativeQA.valid_record(record, "native-source", "exact-request"),
		"exact native QA failure report was not reusable")
	_expect(res, not NativeQA.valid_record(record, "changed-source", "exact-request"),
		"stale native QA source reused a result")
	_expect(res, not NativeQA.valid_record(record, "native-source", "other-request"),
		"native QA report reused for a different request")
	report["failures"].clear()
	report["ok"] = true
	_expect(res, not NativeQA.valid_record(record, "native-source", "exact-request"),
		"damaged native QA report erased a real failure")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok: res.fail(message)
