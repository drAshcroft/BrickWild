extends RefCounted
## Focused pure-plan contract for the motte shell keep.

const CastleInteriors = preload("res://src/castle/castle_interiors.gd")

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle motte plan")
	for scale in [0.5, 1.0, 1.5]:
		_scale_contract(res, float(scale))
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 90.0
	spec.length = 110.0
	spec.height = 12.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8806)
	var plan := CastleMottePlan.generate(spec)
	_expect(res, plan.spec != null, "motte fixture produced no plan")
	if plan.spec == null:
		return res
	_expect(res, not plan.has_court(), "shell keep centre was incorrectly represented as a court")
	_expect(res, plan.rooms.size() == CastleMottePlan.levels(spec), "wrong occupied storey count")
	_expect(res, CastleMottePlan.origin(spec).y == spec.motte_height, "plan origin is not on mound top")
	_expect(res, String(plan.exterior[0].id) == "keep_shell", "stable keep_shell intent missing")
	var good := CastleMottePlan.validate(plan)
	_expect(res, bool(good["ok"]), "valid shell plan rejected: " + str(good["failures"]))
	_expect(res, not plan.doors.is_empty(), "climb-side shell door missing")
	if not plan.doors.is_empty():
		var door: Dictionary = plan.doors[0]
		var facet := false
		for wall in HouseGeometry.room_walls(plan, 0):
			if (-Vector2(wall["normal"])).dot(Vector2(door["normal"])) > 0.999 \
					and _point_on_segment(Vector2(door["pos"]), Vector2(wall["from"]), Vector2(wall["to"])):
				facet = true
		_expect(res, facet, "shell door is not on its exact front facet")
	_expect(res, not plan.windows.is_empty(), "ellipse-surface windows missing")
	for window in plan.windows:
		var level := int(window["storey"])
		var edge := int(window["edge"])
		var walls := HouseGeometry.room_walls(plan, level)
		_expect(res, edge >= 0 and edge < walls.size(),
			"window edge index is not a real polygon wall")
		if edge >= 0 and edge < walls.size():
			_expect(res, Vector2(window["normal"]) == -Vector2(walls[edge]["normal"]),
				"window normal does not match its exact outward wall facet")
	_expect(res, plan.stairs.size() == plan.rooms.size() - 1, "stair chain does not join every storey")
	for i in range(plan.stairs.size() - 1):
		_expect(res, not Rect2(plan.stairs[i]["upper_rect"]).intersects(
			Rect2(plan.stairs[i + 1]["lower_rect"]), true),
			"adjacent shell stair flights overlap at storey %d" % (i + 1))

	var rectangular := CastleMottePlan.generate(spec)
	var box := Poly.bounding_rect(rectangular.outline_of(0))
	rectangular.rooms[0].outline = Poly.from_rect(box)
	var bad_rect := CastleMottePlan.validate(rectangular)
	_expect(res, not bad_rect["ok"], "AABB/rectangular substitution escaped validation")

	var off_surface := CastleMottePlan.generate(spec)
	off_surface.windows[0].pos += Vector2(4.0, 0.0)
	var bad_window := CastleMottePlan.validate(off_surface)
	_expect(res, not bad_window["ok"], "off-surface window escaped validation")

	var bad_landing := CastleMottePlan.generate(spec)
	bad_landing.stairs[0].upper_rect = Rect2(100.0, 100.0, 2.0, 2.0)
	var bad_stair := CastleMottePlan.validate(bad_landing)
	_expect(res, not bad_stair["ok"], "invalid stair landing escaped validation")
	return res


## Canonical small/default/large coverage exercises pure planning and the real
## HouseBuilder emission without making the focused suite depend on the
## furnisher's search cost at very large scales.
static func _scale_contract(res: SuiteResult, scale: float) -> void:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 90.0 * scale
	spec.length = 110.0 * scale
	spec.height = 12.0 * scale
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8806 + int(scale * 100.0))
	var plan := CastleMottePlan.generate(spec, false)
	var keep := CastleGeometry.shell_keep_aabb(spec)
	var row: Dictionary = CastleInteriors.record("keep_shell", plan, keep)
	_expect(res, plan.spec != null, "scale %.1f produced no shell plan" % scale)
	if plan.spec == null:
		return
	_expect(res, row.bounds == keep, "scale %.1f keep_shell bounds drifted" % scale)
	_expect(res, is_equal_approx(float(row.transform.origin.y), spec.motte_height),
		"scale %.1f keep_shell transform is not on mound top" % scale)
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	CastleInteriors.emit(builder, row)
	var doors: Array = builder.part_log.filter(func(part: Dictionary) -> bool:
		return String(part.get("opening_kind", "")) == "door" \
			and String(part.get("tag", "")) == "keep_shell")
	_expect(res, doors.size() == 1, "scale %.1f shell emission lacks one planned door" % scale)


static func _point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	var edge := b - a
	var t := clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + edge * t) <= 0.001


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
