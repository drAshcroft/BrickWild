extends SceneTree
## Probe: pitch of every stair in edwardian towers and tower houses.
func _init() -> void:
	var rows: Array = []
	var spec := BrickWild.generate(_req(&"edwardian", 1)).spec as CastleSpec
	var prim: Dictionary = preload("res://src/castle/castle_interiors.gd").primary(spec)
	for id in prim:
		rows.append({"id": "ed_" + str(id), "plan": prim[id].plan})
	var wiz := BrickWild.generate(BrickWild.default_request(&"castle", 1, &"wizard"))
	rows.append({"id": "wizard", "plan": CastleTowerPlan.generate(wiz.spec as CastleSpec)})
	for st in [&"norman", &"edwardian", &"wizard"]:
		for sd in [1, 2, 3]:
			var s := CastleSpec.new()
			s.style = st; s.width = 12.0; s.length = 12.0; s.height = 30.0
			s.plan_override = &"tower_house"
			CastleGenerator.generate(s, sd)
			rows.append({"id": "th_%s_%d" % [st, sd], "plan": CastleTowerPlan.generate(s)})
	for row in rows:
		var plan: HousePlan = row.plan
		if plan == null or plan.spec == null: continue
		var fails := HouseStairCheck.check(plan)
		for i in plan.stairs.size():
			var st: Dictionary = plan.stairs[i]
			var r := Rect2(st["rect"])
			if not str(row.id).begins_with("ed_tower_0"): print("%s stair %d kind=%s rect=%s h=%.2f" % [row.id, i, st.get("kind", "straight"), r.size, plan.spec.height])
		for f in fails:
			if str(f).begins_with("stair_pitch") or str(f).begins_with("stair_head"):
				print("   FAIL ", row.id, " ", f)
	quit()
func _req(style, seed):
	var req := BuildingRequest.castle(seed, style)
	req.width = 55.0; req.length = 50.0; req.height = 18.0
	return req
