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

	var descriptor: Dictionary = BigGlade.describe_kind(&"house")
	res.checked += 1
	if descriptor.get("api_version") != BigGlade.API_VERSION \
			or (descriptor.get("styles", []) as Array).is_empty() \
			or (descriptor.get("purposes", []) as Array).is_empty():
		res.fail("house descriptor is incomplete")
	descriptor["width"]["min"] = -1.0
	if BigGlade.describe_kind(&"house")["width"]["min"] < 0.0:
		res.fail("describe_kind returned mutable library state")
	return res


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
	if request.kind == &"house":
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
	if request.kind == &"house":
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
	if request.kind == &"house" and made.plan.furniture != again.plan.furniture:
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
	elif request.kind == &"house" and scene_a.get_node_or_null("Furniture") == null:
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
