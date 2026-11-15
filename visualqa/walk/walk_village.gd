extends RefCounted
## One village of a walk series (visualqa/villages/<name>.json), planned the
## way the vgroundterrain suite plans one, plus the stop's `extras`; and its
## bake: the assembled scene saved once by tools/bake_walk_villages.gd, so the
## walk rig loads a village in seconds instead of generating it for a quarter
## of an hour (nearly all of it the furnisher, measured 1 Nov: 452 s to
## measure 22 buildings, then the assembler generates each one again).
##
## Preloaded, not a class_name: the rig and the baker share it, nothing else.
##
## A stop: {culture, purpose, population, wealth, water, enclosure, terrain,
## vernacular, seed, attempts, extras, why}. Every field is optional.
## `vernacular` is VillageSpec.vernacular: the regions the village is built
## from and how they blend (docs/VILLAGE_VERNACULAR.md); see
## visualqa/villages/vernacular.json.

const BAKE_DIR := "res://artifacts/walk_villages/"
const STOP_FIELDS := ["culture", "purpose", "population", "wealth", "water",
	"enclosure", "terrain", "vernacular", "attempts", "extras"]


## Plan a stop at a seed. Returns {plan, spec, extras, t_plan} or {error}.
static func plan(stop: Dictionary, v_seed: int) -> Dictionary:
	var spec := VillageSpec.new(v_seed)
	spec.population = int(stop.get("population", 40))
	for f in ["culture", "purpose", "water", "enclosure"]:
		if stop.has(f):
			spec.set(f, StringName(stop[f]))
	if stop.has("wealth"):
		spec.wealth = float(stop["wealth"])
	if stop.has("attempts"):
		spec.search_max_attempts = int(stop["attempts"])
	if stop.get("vernacular") is Dictionary:
		spec.vernacular = (stop["vernacular"] as Dictionary).duplicate(true)
	var terrain := String(stop.get("terrain", ""))
	if terrain != "":
		var path := terrain_path(terrain)
		var ground := VillageCharacterCheck.apply(VillageTerrain.from_file(path), terrain)
		if not ground.valid():
			return {"error": "No terrain %s (%s)." % [terrain, path]}
		spec.terrain = ground
	if not spec.valid():
		return {"error": "Not a valid village: %s" % [stop]}
	var extras := extras_of(stop, v_seed)
	var t0 := Time.get_ticks_msec()
	spec.generate(v_seed)
	var requests: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	requests.append_array(extras)
	var p := VillageLotPlanner.plan_measured(spec, VillageLotPlanner.measure_all(requests))
	if p.buildings.is_empty():
		return {"error": "The village was not planned on %s (seed %d)." % [where(stop), v_seed]}
	return {"plan": p, "spec": spec, "extras": extras, "t_plan": (Time.get_ticks_msec() - t0) / 1000.0}


static func terrain_path(terrain: String) -> String:
	if terrain.begins_with("res://"):
		return terrain
	var path := "res://tests/fixtures/terrain/%s.json" % terrain
	if not FileAccess.file_exists(path):
		path = "res://tests/fixtures/terrain/real30/%s.json" % terrain
	return path


static func where(stop: Dictionary) -> String:
	var t := String(stop.get("terrain", ""))
	return t if t != "" else "flat ground"


## The stop's extra requests, each through BuildingRequest.from_dict (so a
## dict names only what it means: {"kind": "windmill", "style": "post"}). A
## dict without a seed gets one from the village seed and its place in the
## list, so a new village seed changes the extras too. Invalid ones are left
## out with a warning.
static func extras_of(stop: Dictionary, v_seed: int) -> Array[BuildingRequest]:
	var out: Array[BuildingRequest] = []
	var bad := PackedStringArray()
	var list: Array = stop.get("extras", [])
	for i in list.size():
		var d: Dictionary = (list[i] as Dictionary).duplicate()
		if not d.has("seed"):
			d["seed"] = absi(hash([v_seed, i, d.get("kind", ""), d.get("style", "")])) % 1000000
		var req := BuildingRequest.from_dict(d)
		var errors := BuildingLibrary.validate(req)
		if not errors.is_empty():
			bad.append("%s/%s: %s" % [d.get("kind", "?"), d.get("style", ""), errors[0].get("message", "")])
			continue
		out.append(req)
	if not bad.is_empty():
		push_warning("walk village: extras left out: " + "; ".join(bad))
	return out


## One row per placed building, in the plan's order (the assembler names the
## node <kind>_<i> by the same index): request, transform, door, extra.
static func rows_of(p: VillagePlan, extras: Array[BuildingRequest]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in p.buildings:
		var xf: Transform3D = b.get("transform", Transform3D.IDENTITY)
		out.append({"request": b["request"], "transform": xf,
			"door": b.get("door", xf.origin), "extra": extras.has(b["request"])})
	return out


## What the sidebar and the review say about the village.
static func meta_of(stop: Dictionary, v_seed: int, planned: Dictionary) -> Dictionary:
	var spec: VillageSpec = planned["spec"]
	var p: VillagePlan = planned["plan"]
	var placed := 0
	for b in p.buildings:
		if (planned["extras"] as Array).has(b["request"]):
			placed += 1
	var meta := {"seed": v_seed, "culture": String(spec.culture), "purpose": String(spec.purpose),
		"population": spec.population, "wealth": spec.wealth, "form": String(spec.form),
		"where": where(stop), "on_terrain": p.ground != null, "buildings": p.buildings.size(),
		"extras": (planned["extras"] as Array).size(), "extras_placed": placed,
		"t_plan": planned.get("t_plan", 0.0)}
	var fs: VillageVernacular = spec.feature_set()
	if fs != null:
		meta["vernacular"] = spec.vernacular.duplicate(true)
		meta["vernacular_label"] = vernacular_label(fs)
		meta["name"] = spec.variant_name
		meta["vernacular_check"] = vernacular_check(p, fs)
	return meta


## "Provence", "Norse 50% + Japanese 50%", "Cyclades; roofs: Japanese".
static func vernacular_label(fs: VillageVernacular) -> String:
	var parts := PackedStringArray()
	for id in fs.blend:
		var label := String(VillageVernacular.region(id).get("label", String(id))).get_slice(" (", 0)
		parts.append(label if fs.blend.size() == 1 else "%s %d%%" % [label, roundi(float(fs.blend[id]) * 100.0)])
	var out := " + ".join(parts)
	for g in fs.groups:
		var w: Dictionary = fs.groups[g]
		if w != fs.blend:
			var names := PackedStringArray()
			for id in w:
				names.append(String(VillageVernacular.region(id).get("label", String(id))).get_slice(" (", 0))
			out += "; %s: %s" % [g, ", ".join(names)]
	if fs.coherence > 0.0:
		out += "; coherence %.1f" % fs.coherence
	return out


## VillageVernacularCheck on the planned village, small enough for the
## sidebar, the bake's side file and a pin record:
## {ok, failures (the first five), signature {id: value}}.
static func vernacular_check(p: VillagePlan, fs: VillageVernacular) -> Dictionary:
	var rep := VillageVernacularCheck.new().check(VillageVernacularCheck.measure_plan(p), fs)
	var sig := {}
	var raw: Dictionary = rep["stats"].get("signature", {})
	for k in raw:
		# a trait the village is too small to ask (variety under ten
		# dwellings, a church in a hamlet) says so rather than showing 0
		if bool(raw[k].get("skipped", false)):
			sig[k] = "skipped"
			continue
		var v: Variant = raw[k]["value"]
		sig[k] = snappedf(v, 0.01) if v is float else v
	return {"ok": rep["ok"], "failures": (rep["failures"] as Array).slice(0, 5),
		"failure_count": (rep["failures"] as Array).size(), "signature": sig}


# --- bakes ----------------------------------------------------------------

static func bake_base(series: String, stop_n: int, v_seed: int) -> String:
	return BAKE_DIR + "%s/%02d_seed%d" % [series, stop_n, v_seed]


## The stop's own fields, so a bake made from an edited stop is not reused.
static func stop_key(stop: Dictionary) -> String:
	var d := {}
	for f in STOP_FIELDS:
		if stop.has(f):
			d[f] = stop[f]
	return JSON.stringify(d, "", true)


static func save_bake(base: String, root: Node3D, rows: Array[Dictionary], meta: Dictionary,
		stop: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base.get_base_dir()))
	_own(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		return "cannot pack the village"
	if ResourceSaver.save(packed, base + ".scn", ResourceSaver.FLAG_COMPRESS) != OK:
		return "cannot write " + base + ".scn"
	var out_rows: Array = []
	for r in rows:
		var xf: Transform3D = r["transform"]
		out_rows.append({"request": (r["request"] as BuildingRequest).to_dict(),
			"transform": [xf.basis.x.x, xf.basis.x.y, xf.basis.x.z, xf.basis.y.x, xf.basis.y.y,
				xf.basis.y.z, xf.basis.z.x, xf.basis.z.y, xf.basis.z.z, xf.origin.x, xf.origin.y, xf.origin.z],
			"door": [r["door"].x, r["door"].y, r["door"].z], "extra": r["extra"]})
	var side := meta.duplicate()
	side["stop_key"] = stop_key(stop)
	side["commit"] = git_head()
	side["tree_state"] = tree_state(side["commit"])
	side["baked_at"] = Time.get_datetime_string_from_system(true) + "Z"
	side["rows"] = out_rows
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	if f == null:
		return "cannot write " + base + ".json"
	f.store_string(JSON.stringify(side, "  "))
	f.close()
	return ""


## Every node is owned by the root so the scene packs, a model the assembler
## instanced included: it is embedded, not referenced, because the assembler
## and the appearance pass change nodes inside it (materials, visibility),
## and an instance reference would drop those changes.
static func _own(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		c.scene_file_path = ""
		_own(c, root)


## A bake of this stop at this seed: {root, rows, meta}, or {} when there is
## none or it was made from a different stop.
static func load_bake(base: String, stop: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(base + ".json") or not ResourceLoader.exists(base + ".scn"):
		return {}
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not (side is Dictionary) or String(side.get("stop_key", "")) != stop_key(stop):
		return {}
	var packed := ResourceLoader.load(base + ".scn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {}
	var rows: Array[Dictionary] = []
	for r in side.get("rows", []):
		var t: Array = r["transform"]
		var xf := Transform3D(Basis(Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]),
			Vector3(t[6], t[7], t[8])), Vector3(t[9], t[10], t[11]))
		var d: Array = r["door"]
		rows.append({"request": BuildingRequest.from_dict(r["request"]), "transform": xf,
			"door": Vector3(d[0], d[1], d[2]), "extra": bool(r.get("extra", false))})
	var meta: Dictionary = side
	meta.erase("rows")
	return {"root": packed.instantiate(), "rows": rows, "meta": meta}


## The seeds this stop has been baked at.
static func baked_seeds(series: String, stop_n: int) -> Array[int]:
	var out: Array[int] = []
	var dir := BAKE_DIR + series
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var prefix := "%02d_seed" % stop_n
	for name in DirAccess.get_files_at(dir):
		if name.begins_with(prefix) and name.ends_with(".json"):
			out.append(int(name.trim_prefix(prefix).trim_suffix(".json")))
	return out


## What makes a village: the generator, its checks (the planner measures
## with them), the props and the terrain fixtures. Not this file, not the rig:
## a change to either leaves every bake good. (A change to how plan() above
## plans does not: re-bake with --force.)
const GENERATOR_PATHS := ["src", "core", "qa", "assets/props", "tests/fixtures/terrain"]


## The generator files that differ between `commit` and the working tree --
## committed since, or edited and not yet committed. A bake is stale when this
## is not empty, not merely when HEAD has moved: a commit of docs or of the
## walk rig leaves the villages as they were. ["?"] when git cannot say (no
## commit recorded, git not on PATH, a commit this clone does not have).
## Before 15 Nov the rig compared commits only and said so in one grey line;
## the walk then showed 29 Oct villages for two weeks after the VREAL layout
## and the household interiors landed.
static func changed_since(commit: String) -> PackedStringArray:
	if commit == "" or commit == "?":
		return PackedStringArray(["?"])
	var args := PackedStringArray(["-C", ProjectSettings.globalize_path("res://"),
		"diff", "--name-only", commit, "--"])
	args.append_array(PackedStringArray(GENERATOR_PATHS))
	var out: Array = []
	if OS.execute("git", args, out, false) != 0 or out.is_empty():
		return PackedStringArray(["?"])
	# in GENERATOR_PATHS order, so the sidebar names src/ before qa/
	var files := PackedStringArray()
	var lines := String(out[0]).split("\n", false)
	for root in GENERATOR_PATHS:
		for line in lines:
			var f := line.strip_edges()
			if f.begins_with(String(root) + "/"):
				files.append(f)
	return files


## What the working tree's generator files are, as against `commit`: a hash
## of `git diff <commit>` over GENERATOR_PATHS (content, not names) and of every
## untracked generator file (`git diff` does not see a new file). "" when git
## cannot say. A bake records it (save_bake), so a bake made from work not yet
## committed is current while the work is unchanged -- changed_since() alone
## called such a bake "the OLD village" the moment it was made -- and stale as
## soon as one of those files is edited again (VILLAGE-VERNACULAR, 15 Nov).
static func tree_state(commit: String) -> String:
	if commit == "" or commit == "?":
		return ""
	var root := ProjectSettings.globalize_path("res://")
	var diff_args := PackedStringArray(["-C", root, "diff", commit, "--"])
	diff_args.append_array(PackedStringArray(GENERATOR_PATHS))
	var out: Array = []
	if OS.execute("git", diff_args, out, false) != 0:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(String(out[0] if not out.is_empty() else "").to_utf8_buffer())
	var new_args := PackedStringArray(["-C", root, "ls-files", "--others", "--exclude-standard", "--"])
	new_args.append_array(PackedStringArray(GENERATOR_PATHS))
	var listed: Array = []
	if OS.execute("git", new_args, listed, false) != 0:
		return ""
	var names := String(listed[0] if not listed.is_empty() else "").split("\n", false)
	names.sort()
	for name in names:
		var f := name.strip_edges()
		ctx.update(f.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes("res://" + f))
	return ctx.finish().hex_encode()


## One line for the sidebar about a bake's age, "" when it is current.
static func stale_note(meta: Dictionary) -> String:
	var commit := String(meta.get("commit", ""))
	# made from the generator exactly as it stands now, committed or not
	var baked_state := String(meta.get("tree_state", ""))
	if baked_state != "" and tree_state(commit) == baked_state:
		return ""
	var changed := changed_since(commit)
	if changed.size() == 1 and changed[0] == "?":
		if commit == git_head():
			return ""
		return "Baked at %s, HEAD is now %s, and git could not say what changed: re-bake before trusting a pin." % [
			commit if commit != "" else "an unrecorded commit", git_head()]
	if changed.is_empty():
		return ""
	var shown := changed.slice(0, 3)
	return "STALE BAKE: %d generator file%s changed since %s (%s%s). This is the OLD village. Re-bake: .\\visualqa\\walk.ps1 -Bake" % [
		changed.size(), "" if changed.size() == 1 else "s", commit, ", ".join(shown),
		", ..." if changed.size() > shown.size() else ""]


## The checked-out commit, read from .git (no process): a bake says which
## code made it, and the rig warns when that is not the code it is running.
static func git_head() -> String:
	var git := ProjectSettings.globalize_path("res://.git")
	var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref: "):
		return head.substr(0, 10)
	var ref := head.trim_prefix("ref: ")
	var sha := FileAccess.get_file_as_string(git.path_join(ref)).strip_edges()
	if sha == "":
		for line in FileAccess.get_file_as_string(git.path_join("packed-refs")).split("\n"):
			if line.ends_with(" " + ref):
				sha = line.get_slice(" ", 0)
	return sha.substr(0, 10)
