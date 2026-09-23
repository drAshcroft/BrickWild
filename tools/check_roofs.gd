extends SceneTree
## Headless roof audit: --family=hotel --seed=42 --out=res://artifacts/roof_audit
## Defaults: all six implemented building families, seeds 42 and 4413.
## Exit 0 = no detected failures, 1 = defects, 2 = usage/report-write error.
const Probe = preload("res://tests/roof_probe.gd")
const HouseRoofs = preload("res://tests/suites/house_roof_suite.gd")
const ChurchRoofs = preload("res://tests/suites/church_roof_suite.gd")
const OtherRoofs = preload("res://tests/suites/castle_temple_roof_suite.gd")
const Regions = preload("res://tests/roof_region_fixtures.gd")
const FAMILIES := ["house", "shop", "hotel", "church", "castle", "temple"]
var rows: Array[Dictionary] = []
var selected: Array[String] = []
var seeds: Array[int] = [42, 4413]
var output := "res://artifacts/roof_audit"
var controls_only := false
var regions_only := false

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):
			var family := arg.trim_prefix("--family=")
			if family not in FAMILIES:
				_usage("Unknown family: " + family)
				return
			if family not in selected:
				selected.append(family)
		elif arg.begins_with("--seed=") and arg.trim_prefix("--seed=").is_valid_int():
			seeds = [int(arg.trim_prefix("--seed="))]
		elif arg.begins_with("--out=") and not arg.trim_prefix("--out=").is_empty():
			output = arg.trim_prefix("--out=")
		elif arg == "--self-test":
			controls_only = true
		elif arg == "--regions-only":
			regions_only = true
		else:
			_usage("Unknown argument: " + arg)
			return
	if selected.is_empty():
		selected.assign(FAMILIES)
	call_deferred("_run")

func _usage(message: String) -> void:
	printerr(message + "\nUsage: --family=house|shop|hotel|church|castle|temple (repeatable) --seed=42 --out=res://artifacts/roof_audit --self-test --regions-only")
	quit(2)

func _run() -> void:
	_suite("controls", Probe.self_test(), "tests/roof_probe.gd", "synthetic valid and broken slabs/dormers")
	if not controls_only:
		for family in selected:
			if regions_only:
				break
			print("Checking " + family + " roofs...")
			match family:
				"house":
					_suite(family, HouseRoofs.run(), "tests/suites/house_roof_suite.gd", "fixed hip/gable/dormer matrix and regression seeds")
				"church":
					_suite(family, ChurchRoofs.run(), "tests/suites/church_roof_suite.gd", "fixed valleys/aisles/apse/tower/dome matrix")
				"castle":
					var r := SuiteResult.new("castle roofs")
					OtherRoofs._gables(r)
					OtherRoofs._joints(r)
					OtherRoofs._castles(r)
					_suite(family, r, "tests/suites/castle_temple_roof_suite.gd", "fixed rotated gables/valleys/keep offsets/tower caps")
				"temple":
					var r := SuiteResult.new("temple roofs")
					OtherRoofs._temples(r)
					_suite(family, r, "tests/suites/castle_temple_roof_suite.gd", "fixed forms/dimensions/dome/spire matrix")
			for seed in seeds:
				for style in BuildingLibrary.styles(StringName(family)):
					print("  %s %s seed=%d" % [family, style, seed])
					_fixture(family, style, seed)
				# Yield between seeds so Godot flushes released mesh resources.
				await process_frame
		for fixture in Regions.build(selected):
			print("  Region contract " + fixture["fixture"])
			var region_row := Regions.evaluate(fixture)
			rows.append(region_row)
			for failure in region_row.failures:
				print("    FAIL " + failure)
			await process_frame
	var failures := 0
	var warnings := 0
	var checked := 0
	for row in rows:
		failures += row.failures.size()
		warnings += row.warnings.size()
		checked += row.checked
	var report := {"schema_version": 1, "generated_utc": Time.get_datetime_string_from_system(true),
		"families": selected if not controls_only else [], "seeds": seeds,
		"checked": checked, "failure_groups": failures, "warning_groups": warnings,
		"rows": rows, "coverage_limits": _limits(), "registry_coverage": _registry_coverage()}
	if not _save(report):
		quit(2)
		return
	print("ROOF AUDIT: %d checks, %d failure groups, %d warning groups. %s.md" % [checked, failures, warnings, output])
	quit(1 if failures > 0 else 0)

func _suite(family: String, result: SuiteResult, source: String, fixture: String) -> void:
	rows.append({"family": family, "fixture": fixture, "source": source, "type": "regression_suite",
		"checked": result.checked, "failures": result.failures, "warnings": result.warnings, "notes": result.notes})
	print("  " + result.summary())

func _fixture(family: String, style: StringName, seed: int) -> void:
	var spec: RefCounted
	var builder: MassBuilder
	var mesh: ArrayMesh
	var plan: HousePlan
	var bottom := 0.0
	match family:
		"house":
			spec = HouseSpec.new()
			spec.style = style
			plan = HouseGenerator.generate(spec, seed, false)
			builder = HouseBuilder.new()
			mesh = builder.build(plan)
			bottom = spec.height * spec.storeys - 0.2
		"shop":
			spec = ShopSpec.new()
			spec.style = style
			plan = ShopGenerator.generate(spec, seed, false)
			builder = HouseBuilder.new()
			mesh = builder.build(plan)
			bottom = spec.height * spec.storeys - 0.2
		"hotel":
			spec = HotelSpec.new()
			spec.style = style
			plan = HotelGenerator.generate(spec, seed, false)
			builder = HotelBuilder.new()
			mesh = builder.build(plan)
			bottom = HotelGeometry.wall_top(spec) - 0.2
		"church":
			spec = ChurchSpec.new()
			spec.style = style
			ChurchGenerator.generate(spec, seed)
			builder = ChurchBuilder.new()
			mesh = builder.build(spec)
			bottom = spec.height - 0.2
		"castle":
			spec = CastleSpec.new()
			spec.style = style
			CastleGenerator.generate(spec, seed)
			builder = CastleBuilder.new()
			mesh = builder.build(spec)
			bottom = 0.1
		"temple":
			spec = TempleSpec.new()
			spec.form = style
			TempleGenerator.generate(spec, seed)
			builder = TempleBuilder.new()
			mesh = builder.build(spec)
			bottom = spec.height - 0.2 if style != &"ziggurat" else 0.1
	var row := Probe.inspect(mesh, bottom)
	row.merge({"family": family, "fixture": "%s seed=%d" % [style, seed], "type": "generated_building",
		"source": "src/%s/%s_builder.gd" % ["house" if family == "shop" else family, "house" if family == "shop" else family],
		"seed": seed, "style": String(style), "width": spec.width, "length": spec.length, "height": spec.height,
		"samples": [], "notes": []})
	if plan != null:
		row.storeys = spec.storeys
		row.roof_type = String(spec.roof_type)
		var holes: Array[PackedVector2Array] = []
		for i in plan.courts.size():
			holes.append(plan.court_outline(i))
		for i in plan.rooms.size():
			if plan.storey_of_room(i) == spec.storeys - 1:
				_cover(row, mesh, plan.outline_of(i), bottom, "room_%d" % i, holes)
		for i in holes.size():
			_cover(row, mesh, holes[i], bottom, "court_%d" % i, [], true)
		if family == "shop":
			var result := SuiteResult.new("shop envelope")
			HouseRoofs._check_house(result, plan, mesh, row.fixture)
			row.checked += result.checked
			row.failures.append_array(result.failures)
		if family == "hotel":
			_hotel_attachments(row, plan, builder)
	elif family == "church":
		# Roof over the occupied nave; exterior aisles are independently tested
		# by the fixed regression matrix above.
		_cover(row, mesh, Poly.from_rect(Rect2(-spec.width/2 + 0.15, -spec.length/2 + 0.15, spec.width - 0.3, spec.length - 0.3)), bottom, "nave")
	elif family == "temple" and style != &"ziggurat":
		_cover(row, mesh, Poly.from_rect(TempleGeometry.hall_rect(spec).grow(-0.15)), bottom, "hall")
	elif family == "castle":
		row.notes.append("Full generated roof surface integrity; coverage/joints use isolated regression fixtures because open battlements and yards are intentional.")
	rows.append(row)
	for f in row.failures:
		print("    FAIL " + f)

func _cover(row: Dictionary, mesh: ArrayMesh, polygon: PackedVector2Array, bottom: float,
		label: String, holes: Array[PackedVector2Array] = [], sky := false) -> void:
	var check := Probe.coverage(mesh, polygon, bottom, holes, sky)
	row.checked += check.checked
	row.samples.append({"region": label, "checked": check.checked, "covered": check.covered, "misses": check.misses})
	if check.checked == 0:
		row.warnings.append("roof_coverage: no samples in " + label)
	elif not check.misses.is_empty():
		row.failures.append("%s: %s %d/%d samples; first=%s" % ["court_sky" if sky else "roof_coverage", label, check.misses.size(), check.checked, str(check.misses[0])])

func _hotel_attachments(row: Dictionary, plan: HousePlan, builder: MassBuilder) -> void:
	# Snapshot the emitted dormer bodies before building a host-only variant.
	var bodies: Array = builder.part_log.filter(func(p: Dictionary) -> bool: return p.tag == "dormer" and p.kind == "box")
	var host_spec := HotelSpec.new()
	for p in plan.spec.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			host_spec.set(p.name, plan.spec.get(p.name))
	host_spec.dormer_count = 0
	host_spec.cupolas = false
	var host_plan := HousePlan.new()
	host_plan.spec = host_spec
	var host_builder := HotelBuilder.new()
	host_builder.plan = host_plan
	host_builder.spec = host_spec
	host_builder.begin(4)
	for s in 4:
		host_builder._kit.box(Vector3.ONE, Vector3(-100,-100,-100), s)
	host_builder._build_palace_roof()
	var host := host_builder.commit()
	var failures: Array = []
	for body in bodies:
		# The frame is a second, shallow box. Probe the 0.95m-deep body only.
		if body.size.z < 0.5:
			continue
		row.checked += 1
		var result := Probe.attachment(host, body.pos, body.size)
		if not result.attached:
			failures.append(result)
	row.dormer_attachment_failures = failures
	if not failures.is_empty():
		row.failures.append("dormer_attachment: %d bodies do not meet host roof; first=%s" % [failures.size(), str(failures[0])])

func _limits() -> Array[String]:
	return ["Finite deterministic samples, not exhaustive geometric proof or visual approval. Coverage alone cannot detect crossed slabs; the fixed envelope suites supplement it.",
		"Generated cases use default dimensions and every registered style/form at selected seeds. Fixed regression matrices additionally vary roof size, pitch, rotation and attachments; --seed does not replace their fixed seeds.",
		"Shops test the default business with every shell style. Hotel dormer attachment and named cupola rim/bearing seams are tested; a true mansard profile is not implemented or certified.",
		"Authored courts, 8/14-gon oculi, two ziggurat chamber/terrace sizes, all four castle tiers at two sizes, and hotel cupolas have explicit region contracts. Arbitrary shapes and all tier/shape combinations remain outside this finite matrix.",
		"Castle yard/battlement sky and occupied ranges/keep plans are measured separately. Ziggurat chamber ceilings use stone surface0. Complete church peripheral full-building joins remain uncovered beyond existing fixed suites.",
		"WorldFamilies currently has %d registered families. World roofs are not counted as passing when there are no implementations." % WorldFamilies.families().size(),
		"Village fixtures measure two native buildings after real lot placement and transformation when house and shop are selected. Other placed families, inter-building roof joins and tree/roof interference remain uncovered."]

func _registry_coverage() -> Array[Dictionary]:
	var registry: Array[Dictionary] = []
	for family in WorldFamilies.families():
		for kind in WorldFamilies.kinds_of(family):
			registry.append({"family": "world", "style": String(family), "kind": String(kind),
				"status": "uncovered", "reason": "No authored roof-region fixture for this registered world kind; not counted as passing."})
	if registry.is_empty():
		registry.append({"family": "world", "status": "uncovered", "reason": "Registry is empty; no implemented families to audit."})
	return registry

func _save(report: Dictionary) -> bool:
	var path := ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		printerr("Cannot create report directory: " + path.get_base_dir())
		return false
	var json := FileAccess.open(path + ".json", FileAccess.WRITE)
	if json == null:
		printerr("Cannot write " + path + ".json")
		return false
	json.store_string(JSON.stringify(report, "\t"))
	json.close()
	var lines: Array[String] = ["# Roof audit", "", "Generated UTC: " + report.generated_utc, "",
		"%d checks; **%d failure groups**, %d warning groups. See the JSON companion for every failing sample." % [report.checked, report.failure_groups, report.warning_groups], "",
		"| Family | Cases / suites | Checks | Failures | Warnings |", "|---|---:|---:|---:|---:|"]
	for family in ["controls"] + selected + ["village"]:
		var counts := [0, 0, 0, 0]
		for row in rows:
			if row.family == family:
				counts[0] += 1
				counts[1] += row.checked
				counts[2] += row.failures.size()
				counts[3] += row.warnings.size()
		if counts[0] > 0:
			lines.append("| %s | %d | %d | %d | %d |" % [family, counts[0], counts[1], counts[2], counts[3]])
	lines.append_array(["", "## Findings", ""])
	for row in rows:
		if row.failures.is_empty() and row.warnings.is_empty():
			continue
		lines.append_array(["### %s: %s" % [row.family, row.fixture], "", "Source: `%s`" % row.source, ""])
		for f in row.failures:
			lines.append("- **FAIL** " + f)
		for w in row.warnings:
			lines.append("- WARN " + w)
		lines.append("")
	lines.append_array(["## Coverage limits", ""])
	for limit in report.coverage_limits:
		lines.append("- " + limit)
	lines.append_array(["", "## Registry entries without roof contracts", ""])
	for entry in report.registry_coverage:
		lines.append("- **%s** `%s/%s/%s`: %s" % [entry.status,
			entry.family, entry.get("style", ""), entry.get("kind", ""), entry.reason])
	var md := FileAccess.open(path + ".md", FileAccess.WRITE)
	if md == null:
		printerr("Cannot write " + path + ".md")
		return false
	md.store_string("\n".join(lines) + "\n")
	md.close()
	return true
