extends SceneTree
## The measured side of the LIVE-SACRED acceptance review: for each request of
## the frozen sacred matrix (tests/fixtures/sacred_sequence_requests.json) run
## the same judges the gates run -- qa/sacred_sequence_check.gd for a church,
## TempleRiteCheck for a temple -- and write their stats and failures as JSON,
## so a per-case verdict can cite a number instead of an impression.
##
##   godot --headless --path . --script res://tools/sacred_sequence_report.gd \
##     -- --ids=church/gothic/default/1,temple/basilica/blood/default/1/pinned-barn \
##     --out=res://artifacts/sacred_review_20261023/measurements.json
##
## No --ids means every case in the matrix. Exit code 1 if any case fails a
## SEQUENCE rule; the other rite rules are recorded but not counted here.

const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"
const Seq = preload("res://qa/sacred_sequence_check.gd")
## The rules this report is about, as the sequence suite defines them.
const SEQUENCE := ["axis", "sightline", "procession", "approach", "congregation"]

var _ids: PackedStringArray = []
var _out := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--ids="):
			_ids = text.trim_prefix("--ids=").split(",", false)
		elif text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATRIX))
	if not parsed is Dictionary:
		push_error("matrix %s did not parse" % MATRIX)
		quit(2)
		return
	var rows: Array = []
	var failed := 0
	for case in parsed["cases"]:
		if not _ids.is_empty() and String(case["id"]) not in _ids:
			continue
		var row := _measure(case)
		rows.append(row)
		if not bool(row.get("ok", false)):
			failed += 1
		print("%-46s %-8s %s" % [row["id"], "ok" if row.get("ok", false) else "FAIL",
			str(row.get("stats", {}))])
		if not bool(row.get("ok", false)):
			for f in row.get("failures", []):
				print("    ", f)
	if rows.is_empty():
		push_error("no case selected")
		quit(2)
		return
	var summary := {"matrix": MATRIX, "cases": rows, "case_count": rows.size(),
		"failed": failed, "ok": rows.size() - failed,
		"rule": "sequence rules: " + ", ".join(SEQUENCE)}
	if _out.is_empty():
		print(JSON.stringify(summary, "\t", true, true))
	else:
		var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("could not write " + path)
			quit(2)
			return
		file.store_string(JSON.stringify(summary, "\t", true, true) + "\n")
		file.close()
		print("wrote ", path)
	quit(1 if failed > 0 else 0)


func _measure(case: Dictionary) -> Dictionary:
	var request := BuildingRequest.from_dict(case["request"])
	var made := BrickWild.generate(request)
	var row := {"id": String(case["id"]), "family": String(case["family"]),
		"style_or_form": String(case["style"]), "size": String(case["size"]),
		"seed": int(case["request"].get("seed", 0)),
		"dimensions": [request.width, request.length, request.height]}
	if not made.is_ok():
		row["ok"] = false
		row["failures"] = ["generate: " + str(made.errors)]
		row["stats"] = {}
		return row
	if String(case["family"]) == "church":
		var spec := made.spec as ChurchSpec
		var builder := ChurchBuilder.new()
		builder.build(spec)
		var report: Dictionary = Seq.check(spec, builder)
		row["ok"] = bool(report["ok"])
		row["failures"] = report["failures"]
		row["stats"] = report["stats"]
		row["trait"] = _church_trait(spec)
	else:
		var tspec := made.spec as TempleSpec
		var temple_builder := TempleBuilder.new()
		temple_builder.build(tspec)
		var rite: Dictionary = TempleRiteCheck.new().check(tspec, temple_builder)
		var failures: Array[String] = []
		for f in rite["failures"]:
			if String(f).split(":")[0] in SEQUENCE:
				failures.append(String(f))
		row["ok"] = failures.is_empty()
		row["failures"] = failures
		row["other_rite_failures"] = _not_sequence(rite["failures"])
		row["stats"] = rite["stats"]
		row["cult"] = String(tspec.cult)
		row["trait"] = _temple_trait(tspec)
	return row


func _not_sequence(failures: Array) -> Array[String]:
	var out: Array[String] = []
	for f in failures:
		if String(f).split(":")[0] not in SEQUENCE:
			out.append(String(f))
	return out


func _church_trait(spec: ChurchSpec) -> Dictionary:
	return {"style": String(spec.style), "width": spec.width, "length": spec.length,
		"height": spec.height, "tower": spec.tower, "west_towers": spec.west_towers,
		"dome": spec.dome, "apse": spec.apse, "buttresses": spec.buttresses}


func _temple_trait(spec: TempleSpec) -> Dictionary:
	return {"form": String(spec.form), "cult": String(spec.cult),
		"width": spec.width, "length": spec.length, "height": spec.height,
		"idol_height": spec.idol_height, "idol_width": spec.idol_width}
