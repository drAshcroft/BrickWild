extends RefCounted

static func run() -> SuiteResult:
	var result := SuiteResult.new("castle gate access")
	for style in [&"norman", &"crusader", &"moorish", &"japanese"]:
		var spec := CastleSweep.spec_at(style, &"fortress", 0)
		spec.ditch_width = 5.0
		var builder := CastleBuilder.new()
		builder.spec = spec
		builder.begin(4)
		for ring in CastleGeometry.rings(spec):
			builder._build_ring(ring)
		builder._build_drawbridge()
		var mesh := builder.commit()
		var report := CastleQA.gate_access_report(spec, builder, mesh)
		_expect(result, report.failures.is_empty(), String(style) + " " + str(report.failures))
		_expect(result, ComponentCheck.check(builder, mesh).ok, String(style) + " accessories differ from emitted triangles")
		builder.mass_log = builder.mass_log.filter(func(m): return not String(m.name).begins_with("portcullis_") and m.name != "drawbridge")
		report = CastleQA.gate_access_report(spec, builder, mesh)
		_expect(result, report.failures.size() >= CastleGeometry.rings(spec).size() + 1, String(style) + " missing accessory logs escaped QA")
		builder = CastleBuilder.new()
		builder.spec = spec
		builder.begin(4)
		for ring in CastleGeometry.rings(spec):
			var gate := CastleGeometry.gatehouse_aabb(spec, ring)
			builder._passage(gate, minf(gate.size.x * 0.4, 4.0), minf(gate.size.y * 0.4, 5.0))
		builder._build_drawbridge()
		report = CastleQA.gate_access_report(spec, builder, builder.commit())
		_expect(result, report.failures.any(func(f): return String(f).contains("open recessed groove")), String(style) + " uncut passage escaped physical QA")
		print("GATE_ACCESS ", style, " failures=", result.failures.size())
	return result

static func _expect(result: SuiteResult, ok: bool, message: String) -> void:
	result.checked += 1
	if not ok:
		result.fail(message)
		print("FAIL: ", message)
