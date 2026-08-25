extends SceneTree
## Headless smoke test: generate N specs, build meshes, verify counts/verts.
## Run: godot --headless --script res://tests/smoke_test.gd

func _init() -> void:
	var failures := 0
	var total_verts := 0
	for i in range(200):
		var spec := SpecGenerator.generate(1000 + i)
		assert(spec.style in [&"european", &"east_asian"])
		var builder := BuildingBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		if mesh == null or mesh.get_surface_count() != 4:
			printerr("FAIL seed=%d surfaces=%d" % [1000 + i, mesh.get_surface_count() if mesh else -1])
			failures += 1
			continue
		var v := 0
		for s in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(s)
			v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		total_verts += v
	print("OK: 200 buildings, %d total vertices, %d failures" % [total_verts, failures])
	quit(1 if failures > 0 else 0)
