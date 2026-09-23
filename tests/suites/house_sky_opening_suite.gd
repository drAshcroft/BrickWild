extends RefCounted
## INT-018: authored compluvia, oculi and court-sky holes are actual roof cuts.
## The fixtures deliberately pass the built shell into the court check: a plan
## can say "sky" while an emitter still roofs the yard with a solid box.

const Probe := preload("res://tests/roof_probe.gd")

class FloatingCourtRoof extends HouseBuilder:
	func component_slab(role: String, points: PackedVector3Array, depth: float,
			surf: int, vertical := true) -> Dictionary:
		var shifted := points.duplicate()
		if role.begins_with("roof_court_"):
			for i in shifted.size():
				shifted[i].y += 0.3
		return super.component_slab(role, shifted, depth, surf, vertical)
	func _log_mass(mass_name: String, aabb: AABB, ground := 0.0) -> void:
		if mass_name.begins_with("roof_court_"):
			aabb.position.y += 0.3
		super._log_mass(mass_name, aabb, ground)

static func run() -> SuiteResult:
	var res := SuiteResult.new("hsky")
	_domus(res)
	_oculus(res)
	return res


static func _domus(res: SuiteResult) -> void:
	var plan: HousePlan = CourtSuite.courtyard(17.0, 15.0, 1818)
	var court := Rect2(plan.courts[0]["rect"])
	var impluvium := Rect2(court.get_center() - Vector2(1.0, 1.0), Vector2(2.0, 2.0))
	plan.roof_openings = [{"id": "atrium_compluvium", "kind": &"compluvium",
		"storey": 0, "room": 0, "rect": court, "impluvium": impluvium}]
	plan.furniture.append({"key": "well", "pos": Vector3(impluvium.get_center().x, 0.0,
		impluvium.get_center().y), "rect": impluvium, "zone": impluvium,
		"host": -1, "mounted": false})
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	res.checked += 1
	var report := CourtCheck.new().check(plan, {"builder": builder})
	for failure in report["failures"]:
		res.fail("domus court: %s" % failure)
	_expect(res, builder.roof_opening_log.size() == 1,
		"domus emits one real roof_opening record")
	_expect(res, builder.part_log.any(func(row: Dictionary) -> bool:
		return row.get("kind", "") == "roof_opening"),
		"domus part_log carries roof_opening evidence")
	var sky_probe := Probe.coverage(mesh, Poly.from_rect(court), 0.0, [], true, 9)
	_expect(res, int(sky_probe["checked"]) > 0 and sky_probe["misses"].is_empty(),
		"domus vertical roof probe reaches sky over the court")
	var water := CourtCheck.new().water(plan)
	for failure in water["failures"]:
		res.fail("domus water: %s" % failure)
	# A roof mass dropped into the court is the negative fixture. It must fail
	# the same built-shell sky rule instead of being forgiven by plan metadata.
	var bad := HouseBuilder.new()
	bad.build(plan)
	bad.mass_log.append({"name": "roof_over_court", "aabb": AABB(
		Vector3(court.get_center().x - 0.8, plan.spec.height, court.get_center().y - 0.8),
		Vector3(1.6, 0.4, 1.6))})
	res.checked += 1
	var bad_report := CourtCheck.new().check(plan, {"builder": bad})
	_expect(res, not bad_report["ok"], "solid roof over court is rejected")
	_expect(res, _has_prefix(bad_report["failures"], "sky:"),
		"solid roof failure is attributed to sky")
	_expect(res, mesh != null, "domus shell builds with roof")
	var floating := FloatingCourtRoof.new()
	var floating_mesh := floating.build(plan)
	_expect(res, ComponentCheck.check(floating, floating_mesh)["ok"],
		"floating court fixture really emits its moved roof components")
	var support_report := CourtCheck.new().check(plan, {"builder": floating})
	_expect(res, _has_prefix(support_report["failures"], "roof_support:"),
		"actual court roof lifted clear of its bearing is rejected")


static func _oculus(res: SuiteResult) -> void:
	var spec := HouseSpec.new(1919)
	spec.width = 10.0
	spec.length = 14.0
	spec.height = 2.8
	spec.storeys = 1
	spec.room_count = 1
	spec.program = [&"hall"]
	spec.roof_type = &"gable"
	spec.roof_pitch = 1.0
	spec.chimney = false
	spec.porch = false
	spec.dormers = false
	var plan := HousePlanner.plan(spec)
	plan.roof_openings = [{"id": "hall_oculus", "kind": &"oculus",
		"storey": 0, "room": 0, "rect": Rect2(-1.2, -1.2, 2.4, 2.4)}]
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var report := RoofOpeningCheck.check(plan, builder, mesh)
	res.checked += 1
	for failure in report["failures"]:
		res.fail("oculus: %s" % failure)
	_expect(res, report["authored"] == 1, "oculus is counted as an authored opening")
	_expect(res, builder.roof_opening_log.size() == 1,
		"oculus emits one real roof_opening record")
	var opening: PackedVector2Array = HouseGeometry.roof_openings(plan)[0]["polygon"]
	var sky_probe := Probe.coverage(mesh, opening, 0.0, [], true, 9)
	_expect(res, int(sky_probe["checked"]) > 0 and sky_probe["misses"].is_empty(),
		"oculus vertical roof probe reaches sky (misses=%d)" % sky_probe["misses"].size())
	_expect(res, builder.components("roof_face_").size() > 2,
		"oculus subtraction leaves multiple roof pieces")
	# Build the same plan without the opening, then author it after emission.
	# This is the painted-on-solid negative: the metadata exists, but a ray
	# through the opening still hits the uncut roof and RoofOpeningCheck reports
	# the host face covering it.
	var bad_plan := HousePlanner.plan(spec)
	var bad_builder := HouseBuilder.new()
	var bad_mesh := bad_builder.build(bad_plan)
	bad_plan.roof_openings = plan.roof_openings.duplicate(true)
	var bad_report := RoofOpeningCheck.check(bad_plan, bad_builder, bad_mesh)
	_expect(res, not bad_report["ok"], "uncut authored oculus is rejected")
	var bad_probe := Probe.coverage(bad_mesh, opening, 0.0, [], true, 9)
	_expect(res, not bad_probe["misses"].is_empty(), "uncut oculus fails vertical sky probe")
	_expect(res, mesh.get_surface_count() >= 3, "oculus mesh retains wall/roof/floor surfaces")


static func _has_prefix(values: Array, prefix: String) -> bool:
	for value in values:
		if String(value).begins_with(prefix):
			return true
	return false


static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
