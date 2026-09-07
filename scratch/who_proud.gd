extends SceneTree
## Name the box that is still standing proud on cottage seed 74009.


func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 6.0 + 4.0 * 1.6
	spec.length = 7.0 + 2.0 * 1.5
	spec.height = 2.5
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 74009)
	var b := HouseBuilder.new()
	var mesh: ArrayMesh = b.build(plan)
	var wall_top: float = spec.height * spec.storeys
	var rise: float = HouseGeometry.roof_rise(spec)
	print("cottage %.1f x %.1f storeys %d  roof=%s  wall_top %.2f rise %.2f ridge %.2f"
		% [spec.width, spec.length, spec.storeys, String(spec.roof_type),
			wall_top, rise, wall_top + rise])
	print("chimney=%s chimney_style=%s" % [str(spec.chimney), String(spec.chimney_style)])
	for m in b.mass_log:
		if String(m["name"]).begins_with("chimney"):
			print("  mass %s %s" % [String(m["name"]), str(m["aabb"])])
	var v: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
	for i in range(0, v.size(), 36):
		var a := AABB(v[i], Vector3.ZERO)
		for k in range(i, mini(i + 36, v.size())):
			a = a.expand(v[k])
		if a.position.y + a.size.y < wall_top + rise + 0.1:
			continue
		print("  TRIM box centre %s size %s y %.2f..%.2f"
			% [str(a.get_center().snappedf(0.01)), str(a.size.snappedf(0.01)),
				a.position.y, a.position.y + a.size.y])
	quit()
