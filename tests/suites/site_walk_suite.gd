extends RefCounted
## The SitePlan's `walk` key, read the way a consumer reads it: out of JSON,
## with nothing of BrickWild but the numbers. The two real Voxel_Build cities,
## sized as VoxelGames sizes them.
##
##   every door has standing ground outside it, on the mesh
##   every door and every placed well, stall and bench is in the same island
##   of the mesh as every gate
##   no part of the mesh stands on a building's walls
##   the same plan writes the same bytes

const EXPORTER := preload("res://tools/export_village_plan.gd")
const BRIEF := preload("res://tests/suites/site_brief_suite.gd")
const ON_MESH := 0.002
## A threshold is searched for up to `VillageNavCheck.PATH_SEARCH` out of the
## door, then moved onto the mesh by at most the grid's cell.
const DOOR_TO_OUTSIDE := VillageNavCheck.PATH_SEARCH + 0.6
## Overlap a footprint may share with the mesh: rounding, not ground.
const OVERLAP_M2 := 0.01


static func run() -> SuiteResult:
	var result := SuiteResult.new("dmv site walk")
	for row in [["Thaannafu", BRIEF.THAAN, 45, "4000"], ["Wuunafu", BRIEF.WUUN, 60, "6000"]]:
		_check_city(result, "%s %d + %s" % [row[0], row[2], row[3]], row[1], row[2], row[3])
	_check_hole_cut(result)
	return result


static func _check_city(result: SuiteResult, label: String, path: String, visible: int,
		implied: String) -> void:
	var started := Time.get_ticks_msec()
	var raw := FileAccess.get_file_as_string(path)
	var notes: Array[String] = []
	var request: Dictionary = EXPORTER.with_implied_population(
		EXPORTER.with_caller_population(JSON.parse_string(raw), str(visible), notes), implied)
	var spec: VillageSpec = EXPORTER.spec_from_request(request, raw, notes)
	spec.generate(spec.seed)
	var plan: VillagePlan = VillageLotPlanner.plan(spec)
	var text := JSON.stringify(EXPORTER.site_plan(plan, request), "\t", true)
	var again := JSON.stringify(EXPORTER.site_plan(plan, request), "\t", true)
	result.checked += 1
	if text != again:
		result.fail("%s: the same plan wrote two different SitePlans" % label)
	var site: Dictionary = JSON.parse_string(text)
	var walk: Dictionary = site.get("walk", {})
	result.checked += 1
	if walk.get("schema", "") != VillageWalk.SCHEMA or int(walk.get("schema_version", 0)) != VillageWalk.SCHEMA_VERSION:
		result.fail("%s: no %s v%d key" % [label, VillageWalk.SCHEMA, VillageWalk.SCHEMA_VERSION])
		return
	var mesh := _mesh(walk["navmesh"])
	var polygons: Array[PackedInt32Array] = mesh["polygons"]
	result.checked += 1
	if polygons.is_empty():
		result.fail("%s: an empty navigation mesh" % label)
		return
	var islands: PackedInt32Array = NavBake.islands(mesh)
	_check_convex(result, label, mesh)
	var gate_islands := {}
	for g in walk["gates"]:
		var at: int = _polygon_near(mesh, _v(g["nav_m"]))
		result.checked += 1
		if at < 0:
			result.fail("%s: %s is not on the mesh" % [label, g["gate_id"]])
			continue
		gate_islands[islands[at]] = true
	result.checked += 1
	if gate_islands.size() != 1:
		result.fail("%s: the %d gates stand on %d separate islands" % [label, walk["gates"].size(), gate_islands.size()])
		return
	var island: int = gate_islands.keys()[0]
	result.checked += 1
	if walk["doors"].size() != site["buildings"].size():
		result.fail("%s: %d doors for %d buildings" % [label, walk["doors"].size(), site["buildings"].size()])
	var stranded: Array[String] = []
	for d in walk["doors"]:
		result.checked += 1
		if not d["reachable"] or d["outside_m"] == null:
			stranded.append("%s (the village check cannot reach it)" % d["building_id"])
			continue
		var outside := _v(d["outside_m"])
		var at: int = _polygon_near(mesh, outside)
		if at < 0:
			stranded.append("%s (outside point off the mesh)" % d["building_id"])
		elif islands[at] != island:
			stranded.append("%s (on an island no gate reaches)" % d["building_id"])
		elif outside.distance_to(_v(d["door_m"])) > DOOR_TO_OUTSIDE:
			stranded.append("%s (outside point %.1f m from the door)" % [d["building_id"], outside.distance_to(_v(d["door_m"]))])
	for f in walk["furniture"]:
		result.checked += 1
		var at: int = _polygon_near(mesh, _v(f["use_m"]))
		if at < 0 or islands[at] != island:
			stranded.append("%s %s" % [f["key"], f["prop_id"]])
	if not stranded.is_empty():
		result.fail("%s: %d doors or furniture not walkable from the gates: %s" % [label, stranded.size(), ", ".join(stranded.slice(0, 5))])
	_check_footprints(result, label, site, walk, mesh)
	print("  %s: %d buildings, %d gates, %d mesh polygons over %.0f m2, %d furniture, %.1f s" % [
		label, site["buildings"].size(), walk["gates"].size(), polygons.size(),
		float(walk["navmesh"]["area_m2"]), walk["furniture"].size(),
		float(Time.get_ticks_msec() - started) / 1000.0])


## No mesh polygon stands on a building's walls. A manor's arrival court is
## inside its footprint rectangle and is ground, so it is taken out first.
static func _check_footprints(result: SuiteResult, label: String, site: Dictionary,
		walk: Dictionary, mesh: Dictionary) -> void:
	var courts := {}
	for row in walk["floor"]:
		if row["kind"] == "court":
			courts[row["ref"]] = _poly(row["poly_m"])
	var worst := 0.0
	var worst_id := ""
	for b in site["buildings"]:
		var walls: PackedVector2Array = _poly(b["poly_m"])
		var court: PackedVector2Array = courts.get(b["building_id"], PackedVector2Array())
		var box: Rect2 = Poly.bounding_rect(walls)
		var shared := 0.0
		for i in mesh["polygons"].size():
			var cell: PackedVector2Array = NavBake.points_of(mesh, i)
			if not Poly.bounding_rect(cell).intersects(box):
				continue
			for piece in Geometry2D.intersect_polygons(cell, walls):
				shared += Poly.area(piece)
				if not court.is_empty():
					for open in Geometry2D.intersect_polygons(piece, court):
						shared -= Poly.area(open)
		if shared > worst:
			worst = shared
			worst_id = b["building_id"]
	result.checked += 1
	if worst > OVERLAP_M2:
		result.fail("%s: %.3f m2 of the mesh stands inside %s" % [label, worst, worst_id])


## Godot wants every navigation polygon convex. A turn under a milliradian
## is a straight edge the millimetre snap has bent.
static func _check_convex(result: SuiteResult, label: String, mesh: Dictionary) -> void:
	var bad := 0
	for i in mesh["polygons"].size():
		var pts: PackedVector2Array = NavBake.points_of(mesh, i)
		var sign := 0.0
		for k in pts.size():
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[(k + 1) % pts.size()]
			var c: Vector2 = pts[(k + 2) % pts.size()]
			var cross: float = (b - a).cross(c - b)
			if absf(cross) < 1e-3 * (b - a).length() * (c - b).length():
				continue
			if sign == 0.0:
				sign = signf(cross)
			elif signf(cross) != sign:
				bad += 1
				break
	result.checked += 1
	if bad > 0:
		result.fail("%s: %d navigation polygons are not convex" % [label, bad])


## A cutter wholly inside an obstacle is split round, not lost: the hole a
## bridge makes in a lake still comes out as walkable ground.
static func _check_hole_cut(result: SuiteResult) -> void:
	var lake := Poly.from_rect(Rect2(-10.0, -10.0, 20.0, 20.0))
	var bridge := Poly.from_rect(Rect2(-2.0, -2.0, 4.0, 4.0))
	var pieces: Array[PackedVector2Array] = VillageNavCheck._minus([lake], [bridge])
	var area := 0.0
	var holed := false
	for p in pieces:
		area += Poly.area(p)
		holed = holed or Geometry2D.is_polygon_clockwise(p)
	result.checked += 1
	if holed or absf(area - 384.0) > 0.01:
		result.fail("cutting a hole: %d pieces, %.2f m2 (want 384), holes %s" % [pieces.size(), area, holed])
	var mesh := NavBake.bake([Poly.from_rect(Rect2(-12.0, -12.0, 24.0, 24.0))], pieces, 0.24)
	result.checked += 1
	if NavBake.polygon_at(mesh, Vector2.ZERO) < 0 or NavBake.polygon_at(mesh, Vector2(6.0, 0.0)) >= 0:
		result.fail("the baked hole is not walkable, or the lake is")


static func _polygon_near(mesh: Dictionary, p: Vector2) -> int:
	var at: int = NavBake.polygon_at(mesh, p)
	if at >= 0:
		return at
	if NavBake.closest_point(mesh, p).distance_to(p) > ON_MESH:
		return -1
	var best := -1
	var best_d := INF
	for i in mesh["polygons"].size():
		var pts: PackedVector2Array = NavBake.points_of(mesh, i)
		for k in pts.size():
			var d: float = Geometry2D.get_closest_point_to_segment(p, pts[k], pts[(k + 1) % pts.size()]).distance_to(p)
			if d < best_d:
				best_d = d
				best = i
	return best


static func _mesh(data: Dictionary) -> Dictionary:
	var vertices := PackedVector2Array()
	for v in data["vertices_m"]:
		vertices.append(_v(v))
	var polygons: Array[PackedInt32Array] = []
	for p in data["polygons"]:
		polygons.append(PackedInt32Array(p))
	return {"vertices": vertices, "polygons": polygons}


static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_v(p))
	return out


static func _v(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))
