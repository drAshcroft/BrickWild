class_name PlacementSuite
extends RefCounted
## BigGlade.placement()'s `door` contract: every family's door lies on the
## -Z edge of its own measured `footprint` (the walls' outline -- narrower
## than `bounds`, which also covers roof eaves, porches, chimney stacks,
## battlements and facade towers), and Placement.world_rect rotates either
## rect correctly. VIL-002.

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
	return res


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
