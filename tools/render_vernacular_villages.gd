extends "res://tools/render_shots.gd"
## The vernacular villages, photographed (VILLAGE-VERNACULAR;
## docs/VILLAGE_VERNACULAR.md). One village per region and the blends the doc
## shows, each from above three-quarters and from the street, written with a
## manifest of the request and the VillageVernacularCheck report beside them.
##
## Must NOT be headless (the dummy renderer makes no image):
##   godot --path . --script res://tools/render_vernacular_villages.gd
##   godot --path . --script res://tools/render_vernacular_villages.gd -- only=cyclades,norse
##   godot --path . --script res://tools/render_vernacular_villages.gd -- pop=60 seed=7 compact
## VILLAGE-PLACE (docs/VILLAGE_PLACE.md): `places=` photographs villages of
## places described by their features instead -- preset ids, or `all`:
##   godot --path . --script res://tools/render_vernacular_villages.gd -- places=british_hamlet,sahel_town

const VERN_ROOT := "res://artifacts/renders/vernacular"
const VERN_SIZE := Vector2i(1280, 860)

const FIXTURES := [
	{"key": "provence", "vernacular": {"provence": 1.0}, "purpose": &"market"},
	{"key": "cyclades", "vernacular": {"cyclades": 1.0}, "purpose": &"fishing"},
	{"key": "norse", "vernacular": {"norse": 1.0}, "purpose": &"farming"},
	{"key": "japanese", "vernacular": {"japanese": 1.0}, "purpose": &"farming"},
	{"key": "blend_norse_japanese", "vernacular": {"norse": 0.5, "japanese": 0.5}, "purpose": &"farming"},
	{"key": "blend_cyclades_walls_provence", "vernacular": {"blend": {"provence": 1.0}, "groups": {"walls": {"cyclades": 1.0}, "trim": {"cyclades": 1.0}}}, "purpose": &"market"},
]

var _rows: Array[Dictionary] = []


func _init() -> void:
	var only: PackedStringArray = []
	var pop := 50
	var seed_value := 7
	var compact := false
	var fixtures: Array = FIXTURES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=").split(",")
		elif arg.begins_with("pop="):
			pop = int(arg.trim_prefix("pop="))
		elif arg.begins_with("seed="):
			seed_value = int(arg.trim_prefix("seed="))
		elif arg == "compact":
			compact = true
		elif arg.begins_with("places="):
			var ids := arg.trim_prefix("places=").split(",")
			if ids == PackedStringArray(["all"]):
				ids = PackedStringArray(VillagePlace.preset_ids())
			fixtures = []
			for id in ids:
				fixtures.append({"key": "place_" + id, "vernacular": {"place": {"like": id}}, "purpose": &"farming"})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VERN_ROOT))
	_build_stage()
	_vp.size = VERN_SIZE
	await process_frame
	for fixture in fixtures:
		if not only.is_empty() and not String(fixture["key"]) in only:
			continue
		await _shoot(fixture, pop, seed_value, compact)
	var doc := {"schema": "brickwild.vernacular_renders", "schema_version": 1,
		"captured_at": Time.get_datetime_string_from_system(true), "fixtures": _rows}
	var f := FileAccess.open(VERN_ROOT + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t") + "\n")
	f.close()
	print("VERNACULAR_RENDERS fixtures=%d out=%s" % [_rows.size(), VERN_ROOT])
	quit(0)


func _shoot(fixture: Dictionary, pop: int, seed_value: int, compact: bool) -> void:
	var t0 := Time.get_ticks_msec()
	var key := String(fixture["key"])
	var request := BuildingRequest.village(seed_value, pop, &"english", fixture["purpose"], 0.5, compact)
	request.vernacular = fixture["vernacular"]
	var building := BrickWild.generate(request)
	var row := {"fixture": key, "request": request.to_dict(), "captures": []}
	if not building.is_ok():
		row["errors"] = building.errors
		_rows.append(row)
		printerr("VERNACULAR %s: generation failed %s" % [key, str(building.errors)])
		return
	var plan: VillagePlan = building.village
	var fs: VillageVernacular = plan.spec.feature_set()
	var report := VillageVernacularCheck.new().check(VillageVernacularCheck.measure_plan(plan), fs)
	row["name"] = plan.spec.variant_name
	row["check"] = {"ok": report["ok"], "failures": report["failures"]}
	var node := BrickWild.instantiate(building, false)
	_root3d.add_child(node)
	await process_frame
	var site: Rect2 = plan.site
	var top := 12.0
	for placed in plan.buildings:
		top = maxf(top, (placed["placement"].get("bounds", AABB()) as AABB).end.y)
	var bounds := AABB(Vector3(site.position.x, 0.0, site.position.y), Vector3(site.size.x, top, site.size.y))
	_set_atmosphere(&"house")
	# from above, three-quarters
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var yaw := 2.28
	var pitch := -0.5
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var distance := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 0.95
	_cam.position = centre + direction * distance
	_cam.look_at(centre, Vector3.UP)
	_set_shot_lighting(yaw, distance + radius)
	row["captures"].append(await _save(key + "_overview.jpg"))
	# closer, over the common toward the houses
	var near := centre + direction * distance * 0.45
	near.y = maxf(near.y * 0.55, 9.0)
	_cam.position = near
	_cam.look_at(Vector3(centre.x, 2.0, centre.z), Vector3.UP)
	_set_shot_lighting(yaw, distance)
	row["captures"].append(await _save(key + "_near.jpg"))
	# along the through road, at eye height
	if not plan.roads.is_empty():
		var points: PackedVector2Array = plan.roads[0]["points"]
		var segment := mini(maxi(0, (points.size() - 1) / 2), points.size() - 2)
		var at := points[segment].lerp(points[segment + 1], 0.2)
		var ahead := (points[segment + 1] - points[segment]).normalized()
		_cam.position = Vector3(at.x, 1.7, at.y)
		_cam.look_at(_cam.position + Vector3(ahead.x, -0.05, ahead.y) * 15.0, Vector3.UP)
		_set_shot_lighting(atan2(-ahead.x, -ahead.y), 80.0)
		row["captures"].append(await _save(key + "_street.jpg"))
	node.queue_free()
	await process_frame
	row["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	print("VERNACULAR %s (%s): check %s, %.0f s" % [key, row["name"], "ok" if report["ok"] else "FAILS " + str(report["failures"]), row["seconds"]])
	_rows.append(row)


func _save(file: String) -> String:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(VERN_ROOT + "/" + file), 0.92)
	return file
