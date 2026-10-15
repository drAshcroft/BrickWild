extends SceneTree
## Tower-house occupancy sweep: every style x several seeds/footprints with
## plan_override = tower_house, run through the occupancy and route checks and
## each plan's HouseQA; failures are grouped by message.
##
##   godot --headless --path . --script res://tools/castle_tower_house_sweep.gd -- [styles|all] [seeds]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var styles: Array = CastleSweep.styles()
	if args.size() > 0 and args[0] != "all":
		styles = args[0].split(",")
	var seeds: Array = [8803, 8804, 8805, 9001, 9249, 9331]
	if args.size() > 1:
		seeds = Array(args[1].split(",")).map(func(s): return int(s))
	var sizes := [[8.0, 8.0, 45.0], [14.0, 12.0, 34.0], [10.0, 10.0, 24.0]]
	for style in styles:
		for sd in seeds:
			for sz in sizes:
				var spec := CastleSpec.new()
				spec.style = StringName(style)
				spec.width = sz[0]
				spec.length = sz[1]
				spec.height = sz[2]
				spec.plan_override = &"tower_house"
				CastleGenerator.generate(spec, int(sd))
				if spec.plan_kind != &"tower_house":
					continue
				var t := Time.get_ticks_msec()
				var builder := CastleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				var fails: Array = []
				for e in builder.interior_errors:
					fails.append("interior_error " + str(e))
				fails.append_array(CastleOccupancyCheck.check(spec, builder, mesh).failures)
				fails.append_array(CastleRouteCheck.check(builder, mesh).failures)
				for row in builder.interiors:
					for f in HouseQA.new().check(row.plan, null).failures:
						fails.append("interiors[%s]: %s" % [row.id, f])
				var kinds := {}
				for f in fails:
					var key := str(f).substr(0, 110)
					kinds[key] = int(kinds.get(key, 0)) + 1
				print("CASE %s seed=%d %sx%sx%s wings=%d fails=%d (%dms)" % [style, sd, sz[0], sz[1], sz[2], spec.wings, fails.size(), Time.get_ticks_msec() - t])
				for key in kinds:
					print("    %dx %s" % [kinds[key], key])
	quit()
