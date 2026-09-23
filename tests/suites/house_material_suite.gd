extends RefCounted

static func run() -> SuiteResult:
	var res := SuiteResult.new("house materials")
	for kind in [&"gable", &"half_hipped", &"hipped"]:
		for rotated in [false, true]:
			var s := HouseSpec.new()
			s.width = 13.0 if rotated else 9.0
			s.length = 9.0 if rotated else 13.0
			s.exterior_props = false
			var p := HouseGenerator.generate(s, 4413, false)
			s.roof_type = kind
			s.dormers = true
			s.dormer_count = 2
			var b := HouseBuilder.new()
			var mesh := b.build(p)
			_expect(res, mesh.get_surface_count() == 4, "house changed shared material slot contract")
			var a := mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var normal: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
			var glazing := 0
			for tint in colors:
				if tint.r < 0.5:
					glazing += 1
			_expect(res, glazing > 0, "window/dormer glazing lacks material marker")
			var sloped := 0
			for i in range(0, verts.size(), 3):
				if absf(normal[i].y) < 0.1 or absf(normal[i].y) > 0.99:
					continue
				var area3 := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).length()
				var area2 := absf((uv[i + 1] - uv[i]).cross(uv[i + 2] - uv[i]))
				_expect(res, absf(area3 - area2) < 0.002, "%s rotated=%s roof UV is stretched or collapsed" % [kind, rotated])
				sloped += 1
			_expect(res, sloped > 4, "material fixture lacks roof/dormer slope triangles")
			var shell := MeshInstance3D.new()
			shell.mesh = mesh
			ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(s))
			ShellAssembler.house_materials(shell, s)
			s.roof_color = Color.RED
			s.roof_material = &"slate"
			ShellAssembler.house_materials(shell, s)
			_expect(res, b.build(p).surface_get_arrays(2)[Mesh.ARRAY_COLOR] == colors,
				"roof material change altered glazing classification")
			_expect(res, shell.get_surface_override_material(2) is ShaderMaterial or DisplayServer.get_name() == "headless", "roof lacks course material")
			shell.mesh = null
			shell.free()
	return res


static func _expect(res: SuiteResult, ok: bool, why: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(why)
