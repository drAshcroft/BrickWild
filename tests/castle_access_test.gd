extends SceneTree
## Exercise the real access emitter without re-running interior furnishing.

func _init() -> void:
	var res := SuiteResult.new("castle physical access")
	var filters := OS.get_cmdline_user_args()
	for style in CastleSweep.styles():
		for tier in [&"castle", &"fortress"]:
			for index in range(3):
				var who := "%s/%s/%d" % [style, tier, index]
				if not filters.is_empty() and not Array(filters).any(func(f): return who.contains(f)):
					continue
				var spec := CastleSweep.spec_at(style, tier, index)
				if not CastleGeometry.is_enclosed(spec):
					continue
				var builder := CastleBuilder.new()
				builder.spec = spec
				builder.begin(4)
				for ring in CastleGeometry.rings(spec):
					builder._build_ring(ring)
				builder._build_wall_stairs()
				var mesh := builder.commit()
				var check := CastleMassingCheck.new()
				check._check_wall_stairs(spec, builder)
				_expect(res, check.failures.is_empty(), who + " " + str(check.failures))
				_expect(res, ComponentCheck.check(builder, mesh)["ok"], who + " stair components differ from real triangles")
				var triangles: Array = []
				for surface in mesh.get_surface_count():
					triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
				var missing := 0
				var blocked := 0
				for row in builder.component_log:
					if row.role not in ["wall_stair_tread", "wall_stair_landing"]:
						continue
					var centre: Vector3 = row.xf.origin + Vector3.UP * row.size.y * 0.5
					if not _hit(triangles, centre + Vector3.UP * 0.04, centre - Vector3.UP * 0.04):
						missing += 1
					if _hit(triangles, centre + Vector3.UP * 0.05, centre + Vector3.UP * 1.95):
						blocked += 1
						print("BLOCKED ", who, " ", row.host, " ", row.role, " ", centre)
						for tri in triangles:
							var hit = Geometry3D.segment_intersects_triangle(centre + Vector3.UP * 0.05, centre + Vector3.UP * 1.95, tri[0], tri[1], tri[2])
							if hit != null:
								print("HIT ", hit, " triangle ", tri)
								break
				_expect(res, missing == 0, who + " %d treads/landings have no emitted floor" % missing)
				_expect(res, blocked == 0, who + " %d treads/landings have obstructed headroom" % blocked)
				if index == 0:
					builder.mass_log = builder.mass_log.filter(func(m): return not String(m.name).begins_with("wall_stair_"))
					check = CastleMassingCheck.new()
					check._check_wall_stairs(spec, builder)
					_expect(res, not check.failures.is_empty(), who + " missing stairs escaped QA")
				print("ACCESS ", who, " failures=", res.failures.size())
	for failure in res.failures:
		print("FAIL: ", failure)
	print(res.summary())
	quit(0 if res.ok() else 1)


func _hit(triangles: Array, a: Vector3, b: Vector3) -> bool:
	for tri in triangles:
		if Geometry3D.segment_intersects_triangle(a, b, tri[0], tri[1], tri[2]) != null:
			return true
	return false


func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
		print("FAIL: ", message)
