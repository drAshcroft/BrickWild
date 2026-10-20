extends SceneTree
## Probe: site-plan a village on a tight river_valley grid (fixed centre, so the
## channel crosses the site) and list its water, roads and crossings.
##   godot --headless --path . --script res://tools/vter_crossings_probe.gd -- street river
const VT := preload("res://tests/suites/village_terrain_plan_suite.gd")
const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var form := StringName(args[0]) if args.size() > 0 else &"street"
	var water := StringName(args[1]) if args.size() > 1 else &"none"
	var s := VT.spec_for(form, null)
	s.water = water
	var flat := VillageSitePlanner.plan_flat(s)
	var half: float = flat.site.size.x * 0.5 + 1.0
	s.terrain = SYNTH.make("river_valley", Rect2(-half, -half, 2.0 * half, 2.0 * half), 5.0)
	var t0 := Time.get_ticks_msec()
	var plan := VillageSitePlanner.plan(s)
	print("plan %.1fs site=%s yaw=%.1f anchor=%s" % [(Time.get_ticks_msec() - t0) / 1000.0, plan.site, rad_to_deg(plan.site_yaw), plan.site_anchor])
	for i in plan.water.size():
		var w: Dictionary = plan.water[i]
		print("water ", i, " ", w["kind"], " ground=", w.get("ground", false), " rect=", Poly.bounding_rect(w["poly"]), " n=", w["poly"].size())
	for i in plan.roads.size():
		var r: Dictionary = plan.roads[i]
		print("road ", i, " ", r["class"], " w=", r["width"], " pts=", r["points"].size(), " ", r["points"][0], " -> ", r["points"][r["points"].size() - 1])
	for c in plan.water_crossings:
		print("crossing road=", c["road"], " water=", c["water"], " kind=", c["kind"], " pts=", c["points"])
	quit()
