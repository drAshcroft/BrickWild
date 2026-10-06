extends SceneTree
## Re-shoots every pin of every human walk review from its own camera pose, so
## a fix round can be compared with the walker's screenshots side by side.
## NOT headless (the dummy renderer makes no image).
##   godot --path . --script res://tools/render_walk_pins.gd -- [since=2026-10-06] [out=artifacts/walk_pins]
## Output: <out>/<kind>_<review>_<n>.png, next to visualqa/walk_shots/<same pin>.

const PINS := "res://visualqa/walk_pins.jsonl"


func _initialize() -> void:
	root.size = Vector2i(792, 648)
	_run.call_deferred()


func _run() -> void:
	var since := ""
	var out := "res://artifacts/walk_pins/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("since="):
			since = a.trim_prefix("since=")
		elif a.begins_with("out="):
			out = "res://" + a.trim_prefix("out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var f := FileAccess.open(PINS, FileAccess.READ)
	while f != null and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var review: Dictionary = JSON.parse_string(line)
		if review == null or String(review.get("time", "")) < since:
			continue
		if (review.get("pins", []) as Array).is_empty():
			continue
		await _shoot(review, out)
	quit()


func _shoot(review: Dictionary, out: String) -> void:
	var req := BuildingRequest.from_dict(review["request"])
	var b := BrickWild.generate(req)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	# the rig's lawn, so nothing below ground shows and colours read as walked
	var lawn := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.36, 0.5, 0.3)
	plane.material = grass
	lawn.mesh = plane
	lawn.position.y = -0.03
	world.add_child(lawn)
	world.add_child(BrickWild.instantiate(b, bool(review.get("cutaway", false)), true))
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.fov = 75
	world.add_child(cam)
	var lantern := OmniLight3D.new()
	lantern.omni_range = 9.0
	lantern.light_energy = 1.1
	cam.add_child(lantern)
	cam.make_current()
	var tag := String(review["time"]).replace(":", "").replace("-", "")
	for pin in review["pins"]:
		var c: Array = pin["camera"]
		var l: Array = pin["look"]
		var at := Vector3(c[0], c[1], c[2])
		cam.global_position = at
		cam.look_at(at + Vector3(l[0], l[1], l[2]), Vector3.UP)
		for i in range(6):
			await process_frame
		var path := out + "%s_%s_%d.png" % [String(req.kind), tag, int(pin["n"])]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("saved ", path, "  <- ", pin["screenshot"])
	world.queue_free()
	await process_frame
