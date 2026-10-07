extends SceneTree
## Rebuilds every human walk review through the public path the walker used,
## runs the family's own QA on it, and says of each pin whether the QA already
## complains about the thing it points at. A pin no rule names is a blind spot.
##   godot --headless --path . --script res://tools/replay_walk_pins.gd -- [since=2026-10-06T23] [kind=house] [out=artifacts/walk_replay]
## Output: <out>/<review>.txt per review and <out>/summary.txt.
##
## Attribution is by the plan, so it is exact only for the plan-backed families
## (house, shop, hotel, world): a pin is CAUGHT when a diagnostic names a
## furniture record under it ("Chair_1 in room 1") or, for a shell pin, its
## room ("room 1 (hall)"). Everything else is listed as UNMATCHED beside the
## full diagnostics, for a person to read.

const PINS := "res://visualqa/walk_pins.jsonl"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var since := ""
	var only_kind := ""
	var out := "res://artifacts/walk_replay/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("since="):
			since = a.trim_prefix("since=")
		elif a.begins_with("kind="):
			only_kind = a.trim_prefix("kind=")
		elif a.begins_with("out="):
			out = "res://" + a.trim_prefix("out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var summary := PackedStringArray()
	var f := FileAccess.open(PINS, FileAccess.READ)
	while f != null and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var review: Dictionary = JSON.parse_string(line)
		if review == null or String(review.get("time", "")) < since:
			continue
		if (review.get("pins", []) as Array).is_empty():
			continue
		if only_kind != "" and String(review["request"].get("kind", "")) != only_kind:
			continue
		var text := _replay(review)
		var name := "%s_%s" % [review["request"].get("kind", "x"), review.get("review_id", "r")]
		var w := FileAccess.open(out + name + ".txt", FileAccess.WRITE)
		w.store_string(text)
		w.close()
		for l in text.split("\n"):
			if l.begins_with("  pin ") or l.begins_with("== "):
				summary.append(l)
		print(text.split("\n")[0])
	var s := FileAccess.open(out + "summary.txt", FileAccess.WRITE)
	s.store_string("\n".join(summary) + "\n")
	s.close()
	print("\n".join(summary))
	quit()


func _replay(review: Dictionary) -> String:
	var req := BuildingRequest.from_dict(review["request"])
	var t0 := Time.get_ticks_msec()
	var b := BrickWild.generate(req)
	var lines := PackedStringArray()
	lines.append("== %s  %s %s seed %s  (%s)" % [review.get("name", "?"), req.kind,
		req.style, req.seed, review.get("time", "")])
	if not b.is_ok():
		lines.append("  not generated: %s" % [b.errors])
		return "\n".join(lines)
	var report := BrickWild.check(b)
	var diags: Array = report.get("diagnostics", [])
	var msgs := PackedStringArray()
	for d in diags:
		msgs.append("%s %s" % [String(d["severity"]).to_upper(), d["message"]])
	var plan = b.plan if "plan" in b else null
	var subs := {}
	for pin in review["pins"]:
		var pos: Array = pin["pos"]
		var p := Vector3(pos[0], pos[1], pos[2])
		var house_plan := plan as HousePlan
		var part := String(pin.get("part", ""))
		var room_text := String(pin.get("room", ""))
		var token := ""
		# a village pin is in the village's frame and names its building node
		# ("Buildings/house_9/..."): take it into that building's own frame
		if b.village != null and part.begins_with("Buildings/"):
			var idx := int(part.get_slice("/", 1).get_slice("_", 1))
			if idx >= 0 and idx < b.village.buildings.size():
				var row: Dictionary = b.village.buildings[idx]
				if not subs.has(idx):
					subs[idx] = BrickWild.generate(row["request"])
				p = Transform3D(row["transform"]).affine_inverse() * p
				house_plan = subs[idx].plan as HousePlan
				part = part.get_slice("/", 2)
				room_text = _room_text(house_plan, p)
				token = "building %d " % idx
		var keys := _needles(house_plan, p, room_text, part)
		var hits := PackedStringArray()
		for m in msgs:
			if token != "" and not token in m:
				continue
			for k in keys:
				if k in m:
					hits.append(m)
					break
		var verdict := "CAUGHT" if not hits.is_empty() else ("UNMATCHED" if keys.is_empty() else "MISSED")
		lines.append("  pin %s/%d %-9s %s :: %s  [%s]" % [review.get("review_id", "?").substr(0, 6),
			int(pin["n"]), verdict, String(pin.get("part", "")).get_file(), pin["note"], ", ".join(keys)])
		for h in hits:
			lines.append("      <- %s" % h)
	lines.append("")
	lines.append("-- %d diagnostics (%d ms)" % [msgs.size(), Time.get_ticks_msec() - t0])
	for m in msgs:
		lines.append("  " + m)
	return "\n".join(lines)


## The walker's own room label for a point ("hall #1"), so a village pin
## reads like a house pin.
static func _room_text(plan: HousePlan, p: Vector3) -> String:
	if plan == null:
		return ""
	var out := PackedStringArray()
	for i in plan.rooms.size():
		var rect: Rect2 = plan.rooms[i].get("rect", Rect2())
		var base := float(HousePlan.record_storey(plan.rooms[i])) * plan.spec.height
		if rect.grow(0.15).has_point(Vector2(p.x, p.z)) and p.y > base - 0.2 and p.y < base + plan.spec.height + 1.0:
			out.append("%s #%d" % [plan.kind_of(i), i])
	return ", ".join(out)


## The strings a diagnostic would contain if it were about this pin.
static func _needles(plan: HousePlan, p: Vector3, room_text: String, part: String) -> PackedStringArray:
	var out := PackedStringArray()
	if plan == null:
		return out
	var storey := clampi(int(floor((p.y + 0.3) / plan.spec.height)), 0, maxi(plan.spec.storeys - 1, 0))
	var at := Vector2(p.x, p.z)
	if part.begins_with("Furniture"):
		for i in plan.furniture.size():
			var f: Dictionary = plan.furniture[i]
			var rect: Rect2 = f.get("rect", Rect2())
			if HousePlan.record_storey(f) == storey and rect.grow(0.15).has_point(at):
				out.append("%s in room %d" % [f.get("key", "?"), int(f["room"])])
	# a room pin: any rule that names the room it stands in
	var re := RegEx.create_from_string("#(\\d+)")
	for m in re.search_all(room_text):
		out.append("room %s " % m.get_string(1))
		out.append("room %s)" % m.get_string(1))
	return out
