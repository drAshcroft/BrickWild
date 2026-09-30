extends SceneTree
## Repeatable stage timings for the bounded castle change lane. Run one case per
## process so a costly voxel case cannot conceal the timings of earlier cases.

const CASES := [
	{"name": "square", "style": &"norman", "tier": &"house", "index": 1},
	{"name": "round", "style": &"edwardian", "tier": &"manor", "index": 1},
	{"name": "battered", "style": &"crusader", "tier": &"castle", "index": 1},
	{"name": "nested", "style": &"crusader", "w": 90.0, "l": 140.0, "h": 20.0, "seed": 9118},
	{"name": "ridge", "style": &"bavarian", "w": 120.0, "l": 40.0, "h": 20.0,
		"seed": 8805, "plan": &"ridge"},
	{"name": "tower_house", "style": &"norman", "w": 14.0, "l": 12.0, "h": 34.0,
		"seed": 8804, "plan": &"tower_house"},
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) if not args.is_empty() else 0
	if index < 0 or index >= CASES.size():
		printerr("case index must be 0..%d" % (CASES.size() - 1))
		quit(2)
		return
	var row: Dictionary = CASES[index]
	var stamp := Time.get_ticks_msec()
	var spec: CastleSpec
	if row.has("tier"):
		spec = CastleSweep.spec_at(row.style, row.tier, row.index)
	else:
		spec = CastleSpec.new()
		spec.style = row.style
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.plan_override = row.get("plan", &"")
		CastleGenerator.generate(spec, row.seed)
	print("CASE ", row.name, " style=", spec.style, " tier=", spec.tier,
		" seed=", spec.seed, " plan=", spec.plan_kind,
		" rings=", CastleGeometry.rings(spec).size(),
		" generate_ms=", Time.get_ticks_msec() - stamp)
	stamp = Time.get_ticks_msec()
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	print("STAGE build_ms=", Time.get_ticks_msec() - stamp,
		" vertices=", _vertices(mesh), " parts=", builder.part_log.size(),
		" masses=", builder.mass_log.size())
	stamp = Time.get_ticks_msec()
	var normal_result := SuiteResult.new("profile normals")
	NormalsSuite.check_mesh(normal_result, mesh, row.name)
	NormalsSuite.check_openings(normal_result, builder, row.name)
	print("STAGE normals_ms=", Time.get_ticks_msec() - stamp,
		" checks=", normal_result.checked, " failures=", normal_result.failures.size())
	stamp = Time.get_ticks_msec()
	var massing := CastleMassingCheck.new().check(spec, builder)
	print("STAGE massing_ms=", Time.get_ticks_msec() - stamp,
		" failures=", massing.failures.size(), " first=", massing.failures.slice(0, 3))
	stamp = Time.get_ticks_msec()
	var components := ComponentCheck.check(builder, mesh)
	print("STAGE components_ms=", Time.get_ticks_msec() - stamp,
		" checked=", components.checked, " unverified=", components.unverified,
		" failures=", components.failures.size())
	stamp = Time.get_ticks_msec()
	var qa := CastleQA.new().check(spec, mesh, builder)
	print("STAGE voxel_qa_ms=", Time.get_ticks_msec() - stamp,
		" failures=", qa.failures.size(), " voxels=", qa.stats.get("voxels_solid", -1),
		" first=", qa.failures.slice(0, 5))
	quit()


static func _vertices(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return count
