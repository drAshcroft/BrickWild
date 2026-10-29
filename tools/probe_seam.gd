extends SceneTree
## VTER-VISUAL-DOOR-ISLAND: the ground layers round one seam sample.
##   godot --headless --path . --script res://tools/probe_seam.gd -- real30/hallstatt -6.4 8.0
const S := preload("res://tests/suites/village_steps_walk_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(S.VTP.spec_for(&"street", null)))
	var plan := VillageLotPlanner.plan_measured(S.VTP.spec_for(&"green", S.VTP.terrain(args[0])), jobs)
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var probe := VillageGroundCheck.GroundProbe.of(mesh)
	var surf := VillageGroundSurface.of(plan)
	var c := Vector2(float(args[1]), float(args[2]))
	for j in range(-6, 7):
		var line := ""
		for i in range(-6, 7):
			var q := c + Vector2(i, j) * 0.1
			var hs := probe.heights(q)
			hs.sort()
			line += "%s k%d | " % [str(hs.map(func(h): return snappedf(h, 0.01))), surf.kind_of(surf.region_at(q))]
		print("SEAM y", snappedf(c.y + j * 0.1, 0.01), " ", line)
	quit()
