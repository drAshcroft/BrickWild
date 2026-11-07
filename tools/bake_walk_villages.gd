extends SceneTree
## Bake a walk series's villages so the walk rig loads each one in seconds.
##
##   godot --path . --script res://tools/bake_walk_villages.gd -- [--series=mixed] [--stops=1,4] [--seeds=1,2] [--force]
##
## Not headless: the scene is saved with its meshes, and the dummy renderer
## keeps none. Each village is minutes to a quarter of an hour (the furnisher),
## so background it and redirect the log:
##   ... > artifacts/walk_villages/bake.log 2>&1
## The rig walks whatever is baked and generates the rest live. A bake made
## from a different stop is ignored; one made at another commit is used but
## flagged on the sidebar. --force re-bakes what is already there.
## Writes artifacts/walk_villages/<series>/<NN>_seed<S>.scn and .json.

const WalkVillage := preload("res://visualqa/walk/walk_village.gd")


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if s.contains("=") else ""
	var series := String(args.get("series", "mixed"))
	var path := "res://visualqa/villages/%s.json" % series
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		data = data.get("stops", [])
	if not (data is Array) or (data as Array).is_empty():
		printerr("bake: no stops in ", path)
		quit(1)
		return
	var stops: Array = data
	var picked: Array[int] = []
	for s in String(args.get("stops", "")).split(",", false):
		picked.append(int(s))
	if picked.is_empty():
		for i in stops.size():
			picked.append(i + 1)
	var force := args.has("force")
	var failed := 0
	var t_all := Time.get_ticks_msec()
	for n in picked:
		if n < 1 or n > stops.size():
			continue
		var stop: Dictionary = stops[n - 1]
		var seeds: Array[int] = []
		for s in String(args.get("seeds", "")).split(",", false):
			seeds.append(int(s))
		if seeds.is_empty():
			seeds.append(int(stop.get("seed", 1)))
		for v_seed in seeds:
			var base := WalkVillage.bake_base(series, n, v_seed)
			if not force and _current(base, stop):
				print("bake: %02d seed %d already baked at this commit, skipped" % [n, v_seed])
				continue
			print("bake: %02d seed %d — %s" % [n, v_seed, stop.get("why", "")])
			var t0 := Time.get_ticks_msec()
			var planned := WalkVillage.plan(stop, v_seed)
			if planned.has("error"):
				printerr("bake: %02d seed %d not planned: %s" % [n, v_seed, planned["error"]])
				failed += 1
				continue
			var t1 := Time.get_ticks_msec()
			var root := VillageAssembler.build(planned["plan"], false)
			var meta := WalkVillage.meta_of(stop, v_seed, planned)
			meta["t_build"] = (Time.get_ticks_msec() - t1) / 1000.0
			var rows := WalkVillage.rows_of(planned["plan"], planned["extras"])
			var err := WalkVillage.save_bake(base, root, rows, meta, stop)
			root.free()
			if err != "":
				printerr("bake: %02d seed %d not saved: %s" % [n, v_seed, err])
				failed += 1
				continue
			var kinds := {}
			for r in rows:
				var req: BuildingRequest = r["request"]
				var k := "%s/%s" % [req.kind, req.style]
				kinds[k] = int(kinds.get(k, 0)) + 1
			print("bake: %02d seed %d done: %d buildings, %d of %d extras, plan %.0f s, build %.0f s, total %.0f s %s" % [
				n, v_seed, rows.size(), meta["extras_placed"], meta["extras"], (t1 - t0) / 1000.0,
				meta["t_build"], (Time.get_ticks_msec() - t0) / 1000.0, kinds])
	print("bake: finished in %.0f s, %d failed" % [(Time.get_ticks_msec() - t_all) / 1000.0, failed])
	quit(1 if failed > 0 else 0)


static func _current(base: String, stop: Dictionary) -> bool:
	if not FileAccess.file_exists(base + ".json") or not FileAccess.file_exists(base + ".scn"):
		return false
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	return side is Dictionary and String(side.get("stop_key", "")) == WalkVillage.stop_key(stop) \
		and String(side.get("commit", "")) == WalkVillage.git_head()
