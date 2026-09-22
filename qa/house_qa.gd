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
# A pitched roof is carried by the wall plates even in a one-storey house.
const SHELL_CARRIED: Array = ["roof"]


## `overrides` lets a family replace a rule of the plan or furnishing check
## by name (RuleSet, INT-020); the report says which under "replaced".
func check(plan: HousePlan, builder: HouseBuilder, overrides: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}
	# which rule belongs to which section of the report; the parts that name
	# their groups (the furnishing check does) hand them up unchanged
	var groups := {}
	var replaced := {}
	failures.append_array(HouseExterior.check(plan))
	for bad in RuleSet.unknown(overrides, [HousePlanCheck.RULES, HouseFurnishCheck.RULES]):
		failures.append("rules: no house rule is called %s" % bad)

	for part in [
		HousePlanCheck.new().check(plan, overrides),
		HouseFurnishCheck.new().check(plan, overrides),
		HouseNavCheck.new().check(plan),
	]:
		for f in part["failures"]:
			failures.append(str(f))
		for w in part["warnings"]:
			warnings.append(str(w))
		for k in part["stats"]:
			stats[k] = part["stats"][k]
		for g in part.get("groups", {}):
			groups[g] = part["groups"][g]
		for r in part.get("replaced", {}):
			replaced[r] = part["replaced"][r]

	if builder != null:
		for f2 in _check_shell(plan, builder):
			failures.append(f2)
		for f3 in _check_vertical_shell(plan, builder):
			failures.append(f3)
		for f4 in _check_opening_elevations(plan, builder):
			failures.append(f4)
		stats["masses"] = builder.mass_log.size()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "groups": groups, "replaced": replaced}


## The shell: every mass stands on the ground and touches the rest of the
## house. The floor slab is the anchor, because everything is built on it.
static func _check_shell(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var masses: Array[Dictionary] = builder.mass_log
	if masses.is_empty():
		out.append("shell: the builder logged no structural masses")
		return out
	# the ground floor slab, or its first piece when a stair down to a cellar
	# has cut a hole in it (INT-016)
	var anchor := ""
	for m0 in masses:
		var nm0: String = m0["name"]
		if nm0 == "floor" or nm0 == "floor_0":
			anchor = nm0
			break
		if anchor == "" and nm0.begins_with("floor_0"):
			anchor = nm0
	if anchor == "":
		anchor = "floor"
	var gaps: Dictionary = MassRules.gaps(masses, anchor)
	for f in gaps["failures"]:
		out.append(str(f))
	var carried: Array = SHELL_CARRIED.duplicate()
	# Ground-floor plans retain the original strict grounding rule. Upper
	# storeys are intentionally carried by the walls/floors below; gaps() still
	# requires every one to join the structural assembly. Every mass carries
	# its own ground level (a cellar's is a storey down, INT-016), so the
	# per-storey masses are measured against that rather than exempted.
	if int(plan.spec.storeys) > 1:
		carried += ["roof", "stair_"]
		for m in masses:
			var nm: String = m["name"]
			if (nm.begins_with("floor_") or nm.begins_with("wall_") or nm.begins_with("partition_")) \
					and not m.has("ground"):
				carried.append(nm)
	for g in MassRules.grounded(masses, carried):
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


## Structural vertical contract. Builders may keep the legacy `floor` name for
## level zero or use `floor_0`; upper levels must be represented explicitly.
## Roofs are required for multi-storey builds and must start at the top wall
## band, which catches a roof accidentally left at the first storey.
static func _check_vertical_shell(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var wanted: int = clampi(int(plan.spec.storeys), 1, HouseGeometry.MAX_STOREYS)
	var lowest := 0
	if plan.spec.has_method("lowest_storey"):
		lowest = int(plan.spec.lowest_storey())
	var floor_names := {}
	var roofs: Array[AABB] = []
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm == "floor" or nm.begins_with("floor_"):
			floor_names[nm] = true
		if nm.begins_with("roof"):
			roofs.append(m["aabb"])
	for level in range(lowest, wanted):
		var ground_slab := floor_names.has("floor") or floor_names.has("floor_0")
		for floor_name0 in floor_names:
			if String(floor_name0).begins_with("floor_0"):
				ground_slab = true
		if level == 0 and ground_slab:
			continue
		if level != 0:
			var prefix := "floor_%d" % level
			var found_level := false
			for floor_name in floor_names:
				if String(floor_name).begins_with(prefix):
					found_level = true
					break
			if found_level:
				continue
		if wanted > 1 or lowest < 0:
			out.append("shell: missing floor mass for storey %d" % level)
	if roofs.is_empty():
		out.append("shell: house has no logged roof mass")
	elif roofs.size() > 1 and plan.world_family != &"courtyard_house":
		out.append("shell: %d main roof masses logged; expected exactly one" % roofs.size())
	var top_wall: float = float(wanted) * plan.spec.height
	if not roofs.is_empty():
		var roof_top := -INF
		var roof_bottom := INF
		for roof in roofs:
			roof_top = maxf(roof_top, (roof as AABB).end.y)
			roof_bottom = minf(roof_bottom, (roof as AABB).position.y)
		var expected_bottom := top_wall
		if plan.world_family == &"courtyard_house":
			# The shallow courtyard ring meets the wall head at its inner eave;
			# only slab depth extends below that support line.
			expected_bottom = top_wall - 0.12
		if absf(roof_bottom - expected_bottom) > 0.15:
			out.append("shell: roof begins at Y %.2f, expected wall band %.2f" % [roof_bottom, expected_bottom])
	return out


## The plan check validates a window's relative sill/head. This companion check
## ties the emitted `window` records back to the actual storey Y offset, so a
## builder cannot cut every upper window at ground level.
static func _check_opening_elevations(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	for wi in range(plan.windows.size()):
		var win: Dictionary = plan.windows[wi]
		var room: int = int(win.get("room", -1))
		if room < 0 or room >= plan.room_count():
			continue
		var level := HousePlan.record_storey(win)
		var expected: float = float(level) * plan.spec.height \
			+ (float(win["sill"]) + float(win["head"])) / 2.0
		var found := false
		for part in builder.part_log:
			if part["kind"] != "window":
				continue
			var pp: Vector3 = part["pos"]
			var wp: Vector2 = win["pos"]
			# Plan openings sit on the interior wall face while trim is logged on
			# the wall centreline, so their plan-space separation is half a wall.
			if Vector2(pp.x, pp.z).distance_to(wp) < HouseGeometry.wall_thickness(plan.spec) / 2.0 + 0.04 \
					and absf(pp.y - expected) < 0.06:
				found = true
				break
		if not found:
			out.append("opening: window %d has no emitted trim at storey %d elevation %.2f" % [wi, level, expected])
	return out
