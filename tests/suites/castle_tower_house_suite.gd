extends RefCounted
## Production integration checks for tower-house raised doors and slit windows.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle tower house openings")
	for row in [
		{"name": "Bologna 8803", "w": 8.0, "l": 8.0, "h": 45.0, "seed": 8803},
		{"name": "Scottish 8804", "w": 14.0, "l": 12.0, "h": 34.0, "seed": 8804},
	]:
		var spec := CastleSpec.new()
		spec.style = &"norman"
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.plan_override = &"tower_house"
		CastleGenerator.generate(spec, int(row.seed))
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var who: String = row.name
		NormalsSuite.check_mesh(res, mesh, who)
		NormalsSuite.check_openings(res, builder, who)
		var doors: Array = builder.part_log.filter(func(p: Dictionary) -> bool:
			return String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "door")
		_expect(res, doors.size() == 1, who + ": expected one emitted planned entrance")
		var door_sill := -INF
		if not doors.is_empty():
			var door: Dictionary = doors[0]
			door_sill = (door.pos as Vector3).y - (door.size as Vector3).y * 0.5
		_expect(res, door_sill >= 2.0, who + ": entrance sill is below the raised-entry limit")
		var tower := TowerCheck.new().check(spec, builder)
		_expect(res, tower.ok, who + ": TowerCheck failed: " + "; ".join(tower.failures))
		var windows: Array = builder.part_log.filter(func(p: Dictionary) -> bool:
			return String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "window")
		var planned := CastleTowerPlan.generate(spec, false)
		_expect(res, windows.size() == planned.windows.size(),
			who + ": emitted window count differs from the actual tower plan")
		_expect(res, windows.all(func(p: Dictionary) -> bool:
			return bool(p.get("planned_opening", false))),
			who + ": an emitted tower-house window has no planned opening record")
		for storey in range(1, spec.tower_storeys):
			var low := storey * CastleGeometry.tower_storey_height(spec)
			var high := low + CastleGeometry.tower_storey_height(spec)
			var found := false
			for window in windows:
				var p: Vector3 = window.pos
				var h := float(window.size.y)
				var sill := p.y - h * 0.5
				if sill >= low - 0.05 and sill + h <= high + 0.05:
					found = true
					break
			_expect(res, found, who + ": occupied storey %d has no emitted window inside its height band" % storey)
		var massing := CastleMassingCheck.new().check(spec, builder)
		var facade_failures: Array = massing.failures.filter(func(message: String) -> bool:
			return message.begins_with("facade: tower_house occupied storey"))
		_expect(res, facade_failures.is_empty(), who + ": facade check failed: " + "; ".join(facade_failures))
		# Negative control: the production facade rule must reject the same builder
		# when its actual tower-house window records are removed.
		var original_parts := builder.part_log
		builder.part_log = original_parts.filter(func(p: Dictionary) -> bool:
			return not (String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "window"))
		var negative := CastleMassingCheck.new().check(spec, builder)
		var caught: bool = negative.failures.any(func(message: String) -> bool:
			return message.begins_with("facade: tower_house occupied storey"))
		_expect(res, caught, who + ": missing-window negative control was not caught")
		builder.part_log = original_parts
		builder.part_log = original_parts.filter(func(p: Dictionary) -> bool:
			return not (String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "door"))
		var missing_door := TowerCheck.new().check(spec, builder)
		_expect(res, not missing_door.ok, who + ": missing-door negative control was not caught")
		builder.part_log = original_parts
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
