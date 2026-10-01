class_name PlacementSuite
extends RefCounted
## BigGlade.placement()'s `door` contract: the canonical fixtures' doors lie on the
## -Z edge of its own measured `footprint` (the walls' outline -- narrower
## than `bounds`, which also covers roof eaves, porches, chimney stacks,
## battlements and facade towers), and Placement.world_rect rotates either
## rect correctly. VIL-002.
## Recessed open-manor entrances are covered by castle_placement_test.gd and
## the village's explicit courtyard approach checks.

const SEEDS := 20
const TOLERANCE := 0.2


static func run() -> SuiteResult:
	var res := SuiteResult.new("placement")
	_check_family(res, "house", func(s: int): return BuildingRequest.house(s, &"cottage", &"none", 9.0, 12.0, 2.6))
	_check_family(res, "shop", func(s: int): return BuildingRequest.shop(s, &"blacksmith", &"longhall", 11.0, 14.0, 2.8))
	_check_family(res, "hotel", func(s: int): return BuildingRequest.hotel(s, &"grand_budapest", 48.0, 24.0, 3.6))
	_check_family(res, "church", func(s: int): return BuildingRequest.church(s, &"gothic", 10.0, 22.0, 12.0))
	_check_family(res, "castle", func(s: int): return BuildingRequest.castle(s, &"norman", 55.0, 50.0, 18.0))
	_check_family(res, "temple", func(s: int): return BuildingRequest.temple(s, &"basilica", &"blood", 26.0, 44.0, 12.0))
	_check_world_rect(res)
	_check_orientation_and_period(res)
	return res


static func _check_orientation_and_period(res: SuiteResult) -> void:
	var requests: Array[BuildingRequest] = [
		BuildingRequest.house(821), BuildingRequest.shop(822), BuildingRequest.hotel(823),
		BuildingRequest.church(824), BuildingRequest.castle(825), BuildingRequest.temple(826),
		BigGlade.default_request(&"village", 827)]
	var insula := BigGlade.default_request(&"world", 828)
	insula.style = &"insula"
	insula.purpose = &"port_tenement"
	insula.width = 30.0
	insula.length = 24.0
	insula.height = 15.0
	requests.append(insula)
	var hall := BigGlade.default_request(&"world", 829)
	hall.style = &"timber_hall"
	hall.purpose = &"great_hall"
	hall.width = 34.0
	hall.length = 18.0
	hall.height = 20.0
	requests.append(hall)
	var stupa := BigGlade.default_request(&"world", 830)
	stupa.style = &"stupa"
	stupa.purpose = &"saints_mound"
	stupa.width = 40.0
	stupa.length = 40.0
	stupa.height = 17.0
	requests.append(stupa)

	for request in requests:
		var default_building: GeneratedBuilding = BigGlade.generate(request)
		var explicit_default := request.copy()
		explicit_default.orientation = 0.0
		explicit_default.period = 1200
		var repeated: GeneratedBuilding = BigGlade.generate(explicit_default)
		res.checked += 1
		if not default_building.is_ok() or not repeated.is_ok():
			res.fail("%s orientation fixture failed to generate" % request.kind)
			continue
		if float(default_building.spec.get("orientation")) != 0.0 \
				or int(default_building.spec.get("period")) != 1200:
			res.fail("%s spec did not receive default orientation/period" % request.kind)
		if not _same_mesh(BigGlade.build_mesh(default_building), BigGlade.build_mesh(repeated)):
			res.fail("%s explicit defaults changed seeded mesh output" % request.kind)
		var restored := BuildingRequest.from_json(explicit_default.to_json())
		if restored.orientation != 0.0 or restored.period != 1200:
			res.fail("%s request defaults did not survive JSON" % request.kind)

		var oriented := request.copy()
		oriented.orientation = PI / 2.0
		oriented.period = 1789
		var turned: GeneratedBuilding = BigGlade.generate(oriented)
		res.checked += 1
		if not turned.is_ok():
			res.fail("%s non-default orientation fixture failed to generate" % request.kind)
			continue
		if not is_equal_approx(float(turned.spec.get("orientation")), PI / 2.0) \
				or int(turned.spec.get("period")) != 1789:
			res.fail("%s spec did not receive non-default orientation/period" % request.kind)
		var placement: Dictionary = BigGlade.placement(turned)
		var north: Vector3 = placement.get("north", Vector3.ZERO)
		if north.distance_to(Vector3.LEFT) > 0.001:
			res.fail("%s placement north is wrong in the oriented building frame: %s" %
				[request.kind, north])
		var round_trip := BuildingRequest.from_json(oriented.to_json())
		if not is_equal_approx(round_trip.orientation, oriented.orientation) \
				or round_trip.period != 1789:
			res.fail("%s non-default request metadata did not survive JSON" % request.kind)


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a == null or b == null or a.get_surface_count() != b.get_surface_count():
		return false
	for surface in range(a.get_surface_count()):
		if a.surface_get_arrays(surface) != b.surface_get_arrays(surface):
			return false
	return true


static func _check_family(res: SuiteResult, kind: String, make: Callable) -> void:
	for i in range(SEEDS):
		var request: BuildingRequest = make.call(1000 + i)
		var made: GeneratedBuilding = BigGlade.generate(request)
		res.checked += 1
		if not made.is_ok():
			res.fail("%s seed=%d: generation failed: %s" % [kind, request.seed, made.errors])
			continue
		var placement: Dictionary = BigGlade.placement(made)
		if placement.is_empty():
			res.fail("%s seed=%d: placement() returned nothing" % [kind, request.seed])
			continue
		var bounds: AABB = placement.get("bounds", AABB())
		var footprint: Rect2 = placement.get("footprint", Rect2())
		var door: Vector3 = placement.get("door", Vector3.INF)
		var front_z: float = footprint.position.y
		if absf(door.z - front_z) > TOLERANCE:
			res.fail("%s seed=%d: door.z=%.3f is not within %.1fm of footprint -Z edge %.3f" %
				[kind, request.seed, door.z, TOLERANCE, front_z])
		if door.x < footprint.position.x - TOLERANCE \
				or door.x > footprint.position.x + footprint.size.x + TOLERANCE:
			res.fail("%s seed=%d: door.x=%.3f falls outside footprint's X span" % [kind, request.seed, door.x])
		# The footprint is the walls, so it must never be larger than the full
		# emitted architecture that measured `bounds`.
		if footprint.size.x > bounds.size.x + TOLERANCE:
			res.fail("%s seed=%d: footprint width %.3f exceeds bounds width %.3f" %
				[kind, request.seed, footprint.size.x, bounds.size.x])


## A door authored on the local -Z face rotates and translates with the rest
## of the footprint: world_rect should carry it along with the same transform.
static func _check_world_rect(res: SuiteResult) -> void:
	var request := BuildingRequest.house(42, &"cottage", &"none", 9.0, 12.0, 2.6)
	var made: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if not made.is_ok():
		res.fail("world_rect fixture: house generation failed: %s" % made.errors)
		return
	var placement: Dictionary = BigGlade.placement(made)
	var bounds: AABB = placement["bounds"]
	var transform := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(10.0, 0.0, -5.0))
	var rect: PackedVector2Array = Placement.world_rect(placement, transform)
	res.checked += 1
	if rect.size() != 4:
		res.fail("world_rect did not return four corners")
		return
	var expect0 := Vector2(
		(transform * Vector3(bounds.position.x, 0.0, bounds.position.z)).x,
		(transform * Vector3(bounds.position.x, 0.0, bounds.position.z)).z)
	if rect[0].distance_to(expect0) > 0.001:
		res.fail("world_rect did not rotate/translate the first corner correctly")
	# The rotated footprint keeps the same area as the local one -- a 90-degree
	# turn must not stretch or shrink the building.
	var local_area: float = bounds.size.x * bounds.size.z
	var world_area: float = absf(
		(rect[1].x - rect[0].x) * (rect[2].y - rect[0].y) -
		(rect[2].x - rect[0].x) * (rect[1].y - rect[0].y))
	if absf(world_area - local_area) > 0.01:
		res.fail("world_rect area %.3f differs from local footprint area %.3f" %
			[world_area, local_area])

	# use_footprint=true rotates the narrower walls-outline rect instead.
	var footprint: Rect2 = placement["footprint"]
	var frect: PackedVector2Array = Placement.world_rect(placement, transform, true)
	res.checked += 1
	if frect.size() != 4:
		res.fail("world_rect(use_footprint=true) did not return four corners")
		return
	var fexpect0 := Vector2(
		(transform * Vector3(footprint.position.x, 0.0, footprint.position.y)).x,
		(transform * Vector3(footprint.position.x, 0.0, footprint.position.y)).z)
	if frect[0].distance_to(fexpect0) > 0.001:
		res.fail("world_rect(use_footprint=true) did not rotate/translate the first corner correctly")
