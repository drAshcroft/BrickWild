extends SceneTree
const Probe = preload("res://tests/roof_probe.gd")

func _init() -> void:
	var result := SuiteResult.new("roof seams and dome caps")
	var sliver := PackedVector2Array([Vector2(6.668438, 7.183245), Vector2(8.003682, 8.065014), Vector2(8.003694, 8.065015)])
	result.checked += 2
	if not preload("res://src/church/church_roofs.gd")._precision_sliver(sliver):
		result.fail("real dome clipping sliver would still become a full-depth duplicate cap")
	if preload("res://src/church/church_roofs.gd")._precision_sliver(Poly.from_rect(Rect2(0, 0, 2, 0.001))):
		result.fail("millimetre-wide intentional roof fragment was discarded")
	var doubled_corner := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2.00001, 0.00001), Vector2(2, 2), Vector2(0, 2)])
	result.checked += 1
	if preload("res://src/church/church_roofs.gd")._clean_precision_edges(doubled_corner).size() != 4:
		result.fail("micrometre edge would still be extruded as a full-depth cap")
	for arc in [PI * 0.5, PI, PI * 1.5]:
		var kit := MeshKit.new(3)
		kit.box(Vector3.ONE, Vector3(0, -10, 0), 0)
		kit.box(Vector3.ONE, Vector3(0, -10, 0), 1)
		kit.revolve(PackedVector2Array([Vector2(2, 0), Vector2(1.4, 1), Vector2(0, 2)]), Vector3.ZERO, 2, 12, arc)
		var mesh := kit.commit()
		var report := Probe.inspect(mesh, -0.1)
		result.checked += 1
		if not report.failures.is_empty() or not report.warnings.is_empty():
			result.fail("partial dome arc=%f: %s / %s" % [arc, report.failures, report.warnings])
		var arrays := mesh.surface_get_arrays(2)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var outward := Vector3(-sin(arc), 0, cos(arc))
		var end_direction := Vector3(cos(arc), 0, sin(arc))
		var caps := 0
		for index in range(0, points.size(), 3):
			var center := (points[index] + points[index + 1] + points[index + 2]) / 3.0
			if absf(center.dot(outward)) < 0.0001 and center.dot(end_direction) > 0.1 \
					and absf(normals[index].y) < 0.001:
				caps += 1
				result.checked += 1
				if normals[index].dot(outward) < 0.99:
					result.fail("partial dome end cap faces inside the swept solid")
		result.checked += 1
		if caps == 0:
			result.fail("partial dome end cap vanished")
	# Same coordinates are insufficient to call a seam a visible double skin.
	for opposed in [false, true]:
		var kit := MeshKit.new(3)
		kit.box(Vector3.ONE, Vector3(0, -10, 0), 0)
		kit.box(Vector3.ONE, Vector3(0, -10, 0), 1)
		var a := Vector3(0, 1, 0)
		var b := Vector3(1, 1, 0)
		var c := Vector3(0, 1, 1)
		kit._tri(kit.surface(2), a, b, c)
		kit._tri(kit.surface(2), a, c if opposed else b, b if opposed else c)
		var findings: Array = Probe.inspect(kit.commit(), 0).mesh_findings
		result.checked += 1
		var expected := "opposed_shared_cap" if opposed else "same_facing"
		if findings.size() != 1 or findings[0].get("classification", "") != expected:
			result.fail("duplicate winding classification lost: " + expected)
	# The remaining real warnings are retained closed-solid boundaries, not
	# exposed double skins. Guard their disposition on actual generated meshes.
	for style in [&"renaissance", &"russian", &"byzantine"]:
		for seed in [42, 4413]:
			var spec := ChurchSpec.new()
			spec.style = style
			ChurchGenerator.generate(spec, seed)
			var mesh := ChurchBuilder.new().build(spec)
			var report := Probe.inspect(mesh, spec.height - 0.2)
			result.checked += 1
			for finding in report.mesh_findings:
				if finding.get("classification", "") != "opposed_shared_cap":
					result.fail("%s/%d exposed duplicate or degenerate remains: %s" % [style, seed, finding])
	for seed in [42, 4413]:
		var spec := TempleSpec.new()
		spec.form = &"rotunda"
		TempleGenerator.generate(spec, seed)
		var report := Probe.inspect(TempleBuilder.new().build(spec), spec.height - 0.2)
		result.checked += 1
		for finding in report.mesh_findings:
			if finding.get("normal_dot", 0.0) > -0.999 or finding.get("vertex_delta", INF) > 0.000002:
				result.fail("rotunda/%d seam is no longer its opposed rim cap: %s" % [seed, finding])
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
