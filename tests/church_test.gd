extends SceneTree
## Headless verification of the church pipeline.
## Run: godot --headless --script res://tests/church_test.gd

func _init() -> void:
	var failures := 0
	var styles: Array = ChurchSpec.STYLES.keys()
	for style in styles:
		for i in range(15):
			var spec := ChurchSpec.new(0)
			spec.style = style
			spec.width = 10.0 + i * 0.5
			spec.length = 18.0 + i * 2.0
			spec.height = 10.0 + (i % 5) * 1.5
			ChurchGenerator.generate(spec, 5000 + i)
			# user inputs must be preserved exactly
			if spec.style != style or not is_equal_approx(spec.length, 18.0 + i * 2.0):
				printerr("FAIL: user inputs mutated, style=%s seed=%d" % [style, 5000 + i])
				failures += 1
				continue
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			if mesh == null or mesh.get_surface_count() != 4:
				printerr("FAIL: bad mesh style=%s seed=%d" % [style, 5000 + i])
				failures += 1
				continue
			var verts := 0
			for s in range(mesh.get_surface_count()):
				verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if verts < 100:
				printerr("FAIL: too few verts (%d) style=%s" % [verts, style])
				failures += 1

	# determinism check
	var a := ChurchSpec.new(0); a.style = &"gothic"
	var b := ChurchSpec.new(0); b.style = &"gothic"
	ChurchGenerator.generate(a, 42)
	ChurchGenerator.generate(b, 42)
	var ma: PackedVector3Array = ChurchBuilder.new().build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mb: PackedVector3Array = ChurchBuilder.new().build(b).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ma != mb:
		printerr("FAIL: same seed produced different geometry")
		failures += 1

	print("CHURCH TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
