class_name VillageDressPlacement
extends RefCounted
## Commits props and plants after shared clearance checks.

# ---------------------------------------------------------- placing them

## Put one piece down, if the ground is free. A plant goes in `plan.plants`
## with its measured trunk and canopy; everything else in `plan.props` with
## the floor it stands on and the floor a person needs to use it.
## True when the piece went down. False is not a failure: an outdoor recipe
## describes a full village, and a hamlet is not wrong for having one bench
## where the recipe offers two.
static func place(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		key: String, at: Vector2, rng: RandomNumberGenerator, host: int) -> bool:
	var is_plant: bool = bool(step.get("plant", false))
	if is_plant:
		if bool(step.get("orchard", false)) and (host < 0 or not Poly.contains_point(plan.lots[plan.lot_of_building(host)]["poly"], at)):
			return false
		var looks: Array = plant_looks(plan, step, key, at)
		for look in looks:
			if not plant_is_clear(plan, ctx, at, look["trunk"], look["canopy"]):
				continue
			plan.plants.append(plant_row(key, at, look, snappedf(rng.randf_range(0.0, TAU), 0.001)))
			remember(ctx, at, Rect2(at - Vector2(look["trunk"], look["trunk"]),
				Vector2(look["trunk"], look["trunk"]) * 2.0), look["trunk"])
			return true
		return false
	var built: bool = bool(step.get("built", false))
	var size: Vector2 = Vector2(VillageDressCatalog.BUILT[key]["size"]) if built \
		else PropCatalog.footprint(key)
	var zone: float = float(VillageDressCatalog.BUILT[key]["zone"]) if built else PropCatalog.zone_depth(key)
	var yaw: float = snappedf(float(step.get("yaw", _facing(plan, host, at))), 0.001)
	var rect := Rect2(at - size / 2.0, size)
	var shore_piece := built and key in ["boat", "drying_rack"] and ctx.has("strand_walk")
	var shore_obstacle := ctx.has("strand_walk") and (built or PropCatalog.blocks_floor(key))
	if shore_piece:
		# These long pieces turn toward the village. Their unrotated recipe
		# size understates the occupied width after that turn.
		var kit := PropKit.new(MeshKit.new(4), 0, 1, 2, 3)
		var bounds: AABB = kit.boat(Vector3.ZERO, yaw) if key == "boat" \
			else kit.drying_rack(Vector3.ZERO, yaw)
		size = Vector2(bounds.size.x, bounds.size.z)
		rect = Rect2(at + Vector2(bounds.position.x, bounds.position.z), size)
	var use := Rect2(at - Vector2(zone, zone), Vector2(zone, zone) * 2.0) \
		if zone > 0.0 else Rect2()
	# A lamp hangs on the wall and takes no floor, so it is held only to
	# being on the site and out of the doorway. Held to the floor rules it
	# competed for ground with the anvil and the barrel already against that
	# wall, and the smithy's own lamp lost every time -- which is how a
	# village came out with nothing lit at all.
	if not prop_is_clear(plan, ctx, rect, use, PropCatalog.blocks_floor(key) or built):
		return false
	if not _host_owns(plan, ctx, host, at):
		return false
	var shore_apron := PackedVector2Array()
	if shore_piece and not (ctx["strand_walk"] as WalkGrid).reached(rect, VillageNavCheck.PERSON_RADIUS + 0.4):
		shore_apron = VillageDressSpots.strand_apron(plan, ctx, rect)
		if shore_apron.is_empty():
			return false
	plan.props.append({"key": key, "pos": at, "yaw": snappedf(yaw, 0.001),
		"host": host, "rect": rect, "zone": use,
		"built": built, "light": _is_light(key, built)})
	if not shore_apron.is_empty():
		plan.props.back()["approach"] = shore_apron
	if shore_obstacle:
		var occupied_walk := VillageNavCheck.reached_grid(plan)
		var all_reached := true
		for prop in plan.props:
			if prop["key"] in ["boat", "drying_rack"]:
				all_reached = all_reached and occupied_walk.reached(prop["rect"], VillageNavCheck.PERSON_RADIUS + 0.4)
		if not all_reached:
			plan.props.pop_back()
			return false
		ctx["strand_walk"] = occupied_walk
	remember(ctx, at, rect, maxf(size.x, size.y) * 0.5)
	return true


# --------------------------------------------------- how a plant is grown

## A plant row. `canopy` and `trunk` are what THIS tree promises, after its
## scale and lean: the checks read these and never the catalogue's, and the
## assembler draws the model at exactly this scale and tilt.
static func plant_row(key: String, at: Vector2, look: Dictionary, yaw: float) -> Dictionary:
	var row := {"key": key, "pos": at, "canopy": look["canopy"], "trunk": look["trunk"],
		"yaw": yaw}
	if look["scale"] != 1.0 or look["lean"] != 0.0:
		row["scale"] = look["scale"]
		row["lean"] = look["lean"]
		row["lean_yaw"] = look["lean_yaw"]
	return row


## What kind of growing thing a key is, for how much it may vary.
static func plant_kind(key: String) -> StringName:
	match PropCatalog.category(key):
		"tree":
			return &"tree"
		"dead_tree":
			return &"dead"
		"bush":
			return &"bush"
	return &"cover"


## One plant as grown (EVAL-B05): a scale, and for some a lean, drawn from
## the position so the same village always grows the same trees and no other
## random stream moves. The measured promise is carried through exactly:
##   canopy = measured * scale + the reach of the lean at the crown
##   trunk  = measured * scale where it grew, the measured trunk where it
##            shrank (a smaller model's head-height band reaches higher into
##            the crown, so it cannot promise less), plus the lean at 1.8 m.
## The clearance contract is a bound, so a promise a little generous is safe.
## A `green` tree, the one on the common, is a veteran: it tries the largest
## of 1.6x down to 1.15x that the ground allows, and is first in the list.
static func plant_looks(plan: VillagePlan, step: Dictionary, key: String,
		at: Vector2) -> Array:
	var canopy0: float = PropCatalog.canopy(key)
	var trunk0: float = maxf(PropCatalog.trunk(key), 0.1)
	var kind := plant_kind(key)
	var out: Array = []
	if kind == &"cover":
		out.append(_look(key, 1.0, 0.0, 0.0, canopy0, trunk0))
		return out
	var r := RandomNumberGenerator.new()
	r.seed = hash("look|%d|%s|%.1f|%.1f" % [plan.spec.seed, key, at.x, at.y])
	var s := 1.0
	var lean_max := 0.0
	var lean_chance := 0.0
	match kind:
		&"tree":
			s = r.randf_range(0.8, 1.28)
			lean_max = deg_to_rad(7.0)
			lean_chance = 0.3
		&"dead":
			s = r.randf_range(0.85, 1.2)
			lean_max = deg_to_rad(13.0)
			lean_chance = 0.65
		&"bush":
			s = r.randf_range(0.8, 1.3)
	if bool(step.get("orchard", false)):
		s = r.randf_range(0.92, 1.08)   # planted in a row, so nearly alike
		lean_max = deg_to_rad(3.0)
	var lean := 0.0
	var lean_yaw := r.randf_range(0.0, TAU)
	if lean_max > 0.0 and r.randf() < lean_chance:
		lean = r.randf_range(0.35, 1.0) * lean_max
	if String(step.get("palette", "")) == "green" and kind == &"tree":
		for veteran in [1.6, 1.45, 1.3, 1.15]:
			out.append(_look(key, veteran, 0.0, 0.0, canopy0, trunk0))
	out.append(_look(key, s, lean, lean_yaw, canopy0, trunk0))
	if s > 0.8 or lean > 0.0:
		# the smallest, upright version of the same tree is always on offer
		out.append(_look(key, 0.8, 0.0, 0.0, canopy0, trunk0))
	return out


static func _look(key: String, s: float, lean: float, lean_yaw: float,
		canopy0: float, trunk0: float) -> Dictionary:
	var height: float = PropCatalog.size(key).y * s
	return {"scale": snappedf(s, 0.001), "lean": snappedf(lean, 0.001),
		"lean_yaw": snappedf(lean_yaw, 0.001),
		"canopy": canopy0 * s + height * sin(lean),
		"trunk": trunk0 * maxf(s, 1.0) + 1.8 * s * sin(lean)}


static func _is_light(key: String, built: bool) -> bool:
	if built:
		return bool(VillageDressCatalog.BUILT[key].get("light", false))
	return PropCatalog.has_tag(key, PropCatalog.LIGHT)


## Which way a piece faces: away from its host building, so a bench by a door
## looks out at the street; toward the village otherwise.
static func _facing(plan: VillagePlan, host: int, at: Vector2) -> float:
	var dir: Vector2 = Vector2(0, -1)
	if host >= 0 and host < plan.buildings.size():
		dir = VillageMeasure.front_dir(plan.buildings[host])
	else:
		var to_centre: Vector2 = plan.site.get_center() - at
		if to_centre.length_squared() > 0.01:
			dir = to_centre.normalized()
	return PropCatalog.yaw_facing(dir)


## Nothing on a road, in a doorway, inside a building or on top of another
## prop.
##
## Measured the way `RoadCheck.clear` measures it, and with the same
## functions: its ZONE against the ribbon WITH its verge, through
## `VillageLotPlanner.overlap_area`. Two things were wrong with doing it any
## other way. The check tests the zone -- the floor a person needs to USE the
## piece -- and an anvil's zone is nearly a metre wider than the anvil, so a
## dresser that only kept the anvil out of the road put its zone in it. And
## `Poly.intersection_area` clips one convex polygon against another, which a
## bowed road ribbon is not; `overlap_area` goes through `Geometry2D` and
## does not care.
## Ground the host may put something on: its own lot, a road (the verge in
## front of it is where Â§7's `verge` rule puts a bench), or the common.
##
## Â§9.6's `host` rule measures exactly this, and without it the placer could
## put a smithy's anvil on the strip of nothing between a shallow shop lot
## and the road -- ground that belongs to nobody, that the walk grid does not
## take as floor, and that the `use` rule then reports as unreachable.
static func _host_owns(plan: VillagePlan, ctx: Dictionary, host: int,
		at: Vector2) -> bool:
	if host < 0:
		return true          # a place, not a building: the village at large
	var lot: int = plan.lot_of_building(host)
	if lot >= 0 and Poly.contains_point(plan.lots[lot]["poly"], at):
		return true
	for ribbon in ctx["roads"]:
		if Poly.contains_point(ribbon, at):
			return true
	var common: PackedVector2Array = ctx["common"]
	return not common.is_empty() and Poly.contains_point(common, at)


## `floors` is false for a piece that hangs on a wall and takes no ground.
## Such a piece is still held to the site, the doorways and the ROAD -- a
## lantern over the carriageway is over the carriageway -- but not to the
## floor it does not occupy. Held to that too it competed for ground with the
## anvil and the barrel already against its wall and lost every time, which
## is how a village came out with nothing lit at all.
static func prop_is_clear(plan: VillagePlan, ctx: Dictionary, rect: Rect2,
		zone: Rect2, floors := true) -> bool:
	if not plan.site.grow(-0.5).encloses(rect):
		return false
	var claim: Rect2 = rect.merge(zone) if zone.size.x > 0.0 else rect
	var wide: Rect2 = claim.grow(VillageDressCatalog.ROAD_CLEAR)
	var poly: PackedVector2Array = Poly.from_rect(wide)
	var road_boxes: Array[Rect2] = ctx["road_boxes"]
	var roads: Array[PackedVector2Array] = ctx["roads"]
	for i in range(roads.size()):
		if not road_boxes[i].intersects(wide):
			continue
		if VillageLotPlanner.overlap_area(poly, roads[i]) > VillageLotPlanner.AREA_EPS:
			return false
	for d in ctx["doors"]:
		if d.intersects(claim):
			return false
	if not floors:
		return true
	var mine: PackedVector2Array = Poly.from_rect(rect)
	for prop in plan.props:
		if prop["key"] in ["boat", "drying_rack"] and prop.has("approach") \
				and VillageLotPlanner.overlap_area(mine, prop["approach"]) > VillageLotPlanner.AREA_EPS:
			return false
	for w in plan.water:
		if w["kind"] == &"race" and VillageLotPlanner.overlap_area(mine, w["poly"]) > VillageLotPlanner.AREA_EPS:
			return false
	var boxes: Array[Rect2] = ctx["boxes"]
	var bounds: Array[PackedVector2Array] = ctx["bounds"]
	for j in range(bounds.size()):
		if not boxes[j].intersects(rect):
			continue
		if VillageLotPlanner.overlap_area(mine, bounds[j]) > VillageLotPlanner.AREA_EPS:
			return false
	var grown: Rect2 = rect.grow(VillageDressCatalog.PROP_CLEAR)
	for near in near(ctx, rect.get_center(), grown.size.length()):
		if grown.intersects(near["rect"] as Rect2):
			return false
	return true


## A trunk off every road and every building, and a canopy over no roof.
## Same functions as the checks -- `overlap_area` over `Geometry2D`, not the
## convex clipper, because a road ribbon bends.
static func plant_is_clear(plan: VillagePlan, ctx: Dictionary, at: Vector2,
		trunk: float, canopy: float) -> bool:
	if not plan.site.has_point(at):
		return false
	# The green's working space belongs to the well. Large boulders from a
	# ground palette need the same clearance as trees placed by its green rule.
	if canopy >= 1.0:
		for prop in plan.props:
			if prop["key"] == "well" and at.distance_to(prop["pos"]) < VillageDressCatalog.GREEN_TREE_CLEAR:
				return false
	for w in plan.water:
		if Poly.contains_point(w["poly"], at) or VillageMeasure.point_to_poly(at, w["poly"]) < trunk + 0.2:
			return false
	var stem_rect: Rect2 = Rect2(at - Vector2(trunk, trunk),
		Vector2(trunk, trunk) * 2.0).grow(VillageDressCatalog.TRUNK_CLEAR)
	var stem: PackedVector2Array = Poly.from_rect(stem_rect)
	for prop in plan.props:
		if prop["key"] in ["boat", "drying_rack"] and prop.has("approach") \
				and VillageLotPlanner.overlap_area(stem, prop["approach"]) > VillageLotPlanner.AREA_EPS:
			return false
	var road_boxes: Array[Rect2] = ctx["road_boxes"]
	var roads: Array[PackedVector2Array] = ctx["roads"]
	for i in range(roads.size()):
		if not road_boxes[i].intersects(stem_rect):
			continue
		if VillageLotPlanner.overlap_area(stem, roads[i]) > VillageLotPlanner.AREA_EPS:
			return false
	var crown_rect: Rect2 = Rect2(at - Vector2(canopy, canopy),
		Vector2(canopy, canopy) * 2.0).grow(-VillageDressCatalog.CANOPY_SLACK)
	var crown: PackedVector2Array = Poly.from_rect(crown_rect)
	var boxes: Array[Rect2] = ctx["boxes"]
	var bounds: Array[PackedVector2Array] = ctx["bounds"]
	for j in range(bounds.size()):
		if not boxes[j].grow(canopy + VillageDressCatalog.TRUNK_CLEAR).has_point(at):
			continue
		# The CHECK'S measurement, not a rect overlap: `DressCheck.canopies`
		# asks for the true distance from the trunk to the building, and a
		# rect that only touches a polygon at a corner has no overlapping
		# area at all -- so the two disagreed by a few centimetres and the
		# dresser planted bushes the check then refused.
		var d: float = VillageMeasure.point_to_poly(at, bounds[j])
		if Poly.contains_point(bounds[j], at) or d < trunk + VillageDressCatalog.TRUNK_CLEAR:
			return false
		if canopy > 0.0 and d < canopy:
			return false
	for d in ctx["doors"]:
		if d.has_point(at):
			return false
	for near in near(ctx, at, trunk + GRID_CELL):
		if (near["rect"] as Rect2).grow(trunk).has_point(at):
			return false
		if at.distance_to(near["pos"]) < trunk + float(near["radius"]) + 0.5:
			return false
	return true


# ------------------------------------------------------------- the hedges

## A hedge along each lot's side boundaries, with a gap where the path to the
## door crosses it. Culture's `hedge` slot, at a pitch, and only where the
## village is rich enough to keep one (Â§7: `row`, wealth x 0.8).
static func hedges(plan: VillagePlan, ctx: Dictionary) -> void:
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "hedge")
	if keys.is_empty():
		return
	var rng := rng(plan, "hedge")
	var chance: float = plan.spec.wealth * 0.8
	for i in range(plan.buildings.size()):
		if rng.randf() > chance:
			continue
		var lot: int = plan.lot_of_building(i)
		if lot < 0:
			continue
		var poly: PackedVector2Array = plan.lots[lot]["poly"]
		var front: PackedVector2Array = plan.lots[lot]["front"]
		for e in range(poly.size()):
			var a: Vector2 = poly[e]
			var b: Vector2 = poly[(e + 1) % poly.size()]
			# the frontage itself is the way in, never hedged across
			if _same_edge(a, b, front):
				continue
			var run: float = a.distance_to(b)
			var steps: int = int(run / 1.6)
			for k in range(steps):
				var t: float = (float(k) + 0.5) / float(maxi(steps, 1))
				var key: String = keys[rng.randi() % keys.size()]
				# a hedge is a run: the pieces that will not fit are simply
				# the gaps in it, which is what a hedge looks like anyway
				var _in_hedge: bool = place(plan, ctx,
					{"plant": true, "palette": "hedge"}, key, a.lerp(b, t), rng, i)


static func _same_edge(a: Vector2, b: Vector2, front: PackedVector2Array) -> bool:
	if front.size() < 2:
		return false
	return (a.distance_to(front[0]) < 0.5 and b.distance_to(front[1]) < 0.5) \
		or (a.distance_to(front[1]) < 0.5 and b.distance_to(front[0]) < 0.5)


## How big a bucket of the placement grid is. Wide enough that anything that
## could clash with a piece is in the piece's own cell or one beside it.
const GRID_CELL := 6.0


## Remember one placement in the grid, so later ones can find it cheaply.
static func remember(ctx: Dictionary, at: Vector2, rect: Rect2, radius: float) -> void:
	var grid: Dictionary = ctx["grid"]
	var cell := Vector2i(int(floorf(at.x / GRID_CELL)), int(floorf(at.y / GRID_CELL)))
	if not grid.has(cell):
		grid[cell] = []
	(grid[cell] as Array).append({"pos": at, "rect": rect, "radius": radius})


## Everything already placed within `reach` of `at`, from the grid.
static func near(ctx: Dictionary, at: Vector2, reach: float) -> Array:
	var grid: Dictionary = ctx["grid"]
	var out: Array = []
	var span: int = maxi(int(ceilf(reach / GRID_CELL)), 1)
	var base := Vector2i(int(floorf(at.x / GRID_CELL)), int(floorf(at.y / GRID_CELL)))
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var cell: Vector2i = base + Vector2i(dx, dy)
			if grid.has(cell):
				out.append_array(grid[cell])
	return out


## An RNG named from the spec's seed, so dressing is a pure function of the
## plan and two runs put the same barrel in the same place.
static func rng(plan: VillagePlan, key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dress|%d|%s" % [plan.spec.seed, key])
	return rng

