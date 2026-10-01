class_name WorldStupaSuite
extends RefCounted
## WLD-017 focused gate: Saint's Mound and one negative fixture per rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("world stupa")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"stupa"
	request.purpose = &"saints_mound"
	request.seed = 17017
	request.width = 40.0
	request.length = 40.0
	request.height = 17.0
	var building: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Saint's Mound 40 x 40 x 17 did not generate: %s" %
			(str(building.errors) if building != null else "null"))
		return res
	if not building.spec is StupaSpec:
		res.fail("Saint's Mound did not retain its StupaSpec representation")
		return res
	var spec := building.spec as StupaSpec
	var builder := StupaBuilder.new()
	var mesh := builder.build(spec)
	if mesh == null or mesh.get_surface_count() == 0:
		res.fail("Saint's Mound did not emit a mesh")
	for failure in StupaCheck.new().check(spec, builder).get("failures", []):
		res.fail("Saint's Mound: %s" % str(failure))
	var replacement: Dictionary = StupaCheck.new().check(spec, builder).get("replaced", {})
	if not replacement.has("walk"):
		res.fail("StupaCheck did not explicitly replace ordinary walk with ring-and-stair QA")
	_negative_fixtures(res)
	return res


static func _fixture() -> Array:
	var spec := StupaGenerator.generate(&"saints_mound", 17100, 40.0, 40.0, 17.0)
	var builder := StupaBuilder.new()
	builder.build(spec)
	return [spec, builder]


static func _expect(res: SuiteResult, label: String, prefix: String,
		spec: StupaSpec, builder: StupaBuilder) -> void:
	res.checked += 1
	var report := StupaCheck.new().check(spec, builder)
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative stupa fixture %s did not fail %s" % [label, prefix])


static func _negative_fixtures(res: SuiteResult) -> void:
	var solid: Array = _fixture()
	for row in solid[1].component_log:
		if String(row.get("role", "")) == "stupa_dome":
			row["base_capped"] = false
			break
	_expect(res, "uncapped solid dome", "solid", solid[0], solid[1])

	var dome: Array = _fixture()
	for i in range(dome[1].mass_log.size() - 1, -1, -1):
		if String(dome[1].mass_log[i].get("name", "")) == "stupa_harmika":
			dome[1].mass_log.remove_at(i)
	_expect(res, "missing harmika", "dome", dome[0], dome[1])

	var circle: Array = _fixture()
	for i in range(circle[1].component_log.size() - 1, -1, -1):
		if String(circle[1].component_log[i].get("role", "")) == "ground_circumambulatory_ring":
			circle[1].component_log.remove_at(i)
	_expect(res, "missing ground ring", "circle", circle[0], circle[1])

	var cardinal: Array = _fixture()
	for i in range(cardinal[1].component_log.size() - 1, -1, -1):
		if String(cardinal[1].component_log[i].get("role", "")) == "torana_cardinal_mass":
			cardinal[1].component_log.remove_at(i)
			break
	_expect(res, "missing torana", "cardinal", cardinal[0], cardinal[1])

	var dominance: Array = _fixture()
	for i in range(dominance[1].mass_log.size() - 1, -1, -1):
		if String(dominance[1].mass_log[i].get("name", "")) == "stupa_chatra_disc_2":
			dominance[1].mass_log.remove_at(i)
			break
	_expect(res, "incomplete chatra", "dominance", dominance[0], dominance[1])

	var walk: Array = _fixture()
	for i in range(walk[1].component_log.size() - 1, -1, -1):
		if String(walk[1].component_log[i].get("role", "")) == "stupa_double_stair":
			walk[1].component_log.remove_at(i)
	_expect(res, "missing connecting stair", "circle", walk[0], walk[1])
