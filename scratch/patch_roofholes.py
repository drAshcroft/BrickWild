import io

p = 'scratch/roof_holes.gd'
s = io.open(p, encoding='utf-8').read()

old = s[s.index('## What fraction of the building footprint has mesh above it?'):]
new = '''## What fraction of the building footprint has mesh above it?
##
## Triangles are bucketed into 1 m plan cells first, so the ray test looks at
## the handful of triangles over its own cell rather than at all eight thousand.
func _cover(mesh: ArrayMesh, spec: HouseSpec) -> float:
	var wall_top: float = spec.height * mini(spec.storeys, 3)
	var buckets: Dictionary = {}
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw = arr[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = raw if raw != null else PackedInt32Array()
		var n: int = idx.size() if not idx.is_empty() else v.size()
		for i in range(0, n, 3):
			var t := PackedVector3Array([
				v[idx[i]] if not idx.is_empty() else v[i],
				v[idx[i + 1]] if not idx.is_empty() else v[i + 1],
				v[idx[i + 2]] if not idx.is_empty() else v[i + 2]])
			if maxf(t[0].y, maxf(t[1].y, t[2].y)) < wall_top + 0.05:
				continue
			var lo := Vector2i(int(floor(minf(t[0].x, minf(t[1].x, t[2].x)))),
				int(floor(minf(t[0].z, minf(t[1].z, t[2].z)))))
			var hi := Vector2i(int(floor(maxf(t[0].x, maxf(t[1].x, t[2].x)))),
				int(floor(maxf(t[0].z, maxf(t[1].z, t[2].z)))))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append(t)

	var rect: Rect2 = HouseGeometry.interior_rect(spec)
	var hit := 0
	var total := 0
	var z: float = rect.position.y + STEP * 0.5
	while z < rect.end.y:
		var x: float = rect.position.x + STEP * 0.5
		while x < rect.end.x:
			total += 1
			var here: Array = buckets.get(Vector2i(int(floor(x)), int(floor(z))), [])
			if _above(here, Vector2(x, z)):
				hit += 1
			x += STEP
		z += STEP
	return float(hit) / float(maxi(total, 1))


## Is any of these triangles directly above (x, z)?
static func _above(tris: Array, p: Vector2) -> bool:
	for t in tris:
		var a := Vector2(t[0].x, t[0].z)
		var b := Vector2(t[1].x, t[1].z)
		var c := Vector2(t[2].x, t[2].z)
		if Geometry2D.point_is_inside_triangle(p, a, b, c):
			return true
	return false
'''
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
