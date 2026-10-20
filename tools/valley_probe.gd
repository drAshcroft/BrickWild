extends SceneTree
## Plan a valley village site (no buildings) and print roads, grades, water and
## how near the through road keeps to the river.
##   godot --headless --path . --script res://tools/valley_probe.gd -- river_valley [site_scale] [extra_lanes]

const SUITE := preload("res://tests/suites/village_valley_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "river_valley"
	var scale: float = float(args[1]) if args.size() > 1 else 1.0
	var lanes: int = int(args[2]) if args.size() > 2 else 0
	var ground: VillageTerrain = SUITE.terrain(name)
	var spec: VillageSpec = SUITE.spec_for(ground)
	print("form intent=%s planned=%s households=%d" % [spec.form_intent, spec.form, spec.households])
	var sit: Dictionary = VillageSiting.site(spec)
	print("siting terms: %s score %.2f" % [sit["terms"], sit["score"]])
	var t0 := Time.get_ticks_msec()
	var plan := VillageSitePlanner.plan(spec, lanes, scale)
	print("site %s anchor %s yaw %.1f deg (%.1f s)" % [plan.site, plan.site_anchor, rad_to_deg(plan.site_yaw), (Time.get_ticks_msec() - t0) / 1000.0])
	for r in range(plan.roads.size()):
		var rd: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = rd["points"]
		var gr: float = float(plan.ground.profile(pts)["grade_max"]) if plan.ground != null else 0.0
		print("  road %d %-7s n=%d len=%.0f from %s to %s grade %.1f%%" % [r, rd["class"], pts.size(),
			Poly.polyline_length(pts), pts[0], pts[pts.size() - 1], gr * 100.0])
	for w in plan.water:
		print("  water %s area %.0f bounds %s" % [w["kind"], Poly.area(w["poly"]), Poly.bounding_rect(w["poly"])])
		var through: PackedVector2Array = plan.roads[0]["points"]
		var line := ""
		for i in range(0, through.size(), 2):
			line += " %.0f:%.1f" % [through[i].x, VillageMeasure.point_to_poly(through[i], w["poly"])]
		print("  through road to the river (x:distance)%s" % line)
	var seeded := VillageSitePlanner._through_road(plan.site, spec, RandomNumberGenerator.new())
	var v := VillageValleyForm.read_valley(plan.site, plan.ground, seeded)
	var offs := ""
	for i in range(0, seeded.size(), 2):
		offs += " %.1f/%.1f" % [v["river"][i], v["offset"][i]]
	print("  valley found=%s wet=%s river/offset per column:%s" % [v["found"], v["wet"], offs])
	if args.size() > 3:
		var xcol := float(args[3])
		var row := ""
		var y: float = plan.site.position.y
		while y <= plan.site.end.y:
			row += " %.0f:%.1f" % [y, plan.ground.height_at(Vector2(xcol, y))]
			y += 6.0
		print("  section at x=%.0f:%s" % [xcol, row])
	quit(0)
