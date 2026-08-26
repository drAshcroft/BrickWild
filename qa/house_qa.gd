class_name HouseQA
extends RefCounted
## The whole house harness in one call: the plan, the furnishing, the walking,
## and the shell the mesh actually came out as.
##
## The four are deliberately separate modules -- a plan can be sound and its
## furnishing nonsense, and the failure should say which -- but nothing outside
## qa/ should have to know that, so this runs them all and merges the reports.
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

## Shell masses are all joined by design: a partition dies into the exterior
## wall, the floor slab carries everything. So the shell only gets the two
## structural rules that can still fail -- nothing floating, nothing hovering.
const SHELL_CARRIED: Array = []


func check(plan: HousePlan, builder: HouseBuilder) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}

	for part in [
		HousePlanCheck.new().check(plan),
		HouseFurnishCheck.new().check(plan),
		HouseNavCheck.new().check(plan),
	]:
		for f in part["failures"]:
			failures.append(str(f))
		for w in part["warnings"]:
			warnings.append(str(w))
		for k in part["stats"]:
			stats[k] = part["stats"][k]

	if builder != null:
		for f2 in _check_shell(plan, builder):
			failures.append(f2)
		stats["masses"] = builder.mass_log.size()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


## The shell: every mass stands on the ground and touches the rest of the
## house. The floor slab is the anchor, because everything is built on it.
static func _check_shell(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var masses: Array[Dictionary] = builder.mass_log
	if masses.is_empty():
		out.append("shell: the builder logged no structural masses")
		return out
	var gaps: Dictionary = MassRules.gaps(masses, "floor")
	for f in gaps["failures"]:
		out.append(str(f))
	for g in MassRules.grounded(masses, SHELL_CARRIED):
		out.append(str(g))
	# and the rooms the mesh was built from must be the rooms the plan claims
	var wall_masses := 0
	for m in masses:
		if (m["name"] as String).begins_with("wall_") \
				or (m["name"] as String).begins_with("partition_"):
			wall_masses += 1
	if wall_masses < 4:
		out.append("shell: only %d wall masses -- a house has four sides" % wall_masses)
	return out
