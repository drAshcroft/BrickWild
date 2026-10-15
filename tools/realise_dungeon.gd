extends SceneTree
## Read a dungeon planner export, write the realised dungeon a consumer carves.
##
##   godot --headless --path . --script res://tools/realise_dungeon.gd -- \
##       --plan plan.json --out rooms.json [--pretty]
##
## The plan comes from C:\Projects\dungeon\tools\export_plan.gd. The output is
## `brickwild.dungeon.rooms` (docs/DUNGEONS.md). Exit 2 bad arguments, 3 the
## plan could not be read or realised, 4 the file could not be written; nothing
## is written unless the whole document was built.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan_path := ""
	var out_path := ""
	var pretty := false
	var i := 0
	while i < args.size():
		match args[i]:
			"--plan":
				i += 1
				plan_path = args[i] if i < args.size() else ""
			"--out":
				i += 1
				out_path = args[i] if i < args.size() else ""
			"--pretty":
				pretty = true
			_:
				printerr("unknown argument: %s" % args[i])
				quit(2)
				return
		i += 1
	if plan_path == "" or out_path == "":
		printerr("usage: realise_dungeon.gd -- --plan PLAN.json --out ROOMS.json [--pretty]")
		quit(2)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	if not parsed is Dictionary:
		printerr("cannot read a plan from %s" % plan_path)
		quit(3)
		return
	var result := DungeonRealiser.realise(parsed)
	for w in result["warnings"]:
		printerr("warning: %s" % w)
	if not bool(result["ok"]):
		for e in result["errors"]:
			printerr(e)
		quit(3)
		return
	var text := JSON.stringify(result["document"], "\t" if pretty else "", true) + "\n"
	var temp := out_path + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % temp)
		quit(4)
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	if DirAccess.rename_absolute(temp, out_path) != OK:
		printerr("cannot move %s over %s" % [temp, out_path])
		quit(4)
		return
	print("wrote %s (%d rooms)" % [out_path, (result["document"]["rooms"] as Array).size()])
	quit(0)
