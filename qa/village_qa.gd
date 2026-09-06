class_name VillageQA
extends RefCounted
## The whole village harness in one call (VILLAGES §9): the SIX checks over
## the VillagePlan -- scale, roads, lots, places, dressing and walking -- and
## then every building's own family QA. A village whose smithy has an anvil
## in the doorway fails the village.
##
## The order is the order of §9 and it is the order a person would look in:
## is this a village at all, do its roads make sense, do the houses sit on
## the street, is everything where a village puts it, does the dressing
## belong, and can a person walk it. Walking is last because it is the only
## one that rasterises the whole site, and there is no sense grinding a
## grid over a plan that has already failed to be a village.
##
## `overrides` replaces a named rule of any of the six plan checks
## (RuleSet, INT-020); the report says which under "replaced".
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...},
##           "replaced": {...}}


func check(plan: VillagePlan, overrides: Dictionary = {}, buildings := true) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}
	var replaced := {}
	for bad in RuleSet.unknown(overrides, [VillageScaleCheck.RULES, VillageRoadCheck.RULES,
			VillageLotCheck.RULES, VillagePlaceCheck.RULES,
			VillageDressCheck.RULES, VillageNavCheck.RULES]):
		failures.append("rules: no village rule is called %s" % bad)
	for part in [
		VillageScaleCheck.new().check(plan, overrides),
		VillageRoadCheck.new().check(plan, overrides),
		VillageLotCheck.new().check(plan, overrides),
		VillagePlaceCheck.new().check(plan, overrides),
		VillageDressCheck.new().check(plan, overrides),
		VillageNavCheck.new().check(plan, overrides),
	]:
		for f in part["failures"]:
			failures.append(str(f))
		for w in part["warnings"]:
			warnings.append(str(w))
		for k in part["stats"]:
			stats[k] = part["stats"][k]
		for r in part.get("replaced", {}):
			replaced[r] = part["replaced"][r]
	if buildings:
		for i in range(plan.buildings.size()):
			var rep: Dictionary = _building_qa(plan.buildings[i])
			for f2 in rep.get("failures", []):
				failures.append("building %d (%s): %s" % [i, String(plan.buildings[i]["kind"]), str(f2)])
			for w2 in rep.get("warnings", []):
				warnings.append("building %d (%s): %s" % [i, String(plan.buildings[i]["kind"]), str(w2)])
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


## The village, drawn: the walk grid with the gates and the trees marked on
## it. A village is the building most in need of being LOOKED at, and this is
## the one call that shows it -- reach for it before theorising about a
## failure, the way `HouseNavCheck.ascii_map` is reached for indoors.
static func ascii_map(plan: VillagePlan) -> String:
	return VillageNavCheck.new().ascii_map(plan)


## What is standing about, drawn: buildings, roads, the common, the trees and
## the props. The dressing's own view, when the question is what is there
## rather than where a person can go.
static func dressing_map(plan: VillagePlan, cols := 78) -> String:
	return VillageDressCheck.ascii_map(plan, cols)


## The family harness for one building of the plan, regenerated from its
## request the way the lot planner measured it.
static func _building_qa(b: Dictionary) -> Dictionary:
	var built: GeneratedBuilding = BigGlade.generate(b["request"])
	if built == null or not built.is_ok():
		return {"failures": ["did not generate"]}
	var request: BuildingRequest = b["request"]
	match request.kind:
		&"house", &"shop", &"hotel":
			var builder := HouseBuilder.new()
			builder.build(built.plan)
			return HouseQA.new().check(built.plan, builder)
		&"castle":
			var cb := CastleBuilder.new()
			cb.build(built.spec)
			return CastleMassingCheck.new().check(built.spec, cb)
		&"temple":
			var tb := TempleBuilder.new()
			tb.build(built.spec)
			return TempleQA.new().check(built.spec, tb)
	return {}
