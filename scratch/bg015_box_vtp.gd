extends SceneTree
## BG-015 scratch: the walk's polygons and the obstacles in a plan box, baked
## both ways. args: fixture form x0 z0 x1 z1
const LANE := preload("res://tests/suites/village_terrain_plan_suite.gd")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var box := Rect2(Vector2(float(a[2]), float(a[3])), Vector2(float(a[4]) - float(a[2]), float(a[5]) - float(a[3])))
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	var plan := VillageLotPlanner.plan_measured(LANE.spec_for(StringName(a[1]), LANE.terrain(a[0])), jobs)
	var surface := VillageGroundSurface.of(plan)
	for mode in [{}, {"footprints": true}]:
		var m3: Dictionary = VillageWalk3D.bake(plan, mode)
		var isl := VillageWalk3D.islands(m3)
		print("== ", "footprints" if not mode.is_empty() else "built")
		var built := VillageWalk3D.built_outlines(plan, mode)
		for poly in VillageWalk3D.obstacle_outlines(plan, built) + VillageWalk3D.corner_pads(plan, built):
			if Poly.bounding_rect(poly).intersects(box):
				print("  obstacle ", poly)
		for i in (m3["polygons"] as Array).size():
			var poly: PackedInt32Array = m3["polygons"][i]
			var pts := []
			var inside := false
			for k in poly:
				var v: Vector3 = m3["vertices"][k]
				pts.append(Vector3(snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)))
				inside = inside or box.has_point(Vector2(v.x, v.z))
			if inside:
				print("  poly %d island %d %s" % [i, isl[i], pts])
	# the regions under the box
	for z in range(int(box.position.y * 4), int(box.end.y * 4) + 1):
		var row := ""
		for x in range(int(box.position.x * 4), int(box.end.x * 4) + 1):
			var p := Vector2(x / 4.0 + 0.125, z / 4.0 + 0.125)
			row += str(surface.kind_of(surface.region_at(p)))
		print("  z %.2f %s" % [z / 4.0 + 0.125, row])
	quit()
