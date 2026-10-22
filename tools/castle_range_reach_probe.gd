extends SceneTree
## Which occupied ranges of a walled castle can be reached from the ward?
##
## Builds the castle, reads the plan-derived walk (`CastleWalkSources`), floods
## from storey 0 and prints every range whose floor no link reaches, with the
## doors of any range named on the command line.
##
##   godot --headless --path . --script res://tools/castle_range_reach_probe.gd -- bavarian castle 55 50 3
##   godot --headless --path . --script res://tools/castle_range_reach_probe.gd -- bavarian castle 55 50 3 chapel apse
##
## arguments: style tier width length seed [range ids to detail]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var style := StringName(args[0] if args.size() > 0 else "bavarian")
	var tier := StringName(args[1] if args.size() > 1 else "castle")
	var w := float(args[2] if args.size() > 2 else 55.0)
	var l := float(args[3] if args.size() > 3 else 50.0)
	var seed_value := int(args[4] if args.size() > 4 else 3)
	var detail: Array = args.slice(5)
	var spec := CastleSpec.new()
	spec.style = style
	spec.width = w
	spec.length = l
	spec.height = 14.0 if tier != &"fortress" else 20.0
	CastleGenerator.generate(spec, seed_value)
	print("SPEC style=%s tier=%s %sx%s seed=%d plan=%s enclosed=%s barbican=%s keep=%s chapel=%s" % [
		style, spec.tier, spec.width, spec.length, spec.seed, spec.plan_kind,
		CastleGeometry.is_enclosed(spec), CastleGeometry.barbican_aabb(spec).size.x > 0.0,
		spec.keep, spec.chapel])
	print("  chapel_aabb=%s apse_aabb=%s apse_radius=%.2f walkable=%s" % [
		CastleGeometry.chapel_aabb(spec), CastleGeometry.apse_aabb(spec),
		CastleGeometry.apse_radius(spec), CastleWalkSources.supported(spec)])
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	print("  built %d interiors, %d parts in %d ms" % [builder.interiors.size(),
		builder.part_log.size(), 0])
	var rows := CastleWalkSources.rows(spec)
	var ids: Array = []
	for row in rows:
		ids.append(String(row.id))
	print("  ranges=%s" % str(ids))
	var frame := CastleWalkSources.frame(spec)
	if frame.is_empty():
		print("  NOT WALKED by CastleWalkSources")
		for row in rows:
			_dump(row, detail)
		quit()
		return
	# --- the link graph: storey 0 is the ward
	var reached := {0: true}
	var links: Array = frame.get("links", [])
	var grew := true
	while grew:
		grew = false
		for link in links:
			var a := int(link.from_storey)
			var b := int(link.to_storey)
			if reached.has(a) and not reached.has(b):
				reached[b] = true
				grew = true
			elif reached.has(b) and not reached.has(a):
				reached[a] = true
				grew = true
	# --- every range with an occupied room must be reached on that storey
	for i in rows.size():
		var row: Dictionary = rows[i]
		var plan: HousePlan = row.plan
		var away: Array = []
		for room in plan.rooms.size():
			var storey := (i + 1) * CastleWalkSources.STRIDE + HousePlan.record_storey(plan.rooms[room])
			if not reached.has(storey):
				away.append("%s@%d" % [String(plan.rooms[room].kind), storey])
		print("  %-22s %s" % [String(row.id), "REACHED" if away.is_empty() else "SEALED " + str(away)])
	for row in rows:
		_dump(row, detail)
	for link in links:
		print("    link %d -> %d  %s" % [int(link.from_storey), int(link.to_storey), str(link.get("lower", Vector2.ZERO))])
	quit()


func _dump(row: Dictionary, detail: Array) -> void:
	if not detail.is_empty() and not detail.has(String(row.id)):
		return
	var plan: HousePlan = row.plan
	print("  -- %s bounds=%s rooms=%d" % [String(row.id), row.bounds, plan.rooms.size()])
	for i in plan.rooms.size():
		print("       room %d %s %s" % [i, String(plan.rooms[i].kind),
			HouseGeometry.room_floor_rect(plan, i)])
	for d in plan.doors:
		print("       door a=%s b=%s pos=%s normal=%s ext=%s front=%s storey=%s connects_to=%s head=%s" % [
			d.get("a", -1), d.get("b", -1), d.get("pos", Vector2.ZERO), d.get("normal", Vector2.ZERO),
			d.get("exterior", false), d.get("front", false), HousePlan.record_storey(d),
			d.get("connects_to", "-"), d.get("head", -1.0)])
