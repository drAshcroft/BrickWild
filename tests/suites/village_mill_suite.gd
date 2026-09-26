extends RefCounted
## Real shop measurement, bank/race fitting and emitted wheel, without
## repeatedly furnishing unrelated households during the 50-seed water matrix.

class DammedRace extends VillageBuilder:
	func _mill_culvert(a: Vector2, b: Vector2, _index: int, _kind: StringName) -> void:
		var mid := (a + b) * 0.5
		var run := b - a
		component_box("faulty_race_dam", Vector3(run.length(), 1.0, WALL_THICK),
			Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, 0.5, mid.y)), SURF_STONE)

class DammedShore extends VillageBuilder:
	func _enclosure(plan: VillagePlan) -> void:
		super._enclosure(plan)
		# Actual masonry across the river mouth, regardless of its valid plan.
		box(Vector3(4.0, 1.0, WALL_THICK), Vector3(0, 0.5, -8), SURF_STONE)

static func run(full := false) -> SuiteResult:
	var res := SuiteResult.new("village mill")
	_shore_controls(res)
	var request := BuildingRequest.shop(18550, &"bakery", &"farmhouse", 11.0, 14.0, 2.8, 1)
	var jobs := VillageLotPlanner.measure_all([request])
	_expect(res, jobs.size() == 1, "working bakery request did not generate")
	if jobs.is_empty():
		return res
	var count := 50 if full else 3
	for enclosure in [&"hedge", &"palisade", &"wall"]:
		for water in [&"pond", &"stream", &"river", &"coast"]:
			for seed_index in count:
				var s := VillageSpec.new(18500 + seed_index)
				s.population = 150 if enclosure == &"wall" else 50
				s.purpose = &"mill"
				s.culture = &"english"
				s.enclosure = enclosure
				s.water = water
				s.wealth = 0.4
				s.generate(s.seed)
				var p := VillageSitePlanner.plan(s)
				var label := "%s/%s seed=%d" % [enclosure, water, s.seed]
				var requests := VillageProgrammer.programme(s)
				_expect(res, requests.any(func(r: BuildingRequest) -> bool:
					return r.kind == &"shop" and r.purpose == &"bakery"), label + " missing earned mill")
				var unplaced := VillageLotPlanner.cut_measured(p, jobs)
				for attempt in VillageLotPlanner.RETRIES:
					if unplaced == 0:
						break
					p = VillageSitePlanner.plan(s, int(attempt[0]), float(attempt[1]))
					unplaced = VillageLotPlanner.cut_measured(p, jobs)
				_expect(res, unplaced == 0, label + " cannot place measured mill")
				if unplaced > 0:
					continue
				# Complete the production post-cut phase before dressing: the
				# planted hedge needs its persistent boundary, and final crossings
				# must include the mill race and any added service lane.
				p.water_crossings = VillageWaterPlan.crossings(p.water, p.roads)
				VillageEnclosurePlan.author(p)
				VillageDresser.dress(p)
				var places := VillagePlaceCheck.new()
				places._check_mill(p)
				_expect(res, places.failures.is_empty(), label + ": " + "; ".join(places.failures))
				var lots := VillageLotCheck.new()
				lots._check_tiling(p)
				lots._check_fit(p)
				lots._check_setback(p)
				_expect(res, lots.failures.is_empty(), label + ": " + "; ".join(lots.failures))
				var dress := VillageDressCheck.new()
				for rule in [&"host", &"doorways", &"road", &"edge"]:
					dress.call("_check_" + String(rule), p)
				_expect(res, dress.failures.is_empty(), label + ": " + "; ".join(dress.failures))
				var builder := VillageBuilder.new()
				var mesh := builder.build(p)
				var flow := VillagePlaceCheck.check_water_flow(p, mesh)
				_expect(res, flow.is_empty(), label + ": " + "; ".join(flow))
				var wheels: Array = builder.mass_log.filter(func(row: Dictionary) -> bool:
					return String(row["name"]).begins_with("mill_wheel"))
				_expect(res, wheels.size() == 1 and mesh != null, label + " missing emitted wheel")
				if wheels.size() == 1:
					var box: AABB = wheels[0]["aabb"]
					_expect(res, box.end.y > 2.4 and box.end.y < 2.8 and box.position.y < 0.0 and box.position.y > -0.5,
						label + " wheel does not dip its paddles into water")
				if seed_index == 0:
					_mutations(res, p, label)
					var broken := DammedRace.new()
					var broken_mesh := broken.build(p)
					# A race entirely inside the enclosure needs no culvert. Only
					# claim a negative fixture when it actually emitted a dam.
					if not broken.components("faulty_race_dam").is_empty():
						_expect(res, not VillagePlaceCheck.check_mill_flow(p, broken_mesh).is_empty(), label + " emitted race dam escaped")
	return res


static func _shore_controls(res: SuiteResult) -> void:
	for enclosure in [&"hedge", &"palisade", &"wall"]:
		var spec := VillageSpec.new(18590)
		spec.enclosure = enclosure
		var plan := VillagePlan.new(spec)
		plan.site = Rect2(-10, -10, 20, 20)
		plan.enclosure = Poly.from_rect(Rect2(-8, -8, 16, 16))
		plan.water.append({"kind": &"river", "poly": Poly.from_rect(Rect2(-2, -11, 4, 22))})
		var builder := VillageBuilder.new()
		_expect(res, VillagePlaceCheck.check_water_flow(plan, builder.build(plan)).is_empty(),
			"shore control: " + String(enclosure) + " dams natural water")
		var faulty := DammedShore.new()
		_expect(res, not VillagePlaceCheck.check_water_flow(plan, faulty.build(plan)).is_empty(),
			"shore control: " + String(enclosure) + " emitted dam escaped")


static func _mutations(res: SuiteResult, plan: VillagePlan, label: String) -> void:
	var race: Dictionary = plan.water.back()
	var original: PackedVector2Array = race["poly"]
	race["poly"] = Poly.from_rect(Rect2(-1, -1, 2, 2))
	var check := VillagePlaceCheck.new()
	check._check_mill(plan)
	_expect(res, not check.failures.is_empty(), label + " disconnected race escaped")
	race["poly"] = original
	var wheel: Dictionary = plan.props.filter(func(p: Dictionary) -> bool: return p["key"] == "mill_wheel")[0]
	var at: Vector2 = wheel["pos"]
	wheel["pos"] = at + Vector2(20, 20)
	check.failures.clear()
	check._check_mill(plan)
	_expect(res, "\n".join(check.failures).contains("wheel"), label + " displaced actual wheel escaped")
	wheel["pos"] = at
	wheel["elevation"] = 0.0
	check.failures.clear()
	check._check_mill(plan)
	_expect(res, "\n".join(check.failures).contains("axle"), label + " buried wheel escaped")
	wheel["elevation"] = 1.15
	var yaw: float = wheel["yaw"]
	wheel["yaw"] = yaw + PI * 0.5
	check.failures.clear()
	check._check_mill(plan)
	_expect(res, "\n".join(check.failures).contains("axle does not enter"), label + " unconnected axle escaped")
	wheel["yaw"] = yaw
	var b: Dictionary = plan.buildings[int(wheel["host"])]
	var opening: Dictionary = b["placement"]["mill_openings"][0]
	var p: Vector2 = opening["pos"]
	var n: Vector2 = opening["normal"]
	var xf: Transform3D = b["transform"]
	var bad_pos := xf * Vector3(p.x + n.x * 1.0, 0, p.y + n.y * 1.0)
	wheel["pos"] = Vector2(bad_pos.x, bad_pos.z)
	check.failures.clear()
	check._check_mill(plan)
	_expect(res, "\n".join(check.failures).contains("blocks a facade opening"), label + " wheel across glazing escaped")
	wheel["pos"] = at


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
