extends SceneTree
## THROWAWAY. Dump every shell vertex for the one fixture whose hash moved, so
## the diff names the emitter rather than the hash. Written against the API both
## trees share, so it runs on HEAD as well as on the working tree.

func _init() -> void:
	var s := HouseSpec.new()
	s.style = &"farmhouse"
	s.trade = &"alchemist"
	s.width = 5.5
	s.length = 7.0
	s.height = 2.4
	var plan: HousePlan = HouseGenerator.generate(s, 11268, false)
	var b := HouseBuilder.new()
	var mesh := b.build(plan)
	print("roof=%s mat=%s ridge=%.9f rise=%.9f overhang=%s total=%.9f"
		% [String(s.roof_type), String(s.roof_material), HouseGeometry.ridge_half(s),
			HouseGeometry.roof_rise(s), str(HouseGeometry.roof_overhang(s)),
			HouseGeometry.total_height(s)])
	var o: Vector2 = HouseGeometry.roof_oversail(s)
	print("terms ", var_to_str([7.0*0.5 + o.y, 5.5*0.5 + o.x, (7.0*0.5 + o.y) - (5.5*0.5 + o.x)]))
	print("terms2 ", var_to_str([7.0*0.5 + 0.25, 5.5*0.5 + 0.35, (7.0*0.5 + 0.25) - (5.5*0.5 + 0.35)]))
	print("spanlen ", var_to_str([HouseGeometry.roof_oversail(s), HouseGeometry.site_rect(s, 0)]))
	print("ridgehalf ", var_to_str(HouseGeometry.ridge_half(s)))
	for si in mesh.get_surface_count():
		var vs: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		print("SURFACE %d vertices=%d" % [si, vs.size()])
		for p in vs:
			print("  %.9f %.9f %.9f" % [p.x, p.y, p.z])
	for row in b.component_log:
		print("COMP %s host=%s form=%s" % [String(row.get("id", "")), String(row.get("host", "")), String(row.get("form", ""))])
	quit()
