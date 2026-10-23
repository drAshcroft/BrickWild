extends SceneTree
## Probe: where a small smithy's forge can stand. Prints the plan's rooms,
## openings, the chosen hearth wall and the clear run of every wall of every
## workshop, then the furnishing check's failures.
##
## godot --headless --path . --script res://tools/probe_shop_forge.gd -- 9 12 1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var w := float(args[0]) if args.size() > 0 else 9.0
	var l := float(args[1]) if args.size() > 1 else 12.0
	var seed_ := int(args[2]) if args.size() > 2 else 1
	var business := StringName(args[3]) if args.size() > 3 else &"blacksmith"
	var spec := ShopSpec.new()
	spec.business = business
	spec.style = &"longhall"
	spec.width = w
	spec.length = l
	spec.height = 2.9
	var plan := ShopGenerator.generate(spec, seed_)
	print("SPEC %s %.1fx%.1f seed %d style=%s door_w=%.2f front_open=%s" % [
		business, w, l, seed_, spec.style, spec.door_w(), str(spec.front_open())])
	print("interior=%s site=%s" % [str(HouseGeometry.interior_rect(spec)), str(HouseGeometry.site_rect(spec))])
	print("hearth=%s focus=%s" % [str(plan.hearth), str(plan.focus)])
	print("need=%.2f" % HousePlanFeatures.hearth_run_needed(spec, plan))
	for i in range(plan.room_count()):
		var r: Dictionary = plan.rooms[i]
		print("room %d %s storey %d floor %s rect %s" % [i, r.kind, plan.storey_of_room(i),
			str(HouseGeometry.room_floor_rect(plan, i)), str(r.rect)])
	for d in range(plan.doors.size()):
		var door: Dictionary = plan.doors[d]
		print("door %d a=%d b=%d ext=%s pos=%s normal=%s w=%.2f" % [d, int(door.a), int(door.b),
			str(door.get("exterior", false)), str(door.pos), str(door.normal), float(door.width)])
	for wi in range(plan.windows.size()):
		var win: Dictionary = plan.windows[wi]
		print("window %d room=%d pos=%s normal=%s w=%.2f hatch=%s" % [wi, int(win.room),
			str(win.pos), str(win.normal), float(win.width), str(win.get("hatch", false))])
	for i in range(plan.room_count()):
		if plan.kind_of(i) != &"workshop":
			continue
		var walls: Array = HouseGeometry.room_walls(plan, i)
		print("-- workshop %d walls" % i)
		for wi in range(walls.size()):
			var span := HousePlanFeatures.clear_wall_span(plan, i, wi)
			print("   wall %d from %s to %s normal %s span %.2f..%.2f run %.2f" % [wi,
				str(walls[wi].from), str(walls[wi].to), str(walls[wi].normal), span.x, span.y,
				span.y - span.x])
	var cats := {}
	for p in plan.furniture:
		var cat := String(PropCatalog.category(String(p.key)))
		cats[cat] = int(cats.get(cat, 0)) + 1
	print("categories=%s" % str(cats))
	for p in plan.furniture:
		if String(PropCatalog.category(String(p.key))) == "hearth":
			print("hearth piece %s room %d rect %s" % [p.key, int(p.room), str(p.rect)])
	var rep: Dictionary = HouseFurnishCheck.new().check(plan)
	for f in rep["failures"]:
		print("FURNISH FAIL: %s" % str(f))
	for f in rep["warnings"]:
		print("FURNISH WARN: %s" % str(f))
	for f in ShopTradeSuite.trade_contract(plan, business):
		print("TRADE FAIL: %s" % str(f))
	quit()
