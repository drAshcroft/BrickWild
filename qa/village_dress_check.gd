class_name VillageDressCheck
extends RefCounted
## Do the props and plants belong? (VIL-015; VILLAGES §9.6)
##
## Twelve rules over what `VillageDresser` put outside, each a sentence and a
## measurement. The dresser tries to place well; this refuses to believe it
## did, and re-derives every footprint, every trunk and every canopy from the
## placements alone:
##
##   HOST       every prop belongs to something -- its host's lot, or the common
##   DOORWAYS   nothing in the swing of a door
##   ROAD       nothing on a carriageway or its verge, prop or trunk
##   STALLS     a stall faces an aisle, not another stall
##   FENCES     a fence is on a boundary and has a way through it
##   CANOPIES   a trunk off the road and the buildings, a canopy off the roofs
##   EDGE       the village is bounded by something you can see
##   GREEN      a few trees on the common at most, and none over the well
##   COVER      ground cover on the ground and off the road
##   LIGHTS     the night has somewhere to go
##   FIELDS     fields and pasture outside the edge, touching a track
##   CULTURE    every plant is in the culture's own palette
##
## The rules that are about things the planner does not yet lay -- fences,
## fields, pasture -- run only when the plan carries them, the same way
## `VillagePlaceCheck` treats the mill and the market. A rule that measures
## nothing says nothing; the fixtures in `VillageCheckSuite` build each of
## those by hand to prove it can still fire.

const RULES: Array[StringName] = [&"host", &"doorways", &"road", &"stalls",
	&"fences", &"canopies", &"edge", &"green", &"cover", &"lights",
	&"fields", &"wood", &"culture"]

## A prop may sit this far outside its host's lot before it is somebody
## else's problem: half a metre of slack for a barrel against a wall on the
## lot line.
const HOST_SLACK := 0.5
## Nothing in this much of a door's own threshold.
const DOOR_CLEAR := 1.2
## A trunk stands at least this far off any road polygon and any bounds.
const TRUNK_CLEAR := 1.0
## A canopy over a roof at all is a canopy over a roof; this is the slack.
const CANOPY_SLACK := 0.1
## Two rows of stalls with less than this between them are not two rows.
const AISLE_MIN := 4.0
## A gap in a closed fence a person can get through.
const FENCE_GAP := 1.2
## Walking the edge, no run longer than this without something to see.
const EDGE_RUN_MAX := 25.0
## And "something to see" means within this of the edge.
const EDGE_REACH := 6.0
## Trees on the common: a few, and none this close to the well.
const GREEN_TREES_MAX := 3
const WELL_TREE_CLEAR := 4.0
## Every door within this of a light.
const DOOR_TO_LIGHT := 25.0

## The categories §9.6 calls ground cover: they lie on the ground and a
## person walks over them.
const COVER_CATS := ["grass", "flower", "ground_cover", "pebble",
	"stepping_stone", "mushroom"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["props"] = plan.props.size()
	stats["plants"] = plan.plants.size()
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


# ------------------------------------------------------------------- host

## Every prop belongs to something: it stands on its host's lot, or on the
## common, or -- for the places that are not buildings -- inside the site.
## A prop with a host index that is not a building is a bug, not a bench.
func _check_host(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	for i in range(plan.props.size()):
		var p: Dictionary = plan.props[i]
		var host: int = int(p.get("host", -1))
		var at: Vector2 = p["pos"]
		if host >= plan.buildings.size() or host < -1:
			failures.append("host: prop %d (%s) names building %d, which is not one"
				% [i, String(p["key"]), host])
			continue
		if host < 0:
			# a place, not a building: it belongs to the village at large
			if not plan.site.has_point(at):
				failures.append("host: %s stands outside the site" % String(p["key"]))
			continue
		var lot: int = plan.lot_of_building(host)
		if lot < 0:
			continue
		var poly: PackedVector2Array = Poly.offset(plan.lots[lot]["poly"], HOST_SLACK)
		if Poly.contains_point(poly, at):
			continue
		if not common.is_empty() and Poly.contains_point(common, at):
			continue
		# ...or on the verge in front of its own lot, which is where §7's
		# `verge` rule puts a bench and a barrel on purpose. The verge is
		# road, not lot, so a rule that only knew about lots called every one
		# of them homeless.
		if _on_a_verge(plan, at):
			continue
		failures.append("host: %s of building %d stands on neither its lot, the common nor a verge"
			% [String(p["key"]), host])


## Is this point on a road's verge -- inside the ribbon WITH its verge but
## outside the carriageway itself? A prop on the carriageway is the `road`
## rule's business and fails there.
static func _on_a_verge(plan: VillagePlan, at: Vector2) -> bool:
	for road in plan.roads:
		if Poly.contains_point(VillageSitePlanner.road_ribbon(road, true), at):
			return true
	return false


# --------------------------------------------------------------- doorways

## Nothing in the swing of a door -- the same rectangle the house furnisher
## keeps clear indoors, applied to the door the village actually uses.
func _check_doorways(plan: VillagePlan) -> void:
	for b in range(plan.buildings.size()):
		var door: Vector2 = VillageMeasure.door(plan.buildings[b])
		var swing := Rect2(door - Vector2(DOOR_CLEAR, DOOR_CLEAR),
			Vector2(DOOR_CLEAR, DOOR_CLEAR) * 2.0)
		for p in plan.props:
			if swing.intersects(p.get("rect", Rect2(p["pos"], Vector2.ZERO))):
				failures.append("doorways: %s stands in building %d's doorway"
					% [String(p["key"]), b])
				return
		for t in plan.plants:
			if swing.has_point(t["pos"]):
				failures.append("doorways: a %s stands in building %d's doorway"
					% [String(t["key"]), b])
				return


# ------------------------------------------------------------------- road

## `RoadCheck.clear`, applied to the dressing: a prop's own USE space against
## the carriageway and its verge, and every trunk out of it.
func _check_road(plan: VillagePlan) -> void:
	for r in range(plan.roads.size()):
		var verged: PackedVector2Array = VillageSitePlanner.road_ribbon(plan.roads[r], true)
		for p in plan.props:
			var zone: Rect2 = p.get("zone", Rect2())
			var foot: Rect2 = zone if zone.size.x > 0.0 else p.get("rect", Rect2())
			if foot.size.x <= 0.0:
				continue
			if VillageLotPlanner.overlap_area(Poly.from_rect(foot), verged) \
					> VillageLotPlanner.AREA_EPS:
				failures.append("road: %s stands in %s %d"
					% [String(p["key"]), String(plan.roads[r]["class"]), r])
				return
		for t in plan.plants:
			if float(t.get("trunk", 0.0)) <= 0.0:
				continue
			if Poly.contains_point(verged, t["pos"]):
				failures.append("road: a %s trunk stands in %s %d"
					% [String(t["key"]), String(plan.roads[r]["class"]), r])
				return


# ----------------------------------------------------------------- stalls

## A market is rows with aisles between them, and a stall serves the aisle:
## its own local -Z points across one, never into the back of another stall.
func _check_stalls(plan: VillagePlan) -> void:
	var stalls: Array[int] = []
	for i in range(plan.props.size()):
		if PropCatalog.category(String(plan.props[i]["key"])) in ["stall", "counter"]:
			stalls.append(i)
	stats["stalls"] = stalls.size()
	if stalls.size() < 2:
		return
	for a in stalls:
		var pa: Dictionary = plan.props[a]
		var facing: Vector2 = _facing_of(pa)
		for b in stalls:
			if a == b:
				continue
			var pb: Dictionary = plan.props[b]
			var to: Vector2 = Vector2(pb["pos"]) - Vector2(pa["pos"])
			if to.length() > AISLE_MIN:
				continue
			if to.normalized().dot(facing) > 0.85:
				failures.append("stalls: %s at %v faces the back of another stall %.1fm away"
					% [String(pa["key"]), pa["pos"], to.length()])
				return


static func _facing_of(prop: Dictionary) -> Vector2:
	var yaw: float = float(prop.get("yaw", 0.0))
	return Vector2(-sin(yaw), -cos(yaw))


# ----------------------------------------------------------------- fences

## A fence lies on a boundary -- a lot's or a pasture's -- and a closed loop
## of it has a way through. Runs only when the plan carries fences; the
## planner does not lay them yet (VIL-016), and the fixture proves the rule
## fires on a plan that does.
func _check_fences(plan: VillagePlan) -> void:
	var rails: Array[int] = []
	for i in range(plan.props.size()):
		if PropCatalog.category(String(plan.props[i]["key"])) == "rail":
			rails.append(i)
	stats["fences"] = rails.size()
	if rails.is_empty():
		return
	for i in rails:
		var at: Vector2 = plan.props[i]["pos"]
		if _on_a_boundary(plan, at):
			continue
		failures.append("fences: a rail at %v is on no lot or field boundary" % at)
		return
	# a closed run with no gap is a pen nobody can get into
	var gap := false
	for a in rails:
		var near := INF
		for b in rails:
			if a == b:
				continue
			near = minf(near, Vector2(plan.props[a]["pos"]).distance_to(plan.props[b]["pos"]))
		if near >= FENCE_GAP:
			gap = true
	if not gap and rails.size() > 3:
		failures.append("fences: %d rails and no gap %.1fm wide to get through them"
			% [rails.size(), FENCE_GAP])


static func _on_a_boundary(plan: VillagePlan, at: Vector2) -> bool:
	for lot in plan.lots:
		if VillageMeasure.point_to_poly(at, lot["poly"]) <= 1.0:
			return true
	for f in plan.fields:
		if VillageMeasure.point_to_poly(at, f["poly"]) <= 1.0:
			return true
	return false


# -------------------------------------------------------------- canopies

## Trees do not stand in the road and do not grow through roofs. The trunk is
## the footprint, the canopy is the crown, and the catalogue measured both --
## a bounding box would call a birch two metres wide and put it nowhere.
func _check_canopies(plan: VillagePlan) -> void:
	var bounds: Array[PackedVector2Array] = []
	for b in plan.buildings:
		bounds.append(VillageMeasure.bounds_poly(b))
	for t in plan.plants:
		var trunk: float = float(t.get("trunk", 0.0))
		var canopy: float = float(t.get("canopy", 0.0))
		var at: Vector2 = t["pos"]
		if trunk <= 0.0:
			continue
		for bi in range(bounds.size()):
			var d: float = VillageMeasure.point_to_poly(at, bounds[bi])
			if Poly.contains_point(bounds[bi], at) or d < trunk + TRUNK_CLEAR - 0.01:
				failures.append("canopies: a %s trunk stands %.1fm from building %d"
					% [String(t["key"]), d, bi])
				return
			if canopy > 0.0 and not Poly.contains_point(bounds[bi], at) \
					and d < canopy - CANOPY_SLACK:
				failures.append("canopies: a %s canopy hangs %.1fm over building %d"
					% [String(t["key"]), canopy - d, bi])
				return


# ------------------------------------------------------------------- edge

## The village is bounded by something a person can see. Walking the edge --
## the enclosure where there is one, the site's own boundary where there is
## not -- no run longer than EDGE_RUN_MAX without a building back, a hedge, a
## wall or a tree within reach, except where a road or the water crosses it.
func _check_edge(plan: VillagePlan) -> void:
	# Compact displays dress the occupied streets, without a perimeter ring.
	if not VillageDresser.edge_band_required(plan.spec):
		return
	var edge: PackedVector2Array = plan.enclosure
	if edge.size() < 3 and plan.spec.enclosure != &"none":
		var derived: Dictionary = VillageEnclosurePlan.build(plan)
		edge = derived["edge"]
	if edge.size() < 3:
		edge = Poly.from_rect(plan.site.grow(-1.0))
	if edge.size() < 3:
		return
	var gates: Array[Vector2] = VillageMeasure.gates(plan)
	# bounding rects for the cheap rejection: the perimeter is walked at two
	# metres and every sample would otherwise measure its distance to every
	# building's polygon
	var boxes: Array[Rect2] = []
	var polys: Array[PackedVector2Array] = []
	for b in plan.buildings:
		var poly: PackedVector2Array = VillageMeasure.bounds_poly(b)
		polys.append(poly)
		boxes.append(Poly.bounding_rect(poly).grow(EDGE_REACH))
	var run := 0.0
	var worst := 0.0
	var n: int = edge.size()
	for i in range(n):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % n]
		var steps: int = maxi(int(a.distance_to(b) / 2.0), 1)
		for k in range(steps):
			var p: Vector2 = a.lerp(b, (float(k) + 0.5) / float(steps))
			if _edge_is_held(plan, gates, p, boxes, polys):
				run = 0.0
				continue
			run += a.distance_to(b) / float(steps)
			worst = maxf(worst, run)
	stats["edge_run"] = snappedf(worst, 0.1)
	if worst > EDGE_RUN_MAX:
		failures.append("edge: %.0fm of the village's edge has nothing to see on it, wants <= %.0f"
			% [worst, EDGE_RUN_MAX])


static func _edge_is_held(plan: VillagePlan, gates: Array[Vector2], p: Vector2,
		boxes: Array[Rect2], polys: Array[PackedVector2Array]) -> bool:
	# Masonry and stakes are emitted continuously by VillageBuilder. A hedge
	# is the dresser's actual planted row: its requested kind alone cannot
	# prove that any bushes were successfully placed.
	if plan.spec.enclosure in [&"palisade", &"wall"]:
		return true
	for g in gates:
		if p.distance_to(g) <= EDGE_REACH * 1.5:
			return true          # a gate is a hole on purpose
	for t in plan.plants:
		if _visible_edge_plant(t) and p.distance_to(t["pos"]) <= EDGE_REACH:
			return true
	for i in range(boxes.size()):
		if boxes[i].has_point(p) 				and VillageMeasure.point_to_poly(p, polys[i]) <= EDGE_REACH:
			return true
	for w in plan.water:
		if VillageMeasure.point_to_poly(p, w["poly"]) <= EDGE_REACH:
			return true
	return false


## The catalogue, not an authored radius, proves that a real upright plant
## would be visible here. Grass, pebbles and unknown model names cannot stand
## in for the requested shrub row, even when their records follow its edge.
static func _visible_edge_plant(plant: Dictionary) -> bool:
	var key := String(plant.get("key", ""))
	if not PropCatalog.known(key) or not PropCatalog.has_tag(key, PropCatalog.PLANT) \
			or PropCatalog.has_tag(key, PropCatalog.GROUND):
		return false
	var size := PropCatalog.size(key)
	return size.y >= 0.5 and minf(size.x, size.z) >= 0.25


# ------------------------------------------------------------------ green

## A common is open ground. A few trees on it at most, and none over the well.
func _check_green(plan: VillagePlan) -> void:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	if common.is_empty():
		return
	var on_it: Array[Dictionary] = []
	for t in plan.plants:
		if float(t.get("canopy", 0.0)) < 1.0:
			continue          # ground cover is not a tree
		if Poly.contains_point(common, t["pos"]):
			on_it.append(t)
	stats["green_trees"] = on_it.size()
	if on_it.size() > GREEN_TREES_MAX:
		failures.append("green: %d trees on the common, wants at most %d"
			% [on_it.size(), GREEN_TREES_MAX])
	for p in plan.props:
		if not String(p["key"]).to_lower().contains("well"):
			continue
		for t in on_it:
			var d: float = Vector2(t["pos"]).distance_to(p["pos"])
			if d < WELL_TREE_CLEAR:
				failures.append("green: a %s grows %.1fm from the well, wants %.0f"
					% [String(t["key"]), d, WELL_TREE_CLEAR])
				return


# ------------------------------------------------------------------ cover

## Ground cover lies on the ground: on a verge, the common, a lot or the
## edge -- never on a carriageway, which the `road` rule above already holds
## for trunks. This one is about the cover that has no trunk at all.
func _check_cover(plan: VillagePlan) -> void:
	var ways: Array[PackedVector2Array] = []
	for road in plan.roads:
		ways.append(VillageSitePlanner.road_ribbon(road, false))
	var count := 0
	for t in plan.plants:
		if not PropCatalog.category(String(t["key"])) in COVER_CATS:
			continue
		count += 1
		for way in ways:
			if Poly.contains_point(way, t["pos"]):
				failures.append("cover: a %s lies on the carriageway" % String(t["key"]))
				return
	stats["cover"] = count


# ----------------------------------------------------------------- lights

## The night has somewhere to go: every gate lit, and every door within reach
## of a light. Warned rather than failed where the planner has not laid the
## thing yet -- a village with no gates has no gate lights to want.
func _check_lights(plan: VillagePlan) -> void:
	var lights: Array[Vector2] = []
	for p in plan.props:
		if bool(p.get("light", false)) or PropCatalog.has_tag(String(p["key"]), PropCatalog.LIGHT):
			lights.append(p["pos"])
	stats["lights"] = lights.size()
	if lights.is_empty():
		warnings.append("lights: nothing outside is lit at all")
		return
	for g in VillageMeasure.gates(plan):
		var near := INF
		for l in lights:
			near = minf(near, g.distance_to(l))
		if near > DOOR_TO_LIGHT:
			warnings.append("lights: a gate at %v is %.0fm from the nearest light" % [g, near])
			break
	var dark := 0
	for b in plan.buildings:
		var door: Vector2 = VillageMeasure.door(b)
		var near2 := INF
		for l in lights:
			near2 = minf(near2, door.distance_to(l))
		if near2 > DOOR_TO_LIGHT:
			dark += 1
	stats["dark_doors"] = dark
	if dark > 0:
		warnings.append("lights: %d of %d doors are more than %.0fm from a light"
			% [dark, plan.buildings.size(), DOOR_TO_LIGHT])


# ----------------------------------------------------------------- fields

## Fields and pasture are the OUTSIDE: every one of them beyond the edge, and
## every one reachable by a track. Runs only when the plan carries fields.
func _check_fields(plan: VillagePlan) -> void:
	if plan.fields.is_empty():
		return
	var edge: PackedVector2Array = plan.enclosure
	if edge.size() < 3 and plan.spec.enclosure != &"none":
		var derived: Dictionary = VillageEnclosurePlan.build(plan)
		edge = derived["edge"]
	var tracks: Array[int] = plan.roads_of_class(&"track")
	for i in range(plan.fields.size()):
		var poly: PackedVector2Array = plan.fields[i]["poly"]
		if not edge.is_empty() \
				and VillageLotPlanner.overlap_area(poly, edge) > VillageLotPlanner.AREA_EPS:
			failures.append("fields: %s %d lies inside the village's edge"
				% [String(plan.fields[i].get("kind", &"field")), i])
			return
		var touched := false
		for r in tracks:
			for p in plan.roads[r]["points"]:
				if VillageMeasure.point_to_poly(p, poly) <= 6.0 or Poly.contains_point(poly, p):
					touched = true
		if not touched and not tracks.is_empty():
			failures.append("fields: %s %d touches no track"
				% [String(plan.fields[i].get("kind", &"field")), i])
			return


## A wood is the far-side landmark, not a few edge trees scattered wherever
## the dresser happened to find room. The derived point is the shared contract
## with VillageEnclosurePlan, and every accepted tree must remain outside it.
func _check_wood(plan: VillagePlan) -> void:
	if plan.spec.enclosure == &"none":
		return
	var derived: Dictionary = VillageEnclosurePlan.build(plan)
	var edge: PackedVector2Array = derived["edge"]
	var wood: Vector2 = derived["wood"]
	var found := false
	for tree in plan.plants:
		if not _visible_edge_plant(tree) or PropCatalog.canopy(String(tree["key"])) < 1.0:
			continue
		var at: Vector2 = tree["pos"]
		if plan.water.any(func(water: Dictionary) -> bool: return Poly.contains_point(water["poly"], at)):
			continue
		if at.distance_to(wood) <= 10.0 and not Poly.contains_point(edge, at):
			found = true
			break
	if not found:
		failures.append("wood: no tree marks the far-side wood outside the enclosure")


# ---------------------------------------------------------------- culture

## Every plant in the culture's own palette. A village that mixes two
## palettes reads as two villages, and this is the rule that says so.
func _check_culture(plan: VillagePlan) -> void:
	var allowed := {}
	for slot in ["edge", "green", "hedge", "ground", "wild", "reed"]:
		for key in VillageDressRules.palette_keys(
				{"palette": VillageDressCatalog.PALETTES.get(plan.spec.culture,
					VillageDressCatalog.PALETTES[&"english"])}, slot):
			allowed[key] = true
	if allowed.is_empty():
		return
	for t in plan.plants:
		if not allowed.has(String(t["key"])):
			failures.append("culture: a %s is not in the %s palette"
				% [String(t["key"]), String(plan.spec.culture)])
			return


# -------------------------------------------------------------- the map

## What is out there, drawn. `#` a building, `=` a road, `.` the common,
## `T` a tree, `o` a prop, `*` a light.
static func ascii_map(plan: VillagePlan, cols := 78) -> String:
	var site: Rect2 = plan.site
	var cell: float = maxf(site.size.x / float(cols), 0.001)
	var rows: int = maxi(int(site.size.y / cell / 2.0), 1)
	var grid: Array = []
	for r in range(rows):
		grid.append(" ".repeat(cols).split(""))
	var put := func(p: Vector2, ch: String) -> void:
		var cx: int = int((p.x - site.position.x) / cell)
		var cy: int = int((p.y - site.position.y) / cell / 2.0)
		if cx >= 0 and cx < cols and cy >= 0 and cy < rows:
			grid[cy][cx] = ch
	for road in plan.roads:
		var pts: PackedVector2Array = road["points"]
		for i in range(pts.size() - 1):
			var steps: int = maxi(int(pts[i].distance_to(pts[i + 1]) / cell), 1)
			for k in range(steps + 1):
				put.call(pts[i].lerp(pts[i + 1], float(k) / float(steps)), "=")
	for c in plan.commons:
		for p in _fill_points(c["poly"], cell):
			put.call(p, ".")
	for b in plan.buildings:
		for p in _fill_points(VillageMeasure.bounds_poly(b), cell):
			put.call(p, "#")
	for t in plan.plants:
		if float(t.get("canopy", 0.0)) >= 1.0:
			put.call(t["pos"], "T")
	for pr in plan.props:
		put.call(pr["pos"], "*" if bool(pr.get("light", false)) else "o")
	var out: Array[String] = []
	for r2 in range(rows):
		out.append("".join(grid[r2]))
	return "\n".join(out)


static func _fill_points(poly: PackedVector2Array, cell: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.size() < 3:
		return out
	var rect: Rect2 = Poly.bounding_rect(poly)
	var x: float = rect.position.x
	while x <= rect.end.x:
		var y: float = rect.position.y
		while y <= rect.end.y:
			var p := Vector2(x, y)
			if Poly.contains_point(poly, p):
				out.append(p)
			y += cell
		x += cell
	return out
