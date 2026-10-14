extends SceneTree
## LIVE-FAMILY-STYLES: generate every frozen family-style request once.
##
## NOT a per-task lane. Hotels take ~45 s each and the whole file is minutes.
## Run it in the background, output redirected:
##
##   godot --headless --path . --script res://tools/generate_family_requests.gd \
##     > artifacts/family_requests_20261014/run.log 2>&1
##
## Options (after `--`):
##   --write-fixture   rebuild tests/fixtures/family_style_requests.json from the
##                     public tables, then stop. The fixture is frozen: do this
##                     only when a published row is added.
##   --only=<prefix>   generate only ids starting with <prefix> (e.g. world/)
##   --out=<path>      result file (default
##                     res://artifacts/family_requests_20261014/result.json)
##
## Each request is decoded with BuildingRequest.from_dict, generated through
## BrickWild.generate like a consumer's, meshed with BrickWild.build_mesh and
## measured with BrickWild.placement. A request that does not generate is a
## finding, recorded with its errors; the tool never stops on one.

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const OUT_DEFAULT := "res://artifacts/family_requests_20261014/result.json"
const SEED := 8102

## Sizes for the world sub-kinds not in WorldArchetypeSuite.ARCHETYPES.
const WORLD_EXTRA := {
	&"riad": [18.0, 24.0, 7.0], &"palazzo": [20.0, 30.0, 18.0],
	&"octagonal_pagoda": [30.0, 30.0, 65.0], &"dodecagonal_pagoda": [30.0, 30.0, 65.0],
	&"two_court_compound": [22.0, 70.0, 5.0],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only := ""
	var out_path := OUT_DEFAULT
	var write_fixture := false
	for a in args:
		if a == "--write-fixture":
			write_fixture = true
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	if write_fixture:
		_write_fixture()
		quit(0)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not parsed is Dictionary:
		push_error("fixture did not parse: " + FIXTURE)
		quit(2)
		return
	var results: Array = []
	var failed := 0
	var t_all := Time.get_ticks_msec()
	for c in parsed["cases"]:
		var id: String = c["id"]
		if only != "" and not id.begins_with(only):
			continue
		var row := _generate(c)
		results.append(row)
		if not row["ok"]:
			failed += 1
		print("%s  %s  %.1fs  %s" % ["OK  " if row["ok"] else "FAIL", id, row["seconds"], row.get("error", "")])
		_save(out_path, results, failed, (Time.get_ticks_msec() - t_all) / 1000.0, false)
	_save(out_path, results, failed, (Time.get_ticks_msec() - t_all) / 1000.0, true)
	print("generated %d, failed %d" % [results.size() - failed, failed])
	quit(1 if failed > 0 else 0)


func _generate(c: Dictionary) -> Dictionary:
	var row := {"id": c["id"], "ok": false, "seconds": 0.0}
	var t0 := Time.get_ticks_msec()
	var req := BuildingRequest.from_dict(c["request"])
	var built: GeneratedBuilding = BrickWild.generate(req)
	if built == null or not built.is_ok():
		row["error"] = str(built.errors) if built != null else "null"
		row["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
		return row
	var mesh: ArrayMesh = BrickWild.build_mesh(built)
	var parts := -1
	if built.village != null:
		parts = built.village.buildings.size()
	elif built.plan != null:
		parts = built.plan.rooms.size()
	var vertices := 0
	var surfaces := 0
	if mesh != null:
		surfaces = mesh.get_surface_count()
		for s in surfaces:
			vertices += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var bounds := AABB()
	var placed: Dictionary = BrickWild.placement(built)
	if placed.has("bounds"):
		bounds = placed["bounds"]
	elif built.village != null:
		var site := built.village.site
		bounds = AABB(Vector3(site.position.x, 0.0, site.position.y), Vector3(site.size.x, 0.0, site.size.y))
	row["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	if mesh == null and built.village == null:
		row["error"] = "no mesh"
		return row
	if bounds.size == Vector3.ZERO:
		row["error"] = "empty bounds"
		return row
	row["ok"] = true
	row["bounds_position"] = [snappedf(bounds.position.x, 0.01), snappedf(bounds.position.y, 0.01), snappedf(bounds.position.z, 0.01)]
	row["bounds_size"] = [snappedf(bounds.size.x, 0.01), snappedf(bounds.size.y, 0.01), snappedf(bounds.size.z, 0.01)]
	row["mesh_vertices"] = vertices
	row["mesh_surfaces"] = surfaces
	row["parts"] = parts
	row["name"] = built.name()
	return row


func _save(path: String, results: Array, failed: int, seconds: float, done: bool) -> void:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify({"complete": done, "requests": results.size(),
		"generated": results.size() - failed, "failed": failed,
		"wall_seconds": snappedf(seconds, 0.1), "results": results}, "  "))
	f.close()


# ---------------------------------------------------------------- fixture

func _case(cases: Array, id: String, family: String, row: String, req: BuildingRequest) -> void:
	cases.append({"id": id, "family": family, "row": row, "request": req.to_dict()})


func _write_fixture() -> void:
	var cases: Array = []
	# castle styles: default envelope
	for id in BuildingLibrary.styles(&"castle"):
		if id != &"norman":
			_case(cases, "castle/%s/%d" % [id, SEED], "castle", String(id), BuildingRequest.castle(SEED, id))
	# windmill types
	for id in BuildingLibrary.styles(&"windmill"):
		if id != &"tower":
			_case(cases, "windmill/%s/%d" % [id, SEED], "windmill", String(id), BuildingRequest.windmill(SEED, id))
	# house styles (witch_hut and cottage already have requests) and trades
	for id in BuildingLibrary.styles(&"house"):
		if id != &"cottage" and id != &"witch_hut":
			_case(cases, "house/%s/%d" % [id, SEED], "house", String(id), BuildingRequest.house(SEED, id))
	for id in HouseSpec.TRADES:
		_case(cases, "house_trade/%s/%d" % [id, SEED], "house_trade", String(id),
			BuildingRequest.house(SEED, &"cottage", id))
	# shop shells (business general_store) and businesses (townhouse shell)
	for id in BuildingLibrary.styles(&"shop"):
		_case(cases, "shop_shell/%s/%d" % [id, SEED], "shop_shell", String(id),
			BuildingRequest.shop(SEED, &"general_store", id))
	for id in ShopSpec.BUSINESSES:
		if id == &"barracks":
			continue  # in visualqa/personality/frozen_requests.json
		_case(cases, "shop/%s/%d" % [id, SEED], "shop", String(id), BuildingRequest.shop(SEED, id))
	# hotel
	_case(cases, "hotel/alpine_palace/%d" % SEED, "hotel", "alpine_palace",
		BuildingRequest.hotel(SEED, &"alpine_palace"))
	# world sub-kinds, one request per (family, sub-kind)
	var dims := {}
	for a in WorldArchetypeSuite.ARCHETYPES:
		dims[a["kind"]] = [a["width"], a["length"], a["height"]]
	for fam in WorldFamilies.FAMILIES:
		for kind in WorldFamilies.kinds_of(fam):
			if fam == &"courtyard_house" and kind == &"domus":
				continue
			var d: Array = WORLD_EXTRA.get(kind, dims.get(kind, []))
			if d.is_empty():
				push_error("no size for world kind %s" % kind)
				continue
			var r := BuildingRequest.new()
			r.kind = &"world"
			r.seed = SEED
			r.style = fam
			r.purpose = kind
			r.width = d[0]
			r.length = d[1]
			r.height = d[2]
			if fam == &"tulou":
				r.storeys = 4
			_case(cases, "world/%s/%s/%d" % [fam, kind, SEED], "world", "%s/%s" % [fam, kind], r)
	# villages: every culture with its first purpose; every purpose in english
	for id in BuildingLibrary.styles(&"village"):
		if id != &"english":
			_case(cases, "village_culture/%s/%d" % [id, SEED], "village_culture", String(id),
				BuildingRequest.village(SEED, 40, id, &"farming"))
	for id in BuildingLibrary.purposes(&"village"):
		if id != &"farming":
			_case(cases, "village_purpose/%s/%d" % [id, SEED], "village_purpose", String(id),
				BuildingRequest.village(SEED, 40, &"english", id))
	var doc := {
		"schema": "brickwild.family-style-requests.v1",
		"purpose": "LIVE-FAMILY-STYLES: one frozen public request per published row that had no saved request. Default envelope, seed %d. Generated once by tools/generate_family_requests.gd (slow; not a lane). Not evidence of visual approval." % SEED,
		"cases": cases,
	}
	var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, " ") + "\n")
	f.close()
	print("wrote %d cases to %s" % [cases.size(), FIXTURE])
