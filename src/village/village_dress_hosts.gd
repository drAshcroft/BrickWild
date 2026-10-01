class_name VillageDressHosts
extends RefCounted
## Dispatches recipes to buildings and named village places.

# ------------------------------------------------------------- the hosts

## One building's own dressing: which recipe it takes is its programme role,
## read off the request the way the checks read it.
static func dress_building(plan: VillagePlan, ctx: Dictionary, i: int) -> void:
	var host: StringName = host_of(plan, i)
	if not VillageDressCatalog.RECIPES.has(host):
		return
	var rng := VillageDressPlacement.rng(plan, "host|%d" % i)
	# A house dresses its own yard (HouseYard, EVAL-B06): its measured
	# placement says which categories it already put outside. The village hands
	# those to the house instead of adding a second barrel, bench or cart, and
	# keeps what only a village plants -- trees, hedges, ground cover.
	var given: Array = (plan.buildings[i].get("placement", {}) as Dictionary).get("yard_categories", [])
	for step in VillageDressCatalog.RECIPES[host]:
		if not bool(step.get("plant", false)) and String(step["cat"]) in given:
			continue
		VillageDressRules.apply(plan, ctx, step, rng, i, host)


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
static func dress_place(plan: VillagePlan, ctx: Dictionary, place: StringName) -> void:
	if not VillageDressCatalog.RECIPES.has(place):
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
	if place == &"strand":
		ctx["strand_walk"] = VillageNavCheck.reached_grid(plan)
	var rng := VillageDressPlacement.rng(plan, "place|%s" % String(place))
	for step in VillageDressCatalog.RECIPES[place]:
		VillageDressRules.apply(plan, ctx, step, rng, -1, place)


static func _has_market(plan: VillagePlan) -> bool:
	for row in plan.spec.programme:
		if row["kind"] == &"market":
			return true
	return false

