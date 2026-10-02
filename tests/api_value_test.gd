extends SceneTree
## Cheap boundary fixtures; no furnisher search, mesh emission, or assets.
const Exporter = preload("res://tools/export_building_plan.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var values := [Vector2(INF, INF), Vector3(1.25, -8.5, 0.001), Rect2(-3, 4, 5, 6),
		AABB(Vector3(-1, -2, -3), Vector3(4, 5, 6)), Color(0.1234567, 0.3, 0.7, 0.4),
		Transform3D(Basis(Vector3.UP, 0.25), Vector3(100, 0, -40)),
		PackedVector2Array([Vector2.ONE, Vector2.ZERO]), PackedVector3Array([Vector3.UP]),
		PackedInt64Array([9223372036854775807]), &"timber", {3: &"bedroom"}]
	for value in values:
		var codec := BuildingCodec.new()
		var decoded: Variant = codec.decode(JSON.parse_string(JSON.stringify(BuildingCodec.encode(value))))
		_expect(codec.errors.is_empty() and decoded == value, "lossless value %s" % type_string(typeof(value)))
		var plain: Variant = BuildingDocument._plain(value)
		var parser := JSON.new()
		_expect(parser.parse(JSON.stringify(plain)) == OK, "readable value is JSON-safe")
	var village := VillageSpec.new(818)
	village.generate(818)
	var doc := BuildingDocument.new()
	doc.request = BrickWild.default_request(&"village", 818)
	doc.spec = village
	doc.village = VillagePlan.new(village)
	doc.village.buildings.append({"request": BuildingRequest.house(1), "transform": Transform3D.IDENTITY})
	var text := doc.to_json()
	_expect(not "RefCounted#" in text and not '"rng"' in text, "no instance IDs or RNG state")
	var restored := BuildingDocument.from_json(text)
	_expect(restored.is_ok() and restored.to_json() == text, "village data roundtrip")
	_expect(restored.village.spec == restored.spec, "village shared spec identity")
	var codec := BuildingCodec.new()
	codec.decode({"type": "Node3D", "fields": {}})
	_expect(not codec.errors.is_empty(), "runtime object type refused")
	var wrong := doc.to_dict()
	wrong["state"] = BuildingCodec.encode({"spec": BuildingRequest.house(1), "placement": {}})
	_expect(not BuildingDocument.from_dict(wrong).is_ok(), "request cannot masquerade as spec")
	var disconnected := {"rooms": [
		{"room_id": "a", "storey": 0, "rect_m": [0, 0, 2, 2]},
		{"room_id": "b", "storey": 1, "rect_m": [0, 0, 2, 2]}],
		"entrance_door_id": "front", "doors": [
			{"door_id": "front", "between": ["a", "outside"]},
			{"door_id": "back", "between": ["b", "outside"]}], "stairs": []}
	var defects := Exporter.validate(disconnected, {"rect_m": [0, 0, 4, 4]})
	_expect(defects.any(func(e): return e["code"] == "unreachable_room"), "front route required")
	_expect(defects.any(func(e): return e["code"] == "missing_stair"), "stair required")
	for fail in failures: print("FAIL " + fail)
	print("api_values: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
