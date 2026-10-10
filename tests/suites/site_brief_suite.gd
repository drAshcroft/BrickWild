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
	_check_royal_hamlet_placed(result)
	_check_caller_size(result)
	_check_monuments_are_not_seats(result)
	_check_small_wall(result)
	_check_implied_programme(result)
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
		var castles := requests.filter(func(r: BuildingRequest) -> bool: return r.kind == &"castle").size()
		result.checked += 1
		if castles > 1:
			result.fail("%s regime asked for %d castles; a seat is the one castle" % [fixture[0], castles])
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


## A royal or military seat must stand in a hamlet, not cost it the whole
## plan. Below a manor's population it is a hold: the castle family's house
## tier. The 40 x 50 m castle's manor lot used to cross a field track at every
## candidate in a round village, so every royal brief of 20..60 people was
## refused with "only N of N+1 requested buildings fit" on a site with room to
## spare.
static func _check_royal_hamlet_placed(result: SuiteResult) -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/thorn-hamlet.json")
	for regime in ["royal", "military"]:
		for population in [30, 45, 60]:
			# The raw text carries mythsim's unsigned 64-bit seed, which a parsed
			# Dictionary loses: without it this is a different village from the
			# one the exporter plans.
			var raw := text.replace("\"population\": 26", "\"population\": %d" % population) \
				.replace("\"regime\": \"royal\"", "\"regime\": \"%s\"" % regime)
			var request: Dictionary = JSON.parse_string(raw)
			# Village QA stays on the two royal sizes it always ran on: the
			# military hamlet of 30 is 4.9% built against a 5.0% density floor,
			# which is open and does not stop the plan being written.
			_check_seat_placed(result, "%s hamlet of %d" % [regime, population], request, raw,
				true, regime == "royal" and population != 45)


## `hold` asks that the one castle be the seat at the house tier; a request
## whose great-tomb or ziggurat is also a castle mass cannot promise that.
static func _check_seat_placed(result: SuiteResult, label: String, request: Dictionary,
		raw: String, hold: bool, qa_rules: bool) -> void:
	var errors: Array[String] = EXPORTER.request_errors(request)
	result.checked += 1
	if not errors.is_empty():
		result.fail("%s refused: %s" % [label, "; ".join(errors)])
		return
	var spec: VillageSpec = EXPORTER.spec_from_request(request, raw)
	spec.generate(spec.seed)
	var wanted: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	var plan: VillagePlan = VillageLotPlanner.plan(spec)
	var castles := plan.buildings.filter(func(b: Dictionary) -> bool:
		return (b["request"] as BuildingRequest).kind == &"castle").size()
	for b in plan.buildings if hold else []:
		var seat: BuildingRequest = b["request"]
		result.checked += 1
		if seat.kind == &"castle" and CastleSpec.tier_for(seat.width, seat.length) != &"house":
			result.fail("%s: the seat is a %s, not a hold" % [
				label, CastleSpec.tier_for(seat.width, seat.length)])
	result.checked += 1
	if plan.buildings.size() < wanted.size() or (hold and castles != 1):
		result.fail("%s placed %d of %d buildings, %d castle(s)" % [
			label, plan.buildings.size(), wanted.size(), castles])
	result.checked += 1
	if plan.site.size.x > float(request["site_m"]) or plan.site.size.y > float(request["site_m"]):
		result.fail("%s needs a %s site, beyond %s m" % [label, plan.site.size, request["site_m"]])
	if not qa_rules:
		return
	var qa: Dictionary = VillageQA.new().check(plan, {}, false)
	result.checked += 1
	for failure in qa["failures"]:
		# Open for every C1 brief, whatever the regime, and not about
		# where the seat stands: `earned` (a brief's seat is not earned by
		# population), `culture` (the norse palette lacks a wild tree), and
		# `landmark` (whether a royal keep may out-top the shrine).
		var rule := String(failure).get_slice(":", 0)
		if rule in ["earned", "culture", "landmark"]:
			continue
		result.fail("%s: QA: %s" % [label, String(failure)])


## Schema 2's `population` is the people of the whole polity node, so the
## settlement's size comes from the caller. Fixtures are two real requests from
## Voxel_Build world genesis-000100-1024.
static func _check_caller_size(result: SuiteResult) -> void:
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/thaannafu-schema2.json")
	var node: Dictionary = JSON.parse_string(raw)
	var refusal: String = EXPORTER.population_error(node, "")
	result.checked += 1
	if refusal.is_empty() or not refusal.contains("--population"):
		result.fail("schema 2 without a caller size was not refused with a pointer to --population: '%s'" % refusal)
	var royal_raw := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/wuunafu-schema2.json")
	var royal_node: Dictionary = JSON.parse_string(royal_raw)
	result.checked += 1
	if EXPORTER.population_error(royal_node, "").is_empty():
		result.fail("a schema 2 request of %d node people was read as a village" % int(royal_node["population"]))
	for bad in ["sixty", "45.5", "-"]:
		result.checked += 1
		if EXPORTER.population_error(node, bad).is_empty():
			result.fail("--population '%s' was accepted" % bad)
	result.checked += 1
	if not EXPORTER.population_error(node, "45").is_empty():
		result.fail("schema 2 with --population 45 was refused")
	var notes: Array[String] = []
	var sized: Dictionary = EXPORTER.with_caller_population(node, "45", notes)
	var spec: VillageSpec = EXPORTER.spec_from_request(sized, raw)
	result.checked += 1
	if spec.population != 45 or int(node["population"]) != 2942190:
		result.fail("schema 2 with --population 45 planned %d people (node request now %d)" % [
			spec.population, int(node["population"])])
	result.checked += 1
	if notes.size() != 1 or not notes[0].contains("2942190"):
		result.fail("the caller's size did not leave a note naming the node population: %s" % [notes])
	_check_seat_placed(result, "Thaannafu (military, schema 2) at 45", sized, raw, false, false)
	var hamlet_raw := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/thorn-hamlet.json")
	var hamlet: Dictionary = JSON.parse_string(hamlet_raw)
	var kept: Array[String] = []
	result.checked += 1
	if not EXPORTER.population_error(hamlet, "").is_empty() 			or EXPORTER.with_caller_population(hamlet, "", kept) != hamlet or not kept.is_empty():
		result.fail("a schema 1 request without --population no longer plans its own population")
	var over: Dictionary = EXPORTER.with_caller_population(hamlet, "40", kept)
	result.checked += 1
	if int(over["population"]) != 40 or int(hamlet["population"]) != 26:
		result.fail("--population 40 did not override a schema 1 request's 26")


const THAAN := "res://tests/fixtures/site_requests/thaannafu-schema2.json"
const WUUN := "res://tests/fixtures/site_requests/wuunafu-schema2.json"


## One of the real Voxel_Build cities, sized as the exporter sizes it.
static func city_spec(path: String, visible: int, implied: String,
		notes: Array[String] = []) -> VillageSpec:
	var raw := FileAccess.get_file_as_string(path)
	var request: Dictionary = EXPORTER.with_implied_population(
		EXPORTER.with_caller_population(JSON.parse_string(raw), str(visible), notes), implied)
	var spec: VillageSpec = EXPORTER.spec_from_request(request, raw, notes)
	spec.generate(spec.seed)
	return spec


static func seats(spec: VillageSpec, requests: Array[BuildingRequest]) -> Array[BuildingRequest]:
	var out: Array[BuildingRequest] = []
	for r in requests:
		if r.kind == &"castle" and VillageProgrammer.monument_of(spec, r).is_empty():
			out.append(r)
	return out


static func monuments(spec: VillageSpec, requests: Array) -> Array[String]:
	var out: Array[String] = []
	for r in requests:
		var word: String = VillageProgrammer.monument_of(spec, r)
		if not word.is_empty():
			out.append(word)
	return out


static func _homes(requests: Array[BuildingRequest]) -> int:
	return requests.filter(func(r: BuildingRequest) -> bool: return r.kind == &"house").size()


static func _tier(request: BuildingRequest) -> StringName:
	return CastleSpec.tier_for(request.width, request.length)


## Owner decision 2026-10-10 (C1-MONUMENT-SEAT): a great-tomb or ziggurat is a
## monument and never the seat. Thaannafu kept a great-tomb and no palace; it
## used to get the tomb and no seat.
static func _check_monuments_are_not_seats(result: SuiteResult) -> void:
	for row in [[THAAN, 45, ["great-tomb"]], [WUUN, 60, ["great-tomb", "ziggurat"]]]:
		var label := "%s at %d" % [String(row[0]).get_file(), row[1]]
		var spec: VillageSpec = city_spec(row[0], row[1], "")
		var requests: Array[BuildingRequest] = VillageProgrammer.programme(spec)
		var seat: Array[BuildingRequest] = seats(spec, requests)
		result.checked += 1
		if seat.size() != 1:
			result.fail("%s asked for %d seats beside its monuments" % [label, seat.size()])
		elif _tier(seat[0]) != &"house":
			result.fail("%s: the seat is a %s, not a hold" % [label, _tier(seat[0])])
		result.checked += 1
		if str(monuments(spec, requests)) != str(row[2]):
			result.fail("%s monuments %s, wanted %s" % [label, monuments(spec, requests), row[2]])
		for r in requests:
			if VillageProgrammer.monument_of(spec, r).is_empty():
				continue
			result.checked += 1
			if _tier(r) != &"house":
				result.fail("%s: a monument of %d people is a %s mass" % [label, row[1], _tier(r)])


## Owner decision 2026-10-10 (C1-WALL-SMALL-ROYAL): below 150 people, counting
## the implied ones, a kept wall is a palisade and the brief is planned. A
## military regime keeps its wall; 150 implied people build the wall.
static func _check_small_wall(result: SuiteResult) -> void:
	var walled: Dictionary = _base()
	walled["buildings"] = {"stone-wall": 1.0}
	result.checked += 1
	if not EXPORTER.request_errors(walled).is_empty():
		result.fail("a royal brief of 80 with a kept wall was refused: %s" % [EXPORTER.request_errors(walled)])
	var notes: Array[String] = []
	var small: VillageSpec = EXPORTER.spec_from_request(walled, "", notes)
	result.checked += 1
	if small.enclosure != &"palisade" or not small.valid():
		result.fail("a royal brief of 80 kept enclosure '%s' (valid %s), wanted a palisade" % [
			small.enclosure, small.valid()])
	result.checked += 1
	if not notes.any(func(n: String) -> bool: return n.contains("palisade")):
		result.fail("the palisade in place of a kept wall left no note: %s" % [notes])
	var none: Array[String] = []
	var implied: VillageSpec = EXPORTER.spec_from_request(
		EXPORTER.with_implied_population(walled, "150"), "", none)
	result.checked += 1
	if implied.enclosure != &"wall" or not implied.valid():
		result.fail("80 shown and 150 implied kept '%s' (valid %s), wanted the wall" % [
			implied.enclosure, implied.valid()])
	var military: Dictionary = walled.duplicate(true)
	military["regime"] = "military"
	result.checked += 1
	if EXPORTER.spec_from_request(military).enclosure != &"wall":
		result.fail("a military brief of 80 lost its kept wall")
	var both: Dictionary = walled.duplicate(true)
	both["population"] = 160
	both["buildings"] = {"stone-wall": 1.0, "palisade": 1.0}
	result.checked += 1
	if EXPORTER.spec_from_request(both).enclosure != &"wall":
		result.fail("a city of 160 that kept a wall and a palisade alike is not walled")
	var thaan: VillageSpec = city_spec(THAAN, 45, "")
	var wuun: VillageSpec = city_spec(WUUN, 60, "")
	result.checked += 1
	if thaan.enclosure != &"wall" or wuun.enclosure != &"palisade":
		result.fail("military Thaannafu at 45 kept '%s' and royal Wuunafu at 60 kept '%s'" % [
			thaan.enclosure, wuun.enclosure])


static func _dicts(requests: Array[BuildingRequest]) -> Array:
	return requests.map(func(r: BuildingRequest) -> Dictionary: return r.to_dict())


## Owner decision 2026-10-10: the caller's implied population sizes the civic
## programme and never the homes. Past CIVIC_MAX it is the same programme.
static func _check_implied_programme(result: SuiteResult) -> void:
	for row in [[THAAN, 45, "4000", "2942190"], [WUUN, 60, "6000", "10614806"]]:
		var label := "%s at %d" % [String(row[0]).get_file(), row[1]]
		var shown: VillageSpec = city_spec(row[0], row[1], "")
		var notes: Array[String] = []
		var city: VillageSpec = city_spec(row[0], row[1], row[2], notes)
		var huge: VillageSpec = city_spec(row[0], row[1], row[3])
		var shown_requests: Array[BuildingRequest] = VillageProgrammer.programme(shown)
		var city_requests: Array[BuildingRequest] = VillageProgrammer.programme(city)
		var huge_requests: Array[BuildingRequest] = VillageProgrammer.programme(huge)
		result.checked += 1
		if city.population != row[1] or city.households != shown.households or _homes(city_requests) != _homes(shown_requests):
			result.fail("%s with %s implied planned %d homes for %d people; shown alone, %d" % [
				label, row[2], _homes(city_requests), city.population, _homes(shown_requests)])
		result.checked += 1
		if city.civic_population() != VillageSpec.CIVIC_MAX or huge.civic_population() != VillageSpec.CIVIC_MAX:
			result.fail("%s civic population %d / %d, wanted the cap %d" % [label,
				city.civic_population(), huge.civic_population(), VillageSpec.CIVIC_MAX])
		result.checked += 1
		if _dicts(city_requests) != _dicts(huge_requests):
			result.fail("%s: %s and %s implied people asked for different programmes past the cap" % [
				label, row[2], row[3]])
		var seat: Array[BuildingRequest] = seats(city, city_requests)
		result.checked += 1
		if seat.size() != 1 or _tier(seat[0]) == &"house":
			result.fail("%s with %s implied has %d seat(s), the first a hold" % [label, row[2], seat.size()])
		result.checked += 1
		if city.enclosure != &"wall":
			result.fail("%s with %s implied kept '%s', not the wall its history kept" % [
				label, row[2], city.enclosure])
		for hall in [&"town_hall", &"guildhall", &"butcher", &"tailor"]:
			result.checked += 1
			if not _has_request(city_requests, &"shop", hall):
				result.fail("%s with %s implied has no %s" % [label, row[2], hall])
		result.checked += 1
		if not notes.any(func(n: String) -> bool: return n.contains("implied %s people" % row[2])):
			result.fail("%s: the implied population left no note: %s" % [label, notes])
		var homes_serve_city := city_requests.any(func(r: BuildingRequest) -> bool:
			return r.kind == &"house" and VillageProgrammer.serves(city, r) != "visible")
		result.checked += 1
		if homes_serve_city or VillageProgrammer.serves(city, seat[0]) != "implied":
			result.fail("%s: a home serves the implied city or the seat serves the shown people" % label)
	var hamlet := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/thorn-hamlet.json")
	var plain: VillageSpec = EXPORTER.spec_from_request(JSON.parse_string(hamlet), hamlet)
	result.checked += 1
	if plain.implied_population != 0 or plain.civic_population() != plain.population:
		result.fail("a request without --implied-population has civic population %d for %d people" % [
			plain.civic_population(), plain.population])
	for bad in ["many", "-3", "4.5"]:
		result.checked += 1
		if EXPORTER.implied_error(bad).is_empty():
			result.fail("--implied-population '%s' was accepted" % bad)
	var negative: Dictionary = _base()
	negative["implied_population"] = -1
	result.checked += 1
	if EXPORTER.request_errors(negative).is_empty():
		result.fail("a request with implied_population -1 was accepted")
