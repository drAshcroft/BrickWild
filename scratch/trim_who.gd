extends SceneTree
## Which TRIM box is the one standing proud? Chunk the stream into boxes and
## report each box together with how far its top rises above the roof.


func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 6.0
	spec.length = 11.5
	spec.height = 2.5
	spec.storeys = 1
	var plan: HousePlan = HouseGenerator.generate(spec, 74010)
	var mesh: ArrayMesh = HouseBuilder.new().build(plan)
	var wall_top: float = spec.height
	var rise: float = HouseGeometry.roof_rise(spec)
	var site: Rect2 = HouseGeometry.site_rect(spec)
	print("cottage 6.0 x 11.5  roof=%s truss=%s bargeboards=%s dormers=%s"
		% [String(spec.roof_type), String(spec.gable_truss),
			str(spec.bargeboards), str(spec.dormers)])
	print("wall top %.2f  rise %.2f  ridge %.2f  site %s"
		% [wall_top, rise, wall_top + rise, str(site)])
	var v: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
	var n := 0
	for i in range(0, v.size(), 36):
		var a := AABB(v[i], Vector3.ZERO)
		for k in range(i, mini(i + 36, v.size())):
			a = a.expand(v[k])
		var top: float = a.position.y + a.size.y
		if top < wall_top + 0.2:
			continue
		n += 1
		var mark := ""
		if top > wall_top + rise + 0.1:
			mark = "  ABOVE RIDGE by %.2f" % (top - wall_top - rise)
		print("  %2d centre %s size %s  y %.2f..%.2f%s"
			% [n, _v(a.get_center()), _v(a.size), a.position.y, top, mark])
	quit()


static func _v(p: Vector3) -> String:
	return "(%6.2f,%6.2f,%6.2f)" % [p.x, p.y, p.z]
