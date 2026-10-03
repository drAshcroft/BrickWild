class_name LibrarySuite
extends RefCounted

## Wall time per "family step", in ms. Always summarised in the suite notes
## (one line per family); the raw per-step lines are printed when the
## BRICK_WILD_TEST_TRACE environment variable is set.
static var _tm: Dictionary = {}

## The bounded selector (`libraryquick`) runs every rule once on the smallest
## sensible size of every family. The full suite keeps the production sizes
## and the extra independent generation for the determinism rules.
static var _quick := false

## What the first pass learned about each request, keyed "kind:seed", so the
## contract and document passes judge the SAME generation instead of paying
## for a fresh one per rule. A hotel generation is ~45 s of furnisher search;
## the suite used to make seven of them. Keys: made, mesh, pa (placement),
## again, again_mesh, pb (the second independent generation, full run only).
static var _cache: Dictionary = {}


static func _lap(family: Variant, step: String, started: int) -> void:
	var key := "%s %s" % [String(family), step]
	_tm[key] = int(_tm.get(key, 0)) + Time.get_ticks_msec() - started
	if OS.get_environment("BRICK_WILD_TEST_TRACE") != "":
		print("[library] %s +%d ms" % [key, Time.get_ticks_msec() - started])


static func _notes(res: SuiteResult) -> void:
	var by_family := {}
	for key in _tm:
		var parts: PackedStringArray = String(key).split(" ", true, 1)
		var row: Array = by_family.get(parts[0], [])
		row.append("%s %.1fs" % [parts[1], float(_tm[key]) / 1000.0])
		by_family[parts[0]] = row
	for family in by_family:
		var total := 0
		for key in _tm:
			if String(key).begins_with(String(family) + " "):
				total += int(_tm[key])
		res.note("time %s %.1fs: %s" % [family, total / 1000.0, ", ".join(by_family[family])])
## Public API contract: the facade preserves every existing family pipeline,
## rejects invalid requests cleanly, and keeps generation separate from mesh
## emission.


static func run() -> SuiteResult:
	return _run(false)


## `libraryquick`: every kind the library publishes, every contract rule, once.
static func run_quick() -> SuiteResult:
	return _run(true)


static func _key(request: BuildingRequest) -> String:
	return "%s:%d" % [String(request.kind), request.seed]


static func _run(quick: bool) -> SuiteResult:
	var res := SuiteResult.new("libraryquick" if quick else "library")
	_quick = quick
	_cache.clear()
	var requests: Array[BuildingRequest] = [
		BuildingRequest.church(101, &"gothic", 10.0, 22.0, 12.0),
		BuildingRequest.castle(202, &"norman", 55.0, 50.0, 18.0),
		BuildingRequest.house(303, &"cottage", &"none", 9.0, 12.0, 2.6),
		BuildingRequest.shop(353, &"blacksmith", &"longhall", 11.0, 14.0, 2.8),
		BuildingRequest.hotel(373, &"grand_budapest", 48.0, 24.0, 3.6),
		BuildingRequest.temple(404, &"basilica", &"blood", 26.0, 44.0, 12.0),
		BuildingRequest.windmill(505, &"tower", 13.0, 6.5, 14.0),
		BuildingRequest.windmill(515, &"paddle", 10.0, 6.5, 12.0),
	]
	if quick:
		# the smallest hotel the library accepts: still the whole programme
		# the smallest castle that is still an enclosed castle: below ~46 m the
		# generator makes an open manor whose door is recessed (see placement)
		requests[1] = BuildingRequest.castle(202, &"norman", 48.0, 42.0, 18.0)
		requests[4] = BuildingRequest.hotel(373, &"grand_budapest", 30.0, 16.0, 3.0)
	_tm.clear()
	for request in requests:
		_check_family(res, request)

	var unknown := BuildingRequest.church(1)
	unknown.kind = &"shed"
	_check_invalid(res, unknown, &"unknown_kind")
	var bad_style := BuildingRequest.church(1)
	bad_style.style = &"cardboard"
	_check_invalid(res, bad_style, &"unknown_style")
	var bad_trade := BuildingRequest.house(1)
	bad_trade.purpose = &"dragon_tamer"
	_check_invalid(res, bad_trade, &"unknown_trade")
	var bad_storeys := BuildingRequest.house(1)
	bad_storeys.storeys = 4
	_check_invalid(res, bad_storeys, &"storeys_out_of_range")
	var bad_business := BuildingRequest.shop(1)
	bad_business.purpose = &"dragon_tamer"
	_check_invalid(res, bad_business, &"unknown_business")
	var bad_size := BuildingRequest.temple(1)
	bad_size.width = 0.0
	_check_invalid(res, bad_size, &"invalid_dimension")
	var non_finite := BuildingRequest.castle(1)
	non_finite.height = INF
	_check_invalid(res, non_finite, &"invalid_dimension")
	var outside := BuildingRequest.church(1)
	outside.width = 5.9
	_check_invalid(res, outside, &"dimension_out_of_range")
	_check_invalid(res, null, &"request_required")

	_check_contract(res, requests)
	_check_documents(res, requests)
	_check_village_kind(res)
	_check_world_kind(res)
	_check_every_kind_covered(res, requests)
	_check_world_generic_envelope(res)

	var descriptor: Dictionary = BrickWild.describe_kind(&"house")
	res.checked += 1
	if descriptor.get("api_version") != BrickWild.API_VERSION \
			or (descriptor.get("styles", []) as Array).is_empty() \
			or (descriptor.get("purposes", []) as Array).is_empty() \
			or not descriptor.has("storeys"):
		res.fail("house descriptor is incomplete")
	descriptor["width"]["min"] = -1.0
	if BrickWild.describe_kind(&"house")["width"]["min"] < 0.0:
		res.fail("describe_kind returned mutable library state")

	# Storeys are an explicit house input and survive both the detached request
	# copy and the generated model. This deliberately stops before mesh emission:
	# the shell tests own the geometry contract, while this suite checks the API
	# and plan representation.
	var stacked_request := BuildingRequest.house(505, &"cottage", &"none",
		9.0, 12.0, 2.6, 2)
	var stacked_copy := stacked_request.copy()
	res.checked += 1
	if stacked_request.storeys != 2 or stacked_copy.storeys != 2:
		res.fail("house storeys did not survive request copy")
	var stacked: GeneratedBuilding = BrickWild.generate(stacked_request)
	res.checked += 1
	var stacked_spec: HouseSpec = stacked.spec as HouseSpec
	if not stacked.is_ok() or stacked_spec == null or stacked_spec.storeys != 2 \
			or stacked.plan == null:
		res.fail("two-storey house did not transfer storeys into its model")
	else:
		var plan: HousePlan = stacked.plan
		var floors := {}
		for room in plan.rooms:
			floors[int(room.get("storey", 0))] = true
		var exterior_upper := false
		for door in plan.doors:
			if door.get("storey", 0) > 0 and door["exterior"]:
				exterior_upper = true
		if floors.size() != 2 or plan.stairs.size() != 1 or exterior_upper \
				or plan.reachable_rooms(plan.entrance_room()).size() != plan.room_count():
			res.fail("two-storey plan lacks complete upper-floor circulation")
	_notes(res)
	return res


## The world families share one kind with no pre-facade pipeline and no house
## plan. The quick selector gives it the facade rules that apply: it
## generates, builds four surfaces, places its door on the -Z edge, round-trips
## a document and assembles. The envelope rules follow in
## _check_world_generic_envelope; the full suite leaves the families to `world`.
## The quick selector's promise is "every kind once". Keep it true: a kind
## added to BuildingLibrary.KINDS that this suite does not touch fails here.
static func _check_every_kind_covered(res: SuiteResult, requests: Array[BuildingRequest]) -> void:
	if not _quick:
		return
	var covered := {&"village": true, &"world": true}  # _check_village_kind, _check_world_kind
	for request in requests:
		covered[request.kind] = true
	for kind in BrickWild.kinds():
		res.checked += 1
		if not covered.has(kind):
			res.fail("libraryquick does not exercise the published kind '%s'" % String(kind))


static func _check_world_kind(res: SuiteResult) -> void:
	if not _quick:
		return
	var request := BrickWild.default_request(&"world", 828)
	request.style = &"insula"
	request.purpose = &"port_tenement"
	request.width = 30.0
	request.length = 24.0
	request.height = 15.0
	var t0 := Time.get_ticks_msec()
	var made: GeneratedBuilding = BrickWild.generate(request)
	_lap("world", "generate", t0)
	res.checked += 1
	if not made.is_ok():
		res.fail("world: insula did not generate: %s" % made.errors)
		return
	t0 = Time.get_ticks_msec()
	var mesh: ArrayMesh = BrickWild.build_mesh(made)
	_lap("world", "build", t0)
	res.checked += 1
	if mesh == null or mesh.get_surface_count() != 4:
		res.fail("world: the mesh does not have four surfaces")
	var placement: Dictionary = BrickWild.placement(made)
	var fp: Rect2 = placement.get("footprint", Rect2())
	var door: Vector3 = placement.get("door", Vector3.ZERO)
	res.checked += 1
	if placement.get("kind") != &"world" or placement.get("front") != Vector3(0.0, 0.0, -1.0) 			or absf(door.z - fp.position.y) > 0.6:
		res.fail("world: placement identity, front or door is wrong: %s" % placement)
	var doc: BuildingDocument = BrickWild.generate_document(request)
	res.checked += 1
	if doc == null or not doc.is_ok() or doc.placement != placement 			or not (JSON.parse_string(JSON.stringify(doc.to_dict())) is Dictionary):
		res.fail("world: the document differs from the generation or is not plain data")
	t0 = Time.get_ticks_msec()
	var scene: Node3D = BrickWild.instantiate(made, true)
	_lap("world", "instantiate", t0)
	res.checked += 1
	if scene == null:
		res.fail("world: the family assembled to nothing")
	else:
		scene.free()


static func _check_world_generic_envelope(res: SuiteResult) -> void:
	var descriptor: Dictionary = BrickWild.describe_kind(&"world")
	var tower_envelope: Dictionary = WorldFamilies.envelope(&"tower_house")
	var tower_max := float(tower_envelope["height"]["max"])
	res.checked += 1
	if float(descriptor["height"]["max"]) < tower_max:
		res.fail("world generic height envelope does not include registered tower families")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"tower_house"
	request.purpose = &"merchant_tower"
	var width_max := float(tower_envelope["width"]["max"])
	var length_max := float(tower_envelope["length"]["max"])
	request.width = width_max + 0.000001
	request.length = length_max + 0.000001
	request.height = tower_max
	res.checked += 1
	if not BuildingLibrary.validate(request).is_empty():
		res.fail("tower dimensions with float-scale endpoint drift were refused")
	request.height = tower_max + 0.01
	var failures := BuildingLibrary.validate(request)
	res.checked += 1
	if not _has_dimension_failure(failures, &"height"):
		res.fail("tower family height above its envelope was not rejected")
	request.height = tower_max
	request.width = width_max + 0.01
	res.checked += 1
	if not _has_dimension_failure(BuildingLibrary.validate(request), &"width"):
		res.fail("tower family width 0.01 m above its envelope was not rejected")
	request.width = width_max
	request.length = length_max + 0.01
	res.checked += 1
	if not _has_dimension_failure(BuildingLibrary.validate(request), &"length"):
		res.fail("tower family length 0.01 m above its envelope was not rejected")


static func _has_dimension_failure(failures: Array[Dictionary], field: StringName) -> bool:
	return failures.any(func(failure: Dictionary) -> bool:
		return failure.get("code", &"") == &"dimension_out_of_range" \
			and failure.get("field", &"") == field)


## VIL-019: a village asked for like any other building.
##
## Its two numbers ride on `width` and `length` -- a population and a wealth,
## not metres -- and the descriptor's `width_label`/`length_label` say so.
## Everything else about it is the same contract every family keeps: it
## generates, it builds a mesh, its placement puts its door on the -Z edge of
## its own footprint, and it assembles to a scene.
static func _check_village_kind(res: SuiteResult) -> void:
	res.checked += 1
	if not &"village" in BrickWild.kinds():
		res.fail("village: the kind is not registered")
		return
	var d: Dictionary = BrickWild.describe_kind(&"village")
	res.checked += 1
	if d.get("width_label", "") != "Population" or d.get("style_label") != "Culture" 			or (d.get("styles", []) as Array).size() != VillageSpec.CULTURES.size() 			or (d.get("purposes", []) as Array).size() != VillageSpec.PURPOSES.size():
		res.fail("village: the descriptor does not publish its own controls: %s" % d)
	# a population out of range is refused in the village's own words
	var small: BuildingRequest = BrickWild.default_request(&"village", 1)
	small.width = 9.0
	var refused: GeneratedBuilding = BrickWild.generate(small)
	res.checked += 1
	if refused.is_ok() or not str(refused.errors).contains("Population"):
		res.fail("village: a population of 9 was not refused in its own words: %s"
			% refused.errors)

	var request: BuildingRequest = BrickWild.default_request(&"village", 9101)
	request.style = &"english"
	request.purpose = &"farming"
	request.width = 12.0 if _quick else 40.0
	var t0 := Time.get_ticks_msec()
	var made: GeneratedBuilding = BrickWild.generate(request)
	_lap("village", "generate", t0)
	res.checked += 1
	if not made.is_ok() or made.village == null or made.village.buildings.is_empty():
		res.fail("village: the kind did not generate a village: %s" % made.errors)
		return
	res.checked += 1
	if made.representation() != made.village:
		res.fail("village: the generated representation is not its plan")
	t0 = Time.get_ticks_msec()
	var mesh: ArrayMesh = BrickWild.build_mesh(made)
	_lap("village", "build", t0)
	res.checked += 1
	if mesh == null or mesh.get_surface_count() == 0:
		res.fail("village: the kind emitted no mesh")
	var pl: Dictionary = BrickWild.placement(made)
	res.checked += 1
	if pl.get("kind") != &"village" or pl.get("front") != Vector3(0.0, 0.0, -1.0):
		res.fail("village: placement identity or orientation is wrong: %s" % pl)
	var fp: Rect2 = pl.get("footprint", Rect2())
	var door: Vector3 = pl.get("door", Vector3.ZERO)
	res.checked += 1
	if absf(door.z - fp.position.y) > 0.6:
		res.fail("village: its gate is %.2fm off the -Z edge of its own site"
			% (door.z - fp.position.y))
	t0 = Time.get_ticks_msec()
	var scene: Node3D = BrickWild.instantiate(made)
	_lap("village", "instantiate", t0)
	res.checked += 1
	if scene == null or scene.get_node_or_null("Buildings") == null:
		res.fail("village: the kind assembled to nothing")
	if scene != null:
		scene.free()


## API-003, the middle stage: a document is the same building as the
## generation it came from -- same mesh vertex for vertex, same placement --
## and it is plain enough to serialise. Parity is the whole point: a document
## that re-derives anything is a second generator, and two generators drift.
static func _check_documents(res: SuiteResult, requests: Array[BuildingRequest]) -> void:
	for request in requests:
		var where := "kind=%s seed=%d" % [String(request.kind), request.seed]
		var t0 := Time.get_ticks_msec()
		var doc: BuildingDocument = BrickWild.generate_document(request)
		_lap(request.kind, "documents", t0)
		# the first pass's generation, judged again here rather than rebuilt
		var entry: Dictionary = _cache.get(_key(request), {})
		var made: GeneratedBuilding = entry.get("made")
		if made == null:
			made = BrickWild.generate(request)
		res.checked += 1
		if doc == null or not doc.is_ok():
			res.fail("document: %s did not generate: %s" % [where, doc.errors if doc else "null"])
			continue
		if doc.kind() != request.kind or doc.name() != made.name():
			res.fail("document: identity differs from the generation, " + where)
		# the payload IS the family's own object -- the plan for a plan
		# family, the spec for the rest -- and not a copy of one. (Identity
		# against `made` would be wrong: `made` is a second generation, so a
		# second object; what matters is that the document did not build a
		# third representation of its own.)
		var want_plan: bool = request.kind in [&"house", &"shop", &"hotel"]
		if want_plan and (doc.plan == null or doc.payload() != doc.plan):
			res.fail("document: a %s carries no plan as its payload, %s"
				% [String(request.kind), where])
		elif not want_plan and (doc.plan != null or doc.payload() != doc.spec):
			res.fail("document: a %s carries something other than its spec, %s"
				% [String(request.kind), where])

		res.checked += 1
		var made_mesh: ArrayMesh = entry.get("mesh")
		if made_mesh == null:
			made_mesh = BrickWild.build_mesh(made)
		var made_placement: Dictionary = entry.get("pa", {})
		if made_placement.is_empty():
			made_placement = BrickWild.placement(made)
		if not _same_mesh(BrickWild.build_mesh(doc), made_mesh):
			res.fail("document: builds a different mesh from its own generation, " + where)
		res.checked += 1
		if doc.placement != made_placement:
			res.fail("document: placement differs from the generation's, " + where)
		# two independent generations of one request furnish identically
		if want_plan and doc.plan != null and made.plan != null:
			res.checked += 1
			if doc.plan.furniture != made.plan.furniture:
				res.fail("document: furnishing differs from the generation's, " + where)

		# plain enough to leave the process: JSON must take it whole, and what
		# comes back must still name the same building
		res.checked += 1
		var text: String = JSON.stringify(doc.to_dict())
		var back: Variant = JSON.parse_string(text)
		if not (back is Dictionary):
			res.fail("document: to_dict() did not survive JSON, " + where)
		elif back["name"] != doc.name() or back["kind"] != String(request.kind) \
				or int(back["seed"]) != request.seed or not bool(back["ok"]):
			res.fail("document: the serialised document names another building, " + where)
		elif not back.has("placement") or not back.has("spec"):
			res.fail("document: the serialised document has no placement or spec, " + where)
		elif request.kind in [&"house", &"shop", &"hotel"]:
			var plan_dict: Dictionary = back.get("plan", {})
			if (plan_dict.get("rooms", []) as Array).size() != made.plan.room_count() \
					or (plan_dict.get("doors", []) as Array).size() != made.plan.doors.size() \
					or (plan_dict.get("furniture", []) as Array).size() != made.plan.furniture.size():
				res.fail("document: the serialised plan lost rooms, doors or furniture, " + where)
		elif back.has("plan"):
			res.fail("document: a %s carries a house plan" % String(request.kind))

	# a refused request is a document that says why and builds nothing
	var bad := BuildingRequest.house(1)
	bad.purpose = &"dragon_tamer"
	var refused: BuildingDocument = BrickWild.generate_document(bad)
	res.checked += 1
	if refused.is_ok() or refused.errors.is_empty() or BrickWild.build_mesh(refused) != null:
		res.fail("document: an invalid request produced a buildable document")
	elif not refused.placement.is_empty():
		res.fail("document: a refused document carries a placement")


static func _check_family(res: SuiteResult, request: BuildingRequest) -> void:
	var before := _request_fingerprint(request)
	var t0 := Time.get_ticks_msec()
	var made: GeneratedBuilding = BrickWild.generate(request)
	_lap(request.kind, "generate", t0)
	res.checked += 1
	var where := "kind=%s seed=%d" % [String(request.kind), request.seed]
	if not made.is_ok():
		res.fail("facade rejected valid request, %s: %s" % [where, made.errors])
		return
	if _request_fingerprint(request) != before:
		res.fail("facade mutated its request, " + where)
	if made.request == request:
		res.fail("facade retained caller-owned request, " + where)
	if made.spec.get("seed") != request.seed or made.name().is_empty():
		res.fail("generated identity is incomplete, " + where)
	# A family's spec names its three numbers in its own words -- a windmill's
	# are a sail span and a body -- and a generator may CLAMP them to what its
	# own type can be built as. One that clamps must still answer inside the
	# envelope the library published; one that does not must answer with exactly
	# what it was given.
	var fields: Array[StringName] = BuildingLibrary.dimension_fields(request.kind)
	var limits_row: Dictionary = BuildingLibrary.KIND_ROWS[request.kind]
	var clamps: bool = BuildingLibrary.clamps(request.kind)
	for i in range(BuildingLibrary.DIMENSIONS.size()):
		var field: StringName = fields[i]
		var got = made.spec.get(field)
		if got == null:
			res.fail("generated %s is missing, %s" % [String(field), where])
			continue
		if clamps:
			var band: Dictionary = limits_row[BuildingLibrary.DIMENSIONS[i]]
			if float(got) < float(band["min"]) - 0.001 or float(got) > float(band["max"]) + 0.001:
				res.fail("generated %s is %.2f, outside the published envelope, %s"
					% [String(field), float(got), where])
		elif float(got) != float(request.get(BuildingLibrary.DIMENSIONS[i])):
			res.fail("generated %s differs from request, %s" % [String(field), where])
	if request.kind in [&"house", &"shop", &"hotel"]:
		if made.plan == null or made.plan.spec != made.spec:
			res.fail("house result did not retain its plan, " + where)
	elif made.plan != null:
		res.fail("non-house result unexpectedly has a house plan, " + where)

	t0 = Time.get_ticks_msec()
	var mesh: ArrayMesh = BrickWild.build_mesh(made)
	_lap(request.kind, "build", t0)
	t0 = Time.get_ticks_msec()
	var legacy: Array = _legacy(request)
	_lap(request.kind, "legacy", t0)
	# A family declares how many surfaces its mesh carries; four is nearly
	# everyone's, and a mill has a fifth because its iron is not its thatch.
	# A mill with no race draws no water, and an empty TRAILING surface moves
	# nothing, so the count may be lower than declared but never higher.
	var surfaces: int = mesh.get_surface_count() if mesh != null else 0
	var declared: int = BuildingLibrary.surface_count(request.kind)
	if surfaces < 1 or surfaces > declared:
		res.fail("facade emitted a bad mesh (%d surfaces, the family declares %d), %s"
			% [surfaces, declared, where])
	elif legacy.is_empty():
		pass  # the world families have no pre-facade pipeline to compare with
	elif not _same_mesh(mesh, legacy[2]):
		res.fail("facade mesh differs from legacy pipeline, " + where)
	if request.kind in [&"house", &"shop", &"hotel"]:
		var old_plan: HousePlan = legacy[1]
		if made.plan.rooms != old_plan.rooms or made.plan.doors != old_plan.doors \
				or made.plan.windows != old_plan.windows \
				or made.plan.furniture != old_plan.furniture \
				or made.plan.compromises != old_plan.compromises:
			res.fail("facade house plan differs from legacy pipeline, " + where)

	# A second independent generation of the same request. The full suite makes
	# it here; the quick selector leaves the determinism rules to the document
	# pass, whose generate_document() is a second independent generation.
	var entry := {"made": made, "mesh": mesh}
	if not _quick:
		t0 = Time.get_ticks_msec()
		var again: GeneratedBuilding = BrickWild.generate(request)
		_lap(request.kind, "generate", t0)
		t0 = Time.get_ticks_msec()
		var again_mesh: ArrayMesh = BrickWild.build_mesh(again)
		_lap(request.kind, "build", t0)
		if made.name() != again.name() or not _same_mesh(mesh, again_mesh):
			res.fail("facade is not deterministic, " + where)
		if request.kind in [&"house", &"shop", &"hotel"] and made.plan.furniture != again.plan.furniture:
			res.fail("facade furnishing is not deterministic, " + where)
		entry["again"] = again
		entry["again_mesh"] = again_mesh

	# Dispatch follows the retained representation, not the mutable request
	# snapshot a caller receives for diagnostics.
	var generated_kind: StringName = made.request.kind
	made.request.kind = &"temple" if generated_kind != &"temple" else &"church"
	if not _same_mesh(mesh, BrickWild.build_mesh(made)):
		res.fail("mutating the request snapshot broke mesh dispatch, " + where)
	made.request.kind = generated_kind
	var placement: Dictionary = BrickWild.placement(made)
	entry["pa"] = placement
	_cache[_key(request)] = entry
	var bounds: AABB = placement.get("bounds", AABB())
	if placement.get("kind") != request.kind or placement.get("seed") != request.seed \
			or placement.get("front") != Vector3(0.0, 0.0, -1.0):
		res.fail("placement identity or orientation is incomplete, " + where)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		res.fail("placement bounds are empty, " + where)

	t0 = Time.get_ticks_msec()
	var scene_a: Node3D = BrickWild.instantiate(made, true, true)
	var scene_b: Node3D = BrickWild.instantiate(made, true)
	_lap(request.kind, "instantiate", t0)
	if scene_a == null or scene_b == null or scene_a == scene_b:
		res.fail("facade did not create fresh scene instances, " + where)
	elif request.kind in [&"house", &"shop", &"hotel"] and scene_a.get_node_or_null("Furniture") == null:
		res.fail("assembled house omitted its furniture, " + where)
	elif request.kind == &"temple" and scene_a.get_node_or_null("Dressing") == null:
		res.fail("assembled temple omitted its dressing, " + where)
	if scene_a != null:
		if not scene_a.has_meta(&"brick_wild") \
				or scene_a.get_meta(&"brick_wild_kind") != request.kind \
				or scene_a.find_child("*col", true, false) == null:
			res.fail("scene identity or collision is incomplete, " + where)
	if scene_a != null:
		scene_a.free()
	if scene_b != null:
		scene_b.free()


static func _legacy(request: BuildingRequest) -> Array:
	match request.kind:
		&"church":
			var spec := ChurchSpec.new()
			_copy_inputs(request, spec)
			ChurchGenerator.generate(spec, request.seed)
			return [spec, null, ChurchBuilder.new().build(spec)]
		&"castle":
			var spec := CastleSpec.new()
			_copy_inputs(request, spec)
			CastleGenerator.generate(spec, request.seed)
			return [spec, null, CastleBuilder.new().build(spec)]
		&"house":
			var spec := HouseSpec.new()
			_copy_inputs(request, spec)
			spec.trade = request.purpose
			var plan: HousePlan = HouseGenerator.generate(spec, request.seed)
			return [spec, plan, HouseBuilder.new().build(plan)]
		&"shop":
			var spec := ShopSpec.new()
			_copy_inputs(request, spec)
			spec.business = request.purpose
			var plan: HousePlan = ShopGenerator.generate(spec, request.seed)
			return [spec, plan, HouseBuilder.new().build(plan)]
		&"hotel":
			var spec := HotelSpec.new()
			_copy_inputs(request, spec)
			var plan: HousePlan = HotelGenerator.generate(spec, request.seed)
			return [spec, plan, HotelBuilder.new().build(plan)]
		&"temple":
			var spec := TempleSpec.new()
			spec.form = request.style
			spec.cult = request.purpose
			spec.width = request.width
			spec.length = request.length
			spec.height = request.height
			TempleGenerator.generate(spec, request.seed)
			return [spec, null, TempleBuilder.new().build(spec)]
	return []


static func _copy_inputs(request: BuildingRequest, spec: RefCounted) -> void:
	spec.set("style", request.style)
	spec.set("width", request.width)
	spec.set("length", request.length)
	spec.set("height", request.height)


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a == null or b == null or a.get_surface_count() != b.get_surface_count():
		return false
	for surface in range(a.get_surface_count()):
		var aa: Array = a.surface_get_arrays(surface)
		var ba: Array = b.surface_get_arrays(surface)
		for slot in range(Mesh.ARRAY_MAX):
			if aa[slot] != ba[slot]:
				return false
	return true


static func _check_invalid(res: SuiteResult, request: BuildingRequest,
		want_code: StringName) -> void:
	var made: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if made.is_ok() or made.errors.is_empty():
		res.fail("invalid request succeeded: %s" % String(want_code))
		return
	for error in made.errors:
		if error["code"] == want_code:
			if BrickWild.build_mesh(made) != null:
				res.fail("invalid request emitted a mesh: %s" % String(want_code))
			return
	res.fail("invalid request did not report %s: %s" % [String(want_code), made.errors])


static func _request_fingerprint(request: BuildingRequest) -> Array:
	return [request.kind, request.seed, request.style, request.purpose,
		request.width, request.length, request.height]


## The compatibility contract README.md promises: the version on every
## descriptor and placement, four surfaces in one order, the front on -Z with
## the door on the footprint's -Z edge, and the same request generated twice
## giving the same placement, name and mesh.
static func _check_contract(res: SuiteResult, requests: Array[BuildingRequest]) -> void:
	res.checked += 1
	if BrickWild.API_VERSION != 2:
		res.fail("contract: API_VERSION is %d; README documents 2" % BrickWild.API_VERSION)
	for kind in BrickWild.kinds():
		res.checked += 1
		var d: Dictionary = BrickWild.describe_kind(kind)
		if d.get("api_version") != BrickWild.API_VERSION or not d.has("styles") \
				or not d.has("width") or not d.has("length") or not d.has("height"):
			res.fail("contract: describe_kind(%s) lacks the version or an envelope" % String(kind))
	var world: Dictionary = BrickWild.describe_kind(&"world")
	res.checked += 1
	if not world.has("families"):
		res.fail("contract: the world descriptor lists no families field")
	var no_family := BuildingRequest.new()
	no_family.kind = &"world"
	no_family.style = &"no_such_family"
	no_family.width = 10.0
	no_family.length = 10.0
	no_family.height = 5.0
	_check_invalid(res, no_family, &"unknown_family")
	for request in requests:
		# The first pass's two independent generations; the quick selector has
		# one, and the document pass proves the second (same mesh, same placement).
		var t0 := Time.get_ticks_msec()
		var entry: Dictionary = _cache.get(_key(request), {})
		var a: GeneratedBuilding = entry.get("made")
		var b: GeneratedBuilding = entry.get("again")
		if a == null:
			a = BrickWild.generate(request)
		if b == null and not _quick:
			b = BrickWild.generate(request)
		_lap(request.kind, "contract", t0)
		res.checked += 1
		if a == null or (b == null and not _quick) or not a.is_ok() or (b != null and not b.is_ok()):
			res.fail("contract: %s did not generate" % String(request.kind))
			continue
		var pa: Dictionary = entry.get("pa", {})
		if pa.is_empty():
			pa = BrickWild.placement(a)
		var pb: Dictionary = BrickWild.placement(b) if b != null else pa
		for key in ["api_version", "kind", "seed", "name", "bounds", "footprint", "front", "door"]:
			if not pa.has(key):
				res.fail("contract: placement(%s) has no %s" % [String(request.kind), key])
		if pa != pb:
			res.fail("contract: %s seed %d placed differently twice" % [String(request.kind), request.seed])
		if pa.get("front") != Vector3(0.0, 0.0, -1.0):
			res.fail("contract: %s's front is not -Z" % String(request.kind))
		var fp: Rect2 = pa.get("footprint", Rect2())
		var door: Vector3 = pa.get("door", Vector3.ZERO)
		if absf(door.z - fp.position.y) > 0.6:
			res.fail("contract: %s's door is %.2fm off the footprint's -Z edge" % [String(request.kind), door.z - fp.position.y])
		var mesh: ArrayMesh = entry.get("mesh")
		if mesh == null:
			mesh = BrickWild.build_mesh(a)
		var mesh_b: ArrayMesh = entry.get("again_mesh")
		if mesh_b == null and b != null:
			mesh_b = BrickWild.build_mesh(b)
		# A family declares how many surfaces its mesh carries; four is nearly
		# everyone's, and a mill has a fifth because its iron is not its thatch.
		# A mill with no race draws no water, and an empty TRAILING surface moves
		# nothing, so the count may be lower than declared but never higher.
		var surfaces: int = mesh.get_surface_count() if mesh != null else 0
		var declared: int = BuildingLibrary.surface_count(request.kind)
		if surfaces < 1 or surfaces > declared:
			res.fail("contract: %s's mesh has %d surfaces; its row declares %d"
				% [String(request.kind), surfaces, declared])
		elif mesh_b != null and not _same_mesh(mesh, mesh_b):
			res.fail("contract: %s seed %d built two different meshes" % [String(request.kind), request.seed])
