class_name VillageDresser
extends RefCounted
## What is standing about outside (VIL-013). VILLAGES Â§7 and Â§8.
##
## The same shape as `HouseFurnisher`: a table of VillageDressCatalog.RECIPES keyed by host, each
## a list of steps naming a prop CATEGORY and a RULE, never a coordinate.
## Indoors the rules are wall/free/around/corner/mounted/on; out here they are
## the seven Â§7 gives, and they mean the same kind of thing:
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
## Â§8's palette -- so a norse edge is birch and pine and a moorish one twisted
## trees and pebbles, and no village mixes two palettes.
##
## Nothing here trusts itself. `DressCheck` re-derives every footprint, every
## trunk and every canopy from the placements alone and judges them.
##
## Deterministic: every draw comes from an RNG seeded by name from the spec's
## seed, and the plan is never read in a different order than it is written.

static func dress(plan: VillagePlan) -> VillagePlan:
	if plan == null or plan.spec == null or plan.buildings.is_empty():
		return plan
	plan.props.clear()
	plan.plants.clear()
	if not plan.spec.compact_display:
		VillageDressContext.outer_land(plan)
	var ctx: Dictionary = VillageDressContext.make_context(plan)
	VillageDressContext.enclosure_hedge(plan, ctx)
	VillageDressContext.mill_wheels(plan, ctx)
	VillageDressContext.mine_adit(plan, ctx)
	VillageDressContext.wood(plan, ctx)
	# hosts in a fixed order: the common first (the well is what everything
	# else keeps clear of), then the buildings in plan order, then the places
	for step in [&"common", &"market", &"church", &"gate", &"water"]:
		VillageDressHosts.dress_place(plan, ctx, step)
	for i in range(plan.buildings.size()):
		VillageDressHosts.dress_building(plan, ctx, i)
	VillageDressContext.blight_remnants(plan, ctx)
	VillageDressPlacement.hedges(plan, ctx)
	if plan.spec.compact_display and plan.spec.decoration_level > 0.0:
		_compact_plants(plan, ctx)
	else:
		if not plan.spec.compact_display:
			VillageDressHosts.dress_place(plan, ctx, &"edge")
	# Shore yards must be reached through the final garden and hedge layout.
	# An unobstructed apron cannot help when later planting cuts its yard off.
	VillageDressHosts.dress_place(plan, ctx, &"strand")
	VillageDressHosts.dress_place(plan, ctx, &"reeds")
	_lush_pass(plan, ctx)
	open_ground(plan, ctx)
	return plan


## Open ground (walk QA, Wolfmarch Green pins 2 and 8: "really empty", "big
## gaps"). A village's site is sized for its roads, so between the last lot and
## the edge band there can be tens of metres of land nobody planned: not a lot,
## not a road, not the common, and before this pass nothing grew on it. The
## edge band dresses only the boundary, so a whole field of bare slab lay
## between the main street and the trees.
##
## The land is found by measurement, not by form: a grid of points, each kept
## when nothing planned -- lot, road and its verge, common, field, water,
## building bounds -- is within OPEN_CLEAR of it. The most open of those are
## taken OPEN_SPACING apart and each becomes a small patch: a copse (a tree or
## three from the culture's own edge palette, a bush from its hedge, ground
## cover), or in a farming village every other patch a hay meadow (a built
## haystack with cover and a bush round it). Plants and built pieces only: the
## open land is not walk-grid floor, so nothing with a use space goes there.
##
## It runs LAST, each patch on its own named stream, so every earlier
## placement is exactly what it was. Decoration scales it: none at zero, the
## patches at the default, and fuller patches above it. Low upkeep turns some
## copse trees to the culture's dead wood.
const OPEN_PITCH := 4.0
const OPEN_CLEAR := 7.0
const OPEN_SPACING := 15.0
const OPEN_EDGE := 6.0
const OPEN_MAX := 16


static func open_ground(plan: VillagePlan, ctx: Dictionary) -> void:
	var level: float = clampf(plan.spec.decoration_level, 0.0, 1.0)
	if level <= 0.0 or plan.spec.compact_display:
		return
	var patches: Array[Vector2] = open_patches(plan, ctx)
	var count: int = mini(patches.size(), int(ceil(float(patches.size()) * minf(level * 2.0, 1.0))))
	var farming: bool = plan.spec.purpose in [&"farming", &"forest"]
	for i in range(count):
		var rng := VillageDressPlacement.rng(plan, "open|%d" % i)
		var centre: Vector2 = patches[i]
		if farming and i % 2 == 1:
			_hay_meadow(plan, ctx, centre, rng, level)
		else:
			_copse(plan, ctx, centre, rng, level)


## The centres of the open patches, most open first, OPEN_SPACING apart.
static func open_patches(plan: VillagePlan, ctx: Dictionary) -> Array[Vector2]:
	var blockers: Array[PackedVector2Array] = []
	for lot in plan.lots:
		blockers.append(lot["poly"])
	for road in plan.roads:
		blockers.append(VillageSitePlanner.road_ribbon(road, true))
	for c in plan.commons:
		blockers.append(c["poly"])
	for f in plan.fields:
		if f.has("poly"):
			blockers.append(f["poly"])
	for w in plan.water:
		blockers.append(w["poly"])
	for b in ctx["bounds"]:
		blockers.append(b)
	if plan.landmark_site.has("poly"):
		blockers.append(plan.landmark_site["poly"])
	var boxes: Array[Rect2] = []
	for poly in blockers:
		boxes.append(Poly.bounding_rect(poly).grow(OPEN_CLEAR))
	var inner: Rect2 = plan.site.grow(-OPEN_EDGE)
	var scored: Array = []
	var z: float = inner.position.y + OPEN_PITCH * 0.5
	while z < inner.end.y:
		var x: float = inner.position.x + OPEN_PITCH * 0.5
		while x < inner.end.x:
			var p := Vector2(x, z)
			var clear := OPEN_CLEAR * 2.0
			for k in range(blockers.size()):
				if not boxes[k].has_point(p):
					continue
				if Poly.contains_point(blockers[k], p):
					clear = 0.0
					break
				clear = minf(clear, VillageMeasure.point_to_poly(p, blockers[k]))
			if clear >= OPEN_CLEAR:
				scored.append([clear, p])
			x += OPEN_PITCH
		z += OPEN_PITCH
	# most open first; ties broken by position, so the order is the plan's own
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(a[0], b[0]):
			return a[0] > b[0]
		if not is_equal_approx(a[1].y, b[1].y):
			return a[1].y < b[1].y
		return a[1].x < b[1].x)
	var out: Array[Vector2] = []
	for row in scored:
		var p: Vector2 = row[1]
		var spaced := true
		for q in out:
			if p.distance_to(q) < OPEN_SPACING:
				spaced = false
				break
		if spaced:
			out.append(p)
			if out.size() >= OPEN_MAX:
				break
	return out


static func _copse(plan: VillagePlan, ctx: Dictionary, centre: Vector2,
		rng: RandomNumberGenerator, level: float) -> void:
	var trees: Array[String] = VillageDressRules.palette_keys(ctx, "edge")
	var dead: Array[String] = VillageDressRules.palette_keys(ctx, "wild")
	var tree_n: int = 1 + rng.randi_range(0, 1) + (1 if level > 0.5 else 0)
	for k in range(tree_n):
		var at: Vector2 = centre if k == 0 else centre + Vector2.from_angle(
			rng.randf_range(0.0, TAU)) * rng.randf_range(3.5, 5.5)
		var pool: Array[String] = trees
		if not dead.is_empty() and rng.randf() < (1.0 - plan.spec.upkeep) * 0.5:
			pool = dead
		_plant_one(plan, ctx, pool, "edge", at, rng)
	_ring_of(plan, ctx, "hedge", centre, 1 + (1 if level > 0.5 else 0), 2.5, 4.5, rng)
	_ring_of(plan, ctx, "ground", centre, 2 + int(round(level * 2.0)), 1.5, 4.0, rng)


static func _hay_meadow(plan: VillagePlan, ctx: Dictionary, centre: Vector2,
		rng: RandomNumberGenerator, level: float) -> void:
	VillageDressPlacement.place(plan, ctx, {"built": true, "yaw": 0.0}, "haystack", centre, rng, -1)
	var bush_at: Vector2 = centre + Vector2(4.5, 0.0).rotated(rng.randf_range(0.0, TAU))
	_ring_of(plan, ctx, "hedge", bush_at, 1, 0.0, 0.0, rng)
	_ring_of(plan, ctx, "ground", centre, 3 + int(round(level * 2.0)), 2.5, 4.5, rng)


## `n` plants of a palette slot on a ring round `centre`.
static func _ring_of(plan: VillagePlan, ctx: Dictionary, slot: String, centre: Vector2,
		n: int, r0: float, r1: float, rng: RandomNumberGenerator) -> void:
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, slot)
	if keys.is_empty():
		return
	for k in range(n):
		var at: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(r0, r1)
		_plant_one(plan, ctx, keys, slot, at, rng)


static func _plant_one(plan: VillagePlan, ctx: Dictionary, keys: Array[String], palette: String,
		at: Vector2, rng: RandomNumberGenerator) -> bool:
	if keys.is_empty():
		return false
	var key: String = keys[rng.randi() % keys.size()]
	if VillageDressPlacement.place(plan, ctx, {"plant": true, "palette": palette}, key, at, rng, -1):
		plan.plants[-1]["zone"] = &"open"
		return true
	return false


## Extra flowers are a new, isolated stream. The default .5 path never calls
## this pass, so historic recipe RNG and every default placement stay intact.
static func _lush_pass(plan: VillagePlan, ctx: Dictionary) -> void:
	if plan.spec.decoration_level <= 0.5:
		return
	var count := int(round(6.0 * (plan.spec.decoration_level - 0.5) * 2.0))
	if count <= 0:
		return
	var rng := VillageDressPlacement.rng(plan, "lush|common")
	var step := {"cat": "flower", "rule": &"scatter", "n": [count, count],
		"opt": 1.0, "plant": true, "palette": "ground"}
	VillageDressRules.apply(plan, ctx, step, rng, -1, &"common")
	# Kept on its own stream per host: extra beds beside houses cannot perturb
	# the historical barrels, work props, stalls, or any later host's rolls.
	for i in range(plan.buildings.size()):
		var host := VillageDressHosts.host_of(plan, i)
		if host not in [&"house", &"farm", &"tavern", &"stable"]:
			continue
		var yard_rng := VillageDressPlacement.rng(plan, "lush|host|%d" % i)
		var yard_count := maxi(1, int(round(3.0 * (plan.spec.decoration_level - 0.5) * 2.0)))
		var yard_step := {"cat": "flower", "rule": &"verge", "n": [yard_count, yard_count],
			"opt": 1.0, "plant": true, "palette": "ground"}
		VillageDressRules.apply(plan, ctx, yard_step, yard_rng, i, host)


## A few trees in genuine free gaps of the occupied display, never a distant
## decorative ring. The existing native canopy/trunk/door tests decide fit.
static func _compact_plants(plan: VillagePlan, ctx: Dictionary) -> void:
	var occupied := Rect2()
	for building in plan.buildings:
		var rect := Poly.bounding_rect(VillageMeasure.footprint_poly(building))
		occupied = rect if occupied.size == Vector2.ZERO else occupied.merge(rect)
	occupied = occupied.grow(3.5).intersection(plan.site.grow(-2.0))
	var keys := VillageDressRules.palette_keys(ctx, "edge")
	if keys.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("compact-trees|%d" % plan.spec.seed)
	var trees := 0
	var target := int(round(12.0 * plan.spec.decoration_level / 0.5)) \
		if plan.spec.decoration_level <= 0.5 else int(round(12.0 + 12.0 * (plan.spec.decoration_level - 0.5)))
	for plant in plan.plants:
		if VillageDressPlacement.plant_kind(plant["key"]) == &"tree": trees += 1
	for attempt in range(500):
		if trees >= target: break
		var at := Vector2(rng.randf_range(occupied.position.x, occupied.end.x),
			rng.randf_range(occupied.position.y, occupied.end.y))
		var key: String = keys[attempt % keys.size()]
		if VillageDressPlacement.plant_kind(key) != &"tree": continue
		if VillageDressPlacement.place(plan, ctx, {"plant": true, "palette": "edge"}, key, at, rng, -1):
			trees += 1


## A compact display plants its occupied gaps; it has no distant forest ring.
static func edge_band_required(spec: VillageSpec) -> bool:
	return not spec.compact_display
