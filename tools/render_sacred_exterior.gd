extends "res://tools/render_sacred_acceptance.gd"
## Roof-on exterior portraits for cases of the frozen sacred sequence matrix
## (tests/fixtures/sacred_sequence_requests.json), through the public API.
## Run WITHOUT --headless:
##   godot --path . --script res://tools/render_sacred_exterior.gd -- --out=res://artifacts/x --ids=temple/basilica/blood/default/1/pinned-barn,church/gothic/default/1
## Views per id: front (west 3/4), side (south, low), rear (east 3/4), and
## entry: eye height at the first reached floor inside the door, aimed at the
## altar (church) or idol (temple). Pass --views=front,side,entry to choose.

const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"

var _out := "res://artifacts/sacred_exterior_20261014/renders"
var _ids: PackedStringArray = []
var _views: PackedStringArray = ["front", "side", "rear", "entry"]


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := String(arg)
		if t.begins_with("--out="):
			_out = t.trim_prefix("--out=")
		elif t.begins_with("--views="):
			_views = t.trim_prefix("--views=").split(",", false)
		elif t.begins_with("--ids="):
			_ids = t.trim_prefix("--ids=").split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_build_stage()
	await process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MATRIX))
	var failed := 0
	for case in data["cases"]:
		if not _ids.is_empty() and String(case["id"]) not in _ids:
			continue
		if not await _render_case(case):
			failed += 1
	quit(1 if failed > 0 else 0)


func _render_case(case: Dictionary) -> bool:
	var r: Dictionary = case["request"]
	var request: BuildingRequest
	var seed := int(r["seed"])
	var w := float(r["width"])
	var l := float(r["length"])
	var h := float(r["height"])
	if String(case["family"]) == "church":
		request = BuildingRequest.church(seed, StringName(case["style"]), w, l, h)
	else:
		request = BuildingRequest.temple(seed, StringName(case["style"]),
			StringName(r.get("cult", &"flame")), w, l, h)
	var made := BrickWild.generate(request)
	if not made.is_ok():
		push_error("generate failed " + String(case["id"]))
		return false
	var scene: Node3D = BrickWild.instantiate(made, false, false)
	_mesh_inst.mesh = null
	_root3d.add_child(scene)
	await process_frame
	var b: AABB = SceneBounds.of_node(scene)
	var c := b.get_center()
	var radius := maxf(b.size.length() * 0.5, 1.0)
	var slug := String(case["id"]).replace("/", "_")
	# The building's long axis is z; the west door is at -z.
	var views := {"front": [-0.55, 0.38], "side": [1.57, 0.22], "rear": [PI + 0.55, 0.38]}
	for name in _views:
		if name == "entry":
			await _entry_view(case, made, scene, slug)
			continue
		var yaw: float = views[name][0]
		var lift: float = views[name][1]
		_cam.fov = 44.0
		var dist := radius * 2.3
		_cam.position = c + Vector3(sin(yaw) * dist, radius * lift, -cos(yaw) * dist)
		_cam.look_at(c + Vector3(0, -b.size.y * 0.1, 0), Vector3.UP)
		_set_shot_lighting(atan2(-_cam.global_transform.basis.z.x, -_cam.global_transform.basis.z.z), dist + radius)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var target := ProjectSettings.globalize_path(_out).path_join("%s__%s.jpg" % [slug, name])
		_vp.get_texture().get_image().save_jpg(target, 0.92)
		print("  ", target)
	_root3d.remove_child(scene)
	scene.free()
	return true


## First-person view from just inside the door toward the focus. The station
## comes from the same WalkGrid flood the acceptance tool uses, so the eye is
## on reached floor, not inside a wall.
func _entry_view(case: Dictionary, made: GeneratedBuilding, scene: Node3D, slug: String) -> void:
	var saved_family = _family
	var focus := Vector3.ZERO
	var eye := Vector3.ZERO
	if String(case["family"]) == "church":
		_family = &"church"
		var spec: ChurchSpec = made.spec
		var station := _church_axis_station(spec, [0.05, 0.08, 0.12, 0.16, 0.22])
		var builder := ChurchBuilder.new()
		builder.build(spec)
		var altar: Dictionary = {}
		for p in builder.prop_log:
			if p["kind"] == &"altar" and (p["rect"] as Rect2).size.x > 0.0:
				altar = p
		if not bool(station.get("ok", false)) or altar.is_empty():
			push_error("no entry station or altar: " + String(case["id"]))
			_family = saved_family
			return
		var sp: Vector2 = station["position"]
		eye = Vector3(sp.x, float(station["floor_y"]) + 1.65, sp.y)
		var ah := PropCatalog.height(String(altar["key"])) * float(altar["scale"])
		var ap: Vector3 = altar["pos"]
		focus = Vector3(ap.x, ap.y + ah * 0.8, ap.z)
		_cam.fov = 62.0
	else:
		var tspec: TempleSpec = made.spec
		# A ziggurat has no roof, so the night rig only blacks out its stair walls.
		_family = &"temple_dusk" if tspec.form == &"ziggurat" else &"temple_dark"
		var tstation := _temple_axis_station(tspec)
		if not bool(tstation.get("ok", false)):
			push_error("no entry station: " + String(case["id"]))
			_family = saved_family
			return
		var tp: Vector2 = tstation["position"]
		var idol: Vector3 = TempleGeometry.idol_center(tspec)
		eye = Vector3(tp.x, float(tstation["floor_y"]) + 1.65, tp.y)
		focus = Vector3(idol.x, idol.y + tspec.idol_height * 0.55,
			idol.z - tspec.idol_width * 0.5 - 0.05)
		_cam.fov = 60.0
	_cam.position = eye
	_cam.look_at(focus, Vector3.UP)
	_set_shot_lighting(atan2(-_cam.global_transform.basis.z.x, -_cam.global_transform.basis.z.z),
		eye.distance_to(focus) + 10.0)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var target := ProjectSettings.globalize_path(_out).path_join("%s__entry.jpg" % slug)
	_vp.get_texture().get_image().save_jpg(target, 0.92)
	print("  ", target)
	_family = saved_family
