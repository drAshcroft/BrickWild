extends SceneTree
## What a bailey shop's own shell cuts, and what the castle log forwards.
##
## Builds only the yard record (no castle), so it is cheap: a fortress spec,
## one shop plan, one house shell. Prints the plan's windows beside the child's
## wall apertures, then the list `CastleInteriors.emit` would forward today.
##
##   godot --headless --path . --script res://tools/castle_yard_hatch_probe.gd -- general_store
##   godot --headless --path . --script res://tools/castle_yard_hatch_probe.gd -- general_store norman fortress 1
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var business := StringName(args[0] if args.size() > 0 else "general_store")
	var style := StringName(args[1] if args.size() > 1 else "norman")
	var tier := StringName(args[2] if args.size() > 2 else "fortress")
	var index := int(args[3]) if args.size() > 3 else 1
	var spec := CastleSweep.spec_at(style, tier, index)
	print("SPEC %s %s seed=%d %.0fx%.0f" % [spec.style, spec.tier, spec.seed,
		spec.width, spec.length])
	var entry := {}
	for candidate in CastleGenerator.bailey_buildings(spec):
		if candidate.business == business:
			entry = candidate
			break
	if entry.is_empty():
		print("no %s among %s" % [business,
			CastleGenerator.bailey_buildings(spec).map(func(e): return String(e.business))])
		quit(1)
		return
	var row: Dictionary = preload("res://src/castle/castle_interiors.gd").yard(spec, entry)
	var plan: HousePlan = row.plan
	if plan == null or plan.spec == null:
		print("yard plan failed: %s" % row.get("errors", []))
		quit(1)
		return
	print("== %s rooms=%d doors=%d windows=%d yaw=%.3f" % [row.id, plan.rooms.size(),
		plan.doors.size(), plan.windows.size(), float(entry.yaw)])
	for window in plan.windows:
		print("   plan  room=%s pos=%s normal=%s width=%.2f sill=%.2f head=%.2f hatch=%s" % [
			str(window.get("room", -1)), str(window.get("pos", Vector2.ZERO)),
			str(window.get("normal", Vector2.ZERO)), float(window.get("width", 0.0)),
			float(window.get("sill", 0.0)), float(window.get("head", 0.0)),
			str(window.get("hatch", false))])
	var child := HouseBuilder.new()
	child.build(plan, false)
	var wall_apertures := 0
	var forward_now := 0
	for part in child.part_log:
		var kind := String(part.get("opening_kind", ""))
		if kind == "":
			continue
		var role := String(part.get("kind", ""))
		if role == "window" and kind in ["window", "hatch", "door"]:
			wall_apertures += 1
		var forwarded: bool = role == "window" and kind in ["window", "door"]
		if forwarded:
			forward_now += 1
		print("   child %-9s role=%-12s forwarded=%s pos=%s size=%s" % [kind, role,
			str(forwarded), str(part.get("pos", Vector3.ZERO)),
			str(part.get("size", Vector3.ZERO))])
	print("   header: %d wall apertures cut, %d forwarded by the current filter" % [
		wall_apertures, forward_now])
	quit()
