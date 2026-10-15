extends RefCounted
## `BrickWild.navigation()` for a church, judged against the WalkGrid the church
## QA walks with. The grid is fed the church's own floor and obstruction
## (`ChurchGeometry.walk_rects`, with the dressing the REAL builder logged) and
## flooded from the west door; what it reaches, the baked mesh reaches. The
## mesh stands on no pew, altar or engaged pier; the whole mesh is one region,
## aisles included; the altar is reached; the same church bakes the same
## bytes; and Godot's own pathfinder (tests/walk_navserver_test.gd) walks door
## to altar.
##
## The negative control drops the obstacles from the sources and requires the
## "nothing on the obstacles" measure to fire, so that measure is not a
## tautology.

## The grid is 0.12 m cells and the baker's erosion is exact: a cell centre the
## grid reaches may sit a cell or so off the mesh edge, never further.
const GRID_SLACK := 0.3
const OVERLAP_M2 := 0.01
## Rectangular rooms have many corners, where the baker mitres and the grid rounds.
const MISS_SHARE := 0.03

## [style, width, length, height, seed]; sizes chosen to span a chapel, a
## parish church with a tower, aisled and multi-door naves.
const CASES := [
	[&"romanesque", 12.0, 28.0, 11.0, 7],
	[&"gothic", 16.0, 44.0, 18.0, 3],
	[&"gothic", 20.0, 58.0, 22.0, 21],
	[&"byzantine", 16.0, 30.0, 14.0, 12],
	[&"renaissance", 14.0, 34.0, 15.0, 5],
	[&"russian", 12.0, 26.0, 13.0, 9],
	[&"nordic_stave", 9.0, 20.0, 9.0, 4],
	[&"romanesque", 18.0, 40.0, 14.0, 31],
]


static func run() -> SuiteResult:
	var result := SuiteResult.new("church walk")
	var aisled := 0
	var altars := 0
	for c in CASES:
		var got: Array = _check_church(result, BuildingRequest.church(c[4], c[0], c[1], c[2], c[3]))
		aisled += int(got[0])
		altars += int(got[1])
	# a vacuous suite is a green one: the cases must include an aisled church
	# (so the arcade connectors are exercised) and a church with an altar
	result.checked += 2
	if aisled == 0:
		result.fail("no case has an aisle: the arcade connectors are untested")
	if altars == 0:
		result.fail("no case has a nave altar: the focus is untested")
	_negative_control(result)
	_unsupported(result)
	return result


## Returns [has aisles, has altar].
static func _check_church(result: SuiteResult, request: BuildingRequest) -> Array:
	var started := Time.get_ticks_msec()
	var label := "church %s %.0fx%.0f seed %d" % [request.style, request.width, request.length, request.seed]
	var building: GeneratedBuilding = BrickWild.generate(request)
	result.checked += 1
	if not building.is_ok():
		result.fail("%s did not generate" % label)
		return [false, false]
	var spec := building.spec as ChurchSpec
	var text: String = JSON.stringify(BrickWild.navigation(building))
	var data: Dictionary = JSON.parse_string(text)
	result.checked += 1
	if text != JSON.stringify(BrickWild.navigation(building)):
		result.fail("%s: the same church baked two different walks" % label)
	result.checked += 1
	if not data["supported"] or data["storeys"].size() != 1 or not data["stairs"].is_empty():
		result.fail("%s: expected one supported storey and no stairs" % label)
		return [false, false]
	var mesh := _mesh(data["storeys"][0]["navmesh"])
	var islands: PackedInt32Array = NavBake.islands(mesh)
	result.checked += 1
	if mesh["polygons"].is_empty():
		result.fail("%s: no walkable floor" % label)
		return [false, false]
	var layout: Array = ChurchGeometry.west_door_layout(spec)
	result.checked += 1
	if data["doors"].size() != layout.size():
		result.fail("%s: %d doors published, %d cut" % [label, data["doors"].size(), layout.size()])
		return [false, false]
	var gate_island := -1
	for d in data["doors"]:
		var at: int = NavBake.polygon_at(mesh, _xz(d["inside_m"]))
		result.checked += 1
		if at < 0:
			result.fail("%s: door %d's inside point is off the mesh" % [label, d["door"]])
			return [false, false]
		if gate_island < 0:
			gate_island = islands[at]
		elif islands[at] != gate_island:
			result.fail("%s: the west doors do not open on one floor" % label)
	# One region, aisles included (reached through the arcade). A pew end can
	# seal a sliver between itself and a wall; such pockets are allowed but must
	# be a sliver, and the grid must not reach them either (checked below).
	var total_area := 0.0
	var pocket_area := 0.0
	for i in mesh["polygons"].size():
		var a: float = Poly.area(NavBake.points_of(mesh, i))
		total_area += a
		if islands[i] != gate_island:
			pocket_area += a
	result.checked += 1
	if pocket_area > total_area * 0.03:
		result.fail("%s: %.1f of %.1f m2 of floor is not reached from the west door" % [label, pocket_area, total_area])

	# the grid the church QA walks with, from what the real builder logged
	var builder := ChurchBuilder.new()
	builder.build(spec)
	var rects: Dictionary = ChurchGeometry.walk_rects(spec, builder.prop_log)
	var grid: WalkGrid = _grid(rects)
	var door_in: Vector2 = _xz(data["doors"][0]["inside_m"])
	result.checked += 1
	if not grid.flood_from(door_in, 1.2):
		result.fail("%s: the grid cannot stand at the west door" % label)
		return [false, false]

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
		result.fail("%s: %d of %d cells the grid reaches are off the mesh" % [label, off_mesh, reached])

	var stranded := 0
	var sampled := 0
	for i in mesh["polygons"].size():
		if islands[i] != gate_island:
			# floor the door does not reach is floor the grid does not reach
			var pts: PackedVector2Array = NavBake.points_of(mesh, i)
			var c := Vector2.ZERO
			for q in pts:
				c += q
			c /= float(maxi(pts.size(), 1))
			result.checked += 1
			if grid.reached(Rect2(c, Vector2.ZERO), 0.01):
				result.fail("%s: the grid reaches (%.1f, %.1f) but the door's island does not" % [label, c.x, c.y])
			continue
		for p in NavBake.points_of(mesh, i):
			sampled += 1
			if not grid.reached(Rect2(p, Vector2.ZERO), GRID_SLACK):
				stranded += 1
	result.checked += 1
	if float(stranded) > float(sampled) * MISS_SHARE:
		result.fail("%s: %d of %d mesh vertices stand where the grid cannot walk" % [label, stranded, sampled])

	var has_altar := false
	for f in data["furniture"]:
		has_altar = true
		var use := _xz(f["use_m"])
		var at2: int = NavBake.polygon_at(mesh, use)
		result.checked += 1
		if at2 < 0 or islands[at2] != gate_island:
			result.fail("%s: the %s is not reached on the mesh" % [label, f["key"]])
		result.checked += 1
		if not grid.reached(Rect2(use, Vector2.ZERO), GRID_SLACK):
			result.fail("%s: the %s is not reached by the grid" % [label, f["key"]])

	var worst := _worst_overlap(mesh, rects["obstacles"])
	result.checked += 1
	if worst[0] > OVERLAP_M2:
		result.fail("%s: %.3f m2 of the mesh stands on %s" % [label, worst[0], worst[1]])
	# the measure must have something to measure: a church has pews
	var pews := 0
	for p in builder.prop_log:
		pews += 1 if String(p["key"]) == ChurchFurnisher.PEW else 0
	var piers: int = ChurchGeometry.nave_support_zs(spec).size() * 2

	var nav: Node3D = BrickWild.navigation_node(building)
	var regions := 0
	for child in nav.get_children():
		regions += 1 if child is NavigationRegion3D else 0
	result.checked += 1
	if regions != 1 or nav.get_child_count() != 1:
		result.fail("%s: navigation_node has %d regions in %d children" % [label, regions, nav.get_child_count()])
	nav.free()
	print("  %s: %d polygons, %d cells reached, %.1f m2, %d pews, %d piers, aisles %d, altar %s, %.1f s" % [
		label, mesh["polygons"].size(), reached, data["storeys"][0]["navmesh"]["area_m2"],
		pews, piers, spec.aisles, str(has_altar), float(Time.get_ticks_msec() - started) / 1000.0])
	return [spec.aisles > 0, has_altar]


## Drop the obstacles from the sources: the mesh then stands on the pews, the
## altar and the piers, and the measure that polices that must say so.
static func _negative_control(result: SuiteResult) -> void:
	var building: GeneratedBuilding = BrickWild.generate(BuildingRequest.church(7, &"romanesque", 12.0, 28.0, 11.0))
	var spec := building.spec as ChurchSpec
	var props: Array = ChurchFurnisher.dress(spec)
	var rects: Dictionary = ChurchGeometry.walk_rects(spec, props)
	var sources: Dictionary = ChurchGeometry.walk_sources(spec, props)
	var honest: Dictionary = NavBake.bake(sources[0]["floor"], sources[0]["obstacles"], BuildingNavigation.AGENT_RADIUS)
	var dropped: Array[PackedVector2Array] = []
	var broken: Dictionary = NavBake.bake(sources[0]["floor"], dropped, BuildingNavigation.AGENT_RADIUS)
	result.checked += 3
	if rects["obstacles"].is_empty():
		result.fail("negative control: the church has no obstacles to stand on")
	if _worst_overlap(honest, rects["obstacles"])[0] > OVERLAP_M2:
		result.fail("negative control: the honest bake already stands on an obstacle")
	if _worst_overlap(broken, rects["obstacles"])[0] <= OVERLAP_M2:
		result.fail("negative control: a mesh baked without obstacles is not caught standing on them")


## A podium church has no paved floor of its own and publishes no walk; nor
## does a manor (walled castles are walked, suite kwalk).
static func _unsupported(result: SuiteResult) -> void:
	var spec: ChurchSpec = TestSweep.spec_at(&"russian", 6)
	spec.hero = &"basil"
	spec.dome = true
	result.checked += 1
	if ChurchGeometry.podium_height(spec) <= 0.0:
		result.fail("fixture: the basil spec has no podium")
	elif not ChurchGeometry.walk_sources(spec, []).is_empty():
		result.fail("a podium church claims a walk over a floor it does not have")
	var castle: GeneratedBuilding = BrickWild.generate(BuildingRequest.castle(3))
	result.checked += 1
	if castle.is_ok() and (BrickWild.navigation(castle)["supported"] or BrickWild.navigation_node(castle) != null):
		result.fail("a manor claims an interior walk it does not publish")


static func _grid(rects: Dictionary) -> WalkGrid:
	var bounds: Rect2 = rects["floor"][0]
	for r in rects["floor"]:
		bounds = bounds.merge(r)
	var grid := WalkGrid.new()
	grid.setup(bounds.grow(0.5))
	for r in rects["floor"]:
		grid.add_floor(r)
	for o in rects["obstacles"]:
		grid.add_obstacle(o)
	grid.build(BuildingNavigation.AGENT_RADIUS)
	return grid


## The most mesh area on any one obstacle: [m2, what].
static func _worst_overlap(mesh: Dictionary, obstacles: Array) -> Array:
	var worst := 0.0
	var what := ""
	for r in obstacles:
		var body := Poly.from_rect(r)
		var shared := 0.0
		for i in mesh["polygons"].size():
			for piece in Geometry2D.intersect_polygons(NavBake.points_of(mesh, i), body):
				shared += Poly.area(piece)
		if shared > worst:
			worst = shared
			what = "obstacle at (%.1f, %.1f)" % [r.get_center().x, r.get_center().y]
	return [worst, what]


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
