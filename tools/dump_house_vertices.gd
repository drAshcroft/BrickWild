extends SceneTree
## Fingerprint every vertex the house builder emits for the runbook fixtures.
## Two checkouts that print the same lines emit the same geometry -- which is
## how a "logging only" change proves it moved nothing (HOUSE-EXT-005).

func _init() -> void:
	var lines := PackedStringArray()
	for row in [[&"farmhouse", 4413, 10.0, 13.0, 2.7, 1],
			[&"townhouse", 4411, 9.0, 12.0, 2.7, 2],
			[&"cottage", 4412, 7.0, 9.0, 2.5, 1],
			[&"longhall", 4414, 12.0, 16.0, 2.7, 1]]:
		var s := HouseSpec.new()
		s.style = row[0]
		s.width = row[2]
		s.length = row[3]
		s.height = row[4]
		s.storeys = row[5]
		var plan := HouseGenerator.generate(s, row[1], false)
		for with_roof in [true, false]:
			var mesh := HouseBuilder.new().build(plan, with_roof)
			for si in range(mesh.get_surface_count()):
				var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				var acc := 0
				var sum := Vector3.ZERO
				for p in v:
					sum += p
					acc = (acc * 31 + roundi(p.x * 100000.0)) % 1000000007
					acc = (acc * 31 + roundi(p.y * 100000.0)) % 1000000007
					acc = (acc * 31 + roundi(p.z * 100000.0)) % 1000000007
				lines.append("%s roof=%s surf=%d verts=%d hash=%d sum=%.5f,%.5f,%.5f"
					% [row[0], with_roof, si, v.size(), acc, sum.x, sum.y, sum.z])
	for l in lines:
		print(l)
	quit()
