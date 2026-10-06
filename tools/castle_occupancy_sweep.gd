extends SceneTree
## Occupancy sweep over the canonical castle grid: build every case, run the
## occupancy and route checks and each plan's HouseQA, print failures grouped
## by message. Much cheaper than the full CastleQA voxel pass and the quickest
## way to see which FORM of a family is still solid or unreachable.
##
##   godot --headless --path . --script res://tools/castle_occupancy_sweep.gd -- fortress norman 1
##   arguments: tiers (comma list, default all) styles (comma list or all) index (0..2 or all)
##
## A fortress case costs one to five minutes; redirect the log to a file.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tiers: Array = args[0].split(",") if args.size() > 0 else ["house", "manor", "castle", "fortress"]
	var styles: Array = CastleSweep.styles()
	if args.size() > 1 and args[1] != "all":
		styles = args[1].split(",")
	var indices: Array = [0, 1, 2]
	if args.size() > 2 and args[2] != "all":
		indices = [int(args[2])]
	for tier in tiers:
		for style in styles:
			for i in indices:
				var spec := CastleSweep.spec_at(StringName(style), StringName(tier), i)
				var t := Time.get_ticks_msec()
				var builder := CastleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				var fails: Array = []
				for e in builder.interior_errors:
					fails.append("interior_error " + str(e))
				fails.append_array(CastleOccupancyCheck.check(spec, builder, mesh).failures)
				var route := CastleRouteCheck.check(builder, mesh)
				fails.append_array(route.failures)
				for row in builder.interiors:
					var r := HouseQA.new().check(row.plan, null)
					for f in r.failures:
						fails.append("interiors[%s]: %s" % [row.id, f])
				var kinds := {}
				for f in fails:
					var key := str(f).substr(0, 90)
					kinds[key] = int(kinds.get(key, 0)) + 1
				print("CASE %s %s %d seed=%d %s fails=%d (%ds)" % [style, tier, i, spec.seed, spec.plan_kind, fails.size(), (Time.get_ticks_msec() - t) / 1000])
				for key in kinds:
					print("    %dx %s" % [kinds[key], key])
	quit()
