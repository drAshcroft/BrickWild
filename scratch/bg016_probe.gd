extends SceneTree
func _init() -> void:
	var reqs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scratch/bg016_reqs.json"))
	for key in reqs:
		var req := BuildingRequest.from_dict(reqs[key])
		var b: GeneratedBuilding = BrickWild.generate(req)
		print("== ", key, " ok=", b.is_ok())
		var plan: HousePlan = b.plan
		var g := HouseSlope.ground(plan.spec)
		for f in HouseSlope.flights(plan):
			print(" flight door ", f["door"], " landing top ", f["landing"]["top"], " foot ", f["foot"])
			for s in f["steps"]:
				print("   tread top ", snappedf(s["top"], 0.001), " centre ", s["centre"], " len ", s["length"])
		for p in plan.yard_pieces:
			for part in p["parts"]:
				if part["role"] == "path_paver":
					var a := HouseYard.part_aabb(part)
					print(" stone y ", snappedf(a.position.y, 0.001), "..", snappedf(a.end.y, 0.001), " xz ", a.position.x, ",", a.position.z, " size ", a.size.x, "x", a.size.z, " ground ", snappedf(g.ground_y(Vector2(a.get_center().x, a.get_center().z)), 0.001))
		var hb := HouseBuilder.new()
		var mesh := hb.build(plan)
		var vs := PackedVector3Array()
		for s in mesh.get_surface_count():
			vs.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
		print(" mesh hash ", hash(vs), " verts ", vs.size())
	quit()
