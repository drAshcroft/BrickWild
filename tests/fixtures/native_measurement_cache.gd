extends RefCounted
## Test-only cache of native measurements, never of sites, lots or dressing.
## Exact requests and native source contents own each entry. Planner/QA changes
## still rerun their complete work; fresh determinism checks bypass this cache.

const ROOT := "res://artifacts/native_measurement_cache"
static var _source := ""

static func measure(requests: Array[BuildingRequest]) -> Array[Dictionary]:
	var source := source_hash()
	var payload: Array[String] = []
	for request in requests: payload.append(request.to_json())
	var key := (source + JSON.stringify(payload)).sha256_text()
	var path := ROOT.path_join(key + ".bin")
	if FileAccess.file_exists(path):
		var input := FileAccess.open(path, FileAccess.READ)
		var record: Variant = input.get_var(false) if input != null else null
		if record is Dictionary and record.get("source", "") == source and record.get("requests", []) == payload \
				and record.get("checksum", "") == var_to_bytes(record.get("jobs")).hex_encode().sha256_text():
			var codec := BuildingCodec.new()
			var decoded: Variant = codec.decode(record.get("jobs"))
			if codec.errors.is_empty() and valid_jobs(decoded, requests):
				var out: Array[Dictionary] = []
				out.assign(decoded)
				print("NATIVE_CACHE HIT source=", source, " key=", key, " jobs=", out.size())
				return out
		print("NATIVE_CACHE REJECT source=", source, " key=", key)
	print("NATIVE_CACHE MISS source=", source, " key=", key, " requests=", requests.size())
	var jobs := VillageLotPlanner.measure_all(requests)
	if valid_jobs(jobs, requests):
		DirAccess.make_dir_recursive_absolute(ROOT)
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output != null:
			var encoded: Variant = BuildingCodec.encode(jobs)
			output.store_var({"source": source, "requests": payload, "jobs": encoded,
				"checksum": var_to_bytes(encoded).hex_encode().sha256_text()})
	return jobs


static func valid_jobs(value: Variant, requests: Array[BuildingRequest]) -> bool:
	if not value is Array or value.size() != requests.size(): return false
	for i in requests.size():
		var row: Variant = value[i]
		if not row is Dictionary: return false
		for field in ["request", "placement", "footprint", "bounds_rect", "half_w", "over", "back", "width", "depth", "order", "class"]:
			if not row.has(field): return false
		if not row["request"] is BuildingRequest or row["request"].to_json() != requests[i].to_json(): return false
		if int(row["order"]) != i or row["class"] != VillageLotPlanner.lot_class(requests[i]): return false
		if not row["placement"] is Dictionary or not row["footprint"] is Rect2 or not row["bounds_rect"] is Rect2: return false
		var placement: Dictionary = row["placement"]
		if not placement.get("bounds") is AABB or not placement.get("footprint") is Rect2 or not placement.get("door") is Vector3: return false
		if placement["footprint"] != row["footprint"] or row["footprint"].size.x <= 0 or row["footprint"].size.y <= 0: return false
		for field in ["half_w", "over", "back", "width", "depth"]:
			if typeof(row[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(row[field])) or float(row[field]) < 0: return false
	return true


static func source_hash() -> String:
	if not _source.is_empty(): return _source
	var paths: Array[String] = ["res://project.godot", "res://assets/props/catalog.json",
		"res://tests/fixtures/native_measurement_cache.gd"]
	for root in ["res://core", "res://src", "res://qa"]: _sources(root, paths)
	paths.sort()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(("native-measurement-cache-v1\n" + JSON.stringify(Engine.get_version_info())).to_utf8_buffer())
	for path in paths:
		hash.update(path.to_utf8_buffer())
		hash.update(FileAccess.get_file_as_bytes(path))
	# The native measurement wrapper also derives lot dimensions/classes.
	# Hash those functions without invalidating native jobs for siting edits.
	var capture := false
	for line in FileAccess.get_file_as_string("res://src/village/lot_planner.gd").split("\n"):
		if line.begins_with("static func "):
			capture = line.begins_with("static func measure(") or line.begins_with("static func measure_all(") or line.begins_with("static func lot_class(")
		if capture: hash.update((line + "\n").to_utf8_buffer())
	_source = hash.finish().hex_encode()
	return _source


static func _sources(root: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null: return
	for file in dir.get_files():
		if file.ends_with(".gd") and not file.begins_with("village_"):
			paths.append(root.path_join(file))
	for folder in dir.get_directories():
		if folder != "village": _sources(root.path_join(folder), paths)
