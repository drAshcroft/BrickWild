extends SceneTree
## THROWAWAY. Reproduce the one bounds failure the vernacular sweep reported.


func _init() -> void:
	for storeys in [1, 2]:
		var s := HouseSpec.new()
		s.style = &"thatch_cottage"
		s.trade = &"none"
		s.width = 14.0
		s.length = 18.0
		s.height = 2.9
		s.storeys = storeys
		var plan := HouseGenerator.generate(s, 11193, false)
		var b := HouseBuilder.new()
		var mesh := b.build(plan)
		var aabb: AABB = mesh.get_aabb()
		var bound: AABB = HouseGeometry.exterior_bounds(plan)
		print("storeys=%d roof=%s ridge=%.3f rise=%.3f slab_top=%.3f"
			% [storeys, String(s.roof_type), HouseGeometry.ridge_half(s),
				HouseGeometry.roof_rise(s), HouseGeometry.roof_slab_top(s)])
		print("  mesh  min %.4f %.4f %.4f  max %.4f %.4f %.4f"
			% [aabb.position.x, aabb.position.y, aabb.position.z,
				aabb.end.x, aabb.end.y, aabb.end.z])
		var best := INF
		for si in mesh.get_surface_count():
			var vs: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for p in vs:
				if p.z < best:
					best = p.z
					print("  lowest mesh vertex on surface %d: %s" % [si, str(p)])
		print("  roof faces=%d" % b.roof_components.size())
		for row in b.roof_components:
			var pts: PackedVector3Array = row["points"]
			var lo := 0.0
			for p in pts:
				lo = minf(lo, p.z)
			if lo < -9.3:
				print("  roof comp %s role=%s minz=%.3f" % [String(row.get("id", "")),
					String(row.get("role", "")), lo])
		print("  bound min %.4f %.4f %.4f  max %.4f %.4f %.4f"
			% [bound.position.x, bound.position.y, bound.position.z,
				bound.end.x, bound.end.y, bound.end.z])
		print("  total_height(spec)=%.4f" % HouseGeometry.total_height(s))
		for f in HouseQA.check_exterior_geometry(plan, b):
			print("  FAIL ", str(f))
		# who reaches furthest on each axis?
		var worst := {"-x": 0.0, "-y": 0.0, "-z": 0.0, "+x": 0.0, "+y": 0.0, "+z": 0.0}
		for row in b.component_log:
			var a := _aabb(row)
			worst["-x"] = minf(float(worst["-x"]), a.position.x)
			worst["-y"] = minf(float(worst["-y"]), a.position.y)
			worst["-z"] = minf(float(worst["-z"]), a.position.z)
			worst["+x"] = maxf(float(worst["+x"]), a.end.x)
			worst["+y"] = maxf(float(worst["+y"]), a.end.y)
			worst["+z"] = maxf(float(worst["+z"]), a.end.z)
		print("  components reach ", str(worst))
	quit()


func _aabb(row: Dictionary) -> AABB:
	if row.has("points"):
		var pts: PackedVector3Array = row["points"]
		var lo: Vector3 = pts[0]
		var hi: Vector3 = pts[0]
		for p in pts:
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		return AABB(lo, hi - lo)
	var xf: Transform3D = row["xf"]
	var size: Vector3 = row["size"]
	return AABB(xf.origin - size * 0.5, size)
