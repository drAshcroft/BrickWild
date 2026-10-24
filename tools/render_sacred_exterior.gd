extends "res://tools/render_sacred_acceptance.gd"
## Roof-on exterior portraits for cases of the frozen sacred sequence matrix
## (tests/fixtures/sacred_sequence_requests.json), through the public API.
## Run WITHOUT --headless:
##   godot --path . --script res://tools/render_sacred_exterior.gd -- --out=res://artifacts/x --ids=temple/basilica/blood/default/1/pinned-barn,church/gothic/default/1
## Views per id: front (west 3/4), side (south, low), rear (east 3/4),
## cutaway (roof off, aerial 3/4 section), and entry: eye height at the first
## reached floor inside the door, aimed at the altar (church) or idol (temple).
## Pass --views=front,side,entry,cutaway to choose.
##
## --control=hide_focus|break_axis renders ONE entry image with a dark box
## across the axis, the negative control the unlabelled review must fail.
##   godot --path . --script res://tools/render_sacred_exterior.gd -- --out=res://artifacts/x --ids=church/gothic/default/1 --views=entry --control=hide_focus

const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"

var _out := "res://artifacts/sacred_exterior_20261014/renders"
var _ids: PackedStringArray = []
var _views: PackedStringArray = ["front", "side", "rear", "entry"]
var _control := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := String(arg)
		if t.begins_with("--out="):
			_out = t.trim_prefix("--out=")
		elif t.begins_with("--views="):
			_views = t.trim_prefix("--views=").split(",", false)
		elif t.begins_with("--ids="):
			_ids = t.trim_prefix("--ids=").split(",", false)
		elif t.begins_with("--control="):
			_control = t.trim_prefix("--control=")
	if _control not in ["", "hide_focus", "break_axis"]:
		push_error("--control must be hide_focus or break_axis")
		quit(2)
		return
	if _control != "":
		_views = PackedStringArray(["entry"])
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
	# The request exactly as the matrix froze it, as `sacredseq` reads it. This
	# tool used to rebuild it by hand from r.get("cult", &"flame"), but the matrix
	# stores the cult as `purpose`: every temple was rendered as a flame temple
	# (LIVE-SACRED, 20 Oct), which is what "cult identity is a tint" was seeing.
	var request := BuildingRequest.from_dict(case["request"])
	var made := BrickWild.generate(request)
	if not made.is_ok():
		push_error("generate failed " + String(case["id"]))
		return false
	var slug := String(case["id"]).replace("/", "_")
	# The building's long axis is z; the west door is at -z.
	var views := {"front": [-0.55, 0.38], "side": [1.57, 0.22], "rear": [PI + 0.55, 0.38]}
	for name in _views:
		# ONE scene per view: a roof-off scene is only for the cutaway. Sharing
		# one cutaway scene across the views left every "exterior" roofless and
		# floated the roof-mounted finials in the sky (caught by the unlabelled
		# review, 23 Oct), which is not the building anyone is shipped.
		var cutaway: bool = name == "cutaway"
		var scene: Node3D = BrickWild.instantiate(made, cutaway, false)
		_mesh_inst.mesh = null
		_root3d.add_child(scene)
		await process_frame
		var b: AABB = SceneBounds.of_node(scene)
		var c := b.get_center()
		var radius := maxf(b.size.length() * 0.5, 1.0)
		if name == "entry":
			await _entry_view(case, made, scene, slug)
			_root3d.remove_child(scene)
			scene.free()
			continue
		if name == "approach" and made.spec is ChurchSpec:
			# the exterior entry eye (SACRED-BYZANTINE-DOME): 1.6 m on the axis,
			# looking at the dome crown if there is one, else the ridge
			var cs: ChurchSpec = made.spec
			var eye := ChurchGeometry.entry_eye(cs)
			var aim := Vector3(0.0, ChurchGeometry.dome_crown_height(cs) if cs.dome 					else ChurchGeometry.nave_ridge_height(cs),
				ChurchGeometry.crossing_center_z(cs) if cs.dome else 0.0)
			_cam.fov = 60.0
			_cam.position = eye
			_cam.look_at(aim, Vector3.UP)
			_set_shot_lighting(atan2(-_cam.global_transform.basis.z.x, -_cam.global_transform.basis.z.z), 80.0)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var atarget := ProjectSettings.globalize_path(_out).path_join("%s__approach.jpg" % slug)
			_vp.get_texture().get_image().save_jpg(atarget, 0.92)
			print("  ", atarget)
			_root3d.remove_child(scene)
			scene.free()
			continue
		if cutaway:
			await _cutaway_view(slug, c, radius)
			_root3d.remove_child(scene)
			scene.free()
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


## Roof-off aerial section along the building's 3/4 diagonal: the same camera
## the frozen acceptance matrix uses for its cutaway view. This is the image
## that shows the axis, the congregation zone and the focus in one frame.
func _cutaway_view(slug: String, c: Vector3, radius: float) -> void:
	var yaw := 2.45
	_cam.fov = 52.0
	var direction := Vector3(sin(yaw), 1.0, cos(yaw)).normalized()
	var distance: float = radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.12
	_cam.position = c + direction * distance
	_cam.look_at(c, Vector3.UP)
	_set_shot_lighting(atan2(-_cam.global_transform.basis.z.x, -_cam.global_transform.basis.z.z),
		distance + radius)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var target := ProjectSettings.globalize_path(_out).path_join("%s__cutaway.jpg" % slug)
	_vp.get_texture().get_image().save_jpg(target, 0.92)
	print("  ", target)


## A dark box across the axis, between the eye and the focus. `hide_focus`
## stands taller than the eye; `break_axis` is a body-high barrier the eye sees
## over, so the review has one case per failure mode. Added to the generated
## scene so it is freed with it.
func _add_control_blocker(case: Dictionary, made: GeneratedBuilding, scene: Node3D,
		eye: Vector3, focus: Vector3) -> void:
	var size := Vector3(4.0, 8.0, 0.3)
	if String(case["family"]) == "church":
		var spec: ChurchSpec = made.spec
		size = Vector3(maxf(spec.width - 0.8, 2.0), 3.0, 0.3)
		if _control == "break_axis":
			size.y = 1.35
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.12, 0.10)
	material.roughness = 0.9
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.material_override = material
	var mid := (eye + focus) * 0.5
	inst.position = Vector3(mid.x, eye.y - 1.65 + size.y * 0.5, mid.z)
	scene.add_child(inst)


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
	if _control != "":
		_add_control_blocker(case, made, scene, eye, focus)
	_set_shot_lighting(atan2(-_cam.global_transform.basis.z.x, -_cam.global_transform.basis.z.z),
		eye.distance_to(focus) + 10.0)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "__entry.jpg" if _control == "" else "__control_%s.jpg" % _control
	var target := ProjectSettings.globalize_path(_out).path_join(slug + suffix)
	_vp.get_texture().get_image().save_jpg(target, 0.92)
	print("  ", target)
	_family = saved_family
