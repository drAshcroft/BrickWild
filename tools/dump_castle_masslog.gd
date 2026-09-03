extends SceneTree
## Regression dump: every castle in the canonical sweep, as its mass_log.
##
## The polygonal-enceinte work (CAS-001) has to leave the rectangular plan
## bit-for-bit where it was, and mass_log is the record every massing check
## reads. Dump before the change, dump after, diff the two files.
##
##   godot --headless --path . --script res://tools/dump_castle_masslog.gd
##   godot --headless --path . --script res://tools/dump_castle_masslog.gd -- \
##       artifacts/masslog_after.txt rect
##
## Arg 1 is the output path, arg 2 forces `plan_override` on every spec (use
## `rect` to dump the plan the baseline was recorded with).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "artifacts/masslog.txt"
	var force: String = args[1] if args.size() > 1 else ""
	var lines := PackedStringArray()
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				if force != "":
					spec.set("plan_override", StringName(force))
					CastleGenerator.generate(spec, CastleSweep.seed_at(tier, i))
				var builder := CastleBuilder.new()
				builder.build(spec)
				lines.append("# %s %s %d seed=%d" % [String(style), String(tier), i,
					CastleSweep.seed_at(tier, i)])
				for m in builder.mass_log:
					var a: AABB = m["aabb"]
					lines.append("%s %s %s %s %s %s %s" % [m["name"],
						String.num(a.position.x, 9), String.num(a.position.y, 9),
						String.num(a.position.z, 9), String.num(a.size.x, 9),
						String.num(a.size.y, 9), String.num(a.size.z, 9)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote %s (%d lines)" % [out_path, lines.size()])
	quit(0)
