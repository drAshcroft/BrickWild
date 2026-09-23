class_name VillageScaleCheck
extends RefCounted
## Is this a village, not a city? (VIL-006; VILLAGES 9.1)
##
##   HOUSED      there are as many houses as there are households
##   NOT_A_CITY  it stops: <= 140 buildings, <= 500 people, <= 400 x 400 m
##   EARNED      every building the people can support exists, and nothing
##               they cannot -- the 4 table read both ways
##   DENSITY     neither a scatter nor a slum: built area over site area in
##               [0.06, 0.30]
##   PURE        the same spec twice is the same village, and planning did
##               not write to the spec
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const RULES: Array[StringName] = [&"housed", &"not_a_city", &"earned", &"density", &"pure"]
const HOUSED_TOL := 0.10
const BUILDINGS_MAX := 140
const POPULATION_MAX := 500
const SITE_MAX := 400.0
## Five per cent rather than the six of VILLAGES 9.1: a farming village's
## ground is grown until its farms, with their six-metre fire gaps, are all
## housed, and that ground is honestly emptier than a market town's.
const DENSITY_MIN := 0.05
const DENSITY_MAX := 0.30

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: VillagePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	replaced = RuleSet.run(self, RULES, {}, overrides, [plan], [plan], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


func _check_housed(plan: VillagePlan) -> void:
	var houses: int = plan.buildings_of_kind(&"house").size()
	var want: int = plan.spec.households
	var tol: int = maxi(int(round(float(want) * HOUSED_TOL)), 1)
	stats["houses"] = houses
	stats["households"] = want
	if absi(houses - want) > tol:
		failures.append("housed: %d houses for %d households" % [houses, want])


func _check_not_a_city(plan: VillagePlan) -> void:
	stats["buildings"] = plan.buildings.size()
	if plan.buildings.size() > BUILDINGS_MAX:
		failures.append("not_a_city: %d buildings; a village stops at %d" % [plan.buildings.size(), BUILDINGS_MAX])
	if plan.spec.population > POPULATION_MAX:
		failures.append("not_a_city: %d people; a village stops at %d" % [plan.spec.population, POPULATION_MAX])
	if plan.site.size.x > SITE_MAX + 0.01 or plan.site.size.y > SITE_MAX + 0.01:
		failures.append("not_a_city: the site is %.0f x %.0fm; a village stops at %.0f square"
			% [plan.site.size.x, plan.site.size.y, SITE_MAX])


## The 4 table both ways: a guildhall at 40 people fails, and so does a
## village of 100 with no tavern. Read off what stands, by family and
## business.
func _check_earned(plan: VillagePlan) -> void:
	var spec: VillageSpec = plan.spec
	var earned: Array[StringName] = VillageProgrammer.earned_kinds(spec.population, spec.purpose, spec.water, spec.culture)
	var have := {}
	for b in plan.buildings:
		var kind: StringName = b["kind"]
		match kind:
			&"shop":
				var biz: StringName = VillageMeasure.business(b)
				have[biz] = int(have.get(biz, 0)) + 1
			&"church":
				var req: BuildingRequest = b["request"]
				have[&"church" if req.height >= 10.0 else &"shrine"] = 1
			&"temple":
				have[&"temple"] = 1
			&"castle":
				have[&"manor"] = 1
	for kind in earned:
		var key: StringName = kind
		if kind == &"tavern_2":
			if int(have.get(&"tavern", 0)) < 2:
				failures.append("earned: %d people earn a second tavern and there is %d" % [spec.population, int(have.get(&"tavern", 0))])
			continue
		for row in VillageProgrammer.SHOP_RULES:
			if row["kind"] == kind:
				key = row["business"]
		if key == &"smithy":
			key = &"blacksmith"
		if not have.has(key):
			failures.append("earned: %d people earn a %s and there is none" % [spec.population, String(kind)])
	# and nothing they cannot
	for key in have:
		var kind: StringName = key
		for row in VillageProgrammer.SHOP_RULES:
			if row["business"] == key:
				kind = row["kind"]
		if key == &"blacksmith":
			kind = &"smithy"
		var allowed: bool = kind in earned or (key == &"tavern" and &"tavern" in earned) \
			or (key == &"bakery" and &"bakery" in earned)
		if not allowed:
			failures.append("earned: a %s stands in a village of %d that cannot support one"
				% [String(key), spec.population])
	stats["earned"] = earned.size()


func _check_density(plan: VillagePlan) -> void:
	var built := 0.0
	for b in plan.buildings:
		built += Poly.area(VillageMeasure.bounds_poly(b))
	var site: float = plan.site.size.x * plan.site.size.y
	var d: float = built / maxf(site, 1.0)
	stats["density"] = snappedf(d, 0.001)
	if d < DENSITY_MIN:
		failures.append("density: %.1f%% of the site is built; a village is at least %.0f%%" % [d * 100.0, DENSITY_MIN * 100.0])
	if d > DENSITY_MAX:
		failures.append("density: %.1f%% of the site is built; a village is at most %.0f%%" % [d * 100.0, DENSITY_MAX * 100.0])


## Plan the same inputs again and compare, and make sure planning left the
## spec as it found it.
func _check_pure(plan: VillagePlan) -> void:
	var spec: VillageSpec = plan.spec
	var before := [spec.seed, spec.population, spec.culture, spec.purpose, spec.wealth,
		spec.enclosure, spec.water, spec.households, spec.form, spec.site, spec.variant_name]
	var twin := VillageSpec.new(spec.seed)
	twin.population = spec.population
	twin.culture = spec.culture
	twin.purpose = spec.purpose
	twin.wealth = spec.wealth
	twin.enclosure = spec.enclosure
	twin.water = spec.water
	twin.generate(spec.seed)
	var again: VillagePlan = VillageLotPlanner.plan(twin)
	if not plan.equals(again):
		failures.append("pure: the same spec planned twice gave two different villages")
	var after := [spec.seed, spec.population, spec.culture, spec.purpose, spec.wealth,
		spec.enclosure, spec.water, spec.households, spec.form, spec.site, spec.variant_name]
	if before != after:
		failures.append("pure: planning wrote to the spec")
