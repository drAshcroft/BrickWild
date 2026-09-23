extends SceneTree
## Lossless state, malformed input, deterministic CLI contract and C2 semantics.

const Exporter = preload("res://tools/export_building_plan.gd")
const SiteExporter = preload("res://tools/export_village_plan.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var requests := [BuildingRequest.church(101), BuildingRequest.castle(202),
		BuildingRequest.house(303), BuildingRequest.shop(353), BuildingRequest.hotel(373),
		BuildingRequest.temple(404), BigGlade.default_request(&"world", 505)]
	for req in requests:
		print("Round trip: %s" % req.kind)
		var made := BigGlade.generate_document(req)
		_expect(made.is_ok(), "generate %s" % req.kind)
		if not made.is_ok(): continue
		var restored := BuildingDocument.from_json(made.to_json())
		_expect(restored.is_ok(), "restore %s: %s" % [req.kind, restored.errors])
		if not restored.is_ok(): continue
		_expect(restored.to_json() == made.to_json(), "byte round trip %s" % req.kind)
		_expect(_same_mesh(BigGlade.build_mesh(made), BigGlade.build_mesh(restored)), "mesh parity %s" % req.kind)
		if made.plan != null:
			_expect(restored.plan.spec == restored.spec, "spec identity %s" % req.kind)
			_expect(restored.plan.furniture == made.plan.furniture, "all furniture fields %s" % req.kind)
		# A changed derived value must survive: reconstruction must not regenerate.
		made.spec.set("variant_name", "The Crooked Lantern")
		_expect(BuildingDocument.from_json(made.to_json()).name() == "The Crooked Lantern", "edited state preserved")
	# Pure contract fixture: a back door cannot hide a room disconnected from
	# the front entrance, and missing inter-storey stairs must be diagnosed.
	var disconnected := {"rooms": [
		{"room_id": "a", "storey": 0, "rect_m": [0, 0, 2, 2]},
		{"room_id": "b", "storey": 1, "rect_m": [0, 0, 2, 2]}],
		"entrance_door_id": "front", "doors": [
			{"door_id": "front", "between": ["a", "outside"]},
			{"door_id": "back", "between": ["b", "outside"]}], "stairs": []}
	var defects := Exporter.validate(disconnected, {"rect_m": [0, 0, 4, 4]})
	_expect(defects.any(func(e): return e["code"] == "unreachable_room"), "back door does not mask disconnected front route")
	_expect(defects.any(func(e): return e["code"] == "missing_stair"), "missing consecutive-storey stair diagnosed")
	var huge := BuildingRequest.house(9223372036854775807)
	_expect(BuildingRequest.from_json(huge.to_json()).seed == huge.seed, "int64 seed survives JSON")
	for text in ['[]', '{"kind":"house","width":"wide"}', '{"kind":"house","storeys":1.5}', '{"kind":"house","seed":9007199254740994}', '{"kind":"house","schema_version":999}']:
		_expect(not BigGlade.generate(BuildingRequest.from_json(text)).is_ok(), "invalid request refused: " + text)
	_expect(not BuildingDocument.from_json('{"schema_version":999}').is_ok(), "unknown document schema")
	var bad := BigGlade.generate(BuildingRequest.from_json('{}'))
	_expect(not BigGlade.check(bad)["ok"], "invalid building diagnostic")
	var valid := BigGlade.generate(BuildingRequest.house(77))
	valid.plan.rooms[0]["rect"] = Rect2(999, 999, 2, 2)
	var report := BigGlade.check(valid)
	_expect(not report["ok"] and not report["diagnostics"].is_empty(), "functional QA catches displaced room")
	var village := VillageSpec.new(818)
	village.population = 30
	village.generate(818)
	var village_plan := VillageLotPlanner.plan(village)
	var site := SiteExporter.site_plan(village_plan, {"city_id": "site:transport-test", "seed": 818})
	var supported := 0
	var unsupported := 0
	for record in site["buildings"]:
		print("C2: %s %s" % [record["building_id"], record["kind"]])
		var output: Dictionary = Exporter.building_plan(site, record["building_id"])
		if record["kind"] not in ["house", "shop", "hotel"]:
			_expect(output.has("errors") and output["errors"][0]["code"] == "unsupported_interior", "unsupported interior is explicit")
			unsupported += 1
			continue
		supported += 1
		_expect(not output.has("errors"), "C2 export %s: %s" % [record["building_id"], output.get("errors", [])])
		_expect(JSON.stringify(output, "", true, true) == JSON.stringify(Exporter.building_plan(site, record["building_id"]), "", true, true), "C2 byte determinism")
		if not output.has("errors"):
			_expect(not output["rooms"].is_empty() and output["rooms"][0]["purpose"] != "room", "C2 carries room purpose")
	_expect(supported > 0, "C2 tested village interiors")
	print("Village interiors: %d supported, %d explicitly unsupported" % [supported, unsupported])
	for fail in failures: print("FAIL " + fail)
	print("api_transport: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a == null or b == null or a.get_surface_count() != b.get_surface_count(): return false
	for surface in range(a.get_surface_count()):
		if a.surface_get_arrays(surface) != b.surface_get_arrays(surface): return false
	return true
