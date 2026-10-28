class_name VillageNavCheck
extends RefCounted
## Can a person walk it? (VIL-016; VILLAGES §9.5)
##
## One `WalkGrid` over the whole site -- the same distance transform the house
## nav check and the temple rite check use, at a village's scale. Roads,
## paths, verges and the common are floor; buildings, water, the enclosure,
## fences, props with a footprint and tree trunks are obstruction; what
## survives being shrunk by a person's own half-width is where somebody can
## stand.
##
##   ARRIVE   from any gate you can reach any door
##   USE      every prop meant to be used can be got at
##   ROAD_OPEN  the through road is never pinched
##   PATHS    a door reaches its road without crossing a yard
##   COMMON   the common is mostly standable
##   OUTSIDE  the tracks and the mill are reachable from a gate
##
## The cell is chosen per village the way `VoxelGrid` chooses its voxel per
## castle: a hamlet is rasterised at a quarter metre and a four-hundred-metre
## site at a half, where the grid is still under a million cells. A finer
## grid on the cap would be a hundred megabytes and forty seconds, and a
## village is not measured in centimetres.

## `road_open` and not `road`: `DressCheck` has a `road` rule too (nothing
## STANDS in the road) and this one is a different sentence (the road is not
## PINCHED). Two rules whose failures begin with the same word cannot be told
## apart by anything that reads the report.
const RULES: Array[StringName] = [&"arrive", &"use", &"road_open", &"paths",
	&"common", &"outside"]

const PERSON_RADIUS := HouseGeometry.PERSON_RADIUS
## §9.5's cell size, by site side. Interpolated between these two.
const CELL_FINE := 0.25
const CELL_COARSE := 0.5
## A two-metre arrival court can lose half its measured width when rotated
## onto half-metre cells. Measure that bounded route at doorway resolution.
const CELL_APPROACH := 0.1
const SITE_FINE := 120.0
const SITE_COARSE := 400.0
## A door is `reached` if any cell within this of it was walked to. A door
## sits ON the wall, which is solid, and a shop's eaves overhang the little
## setback in front of it -- so the nearest ground a person can actually
## stand on is a stride away, not a centimetre.
const DOOR_REACH := 2.5
## A path from a door to its road has to stay this wide.
const PATH_WIDTH := 1.2
## How far out from a door to look for the first ground a person can stand on.
const PATH_SEARCH := 6.0
## And the through road this much of its own width, all along it.
const ROAD_PINCH := 0.5
## The share of the common a person must be able to stand on.
const COMMON_STANDABLE := 0.7

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}
var _grid: WalkGrid
var _reached_any := false


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	_grid = build_grid(plan)
	stats["cell"] = cell_for(plan)
	stats["walkable_m2"] = snappedf(_grid.walkable_area(), 1.0)
	_reached_any = _flood_from_gates(plan)
	if not _reached_any:
		failures.append("arrive: there is nowhere to stand at any gate into the village")
		return _report()
	stats["reached_m2"] = snappedf(float(_grid.reached_cells())
		* stats["cell"] * stats["cell"], 1.0)
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


## The cell a village of this size is rasterised at.
static func cell_for(plan: VillagePlan) -> float:
	var side: float = maxf(plan.site.size.x, plan.site.size.y)
	var t: float = clampf((side - SITE_FINE) / (SITE_COARSE - SITE_FINE), 0.0, 1.0)
	return snappedf(lerpf(CELL_FINE, CELL_COARSE, t), 0.05)


## The same reached floor used by QA, for placing usable outdoor furniture.
## Call after adding a candidate's real footprint so it cannot count ground
## occupied by that candidate as its own working space.
static func reached_grid(plan: VillagePlan) -> WalkGrid:
	var nav := VillageNavCheck.new()
	nav._grid = build_grid(plan)
	nav._flood_from_gates(plan)
	return nav._grid


## The grid itself, public because the builder and the Studio both want to
## look at the same walk the check judged.
##
## Order matters and is the whole of it: floor first, obstruction after.
## Roads and the common are laid down, then everything solid is cut out of
## them, so a barrel on a verge removes the verge under it rather than the
## other way round.
static func build_grid(plan: VillagePlan) -> WalkGrid:
	return _grid_for_bounds(plan, plan.site, cell_for(plan))


static func _grid_for_bounds(plan: VillagePlan, bounds: Rect2, cell_size: float) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.setup(bounds, cell_size)
	# floor: every road with its verge, and the common
	for road in plan.roads:
		grid.add_floor_poly(VillageSitePlanner.road_ribbon(road, true))
	for c in plan.commons:
		grid.add_floor_poly(c["poly"])
	# and the lots, which is the ground a person crosses to reach a door
	for lot in plan.lots:
		grid.add_floor_poly(lot["poly"])
	# Built working props may have an emitted dirt apron connecting them to
	# a verge. Add that real floor before water and all solid obstructions.
	for p in plan.props:
		if p.has("approach"):
			grid.add_floor_poly(p["approach"])
	# obstruction: what is actually there
	for b in plan.buildings:
		grid.add_obstacle_poly(VillageMeasure.bounds_poly(b))
		for poly in VillageMeasure.yard_polys(b):
			grid.add_obstacle_poly(poly)
	# Restore only explicit native arrival courts; the rest of each building's
	# full measured envelope remains an obstruction. Later props and water can
	# still block this route and are tested normally.
	for b in plan.buildings:
		if not b["placement"].has("approach"):
			continue
		var local: PackedVector2Array = Poly.from_rect(b["placement"]["approach"])
		var world := PackedVector2Array()
		var xf: Transform3D = b["transform"]
		for point in local:
			var p: Vector3 = xf * Vector3(point.x, 0.0, point.y)
			world.append(Vector2(p.x, p.z))
		grid.add_floor_poly(world)
	for w in plan.water:
		grid.add_obstacle_poly(w["poly"])
	for crossing in plan.water_crossings:
		grid.add_floor_poly(Poly.ribbon(crossing["points"],
			(float(crossing["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5),
			0.275 if crossing["kind"] == &"bridge" else 0.14)
	# a house on piles is reached over its landing (VTER-FORM-WATER)
	for landing in VillageWaterForm.landings(plan):
		grid.add_floor_poly(landing)
	# The boundary is a real obstruction. Only its authored gateways and
	# natural shore gaps are open; a plan must not walk through masonry.
	if plan.spec.enclosure != &"none":
		for e in plan.enclosure.size():
			for run in VillageBuilder._minus_gates(plan.enclosure[e], plan.enclosure[(e + 1) % plan.enclosure.size()], plan.gate_crossings):
				for part in VillageBuilder._water_edge_runs(plan, run[0], run[1]):
					if not part["wet"]:
						grid.add_obstacle_poly(Poly.ribbon(PackedVector2Array([part["a"], part["b"]]), VillageBuilder.WALL_THICK * 0.5))
	# Props and plants that take FLOOR, and only those. §9.5 says buildings,
	# water, walls, fences, props with footprints and tree TRUNKS -- a wall
	# lamp hangs above head height and grass is walked over, and the
	# catalogue already knows which is which (`blocks_floor`, the GROUND
	# tag). Blocking on every plant made the verges solid and pinched the
	# through road to nothing.
	for p in plan.props:
		var rect: Rect2 = p.get("rect", Rect2())
		if rect.size.x > 0.0 and (bool(p.get("built", false)) or PropCatalog.blocks_floor(String(p["key"]))):
			if p["key"] == "adit" and bool(p.get("built", false)):
				# A native mine mouth has a real clear gap between its heaps
				# and timber cheeks. Subtract only that measured local passage
				# from this prop, preserving all prior water/wall obstacles.
				for solid in Geometry2D.clip_polygons(Poly.from_rect(rect), PropKit.adit_passage(p["pos"], p["yaw"])):
					grid.add_obstacle_poly(solid)
			else:
				grid.add_obstacle(rect)
	for t in plan.plants:
		var key: String = String(t["key"])
		var trunk: float = float(t.get("trunk", 0.0))
		if trunk <= 0.0 or not PropCatalog.blocks_floor(key):
			continue
		grid.add_obstacle(Rect2(Vector2(t["pos"]) - Vector2(trunk, trunk),
			Vector2(trunk, trunk) * 2.0))
	grid.build(PERSON_RADIUS)
	return grid


## The same ground as `build_grid`, as outlines a navigation baker can union:
## {"floor": [{kind, id, poly}], "obstacles": [{kind, id, poly}]}. The grid
## paints in order and a baker does not, so what the grid restores after an
## obstacle is cut out of that obstacle here: an arrival court out of its
## building, a crossing out of its water. Change one, change the other.
static func sources(plan: VillagePlan) -> Dictionary:
	var floor: Array[Dictionary] = []
	var obstacles: Array[Dictionary] = []
	for r in plan.roads.size():
		floor.append({"kind": "road", "id": r, "poly": VillageSitePlanner.road_ribbon(plan.roads[r], true)})
	for c in plan.commons.size():
		floor.append({"kind": "common", "id": c, "poly": plan.commons[c]["poly"]})
	for l in plan.lots.size():
		floor.append({"kind": "lot", "id": l, "poly": plan.lots[l]["poly"]})
	var crossings: Array[PackedVector2Array] = []
	for crossing in plan.water_crossings:
		var ribbon: PackedVector2Array = Poly.ribbon(crossing["points"],
			(float(crossing["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5)
		crossings.append(ribbon)
		floor.append({"kind": "crossing", "id": crossings.size() - 1, "poly": ribbon})
	# the landings of houses on piles: floor over the water, cut out of it and
	# out of their buildings below (VTER-FORM-WATER)
	var landings := VillageWaterForm.landings(plan)
	for l in landings.size():
		floor.append({"kind": "landing", "id": l, "poly": landings[l]})
	for i in plan.props.size():
		if plan.props[i].has("approach"):
			floor.append({"kind": "approach", "id": i, "poly": plan.props[i]["approach"]})
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var solid: Array[PackedVector2Array] = [VillageMeasure.bounds_poly(b)]
		if b["placement"].has("approach"):
			var court := PackedVector2Array()
			var xf: Transform3D = b["transform"]
			for point in Poly.from_rect(b["placement"]["approach"]):
				var p: Vector3 = xf * Vector3(point.x, 0.0, point.y)
				court.append(Vector2(p.x, p.z))
			solid = _minus(solid, [court])
			floor.append({"kind": "court", "id": i, "poly": court})
		solid = _minus(solid, landings)
		for poly in solid:
			obstacles.append({"kind": "building", "id": i, "poly": poly})
		for poly in VillageMeasure.yard_polys(b):
			obstacles.append({"kind": "yard", "id": i, "poly": poly})
	var cutters: Array[PackedVector2Array] = crossings.duplicate()
	cutters.append_array(landings)
	for w in plan.water.size():
		for poly in _minus([plan.water[w]["poly"]], cutters):
			obstacles.append({"kind": "water", "id": w, "poly": poly})
	if plan.spec.enclosure != &"none":
		for e in plan.enclosure.size():
			for run in VillageBuilder._minus_gates(plan.enclosure[e], plan.enclosure[(e + 1) % plan.enclosure.size()], plan.gate_crossings):
				for part in VillageBuilder._water_edge_runs(plan, run[0], run[1]):
					if not part["wet"]:
						obstacles.append({"kind": "wall", "id": e, "poly": Poly.ribbon(
							PackedVector2Array([part["a"], part["b"]]), VillageBuilder.WALL_THICK * 0.5)})
	for i in plan.props.size():
		var p: Dictionary = plan.props[i]
		var rect: Rect2 = p.get("rect", Rect2())
		if rect.size.x <= 0.0 or not (bool(p.get("built", false)) or PropCatalog.blocks_floor(String(p["key"]))):
			continue
		if p["key"] == "adit" and bool(p.get("built", false)):
			for solid in Geometry2D.clip_polygons(Poly.from_rect(rect), PropKit.adit_passage(p["pos"], p["yaw"])):
				obstacles.append({"kind": "prop", "id": i, "poly": solid})
		else:
			obstacles.append({"kind": "prop", "id": i, "poly": Poly.from_rect(rect)})
	for i in plan.plants.size():
		var t: Dictionary = plan.plants[i]
		var trunk: float = float(t.get("trunk", 0.0))
		if trunk <= 0.0 or not PropCatalog.blocks_floor(String(t["key"])):
			continue
		obstacles.append({"kind": "trunk", "id": i, "poly": Poly.from_rect(
			Rect2(Vector2(t["pos"]) - Vector2(trunk, trunk), Vector2(trunk, trunk) * 2.0))})
	return {"floor": floor, "obstacles": obstacles}


## `polys` with every cutter taken out. A cutter wholly inside a polygon would
## leave a hole, which an obstruction outline cannot carry, so that polygon is
## split through the cutter's centre first and each half cut on its own.
static func _minus(polys: Array[PackedVector2Array], cutters: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = polys.duplicate()
	for cutter in cutters:
		var next: Array[PackedVector2Array] = []
		for poly in out:
			next.append_array(_cut(poly, cutter))
		out = next
	return out


static func _cut(poly: PackedVector2Array, cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array = Geometry2D.clip_polygons(poly, cutter)
	var holed := false
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece):
			holed = true
	var out: Array[PackedVector2Array] = []
	if not holed:
		for piece in pieces:
			out.append(piece)
		return out
	var box: Rect2 = Poly.bounding_rect(poly).grow(1.0)
	var mid: float = Poly.bounding_rect(cutter).get_center().x
	for half in [Rect2(box.position, Vector2(mid - box.position.x, box.size.y)),
			Rect2(Vector2(mid, box.position.y), Vector2(box.end.x - mid, box.size.y))]:
		for piece in Geometry2D.intersect_polygons(poly, Poly.from_rect(half)):
			if not Geometry2D.is_polygon_clockwise(piece):
				out.append_array(_cut(piece, cutter))
	return out


## The first ground outside a building's door a person can stand on, on a
## grid `build_grid` made: the check's own threshold, for an exporter.
static func threshold_on(plan: VillagePlan, grid: WalkGrid, building: int) -> Vector2:
	var nav := VillageNavCheck.new()
	nav._grid = grid
	return nav._threshold(plan, building)


## Walk in from the gates. A village with no enclosure is entered at the ends
## of its through road, which is what `VillageMeasure.gates` already says.
func _flood_from_gates(plan: VillagePlan) -> bool:
	for g in VillageMeasure.gates(plan):
		if _grid.flood_from(g, 3.0):
			return true
	# nothing at a gate: try the middle of the through road, so a village
	# whose gates are off the road still gets judged rather than skipped
	for r in plan.roads_of_class(&"through"):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		if _grid.flood_from(pts[pts.size() / 2], 4.0):
			return true
	return false


# ----------------------------------------------------------------- arrive

## From a gate you can reach every door. This is the rule the whole check
## exists for: a village you cannot walk into is not a village.
func _check_arrive(plan: VillagePlan) -> void:
	var unreached: Array[int] = []
	for i in range(plan.buildings.size()):
		var step: Vector2 = _threshold(plan, i)
		if step == Vector2.INF:
			unreached.append(i)
		elif not _grid.reached(Rect2(step, Vector2.ZERO), DOOR_REACH):
			unreached.append(i)
	stats["unreached_doors"] = unreached.size()
	if unreached.is_empty():
		return
	var names: Array[String] = []
	for i in unreached.slice(0, 4):
		names.append("%d (%s)" % [i, String(plan.buildings[i]["kind"])])
	failures.append("arrive: %d of %d doors cannot be walked to from a gate: %s"
		% [unreached.size(), plan.buildings.size(), ", ".join(names)])


## The first ground outside a building's door that a person can actually
## stand on, or INF when there is none within `PATH_SEARCH`.
##
## A door sits ON the wall and the wall is solid; a townhouse shop is set
## back six-tenths of a metre and its eaves overhang the verge, so the first
## standing ground outside its door is the road. Asking about the door's own
## cell asks about the inside of a wall.
func _threshold(plan: VillagePlan, building: int) -> Vector2:
	var b: Dictionary = plan.buildings[building]
	var out_dir: Vector2 = VillageMeasure.front_dir(b)
	var door: Vector2 = VillageMeasure.door(b)
	var cell: float = cell_for(plan)
	var reach: float = PERSON_RADIUS + 0.3
	while reach <= PATH_SEARCH:
		var p: Vector2 = door + out_dir * reach
		if _grid.standable(Rect2(p, Vector2.ZERO), cell):
			return p
		reach += cell
	return Vector2.INF


# -------------------------------------------------------------------- use

## Every prop that is meant to be USED can be got at: the well, the stalls,
## the benches. A prop with an empty zone is furniture you walk past, and it
## is not asked about.
func _check_use(plan: VillagePlan) -> void:
	var stranded: Array[String] = []
	var asked := 0
	for p in plan.props:
		var zone: Rect2 = p.get("zone", Rect2())
		if zone.size.x <= 0.0:
			continue
		asked += 1
		# Can you stand NEXT to it. The zone box is centred on the piece and
		# the piece is solid, so asking whether the box itself was reached
		# asks whether a person can stand inside the well.
		if not _grid.reached(p.get("rect", Rect2(p["pos"], Vector2.ZERO)),
				PERSON_RADIUS + 0.4):
			stranded.append("%s at %v (host %d)" % [String(p["key"]), p["pos"], int(p.get("host", -1))])
	stats["usable_props"] = asked
	if not stranded.is_empty():
		failures.append("use: %d props cannot be got at: %s"
			% [stranded.size(), ", ".join(stranded.slice(0, 4))])


# -------------------------------------------------------------- road_open

## The through road is never pinched: half its own width of clear floor all
## along its centreline. A cart has to get through, and a village that has
## grown a barrel into its only road has stopped being on the way anywhere.
func _check_road_open(plan: VillagePlan) -> void:
	for r in plan.roads_of_class(&"through"):
		var road: Dictionary = plan.roads[r]
		var want: float = float(road["width"]) * ROAD_PINCH
		var pts: PackedVector2Array = road["points"]
		# Not the very ends. A through road runs from one edge of the site to
		# the other by definition, and the grid stops at the site -- so the
		# last sample measures the width of the world and reports nought.
		var first: int = 1 if pts.size() >= 4 else 0
		var last: int = pts.size() - (2 if pts.size() >= 4 else 1)
		var narrowest := INF
		for i in range(first, last):
			narrowest = minf(narrowest, _grid.clearance_along(pts[i], pts[i + 1],
				float(road["width"])))
		stats["road_clear"] = snappedf(narrowest, 0.1)
		if narrowest < want:
			failures.append("road_open: the through road narrows to %.1fm, wants %.1f"
				% [narrowest, want])
			return


# ------------------------------------------------------------------ paths

## A door reaches its own road without squeezing.
##
## §9.5 says "a `path` from every door to its road, >= 1.2 m clear the whole
## way", and the site planner lays no `path` roads at all yet (VIL-003
## follow-up). So this measures the two halves of the sentence it CAN:
##
##   * there is standing ground outside every door at all, and
##   * where a `path` road does exist, it is PATH_WIDTH clear along it.
##
## What it deliberately does not do is measure the straight line from the
## door to the middle of the lot's frontage. On a jettied townhouse the
## frontage line is under the eaves, so that run starts on the road and ends
## inside a building and is nought metres wide by construction -- which says
## something about the measurement and nothing about the village.
func _check_paths(plan: VillagePlan) -> void:
	var pinched: Array[String] = []
	for i in range(plan.buildings.size()):
		if _threshold(plan, i) == Vector2.INF:
			pinched.append("%d (%s: no standing ground at its door)"
				% [i, String(plan.buildings[i]["kind"])])
		var b: Dictionary = plan.buildings[i]
		if b["placement"].has("approach"):
			if _approach_clearance(plan, b) < PATH_WIDTH:
				pinched.append("%d (courtyard approach)" % i)
	# a stair is a footway too: it must be as clear as a path (VTER-ROADS)
	var paths: Array[int] = plan.roads_of_class(&"path") + plan.roads_of_class(&"steps")
	stats["paths"] = paths.size()
	for r in paths:
		var pts: PackedVector2Array = plan.roads[r]["points"]
		for k in range(pts.size() - 1):
			var from: Vector2 = pts[k]
			var to: Vector2 = pts[k + 1]
			# a ribbon's end is a flat cap: the cells beside its last point are
			# off it, however wide the way. A dead end is measured to a cell
			# short of its tip (a stair up to the site's edge, VTER-VALLEY-GORGE).
			var seg_len: float = from.distance_to(to)
			if seg_len > _grid.cell * 4.0:
				if k == 0:
					from = from.move_toward(to, _grid.cell)
				if k == pts.size() - 2:
					to = to.move_toward(from, _grid.cell)
			var wide: float = _grid.clearance_along(from, to, 3.0)
			if wide < PATH_WIDTH:
				pinched.append("%s %d (%.1fm)" % [String(plan.roads[r]["class"]), r, wide])
				break
	stats["pinched_paths"] = pinched.size()
	if not pinched.is_empty():
		failures.append("paths: %d doors or paths are under %.1fm clear: %s"
			% [pinched.size(), PATH_WIDTH, ", ".join(pinched.slice(0, 4))])


## Use the same floor and obstacles as the village flood, cropped around the
## approach. Only its measurement resolution changes; water, trunks and props
## still obstruct it, and the global flood still decides whether it is reached.
static func _approach_clearance(plan: VillagePlan, building: Dictionary) -> float:
	var approach: Rect2 = building["placement"]["approach"]
	var xf: Transform3D = building["transform"]
	var a: Vector3 = xf * Vector3(approach.get_center().x, 0.0, approach.position.y + 0.5)
	var z: Vector3 = xf * Vector3(approach.get_center().x, 0.0, approach.end.y - 1.0)
	var start := Vector2(a.x, a.z)
	var end := Vector2(z.x, z.z)
	var bounds := Rect2(start, Vector2.ZERO).expand(end).grow(3.0).intersection(plan.site)
	var local := _grid_for_bounds(plan, bounds, CELL_APPROACH)
	return local.clearance_along(start, end, 3.0)


# ----------------------------------------------------------------- common

## The common is mostly standable. It is the one place in the village where
## nothing is built, and a green a person cannot walk on is a green in name.
func _check_common(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	if common.is_empty():
		return
	var rect: Rect2 = Poly.bounding_rect(common)
	var cell: float = cell_for(plan)
	var inside := 0
	var standable := 0
	var x: float = rect.position.x
	while x <= rect.end.x:
		var y: float = rect.position.y
		while y <= rect.end.y:
			var p := Vector2(x, y)
			if Poly.contains_point(common, p):
				inside += 1
				if _grid.standable(Rect2(p, Vector2.ZERO), cell):
					standable += 1
			y += cell
		x += cell
	if inside == 0:
		return
	var share: float = float(standable) / float(inside)
	stats["common_standable"] = snappedf(share, 0.01)
	if share < COMMON_STANDABLE:
		failures.append("common: only %.0f%% of the common can be stood on, wants %.0f%%"
			% [share * 100.0, COMMON_STANDABLE * 100.0])


# ---------------------------------------------------------------- outside

## The fields and the mill are reachable: every field track's far end, and
## the mill's own door, walked to from a gate. Runs only when the plan has
## them -- a village with no tracks has no fields to get out to.
func _check_outside(plan: VillagePlan) -> void:
	var tracks: Array[int] = plan.roads_of_class(&"track")
	var stranded := 0
	for r in tracks:
		var pts: PackedVector2Array = plan.roads[r]["points"]
		if not _grid.reached(Rect2(pts[pts.size() - 1], Vector2.ZERO), DOOR_REACH * 2.0):
			stranded += 1
	stats["stranded_tracks"] = stranded
	if stranded > 0:
		failures.append("outside: %d of %d field tracks cannot be walked to their far end"
			% [stranded, tracks.size()])
	for i in VillageMeasure.shops_of(plan, &"bakery"):
		if not _has_recipe(plan, &"mill"):
			break
		var door: Vector2 = VillageMeasure.door(plan.buildings[i])
		if not _grid.reached(Rect2(door, Vector2.ZERO), DOOR_REACH):
			failures.append("outside: the mill's door cannot be walked to")
			return


static func _has_recipe(plan: VillagePlan, kind: StringName) -> bool:
	for row in plan.spec.programme:
		if row["kind"] == kind:
			return true
	return false


# -------------------------------------------------------------------- map

## The walk, drawn. Reach for this before theorising about why a door cannot
## be reached: it shows the pinch in a second, which is exactly what
## `HouseNavCheck.ascii_map` is for indoors.
##
## `WalkGrid` draws the grid itself -- `#` solid, ` ` walked to, `:` standable
## but never reached, `.` no floor at all -- and this adds what a village has
## that a room does not: `G` a gate, `T` a tree.
func ascii_map(plan: VillagePlan, marks := {}) -> String:
	if _grid == null:
		_grid = build_grid(plan)
		_flood_from_gates(plan)
	var all := marks.duplicate()
	for g in VillageMeasure.gates(plan):
		all[g] = "G"
	for t in plan.plants:
		if float(t.get("canopy", 0.0)) >= 1.0:
			all[t["pos"]] = "T"
	return _grid.ascii_map(all)
