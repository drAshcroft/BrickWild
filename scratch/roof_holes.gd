extends SceneTree
## Is the roof actually closed? Drop a vertical ray on a grid over the
## footprint and ask whether ANY triangle of the mesh is above it.
##
## A picture can be argued with; a coverage percentage cannot.
##
##   godot --path . --script res://scratch/roof_holes.gd

const STEP := 0.15


func _init() -> void:
	for row in [
			{"key": "cottage  ", "style": &"cottage", "w": 7.0, "l": 9.0, "h": 2.5, "s": 1, "seed": 4412},
			{"key": "farmhouse", "style": &"farmhouse", "w": 10.0, "l": 13.0, "h": 2.7, "s": 1, "seed": 4413},
			{"key": "townhouse", "style": &"townhouse", "w": 9.0, "l": 12.0, "h": 2.7, "s": 2, "seed": 4411},
			{"key": "longhall ", "style": &"longhall", "w": 12.0, "l": 16.0, "h": 2.7, "s": 1, "seed": 4414},
			{"key": "witch_hut", "style": &"witch_hut", "w": 6.0, "l": 7.0, "h": 2.4, "s": 1, "seed": 4415},
		]:
		_probe(row)
	print("")
	print("sweep: every style x 24 seeds")
	for style in HouseSweep.styles():
		var worst := 1.0
		var worst_seed := 0
		var kinds := {}
		var bad := 0
		for i in range(24):
			var spec := HouseSpec.new()
			spec.style = style
			spec.width = 6.0 + float(i % 5) * 1.6
			spec.length = 7.0 + float(i % 7) * 1.5
			spec.height = 2.5
			spec.storeys = 1 + (i % 2)
			var plan: HousePlan = HouseGenerator.generate(spec, 71000 + i)
			var cover: float = _cover(HouseBuilder.new().build(plan), spec)
			kinds[spec.roof_type] = int(kinds.get(spec.roof_type, 0)) + 1
			if cover < 0.999:
				bad += 1
			if cover < worst:
				worst = cover
				worst_seed = 71000 + i
		print("  %-11s worst cover %5.1f%% (seed %d), %d of 24 leak, roofs %s"
			% [String(style), worst * 100.0, worst_seed, bad, str(kinds)])
	quit()


func _probe(row: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = row["style"]
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	spec.storeys = int(row["s"])
	var plan: HousePlan = HouseGenerator.generate(spec, int(row["seed"]))
	var mesh: ArrayMesh = HouseBuilder.new().build(plan)
	var cover: float = _cover(mesh, spec)
	# the chimney, against the ridge it has to clear
	var wall_top: float = spec.height * mini(spec.storeys, 3)
	var ridge: float = wall_top + HouseGeometry.roof_rise(spec)
	var stack := 0.0
	var b := HouseBuilder.new()
	b.build(plan)
	for m in b.mass_log:
		if String(m["name"]).begins_with("chimney"):
			var a: AABB = m["aabb"]
			stack = maxf(stack, a.position.y + a.size.y)
	print("%s %-12s roof=%-11s cover %6.2f%%  ridge %.2f  chimney %.2f  %s"
		% [row["key"], "", String(spec.roof_type), cover * 100.0, ridge, stack,
			"OK" if stack > ridge or stack == 0.0 else "STACK BELOW RIDGE"])


## What fraction of the building footprint has mesh above it?
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
