extends SceneTree
func _init() -> void:
	for st in [&"townhouse", &"cottage", &"rhine"]:
		for sd in [8102, 5511]:
			var req: BuildingRequest = BuildingRequest.house(sd, st, &"none", 8.0, 10.0, 2.6, 2)
			var b: GeneratedBuilding = BrickWild.generate(req)
			if not b.is_ok():
				print(st, sd, " not ok"); continue
			var n := 0
			for p in b.plan.yard_pieces:
				if p["kind"] == "path": n += p["parts"].size()
			var mesh := HouseBuilder.new().build(b.plan)
			var vs := PackedVector3Array()
			for s in mesh.get_surface_count():
				vs.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
			print(st, " ", sd, " stones ", n, " hash ", hash(vs), " verts ", vs.size())
	quit()
