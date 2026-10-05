extends RefCounted
## Public request, serialization and dispatch contract for compact villages.

static func run() -> SuiteResult:
	var res := SuiteResult.new("compact village API")
	var request := BuildingRequest.compact_village(781, 40, &"english", &"market", 0.4)
	var copy := request.copy()
	res.checked += 1
	if not copy.compact_display:
		res.fail("BuildingRequest.copy lost compact_display")
	var descriptor: Dictionary = BrickWild.describe_kind(&"village")
	res.checked += 1
	if descriptor.get("compact_display", {}).get("available") != true \
			or descriptor["compact_display"].get("default") != false \
			or descriptor["compact_display"].get("requires", {}) != {"water": &"none", "enclosure": &"none"}:
		res.fail("village descriptor does not explain compact_display constraints")

	var round_trip := BuildingRequest.from_json(request.to_json())
	res.checked += 1
	if not round_trip._decode_errors.is_empty() or not round_trip.compact_display:
		res.fail("request JSON round trip lost compact_display")
	var legacy_data: Dictionary = request.to_dict()
	legacy_data.erase("compact_display")
	res.checked += 1
	if BuildingRequest.from_dict(legacy_data).compact_display:
		res.fail("request without compact_display did not preserve the false default")
	var ordinary_json: Dictionary = BrickWild.default_request(&"house", 780).to_dict()
	res.checked += 1
	if ordinary_json.has("compact_display"):
		res.fail("false compact_display changed existing request JSON shape")
	for bad_value in ["true", 1, null]:
		var malformed: Dictionary = request.to_dict()
		malformed["compact_display"] = bad_value
		res.checked += 1
		if BuildingRequest.from_dict(malformed)._decode_errors.is_empty():
			res.fail("non-boolean compact_display decoded without an error: %s" % str(bad_value))

	for invalid_field in [&"water", &"enclosure"]:
		var invalid_request := request.copy()
		invalid_request.set(invalid_field, &"pond" if invalid_field == &"water" else &"hedge")
		res.checked += 1
		if not BuildingLibrary.validate(invalid_request).any(func(error: Dictionary) -> bool:
			return error["code"] == &"invalid_compact_display"):
			res.fail("compact display accepted village %s=%s" % [invalid_field, invalid_request.get(invalid_field)])
	var other_kind := BrickWild.default_request(&"house", 782)
	other_kind.compact_display = true
	res.checked += 1
	if not BuildingLibrary.validate(other_kind).any(func(error: Dictionary) -> bool:
		return error["field"] == &"compact_display"):
		res.fail("non-village request accepted compact_display")

	var made: GeneratedBuilding = BrickWild.generate(round_trip)
	res.checked += 1
	if not made.is_ok() or not (made.spec is VillageSpec) \
			or not (made.spec as VillageSpec).compact_display \
			or made.village == null or not made.village.spec.compact_display:
		res.fail("generation did not propagate compact_display to the village plan")
	return res
