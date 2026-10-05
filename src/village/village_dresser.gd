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
	if plan.spec.compact_display:
		_compact_plants(plan, ctx)
	else:
		VillageDressHosts.dress_place(plan, ctx, &"edge")
	# Shore yards must be reached through the final garden and hedge layout.
	# An unobstructed apron cannot help when later planting cuts its yard off.
	VillageDressHosts.dress_place(plan, ctx, &"strand")
	VillageDressHosts.dress_place(plan, ctx, &"reeds")
	return plan


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
	for plant in plan.plants:
		if VillageDressPlacement.plant_kind(plant["key"]) == &"tree": trees += 1
	for attempt in range(500):
		if trees >= 12: break
		var at := Vector2(rng.randf_range(occupied.position.x, occupied.end.x),
			rng.randf_range(occupied.position.y, occupied.end.y))
		var key: String = keys[attempt % keys.size()]
		if VillageDressPlacement.plant_kind(key) != &"tree": continue
		if VillageDressPlacement.place(plan, ctx, {"plant": true, "palette": "edge"}, key, at, rng, -1):
			trees += 1


## A compact display plants its occupied gaps; it has no distant forest ring.
static func edge_band_required(spec: VillageSpec) -> bool:
	return not spec.compact_display
