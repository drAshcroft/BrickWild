extends SceneTree
## Every slab the roof is made of, in emission order.
##
## MeshKit._emit_box writes 6 quads = 12 triangles = 36 vertices per box, and
## nothing else on these surfaces emits in another shape, so chunking the
## vertex stream by 36 recovers the boxes the builder actually asked for. That
## turns "there seem to be extra planes" into a list with names against it.


func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.7
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 4411)
	var mesh: ArrayMesh = HouseBuilder.new().build(plan)
	var wall_top: float = spec.height * spec.storeys
	var rise: float = HouseGeometry.roof_rise(spec)
	var site: Rect2 = HouseGeometry.site_rect(spec)
	print("townhouse 9 x 12 x 2.7 x2  roof=%s bargeboards=%s truss=%s"
		% [String(spec.roof_type), str(spec.bargeboards), String(spec.gable_truss)])
	print("wall top %.2f  rise %.2f  ridge %.2f  site %s"
		% [wall_top, rise, wall_top + rise, str(site)])
	for surf in [HouseBuilder.SURF_ROOF, HouseBuilder.SURF_TRIM]:
		print("--- surface %d (%s), boxes whose top is above the wall head"
			% [surf, "ROOF" if surf == HouseBuilder.SURF_ROOF else "TRIM"])
		var v: PackedVector3Array = mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]
		var n := 0
		for i in range(0, v.size(), 36):
			var a := AABB(v[i], Vector3.ZERO)
			for k in range(i, mini(i + 36, v.size())):
				a = a.expand(v[k])
			if a.position.y + a.size.y < wall_top + 0.05:
				continue
			n += 1
			var past_x: float = maxf(site.position.x - a.position.x,
				a.position.x + a.size.x - site.end.x)
			var past_z: float = maxf(site.position.y - a.position.z,
				a.position.z + a.size.z - site.end.y)
			var over: String = ""
			if a.position.y + a.size.y > wall_top + rise + 0.06:
				over += " ABOVE-RIDGE(+%.2f)" % (a.position.y + a.size.y - wall_top - rise)
			if maxf(past_x, past_z) > 0.40:
				over += " PAST-WALL(%.2f)" % maxf(past_x, past_z)
			print("  %2d  centre %s  size %s  y %.2f..%.2f%s"
				% [n, _v(a.get_center()), _v(a.size), a.position.y,
					a.position.y + a.size.y, over])
	quit()


static func _v(p: Vector3) -> String:
	return "(%6.2f,%6.2f,%6.2f)" % [p.x, p.y, p.z]
