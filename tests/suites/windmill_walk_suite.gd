extends RefCounted
## `BrickWild.navigation()` for a windmill: the miller's floor, published.
##
## A mill is one room. The suite proves the room that is published is the room
## the builder draws: the floor's height is `WindmillGeometry.floor_y`, every
## vertex of the baked mesh stands inside the wall's inner face, the floor keeps
## most of the room's own area, and the door the frame names is on the wall face
## the builder cut. A windpump is a lattice and publishes nothing.
##
## The negative control publishes the same floor WITHOUT the wall's thickness
## taken off, and requires the wall measure to fire; a suite that accepts a
## floor drawn through the wall is not measuring the wall.
##
## And the published door is a door a person gets through. On seed 1 of all five
## types the mesh that was drawn is walked from the ground outside to the
## miller's floor (`WindmillCheck`'s `entry` rule: steps of at most the walk
## rig's, the body's height of air, no wall across the way). The 26 Oct walk
## found a tower with no way in, a smock door three metres up, a polder door
## behind its wheel, a post mill's ladder and a door in an open lattice, while
## this suite passed: it measured the room and never walked to it. The control
## draws the same mills with the doorway uncut and the stair without treads, and
## requires the walk to fail.

## [type, sail span, body, height, seed]: two of every type, small and large.
const CASES := [
	[&"tower", 12.0, 6.0, 12.0, 8102],
	[&"tower", 18.0, 7.5, 15.0, 4101],
	[&"smock", 14.0, 6.5, 13.0, 8102],
	[&"smock", 20.0, 8.0, 16.0, 2207],
	[&"post", 10.0, 5.0, 9.0, 8102],
	[&"post", 16.0, 6.5, 12.0, 3301],
	[&"paddle", 11.0, 5.5, 10.0, 8102],
	[&"paddle", 17.0, 7.0, 13.0, 5150],
]

## The baker's mesh is eroded by a person's radius, so the published polygon is
## smaller than the room; it may also round a corner by a cell.
const INNER_SLACK := 0.05
const AREA_SHARE := 0.35


static func run() -> SuiteResult:
	var result := SuiteResult.new("windmill walk")
	for c in CASES:
		_check_mill(result, BuildingRequest.windmill(c[4], c[0], c[1], c[2], c[3]))
	_check_lattice(result)
	_negative_control(result)
	_walk_in(result)
	_walk_in_control(result)
	return result


static func _check_mill(result: SuiteResult, request: BuildingRequest) -> void:
	var label := "windmill %s %.0fx%.0f seed %d" % [request.style, request.width,
		request.height, request.seed]
	var building: GeneratedBuilding = BrickWild.generate(request)
	if building == null or not building.is_ok():
		result.checked += 1
		result.fail("%s did not generate" % label)
		return
	var spec: WindmillSpec = building.spec as WindmillSpec
	var nav: Dictionary = BrickWild.navigation(building)
	result.checked += 1
	if not bool(nav.get("supported", false)):
		result.fail("%s publishes no interior walk" % label)
		return
	var storeys: Array = nav.get("storeys", [])
	result.checked += 1
	if storeys.size() != 1:
		result.fail("%s publishes %d storeys; a mill has one room" % [label, storeys.size()])
		return
	var storey: Dictionary = storeys[0]
	var floor_y: float = float(storey.get("floor_y_m", -9999.0))
	result.checked += 1
	if absf(floor_y - WindmillGeometry.floor_y(spec)) > 0.001:
		result.fail("%s floor is at %.3f m; the miller's floor is %.3f m"
			% [label, floor_y, WindmillGeometry.floor_y(spec)])
	var inner: float = _inner_radius(spec)
	var outside := _wall_violations(storey, inner, WindmillGeometry.is_square(spec))
	result.checked += 1
	if outside > 0:
		result.fail("%s publishes %d mesh vertices outside the wall's inner face (%.2f m)"
			% [label, outside, inner])
	var area: float = _mesh_area(storey)
	var room: float = _room_area(spec)
	result.checked += 1
	if area < room * AREA_SHARE:
		result.fail("%s publishes %.1f m2 of floor where the room is %.1f m2"
			% [label, area, room])
	var doors: Array = nav.get("doors", [])
	result.checked += 1
	if doors.is_empty():
		result.fail("%s publishes no door" % label)
	else:
		var door: Dictionary = doors[0]
		var at := Vector2(float(door.door_m[0]), float(door.door_m[2]))
		var inside := Vector2(float(door.inside_m[0]), float(door.inside_m[2]))
		# The published floor must reach the door it names: the baker's nearest
		# point to the doorway is the room's own edge there.
		result.checked += 1
		if at.distance_to(inside) > 1.6:
			result.fail("%s publishes a door %.2f m from any published floor"
				% [label, at.distance_to(inside)])
		# ... and the doorway itself stands on the drawn wall face.
		var face: float = _face_radius(spec)
		var off: float = maxf(absf(at.x), absf(at.y)) if WindmillGeometry.is_square(spec) \
			else at.length()
		if absf(off - face) > 0.35:
			result.fail("%s door stands %.2f m from the axis; the wall face is %.2f m"
				% [label, off, face])
	# The same mill bakes the same bytes.
	var again: Dictionary = BrickWild.navigation(BrickWild.generate(request))
	result.checked += 1
	if JSON.stringify(again) != JSON.stringify(nav):
		result.fail("%s does not bake the same walk twice" % label)


## Seed 1 of every type, the way the walk rig builds it: a person walks from the
## ground to the floor, and a windpump has no door to walk to.
static func _walk_in(result: SuiteResult) -> void:
	for mill_type in [&"tower", &"smock", &"post", &"windpump", &"paddle"]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.windmill(1, mill_type))
		var spec: WindmillSpec = building.spec as WindmillSpec
		var builder := WindmillBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var report: Dictionary = WindmillCheck.new().check(spec, mesh, builder)
		result.checked += 1
		for failure in report["failures"]:
			if String(failure).begins_with("entry:") or String(failure).begins_with("access:"):
				result.fail("%s seed 1: %s" % [mill_type, failure])
		if mill_type == &"windpump":
			result.checked += 1
			if not builder.components("door").is_empty() 					or not builder.components("door_jamb").is_empty():
				result.fail("windpump seed 1 draws a door in an open lattice")
			continue
		result.checked += 1
		if int(report["stats"].get("entry_lines", 0)) != 3:
			result.fail("%s seed 1: the way in was not walked on three lines" % mill_type)
		# the door a nav consumer is sent to is the one in the wall
		var door: Dictionary = BrickWild.navigation(building).get("doors", [{}])[0]
		var at := Vector3(float(door.door_m[0]), 0.0, float(door.door_m[2]))
		var cut: Vector3 = WindmillGeometry.door_point(spec)
		result.checked += 1
		if Vector2(at.x, at.z).distance_to(Vector2(cut.x, cut.z)) > 0.05:
			result.fail("%s seed 1: the published door is not the one cut in the wall" % mill_type)


## The control: the same seed-1 mills with the doorway left uncut and a stair
## with no treads. The walk must fail every one.
static func _walk_in_control(result: SuiteResult) -> void:
	for mill_type in [&"tower", &"smock", &"post", &"paddle"]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.windmill(1, mill_type))
		var spec: WindmillSpec = building.spec as WindmillSpec
		var faulty: WindmillBuilder = preload(
			"res://tests/fixtures/faulty_windmill_entry_builder.gd").new()
		var mesh: ArrayMesh = faulty.build(spec)
		var report: Dictionary = WindmillCheck.new().check(spec, mesh, faulty)
		var caught := false
		for failure in report["failures"]:
			if String(failure).begins_with("entry:"):
				caught = true
		result.checked += 1
		if not caught:
			result.fail("%s seed 1: a mill with no way in passed the entry walk (%s)"
				% [mill_type, report["failures"]])


## A windpump is posts and bracing: there is no inside, and it must say so.
static func _check_lattice(result: SuiteResult) -> void:
	var request := BuildingRequest.windmill(8102, &"windpump", 9.0, 4.0, 8.0)
	var building: GeneratedBuilding = BrickWild.generate(request)
	result.checked += 1
	if building != null and bool(BrickWild.navigation(building).get("supported", true)):
		result.fail("windpump publishes an interior walk; a lattice has no room")


## Publish the floor without taking the wall's thickness off it: the wall
## measure must refuse it.
static func _negative_control(result: SuiteResult) -> void:
	var request := BuildingRequest.windmill(8102, &"tower", 12.0, 6.0, 12.0)
	var building: GeneratedBuilding = BrickWild.generate(request)
	var spec: WindmillSpec = building.spec as WindmillSpec
	var band: Dictionary = WindmillGeometry.drum_band(spec, WindmillGeometry.floor_y(spec) + 0.05)
	var sides_n: int = int(band["sides"])
	var ring := PackedVector2Array()
	for i in range(sides_n):
		var angle: float = WindmillGeometry.drum_start(sides_n) \
			+ TAU * float(i) / float(sides_n)
		ring.append(Vector2(cos(angle), sin(angle)) * float(band["r0"]))
	var storey := {"navmesh": {"vertices_m": []}}
	for point in ring:
		storey.navmesh.vertices_m.append([point.x, point.y])
	var spread := _wall_violations(storey, _inner_radius(spec))
	result.checked += 1
	if spread <= 0:
		result.fail("the wall measure accepts a floor drawn through the wall: "
			+ "it cannot catch a mill whose room is wider than its drum")


## The room's inner reach: the wall face less the wall.
static func _inner_radius(spec: WindmillSpec) -> float:
	if WindmillGeometry.is_square(spec):
		return spec.base_r + WindmillGeometry.board_proud(spec) \
			- WindmillGeometry.wall_thickness(spec)
	var band: Dictionary = WindmillGeometry.drum_band(spec, WindmillGeometry.floor_y(spec) + 0.05)
	var half: float = PI / float(maxi(int(band["sides"]), 3))
	return float(band["r0"]) * cos(half) - WindmillGeometry.wall_thickness(spec)


## Where the drawn wall stands: a square burr's boarding, or the drum's face.
static func _face_radius(spec: WindmillSpec) -> float:
	if WindmillGeometry.is_square(spec):
		return spec.base_r + WindmillGeometry.board_proud(spec)
	var band: Dictionary = WindmillGeometry.drum_band(spec, WindmillGeometry.floor_y(spec) \
		+ WindmillGeometry.door_h(spec) * 0.5)
	return float(band["r0"]) * cos(PI / float(maxi(int(band["sides"]), 3)))


## The room's own floor area, measured on the same outlines the builder uses.
static func _room_area(spec: WindmillSpec) -> float:
	if WindmillGeometry.is_square(spec):
		var half: float = _inner_radius(spec)
		return half * half * 4.0
	var sides_n: int = int(WindmillGeometry.drum_band(spec,
		WindmillGeometry.floor_y(spec) + 0.05)["sides"])
	var radius: float = _inner_radius(spec) / cos(PI / float(maxi(sides_n, 3)))
	return 0.5 * float(sides_n) * radius * radius * sin(TAU / float(sides_n))


## A square burr's room is a rectangle whose corners stand farther from the axis
## than its walls' apothem, so a square mill is measured against its own rect.
static func _wall_violations(storey: Dictionary, inner: float, square := false) -> int:
	var out := 0
	var vertices: Array = storey.get("navmesh", {}).get("vertices_m", [])
	for point in vertices:
		var at := Vector2(float(point[0]), float(point[1]))
		if square:
			if absf(at.x) > inner + INNER_SLACK or absf(at.y) > inner + INNER_SLACK:
				out += 1
		elif at.length() > inner + INNER_SLACK:
			out += 1
	return out


## Shoelace area of the published mesh's outline(s): the vertices arrive as a
## soup of points per polygon, so area is taken from their convex hull, which
## under-counts a concave room and is therefore a conservative measure.
static func _mesh_area(storey: Dictionary) -> float:
	var points := PackedVector2Array()
	for point in storey.get("navmesh", {}).get("vertices_m", []):
		points.append(Vector2(float(point[0]), float(point[1])))
	if points.size() < 3:
		return 0.0
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].distance_squared_to(hull[-1]) < 1e-10:
		hull.resize(hull.size() - 1)
	var area := 0.0
	for i in range(hull.size()):
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5
