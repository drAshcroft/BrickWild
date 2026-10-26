extends SceneTree
## Read a castle's interior failures as a plan: rooms, areas, furniture, doors.
##
## Builds the castle, runs HouseQA on every interior plan (the same report
## CastleQA folds into `interiors[<id>]`), and prints each room's kind, floor
## rect, area, furnished share and furniture, plus every door. With row ids on
## the command line only those rows are detailed; failures are always printed.
##
##   godot --headless --path . --script res://tools/castle_interior_probe.gd -- sweep crusader castle 1
##   godot --headless --path . --script res://tools/castle_interior_probe.gd -- build norman house 90 140 9250 keep
##
## arguments: sweep <style> <tier> <index> [row ids]
##            build <style> <tier> <width> <length> <seed> [row ids]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("need sweep|build first")
		quit()
		return
	var mode := String(args[0])
	var spec: CastleSpec
	var detail: Array = []
	if mode == "sweep":
		var style := StringName(args[1] if args.size() > 1 else "crusader")
		var tier := StringName(args[2] if args.size() > 2 else "castle")
		var index := int(args[3] if args.size() > 3 else 1)
		spec = CastleSweep.spec_at(style, tier, index)
		detail = args.slice(4)
	else:
		spec = CastleSpec.new()
		spec.style = StringName(args[1] if args.size() > 1 else "crusader")
		spec.width = float(args[3] if args.size() > 3 else 90.0)
		spec.length = float(args[4] if args.size() > 4 else 140.0)
		spec.height = 20.0
		# A fixture that overrides the plan says so through the environment, so
		# the positional arguments keep the same meaning as the sweep form.
		if OS.get_environment("BW_PLAN") != "":
			spec.plan_override = StringName(OS.get_environment("BW_PLAN"))
		CastleGenerator.generate(spec, int(args[5] if args.size() > 5 else 9118))
		detail = args.slice(6)
	print("SPEC style=%s tier=%s %.0fx%.0f seed=%d plan=%s keep=%s hall=%s" % [spec.style,
		spec.tier, spec.width, spec.length, spec.seed, spec.plan_kind, spec.keep, spec.hall])
	var builder := CastleBuilder.new()
	builder.build(spec)
	print("  %d interiors, %d interior errors" % [builder.interiors.size(), builder.interior_errors.size()])
	for error in builder.interior_errors:
		print("  ERROR %s" % error)
	for row in builder.interiors:
		var plan: HousePlan = row.plan
		var report := HouseQA.new().check(plan, null)
		print("")
		print("== %s bounds=%s rooms=%d furniture=%d" % [String(row.id), row.bounds,
			plan.rooms.size(), plan.furniture.size()])
		if not plan.focus.is_empty():
			print("   focus room=%d cat=%s pos=%s facing=%.3f faces_door=%s" % [
				plan.focus_room(), plan.focus_cat(), plan.focus_pos(),
				plan.focus_facing(), plan.focus_faces_door()])
		for failure in report.failures:
			print("   FAIL %s" % failure)
		for warning in report.warnings:
			print("   warn %s" % warning)
		if not detail.is_empty() and not detail.has(String(row.id)):
			continue
		for i in plan.rooms.size():
			_room(plan, i)
		for d in plan.doors:
			print("   door a=%s b=%s pos=%s normal=%s ext=%s front=%s storey=%s connects_to=%s" % [
				d.get("a", -1), d.get("b", -1), d.get("pos", Vector2.ZERO),
				d.get("normal", Vector2.ZERO), d.get("exterior", false),
				d.get("front", false), HousePlan.record_storey(d), d.get("connects_to", "-")])
	quit()


func _room(plan: HousePlan, i: int) -> void:
	var floor_rect := HouseGeometry.room_floor_rect(plan, i)
	var area := HouseGeometry.room_area(plan, i)
	var used := 0.0
	var keys: Array = []
	for f in plan.furniture_of(i):
		var p: Dictionary = plan.furniture[f]
		keys.append("%s%s@%s" % [String(p["key"]),
			"+" if p.get("mounted", false) else "", Rect2(p["rect"]).position])
		if HouseFurnishWalkCheck._on_floor(p) \
				or (HouseFurnishWalkCheck._is_table(String(p["key"])) and not p.get("mounted", false)):
			used += Rect2(p["rect"]).get_area()
	var share := (used / area * 100.0) if area > 0.0 else 0.0
	var flags := []
	if HouseFurnishWalkCheck._corridor(floor_rect):
		flags.append("CORRIDOR")
	if not HouseGeometry.is_habitable(plan.kind_of(i)):
		flags.append("not-habitable")
	print("   room %d %-16s %s area=%.1f furnished=%.0f%% storey=%s %s" % [i,
		String(plan.rooms[i].kind), floor_rect, area, share,
		HousePlan.record_storey(plan.rooms[i]), " ".join(PackedStringArray(flags))])
	print("       %s" % " ".join(PackedStringArray(keys)))
