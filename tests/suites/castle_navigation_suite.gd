extends RefCounted
## `BrickWild.navigation()` for a walled castle, judged against the castle's
## own route check. `CastleQA.lords_walk` floods a WalkGrid from outside the
## gate over the ground inside the curtain, with the EMITTED masonry and the
## floor-blocking props as obstruction; `HouseNavCheck` then walks each range's
## plan. The walk published here is derived from the geometry that placed those
## things and never reads the mesh, so the two can disagree, and this suite is
## where they are made to answer to each other:
##
##  * what the grid reaches from the gate, the ward mesh and the ground floors
##    of the ranges its doors open on reach;
##  * the mesh stands where the grid can walk, and on no emitted prop or piece
##    of range furniture;
##  * the mesh plus its links (a door is one, so is each stair and the keep's
##    forebuilding) carry a person from the gate to the hall, the chapel and the
##    lord's chamber, and to every room of the keep that `HouseNavCheck` reaches;
##  * the same castle bakes the same bytes, with the plan cache cleared between;
##  * the negative controls: with the ward's obstruction dropped the mesh stands
##    on the keep, and with the links dropped the lord's chamber is not reached.
##
## Castles it does not walk (manor, tower house, motte, ridge, barbican, terrace,
## sky) still report `supported: false`.

## The grid pads each masonry hull by half a cell and works in 12 cm cells, so
## the walk it finds hugs a wall 5 to 15 cm less closely than the baker's.
const GRID_SLACK := 0.4
const OVERLAP_M2 := 0.01
const MISS_SHARE := 0.03
## Reached grid cells are sampled every Nth cell each way.
const STRIDE := 3

## [style, width, length, height, seed]: a square castle, and a pentagon whose
## chapel opens only on its apse. Each takes about a minute (the castle's own
## mesh is built for the grid it is judged against).
const CASES := [
	[&"norman", 55.0, 50.0, 18.0, 202],
	[&"bavarian", 55.0, 50.0, 14.0, 3],
]
## Slower, so `kwalk2`: an octagon, and two rings of wall.
const MORE_CASES := [
	[&"edwardian", 55.0, 50.0, 14.0, 1],
	[&"norman", 120.0, 120.0, 14.0, 3],
]


static func run() -> SuiteResult:
	var result := SuiteResult.new("castle navigation")
	var halls := 0
	var chapels := 0
	for c in CASES:
		var got: Array = _check_castle(result, c)
		halls += 1 if got[0] else 0
		chapels += 1 if got[1] else 0
	# a vacuous suite is a green one: some castle must have a hall and a chapel
	# the walk gets into
	result.checked += 2
	if halls == 0:
		result.fail("no case walks into a hall")
	if chapels == 0:
		result.fail("no case walks into a chapel")
	_negative_control(result)
	_unsupported(result)
	return result


static func run_more() -> SuiteResult:
	var result := SuiteResult.new("castle navigation, an octagon and two rings")
	for c in MORE_CASES:
		_check_castle(result, c)
	return result


static func _check_castle(result: SuiteResult, c: Array) -> Array:
	var started := Time.get_ticks_msec()
	var label := "castle %s %.0fx%.0f seed %d" % [c[0], c[1], c[2], c[4]]
	var building: GeneratedBuilding = BrickWild.generate(BuildingRequest.castle(c[4], c[0], c[1], c[2], c[3]))
	result.checked += 1
	if not building.is_ok():
		result.fail("%s did not generate" % label)
		return [false, false]
	var spec := building.spec as CastleSpec
	var text: String = JSON.stringify(BrickWild.navigation(building))
	var data: Dictionary = JSON.parse_string(text)
	result.checked += 2
	if not data["supported"]:
		result.fail("%s: not supported" % label)
		return [false, false]
	# a second bake, with the plan cache cleared, writes the same bytes
	CastleWalkSources._cache.clear()
	if text != JSON.stringify(BrickWild.navigation(building)):
		result.fail("%s: the same castle baked two different walks" % label)
	var walk: Dictionary = CastleWalkSources.frame(spec)
	var ranges: Array = walk["ranges"]
	var meshes := {}
	var islands := {}
	for row in data["storeys"]:
		var sid := int(row["storey"])
		meshes[sid] = _mesh(row["navmesh"])
		islands[sid] = NavBake.islands(meshes[sid])
		result.checked += 1
		if meshes[sid]["polygons"].is_empty():
			result.fail("%s: storey %d has no walkable floor" % [label, sid])
	result.checked += 1
	if not meshes.has(0) or not data["doors"].size() == 1 or not data["doors"][0]["front"]:
		result.fail("%s: expected the ward and one front gate" % label)
		return [false, false]
	var linked := 0
	for link in data["stairs"]:
		result.checked += 1
		if not link["linked"]:
			result.fail("%s: link %d -> %d does not reach its floors" % [label, link["from_storey"], link["to_storey"]])
		linked += 1 if link["linked"] else 0

	# --- the mesh plus its links: who can walk from the gate to whom
	var graph := _graph(data, meshes, islands)
	var gate_in := _node(meshes, islands, 0, _xz(data["doors"][0]["inside_m"]))
	result.checked += 1
	if gate_in < 0:
		result.fail("%s: the gate's inside point is off the ward mesh" % label)
		return [false, false]
	var focus_reached := {}
	for f in data["furniture"]:
		var node := _node(meshes, islands, int(f["storey"]), _xz(f["use_m"]))
		focus_reached[String(f["key"])] = node >= 0 and _find(graph, node) == _find(graph, gate_in)
	result.checked += 1
	if not focus_reached.has("lords_chamber") or not (focus_reached.has("hall") or focus_reached.has("chapel")):
		result.fail("%s: expected a lord's chamber and a hall or chapel to walk to, got %s" % [label, str(focus_reached.keys())])
	result.checked += 1
	if not focus_reached.get("lords_chamber", false):
		result.fail("%s: gate to lords_chamber is not walkable on the mesh and links" % label)

	# --- the castle's own checks, from the real builder's mesh
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var report: Dictionary = CastleQA.lords_walk(spec, builder, mesh)
	result.checked += 1
	if not report["applicable"] or not report["failures"].is_empty():
		result.fail("%s: the castle's own lord's walk fails: %s" % [label, str(report["failures"])])
		return [false, false]
	var outer := CastleGeometry.enceinte_polygon(spec, 0)
	var gate := CastleGeometry.gatehouse_aabb(spec, 0)
	var half := CastleGeometry.gate_width(spec, 0) * 0.5
	var approach := Rect2(-half, gate.position.z - 2.0, half * 2.0, 2.5)
	var bounds := CastleGeometry.polygon_bbox(outer).merge(approach).grow(1.0)
	var trial: Dictionary = CastleQA._walk_trial(bounds, outer, approach, mesh, builder.prop_log,
		report["start"], report["keep_approach"], report["door_inside"])
	var grid: WalkGrid = trial["grid"]
	result.checked += 1
	if not trial["ok"]:
		result.fail("%s: the grid does not reach the keep from the gate" % label)
		return [false, false]

	# Ward the gate does not reach (a sealed ring between two curtains, the wedge
	# behind a keep) must be ward the grid does not reach either: floor the mesh
	# leaves out of the gate's island but the grid walks is a missing connection.
	var ward_total := 0.0
	var ward_missed := 0.0
	for i in meshes[0]["polygons"].size():
		var pts: PackedVector2Array = NavBake.points_of(meshes[0], i)
		var area: float = Poly.area(pts)
		ward_total += area
		if _find(graph, _key(0, islands[0][i])) == _find(graph, gate_in) or area < 0.05:
			continue
		var centre := Vector2.ZERO
		for q in pts:
			centre += q
		centre /= float(pts.size())
		if grid.reached(Rect2(centre, Vector2.ZERO), GRID_SLACK):
			ward_missed += area
	result.checked += 1
	if ward_missed > ward_total * MISS_SHARE:
		result.fail("%s: %.1f of %.1f m2 of ward is not reached from the gate on the mesh but is by the grid" % [
			label, ward_missed, ward_total])

	# the ground a person stands on: the ward and the ranges its doors open on
	var ground: Array[int] = [0]
	var grew := true
	while grew:
		grew = false
		for link in data["stairs"]:
			var lo := int(link["from_storey"])
			var hi := int(link["to_storey"])
			if lo in ground and hi % CastleWalkSources.STRIDE == 0 and not hi in ground:
				ground.append(hi)
				grew = true
	var inner := CastleGeometry.inner_polygon(spec, 0)
	var way_in := Rect2(-half, gate.position.z - 2.0, half * 2.0, gate.size.z + 2.5)
	var set_aside_rects: Array[Rect2] = []
	for r in CastleWalkSources.tower_footprints(spec):
		set_aside_rects.append(r.grow(0.3))
	for row in builder.interiors:
		set_aside_rects.append(CastleWalkSources._rect_of(row.bounds).grow(0.4))
	# the first treads of a stair are low enough to walk onto
	for stair in CastleGeometry.wall_stairs(spec):
		set_aside_rects.append(Rect2(stair.footprint).grow(0.4))
	var fore := CastleGeometry.forebuilding(spec)
	if not fore.is_empty():
		set_aside_rects.append(Rect2(fore.footprint).grow(0.4))
	var reached := 0
	var off_mesh := 0
	var off_at := PackedVector2Array()
	for x in range(0, grid.nx, STRIDE):
		for z in range(0, grid.nz, STRIDE):
			var p: Vector2 = grid.world_of(x, z)
			if not grid.reached(Rect2(p, Vector2.ZERO), 0.01):
				continue
			# The ward is what is compared here. The grid also walks the wall
			# band's gaps, and inside the ranges and towers it knows only their
			# masonry, not the furniture the plans add (the doors and keep rooms
			# below answer for those); a drum or an apse is a rectangle to the
			# walk, which is the safe side of it.
			if not (Geometry2D.is_point_in_polygon(p, inner) or way_in.has_point(p)):
				continue
			var set_aside := false
			for r in set_aside_rects:
				set_aside = set_aside or r.has_point(p)
			if set_aside:
				continue
			reached += 1
			var best := INF
			for sid in ground:
				best = minf(best, NavBake.closest_point(meshes[sid], p).distance_to(p))
				if best <= GRID_SLACK:
					break
			if best > GRID_SLACK:
				off_mesh += 1
				off_at.append(p)
	result.checked += 1
	if reached == 0 or float(off_mesh) > float(reached) * MISS_SHARE:
		result.fail("%s: %d of %d cells the grid reaches are off the mesh, e.g. %s" % [
			label, off_mesh, reached, str(_spread(off_at))])
	# A pocket the gate does not reach (the wedge behind a keep) is the grid's to
	# leave unreached; only floor a person can get to is held to it. Judged by
	# area at each polygon's centre: a slit between a pier and a wall, a few
	# centimetres wide, is a mitre the baker keeps and the grid pads shut.
	var stranded := 0.0
	var sampled := 0.0
	var stranded_at := PackedVector2Array()
	for sid in ground:
		for i in meshes[sid]["polygons"].size():
			if _find(graph, _key(sid, islands[sid][i])) != _find(graph, gate_in):
				continue
			var pts: PackedVector2Array = NavBake.points_of(meshes[sid], i)
			var area: float = Poly.area(pts)
			var centre := Vector2.ZERO
			for q in pts:
				centre += q
			centre /= float(pts.size())
			sampled += area
			if area >= 0.05 and not grid.reached(Rect2(centre, Vector2.ZERO), GRID_SLACK):
				stranded += area
				stranded_at.append(centre)
	result.checked += 1
	if stranded > sampled * MISS_SHARE:
		result.fail("%s: %.1f of %.1f m2 of mesh the gate reaches stands where the grid cannot walk, e.g. %s" % [
			label, stranded, sampled, str(_spread(stranded_at))])

	# the keep door's approach is where the forebuilding link starts
	var keep_at := ranges.find("keep")
	var keep_row := _row(builder, "keep")
	var keep_plan: HousePlan = keep_row.plan
	var nav := HouseNavCheck.new()
	nav.check(keep_plan)
	var rooms := 0
	for r in keep_plan.room_count():
		if r in nav.unreached_rooms:
			continue
		var sid := CastleWalkSources.storey_of(keep_at, HousePlan.record_storey(keep_plan.rooms[r]))
		if not meshes.has(sid):
			continue
		var centre := _world(HouseGeometry.room_floor_rect(keep_plan, r).get_center(), keep_row.transform)
		var node := _node(meshes, islands, sid, NavBake.closest_point(meshes[sid], centre))
		rooms += 1
		result.checked += 1
		if node < 0 or _find(graph, node) != _find(graph, gate_in):
			result.fail("%s: HouseNavCheck reaches keep room %d (%s) but the mesh and links do not" % [
				label, r, keep_plan.rooms[r]["kind"]])
	result.checked += 1
	if rooms < 2:
		result.fail("%s: only %d keep rooms were measured" % [label, rooms])

	# every range whose ground door the grid reaches is reached by the mesh
	var doors_walked := 0
	var grid_open := {}
	for i in ranges.size():
		var row := _row(builder, String(ranges[i]))
		if row.is_empty() or ranges[i] == "keep":
			continue
		var plan: HousePlan = row.plan
		for d in plan.doors:
			if not bool(d.get("exterior", false)) or HousePlan.record_storey(d) != 0:
				continue
			var normal: Vector2 = d["normal"]
			var outside := _world(Vector2(d["pos"]) + normal * (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.6), row.transform)
			if not grid.reached(Rect2(outside, Vector2.ZERO), 0.2):
				continue
			var inside := _world(Vector2(d["pos"]) - normal * (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.2), row.transform)
			var sid := CastleWalkSources.storey_of(i, 0)
			var node := _node(meshes, islands, sid, NavBake.closest_point(meshes[sid], inside))
			doors_walked += 1
			grid_open[String(ranges[i])] = true
			result.checked += 1
			if node < 0 or _find(graph, node) != _find(graph, gate_in):
				result.fail("%s: the grid reaches the door of %s but the mesh and links do not" % [label, ranges[i]])
	# A range the grid cannot get into (a chapel whose only door opens on the
	# apse) is one the mesh must not claim either; one it can, the mesh reaches.
	var seen := [false, false]
	for key in ["hall", "chapel"]:
		if not focus_reached.has(key):
			continue
		result.checked += 1
		if bool(focus_reached[key]) != grid_open.has(key):
			result.fail("%s: the %s is %s by the mesh and links but %s by the grid" % [label, key,
				"reached" if focus_reached[key] else "not reached", "reached" if grid_open.has(key) else "not reached"])
		seen[0 if key == "hall" else 1] = bool(focus_reached[key])
	result.checked += 1
	if doors_walked == 0:
		result.fail("%s: no range door was reached by the grid" % label)

	# --- the mesh stands on no prop and no piece of range furniture
	var worst := 0.0
	var what := ""
	var blockers := 0
	for prop in builder.prop_log:
		var rect := CastleWalkSources.prop_rect(prop)
		if rect.size.x <= 0.0:
			continue
		blockers += 1
		var o := _overlap(meshes[0], Poly.from_rect(rect))
		if o > worst:
			worst = o
			what = "ward prop %s" % prop["key"]
	for i in ranges.size():
		var row := _row(builder, String(ranges[i]))
		if row.is_empty():
			continue
		for p in row.plan.furniture:
			if p.get("mounted", false) or not PropCatalog.blocks_floor(String(p["key"])):
				continue
			var sid := CastleWalkSources.storey_of(i, HousePlan.record_storey(p))
			if not meshes.has(sid):
				continue
			blockers += 1
			var o := _overlap(meshes[sid], CastleWalkSources._world(Poly.from_rect(p["rect"]), row.transform))
			if o > worst:
				worst = o
				what = "%s in %s" % [p["key"], ranges[i]]
	result.checked += 2
	if worst > OVERLAP_M2:
		result.fail("%s: %.3f m2 of the mesh stands on %s" % [label, worst, what])
	if blockers < 3:
		result.fail("%s: only %d floor-blocking things to keep off" % [label, blockers])

	# --- the scene node: a region per storey, a link per linked connection
	var node3d: Node3D = BrickWild.navigation_node(building)
	var regions := 0
	var links3d := 0
	for child in node3d.get_children():
		regions += 1 if child is NavigationRegion3D else 0
		links3d += 1 if child is NavigationLink3D else 0
	node3d.free()
	result.checked += 1
	if regions != data["storeys"].size() or links3d != linked:
		result.fail("%s: navigation_node has %d regions and %d links for %d storeys and %d links" % [
			label, regions, links3d, data["storeys"].size(), linked])
	print("  %s: %d storeys, %d links, ward %.0f m2, %d/%d cells reached, %d foci, %d keep rooms, %.1f s" % [
		label, meshes.size(), data["stairs"].size(), NavBake.area(meshes[0]), reached, grid.nx * grid.nz / (STRIDE * STRIDE),
		focus_reached.size(), rooms, float(Time.get_ticks_msec() - started) / 1000.0])
	return seen


## The ward baked without its obstruction stands on the keep, and the walk
## without its links does not reach the lord's chamber: the measures that say
## otherwise are not tautologies.
static func _negative_control(result: SuiteResult) -> void:
	var c: Array = CASES[0]
	var building: GeneratedBuilding = BrickWild.generate(BuildingRequest.castle(c[4], c[0], c[1], c[2], c[3]))
	var spec := building.spec as CastleSpec
	var sources: Dictionary = CastleWalkSources.sources(spec)
	var keep := CastleGeometry.keep_aabb(spec)
	var body := Poly.from_rect(Rect2(keep.position.x, keep.position.z, keep.size.x, keep.size.z))
	var honest: Dictionary = NavBake.bake(sources[0]["floor"], sources[0]["obstacles"], BuildingNavigation.AGENT_RADIUS)
	var dropped: Array[PackedVector2Array] = []
	var broken: Dictionary = NavBake.bake(sources[0]["floor"], dropped, BuildingNavigation.AGENT_RADIUS)
	result.checked += 2
	if _overlap(honest, body) > OVERLAP_M2:
		result.fail("negative control: the honest ward already stands on the keep")
	if _overlap(broken, body) <= OVERLAP_M2:
		result.fail("negative control: a ward baked without obstruction is not caught standing on the keep")
	# the links: without them the gate does not reach the lord's chamber
	var data: Dictionary = BrickWild.navigation(building)
	var meshes := {}
	var islands := {}
	for row in data["storeys"]:
		var sid := int(row["storey"])
		meshes[sid] = {"vertices": _vertices(row["navmesh"]), "polygons": _polygons(row["navmesh"])}
		islands[sid] = NavBake.islands(meshes[sid])
	var gate_in := _node(meshes, islands, 0, _xz(data["doors"][0]["inside_m"]))
	var lords := {}
	for f in data["furniture"]:
		if f["key"] == "lords_chamber":
			lords = f
	result.checked += 3
	if lords.is_empty():
		result.fail("negative control: the castle has no lord's chamber")
		return
	var lords_node := _node(meshes, islands, int(lords["storey"]), _xz(lords["use_m"]))
	var with_links := _graph(data, meshes, islands)
	if _find(with_links, lords_node) != _find(with_links, gate_in):
		result.fail("negative control: the honest walk does not reach the lord's chamber")
	var without := _graph({"stairs": []}, meshes, islands)
	if _find(without, lords_node) == _find(without, gate_in):
		result.fail("negative control: a walk without links still reaches the lord's chamber")


## What is not walked says so: the unwalled tiers, a motte, a ridge and a castle
## with a barbican.
static func _unsupported(result: SuiteResult) -> void:
	for c in [[&"norman", 40.0, 50.0, 10.0, 3, "manor"], [&"norman", 120.0, 120.0, 14.0, 1, "motte"],
			[&"norman", 120.0, 120.0, 14.0, 2, "barbican"], [&"bavarian", 120.0, 120.0, 14.0, 1, "ridge"]]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.castle(c[4], c[0], c[1], c[2], c[3]))
		result.checked += 1
		if building.is_ok() and (BrickWild.navigation(building)["supported"] or BrickWild.navigation_node(building) != null):
			result.fail("castle (%s) claims an interior walk it does not publish" % c[5])


# ------------------------------------------------------------------ graph

## A handful of points spread through a list, for a failure message.
static func _spread(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in mini(points.size(), 6):
		var p := points[i * points.size() / 6]
		out.append(Vector2(snappedf(p.x, 0.1), snappedf(p.y, 0.1)))
	return out


static func _key(sid: int, island: int) -> int:
	return sid * 100000 + island


## A union-find over every (storey, island), joined by the links that reach.
static func _graph(data: Dictionary, meshes: Dictionary, islands: Dictionary) -> Dictionary:
	var parent := {}
	for sid in meshes:
		for k in islands[sid]:
			parent[_key(sid, k)] = _key(sid, k)
	for link in data["stairs"]:
		if not link["linked"]:
			continue
		var a := _node(meshes, islands, int(link["from_storey"]), _xz(link["lower_m"]))
		var b := _node(meshes, islands, int(link["to_storey"]), _xz(link["upper_m"]))
		if a >= 0 and b >= 0:
			parent[_find(parent, a)] = _find(parent, b)
	return parent


static func _find(parent: Dictionary, node: int) -> int:
	while parent[node] != node:
		parent[node] = parent[parent[node]]
		node = parent[node]
	return node


## The (storey, island) a point stands in, taking the nearest polygon so a
## point on a mesh edge still counts. -1 when the storey has none.
static func _node(meshes: Dictionary, islands: Dictionary, sid: int, p: Vector2) -> int:
	if not meshes.has(sid):
		return -1
	var mesh: Dictionary = meshes[sid]
	var best := -1
	var best_d := INF
	for i in mesh["polygons"].size():
		var pts: PackedVector2Array = NavBake.points_of(mesh, i)
		var d := 0.0
		if not Geometry2D.is_point_in_polygon(p, pts):
			d = INF
			for k in pts.size():
				d = minf(d, Geometry2D.get_closest_point_to_segment(p, pts[k], pts[(k + 1) % pts.size()]).distance_to(p))
		if d < best_d:
			best_d = d
			best = i
	if best < 0 or best_d > 0.05:
		return -1
	return _key(sid, islands[sid][best])


# ---------------------------------------------------------------- helpers

static func _row(builder: CastleBuilder, id: String) -> Dictionary:
	for row in builder.interiors:
		if String(row.id) == id:
			return row
	return {}


static func _world(p: Vector2, xf: Transform3D) -> Vector2:
	return CastleWalkSources._at(p, xf)


static func _overlap(mesh: Dictionary, body: PackedVector2Array) -> float:
	var shared := 0.0
	for i in mesh["polygons"].size():
		for piece in Geometry2D.intersect_polygons(NavBake.points_of(mesh, i), body):
			shared += Poly.area(piece)
	return shared


static func _vertices(data: Dictionary) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for v in data["vertices_m"]:
		vertices.append(Vector2(v[0], v[1]))
	return vertices


static func _polygons(data: Dictionary) -> Array[PackedInt32Array]:
	var polygons: Array[PackedInt32Array] = []
	for p in data["polygons"]:
		polygons.append(PackedInt32Array(p))
	return polygons


static func _mesh(data: Dictionary) -> Dictionary:
	return {"vertices": _vertices(data), "polygons": _polygons(data)}


static func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))
