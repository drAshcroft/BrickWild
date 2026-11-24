extends SceneTree
## BG-015 scratch: is a projected obstruction (carve = false) grown by the
## agent radius in Godot 4.5's 3D baker, and how far off a rotated one does the
## floor stay? A 20 m floor, a 4 m square obstruction turned `deg`.

func _init() -> void:
	for deg in [0.0, 17.0, 45.0]:
		for carve in [false, true]:
			var src := NavigationMeshSourceGeometryData3D.new()
			var f := PackedVector3Array([Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(10, 0, 10),
				Vector3(-10, 0, -10), Vector3(10, 0, 10), Vector3(-10, 0, 10)])
			src.add_faces(f, Transform3D.IDENTITY)
			var sq := PackedVector3Array()
			var poly := PackedVector2Array()
			for c in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
				var r: Vector2 = (c as Vector2).rotated(deg_to_rad(deg)) + Vector2(0.13, 0.07)
				sq.append(Vector3(r.x, 0, r.y))
				poly.append(r)
			src.add_projected_obstruction(sq, -10.0, 100.0, carve)
			var nm := NavigationMesh.new()
			nm.cell_size = 0.25
			nm.cell_height = 0.02
			nm.agent_radius = 0.25
			nm.agent_height = 1.8
			nm.agent_max_climb = 0.24
			nm.edge_max_error = 0.5
			nm.edge_max_length = 4.0
			NavigationServer3D.bake_from_source_geometry_data(nm, src)
			# boundary edges near the square: their distance from it
			var count := {}
			for i in nm.get_polygon_count():
				var p := nm.get_polygon(i)
				for k in p.size():
					var key := Vector2i(mini(p[k], p[(k + 1) % p.size()]), maxi(p[k], p[(k + 1) % p.size()]))
					count[key] = int(count.get(key, 0)) + 1
			var lo := INF
			var hi := 0.0
			var n := 0
			for key in count:
				if int(count[key]) != 1:
					continue
				var a := Vector2(nm.vertices[key.x].x, nm.vertices[key.x].z)
				var b := Vector2(nm.vertices[key.y].x, nm.vertices[key.y].z)
				if a.length() > 6.0 and b.length() > 6.0:
					continue
				var d := VillageWalk3D.segment_to_poly(a, b, poly)
				lo = minf(lo, d)
				hi = maxf(hi, d)
				n += 1
			print("deg %4.0f carve %s: %d edges round the square, nearest %.3f m, farthest %.3f m" % [deg, carve, n, lo, hi])
	quit()
