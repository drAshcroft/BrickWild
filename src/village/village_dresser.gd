class_name VillageDresser
extends RefCounted
## What is standing about outside (VIL-013). VILLAGES §7 and §8.
##
## The same shape as `HouseFurnisher`: a table of RECIPES keyed by host, each
## a list of steps naming a prop CATEGORY and a RULE, never a coordinate.
## Indoors the rules are wall/free/around/corner/mounted/on; out here they are
## the seven §7 gives, and they mean the same kind of thing:
##
##   wall    against the host's own wall, never across a door or a window
##   yard    behind or beside the building, off the path to its door
##   verge   on the road verge in front of the lot, never on the carriageway
##   corner  at a corner of the lot
##   row     N copies along an axis at a pitch -- stalls, orchard trees
##   on      set on a cart, a stall, a bench
##   light   a torch or a lantern; the same LIGHT tag the temple assembler
##           already turns into an OmniLight3D
##
## Plants are separate from props and go in `plan.plants`, because they are
## judged differently: a prop is a footprint and a plant is a TRUNK you walk
## round and a CANOPY that must not hang over a roof, and the catalogue
## measures both (VIL-011). Which plants at all is the culture's business --
## §8's palette -- so a norse edge is birch and pine and a moorish one twisted
## trees and pebbles, and no village mixes two palettes.
##
## Nothing here trusts itself. `DressCheck` re-derives every footprint, every
## trunk and every canopy from the placements alone and judges them.
##
## Deterministic: every draw comes from an RNG seeded by name from the spec's
## seed, and the plan is never read in a different order than it is written.

# ------------------------------------------------------------- the recipes

## Metres of clear ground a prop wants around it before it is worth placing.
const PROP_CLEAR := 0.35
## Nothing stands within this of a door's own swing, ever.
const DOOR_CLEAR := 1.2
## Nothing stands on a road, and this is how far off one it stays.
const ROAD_CLEAR := 0.4
## A trunk stays this far off any road polygon and any building's bounds.
const TRUNK_CLEAR := 1.0
## A canopy may not hang over a roof at all; this is the slack allowed.
const CANOPY_SLACK := 0.1
## How many places along a building's front a `wall` or `verge` step is
## offered, per step out from the wall.
const FRONT_SPOTS := 6
## How far apart the trees of the edge band stand. §9.6 walks the edge and
## refuses a run longer than 25 m with nothing within 6 m of it, so the band
## is PLANTED ALONG the edge at a pitch rather than scattered near it.
const EDGE_PITCH := 6.0

## §7's recipe table, by host. A host is a building (by its programme role),
## or one of the places that is not a building at all -- the common, a gate,
## the water, the strand, the edge.
##
## `n` is [min, max] and `opt` is the same die HouseFurnisher rolls: 1.0 is a
## piece the host is not that host without, and anything less can be left out
## when there is nowhere to put it.
const RECIPES := {
	# any house: what a household leaves outside its own front door
	&"house": [
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 0.7},
		{"cat": "bench", "rule": &"wall", "n": [0, 1], "opt": 0.4},
		{"cat": "bush", "rule": &"verge", "n": [2, 2], "opt": 0.6, "plant": true},
	],
	&"farm": [
		{"cat": "crate", "rule": &"yard", "n": [1, 3], "opt": 0.9},
		{"cat": "sack", "rule": &"yard", "n": [1, 2], "opt": 0.9},
		{"cat": "wagon", "rule": &"yard", "n": [0, 1], "opt": 0.6},
		{"cat": "haystack", "rule": &"yard", "n": [1, 1], "opt": 0.8, "built": true},
		{"cat": "tree", "rule": &"row", "n": [3, 3], "pitch": 5.0, "opt": 1.0, "plant": true, "orchard": true},
	],
	&"smithy": [
		{"cat": "anvil", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "cookware", "rule": &"wall", "n": [0, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
	],
	&"tavern": [
		{"cat": "bench", "rule": &"verge", "n": [2, 2], "opt": 1.0},
		{"cat": "barrel", "rule": &"verge", "n": [1, 2], "opt": 1.0},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
		{"cat": "banner", "rule": &"wall", "n": [1, 1], "opt": 0.6},
	],
	&"stable": [
		{"cat": "wagon", "rule": &"yard", "n": [1, 1], "opt": 0.8},
		{"cat": "sack", "rule": &"wall", "n": [1, 2], "opt": 0.8},
	],
	&"market": [
		{"cat": "stall", "rule": &"row", "n": [3, 6], "pitch": 4.0, "opt": 1.0},
		{"cat": "crate", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "wall_torch", "rule": &"light", "n": [2, 2], "opt": 1.0},
	],
	# the common: the well first, and it is the reason a common is a common
	&"common": [
		{"cat": "well", "rule": &"centre", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "bench", "rule": &"scatter", "n": [2, 2], "opt": 0.7},
		{"cat": "tree", "rule": &"centre", "n": [1, 1], "opt": 0.5, "plant": true,
			"palette": "green"},
		{"cat": "flower", "rule": &"scatter", "n": [2, 4], "opt": 0.6, "plant": true},
	],
	&"church": [
		{"cat": "tree", "rule": &"ring", "n": [4, 6], "opt": 0.8, "plant": true,
			"palette": "edge"},
	],
	&"gate": [
		{"cat": "signpost", "rule": &"beside", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "lamp_post", "rule": &"beside", "n": [2, 2], "opt": 1.0, "built": true},
	],
	&"water": [
		{"cat": "rock", "rule": &"bank", "n": [2, 5], "opt": 0.8, "plant": true},
		{"cat": "plant", "rule": &"bank", "n": [2, 4], "opt": 0.7, "plant": true},
	],
	&"strand": [
		{"cat": "boat", "rule": &"bank", "n": [1, 2], "opt": 1.0, "built": true},
		{"cat": "drying_rack", "rule": &"bank", "n": [1, 2], "opt": 0.9, "built": true},
		{"cat": "crate", "rule": &"bank", "n": [1, 2], "opt": 0.7},
	],
	# the edge: what bounds the village, at the culture's own density
	# `fill` because an edge is as long as the village is round: §9.6 walks
	# the perimeter and refuses a run over twenty-five metres with nothing
	# within six of it, so the count cannot be a number in a recipe -- a
	# fourteen-tree edge round a three-hundred-metre village leaves six
	# hundred metres of nothing. The rule supplies the places and the step
	# takes all of them.
	&"edge": [
		{"cat": "tree", "rule": &"band", "n": [6, 14], "opt": 1.0, "plant": true,
			"palette": "edge", "fill": true},
		{"cat": "ground", "rule": &"band", "n": [4, 10], "opt": 0.6, "plant": true,
			"palette": "ground"},
	],
}

## §8's palette, by culture. Four slots, and a village plants from one row and
## no other: `edge` at the boundary and behind the farms, `green` the one tree
## on the common, `hedge` along a lot's side boundaries and the verges,
## `ground` the cover on the verges and the common.
##
## The keys are catalogue keys, not categories, because a palette is exactly
## the business of naming WHICH birch. A `*` suffix takes every catalogue key
## with that prefix, so a pack that ships a sixth pine is planted without this
## table changing.
const PALETTES := {
	&"english": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"]},
	&"frankish": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"]},
	&"norse": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"]},
	&"alpine": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"]},
	&"moorish": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"]},
	&"eastern": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"]},
	# no green tree at all: nothing grows on a blighted common
	&"blighted": {"edge": ["Nature_DeadTree_*", "Wild_DeadTree_*"],
		"green": [], "hedge": ["Wild_Mushroom_*"],
		"ground": ["Wild_Mushroom_*", "Wild_Pebble_Square_*"]},
}

## The props that are BUILT rather than loaded (VIL-010). A recipe step marked
## `built` names one of these instead of a catalogue category; the assembler
## emits it from `PropKit` and the checks measure the AABB it returns.
const BUILT := {
	"well": {"size": Vector2(2.1, 2.1), "zone": 1.0},
	"signpost": {"size": Vector2(0.8, 0.8), "zone": 0.0},
	"lamp_post": {"size": Vector2(0.6, 0.6), "zone": 0.0, "light": true},
	"haystack": {"size": Vector2(2.8, 2.8), "zone": 0.0},
	"boat": {"size": Vector2(1.6, 4.4), "zone": 0.8},
	"drying_rack": {"size": Vector2(1.6, 3.0), "zone": 0.8},
	"mill_wheel": {"size": Vector2(3.8, 0.8), "zone": 0.0},
	"adit": {"size": Vector2(2.4, 1.2), "zone": 1.2},
	"fence_gate": {"size": Vector2(2.0, 0.4), "zone": 1.2},
}

## How thick the planted band outside the enclosure is, by enclosure kind --
## the same table §1 sizes the edge band with.
const EDGE_BAND := {&"none": 4.0, &"hedge": 5.0, &"palisade": 8.0, &"wall": 10.0}
## A `forest` village plants its edge at twice the density.
const FOREST_DENSITY := 2.0
## The green tree stands this far off the well.
const GREEN_TREE_CLEAR := 4.0


## Dress a planned village: fills `plan.props` and `plan.plants` and nothing
## else. Mutates the plan it is given, like the furnisher does; returns it for
## convenience.
static func dress(plan: VillagePlan) -> VillagePlan:
	if plan == null or plan.spec == null or plan.buildings.is_empty():
		return plan
	plan.props.clear()
	plan.plants.clear()
	_outer_land(plan)
	var ctx: Dictionary = _context(plan)
	_enclosure_hedge(plan, ctx)
	_mill_wheels(plan, ctx)
	_mine_adit(plan, ctx)
	_wood(plan, ctx)
	# hosts in a fixed order: the common first (the well is what everything
	# else keeps clear of), then the buildings in plan order, then the places
	for step in [&"common", &"market", &"church", &"gate", &"water", &"strand"]:
		_dress_place(plan, ctx, step)
	for i in range(plan.buildings.size()):
		_dress_building(plan, ctx, i)
	_blight_remnants(plan, ctx)
	_hedges(plan, ctx)
	_dress_place(plan, ctx, &"edge")
	return plan


## A hedge is a measured, continuous planted row. Neighbouring bushes may
## overlap as a hedge, but every road verge, roof and water body stays clear.
static func _enclosure_hedge(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.enclosure != &"hedge" or plan.enclosure.is_empty():
		return
	var keys: Array[String] = _palette_keys(ctx, "hedge")
	if keys.is_empty():
		return
	var rng := _rng(plan, "enclosure_hedge")
	for e in plan.enclosure.size():
		for run in VillageBuilder._minus_gates(plan.enclosure[e], plan.enclosure[(e + 1) % plan.enclosure.size()], plan.gate_crossings):
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			var steps := maxi(1, int(ceil(a.distance_to(b) / 1.6)))
			for i in steps:
				var at := a.lerp(b, (float(i) + 0.5) / float(steps))
				var key := keys[rng.randi() % keys.size()]
				var radius := maxf(PropCatalog.trunk(key), PropCatalog.canopy(key))
				var clear := true
				for water in plan.water:
					if Poly.contains_point(water["poly"], at) or VillageMeasure.point_to_poly(at, water["poly"]) < radius + 0.3:
						clear = false
				for ribbon in ctx["roads"]:
					if Poly.contains_point(ribbon, at) or VillageMeasure.point_to_poly(at, ribbon) < radius + TRUNK_CLEAR:
						clear = false
				for bounds in ctx["bounds"]:
					if Poly.contains_point(bounds, at) or VillageMeasure.point_to_poly(at, bounds) < radius + TRUNK_CLEAR:
						clear = false
				if not clear:
					continue
				plan.plants.append({"key": key, "pos": at, "canopy": PropCatalog.canopy(key),
					"trunk": PropCatalog.trunk(key), "yaw": rng.randf_range(0, TAU), "zone": &"enclosure"})
				_remember(ctx, at, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), radius)


## The mine mouth sits beside the final through-road segment, inside the
## boundary and facing the road. PropKit measures the whole piece, including
## the spoil heaps; the nominal recipe size is too narrow for those heaps.
static func _mine_adit(plan: VillagePlan, ctx: Dictionary) -> void:
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
				if not _prop_is_clear(plan, ctx, rect, rect):
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
				_remember(ctx, at, claim, claim.size.length() * 0.5)
				return


## A small broken wall and fungal colony tell the blighted settlement's
## story. Use measured owned models, on dry ground and clear of routes.
static func _blight_remnants(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.culture != &"blighted":
		return
	var rng := _rng(plan, "blight_remnants")
	var centres := _scatter(Poly.from_rect(plan.site.grow(-5.0)), rng, 120)
	for centre in centres:
		var wet := false
		for water in plan.water:
			if Poly.contains_point(water["poly"], centre) or VillageMeasure.point_to_poly(centre, water["poly"]) < 4.0:
				wet = true
		if wet:
			continue
		if not _place(plan, ctx, {"yaw": 0.0}, "Dungeon_Wall_Broken", centre, rng, -1):
			continue
		plan.props[-1]["group"] = "blight_ruin"
		for offset in [Vector2(2.6, 0), Vector2(-2.6, 0.3)]:
			if _place(plan, ctx, {"yaw": 0.0}, "Dungeon_Wall_Broken", centre + offset, rng, -1):
				plan.props[-1]["group"] = "blight_ruin"
		for offset in [Vector2(-2,-2), Vector2(-1,-2), Vector2(0,-2), Vector2(1,-2),
			Vector2(2,-2), Vector2(-1,2), Vector2(0,2), Vector2(1,2)]:
			_place(plan, ctx, {"plant": true}, "Wild_Mushroom_Common", centre + offset, rng, -1)
		return


static func _mill_wheels(plan: VillagePlan, ctx: Dictionary) -> void:
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
		_remember(ctx, at, rect, VillageWaterPlan.WHEEL_RADIUS + 0.1)


## Materialise dressed land beyond the measured lot hull. This runs after lot
## cutting, so outside fields cannot influence frontage or building placement.
static func _outer_land(plan: VillagePlan) -> void:
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


static func _wood(plan: VillagePlan, ctx: Dictionary) -> void:
	var derived: Dictionary = VillageEnclosurePlan.build(plan)
	var edge: PackedVector2Array = derived["edge"]
	if edge.size() < 3:
		return
	var centre: Vector2 = derived["wood"]
	if Poly.contains_point(edge, centre):
		return
	var keys: Array[String] = _palette_keys(ctx, "edge")
	if keys.is_empty():
		return
	var key: String = keys[0]
	var rng := _rng(plan, "wood")
	for offset: Vector2 in [Vector2(-4.0, 0.0), Vector2(0.0, 3.0), Vector2(4.0, 0.0)]:
		var at: Vector2 = centre + offset
		var trunk: float = maxf(PropCatalog.trunk(key), 0.1)
		if not _plant_is_clear(plan, ctx, at, trunk, PropCatalog.canopy(key)):
			continue
		plan.plants.append({"key": key, "pos": at,
			"canopy": PropCatalog.canopy(key), "trunk": trunk,
			"yaw": snappedf(rng.randf_range(0.0, TAU), 0.001), "zone": &"wood"})


## What every placement has to keep clear of, gathered once: the road ribbons
## with their verges, every building's measured bounds, the door swings, and
## the common. Rebuilding this per prop is what would make dressing a village
## take longer than planning one.
static func _context(plan: VillagePlan) -> Dictionary:
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
		var d: Vector2 = VillageMeasure.door(b)
		doors.append(Rect2(d - Vector2(DOOR_CLEAR, DOOR_CLEAR),
			Vector2(DOOR_CLEAR, DOOR_CLEAR) * 2.0))
	# Bounding rects beside the polygons, and beside the road ribbons: every
	# clearance test below rejects on the cheap rect first and only reaches
	# for `Geometry2D` when the rects actually meet. A village plants
	# hundreds of pieces and each one was intersecting sixty polygons.
	var road_boxes: Array[Rect2] = []
	for ribbon in roads:
		road_boxes.append(Poly.bounding_rect(ribbon))
	return {
		"roads": roads, "road_boxes": road_boxes,
		"bounds": bounds, "boxes": boxes, "doors": doors,
		# a coarse grid of what has been placed, so "is anything near here"
		# is a lookup and not a walk of every prop and plant already down. A
		# village plants hundreds of pieces and the walk made dressing one
		# slower than planning it.
		"grid": {},
		"common": VillageMeasure.common_poly(plan),
		"palette": PALETTES.get(plan.spec.culture, PALETTES[&"english"]),
	}


# ------------------------------------------------------------- the hosts

## One building's own dressing: which recipe it takes is its programme role,
## read off the request the way the checks read it.
static func _dress_building(plan: VillagePlan, ctx: Dictionary, i: int) -> void:
	var host: StringName = host_of(plan, i)
	if not RECIPES.has(host):
		return
	var rng := _rng(plan, "host|%d" % i)
	for step in RECIPES[host]:
		_apply(plan, ctx, step, rng, i, host)


## What a building is, for dressing: its shop business where it has one, then
## `farm` for a farmer's house, then plain `house`. A church or temple is the
## churchyard's host.
static func host_of(plan: VillagePlan, i: int) -> StringName:
	var b: Dictionary = plan.buildings[i]
	var request: BuildingRequest = b["request"]
	match request.kind:
		&"church", &"temple":
			return &"church"
		&"shop":
			match request.purpose:
				&"blacksmith":
					return &"smithy"
				&"tavern", &"inn":
					return &"tavern"
				&"stable":
					return &"stable"
			return &"shop"
		&"house":
			return &"farm" if request.purpose == &"farmer" else &"house"
	return &""


## The places that are not buildings: the common, the market on it, the
## gates, the water, the strand, the edge.
static func _dress_place(plan: VillagePlan, ctx: Dictionary, place: StringName) -> void:
	if not RECIPES.has(place):
		return
	match place:
		&"common", &"market":
			if (ctx["common"] as PackedVector2Array).is_empty():
				return
			if place == &"market" and not _has_market(plan):
				return
		&"church":
			return          # the churchyard is dressed with its building
		&"water", &"strand":
			if plan.water.is_empty():
				return
			if place == &"strand" and plan.spec.purpose != &"fishing":
				return
		&"gate":
			if VillageMeasure.gates(plan).is_empty():
				return
	var rng := _rng(plan, "place|%s" % String(place))
	for step in RECIPES[place]:
		_apply(plan, ctx, step, rng, -1, place)


static func _has_market(plan: VillagePlan) -> bool:
	for row in plan.spec.programme:
		if row["kind"] == &"market":
			return true
	return false


# -------------------------------------------------------------- the rules

## One recipe step: roll the die, work out how many, and place them by the
## step's own rule. Anything that finds nowhere legal is simply not placed --
## an outdoor recipe is a description of a full village, and a hamlet is not
## a failure for having one bench instead of two.
static func _apply(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName) -> void:
	var opt: float = float(step.get("opt", 1.0))
	if opt < 1.0 and rng.randf() > opt:
		return
	var span: Array = step["n"]
	var count: int = rng.randi_range(int(span[0]), int(span[1]))
	if role == &"market" and step["cat"] == "stall" and plan.spec.form == &"planted":
		count = maxi(count, 8)
	if count <= 0:
		return
	var keys: Array[String] = _keys_for(ctx, step)
	if keys.is_empty():
		return
	# Walk the candidates until `count` pieces are down, rather than trying
	# the first `count` of them: a rule offers several places on purpose --
	# either side of the door, then further out from the wall -- and taking
	# only the first meant one blocked spot lost the piece entirely.
	var spots: Array[Vector2] = _spots_for(plan, ctx, step, rng, host, role, count)
	if bool(step.get("fill", false)):
		count = spots.size()
	var placed := 0
	for spot in spots:
		if placed >= count:
			break
		var key: String = keys[rng.randi() % keys.size()]
		var placement_step: Dictionary = step
		if role == &"market" and step["rule"] == &"row":
			placement_step = step.duplicate()
			var common_rect := Poly.bounding_rect(ctx["common"])
			var along_x: bool = common_rect.size.x >= common_rect.size.y
			# Rows share an orientation and face the aisle, rather than each
			# stall looking diagonally toward the village centre.
			var across: float = spot.y - common_rect.get_center().y if along_x else spot.x - common_rect.get_center().x
			placement_step["yaw"] = (0.0 if across > 0.0 else PI) if along_x else (PI * 0.5 if across > 0.0 else -PI * 0.5)
		var accepted := _place(plan, ctx, placement_step, key, spot, rng, host)
		if not accepted and role == &"edge" and bool(step.get("fill", false)) \
				and bool(step.get("plant", false)):
			# A randomly chosen broad crown is not proof that no tree fits.
			# Try smaller members of the same cultural palette before leaving
			# a long hole beside a roof or another mature tree.
			var alternatives: Array[String] = keys.duplicate()
			alternatives.sort_custom(func(a: String, b: String) -> bool:
				return PropCatalog.canopy(a) < PropCatalog.canopy(b))
			for alternative in alternatives:
				if alternative == key: continue
				if _place(plan, ctx, placement_step, alternative, spot, rng, host):
					accepted = true
					break
			if not accepted and plan.spec.enclosure == &"none":
				# A track can graze the boundary for tens of metres. Offer the
				# inner side of the same visible edge band, rather than either
				# planting in the track or silently leaving that whole side bare.
				var inward_spot := _inside_edge(plan.site, spot, 5.0)
				for alternative in alternatives:
					if _place(plan, ctx, placement_step, alternative, inward_spot, rng, host):
						accepted = true
						break
		if accepted:
			if bool(step.get("orchard", false)):
				plan.plants[-1]["row"] = "orchard:%d" % host
				plan.plants[-1]["host"] = host
			placed += 1


static func _inside_edge(site: Rect2, spot: Vector2, depth: float) -> Vector2:
	var edge := Poly.from_rect(site.grow(-1.0))
	var nearest := Vector2.ZERO
	var inward := Vector2.ZERO
	var distance := INF
	for i in edge.size():
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % edge.size()]
		var projected := Geometry2D.get_closest_point_to_segment(spot, a, b)
		if spot.distance_to(projected) >= distance: continue
		distance = spot.distance_to(projected)
		nearest = projected
		inward = Vector2(-(b-a).y, (b-a).x).normalized()
		if inward.dot(site.get_center()-projected) < 0: inward = -inward
	return nearest + inward * depth


## Which catalogue keys a step may draw from: a palette slot for a plant, the
## BUILT table for a built prop, a category otherwise.
static func _keys_for(ctx: Dictionary, step: Dictionary) -> Array[String]:
	if bool(step.get("built", false)):
		var made: Array[String] = []
		if BUILT.has(String(step["cat"])):
			made.append(String(step["cat"]))
		return made
	if bool(step.get("plant", false)):
		var slot: String = String(step.get("palette", ""))
		if slot.is_empty():
			slot = _slot_for(String(step["cat"]))
		return _palette_keys(ctx, slot)
	return PropCatalog.of_category(String(step["cat"]))


## Which palette slot a plant category comes out of when the step does not
## name one.
static func _slot_for(cat: String) -> String:
	match cat:
		"tree", "dead_tree":
			return "edge"
		"bush":
			return "hedge"
		"ground", "grass", "flower", "pebble", "rock", "plant", "mushroom":
			return "ground"
	return "ground"


## The catalogue keys of one palette slot, expanding the `*` patterns. Only
## keys the catalogue actually knows are returned, so a palette naming a pack
## that is not installed plants nothing rather than crashing.
static func _palette_keys(ctx: Dictionary, slot: String) -> Array[String]:
	var out: Array[String] = []
	var palette: Dictionary = ctx["palette"]
	for pattern in palette.get(slot, []):
		var text: String = String(pattern)
		if text.ends_with("*"):
			var prefix: String = text.substr(0, text.length() - 1)
			for key in PropCatalog.plants():
				if key.begins_with(prefix) and PropCatalog.known(key):
					out.append(key)
		elif PropCatalog.known(text):
			out.append(text)
	return out


## Where a step's pieces go, by its rule. Every rule returns candidate points
## in a fixed order; `_place` is what refuses the illegal ones.
static func _spots_for(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName,
		count: int) -> Array[Vector2]:
	match StringName(step["rule"]):
		&"wall":
			return _along_front(plan, host, count, 0.0)
		&"light":
			# ON the wall, not out in front of it. A shop's setback is
			# six-tenths of a metre, so the ground a `wall` step steps out
			# into is the road, and a lamp that wants ground has nowhere to
			# hang -- which is how a village came out unlit.
			return _along_front(plan, host, count, -0.4)
		&"verge":
			return _along_front(plan, host, count, _verge_offset(plan, host))
		&"yard":
			return _in_yard(plan, host, count, rng)
		&"corner":
			return _lot_corners(plan, host, count)
		&"row":
			return _row(plan, ctx, step, host, role, count)
		&"on":
			return _on_props(plan, host, count)
		&"centre":
			return _common_centre(plan, ctx, count)
		&"scatter":
			return _scatter(ctx["common"], rng, count)
		&"ring":
			return _ring(plan, host, count)
		&"beside":
			return _beside_gates(plan, count)
		&"bank":
			return _along_water(plan, rng, count)
		&"band":
			return _edge_band(plan, rng, count)
	return []


## Points along the building's own front. `front_dir` points OUT of the
## building, so `off` is measured away from its wall: 0 is against it and the
## lot's setback less a stride is out on the verge.
##
## Candidates step BOTH ways -- along the front either side of the door, and
## progressively further out from the wall -- because the near ones are often
## under the eaves. `bounds` covers the roof overhang and `front_mid` is on
## the walls, so a barrel a metre off the wall can still be inside the
## building as far as every check is concerned; without the outward steps
## most houses got no barrel at all.
static func _along_front(plan: VillagePlan, host: int, count: int,
		off: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var mid: Vector2 = VillageMeasure.front_mid(b)
	var dir: Vector2 = VillageMeasure.front_dir(b)
	var across := Vector2(-dir.y, dir.x)
	# A fixed spread of candidates, not `count` of them. Every `wall` step of
	# the same host is offered the same list, so a list only two long meant
	# the anvil and the barrel took both places and the smithy's own lamp had
	# nowhere left -- and a village with nothing lit is a village at night.
	for step_out in range(3):
		for k in range(FRONT_SPOTS):
			var side: float = 1.0 if k % 2 == 0 else -1.0
			var reach: float = 1.4 + float(k / 2) * 1.1
			out.append(mid + across * (side * reach)
				+ dir * (off + 0.8 + float(step_out) * 0.7))
	return out


## How far out the verge is: the lot's own setback, less a stride so the
## bench stands on the verge and not in the road.
static func _verge_offset(plan: VillagePlan, host: int) -> float:
	if host < 0:
		return 0.0
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return 0.0
	return maxf(float(plan.lots[lot].get("setback", 2.0)) - 1.6, 0.0)


## In the lot, behind the front line of the building: the yard.
static func _in_yard(plan: VillagePlan, host: int, count: int,
		rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(b)
	var back: Vector2 = VillageMeasure.centre(bounds) + behind * 4.0
	for k in range(count * 3):
		var jitter := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var p: Vector2 = back + jitter
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


static func _lot_corners(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var centre: Vector2 = VillageMeasure.centre(poly)
	for p in poly:
		if out.size() >= count:
			break
		out.append(Vector2(p).lerp(centre, 0.15))
	return out


## N copies along an axis at a pitch: the orchard behind a farm, the rows of
## stalls on the square.
static func _row(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		host: int, role: StringName, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pitch: float = float(step.get("pitch", 4.0))
	if role == &"market":
		var common: PackedVector2Array = ctx["common"]
		if common.is_empty():
			return out
		var rect: Rect2 = Poly.bounding_rect(common)
		# rows along the square's longer axis, the aisle between them
		var along: Vector2 = Vector2(1, 0) if rect.size.x >= rect.size.y else Vector2(0, 1)
		var across := Vector2(-along.y, along.x)
		var mid: Vector2 = rect.get_center()
		var columns: int = maxi(3, int(ceil(float(count) / 2.0)))
		# Offer spare places at the ends so a well or bench cannot silently
		# reduce an earned market's eight stalls. Two rows leave an open aisle.
		# Keep side aisles as well as the central aisle. A full-width row
		# leaves no way round its end once cart footprints and a person's
		# radius are accounted for, stranding benches beyond the market.
		columns = mini(columns + 2, int(floor((maxf(rect.size.x, rect.size.y) - 4.0) / pitch)))
		for slot in range(columns):
			for row in range(2):
				out.append(mid + along * ((float(slot) - float(columns - 1) * 0.5) * pitch)
					+ across * ((float(row) - 0.5) * 8.0))
		return out
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var bounds := VillageMeasure.bounds_poly(b)
	var centre := VillageMeasure.centre(bounds)
	var reach := 0.0
	for point in bounds:
		reach = maxf(reach, (point - centre).dot(behind))
	var crown := 0.0
	for key in _keys_for(ctx, step):
		crown = maxf(crown, PropCatalog.canopy(key))
	var start := centre + behind * (reach + crown + TRUNK_CLEAR)
	var across2 := Vector2(-behind.y, behind.x)
	for k in range(count):
		out.append(start + across2 * ((float(k) - float(count - 1) * 0.5) * pitch))
	return out


## On something that has a top: a stall, a cart, a bench already placed.
static func _on_props(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in plan.props:
		if out.size() >= count:
			break
		if PropCatalog.has_tag(String(p["key"]), PropCatalog.SURFACE):
			out.append(p["pos"])
	return out


static func _common_centre(plan: VillagePlan, ctx: Dictionary,
		count: int) -> Array[Vector2]:
	var common: PackedVector2Array = ctx["common"]
	if common.is_empty():
		return []
	var centre: Vector2 = VillageMeasure.centre(common)
	var bounds: Rect2 = Poly.bounding_rect(common)
	# The geometric centre can be occupied by a road ribbon on a bowed or
	# ringed street form.  Keep it as the first candidate, but offer measured
	# in-common fallbacks so the required well is not silently lost to that
	# incidental overlap.  `_apply` walks candidates until one is legal.
	var step_x: float = maxf(1.5, bounds.size.x * 0.28)
	var step_y: float = maxf(1.5, bounds.size.y * 0.28)
	var candidates: Array[Vector2] = [centre,
		centre + Vector2(step_x, 0.0), centre - Vector2(step_x, 0.0),
		centre + Vector2(0.0, step_y), centre - Vector2(0.0, step_y)]
	var out: Array[Vector2] = []
	for p in candidates:
		if Poly.contains_point(common, p):
			out.append(p)
	# Anything after the first stands off the middle, so the green tree does
	# not try to grow out of the well.  The common recipe normally asks for one
	# tree, but retaining a few measured candidates keeps optional trees from
	# consuming the well's fallback slot.
	for k in range(1, count):
		var p := centre + Vector2(GREEN_TREE_CLEAR + float(k), 0.0)
		if Poly.contains_point(common, p):
			out.append(p)
	return out


static func _scatter(poly: PackedVector2Array, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.is_empty():
		return out
	var rect: Rect2 = Poly.bounding_rect(poly)
	for k in range(count * 4):
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y))
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


## Round the churchyard: the yews of §7, on a ring outside the church's own
## bounds.
static func _ring(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[host])
	var rect: Rect2 = Poly.bounding_rect(bounds)
	var radius: float = maxf(rect.size.x, rect.size.y) * 0.5 + 3.0
	var centre: Vector2 = rect.get_center()
	for k in range(count):
		var a: float = TAU * float(k) / float(maxi(count, 1))
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out


static func _beside_gates(plan: VillagePlan, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g in VillageMeasure.gates(plan):
		for side in [1.0, -1.0]:
			if out.size() >= count * 2:
				break
			out.append(g + Vector2(0.0, side * 5.0))
	return out


static func _along_water(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in plan.water:
		var poly: PackedVector2Array = w["poly"]
		var grown: PackedVector2Array = Poly.offset(poly, 1.5)
		for p in grown:
			if out.size() >= count * 2:
				break
			out.append(p)
	return out


## The band outside the enclosure, or just inside the site edge when there is
## no enclosure: where the village is bounded by something.
static func _edge_band(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var band: float = float(EDGE_BAND.get(plan.spec.enclosure, 4.0))
	var site: Rect2 = plan.site
	var inner: Rect2 = site.grow(-band - 1.0)
	var want: int = count
	if plan.spec.purpose == &"forest":
		want = int(float(count) * FOREST_DENSITY)
	# WALKED along the edge at a pitch, not scattered near it. §9.6 walks the
	# same perimeter and refuses a run longer than twenty-five metres with
	# nothing within six of it; scattering `want` trees over a site hundreds
	# of metres round left a hundred and fourteen metres of it bare.
	#
	# `want` is a floor, not a cap: the band is as long as the village is
	# round, and the recipe's count says how densely, not how many.
	var ring: PackedVector2Array = Poly.from_rect(site.grow(-0.5))
	if plan.spec.enclosure != &"none":
		var derived: Dictionary = VillageEnclosurePlan.build(plan)
		var derived_edge: PackedVector2Array = derived["edge"]
		if derived_edge.size() >= 3:
			ring = derived_edge
	var perimeter: float = Poly.polyline_length(ring) + ring[0].distance_to(ring[ring.size() - 1])
	var pitch: float = EDGE_PITCH
	if plan.spec.purpose == &"forest":
		pitch *= 0.5
	var steps: int = maxi(int(perimeter / pitch), want)
	var n: int = ring.size()
	for k in range(steps):
		var t: float = float(k) / float(steps) * float(n)
		var seg: int = int(t) % n
		var a: Vector2 = ring[seg]
		var b: Vector2 = ring[(seg + 1) % n]
		var along: Vector2 = a.lerp(b, t - floorf(t))
		# a little way in from the boundary, and jittered so a planted edge
		# does not read as a fence of trees
		var inward: Vector2 = (site.get_center() - along).normalized()
		var depth: float = rng.randf_range(0.5, maxf(band, 1.5))
		var jitter := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var p: Vector2 = along + inward * depth + jitter
		if inner.has_point(p) or not site.has_point(p):
			continue          # inside the village, not at its edge
		out.append(p)
	return out


# ---------------------------------------------------------- placing them

## Put one piece down, if the ground is free. A plant goes in `plan.plants`
## with its measured trunk and canopy; everything else in `plan.props` with
## the floor it stands on and the floor a person needs to use it.
## True when the piece went down. False is not a failure: an outdoor recipe
## describes a full village, and a hamlet is not wrong for having one bench
## where the recipe offers two.
static func _place(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		key: String, at: Vector2, rng: RandomNumberGenerator, host: int) -> bool:
	var is_plant: bool = bool(step.get("plant", false))
	if is_plant:
		if bool(step.get("orchard", false)) and (host < 0 or not Poly.contains_point(plan.lots[plan.lot_of_building(host)]["poly"], at)):
			return false
		var trunk: float = maxf(PropCatalog.trunk(key), 0.1)
		if not _plant_is_clear(plan, ctx, at, trunk, PropCatalog.canopy(key)):
			return false
		plan.plants.append({"key": key, "pos": at,
			"canopy": PropCatalog.canopy(key), "trunk": trunk,
			"yaw": snappedf(rng.randf_range(0.0, TAU), 0.001)})
		_remember(ctx, at, Rect2(at - Vector2(trunk, trunk),
			Vector2(trunk, trunk) * 2.0), trunk)
		return true
	var built: bool = bool(step.get("built", false))
	var size: Vector2 = Vector2(BUILT[key]["size"]) if built \
		else PropCatalog.footprint(key)
	var zone: float = float(BUILT[key]["zone"]) if built else PropCatalog.zone_depth(key)
	var yaw: float = float(step.get("yaw", _facing(plan, host, at)))
	var rect := Rect2(at - size / 2.0, size)
	var use := Rect2(at - Vector2(zone, zone), Vector2(zone, zone) * 2.0) \
		if zone > 0.0 else Rect2()
	# A lamp hangs on the wall and takes no floor, so it is held only to
	# being on the site and out of the doorway. Held to the floor rules it
	# competed for ground with the anvil and the barrel already against that
	# wall, and the smithy's own lamp lost every time -- which is how a
	# village came out with nothing lit at all.
	if not _prop_is_clear(plan, ctx, rect, use, PropCatalog.blocks_floor(key) or built):
		return false
	if not _host_owns(plan, ctx, host, at):
		return false
	plan.props.append({"key": key, "pos": at, "yaw": snappedf(yaw, 0.001),
		"host": host, "rect": rect, "zone": use,
		"built": built, "light": _is_light(key, built)})
	_remember(ctx, at, rect, maxf(size.x, size.y) * 0.5)
	return true


static func _is_light(key: String, built: bool) -> bool:
	if built:
		return bool(BUILT[key].get("light", false))
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
## front of it is where §7's `verge` rule puts a bench), or the common.
##
## §9.6's `host` rule measures exactly this, and without it the placer could
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
static func _prop_is_clear(plan: VillagePlan, ctx: Dictionary, rect: Rect2,
		zone: Rect2, floors := true) -> bool:
	if not plan.site.grow(-0.5).encloses(rect):
		return false
	var claim: Rect2 = rect.merge(zone) if zone.size.x > 0.0 else rect
	var wide: Rect2 = claim.grow(ROAD_CLEAR)
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
	var grown: Rect2 = rect.grow(PROP_CLEAR)
	for near in _near(ctx, rect.get_center(), grown.size.length()):
		if grown.intersects(near["rect"] as Rect2):
			return false
	return true


## A trunk off every road and every building, and a canopy over no roof.
## Same functions as the checks -- `overlap_area` over `Geometry2D`, not the
## convex clipper, because a road ribbon bends.
static func _plant_is_clear(plan: VillagePlan, ctx: Dictionary, at: Vector2,
		trunk: float, canopy: float) -> bool:
	if not plan.site.has_point(at):
		return false
	# The green's working space belongs to the well. Large boulders from a
	# ground palette need the same clearance as trees placed by its green rule.
	if canopy >= 1.0:
		for prop in plan.props:
			if prop["key"] == "well" and at.distance_to(prop["pos"]) < GREEN_TREE_CLEAR:
				return false
	for w in plan.water:
		if w["kind"] == &"race" and VillageMeasure.point_to_poly(at, w["poly"]) < trunk + 0.2:
			return false
	var stem_rect: Rect2 = Rect2(at - Vector2(trunk, trunk),
		Vector2(trunk, trunk) * 2.0).grow(TRUNK_CLEAR)
	var stem: PackedVector2Array = Poly.from_rect(stem_rect)
	var road_boxes: Array[Rect2] = ctx["road_boxes"]
	var roads: Array[PackedVector2Array] = ctx["roads"]
	for i in range(roads.size()):
		if not road_boxes[i].intersects(stem_rect):
			continue
		if VillageLotPlanner.overlap_area(stem, roads[i]) > VillageLotPlanner.AREA_EPS:
			return false
	var crown_rect: Rect2 = Rect2(at - Vector2(canopy, canopy),
		Vector2(canopy, canopy) * 2.0).grow(-CANOPY_SLACK)
	var crown: PackedVector2Array = Poly.from_rect(crown_rect)
	var boxes: Array[Rect2] = ctx["boxes"]
	var bounds: Array[PackedVector2Array] = ctx["bounds"]
	for j in range(bounds.size()):
		if not boxes[j].grow(canopy + TRUNK_CLEAR).has_point(at):
			continue
		# The CHECK'S measurement, not a rect overlap: `DressCheck.canopies`
		# asks for the true distance from the trunk to the building, and a
		# rect that only touches a polygon at a corner has no overlapping
		# area at all -- so the two disagreed by a few centimetres and the
		# dresser planted bushes the check then refused.
		var d: float = VillageMeasure.point_to_poly(at, bounds[j])
		if Poly.contains_point(bounds[j], at) or d < trunk + TRUNK_CLEAR:
			return false
		if canopy > 0.0 and d < canopy:
			return false
	for d in ctx["doors"]:
		if d.has_point(at):
			return false
	for near in _near(ctx, at, trunk + GRID_CELL):
		if (near["rect"] as Rect2).grow(trunk).has_point(at):
			return false
		if at.distance_to(near["pos"]) < trunk + float(near["radius"]) + 0.5:
			return false
	return true


# ------------------------------------------------------------- the hedges

## A hedge along each lot's side boundaries, with a gap where the path to the
## door crosses it. Culture's `hedge` slot, at a pitch, and only where the
## village is rich enough to keep one (§7: `row`, wealth x 0.8).
static func _hedges(plan: VillagePlan, ctx: Dictionary) -> void:
	var keys: Array[String] = _palette_keys(ctx, "hedge")
	if keys.is_empty():
		return
	var rng := _rng(plan, "hedge")
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
				var _in_hedge: bool = _place(plan, ctx,
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
static func _remember(ctx: Dictionary, at: Vector2, rect: Rect2, radius: float) -> void:
	var grid: Dictionary = ctx["grid"]
	var cell := Vector2i(int(floorf(at.x / GRID_CELL)), int(floorf(at.y / GRID_CELL)))
	if not grid.has(cell):
		grid[cell] = []
	(grid[cell] as Array).append({"pos": at, "rect": rect, "radius": radius})


## Everything already placed within `reach` of `at`, from the grid.
static func _near(ctx: Dictionary, at: Vector2, reach: float) -> Array:
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
static func _rng(plan: VillagePlan, key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dress|%d|%s" % [plan.spec.seed, key])
	return rng
