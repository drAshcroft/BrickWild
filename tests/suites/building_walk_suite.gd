extends RefCounted
## `BrickWild.navigation()`: a building's storeys as navigation meshes and its
## stairs as links, judged against `HouseNavCheck`, the walk the furnisher was
## already held to. What the check reaches from the front door, the mesh and
## its links must reach; nothing of the mesh may stand on furniture the check
## walks round; the same building bakes the same bytes.

const ON_MESH := 0.002
const OVERLAP_M2 := 0.01


static func run() -> SuiteResult:
	var result := SuiteResult.new("building walk")
	for request in [
			BuildingRequest.house(32102, &"townhouse", &"innkeeper", 13.0, 16.0, 2.9, 2),
			BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 1),
			BuildingRequest.shop(4410, &"tavern", &"townhouse", 11.0, 14.0, 2.8, 2)]:
		_check_building(result, request)
	var church: GeneratedBuilding = BrickWild.generate(BuildingRequest.church(7, &"romanesque"))
	result.checked += 1
	if BrickWild.navigation(church)["supported"] or BrickWild.navigation_node(church) != null:
		result.fail("a church claims an interior walk it does not publish")
	return result


static func _check_building(result: SuiteResult, request: BuildingRequest) -> void:
	var started := Time.get_ticks_msec()
	var label := "%s %s %s seed %d" % [request.kind, request.style, request.purpose, request.seed]
	var building: GeneratedBuilding = BrickWild.generate(request)
	result.checked += 1
	if not building.is_ok():
		result.fail("%s did not generate" % label)
		return
	var data: Dictionary = JSON.parse_string(JSON.stringify(BrickWild.navigation(building)))
	result.checked += 1
	if JSON.stringify(data) != JSON.stringify(JSON.parse_string(JSON.stringify(BrickWild.navigation(building)))):
		result.fail("%s: the same building baked two different walks" % label)
	result.checked += 1
	if not data["supported"] or data["storeys"].size() != HouseWalkSources.levels_of(building.plan).size():
		result.fail("%s: %d storeys walked of %d" % [label, data.get("storeys", []).size(),
			HouseWalkSources.levels_of(building.plan).size()])
		return
	var meshes := {}
	var islands := {}
	for row in data["storeys"]:
		var mesh := _mesh(row["navmesh"])
		meshes[int(row["storey"])] = mesh
		islands[int(row["storey"])] = NavBake.islands(mesh)
		result.checked += 1
		if mesh["polygons"].is_empty():
			result.fail("%s: storey %d has no walkable floor" % [label, row["storey"]])
			return
	var front: Array = data["doors"].filter(func(d: Dictionary) -> bool: return d["front"])
	result.checked += 1
	if front.size() != 1:
		result.fail("%s: %d front doors" % [label, front.size()])
		return
	var reached := {}
	var start := _island_at(meshes, islands, int(front[0]["storey"]), _xz(front[0]["inside_m"]))
	result.checked += 1
	if start.is_empty():
		result.fail("%s: the front door's inside point is off the mesh" % label)
		return
	var stairs: Array = data["stairs"]
	reached = _reach(meshes, islands, start, stairs)
	var upstairs: Array = data["furniture"].filter(func(f: Dictionary) -> bool: return int(f["storey"]) > 0)
	if not upstairs.is_empty():
		var flat := _reach(meshes, islands, start, [])
		result.checked += 1
		if upstairs.any(func(f: Dictionary) -> bool:
				return flat.has(_island_at(meshes, islands, int(f["storey"]), _xz(f["use_m"])))):
			result.fail("%s: upstairs furniture is reached with the stairs taken away" % label)
	for s in stairs:
		result.checked += 1
		if not s["linked"]:
			result.fail("%s: the stair from storey %d to %d has a landing off the mesh" % [label, s["from_storey"], s["to_storey"]])
	var check := HouseNavCheck.new()
	check.check(building.plan)
	var stranded: Array[String] = []
	for f in data["furniture"]:
		if check.unreachable_items.has(int(f["item"])) or check.unreached_rooms.has(int(f["room"])):
			continue
		result.checked += 1
		var at := _island_at(meshes, islands, int(f["storey"]), _xz(f["use_m"]))
		if at.is_empty() or not reached.has(at):
			stranded.append("%s %d (storey %d)" % [f["key"], f["item"], f["storey"]])
	if not stranded.is_empty():
		result.fail("%s: %d pieces the house check reaches are not reached on the mesh: %s" % [label, stranded.size(), ", ".join(stranded.slice(0, 5))])
	_check_furniture_clear(result, label, building.plan, meshes)
	var nav: Node3D = BrickWild.navigation_node(building)
	var regions := 0
	var links := 0
	for child in nav.get_children():
		regions += 1 if child is NavigationRegion3D else 0
		links += 1 if child is NavigationLink3D else 0
	result.checked += 1
	if regions != data["storeys"].size() or links != stairs.filter(func(s: Dictionary) -> bool: return s["linked"]).size():
		result.fail("%s: navigation_node has %d regions and %d links for %d storeys and %d stairs" % [
			label, regions, links, data["storeys"].size(), stairs.size()])
	nav.free()
	print("  %s: %d storeys, %d stairs, %d furniture, %d doors, %.1f s" % [label, data["storeys"].size(),
		stairs.size(), data["furniture"].size(), data["doors"].size(),
		float(Time.get_ticks_msec() - started) / 1000.0])


## Every island reached from `start`, crossing storeys only by the links.
static func _reach(meshes: Dictionary, islands: Dictionary, start: String, stairs: Array) -> Dictionary:
	var reached := {start: true}
	var grew := true
	while grew:
		grew = false
		for s in stairs:
			if not s["linked"]:
				continue
			var lo := _island_at(meshes, islands, int(s["from_storey"]), _xz(s["lower_m"]))
			var hi := _island_at(meshes, islands, int(s["to_storey"]), _xz(s["upper_m"]))
			if lo.is_empty() or hi.is_empty():
				continue
			if reached.has(lo) != reached.has(hi):
				reached[lo] = true
				reached[hi] = true
				grew = true
	return reached


## Nothing of the mesh stands on a piece the house check walks round.
static func _check_furniture_clear(result: SuiteResult, label: String, plan: HousePlan, meshes: Dictionary) -> void:
	var worst := 0.0
	var worst_key := ""
	for p in plan.furniture:
		if p.get("mounted", false) or not PropCatalog.blocks_floor(String(p["key"])):
			continue
		var level := HousePlan.record_storey(p)
		if not meshes.has(level):
			continue
		var body := Poly.from_rect(p["rect"])
		var shared := 0.0
		for i in meshes[level]["polygons"].size():
			for piece in Geometry2D.intersect_polygons(NavBake.points_of(meshes[level], i), body):
				shared += Poly.area(piece)
		if shared > worst:
			worst = shared
			worst_key = String(p["key"])
	result.checked += 1
	if worst > OVERLAP_M2:
		result.fail("%s: %.3f m2 of the mesh stands on a %s" % [label, worst, worst_key])


## "<storey>:<island>" for the polygon a point stands in (or within ON_MESH of).
static func _island_at(meshes: Dictionary, islands: Dictionary, storey: int, p: Vector2) -> String:
	if not meshes.has(storey):
		return ""
	var mesh: Dictionary = meshes[storey]
	var at: int = NavBake.polygon_at(mesh, p)
	if at < 0:
		var best_d := ON_MESH
		for i in mesh["polygons"].size():
			var pts: PackedVector2Array = NavBake.points_of(mesh, i)
			for k in pts.size():
				var d: float = Geometry2D.get_closest_point_to_segment(p, pts[k], pts[(k + 1) % pts.size()]).distance_to(p)
				if d <= best_d:
					best_d = d
					at = i
	return "" if at < 0 else "%d:%d" % [storey, islands[storey][at]]


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
