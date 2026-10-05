extends RefCounted
## Public request and C1 transport coverage for village decoration/upkeep.
## Classless fixture invoked directly by the bounded test runner.

const EXPORTER := preload("res://tools/export_village_plan.gd")

static func run() -> SuiteResult:
	var res := SuiteResult.new("village decoration/upkeep API")
	var descriptor: Dictionary = BrickWild.describe_kind(&"village")
	var decoration: Dictionary = descriptor.get("decoration_level", {})
	var upkeep: Dictionary = descriptor.get("upkeep", {})
	_expect(res, decoration.get("min_label") == "Bare / basic" \
		and decoration.get("max_label") == "Lush / storybook" \
		and float(decoration.get("value", -1.0)) == 0.5,
		"village descriptor does not publish decoration endpoints/default")
	_expect(res, upkeep.get("min_label") == "Worn / slum" \
		and upkeep.get("max_label") == "Clean" \
		and float(upkeep.get("value", -1.0)) == 1.0,
		"village descriptor does not publish upkeep endpoints/default")

	# The old sixth positional argument remains compact_display. New controls
	# follow it so existing factory calls keep their meaning.
	var old_call := BuildingRequest.village(701, 40, &"english", &"market", 0.4, true)
	_expect(res, old_call.compact_display and old_call.decoration_level == 0.5 \
		and old_call.upkeep == 1.0,
		"appending controls changed the existing village factory argument order")
	var request := BuildingRequest.village(702, 12, &"east_asian", &"market",
		0.4, true, 0.2, 0.35)
	var copied := request.copy()
	_expect(res, copied.decoration_level == 0.2 and copied.upkeep == 0.35,
		"request copy lost decoration/upkeep")
	var restored := BuildingRequest.from_json(request.to_json())
	_expect(res, restored._decode_errors.is_empty() \
		and restored.decoration_level == 0.2 and restored.upkeep == 0.35,
		"request JSON round trip lost decoration/upkeep")
	var defaults := BuildingRequest.village(703)
	var default_fields: Dictionary = defaults.to_dict()
	_expect(res, not default_fields.has("decoration_level") and not default_fields.has("upkeep"),
		"default controls changed the legacy request JSON shape")
	var legacy := BuildingRequest.from_dict(default_fields)
	_expect(res, legacy.decoration_level == 0.5 and legacy.upkeep == 1.0,
		"legacy request without controls did not receive defaults")

	for field in [&"decoration_level", &"upkeep"]:
		for bad_value in [true, "0.5", null, INF]:
			var malformed: Dictionary = request.to_dict()
			malformed[field] = bad_value
			_expect(res, not BuildingRequest.from_dict(malformed)._decode_errors.is_empty(),
				"%s accepted malformed JSON value %s" % [field, str(bad_value)])
		var below := request.copy()
		below.set(field, -0.01)
		_expect(res, not BuildingLibrary.validate(below).is_empty(),
			"%s accepted a value below zero" % field)
		var above := request.copy()
		above.set(field, 1.01)
		_expect(res, not BuildingLibrary.validate(above).is_empty(),
			"%s accepted a value above one" % field)
		var nonfinite := request.copy()
		nonfinite.set(field, NAN)
		_expect(res, not BuildingLibrary.validate(nonfinite).is_empty(),
			"%s accepted NaN" % field)

	var wrong_kind := BrickWild.default_request(&"house", 704)
	wrong_kind.upkeep = 0.9
	_expect(res, not BuildingLibrary.validate(wrong_kind).is_empty(),
		"non-village request accepted a non-default upkeep")
	wrong_kind = BrickWild.default_request(&"house", 705)
	wrong_kind.decoration_level = 0.6
	_expect(res, not BuildingLibrary.validate(wrong_kind).is_empty(),
		"non-village request accepted a non-default decoration level")

	var generated: GeneratedBuilding = BrickWild.generate(request)
	_expect(res, generated.is_ok() and generated.spec is VillageSpec \
		and (generated.spec as VillageSpec).decoration_level == 0.2 \
		and (generated.spec as VillageSpec).upkeep == 0.35,
		"public generation did not carry independent village controls into VillageSpec")

	var raw := {"city_id": "controls", "seed": 706, "population": 40,
		"site_m": 400.0, "decoration_level": 0.23456, "upkeep": 0.34567}
	_expect(res, EXPORTER.request_errors(raw).is_empty(),
		"C1 exporter rejected valid normalized controls")
	var exported_spec: VillageSpec = EXPORTER.spec_from_request(raw, JSON.stringify(raw))
	_expect(res, is_equal_approx(exported_spec.decoration_level, 0.23456) \
		and is_equal_approx(exported_spec.upkeep, 0.34567),
		"C1 request mapping lost decoration/upkeep")
	var site_plan: Dictionary = EXPORTER.site_plan(VillagePlan.new(exported_spec), raw)
	_expect(res, is_equal_approx(float(site_plan.get("decoration_level", -1.0)), 0.235) \
		and is_equal_approx(float(site_plan.get("upkeep", -1.0)), 0.346),
		"C1 SitePlan did not transport decoration/upkeep at its three-decimal precision")
	for field in ["decoration_level", "upkeep"]:
		for bad_value in [true, "0.5", null, INF, -0.01, 1.01]:
			var invalid_raw: Dictionary = raw.duplicate()
			invalid_raw[field] = bad_value
			_expect(res, not EXPORTER.request_errors(invalid_raw).is_empty(),
				"C1 exporter accepted invalid %s=%s" % [field, str(bad_value)])

	return res


static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
