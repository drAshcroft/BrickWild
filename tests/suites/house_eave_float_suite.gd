extends RefCounted
## HOUSE-EAVE-FLOAT: every rafter tail, viga and ashlar touches the building.
##
## The 26 Oct bug walk found blocks hovering at the eave of a witch hut (tails
## 4.6 cm under a deepened eave), of a cottage bakery (tails 9 mm under the
## slab), and round the parapet-less top of an african shop (a style with pitch
## 0 emitted tails and a NaN ridge and no roof at all). ComponentCheck could
## not see any of them: log and mesh agreed, the parts were simply in the air.
## ComponentContactCheck removes a part's own triangles and asks what else is
## within a few millimetres.

const Faulty := preload("res://tests/fixtures/faulty_house_builder.gd")

## The three reopen commands of the walk, then ordinary and Sahel/Pueblo cases.
const CASES := [
	{"kind": "house", "seed": 1, "style": &"witch_hut", "purpose": &"none", "w": 9.0, "l": 12.0},
	{"kind": "shop", "seed": 1, "style": &"cottage", "purpose": &"bakery", "w": 11.0, "l": 14.0},
	{"kind": "shop", "seed": 1, "style": &"african", "purpose": &"apothecary", "w": 11.0, "l": 14.0},
	{"kind": "shop", "seed": 1, "style": &"pueblo", "purpose": &"apothecary", "w": 11.0, "l": 14.0},
	{"kind": "house", "seed": 8102, "style": &"witch_hut", "purpose": &"none", "w": 7.0, "l": 9.0},
	{"kind": "house", "seed": 21325, "style": &"witch_hut", "purpose": &"alchemist", "w": 7.0, "l": 9.0},
	{"kind": "house", "seed": 4412, "style": &"cottage", "purpose": &"none", "w": 7.0, "l": 9.0},
	{"kind": "house", "seed": 4413, "style": &"farmhouse", "purpose": &"none", "w": 10.0, "l": 13.0},
	{"kind": "house", "seed": 4, "style": &"african", "purpose": &"none", "w": 10.0, "l": 12.0},
	{"kind": "house", "seed": 5, "style": &"pueblo", "purpose": &"none", "w": 10.0, "l": 12.0},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("house eave float")
	for c in CASES:
		_case(res, c)
	_control_displaced_tail(res)
	_control_levelled_roof(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _plan(c: Dictionary) -> HousePlan:
	var req: BuildingRequest
	if c["kind"] == "shop":
		req = BuildingRequest.shop(int(c["seed"]), c["purpose"], c["style"],
			float(c["w"]), float(c["l"]))
	else:
		req = BuildingRequest.house(int(c["seed"]), c["style"], c["purpose"],
			float(c["w"]), float(c["l"]))
	var made := BrickWild.generate(req)
	return made.plan if made.is_ok() else null


static func _case(res: SuiteResult, c: Dictionary) -> void:
	var who := "%s %s seed %d" % [c["kind"], c["style"], int(c["seed"])]
	var plan := _plan(c)
	if plan == null:
		_expect(res, false, "%s did not generate" % who)
		return
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var report := ComponentContactCheck.check(builder, mesh)
	_expect(res, bool(report["ok"]), "%s: %s" % [who, "; ".join(report["failures"])])
	_expect(res, ComponentContactCheck.non_finite_triangles(mesh) == 0,
		"%s emitted NaN vertices" % who)


## The check has to be able to fail: a tail built 0.5 m under its eave and
## honestly logged there is a block in the air.
static func _control_displaced_tail(res: SuiteResult) -> void:
	var plan := _plan(CASES[1])
	var faulty := Faulty.new()
	faulty.fault = Faulty.Fault.DISPLACE
	faulty.fault_role = "eave_tail"
	faulty.fault_index = 3
	faulty.move_by = Vector3(0.0, -0.5, 0.0)
	var mesh := faulty.build(plan)
	var report := ComponentContactCheck.check(faulty, mesh)
	_expect(res, not bool(report["ok"]) and (report["floating"] as Array).size() == 1,
		"control: a tail hung 0.5 m below its eave was not caught (%d floating)"
			% (report["floating"] as Array).size())


## The african shop bug: a gable roof at pitch 0 has no faces, so the roof
## descriptor is empty and a tail row would stand in the air round the walls.
static func _control_levelled_roof(res: SuiteResult) -> void:
	var plan := _plan(CASES[1])
	plan.spec.roof_pitch = 0.0
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var tails := builder.components("eave_tail")
	_expect(res, mesh != null and tails.is_empty(),
		"control: a roof at pitch 0 emitted %d tails in the air" % tails.size())
