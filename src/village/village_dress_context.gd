class_name VillageDressContext
extends RefCounted
## Settlement-wide dressing context and special site features.

## A hedge is a measured, continuous planted row. Neighbouring bushes may
## overlap as a hedge, but every road verge, roof and water body stays clear.
static func enclosure_hedge(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.enclosure != &"hedge" or plan.enclosure.is_empty():
		return
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "hedge")
	if keys.is_empty():
		return
	var rng := VillageDressPlacement.rng(plan, "enclosure_hedge")
	for e in plan.enclosure.size():
		for run in VillageBuilder._minus_gates(plan.enclosure[e], plan.enclosure[(e + 1) % plan.enclosure.size()], plan.gate_crossings):
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			var steps := maxi(1, int(ceil(a.distance_to(b) / 1.6)))
			for i in steps:
				var at := a.lerp(b, (float(i) + 0.5) / float(steps))
				var key := keys[rng.randi() % keys.size()]
				var look: Dictionary = VillageDressPlacement.plant_looks(plan, {"palette": "hedge"}, key, a.lerp(b, (float(i) + 0.5) / float(steps)))[0]
				var radius := maxf(float(look["trunk"]), float(look["canopy"]))
				var clear := true
				for water in plan.water:
					if Poly.contains_point(water["poly"], at) or VillageMeasure.point_to_poly(at, water["poly"]) < radius + 0.3:
						clear = false
				for ribbon in ctx["roads"]:
					if Poly.contains_point(ribbon, at) or VillageMeasure.point_to_poly(at, ribbon) < radius + VillageDressCatalog.TRUNK_CLEAR:
						clear = false
				for bounds in ctx["bounds"]:
					if Poly.contains_point(bounds, at) or VillageMeasure.point_to_poly(at, bounds) < radius + VillageDressCatalog.TRUNK_CLEAR:
						clear = false
				if not clear:
					continue
				var row := VillageDressPlacement.plant_row(key, at, look, rng.randf_range(0, TAU))
				row["zone"] = &"enclosure"
				plan.plants.append(row)
				VillageDressPlacement.remember(ctx, at, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), radius)
				_hedgerow_tree(plan, ctx, at, e, i)


## Here and there a hedge keeps a tree: a hedgerow oak left to grow when the
## rest was laid. Rare, outside the line, and held to every clearance the
## row itself keeps.
static func _hedgerow_tree(plan: VillagePlan, ctx: Dictionary, at: Vector2,
		edge_index: int, piece: int) -> void:
	var roll := fposmod(sin(float(edge_index) * 91.7 + float(piece) * 12.9898
		+ float(plan.spec.seed) * 0.31) * 43758.5453, 1.0)
	if roll > 0.045:
		return
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "edge")
	if keys.is_empty():
		return
	var key := keys[int(roll * 1000.0) % keys.size()]
	var outward: Vector2 = (at - plan.site.get_center()).normalized()
	var spot: Vector2 = at + outward * 2.2
	for look in VillageDressPlacement.plant_looks(plan, {"palette": "edge"}, key, spot):
		if VillageDressPlacement.plant_is_clear(plan, ctx, spot, look["trunk"], look["canopy"]):
			var row := VillageDressPlacement.plant_row(key, spot, look, roll * TAU)
			row["zone"] = &"enclosure"
			plan.plants.append(row)
			VillageDressPlacement.remember(ctx, spot, Rect2(spot - Vector2(look["trunk"], look["trunk"]),
				Vector2(look["trunk"], look["trunk"]) * 2.0), look["trunk"])
			return


## The mine mouth sits beside the final through-road segment, inside the
## boundary and facing the road. PropKit measures the whole piece, including
## the spoil heaps; the nominal recipe size is too narrow for those heaps.
static func mine_adit(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.purpose != &"mining":
		return
	for road in plan.roads:
		if road["class"] != &"through":
			continue
		var points: PackedVector2Array = road["points"]
		var end: Vector2 = points[points.size() - 1]
		var along: Vector2 = (end - points[points.size() - 2]).normalized()
		var half: float = float(road["width"]) * 0.5 + float(road["verge"])
		for retreat in [8.0, 10.0, 12.0, 14.0]:
			var road_at: Vector2 = end - along * retreat
			for side in [1.0, -1.0]:
				var normal: Vector2 = Vector2(-along.y, along.x) * float(side)
				var yaw := snappedf(PropCatalog.yaw_facing(-normal), 0.001)
				var kit := PropKit.new(MeshKit.new(4), 0, 1, 2, 3)
				var local: AABB = kit.adit(Vector3.ZERO, yaw)
				var local_rect := Rect2(Vector2(local.position.x, local.position.z), Vector2(local.size.x, local.size.z))
				var front := INF
				for corner in Poly.from_rect(local_rect):
					front = minf(front, corner.dot(normal))
				var at: Vector2 = road_at + normal * (half - front + 0.7)
				var rect := Rect2(at + local_rect.position, local_rect.size)
				if not VillageDressPlacement.prop_is_clear(plan, ctx, rect, rect):
					continue
				# A short working apron joins the verge to the spoil-free front
				# of the mouth. It is actual dirt and walkable floor, not a QA
				# reach extension; later obstacles still cut it out normally.
				var start: Vector2 = road_at + normal * (float(road["width"]) * 0.5 - 0.15)
				var finish: Vector2 = at + normal * 0.5
				var apron := PackedVector2Array([start - along * 0.9, start + along * 0.9,
					finish + along * 0.9, finish - along * 0.9])
				var dry := true
				for water in plan.water:
					if VillageLotPlanner.overlap_area(Poly.from_rect(rect), water["poly"]) > VillageLotPlanner.AREA_EPS \
							or VillageLotPlanner.overlap_area(apron, water["poly"]) > VillageLotPlanner.AREA_EPS:
						dry = false
				if not dry:
					continue
				var clear_apron := true
				for bounds in ctx["bounds"]:
					if VillageLotPlanner.overlap_area(apron, bounds) > VillageLotPlanner.AREA_EPS:
						clear_apron = false
				if not clear_apron:
					continue
				var clear_boundary := true
				for edge in plan.enclosure.size():
					for run in VillageBuilder._minus_gates(plan.enclosure[edge], plan.enclosure[(edge + 1) % plan.enclosure.size()], plan.gate_crossings):
						var wall := Poly.ribbon(PackedVector2Array([run[0], run[1]]), VillageBuilder.WALL_THICK * 0.5 + 0.4)
						if VillageLotPlanner.overlap_area(Poly.from_rect(rect), wall) > VillageLotPlanner.AREA_EPS \
								or VillageLotPlanner.overlap_area(apron, wall) > VillageLotPlanner.AREA_EPS:
							clear_boundary = false
				if not clear_boundary:
					continue
				plan.props.append({"key": "adit", "pos": at, "yaw": yaw, "host": -1,
					"rect": rect, "zone": rect, "built": true, "light": false, "approach": apron})
				var claim := rect.merge(Poly.bounding_rect(apron))
				VillageDressPlacement.remember(ctx, at, claim, claim.size.length() * 0.5)
				return


## A small broken wall and fungal colony tell the blighted settlement's
## story. Use measured owned models, on dry ground and clear of routes.
static func blight_remnants(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.culture != &"blighted":
		return
	var rng := VillageDressPlacement.rng(plan, "blight_remnants")
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(2.6, 0), Vector2(-2.6, 0.3)]
	var wall_size := PropCatalog.footprint("Dungeon_Wall_Broken")
	var cluster := Rect2(-wall_size * 0.5, wall_size)
	for offset in offsets:
		cluster = cluster.merge(Rect2(offset - wall_size * 0.5, wall_size))
	var centres := VillageDressSpots.scatter(Poly.from_rect(plan.site.grow(-5.0)), rng, 120)
	for centre in centres:
		# The common is working public ground, even in a blighted village.
		# Reserve the whole measured group, not only its centre wall.
		var on_common := false
		var footprint := Poly.from_rect(Rect2(centre + cluster.position, cluster.size))
		for common in plan.commons:
			on_common = on_common or VillageLotPlanner.overlap_area(footprint, common["poly"]) > VillageLotPlanner.AREA_EPS
		if on_common:
			continue
		var wet := false
		for water in plan.water:
			if Poly.contains_point(water["poly"], centre) or VillageMeasure.point_to_poly(centre, water["poly"]) < 4.0:
				wet = true
		if wet:
			continue
		if not VillageDressPlacement.place(plan, ctx, {"yaw": 0.0}, "Dungeon_Wall_Broken", centre, rng, -1):
			continue
		plan.props[-1]["group"] = "blight_ruin"
		for offset in offsets.slice(1):
			if VillageDressPlacement.place(plan, ctx, {"yaw": 0.0}, "Dungeon_Wall_Broken", centre + offset, rng, -1):
				plan.props[-1]["group"] = "blight_ruin"
		for offset in [Vector2(-2,-2), Vector2(-1,-2), Vector2(0,-2), Vector2(1,-2),
			Vector2(2,-2), Vector2(-1,2), Vector2(0,2), Vector2(1,2)]:
			VillageDressPlacement.place(plan, ctx, {"plant": true}, "Wild_Mushroom_Common", centre + offset, rng, -1)
		return


static func mill_wheels(plan: VillagePlan, ctx: Dictionary) -> void:
	for race in plan.water:
		if race["kind"] != &"race":
			continue
		var at: Vector2 = race["wheel"]
		var normal: Vector2 = race["normal"]
		var tangent := Vector2(-normal.y, normal.x)
		var size := tangent.abs() * (VillageWaterPlan.WHEEL_RADIUS * 2.0 + 0.2) + normal.abs() * 0.8
		var rect := Rect2(at - size * 0.5, size)
		plan.props.append({"key": "mill_wheel", "pos": at,
			"yaw": atan2(normal.x, normal.y), "elevation": VillageWaterPlan.WHEEL_AXLE,
			"radius": VillageWaterPlan.WHEEL_RADIUS,
			"host": race["host"], "rect": rect, "zone": Rect2(),
			"built": true, "light": false})
		VillageDressPlacement.remember(ctx, at, rect, VillageWaterPlan.WHEEL_RADIUS + 0.1)


## Materialise dressed land beyond the measured lot hull. This runs after lot
## cutting, so outside fields cannot influence frontage or building placement.
static func outer_land(plan: VillagePlan) -> void:
	if plan.spec.enclosure == &"none":
		return
	var derived: Dictionary = VillageEnclosurePlan.build(plan)
	var edge: PackedVector2Array = derived["edge"]
	if edge.size() < 3:
		return
	# Existing authored fields are accepted only when wholly beyond the same
	# measured edge.  Keeping an inside field would make the plan look valid to
	# the dresser while violating the edge rule in DressCheck.
	if not plan.fields.is_empty():
		var outside: Array[Dictionary] = []
		for field in plan.fields:
			var field_poly: PackedVector2Array = field["poly"]
			if VillageLotPlanner.overlap_area(field_poly, edge) <= VillageLotPlanner.AREA_EPS:
				outside.append(field)
		plan.fields = outside
	if plan.fields.is_empty() and plan.spec.purpose in [&"farming", &"forest"]:
		var site := plan.site
		var depth: float = clampf(site.size.y * 0.12, 6.0, 14.0)
		var candidates: Array[Rect2] = []
		for road in plan.roads:
			if road["class"] != &"track":
				continue
			var points: PackedVector2Array = road["points"]
			for endpoint in [points[0], points[points.size() - 1]]:
				var away: Vector2 = (endpoint - site.get_center()).normalized()
				var centre: Vector2 = endpoint + away * 4.0
				candidates.append(Rect2(centre - Vector2(6.0, 4.0), Vector2(12.0, 8.0)))
		candidates.append_array([
			Rect2(Vector2(site.position.x, site.position.y - depth),
				Vector2(site.size.x, depth)),
			Rect2(Vector2(site.position.x, site.end.y),
				Vector2(site.size.x, depth))])
		for candidate in candidates:
			var poly := Poly.from_rect(candidate)
			if VillageLotPlanner.overlap_area(poly, edge) <= VillageLotPlanner.AREA_EPS:
				plan.fields.append({"poly": poly, "kind": &"pasture"})
				break


static func wood(plan: VillagePlan, ctx: Dictionary) -> void:
	var derived: Dictionary = VillageEnclosurePlan.build(plan)
	var edge: PackedVector2Array = derived["edge"]
	if edge.size() < 3:
		return
	var centre: Vector2 = derived["wood"]
	if Poly.contains_point(edge, centre):
		return
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "edge")
	if keys.is_empty():
		return
	var key: String = keys[0]
	var rng := VillageDressPlacement.rng(plan, "wood")
	for offset: Vector2 in [Vector2(-4.0, 0.0), Vector2(0.0, 3.0), Vector2(4.0, 0.0)]:
		var at: Vector2 = centre + offset
		var trunk: float = maxf(PropCatalog.trunk(key), 0.1)
		if not VillageDressPlacement.plant_is_clear(plan, ctx, at, trunk, PropCatalog.canopy(key)):
			continue
		plan.plants.append({"key": key, "pos": at,
			"canopy": PropCatalog.canopy(key), "trunk": trunk,
			"yaw": snappedf(rng.randf_range(0.0, TAU), 0.001), "zone": &"wood"})


## What every placement has to keep clear of, gathered once: the road ribbons
## with their verges, every building's measured bounds, the door swings, and
## the common. Rebuilding this per prop is what would make dressing a village
## take longer than planning one.
static func make_context(plan: VillagePlan) -> Dictionary:
	var roads: Array[PackedVector2Array] = []
	for road in plan.roads:
		roads.append(VillageSitePlanner.road_ribbon(road, true))
	var bounds: Array[PackedVector2Array] = []
	var boxes: Array[Rect2] = []
	var doors: Array[Rect2] = []
	for b in plan.buildings:
		var poly: PackedVector2Array = VillageMeasure.bounds_poly(b)
		bounds.append(poly)
		boxes.append(Poly.bounding_rect(poly))
		# the house's own yard is the house's: nothing of the village's stands in it
		for yard_poly in VillageMeasure.yard_polys(b):
			bounds.append(yard_poly)
			boxes.append(Poly.bounding_rect(yard_poly))
		var d: Vector2 = VillageMeasure.door(b)
		doors.append(Rect2(d - Vector2(VillageDressCatalog.DOOR_CLEAR, VillageDressCatalog.DOOR_CLEAR),
			Vector2(VillageDressCatalog.DOOR_CLEAR, VillageDressCatalog.DOOR_CLEAR) * 2.0))
	# Bounding rects beside the polygons, and beside the road ribbons: every
	# clearance test below rejects on the cheap rect first and only reaches
	# for `Geometry2D` when the rects actually meet. A village plants
	# hundreds of pieces and each one was intersecting sixty polygons.
	var road_boxes: Array[Rect2] = []
	for ribbon in roads:
		road_boxes.append(Poly.bounding_rect(ribbon))
	var palette_id: StringName = plan.spec.plant_palette if plan.spec.site_brief else plan.spec.culture
	return {
		"roads": roads, "road_boxes": road_boxes,
		"bounds": bounds, "boxes": boxes, "doors": doors,
		# a coarse grid of what has been placed, so "is anything near here"
		# is a lookup and not a walk of every prop and plant already down. A
		# village plants hundreds of pieces and the walk made dressing one
		# slower than planning it.
		"grid": {},
		"common": VillageMeasure.common_poly(plan),
		"palette": VillageDressCatalog.PALETTES.get(palette_id,
			VillageDressCatalog.PALETTES.get(plan.spec.culture, VillageDressCatalog.PALETTES[&"english"])),
	}
