extends RefCounted
## WITCH-SIZE: a hut is small. A witch_hut request is clamped to 7 x 9 m and one
## storey, plans at most three rooms, and is furnished and walkable. The frozen
## fixture is 3 seeds x 2 sizes plus one oversize request as the clamp control.

const FIXTURE := "res://tests/fixtures/personality/witch_requests.json"
const SEEDS := [1, 8102, 21325]

static func run() -> SuiteResult:
	var res := SuiteResult.new("Witch hut is small")
	var rows := _cases()
	var huts := 0
	var controls := 0
	var awning_control_done := false
	for row in rows:
		var role := String(row.get("role", ""))
		if role != "witch" and role != "clamp_control":
			continue
		var q: Dictionary = row["request"]
		var who := String(row["id"])
		var request := BuildingRequest.house(int(q["seed"]), &"witch_hut", &"none",
			float(q["width"]), float(q["length"]), float(q["height"]), int(q["storeys"]))
		var generated: GeneratedBuilding = BrickWild.generate(request)
		_expect(res, generated.is_ok() and generated.plan != null,
			"%s: public generation failed: %s" % [who, JSON.stringify(generated.errors)])
		if not generated.is_ok() or generated.plan == null:
			continue
		var plan: HousePlan = generated.plan
		var spec: HouseSpec = plan.spec
		var long_side := maxf(spec.width, spec.length)
		var short_side := minf(spec.width, spec.length)
		_expect(res, long_side <= HouseGenerator.WITCH_MAX_LONG + 0.001
			and short_side <= HouseGenerator.WITCH_MAX_SHORT + 0.001 and spec.storeys == 1,
			"%s: hut is %.2f x %.2f m, %d storeys" % [who, spec.width, spec.length, spec.storeys])
		_expect(res, plan.room_count() <= 3,
			"%s: %d rooms (max 3)" % [who, plan.room_count()])
		# WITCH-REVIEW-FOLLOWUPS 4: the work shelter's roof stops at the thatch edge
		var awning: Dictionary = WitchAwningCheck.check(plan)
		_expect(res, bool(awning["ok"]) and int(awning["checked"]) <= 2,
			"%s: the work shelter roof runs into the thatch at %d samples (worst %.3f m)" % [who,
			awning["intrusions"].size(), _worst(awning)])
		if not awning_control_done and int(awning["checked"]) > 0:
			awning_control_done = true
			# control: hang the same roof from the wall again and the check must fire
			for piece in plan.yard_pieces:
				if String(piece.get("kind", "")) != "witch_work_lean_to":
					continue
				var edge := float(piece["work_clearance"]["thatch_edge"])
				_expect(res, edge > 0.3, "%s: no thatch edge recorded on the shelter" % who)
				for part in piece["parts"]:
					if String(part["role"]).ends_with("_roof"):
						var back := Vector3(piece["work_clearance"]["out"].x, 0.0,
							piece["work_clearance"]["out"].y)
						part["centre"] -= back * edge * 0.5
						part["size"] += Vector3(0.0, 0.0, edge) if absf(back.z) > 0.5 else Vector3(edge, 0.0, 0.0)
			_expect(res, not bool(WitchAwningCheck.check(plan)["ok"]),
				"%s: a shelter roof hung from the wall passed the awning check" % who)
		# WITCH-THATCH-FORM: round eaves and verges, a saddle ridge, brushed ends
		var thatch_builder := HouseBuilder.new()
		thatch_builder.build(plan)
		var form: Dictionary = ThatchFormCheck.check(thatch_builder,
			not HouseGeometry.uses_witch_half_hip_roof(plan.spec, plan.world_family))
		_expect(res, bool(form["ok"]), "%s: thatch form: %s" % [who, "; ".join(form["failures"])])
		if role == "clamp_control":
			controls += 1
			_expect(res, is_equal_approx(spec.width, 7.0) and is_equal_approx(spec.length, 9.0),
				"%s: oversize 17 x 18 came out %.2f x %.2f, not 7 x 9" % [who, spec.width, spec.length])
			continue
		huts += 1
		# an in-bound request is unchanged
		_expect(res, is_equal_approx(spec.width, float(q["width"]))
			and is_equal_approx(spec.length, float(q["length"])),
			"%s: in-bound request moved to %.2f x %.2f" % [who, spec.width, spec.length])
		var nav: Dictionary = HouseNavCheck.new().check(plan)
		_expect(res, bool(nav.get("ok", false)), "%s: nav failed: %s" % [who, JSON.stringify(nav)])
		var furnish: Dictionary = HouseFurnishCheck.new().check(plan)
		_expect(res, bool(furnish.get("ok", false)),
			"%s: HouseFurnishCheck failed: %s" % [who, JSON.stringify(furnish.get("failures", []))])
	_expect(res, huts == 6 and controls == 1,
		"fixture must hold 6 huts and 1 clamp control; found %d and %d" % [huts, controls])
	# the style programme itself is at most three rooms
	var program: Array = HouseSpec.STYLES[&"witch_hut"]["domestic_program"]
	_expect(res, program.size() <= 3, "witch_hut domestic_program has %d rooms" % program.size())
	# a trade hut is clamped too
	var trade := BrickWild.generate(BuildingRequest.house(21118, &"witch_hut", &"alchemist",
		17.0, 18.0, 2.8, 2))
	if trade.is_ok() and trade.plan != null:
		_expect(res, trade.plan.room_count() <= 3 and trade.plan.spec.storeys == 1
			and maxf(trade.plan.spec.width, trade.plan.spec.length) <= 9.001,
			"alchemist hut not clamped: %d rooms, %.1f x %.1f" % [trade.plan.room_count(),
			trade.plan.spec.width, trade.plan.spec.length])
	# thatch form controls: the old five-point hump and tent must fail, and so must
	# a roof with no rolled verge or brushed end (a plain thatched cottage here)
	var hump := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.1, 0.17, 0),
		Vector3(0.22, 0.34, 0), Vector3(0.34, 0.17, 0), Vector3(0.45, 0, 0)])
	_expect(res, ThatchFormCheck.max_turn_deg(hump) > ThatchFormCheck.MAX_TURN_DEG,
		"control: the old five-point eave hump passed as round")
	var tent := PackedVector3Array([Vector3(-0.22, 0.0, 0), Vector3(-0.1, 0.2, 0),
		Vector3(0, 0.3, 0), Vector3(0.1, 0.2, 0), Vector3(0.22, 0.0, 0)])
	_expect(res, ThatchFormCheck.crown_turn_deg(tent) > ThatchFormCheck.MAX_TURN_DEG,
		"control: a tent-peaked ridge roll passed as a saddle")
	var plain := BrickWild.generate(BuildingRequest.house(8102, &"thatch_cottage", &"none", 7.0, 9.0, 2.8, 1))
	if plain.is_ok() and plain.plan != null:
		var plain_builder := HouseBuilder.new()
		plain_builder.build(plain.plan)
		_expect(res, not bool(ThatchFormCheck.check(plain_builder)["ok"]),
			"control: a thatched cottage with no verge roll or brushed end passed the thatch form check")
	# negative control: another style is not clamped
	var cottage := BrickWild.generate(BuildingRequest.house(8102, &"cottage", &"none", 17.0, 18.0, 2.8, 2))
	_expect(res, cottage.is_ok() and cottage.plan != null and cottage.plan.spec.width > 9.0,
		"clamp leaked to a cottage")
	res.note("huts=%d clamp controls=%d" % [huts, controls])
	return res

static func _worst(awning: Dictionary) -> float:
	var worst := 0.0
	for row in awning["intrusions"]:
		worst = maxf(worst, float(row["inside"]))
	return worst

static func _cases() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	return parsed["cases"] if parsed is Dictionary else []

static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
