extends RefCounted
## HOUSE-EXT-007: dormer openings, cheek joins, and the reasons a candidate
## was turned away.
##
## Three things have to hold. The hole is really cut, so no host slope runs
## behind the glazing. The cheeks sit on the slope they close against. And the
## count nobody can explain does not exist: every rejected candidate says why.

const Faulty := preload("res://tests/fixtures/faulty_house_builder.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("house roof openings")
	_variants(res)
	_rejection_reasons(res)
	_mutations(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _spec(w: float, l: float, kind: StringName, pitch: float,
		storeys := 2, count := 3) -> HouseSpec:
	var s := HouseSpec.new()
	s.width = w
	s.length = l
	s.height = 2.7
	s.storeys = storeys
	s.roof_type = kind
	s.roof_pitch = pitch
	s.room_count = 1
	s.program = [&"hall"]
	s.dormers = count > 0
	s.dormer_count = count
	s.chimney = false
	s.porch = false
	s.timber_frame = false
	s.bargeboards = false
	return s


## Gable, half-hip and hip; rotated footprints; low and high pitch; zero, one
## and several dormers; and roof-off, which must take the dormers with it.
static func _variants(res: SuiteResult) -> void:
	var saw_dormers := false
	for kind in [&"gable", &"half_hipped", &"hipped"]:
		for size in [Vector2(9, 14), Vector2(14, 9), Vector2(11, 11)]:
			for pitch in [0.55, 1.5]:
				for count in [0, 1, 3]:
					var s := _spec(size.x, size.y, kind, pitch, 2, count)
					var plan := HousePlanner.plan(s)
					var builder := HouseBuilder.new()
					var mesh := builder.build(plan)
					var who := "%s %s pitch=%.2f n=%d" % [kind, size, pitch, count]
					var report := RoofOpeningCheck.check(plan, builder, mesh)
					_expect(res, bool(report["ok"]),
						"%s: %s" % [who, ", ".join(report["failures"])])
					# The opening check ties the plan to the component log.
					# ComponentCheck ties that log to the emitted mesh. Both
					# together are what "the count agrees end to end" means.
					var backed := ComponentCheck.check(builder, mesh)
					_expect(res, bool(backed["ok"]),
						"%s: components not backed by the mesh: %s"
							% [who, ", ".join(backed["failures"])])
					if int(report["openings"]) > 0:
						saw_dormers = true
					if count == 0:
						_expect(res, int(report["openings"]) == 0,
							"%s: dormers appeared with none requested" % who)
					# Rotating the footprint must not change what fits.
					var rotated := HousePlanner.plan(
						_spec(size.y, size.x, kind, pitch, 2, count))
					_expect(res,
						HouseGeometry.roof_openings(rotated).size() == int(report["openings"]),
						"%s: rotating the footprint changed the dormer count" % who)

					# Roof off takes the dormers with it, coherently.
					var cut := HouseBuilder.new()
					var cut_mesh := cut.build(plan, false)
					_expect(res, _dormer_hosts(cut).is_empty(),
						"%s: cutaway kept dormer components" % who)
					_expect(res, bool(RoofOpeningCheck.check(plan, cut, cut_mesh)["ok"])
							or int(report["openings"]) > 0,
						"%s: cutaway is internally inconsistent" % who)
	_expect(res, saw_dormers, "no variant in the sweep fitted a single dormer")


## Every rejection is inspectable, and the reasons are the real ones.
static func _rejection_reasons(res: SuiteResult) -> void:
	# A pitch this shallow cannot carry a dormer face at all.
	var flat := _spec(9, 14, &"gable", 0.12, 2, 3)
	var flat_plan := HousePlanner.plan(flat)
	var flat_reasons := _reasons(flat_plan)
	_expect(res, HouseGeometry.roof_openings(flat_plan).is_empty(),
		"a 0.12 pitch still produced dormers")
	_expect(res, flat_reasons.has("no_seat"),
		"a pitch too shallow for a dormer gave no reason; got %s" % str(flat_reasons))

	# A chimney standing where a dormer wants to be is a named reason.
	var stack := _spec(9, 14, &"gable", 1.0, 2, 3)
	stack.chimney = true
	var stack_plan := HousePlanner.plan(stack)
	var stack_reasons := _reasons(stack_plan)
	for r in stack_reasons:
		_expect(res, r in ["off_face", "near_edge", "chimney", "no_seat"],
			"unknown dormer rejection reason '%s'" % r)
	for row in HouseGeometry.roof_opening_rejections(stack_plan):
		_expect(res, not String(row["detail"]).is_empty(),
			"rejection %s carries no detail" % row["reason"])

	# A near-square HIP leaves no room for the outer dormers: their footprints
	# run off the face or onto the hip line, and both are named reasons rather
	# than a count that quietly shrank.
	for pitch in [0.55, 1.0, 1.5]:
		var hip := _spec(11, 11, &"hipped", pitch, 2, 3)
		var hip_plan := HousePlanner.plan(hip)
		var hip_reasons := _reasons(hip_plan)
		_expect(res, HouseGeometry.roof_openings(hip_plan).size() < 3,
			"hip pitch %.2f fitted every dormer on a near-square roof" % pitch)
		_expect(res, hip_reasons.has("off_face") or hip_reasons.has("near_edge"),
			"hip pitch %.2f dropped dormers without saying they left the face; got %s"
				% [pitch, str(hip_reasons)])

	# A court is sky, and says so rather than silently fitting nothing. The
	# plan is plain data, so a fixture may state the court directly.
	var court_plan := HousePlanner.plan(_spec(18, 18, &"gable", 1.0, 2, 3))
	court_plan.courts.append({"rect": Rect2(-3, -3, 6, 6), "storey": 0})
	_expect(res, court_plan.has_court(), "court fixture did not take")
	_expect(res, _reasons(court_plan).has("court"),
		"a courtyard house gave no reason for having no dormers")
	_expect(res, HouseGeometry.roof_openings(court_plan).is_empty(),
		"a courtyard house fitted dormers anyway")

	# And the accepted count agrees with the component log and the plan view.
	var ok := _spec(9, 14, &"gable", 1.0, 2, 3)
	var ok_plan := HousePlanner.plan(ok)
	var ok_builder := HouseBuilder.new()
	ok_builder.build(ok_plan)
	_expect(res, _dormer_hosts(ok_builder).size()
			== HouseGeometry.roof_openings(ok_plan).size(),
		"plan openings and emitted dormer components disagree")


static func _reasons(plan: HousePlan) -> PackedStringArray:
	var out := PackedStringArray()
	for row in HouseGeometry.roof_opening_rejections(plan):
		var r := String(row["reason"])
		if not out.has(r):
			out.append(r)
	return out


static func _dormer_hosts(builder: HouseBuilder) -> PackedStringArray:
	var out := PackedStringArray()
	for c in builder.component_log:
		var h: String = c["host"]
		if h.begins_with("dormer") and not out.has(h):
			out.append(h)
	return out


## The negative half: break one thing at a time and require the check to say so.
static func _mutations(res: SuiteResult) -> void:
	var s := _spec(9, 14, &"gable", 1.0, 2, 3)
	var plan := HousePlanner.plan(s)
	var control := HouseBuilder.new()
	var control_mesh := control.build(plan)
	_expect(res, bool(RoofOpeningCheck.check(plan, control, control_mesh)["ok"]),
		"mutation control already fails its own opening check")
	_expect(res, HouseGeometry.roof_openings(plan).size() > 0,
		"mutation control fitted no dormers to break")

	# 1. Shift a cheek off the host slope. The dormer still stands, the hole is
	#    still cut, and there is now a slot of daylight down one side.
	for role in ["dormer_0_cheek", "dormer_1_cheek"]:
		var bent = Faulty.new()
		# DISPLACE, not MOVE: the builder must genuinely believe the cheek is
		# there, or this only re-tests what ComponentCheck already covers.
		bent.fault = Faulty.Fault.DISPLACE
		bent.fault_role = role
		bent.move_by = Vector3(0.0, 0.35, 0.0)
		var bent_mesh: ArrayMesh = bent.build(plan)
		if _dormer_hosts(bent).is_empty():
			continue
		var report := RoofOpeningCheck.check(plan, bent, bent_mesh)
		_expect(res, not bool(report["ok"]),
			"%s lifted off the slope and the cheek rule said nothing" % role)
		break

	# 2. Slide a cheek along the ridge until it is past the hip line and over
	#    the end face. The fitter refuses to place a dormer there; this proves
	#    the geometry rule would catch it even if the fitter did not.
	#
	#    Measured on this fixture: the side face still carries the cheek at
	#    5.5 m (its plane depends only on cross-slope position, so sliding
	#    ALONG the ridge is legitimately harmless), it straddles the hip at
	#    7.0 m, and it is clear of every face by 8.5 m. Use the unambiguous
	#    one, not the boundary.
	var hip := _spec(9, 14, &"hipped", 1.0, 2, 3)
	var hip_plan := HousePlanner.plan(hip)
	if HouseGeometry.roof_openings(hip_plan).size() > 0:
		var onto_hip = Faulty.new()
		onto_hip.fault = Faulty.Fault.DISPLACE
		onto_hip.fault_role = "dormer_0_cheek"
		onto_hip.move_by = Vector3(0.0, 0.0, 8.5)
		var hip_mesh: ArrayMesh = onto_hip.build(hip_plan)
		_expect(res, not bool(RoofOpeningCheck.check(hip_plan, onto_hip, hip_mesh)["ok"]),
			"a cheek slid onto the hip face and the cheek rule said nothing")

	# 3. Bury the glazing: leave the host face uncut by dropping the emitted
	#    face and re-emitting it whole. A painted-on dormer must fail.
	var buried := HouseBuilder.new()
	var buried_mesh := buried.build(plan)
	var layout := HouseGeometry.roof_layout(plan)
	var whole := _uncut_builder(plan, layout)
	var buried_report := RoofOpeningCheck.check(plan, whole, buried_mesh)
	_expect(res, not bool(buried_report["ok"]),
		"an uncut host face left the glazing buried and nothing complained")


## A builder whose main roof faces were never cut for their dormers, with the
## dormers themselves still emitted: the "painted window on a solid roof" case.
static func _uncut_builder(plan: HousePlan, layout: Dictionary) -> HouseBuilder:
	var b := HouseBuilder.new()
	b.build(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	for i in range(b.component_log.size()):
		var row: Dictionary = b.component_log[i]
		if not String(row["role"]).begins_with("roof_face_"):
			continue
		var fi := int(String(row["role"]).substr(10))
		if fi >= faces.size():
			continue
		var world := PackedVector3Array()
		for p in faces[fi]:
			world.append(xf * p)
		row["points"] = world      # the whole face, hole and all
	return b
