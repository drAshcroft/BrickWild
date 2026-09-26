extends SceneTree
const CACHE = preload("res://tests/fixtures/native_measurement_cache.gd")
var checked := 0
var failures: Array[String] = []

func _init() -> void:
	var requests: Array[BuildingRequest] = [BuildingRequest.house(6141, &"cottage", &"none", 7, 9, 2.6)]
	var native := VillageLotPlanner.measure_all(requests)
	var first: Array[Dictionary] = CACHE.measure(requests)
	var second: Array[Dictionary] = CACHE.measure(requests)
	_expect(CACHE.valid_jobs(first, requests), "cached native job schema invalid")
	_expect(var_to_bytes(BuildingCodec.encode(native)) == var_to_bytes(BuildingCodec.encode(first)), "cache differs from fresh native measurements")
	_expect(var_to_bytes(BuildingCodec.encode(first)) == var_to_bytes(BuildingCodec.encode(second)), "cache hit changed native bytes")
	_expect(not CACHE.valid_jobs([], requests), "empty cache accepted")
	var missing: Array[Dictionary] = second.duplicate(true)
	missing[0].erase("back")
	_expect(not CACHE.valid_jobs(missing, requests), "cache missing required field accepted")
	var changed: Array[Dictionary] = second.duplicate(true)
	changed[0]["request"] = requests[0].copy()
	changed[0]["request"].seed += 1
	_expect(not CACHE.valid_jobs(changed, requests), "different native request accepted")
	changed = second.duplicate(true)
	changed[0]["half_w"] = NAN
	_expect(not CACHE.valid_jobs(changed, requests), "non-finite native dimension accepted")
	# Corrupting a persisted checksum must regenerate, not silently reuse data.
	var payload: Array[String] = [requests[0].to_json()]
	var key: String = (CACHE.source_hash() + JSON.stringify(payload)).sha256_text()
	var path: String = CACHE.ROOT.path_join(key + ".bin")
	var record: Dictionary = FileAccess.open(path, FileAccess.READ).get_var(false)
	record["checksum"] = "broken"
	FileAccess.open(path, FileAccess.WRITE).store_var(record)
	var repaired: Array[Dictionary] = CACHE.measure(requests)
	_expect(var_to_bytes(BuildingCodec.encode(native)) == var_to_bytes(BuildingCodec.encode(repaired)), "corrupt cache did not regenerate exact native job")
	for failure in failures: print("FAIL ", failure)
	print("NATIVE_MEASUREMENT_CACHE: %d checks, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checked += 1
	if not ok: failures.append(message)
