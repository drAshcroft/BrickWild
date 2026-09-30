extends SceneTree

func _init() -> void:
	var spec: ChurchSpec = TestSweep.spec_at(&"byzantine", 3)
	print("BUILD PROFILE seed=", spec.seed, " half=", spec.half_domes)
	var start := Time.get_ticks_msec()
	var builder := ChurchBuilder.new()
	var mesh := builder.build(spec)
	print("BUILD PROFILE done surfaces=", mesh.get_surface_count(),
		" elapsed_ms=", Time.get_ticks_msec() - start)
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		print("BUILD FINGERPRINT surface=", surface,
			" vertices=", (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
			" sha256=", _digest(var_to_bytes(arrays)))
	print("BUILD FINGERPRINT logs=", _digest(var_to_bytes([
		builder.part_log, builder.mass_log, builder.component_log])))
	quit()


func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
