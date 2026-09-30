extends RefCounted
## VIS-007: named buttress stages and flyer ribbons must match emitted stone.

static func run() -> SuiteResult:
	var res := SuiteResult.new("church load paths")
	var durham := _landmark("durham", &"romanesque", 11.9, 61.0, 22.2, 5005)
	var db := ChurchBuilder.new()
	var dm: ArrayMesh = db.build(durham)
	_check_components(res, db, dm, "Durham")
	var nave_hosts := 0
	var tower_hosts := {}
	for row in db.component_log:
		var host_name: String = row["host"]
		if host_name.begins_with("nave_") and row["role"] == "shaft_0":
			nave_hosts += 1
			_check_stages(res, db, host_name)
		if host_name.begins_with("tower_") and row["role"] == "shaft_0":
			tower_hosts[host_name] = true
			_check_stages(res, db, host_name)
	_expect(res, nave_hosts == durham.buttress_count_per_side * 2,
		"Durham nave buttress host count")
	_expect(res, tower_hosts.size() == 8, "Durham twin tower corner hosts")

	var notre := _landmark("notre_dame", &"gothic", 12.0, 127.0, 33.0, 5001)
	var nb := ChurchBuilder.new()
	var nm: ArrayMesh = nb.build(notre)
	_check_components(res, nb, nm, "Notre-Dame")
	var arch_count := 0
	var coping_count := 0
	for row in nb.component_log:
		if row["form"] != "arc_ribbon":
			continue
		var role: String = row["role"]
		if role == "arch_web":
			arch_count += 1
		elif role == "arch_coping":
			coping_count += 1
		_expect(res, (row["host"] as String).begins_with("flyer_"),
			"unhosted flyer %s" % role)
		var isolated := MeshKit.new(1, true)
		isolated.arc_ribbon(row["from_p"], row["to_p"], row["rise"],
			row["thickness"], row["depth"], 0, row["steps"])
		var want: PackedVector3Array = isolated.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var have: PackedVector3Array = nm.surface_get_arrays(int(row["surface"]))[Mesh.ARRAY_VERTEX]
		_expect(res, ComponentCheck.missing_triangles(have, want) == 0,
			"%s %s triangles absent" % [row["host"], role])
	var expected: int = ChurchGeometry.flyer_count(notre) * 2 * notre.flyer_tiers
	_expect(res, arch_count == expected, "Notre-Dame arch count")
	_expect(res, coping_count == expected, "Notre-Dame coping count")
	var repeat := ChurchBuilder.new()
	repeat.build(notre)
	_expect(res, ComponentCheck.identities(nb) == ComponentCheck.identities(repeat),
		"Notre-Dame component identities drifted")
	return res


static func _landmark(key: String, style: StringName, width: float,
		length: float, height: float, seed: int) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = style
	spec.width = width
	spec.length = length
	spec.height = height
	ChurchGenerator.generate(spec, seed)
	LandmarkSuite._force_features(key, spec)
	return spec


static func _check_components(res: SuiteResult, builder: ChurchBuilder,
		mesh: ArrayMesh, label: String) -> void:
	var report: Dictionary = ComponentCheck.check(builder, mesh)
	res.checked += int(report["checked"])
	for complaint in report["failures"]:
		res.fail("%s: %s" % [label, complaint])
	for row in builder.component_log:
		if not (row["host"] as String).begins_with("nave_") \
				and not (row["host"] as String).begins_with("tower_"):
			continue
		if row["form"] != "box":
			continue
		var found := false
		for part in builder.part_log:
			if part["kind"] == "box" and part["tag"] == "buttress" \
					and (part["pos"] as Vector3).distance_to(row["xf"].origin) < 0.001 \
					and (part["size"] as Vector3).distance_to(row["size"]) < 0.001:
				found = true
				break
		_expect(res, found, "%s %s lacks part log" % [label, row["host"]])


static func _check_stages(res: SuiteResult, builder: ChurchBuilder,
		host_name: String) -> void:
	var pieces: Dictionary = {}
	for row in builder.components_of(host_name):
		pieces[row["role"]] = row
	_expect(res, pieces.size() == 6, "%s should have three shafts and shoulders" % host_name)
	if pieces.size() != 6:
		return
	for i in range(2):
		var lower: Vector3 = pieces["shaft_%d" % i]["size"]
		var upper: Vector3 = pieces["shaft_%d" % (i + 1)]["size"]
		_expect(res, lower.x > upper.x + 0.05,
			"%s has no setback at %d" % [host_name, i])
		var cap: Vector3 = pieces["shoulder_%d" % i]["size"]
		_expect(res, cap.x >= lower.x - 0.001,
			"%s shoulder %d does not cap shaft" % [host_name, i])


static func _expect(res: SuiteResult, good: bool, complaint: String) -> void:
	res.checked += 1
	if not good:
		res.fail(complaint)
