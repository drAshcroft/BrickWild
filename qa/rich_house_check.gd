class_name RichHouseCheck
extends RefCounted
## What makes a RICH house rich, measured over what the builder actually
## emitted (HOUSE-RICH).
##
## A rich house is an ordinary house plan with its storeys articulated: a crown
## at the wall head, a belt band at each storey line, a pediment over the upper
## windows, an obelisk on the ridge. Every one of those is a NAMED COMPONENT in
## `MassBuilder.component_log`, which is the same evidence exterior QA already
## re-emits against the mesh (`qa/component_check.gd`), so a piece that is
## logged but never built fails here for exactly the reason it fails there.
##
## The rule that matters most is `density`. Without it "rich" is a word: a
## cottage with its height turned up passes every other rule in this file and
## is still a cottage. The floor is deliberately low -- three ornament
## components per storey -- because the point is not to make the check
## impossible to satisfy, it is to make STRETCHING distinguishable from
## BUILDING.
##
## report = {"ok": bool, "failures": [...], "warnings": [...], "stats": {...}}

## The named rules, in the order they run. A family that is a correct rich
## building and breaks one replaces it through `overrides` rather than
## switching it off (RuleSet, INT-020).
const RULES: Array[StringName] = [&"storeys", &"cornice", &"bands", &"pediment",
	&"crown", &"density", &"bounds"]

## The component roles the vocabulary is built from. Kept here rather than in
## the builder so the check names what it looks for in one place, and the suite
## can require that every one of them is exercised by at least one fixture.
const CORNICE_ROLES := [&"cornice_bed", &"cornice_corona", &"cornice_crown"]
const BAND_ROLE := &"string_course"
const PEDIMENT_ROLES := [&"pediment_cornice", &"pediment_face", &"pediment_rake"]
const CROWN_ROLES := [&"ridge_crown_plinth", &"ridge_crown"]

## Three ornament components per storey. A stretched cottage scores zero.
const MIN_TRIM_PER_STOREY := 3

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(plan: HousePlan, builder: HouseBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["style"] = String(plan.spec.style)
	stats["storeys"] = int(plan.spec.storeys)
	RuleSet.run(self, RULES, {}, overrides, [plan, builder], [plan, builder],
		failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


## Every component the rich vocabulary emitted, whatever host it sits on.
func _ornament(builder: HouseBuilder) -> Array[Dictionary]:
	var roles: Array = []
	roles.append_array(CORNICE_ROLES)
	roles.append_array([BAND_ROLE])
	roles.append_array(PEDIMENT_ROLES)
	roles.append_array(CROWN_ROLES)
	var out: Array[Dictionary] = []
	for role in roles:
		out.append_array(builder.components(String(role)))
	return out


# ----------------------------------------------------------------- the rules

## A rich house is banded STOREYS, and a single storey has no band to read.
## The style row asks for a floor (HouseSpec's "min_storeys") rather than the
## generator inventing one, so this measures a promise the spec already made.
func _check_storeys(plan: HousePlan, _builder: HouseBuilder) -> void:
	var spec := plan.spec
	if int(spec.storeys) < 2:
		failures.append("storeys: a rich house has %d storey; a single storey has no band to read"
			% int(spec.storeys))
	for level in range(int(spec.storeys)):
		if plan.rooms_on_storey(level).is_empty():
			failures.append("storeys: storey %d has no rooms" % level)


## The crown at the wall head, in three steps, on EVERY elevation of the top
## storey. A crown on three of four walls is a crown with a hole in it, so the
## count is compared with the run count the plan itself reports rather than
## with a literal four.
func _check_cornice(plan: HousePlan, builder: HouseBuilder) -> void:
	if not plan.spec.cornice:
		return          # the spec asked for no crown; `density` carries the class
	var runs: int = HouseGeometry.shell_runs(plan, maxi(int(plan.spec.storeys) - 1, 0)).size()
	for role in CORNICE_ROLES:
		var rows := builder.components(String(role))
		if rows.size() != runs:
			failures.append("cornice: %s emitted %d times for %d elevations"
				% [String(role), rows.size(), runs])
	stats["cornice"] = builder.components("cornice_bed").size()


## A belt band at each storey line the spec asked for, broken only where an
## opening comes through. Every band host must carry a row on every elevation,
## for the same reason the crown does.
func _check_bands(plan: HousePlan, builder: HouseBuilder) -> void:
	var wanted: int = mini(int(plan.spec.string_courses), maxi(int(plan.spec.storeys) - 1, 0))
	if wanted <= 0:
		warnings.append("bands: this house was generated without a single string course")
		return
	var found := 0
	for level in range(int(plan.spec.storeys)):
		var rows := builder.components_of("band_%d" % level)
		if rows.is_empty():
			continue
		found += 1
		var runs: int = HouseGeometry.shell_runs(plan, level).size()
		if rows.size() < runs:
			failures.append("bands: band_%d covers %d of %d elevations"
				% [level, rows.size(), runs])
	if found < wanted:
		failures.append("bands: the spec asks for %d string courses, %d were emitted"
			% [wanted, found])
	stats["bands"] = found


## A pediment over every upper window that has room for one. Windows whose head
## sits too near the wall head for a pediment are legitimately skipped by the
## emitter, so the rule counts the windows it COULD have dressed rather than
## every window on the floor.
func _check_pediment(plan: HousePlan, builder: HouseBuilder) -> void:
	if not plan.spec.pediments:
		return          # likewise: none asked for, none owed
	var dressable := 0
	for win in plan.windows:
		var level := HousePlan.record_storey(win)
		if level < 1:
			continue
		var base: float = float(level) * plan.spec.height + float(win["head"])
		if minf(HouseGeometry.PEDIMENT_RISE,
			plan.spec.height * float(level + 1) - base - 0.12) < HouseGeometry.PEDIMENT_MIN_RISE:
			continue
		dressable += 1
	for role in PEDIMENT_ROLES:
		var rows := builder.components(String(role))
		if dressable > 0 and rows.is_empty():
			failures.append("pediment: %s was never emitted although %d windows take one"
				% [String(role), dressable])
	if dressable > 0 and builder.components("pediment_face").size() != dressable:
		failures.append("pediment: %d tympana for %d dressable windows"
			% [builder.components("pediment_face").size(), dressable])
	stats["pediments"] = builder.components("pediment_face").size()


## The obelisk, when the spec asked for one. It is emitted only where the roof
## has a ridge to stand on, and HouseGeometry.ridge_half() is the same number
## the bound used, so both sides skip it together.
func _check_crown(plan: HousePlan, builder: HouseBuilder) -> void:
	if not plan.spec.ridge_finial:
		return
	if HouseGeometry.ridge_half(plan.spec) <= 0.05:
		return
	for role in CROWN_ROLES:
		if builder.components(String(role)).is_empty():
			failures.append("crown: %s was never emitted although the spec asks for a ridge crown"
				% String(role))


## THE rule that makes the word mean something. A rich house carries at least
## three ornament components per storey. A plain house relabelled rich, or a
## cottage stretched upward, scores nothing here and fails.
func _check_density(plan: HousePlan, builder: HouseBuilder) -> void:
	var trim: int = _ornament(builder).size()
	var need: int = MIN_TRIM_PER_STOREY * maxi(int(plan.spec.storeys), 1)
	stats["trim"] = trim
	stats["trim_needed"] = need
	if trim < need:
		failures.append("density: %d ornament components for %d storeys; a rich house needs %d"
			% [trim, maxi(int(plan.spec.storeys), 1), need])


## The crown reaches past the wall face and the crown stands above the ridge, so
## the planned exterior has to say so. HouseQA already asserts containment; this
## rule restates it for the rich vocabulary and additionally requires the bound
## to be no looser than the tolerance every other house is held to, which is
## what stops a generous CORNICE_OUT from quietly inflating every camera pull
## back and every lot test.
func _check_bounds(plan: HousePlan, builder: HouseBuilder) -> void:
	if builder.emitted_mesh == null:
		failures.append("bounds: the builder emitted no mesh")
		return
	var planned: AABB = HouseGeometry.exterior_bounds(plan)
	var actual: AABB = builder.emitted_mesh.get_aabb()
	if not planned.grow(0.025).encloses(actual):
		failures.append("bounds: the ornament leaves the planned exterior (tolerance=0.025m)")
	for axis in range(3):
		var lo: float = actual.position[axis] - planned.position[axis]
		var hi: float = planned.end[axis] - actual.end[axis]
		if lo > HouseGeometry.BOUNDS_TOL or hi > HouseGeometry.BOUNDS_TOL:
			failures.append("bounds: the planned bound is %.3fm loose on axis %d"
				% [maxf(lo, hi), axis])
	if plan.spec.ridge_finial and HouseGeometry.ridge_half(plan.spec) > 0.05:
		var promised: float = HouseGeometry.total_height(plan.spec)
		if absf(promised - actual.end.y) > 0.0005:
			failures.append("bounds: total_height %.4f but the crown tops out at %.4f"
				% [promised, actual.end.y])