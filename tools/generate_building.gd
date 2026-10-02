extends SceneTree
## godot --headless --path . --script res://tools/generate_building.gd --
##     --request request.json --out building.json [--mesh shell.tres] [--qa qa.json]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	var i := 0
	while i < args.size():
		if args[i] not in ["--request", "--out", "--mesh", "--qa"] or i + 1 >= args.size():
			_fail("usage", "arguments", "Expected --request input.json --out output.json [--mesh shell.tres] [--qa qa.json].", 2)
			return
		opts[args[i].trim_prefix("--")] = args[i + 1]
		i += 2
	if not opts.has("request") or not opts.has("out"):
		_fail("usage", "arguments", "--request and --out are required.", 2)
		return
	if not FileAccess.file_exists(opts["request"]):
		_fail("read_failed", "request", "Cannot read request file.", 2)
		return
	var request := BuildingRequest.from_json(FileAccess.get_file_as_string(opts["request"]))
	var document := BrickWild.generate_document(request)
	if not document.is_ok():
		var refusal := {"ok": false, "errors": document.errors}
		_write(opts["out"], JSON.stringify(refusal, "\t", true, true) + "\n")
		print(JSON.stringify(refusal))
		quit(3)
		return
	if not _write(opts["out"], document.to_json()):
		return
	if opts.has("mesh"):
		var error := ResourceSaver.save(BrickWild.build_mesh(document), opts["mesh"])
		if error != OK:
			_fail("write_failed", "mesh", error_string(error), 2)
			return
	if opts.has("qa"):
		var qa: Dictionary = BrickWild.check(document)
		if not _write(opts["qa"], JSON.stringify(qa, "\t", true, true) + "\n"):
			return
		if not qa["ok"]:
			print(JSON.stringify({"ok": false, "code": "quality_failed", "qa": opts["qa"]}))
			quit(4)
			return
	print(JSON.stringify({"ok": true, "document": opts["out"], "kind": String(request.kind), "seed": str(request.seed)}))
	quit(0)


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("write_failed", "out", "Cannot write %s." % path, 2)
		return false
	file.store_string(text)
	file.close()
	return true


func _fail(code: String, field: String, message: String, status: int) -> void:
	print(JSON.stringify({"ok": false, "errors": [{"code": code, "field": field, "message": message}]}))
	quit(status)
