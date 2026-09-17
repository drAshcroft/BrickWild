extends RefCounted
## HOUSE-EXT-005: the exterior component log, measured against the mesh.
##
## Three things have to be true for the log to be worth anything downstream:
## it names every piece QA needs, it names the same piece the same way on every
## rebuild, and it is EVIDENCE -- a claim it makes that the mesh does not back
## up has to fail. The last one is what the faulty-builder fixture is for.

const Faulty := preload("res://tests/fixtures/faulty_house_builder.gd")

## The roles the exterior checks downstream (HOUSE-EXT-007/008/009/010) need to
## be able to find by name. Verges and opening trim are in here because that is
## exactly what the old part_log could not see.
const WANTED_ROLES := ["roof_face_", "roof_wall", "verge_board", "eave_tail",
	"opening_jamb", "opening_head"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("house components")
	_fixtures(res)
	_roof_off(res)
	_faults(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


## The four runbook fixtures, plus a forced gable with everything switched on
## so the verge and dormer roles are certain to be exercised.
static func _specs() -> Array:
	var out: Array = []
	for row in [[&"farmhouse", 4413, 10.0, 13.0, 2.7, 1],
			[&"townhouse", 4411, 9.0, 12.0, 2.7, 2],
			[&"cottage", 4412, 7.0, 9.0, 2.5, 1],
			[&"longhall", 4414, 12.0, 16.0, 2.7, 1]]:
		var s := HouseSpec.new()
		s.style = row[0]
		s.width = row[2]
		s.length = row[3]
		s.height = row[4]
		s.storeys = row[5]
		out.append(["%s seed=%s" % [row[0], row[1]],
			HouseGenerator.generate(s, row[1], false)])
	var dressed := HouseSpec.new()
	dressed.width = 9.0
	dressed.length = 14.0
	dressed.height = 2.7
	dressed.storeys = 2
	dressed.room_count = 1
	dressed.program = [&"hall"]
	dressed.roof_type = &"gable"
	dressed.roof_pitch = 0.9
	dressed.dormers = true
	dressed.dormer_count = 2
	dressed.bargeboards = true
	dressed.timber_frame = true
	dressed.porch = true
	out.append(["forced gable dressed", HousePlanner.plan(dressed)])
	return out


static func _fixtures(res: SuiteResult) -> void:
	var seen_roles := {}
	for row in _specs():
		var who: String = row[0]
		var plan: HousePlan = row[1]
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		var report := ComponentCheck.check(builder, mesh)
		_expect(res, bool(report["ok"]),
			"%s component log not backed by the mesh: %s" % [who,
				", ".join(report["failures"])])
		_expect(res, int(report["checked"]) > 0,
			"%s logged no measurable exterior components" % who)
		for c in builder.component_log:
			seen_roles[c["role"]] = true
			_expect(res, not String(c["host"]).is_empty(),
				"%s component %s has no host" % [who, c["id"]])

		# Same plan, same names. An identity that shifts between builds cannot
		# be used to say "dormer_1 moved".
		var first := ComponentCheck.identities(builder)
		builder.build(plan)
		_expect(res, first == ComponentCheck.identities(builder),
			"%s component identities changed on rebuild" % who)
		var ids := {}
		var duplicated := false
		for key in first:
			if ids.has(key):
				duplicated = true
			ids[key] = true
		_expect(res, not duplicated, "%s emitted two components with one identity" % who)

		# The porch has a roof and is not the roof (HOUSE-EXT-005 guardrail).
		var main_faces := 0
		for c in builder.components(ComponentCheck.MAIN_ROOF_ROLE):
			_expect(res, c["host"] == "roof",
				"%s main roof face hosted on %s" % [who, c["host"]])
			main_faces += 1
		_expect(res, main_faces > 0 or plan.has_court(),
			"%s claimed no main roof face" % who)
		for c in builder.components_of("porch"):
			_expect(res, not String(c["role"]).begins_with(ComponentCheck.MAIN_ROOF_ROLE),
				"%s counted porch geometry as a main roof face" % who)
	for role in WANTED_ROLES:
		var found := false
		for seen in seen_roles:
			if String(seen).begins_with(role):
				found = true
		_expect(res, found, "no fixture logged a '%s' component" % role)


## Roof off is the photographer's cutaway, not a house with a flat top: the
## builder must not go on claiming a roof it did not emit.
static func _roof_off(res: SuiteResult) -> void:
	for row in _specs():
		var who: String = row[0]
		var builder := HouseBuilder.new()
		var mesh := builder.build(row[1], false)
		_expect(res, ComponentCheck.roof_claims(builder).is_empty(),
			"%s cutaway still claims roof components" % who)
		_expect(res, builder.roof_components.is_empty(),
			"%s cutaway retained roof_components" % who)
		_expect(res, bool(ComponentCheck.check(builder, mesh)["ok"]),
			"%s cutaway component log not backed by the mesh" % who)


## The negative half. Same spec, same plan, one emitted component removed or
## displaced -- and the check has to notice.
static func _faults(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.width = 9.0
	spec.length = 14.0
	spec.height = 2.7
	spec.storeys = 2
	spec.room_count = 1
	spec.program = [&"hall"]
	spec.roof_type = &"gable"
	spec.roof_pitch = 0.9
	spec.dormers = true
	spec.dormer_count = 2
	spec.bargeboards = true
	spec.timber_frame = true
	var plan := HousePlanner.plan(spec)

	var honest := HouseBuilder.new()
	var honest_mesh := honest.build(plan)
	_expect(res, bool(ComponentCheck.check(honest, honest_mesh)["ok"]),
		"fault control house already fails its own component check")

	for role in ["roof_face_0", "dormer_0_cheek", "verge_board", "opening_jamb"]:
		for fault in [Faulty.Fault.REMOVE, Faulty.Fault.MOVE]:
			var broken = Faulty.new()
			broken.fault = fault
			broken.fault_role = role
			var broken_mesh: ArrayMesh = broken.build(plan)
			var label := "%s %s" % [role, "removed" if fault == Faulty.Fault.REMOVE else "moved"]
			var touched := false
			for c in broken.component_log:
				if c["role"] == role:
					touched = true
			_expect(res, touched, "%s: fixture never reached that role" % label)
			if not touched:
				continue
			# The SPEC is untouched: the log still claims the original piece.
			_expect(res, ComponentCheck.identities(broken) == ComponentCheck.identities(honest),
				"%s: fixture changed the component identities, not just the mesh" % label)
			_expect(res, not bool(ComponentCheck.check(broken, broken_mesh)["ok"]),
				"%s: component check did not notice" % label)
