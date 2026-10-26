extends RefCounted
## LIVE-SACRED: the processional sequence over a frozen matrix of public
## requests (tests/fixtures/sacred_sequence_requests.json, notes in
## docs/SACRED_REVIEW.md).
##
## For every request, generated through BrickWild.generate like a consumer's:
## the way in reaches the focus (altar, idol) along the axis, the focus is
## visible from the entry, and there is a congregation zone. Then, for each
## style/form, two NEGATIVE CONTROLS that must fail: an obstruction that hides
## the focus, and one that breaks the axis. A check that cannot fail on those
## is not checking.

const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"
const Seq = preload("res://qa/sacred_sequence_check.gd")
## Rules of the rite that are the sequence; the rest of the ten are judged by `rite`.
const SEQUENCE := ["axis", "sightline", "procession", "approach", "congregation"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("sacred sequence")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MATRIX))
	if not parsed is Dictionary:
		res.fail("matrix %s did not parse" % MATRIX)
		return res
	var controlled := {}
	var pinned := 0
	for c in parsed["cases"]:
		var req := BuildingRequest.from_dict(c["request"])
		var built := BrickWild.generate(req)
		res.checked += 1
		if not built.is_ok():
			res.fail("%s: generate failed %s" % [c["id"], str(built.errors)])
			continue
		var key := "%s/%s" % [c["family"], c["style"]]
		var control: bool = not controlled.has(key) and c["size"] == "default"
		if c["family"] == "church":
			_church(res, c, built, control)
		else:
			_temple(res, c, req, built, control)
		if control:
			controlled[key] = true
		if c.get("pinned", false):
			pinned += 1
	res.checked += 1
	if pinned != 1:
		res.fail("the matrix must carry exactly one pinned barn-like basilica; found %d" % pinned)
	res.note("%d requests, %d style/form negative-control pairs" % [parsed["cases"].size(), controlled.size()])
	return res


# ------------------------------------------------------------------- church

static func _church(res: SuiteResult, c: Dictionary, built, control: bool) -> void:
	var spec := built.spec as ChurchSpec
	var builder := ChurchBuilder.new()
	builder.build(spec)
	var rep: Dictionary = Seq.check(spec, builder)
	for f in rep["failures"]:
		res.fail("%s: %s" % [c["id"], f])
	if rep["ok"]:
		res.note("%-34s %s" % [c["id"], str(rep["stats"])])
	if not control:
		return
	var id: String = c["id"]
	# 1. a screen across the aisle hides the altar
	var mid: float = 0.0
	var screen := [{"name": "control_screen", "aabb": AABB(
		Vector3(-1.0, 0.0, mid), Vector3(2.0, spec.height, 0.3))}]
	_must_fail(res, id + " [screen hides altar]", Seq.check(spec, builder, [], screen), "sightline")
	# 2. a row of pews across the whole nave breaks the walk to the altar
	var wall: Array = builder.prop_log.duplicate()
	wall.append({"key": "Bench", "pos": Vector3(0, 0, mid), "scale": 1.0, "kind": &"pew",
		"rect": Rect2(-spec.width / 2.0, mid, spec.width, 0.5), "yaw": 0.0})
	_must_fail(res, id + " [pews wall the aisle]", Seq.check(spec, builder, wall), "procession")
	# 3. an altar off the centre line breaks the axis
	var shifted: Array = []
	for p in builder.prop_log:
		var q: Dictionary = p.duplicate()
		if q["kind"] == &"altar":
			q["rect"] = Rect2((q["rect"] as Rect2).position + Vector2(1.5, 0.0), (q["rect"] as Rect2).size)
			q["pos"] = (q["pos"] as Vector3) + Vector3(1.5, 0.0, 0.0)
		shifted.append(q)
	_must_fail(res, id + " [altar off axis]", Seq.check(spec, builder, shifted), "axis")


# ------------------------------------------------------------------- temple

static func _temple(res: SuiteResult, c: Dictionary, req: BuildingRequest, built,
		control: bool) -> void:
	var spec := built.spec as TempleSpec
	var builder := TempleBuilder.new()
	builder.build(spec)
	var rep: Dictionary = TempleRiteCheck.new().check(spec, builder)
	for f in rep["failures"]:
		var rule: String = String(f).split(":")[0]
		if rule in SEQUENCE:
			res.fail("%s: %s" % [c["id"], f])
		else:
			res.warn("%s: %s (judged by `rite`)" % [c["id"], f])
	var stats: Dictionary = rep["stats"]
	if c.get("pinned", false):
		res.note("pinned barn-like basilica: %s" % str(stats))
	if not control:
		return
	var id: String = c["id"]
	# 1. a veil across the axis between the eye and the god
	var eye: Vector2 = TempleGeometry.sight_point(spec)
	var idol: Vector3 = TempleGeometry.idol_center(spec)
	var mid: float = (eye.y + idol.z) / 2.0
	var hidden := TempleBuilder.new()
	hidden.build(spec)
	hidden.mass_log.append({"name": "control_veil", "aabb": AABB(
		Vector3(-1.5, 0.0, mid), Vector3(3.0, 80.0, 0.3))})
	_must_fail(res, id + " [veil hides idol]", TempleRiteCheck.new().check(spec, hidden), "sightline")
	# 1b. SACRED-ZIGGURAT-FOCUS: a ziggurat's stair and terraces are no longer
	# exempt from the sightline, so a stair wall raised across the axis must fail
	if spec.form == &"ziggurat":
		var walled_stair := TempleBuilder.new()
		walled_stair.build(spec)
		var summit: Rect2 = TempleGeometry.terrace_rect(spec, spec.terraces - 1)
		walled_stair.mass_log.append({"name": "stair_wall_control", "aabb": AABB(
			Vector3(-1.5, 0.0, (eye.y + summit.position.y) / 2.0),
			Vector3(3.0, TempleGeometry.terrace_top(spec) + 4.0, 0.3))})
		_must_fail(res, id + " [stair wall hides idol]",
			TempleRiteCheck.new().check(spec, walled_stair), "sightline")
	# 2. a file of columns shoulder to shoulder across the hall breaks the walk
	if spec.form != &"rotunda":
		var fresh := BrickWild.generate(req).spec as TempleSpec
		var hall: Rect2 = TempleGeometry.hall_rect(fresh)
		var z: float = (TempleGeometry.entry_point(fresh).y + TempleGeometry.altar_center(fresh).z) / 2.0
		var x: float = hall.position.x
		while x <= hall.end.x:
			fresh.columns.append({"pos": Vector3(x, 0.0, z), "radius": 0.5,
				"height": 3.0, "ring": 9})
			x += 0.9
		var walled := TempleBuilder.new()
		walled.build(fresh)
		_must_fail(res, id + " [columns wall the axis]",
			TempleRiteCheck.new().check(fresh, walled), "procession")


static func _must_fail(res: SuiteResult, label: String, rep: Dictionary, rule: String) -> void:
	res.checked += 1
	if rep["ok"]:
		res.fail("%s: negative control PASSED; the check cannot see this fault" % label)
		return
	for f in rep["failures"]:
		if String(f).begins_with(rule):
			return
	res.fail("%s: failed, but not on `%s`: %s" % [label, rule, str(rep["failures"])])
