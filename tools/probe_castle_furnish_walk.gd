extends SceneTree
## Dump a castle's interior plans: rooms, furniture, stairs, doors (CASTLE-FURNISH-WALK).
##   -- <style> <seed> [row ids]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var style := StringName(a[0]); var seed := int(a[1])
	var req := BuildingRequest.castle(seed, style)
	req.width = 55.0; req.length = 50.0; req.height = 18.0
	var spec := BrickWild.generate(req).spec as CastleSpec
	var b := CastleBuilder.new()
	b.build(spec)
	for row in b.interiors:
		var plan: HousePlan = row.plan
		var id := String(row.id)
		if a.size() > 2 and not a.slice(2).has(id):
			for r in plan.room_count():
				var bl := CastleKeepPlan.walkway_blockers(plan, r)
				if not bl.is_empty():
					print("WALKWAY %s room %d %s: %s" % [id, r, plan.kind_of(r), bl.map(func(i): return plan.furniture[i].key)])
			for f in HouseStairCheck.check(plan):
				print("STAIRFAIL %s %s" % [id, f])
			print("-- %s rooms=%d furn=%d stairs=%d" % [id, plan.rooms.size(), plan.furniture.size(), plan.stairs.size()])
			continue
		print("== %s" % id)
		for r in plan.room_count():
			var bl := CastleKeepPlan.walkway_blockers(plan, r)
			if not bl.is_empty():
				print("  WALKWAY room %d %s: %s" % [r, plan.kind_of(r), bl.map(func(i): return plan.furniture[i].key)])
		if OS.get_environment("BARE") != "":
			var bare := plan.furniture.duplicate()
			plan.furniture.clear()
			for f in HouseStairCheck.check(plan):
				print("  BARE %s" % f)
			plan.furniture.assign(bare)
		for i in plan.rooms.size():
			var r: Dictionary = plan.rooms[i]
			print("  room %d %s st=%s rect=%s" % [i, r.kind, r.get("storey"), r.rect])
		for f in plan.furniture:
			print("  F %s" % [f])
		for s in plan.stairs:
			print("  S rect=%s a=%s b=%s climb=%s foot=%s head=%s" % [s.get("rect"), s.get("a"), s.get("b"), s.get("climb"), s.get("foot_landing"), s.get("head_landing")])
		for d in plan.doors:
			print("  D %s" % [d])
		print("  hearth=%s" % [plan.hearth])
		for f in HouseStairCheck.check(plan):
			print("  STAIRFAIL %s" % f)
	quit()
