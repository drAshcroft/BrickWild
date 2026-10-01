extends RefCounted
## Small C1 boundary fixtures. No mesh, prop catalogue or long village sweep.

const EXPORTER := preload("res://tools/export_village_plan.gd")

static func run() -> SuiteResult:
	var result := SuiteResult.new("dmv site brief")
	_check_population(result)
	_check_temple_presence(result)
	_check_regime_seats(result)
	_check_language_and_palette(result)
	_check_kept_fractions(result)
	_check_refusals(result)
	return result


static func _base() -> Dictionary:
	return {
		"city_id": "site:brief-fixture", "seed": 42, "name": "Veld",
		"population": 80, "regime": "royal", "wealth": 400.0,
		"culture": "river-song", "tongue": "human", "site_m": 400,
		"terrain": {"elevation": 0.2, "slope": 0.04, "water_edges": [],
			"forest": 0.2, "fertility": 0.6, "rock": "limestone"},
		"buildings": {"temple": 0.0, "palisade": 0.0},
	}


static func _spec(request: Dictionary) -> VillageSpec:
	var spec: VillageSpec = EXPORTER.spec_from_request(request)
	spec.generate(spec.seed)
	return spec


static func _has_request(requests: Array[BuildingRequest], kind: StringName,
	purpose: StringName = &"") -> bool:
	for request in requests:
		if request.kind == kind and (purpose == &"" or request.purpose == purpose):
			return true
	return false


static func _check_population(result: SuiteResult) -> void:
	var small: VillageSpec = _spec(_base())
	var large_request: Dictionary = _base()
	large_request["population"] = 160
	var large: VillageSpec = _spec(large_request)
	var small_count: int = VillageProgrammer.programme(small).size()
	var large_count: int = VillageProgrammer.programme(large).size()
	result.checked += 1
	if large.population != 160 or large_count <= small_count:
		result.fail("population 160 produced %d requests; population 80 produced %d" % [large_count, small_count])
	result.checked += 1
	if small.population != 80:
		result.fail("population was changed from the brief")


static func _check_temple_presence(result: SuiteResult) -> void:
	var with_temple: Dictionary = _base()
	with_temple["buildings"] = {"temple": 0.25}
	var temple_requests: Array[BuildingRequest] = VillageProgrammer.programme(_spec(with_temple))
	var without_temple: Dictionary = _base()
	without_temple["culture"] = "ash"
	var plain_requests: Array[BuildingRequest] = VillageProgrammer.programme(_spec(without_temple))
	result.checked += 1
	if not _has_request(temple_requests, &"temple"):
		result.fail("positive temple kept fraction produced no temple")
	result.checked += 1
	if _has_request(plain_requests, &"temple"):
		result.fail("temple appeared without the temple key, including blighted culture")


static func _check_regime_seats(result: SuiteResult) -> void:
	for fixture in [
		["royal", &"castle", &""], ["council", &"shop", &"town_hall"],
		["theocracy", &"church", &""], ["military", &"castle", &""]]:
		var request: Dictionary = _base()
		request["regime"] = fixture[0]
		var spec: VillageSpec = _spec(request)
		var requests: Array[BuildingRequest] = VillageProgrammer.programme(spec)
		var seat_kind: StringName = StringName(fixture[1])
		var seat_purpose: StringName = StringName(fixture[2])
		result.checked += 1
		if not _has_request(requests, seat_kind, seat_purpose):
			result.fail("%s regime did not receive its %s seat" % [fixture[0], seat_kind])
		if fixture[0] == "military":
			result.checked += 1
			if spec.purpose != &"garrison":
				result.fail("military regime did not select garrison settlement form")


static func _check_language_and_palette(result: SuiteResult) -> void:
	var base: VillageSpec = _spec(_base())
	var tongue_request: Dictionary = _base()
	tongue_request["tongue"] = "orc"
	var tongue: VillageSpec = _spec(tongue_request)
	result.checked += 1
	if tongue.variant_name == base.variant_name or tongue.plant_palette == base.plant_palette:
		result.fail("tongue did not change local naming and plant palette")
	var culture_request: Dictionary = _base()
	culture_request["culture"] = "fjord"
	var culture: VillageSpec = _spec(culture_request)
	result.checked += 1
	if culture.variant_name == base.variant_name or culture.plant_palette == base.plant_palette:
		result.fail("culture did not change local naming and plant palette")
	result.checked += 1
	if tongue.population != base.population or tongue.wealth != base.wealth or tongue.regime != base.regime:
		result.fail("language-only change altered unrelated brief values")


static func _check_kept_fractions(result: SuiteResult) -> void:
	var small_request: Dictionary = _base()
	small_request["buildings"] = {"granary": 0.2, "palisade": 0.2}
	var large_request: Dictionary = _base()
	large_request["buildings"] = {"granary": 0.9, "palisade": 0.9}
	var small: VillageSpec = _spec(small_request)
	var large: VillageSpec = _spec(large_request)
	var small_shop := _request_width(VillageProgrammer.programme(small), &"shop",
		&"general_store", VillageProgrammer._seed_for(small, "brief|granary"))
	var large_shop := _request_width(VillageProgrammer.programme(large), &"shop",
		&"general_store", VillageProgrammer._seed_for(large, "brief|granary"))
	result.checked += 1
	if small.enclosure != &"palisade" or not is_equal_approx(small.enclosure_kept_fraction, 0.2):
		result.fail("palisade fraction was not retained by the authored edge")
	result.checked += 1
	if large_shop <= small_shop:
		result.fail("granary kept fraction did not change its authored building footprint")
	var palace_request: Dictionary = _base()
	palace_request["buildings"] = {"palace": 0.2}
	var palace_large: Dictionary = _base()
	palace_large["buildings"] = {"palace": 0.9}
	var small_palace: VillageSpec = _spec(palace_request)
	var large_palace: VillageSpec = _spec(palace_large)
	var small_castle: float = _request_width(VillageProgrammer.programme(small_palace),
		&"castle", &"", VillageProgrammer._seed_for(small_palace, "brief|seat|royal"))
	var large_castle: float = _request_width(VillageProgrammer.programme(large_palace),
		&"castle", &"", VillageProgrammer._seed_for(large_palace, "brief|seat|royal"))
	result.checked += 1
	if large_castle <= small_castle:
		result.fail("palace kept fraction did not change the authored seat footprint")
	result.checked += 1
	var half_run: Array = VillageBuilder._keep_fraction([[Vector2.ZERO, Vector2(10, 0)]], 0.4)
	var clipped_a: Vector2 = half_run[0][0] if not half_run.is_empty() else Vector2.ZERO
	var clipped_b: Vector2 = half_run[0][1] if not half_run.is_empty() else Vector2.ZERO
	if half_run.size() != 1 or not is_equal_approx(clipped_a.x, 3.0) \
			or not is_equal_approx(clipped_b.x, 7.0):
		result.fail("40% enclosure fraction did not leave physical gaps")


static func _request_width(requests: Array[BuildingRequest], kind: StringName,
		purpose: StringName, seed: int) -> float:
	for request in requests:
		if request.kind == kind and request.seed == seed \
				and (purpose == &"" or request.purpose == purpose):
			return request.width
	return 0.0


static func _check_refusals(result: SuiteResult) -> void:
	var too_many: Dictionary = _base()
	too_many["population"] = 501
	var steep: Dictionary = _base()
	steep["terrain"] = {"slope": 0.35}
	var too_small: Dictionary = _base()
	too_small["site_m"] = 60
	for fixture in [[too_many, "population"], [steep, "slope"], [too_small, "site_m"]]:
		var request: Dictionary = fixture[0]
		var field: String = fixture[1]
		var errors: Array[String] = EXPORTER.request_errors(request)
		result.checked += 1
		if errors.is_empty() or not errors[0].contains(field):
			result.fail("impossible brief was not explicitly refused for %s" % field)
