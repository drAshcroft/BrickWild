extends RefCounted
## Bounded castle change gate. The full style/tier/seed and voxel sweeps remain
## in castle, cnormals, cmassing and cvoxelqa for scheduled regression runs.

const Apertures = preload("res://tests/suites/castle_aperture_suite.gd")
const CASES := [
	{"name": "square", "style": &"norman", "tier": &"house", "index": 1,
		"voxel": true},
	{"name": "round", "style": &"edwardian", "tier": &"manor", "index": 1,
		"voxel": true},
	{"name": "battered", "style": &"crusader", "tier": &"castle", "index": 1,
		"components": true},
	{"name": "ridge", "style": &"bavarian", "w": 120.0, "l": 40.0,
		"h": 20.0, "seed": 8805, "plan": &"ridge"},
	{"name": "tower house", "style": &"norman", "w": 14.0, "l": 12.0,
		"h": 34.0, "seed": 8804, "plan": &"tower_house"},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle change")
	for row in CASES:
		var started := Time.get_ticks_msec()
		var spec := _spec(row)
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var who: String = "%s seed=%d" % [row.name, spec.seed]
		_expect(res, mesh != null and mesh.get_surface_count() >= 3,
			"%s has no structural mesh surfaces" % who)
		if mesh == null:
			continue
		NormalsSuite.check_mesh(res, mesh, who)
		NormalsSuite.check_openings(res, builder, who)
		var massing := CastleMassingCheck.new().check(spec, builder)
		_expect(res, massing.ok, "%s massing: %s" % [who, massing.failures])
		var components := ComponentCheck.check(builder, mesh)
		_expect(res, components.ok, "%s component triangles: %s" % [who, components.failures])
		if row.get("components", false):
			_expect(res, components.checked > 100,
				"%s did not exercise measurable exterior components" % who)
		if row.get("voxel", false):
			var qa := CastleQA.new().check(spec, mesh, builder)
			_expect(res, qa.ok, "%s voxel QA: %s" % [who, qa.failures])
		res.note("%s %.2fs" % [who, (Time.get_ticks_msec() - started) / 1000.0])
	_negative_controls(res)
	return res


static func _spec(row: Dictionary) -> CastleSpec:
	if row.has("tier"):
		return CastleSweep.spec_at(row.style, row.tier, row.index)
	var spec := CastleSpec.new()
	spec.style = row.style
	spec.width = row.w
	spec.length = row.l
	spec.height = row.h
	spec.plan_override = row.plan
	CastleGenerator.generate(spec, row.seed)
	return spec


static func _negative_controls(res: SuiteResult) -> void:
	# A solid wall at the window ray must be rejected by the same triangle
	# probe used on real square, round and battered openings in caperture.
	var wall := MeshKit.new(1)
	wall.box(Vector3(4.0, 4.0, 0.5), Vector3(0, 2, 0), 0)
	var solid := wall.commit()
	_expect(res, Apertures._stone_ray_hits(solid, 0, Vector3(0, 2, -1),
		Vector3.BACK, 2.0), "solid-window negative control was not detected")
	var arrays: Array = solid.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(normals.size()):
		normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var inverted := ArrayMesh.new()
	inverted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var normal_control := SuiteResult.new("inverted normal control")
	NormalsSuite.check_mesh(normal_control, inverted, "inverted wall")
	_expect(res, not normal_control.ok(), "inverted-normal control was not detected")
	var spec := CastleSweep.spec_at(&"norman", &"house", 1)
	var builder := CastleBuilder.new()
	builder.build(spec)
	builder.mass_log.clear()
	var massing := CastleMassingCheck.new().check(spec, builder)
	_expect(res, not massing.ok, "missing-mass control was not detected")


static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
