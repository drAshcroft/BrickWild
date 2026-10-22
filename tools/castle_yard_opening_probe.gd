extends SceneTree
## Why has a yard shop a planned window the castle part log cannot show?
##
## Builds a fortress, runs CastleOccupancyCheck for the real failure list, then
## prints every yard row's plan windows beside the child HouseBuilder's own
## opening records, which is what `CastleInteriors.emit` forwards.
##
##   godot --headless --path . --script res://tools/castle_yard_opening_probe.gd -- norman
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var style := StringName(args[0] if not args.is_empty() else "norman")
	var spec := CastleSweep.spec_at(style, &"fortress", 0)
	print("SPEC %s %s seed=%d %.0fx%.0f" % [spec.style, spec.tier, spec.seed,
		spec.width, spec.length])
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var occupancy := CastleOccupancyCheck.check(spec, builder, mesh)
	print("occupancy ok=%s failures=%d" % [occupancy.ok, occupancy.failures.size()])
	for failure in occupancy.failures:
		print("   FAIL %s" % failure)
	for row in builder.interiors:
		var id := String(row.get("id", ""))
		if not id.begins_with("yard_"):
			continue
		var plan: HousePlan = row.plan
		print("")
		print("== %s rooms=%d windows=%d" % [id, plan.rooms.size(), plan.windows.size()])
		var child: HouseBuilder = row.get("builder")
		if child != null:
			for part in child.part_log:
				var kind := String(part.get("opening_kind", ""))
				if kind == "":
					continue
				print("   child %-6s pos=%-34s facing=%-22s size=%s tag=%s" % [kind,
					str(part.get("pos", Vector3.ZERO)),
					str(part.get("facing", Vector3.ZERO)),
					str(part.get("size", Vector3.ZERO)), str(part.get("tag", ""))])
		for window in plan.windows:
			print("   plan room=%s pos=%s normal=%s width=%.2f sill=%.2f head=%.2f hatch=%s" % [
				str(window.get("room", -1)), str(window.get("pos", Vector2.ZERO)),
				str(window.get("normal", Vector2.ZERO)), float(window.get("width", 0.0)),
				float(window.get("sill", 0.0)), float(window.get("head", 0.0)),
				str(window.get("hatch", false))])
		for part in builder.part_log:
			if String(part.get("tag", "")) != id:
				continue
			print("   castle %-6s pos=%-34s facing=%-22s size=%s" % [
				str(part.get("opening_kind", part.get("kind", ""))),
				str(part.get("pos", Vector3.ZERO)), str(part.get("facing", Vector3.ZERO)),
				str(part.get("size", Vector3.ZERO))])
	quit()
