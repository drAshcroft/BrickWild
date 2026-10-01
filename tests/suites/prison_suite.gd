class_name PrisonSuite
extends RefCounted
## Measured prison plan, locked cell doors, sealed hatch, and scaled footprints.

static func run() -> SuiteResult:
	var result := SuiteResult.new("prison")
	for scale in [0.7, 1.0, 1.4]:
		var spec := ShopSpec.new()
		spec.business = &"prison"
		spec.style = &"longhall"
		spec.width = 15.8 * scale
		spec.length = 22.0 * scale
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 61000 + int(scale * 100))
		var who := "prison scale %.2f" % scale
		var builder := HouseBuilder.new()
		builder.build(plan)
		var hatch_panels := 0
		for component in builder.component_log:
			if String(component.get("role", "")) == "trapdoor_panel":
				hatch_panels += 1
		if hatch_panels != 1:
			result.fail("%s emitted %d closed trapdoor panels, expected one" % [who, hatch_panels])
		result.checked += 1
		if not plan.has_kind(&"guardroom") or not plan.has_kind(&"corridor"):
			result.fail("%s lacks a guardroom or corridor" % who)
		var cells := _rooms(plan, &"cell")
		if cells.size() < 3:
			result.fail("%s has %d locked cells, needs at least three" % [who, cells.size()])
		for cell in cells:
			var f: Rect2 = HouseGeometry.room_floor_rect(plan, cell)
			if minf(f.size.x, f.size.y) < 2.0 or maxf(f.size.x, f.size.y) > 3.0:
				result.fail("%s cell %d measures %.2f x %.2f m" % [who, cell, f.size.x, f.size.y])
			var doors := 0
			for door in plan.doors:
				if int(door.get("a", -1)) == cell or int(door.get("b", -1)) == cell:
					doors += 1
					if not bool(door.get("locked", false)):
						result.fail("%s cell %d has an unlocked door" % [who, cell])
			if doors != 1:
				result.fail("%s cell %d has %d doors, expected one" % [who, cell, doors])
			if not _has_cell_cage(plan, cell):
				result.fail("%s cell %d lacks its measured cage" % [who, cell])
		if not plan.trapdoors.size() == 1 or not plan.rooms[plan.trapdoors[0].get("lower_room", -1)].get("sealed", false):
			result.fail("%s has no single sealed oubliette trapdoor" % who)
		var report := HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			result.fail("%s: %s" % [who, failure])
		for warning in report["warnings"]:
			result.warn("%s: %s" % [who, warning])
		if is_equal_approx(scale, 1.0):
			_negative_controls(result, plan)
	_dead_band_widths(result)
	return result


## Inner widths that the original fixed-aisle search could not tile
## (8.0-8.9, 10.7-12.6, 15.3-16.3, 19.8-20.0 m). The library accepts every one
## of them, so each must still yield a guardroom, corridors and three cells.
static func _dead_band_widths(result: SuiteResult) -> void:
	# pure layout: every width the library can offer, tiled exactly
	var w := 6.0
	while w <= 22.0:
		var inner := Rect2(Vector2.ZERO, Vector2(w, 16.0))
		var layout := ShopSpec.new().prison_layout(inner)
		result.checked += 1
		if layout.is_empty() or (layout["cells"] as Array).size() < 3:
			result.fail("prison inner width %.1f m yields no cell block" % w)
		else:
			var area := 0.0
			for r in [layout["guard"]] + layout["aisles"] + layout["cells"]:
				area += (r as Rect2).get_area()
				if not inner.grow(0.001).encloses(r):
					result.fail("prison inner width %.1f m has a room outside the footprint" % w)
			if absf(area - inner.get_area()) > 0.01:
				result.fail("prison inner width %.1f m leaves %.2f m2 untiled" % [w, inner.get_area() - area])
			for c in layout["cells"]:
				if (c as Rect2).size.x < 2.24 or (c as Rect2).size.x > 3.01:
					result.fail("prison inner width %.1f m has a %.2f m wide cell" % [w, (c as Rect2).size.x])
		w += 0.1
	# whole plans, one width from each dead band
	for inner_w in [8.5, 11.3, 15.8, 19.9]:
		var spec := ShopSpec.new()
		spec.business = &"prison"
		spec.style = &"longhall"
		spec.width = inner_w + 0.7
		spec.length = 16.0
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 62000 + int(inner_w * 10.0))
		var who := "prison inner width %.1f" % inner_w
		result.checked += 1
		if not plan.has_kind(&"guardroom") or not plan.has_kind(&"corridor"):
			result.fail("%s lacks a guardroom or corridor" % who)
		result.checked += 1
		if _rooms(plan, &"cell").size() < 3:
			result.fail("%s has %d cells, needs at least three" % [who, _rooms(plan, &"cell").size()])
		var builder := HouseBuilder.new()
		builder.build(plan)
		var report := HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			result.fail("%s: %s" % [who, failure])


static func _rooms(plan: HousePlan, kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) == 0 and plan.kind_of(i) == kind:
			out.append(i)
	return out


static func _has_cell_cage(plan: HousePlan, room: int) -> bool:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) == "cage":
			return true
	return false


static func _negative_controls(result: SuiteResult, source: HousePlan) -> void:
	var source_report := HousePlanCheck.new().check(source)
	if not source_report["ok"]:
		result.fail("unmutated prison plan fails HousePlanCheck")
		return
	var unlocked := _copy_plan(source)
	for door in unlocked.doors:
		if bool(door.get("locked", false)):
			door["locked"] = false
			break
	result.checked += 1
	if HousePlanCheck.new().check(unlocked)["ok"]:
		result.fail("unlocking a cell door was not detected")
	var missing_hatch := _copy_plan(source)
	missing_hatch.trapdoors.clear()
	result.checked += 1
	if HousePlanCheck.new().check(missing_hatch)["ok"]:
		result.fail("removing the trapdoor was not detected")
	var unsealed := _copy_plan(source)
	var oubliette := int(unsealed.trapdoors[0]["lower_room"])
	unsealed.rooms[oubliette]["sealed"] = false
	result.checked += 1
	if HousePlanCheck.new().check(unsealed)["ok"]:
		result.fail("unsealing the oubliette was not detected")
	var empty_cell := _copy_plan(source)
	var cell := _rooms(empty_cell, &"cell")[0]
	for i in range(empty_cell.furniture.size() - 1, -1, -1):
		if int(empty_cell.furniture[i].get("room", -1)) == cell and PropCatalog.category(empty_cell.furniture[i]["key"]) == "cage":
			empty_cell.furniture.remove_at(i)
	result.checked += 1
	if HouseFurnishCheck.new().check(empty_cell)["ok"]:
		result.fail("removing a cell cage was not detected")


static func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	for property in source.get_property_list():
		var key := StringName(property["name"])
		if key == &"script":
			continue
		var value: Variant = source.get(key)
		if value is Array or value is Dictionary:
			value = value.duplicate(true)
		copy.set(key, value)
	return copy
