extends SceneTree
## Writes furnished house plans as JSON -- rooms, doors, windows, stairs, the
## hearth and every piece of furniture with its footprint -- so an interior can
## be drawn from above and judged against interior-design rules outside Godot
## (tools/interiors/draw_interiors.py, tools/interiors/design_audit.py).
##   godot --headless --path . --script res://tools/dump_interiors_json.gd -- \
##       out=artifacts/interior_research/plans.json cases=cottage:1,townhouse:2,rich:1
## A case is style[:seed[:purpose[:storeys[:period_seating]]]]. Through the public path, as the walk rig is.


func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		if "=" in s:
			a[s.get_slice("=", 0)] = s.get_slice("=", 1)
	var out_path := String(a.get("out", "artifacts/interior_research/plans.json"))
	var cases := String(a.get("cases", "cottage:1")).split(",", false)
	var rows: Array = []
	for c in cases:
		var parts := c.split(":")
		var req := BrickWild.default_request(&"house", int(parts[1]) if parts.size() > 1 else 1,
			StringName(parts[0]))
		if parts.size() > 2 and parts[2] != "":
			req.purpose = StringName(parts[2])
		if parts.size() > 3 and parts[3] != "":
			req.storeys = int(parts[3])
		if parts.size() > 4 and parts[4] != "":
			req.period_seating = StringName(parts[4])
		var t0 := Time.get_ticks_msec()
		var b := BrickWild.generate(req)
		var t1 := Time.get_ticks_msec()
		var plan := b.plan as HousePlan
		if plan == null:
			printerr("no house plan for ", c, ": ", b.errors)
			continue
		rows.append(_plan_row(c, plan))
		print("dumped ", c, ": ", plan.room_count(), " rooms, ", plan.furniture.size(), " pieces; generate ", t1 - t0, " ms, row ", Time.get_ticks_msec() - t1, " ms")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write ", out_path)
		quit(1)
		return
	f.store_string(JSON.stringify({"schema": "brickwild.interiors", "plans": rows}, "  "))
	f.close()
	quit()


static func _r(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


static func _v(v: Variant) -> Array:
	if v is Vector2:
		return [v.x, v.y]
	if v is Vector3:
		return [v.x, v.y, v.z]
	return []


static func _plan_row(case_id: String, plan: HousePlan) -> Dictionary:
	var rooms: Array = []
	for i in plan.room_count():
		var room: Dictionary = plan.rooms[i]
		var outline: Array = []
		for p in plan.outline_of(i):
			outline.append([p.x, p.y])
		rooms.append({"i": i, "kind": String(plan.kind_of(i)), "storey": plan.storey_of_room(i),
			"rect": _r(room.get("rect", Rect2())), "outline": outline,
			"area": HouseGeometry.room_area(plan, i)})
	var doors: Array = []
	for d in plan.doors.size():
		var door: Dictionary = plan.doors[d]
		doors.append({"i": d, "a": int(door.get("a", -1)), "b": int(door.get("b", -1)),
			"pos": _v(door.get("pos")), "normal": _v(door.get("normal")),
			"width": float(door.get("width", 0.9)), "exterior": bool(door.get("exterior", false)),
			"front": bool(door.get("front", false)), "storey": HousePlan.record_storey(door)})
	var windows: Array = []
	for w in plan.windows.size():
		var win: Dictionary = plan.windows[w]
		windows.append({"i": w, "room": int(win.get("room", -1)), "pos": _v(win.get("pos")),
			"normal": _v(win.get("normal")), "width": float(win.get("width", 0.8)),
			"storey": HousePlan.record_storey(win)})
	var stairs: Array = []
	for s in plan.stairs:
		stairs.append({"storey": int(s.get("storey", 0)), "to": int(s.get("to_storey", 1)),
			"lower": _r(s.get("lower_rect", s.get("rect", Rect2()))),
			"upper": _r(s.get("upper_rect", Rect2()))})
	var furniture: Array = []
	for f in plan.furniture.size():
		var p: Dictionary = plan.furniture[f]
		var key := String(p.get("key", ""))
		furniture.append({"i": f, "key": key, "cat": PropCatalog.category(key),
			"room": int(p.get("room", -1)), "storey": HousePlan.record_storey(p),
			"rect": _r(p.get("rect", Rect2())), "pos": _v(p.get("pos")),
			"yaw": float(p.get("yaw", 0.0)), "host": int(p.get("host", -1)),
			"mounted": bool(p.get("mounted", false)), "group": String(p.get("activity_group", "")),
			"zone": _r(p.get("zone", Rect2()))})
	var hearth := {}
	if not plan.hearth.is_empty():
		hearth = {"room": plan.hearth_room(), "wall": plan.hearth_wall()}
	var fire := plan.open_fire()
	if hearth.is_empty() and not fire.is_empty():
		hearth = {"room": int(fire.get("room", -1)), "wall": -1, "open": true,
			"kerb": _r(fire.get("hearth", Rect2()))}
	var focus := {}
	if not plan.focus.is_empty():
		focus = {"room": plan.focus_room(), "cat": plan.focus_cat(), "pos": _v(plan.focus_pos())}
	return {"case": case_id, "style": String(plan.spec.style) if plan.spec else "",
		"period": int(plan.spec.period) if plan.spec and "period" in plan.spec else 0,
		"purpose": String(plan.spec.purpose) if plan.spec and "purpose" in plan.spec else "",
		"entrance_door": plan.entrance(), "entrance_room": plan.entrance_room(),
		"rooms": rooms, "doors": doors, "windows": windows, "stairs": stairs,
		"furniture": furniture, "hearth": hearth, "focus": focus,
		"compromises": plan.compromises.keys().map(func(k): return str(k)),
		"period_seating": String(plan.spec.get("period_seating")) if plan.spec and "period_seating" in plan.spec else "",
		"household": _household_row(plan),
		"dining_selection": String(plan.domestic_layout.get("dining_selection", "")),
		"dining_reason": String(plan.domestic_layout.get("dining_selection_reason", ""))}


static func _household_row(plan: HousePlan) -> Dictionary:
	var h: Dictionary = plan.domestic_layout.get("household", {})
	var out := {}
	for k in h:
		var v: Variant = h[k]
		if v is Dictionary:
			var d := {}
			for kk in v:
				d[str(kk)] = v[kk]
			v = d
		out[str(k)] = v
	return out
