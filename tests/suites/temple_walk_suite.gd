extends RefCounted
## `BrickWild.navigation()` for a temple, judged against `TempleRiteCheck`, the
## walk the rite rules already hold it to. What the check's WalkGrid reaches
## from the gate, the baked mesh reaches; nothing of the mesh stands on a
## column, the altar or the idol; the same temple bakes the same bytes; and
## Godot's own pathfinder (tests/walk_navserver_test.gd) walks gate to altar.
##
## The negative control drops the obstacles from the sources and requires the
## "nothing on the obstacles" measure to fire, so the measure is not a
## tautology.

## The grid is 0.16 m cells and the baker's erosion is exact: a cell centre the
## check reaches may sit a cell or so off the mesh edge, never further.
const GRID_SLACK := 0.3
const OVERLAP_M2 := 0.01
## Share of reached cells (or mesh vertices) allowed to miss by more than the
## slack: rasterisation noise on a curved rotunda wall, not a missing room.
const MISS_SHARE := 0.01

const CASES := [
	[&"basilica", &"blood", 26.0, 44.0, 12.0, 11],
	[&"basilica", &"bone", 24.0, 40.0, 11.0, 305],
	[&"pylon", &"flame", 24.0, 46.0, 12.0, 21],
	[&"ziggurat", &"serpent", 30.0, 30.0, 14.0, 31],
	[&"rotunda", &"void", 26.0, 26.0, 13.0, 41],
]


static func run() -> SuiteResult:
	var result := SuiteResult.new("temple walk")
	for c in CASES:
		_check_temple(result, BuildingRequest.temple(c[5], c[0], c[1], c[2], c[3], c[4]))
	_negative_control(result)
	var church: GeneratedBuilding = BrickWild.generate(BuildingRequest.church(7, &"romanesque"))
	var castle: GeneratedBuilding = BrickWild.generate(BuildingRequest.castle(3))
	result.checked += 1
	for unwalked in [church, castle]:
		if unwalked.is_ok() and (BrickWild.navigation(unwalked)["supported"] or BrickWild.navigation_node(unwalked) != null):
			result.fail("%s claims an interior walk it does not publish" % unwalked.request.kind)
	return result


static func _check_temple(result: SuiteResult, request: BuildingRequest) -> void:
	var started := Time.get_ticks_msec()
	var label := "temple %s %s seed %d" % [request.style, request.purpose, request.seed]
	var building: GeneratedBuilding = BrickWild.generate(request)
	result.checked += 1
	if not building.is_ok():
		result.fail("%s did not generate" % label)
		return
	var text: String = JSON.stringify(BrickWild.navigation(building))
	var data: Dictionary = JSON.parse_string(text)
	result.checked += 1
	if text != JSON.stringify(BrickWild.navigation(building)):
		result.fail("%s: the same temple baked two different walks" % label)
	result.checked += 1
	if not data["supported"] or data["storeys"].size() != 1 or not data["stairs"].is_empty():
		result.fail("%s: expected one supported storey and no stairs" % label)
		return
	var mesh := _mesh(data["storeys"][0]["navmesh"])
	var islands: PackedInt32Array = NavBake.islands(mesh)
	result.checked += 1
	if mesh["polygons"].is_empty():
		result.fail("%s: no walkable floor" % label)
		return
	var front: Array = data["doors"].filter(func(d: Dictionary) -> bool: return d["front"])
	result.checked += 1
	if front.size() != 1:
		result.fail("%s: %d front doors" % [label, front.size()])
		return
	var gate_poly: int = NavBake.polygon_at(mesh, _xz(front[0]["inside_m"]))
	result.checked += 1
	if gate_poly < 0:
		result.fail("%s: the gate's inside point is off the mesh" % label)
		return
	var gate_island: int = islands[gate_poly]

	# the check's own walk, from the same spec
	var spec := building.spec as TempleSpec
	var builder := TempleBuilder.new()
	builder.build(spec)
	var rite := TempleRiteCheck.new()
	rite.check(spec, builder)
	var grid: WalkGrid = rite.walk_grid()

	# every cell the check reaches is on the mesh, within the slack
	var reached := 0
	var off_mesh := 0
	for x in grid.nx:
		for z in grid.nz:
			var p: Vector2 = grid.world_of(x, z)
			if not grid.reached(Rect2(p, Vector2.ZERO), 0.01):
				continue
			reached += 1
			if NavBake.closest_point(mesh, p).distance_to(p) > GRID_SLACK:
				off_mesh += 1
	result.checked += 1
	if reached == 0 or float(off_mesh) > float(reached) * MISS_SHARE:
		result.fail("%s: %d of %d cells the rite check reaches are off the mesh" % [label, off_mesh, reached])

	# and nothing of the gate's island is somewhere the check does not reach
	var stranded := 0
	var sampled := 0
	for i in mesh["polygons"].size():
		if islands[i] != gate_island:
			continue
		for p in NavBake.points_of(mesh, i):
			sampled += 1
			if not grid.reached(Rect2(p, Vector2.ZERO), GRID_SLACK):
				stranded += 1
	result.checked += 1
	if float(stranded) > float(sampled) * MISS_SHARE:
		result.fail("%s: %d of %d mesh vertices stand where the rite check cannot walk" % [label, stranded, sampled])

	# a mesh island the gate does not reach is floor the check does not reach
	for i in mesh["polygons"].size():
		if islands[i] == gate_island:
			continue
		var c: Vector2 = _centroid(NavBake.points_of(mesh, i))
		result.checked += 1
		if grid.reached(Rect2(c, Vector2.ZERO), 0.01):
			result.fail("%s: the rite check reaches (%.1f, %.1f) but the gate's island does not" % [label, c.x, c.y])
			break

	# the altar: reached by the check iff reached on the mesh
	for f in data["furniture"]:
		var use := _xz(f["use_m"])
		var check_reaches: bool = grid.reached(TempleGeometry.altar_approach(spec), 0.0)
		var at: int = NavBake.polygon_at(mesh, use)
		result.checked += 1
		if check_reaches and (at < 0 or islands[at] != gate_island):
			result.fail("%s: the %s the rite check reaches is not reached on the mesh" % [label, f["key"]])

	var worst := _worst_overlap(mesh, spec)
	result.checked += 1
	if worst[0] > OVERLAP_M2:
		result.fail("%s: %.3f m2 of the mesh stands on a %s" % [label, worst[0], worst[1]])

	var nav: Node3D = BrickWild.navigation_node(building)
	var regions := 0
	for child in nav.get_children():
		regions += 1 if child is NavigationRegion3D else 0
	result.checked += 1
	if regions != 1 or nav.get_child_count() != 1:
		result.fail("%s: navigation_node has %d regions in %d children" % [label, regions, nav.get_child_count()])
	nav.free()
	print("  %s: %d polygons, %d cells reached, %.1f m2, %.1f s" % [label, mesh["polygons"].size(),
		reached, data["storeys"][0]["navmesh"]["area_m2"], float(Time.get_ticks_msec() - started) / 1000.0])


## Drop the obstacles from the sources: the mesh then stands on the columns and
## the altar, and the measure that polices that must say so.
static func _negative_control(result: SuiteResult) -> void:
	var building: GeneratedBuilding = BrickWild.generate(BuildingRequest.temple(11, &"basilica", &"blood", 26.0, 44.0, 12.0))
	var spec := building.spec as TempleSpec
	var sources: Dictionary = TempleGeometry.walk_sources(spec)
	var honest: Dictionary = NavBake.bake(sources[0]["floor"], sources[0]["obstacles"], BuildingNavigation.AGENT_RADIUS)
	var dropped: Array[PackedVector2Array] = []
	var broken: Dictionary = NavBake.bake(sources[0]["floor"], dropped, BuildingNavigation.AGENT_RADIUS)
	result.checked += 2
	if _worst_overlap(honest, spec)[0] > OVERLAP_M2:
		result.fail("negative control: the honest bake already stands on an obstacle")
	if _worst_overlap(broken, spec)[0] <= OVERLAP_M2:
		result.fail("negative control: a mesh baked without obstacles is not caught standing on them")


## The most mesh area on any one obstacle: [m2, what].
static func _worst_overlap(mesh: Dictionary, spec: TempleSpec) -> Array:
	var worst := 0.0
	var what := ""
	var bodies: Array = []
	for r in TempleGeometry.obstacle_rects(spec):
		bodies.append(["obstacle at (%.1f, %.1f)" % [r.get_center().x, r.get_center().y], Poly.from_rect(r)])
	for body in bodies:
		var shared := 0.0
		for i in mesh["polygons"].size():
			for piece in Geometry2D.intersect_polygons(NavBake.points_of(mesh, i), body[1]):
				shared += Poly.area(piece)
		if shared > worst:
			worst = shared
			what = body[0]
	return [worst, what]


static func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(maxi(points.size(), 1))


static func _mesh(data: Dictionary) -> Dictionary:
	var vertices := PackedVector2Array()
	for v in data["vertices_m"]:
		vertices.append(Vector2(v[0], v[1]))
	var polygons: Array[PackedInt32Array] = []
	for p in data["polygons"]:
		polygons.append(PackedInt32Array(p))
	return {"vertices": vertices, "polygons": polygons}


static func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))
