extends SceneTree

const Roofs = preload("res://src/church/church_roofs.gd")
const RoofSuite = preload("res://tests/suites/church_roof_suite.gd")

func _init() -> void:
	var spec: ChurchSpec = TestSweep.spec_at(&"byzantine", 3)
	var builder := ChurchBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for surface in range(4):
		builder._kit.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
	builder._build_dome()
	var before := builder.commit()
	var first: int = (before.surface_get_arrays(2)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var volumes: Array[PackedVector3Array] = []
	for i in range(100):
		volumes.append(builder._roof_volumes[i])
	var start := Time.get_ticks_msec()
	Roofs.emit(spec, builder._kit, builder.mass_log, volumes)
	var mesh := builder.commit()
	var triangles := RoofSuite._triangles(mesh, 2).slice(first)
	var samples: Array = []
	var cz := ChurchGeometry.crossing_center_z(spec)
	for ix in range(17):
		for iz in range(17):
			var x := (ix - 8.0) * 0.87 + 0.031
			var z := cz + (iz - 8.0) * 0.87 + 0.047
			var heights := RoofSuite._heights(triangles, x, z, 0, 100)
			var rounded: Array[int] = []
			for h in heights:
				rounded.append(roundi(h * 1000.0))
			samples.append(rounded)
	print("SURFACE PROBE elapsed_ms=", Time.get_ticks_msec() - start,
		" roof_triangles=", triangles.size())
	print("SURFACE PROBE sampled_digest=", _digest(var_to_bytes(samples)),
		" logs_digest=", _digest(var_to_bytes([builder.part_log, builder.mass_log, builder.component_log])))
	FileAccess.open("res://artifacts/qa_perf_003/samples.json", FileAccess.WRITE).store_string(JSON.stringify(samples))
	quit()

func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
