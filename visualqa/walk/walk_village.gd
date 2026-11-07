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
## seed, attempts, extras, why}. Every field is optional.

const BAKE_DIR := "res://artifacts/walk_villages/"
const STOP_FIELDS := ["culture", "purpose", "population", "wealth", "water",
	"enclosure", "terrain", "attempts", "extras"]


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
	return {"seed": v_seed, "culture": String(spec.culture), "purpose": String(spec.purpose),
		"population": spec.population, "wealth": spec.wealth, "form": String(spec.form),
		"where": where(stop), "on_terrain": p.ground != null, "buildings": p.buildings.size(),
		"extras": (planned["extras"] as Array).size(), "extras_placed": placed,
		"t_plan": planned.get("t_plan", 0.0)}


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
