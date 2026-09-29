extends RefCounted
## A jetty is a usable room extension carried by an emitted floor, not trim.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house jetty")
	for levels in [2, 3]:
		for rotated in [false, true]:
			for enabled in [false, true]:
				var s := HouseSpec.new(4411)
				s.style = &"townhouse"
				s.width = 12.0 if rotated else 9.0
				s.length = 9.0 if rotated else 12.0
				s.height = 2.7
				s.storeys = levels
				s.cellars = 1
				s.room_count = 4
				s.program = [&"hall", &"bedroom", &"kitchen", &"store"]
				s.roof_pitch = 1.1
				s.jetty = enabled
				s.jetty_depth = 0.3
				s.stone_ground_floor = true
				s.timber_frame = true
				s.chimney = true
				s.stud_pitch = 0.65
				var p := HousePlanner.plan(s)
				var who := "levels=%d rotated=%s jetty=%s" % [levels, rotated, enabled]
				for f in HousePlanCheck.new().check(p)["failures"]:
					res.fail(who + ": " + str(f))
				for f in HouseNavCheck.new().check(p)["failures"]:
					res.fail(who + ": " + str(f))
				for w in p.windows:
					_expect(res, not HousePlanner.flue_blocks(p, w["pos"], w["normal"], HousePlan.record_storey(w), w["width"]), who + " flue crosses glazing")
				var ground := HouseGeometry.site_rect(s)
				for level in range(-1, levels):
					var site := HouseGeometry.site_rect(s, level)
					var expected := s.jetty_depth if enabled and level > 0 else 0.0
					_expect(res, is_equal_approx(ground.position.y - site.position.y, expected), who + " wrong storey front")
					var area := 0.0
					for room in p.rooms_on_storey(level):
						area += Rect2(p.rooms[room]["rect"]).get_area()
					_expect(res, absf(area - HouseGeometry.interior_rect(s, level).get_area()) < 0.01,
						who + " rooms do not tile own footprint: level=%d area=%.5f expected=%.5f" % [level, area, HouseGeometry.interior_rect(s, level).get_area()])
				var builder := HouseBuilder.new()
				var mesh := builder.build(p)
				for f in HouseQA.check_jetty_geometry(p, mesh):
					res.fail(who + ": " + f)
				_expect(res, ComponentCheck.check(builder, mesh)["ok"], who + " component/mesh mismatch")
				if enabled:
					# Move the actual upper front floor back, leaving the spec,
					# plan and component log untouched. The check must notice.
					var broken := ArrayMesh.new()
					for surface in mesh.get_surface_count():
						var arrays := mesh.surface_get_arrays(surface)
						var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						if surface == HouseBuilder.SURF_FLOOR:
							for i in vertices.size():
								if vertices[i].y >= s.height - 0.01 and vertices[i].z < ground.position.y:
									vertices[i].z = ground.position.y
						arrays[Mesh.ARRAY_VERTEX] = vertices
						broken.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
					_expect(res, not HouseQA.check_jetty_geometry(p, broken).is_empty(), who + " retracted floor mutation escaped")
					var wall_back := ArrayMesh.new()
					for surface in mesh.get_surface_count():
						var arrays := mesh.surface_get_arrays(surface)
						var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						if surface == HouseBuilder.SURF_WALL:
							for i in vertices.size():
								if vertices[i].y >= s.height - 0.01 and vertices[i].z < ground.position.y + 0.1:
									vertices[i].z += s.jetty_depth
						arrays[Mesh.ARRAY_VERTEX] = vertices
						wall_back.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
					_expect(res, "\n".join(HouseQA.check_jetty_geometry(p, wall_back)).contains("jetty_wall:"), who + " retracted wall mutation escaped")
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
