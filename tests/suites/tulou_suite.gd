extends RefCounted
## WLD-010's fixed Clan Ring fixture and one failing fixture for every rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("tulou family")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.seed = 60710
	request.style = &"tulou"
	request.purpose = &"clan_ring"
	request.width = 60.0
	request.length = 60.0
	request.height = 15.0
	request.storeys = 4
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Clan Ring did not generate: %s" % (str(building.errors) if building != null else "null"))
		return res
	var builder := TulouBuilder.new()
	var mesh := builder.build(building.plan)
	if mesh == null or mesh.get_surface_count() == 0:
		res.fail("Clan Ring emitted no mesh")
	var report := TulouCheck.new().check(building.plan, builder)
	for failure in report["failures"]:
		res.fail(String(failure))
	res.checked += 8
	for failure2 in TulouCheck.negative_controls():
		res.fail(String(failure2))
	res.checked += 8
	var document := BrickWild.generate_document(request)
	res.checked += 1
	if document == null or not document.is_ok() or document.plan.world_family != &"tulou":
		res.fail("API document lost the tulou family plan")
	return res
