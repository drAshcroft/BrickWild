class_name LibrarySuite
extends RefCounted
## Public API contract: the facade preserves every existing family pipeline,
## rejects invalid requests cleanly, and keeps generation separate from mesh
## emission.


static func run() -> SuiteResult:
	var res := SuiteResult.new("library")
	var requests: Array[BuildingRequest] = [
		BuildingRequest.church(101, &"gothic", 10.0, 22.0, 12.0),
		BuildingRequest.castle(202, &"norman", 55.0, 50.0, 18.0),
		BuildingRequest.house(303, &"cottage", &"none", 9.0, 12.0, 2.6),
		BuildingRequest.shop(353, &"blacksmith", &"longhall", 11.0, 14.0, 2.8),
		BuildingRequest.hotel(373, &"grand_budapest", 48.0, 24.0, 3.6),
		BuildingRequest.temple(404, &"basilica", &"blood", 26.0, 44.0, 12.0),
	]
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

	var descriptor: Dictionary = BigGlade.describe_kind(&"house")
	res.checked += 1
	if descriptor.get("api_version") != BigGlade.API_VERSION \
			or (descriptor.get("styles", []) as Array).is_empty() \
			or (descriptor.get("purposes", []) as Array).is_empty() \
			or not descriptor.has("storeys"):
		res.fail("house descriptor is incomplete")
	descriptor["width"]["min"] = -1.0
	if BigGlade.describe_kind(&"house")["width"]["min"] < 0.0:
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
	var stacked: GeneratedBuilding = BigGlade.generate(stacked_request)
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
	return res


## API-003, the middle stage: a document is the same building as the
## generation it came from -- same mesh vertex for vertex, same placement --
## and it is plain enough to serialise. Parity is the whole point: a document
## that re-derives anything is a second generator, and two generators drift.
static func _check_documents(res: SuiteResult, requests: Array[BuildingRequest]) -> void:
	for request in requests:
		var where := "kind=%s seed=%d" % [String(request.kind), request.seed]
		var doc: BuildingDocument = BigGlade.generate_document(request)
		var made: GeneratedBuilding = BigGlade.generate(request)
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
		if not _same_mesh(BigGlade.build_mesh(doc), BigGlade.build_mesh(made)):
			res.fail("document: builds a different mesh from its own generation, " + where)
		res.checked += 1
		if doc.placement != BigGlade.placement(made):
			res.fail("document: placement differs from the generation's, " + where)

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
	var refused: BuildingDocument = BigGlade.generate_document(bad)
	res.checked += 1
	if refused.is_ok() or refused.errors.is_empty() or BigGlade.build_mesh(refused) != null:
		res.fail("document: an invalid request produced a buildable document")
	elif not refused.placement.is_empty():
		res.fail("document: a refused document carries a placement")


static func _check_family(res: SuiteResult, request: BuildingRequest) -> void:
	var before := _request_fingerprint(request)
	var made: GeneratedBuilding = BigGlade.generate(request)
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
	if made.spec.get("width") != request.width or made.spec.get("length") != request.length \
			or made.spec.get("height") != request.height:
		res.fail("generated dimensions differ from request, " + where)
	if request.kind in [&"house", &"shop", &"hotel"]:
		if made.plan == null or made.plan.spec != made.spec:
			res.fail("house result did not retain its plan, " + where)
	elif made.plan != null:
		res.fail("non-house result unexpectedly has a house plan, " + where)

	var mesh: ArrayMesh = BigGlade.build_mesh(made)
	var legacy: Array = _legacy(request)
	if mesh == null or mesh.get_surface_count() != 4:
		res.fail("facade emitted a bad mesh, " + where)
	elif not _same_mesh(mesh, legacy[2]):
		res.fail("facade mesh differs from legacy pipeline, " + where)
	if request.kind in [&"house", &"shop", &"hotel"]:
		var old_plan: HousePlan = legacy[1]
		if made.plan.rooms != old_plan.rooms or made.plan.doors != old_plan.doors \
				or made.plan.windows != old_plan.windows \
				or made.plan.furniture != old_plan.furniture \
				or made.plan.compromises != old_plan.compromises:
			res.fail("facade house plan differs from legacy pipeline, " + where)

	var again: GeneratedBuilding = BigGlade.generate(request)
	var again_mesh: ArrayMesh = BigGlade.build_mesh(again)
	if made.name() != again.name() or not _same_mesh(mesh, again_mesh):
		res.fail("facade is not deterministic, " + where)
	if request.kind in [&"house", &"shop", &"hotel"] and made.plan.furniture != again.plan.furniture:
		res.fail("facade furnishing is not deterministic, " + where)

	# Dispatch follows the retained representation, not the mutable request
	# snapshot a caller receives for diagnostics.
	var generated_kind: StringName = made.request.kind
	made.request.kind = &"temple" if generated_kind != &"temple" else &"church"
	if not _same_mesh(mesh, BigGlade.build_mesh(made)):
		res.fail("mutating the request snapshot broke mesh dispatch, " + where)
	made.request.kind = generated_kind
	var placement: Dictionary = BigGlade.placement(made)
	var bounds: AABB = placement.get("bounds", AABB())
	if placement.get("kind") != request.kind or placement.get("seed") != request.seed \
			or placement.get("front") != Vector3(0.0, 0.0, -1.0):
		res.fail("placement identity or orientation is incomplete, " + where)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		res.fail("placement bounds are empty, " + where)

	var scene_a: Node3D = BigGlade.instantiate(made, true, true)
	var scene_b: Node3D = BigGlade.instantiate(made, true)
	if scene_a == null or scene_b == null or scene_a == scene_b:
		res.fail("facade did not create fresh scene instances, " + where)
	elif request.kind in [&"house", &"shop", &"hotel"] and scene_a.get_node_or_null("Furniture") == null:
		res.fail("assembled house omitted its furniture, " + where)
	elif request.kind == &"temple" and scene_a.get_node_or_null("Dressing") == null:
		res.fail("assembled temple omitted its dressing, " + where)
	if scene_a != null:
		if not scene_a.has_meta(&"big_glade") \
				or scene_a.get_meta(&"big_glade_kind") != request.kind \
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
	var made: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if made.is_ok() or made.errors.is_empty():
		res.fail("invalid request succeeded: %s" % String(want_code))
		return
	for error in made.errors:
		if error["code"] == want_code:
			if BigGlade.build_mesh(made) != null:
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
	if BigGlade.API_VERSION != 1:
		res.fail("contract: API_VERSION is %d; README documents 1" % BigGlade.API_VERSION)
	for kind in BigGlade.kinds():
		res.checked += 1
		var d: Dictionary = BigGlade.describe_kind(kind)
		if d.get("api_version") != BigGlade.API_VERSION or not d.has("styles") \
				or not d.has("width") or not d.has("length") or not d.has("height"):
			res.fail("contract: describe_kind(%s) lacks the version or an envelope" % String(kind))
	var world: Dictionary = BigGlade.describe_kind(&"world")
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
		var a: GeneratedBuilding = BigGlade.generate(request)
		var b: GeneratedBuilding = BigGlade.generate(request)
		res.checked += 1
		if a == null or b == null or not a.is_ok() or not b.is_ok():
			res.fail("contract: %s did not generate" % String(request.kind))
			continue
		var pa: Dictionary = BigGlade.placement(a)
		var pb: Dictionary = BigGlade.placement(b)
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
		var mesh: ArrayMesh = BigGlade.build_mesh(a)
		if mesh == null or mesh.get_surface_count() != 4:
			res.fail("contract: %s's mesh does not have four surfaces" % String(request.kind))
		elif not _same_mesh(mesh, BigGlade.build_mesh(b)):
			res.fail("contract: %s seed %d built two different meshes" % [String(request.kind), request.seed])
