extends SceneTree
## Photographs the bridge family to res://artifacts/bridge_renders/.
##
## Must run WITHOUT --headless: the headless dummy renderer cannot produce an
## image. Model it on tools/render_shots.gd and tools/render_trees.gd.
##
##   godot --path . --script res://tools/render_bridges.gd
##
## A bridge runs along X, so its PROFILE is a shot from +-Z and yaw 0. A yaw
## of PI/2 is an ELEVATION -- down the end of the span -- and it puts the near
## bank between the camera and the subject, which buries the bridge in its own
## site. That is what the first pass of this tool did to every shot in it.
##
## Every shot is a bridge IN ITS SITE, never a bridge on a table: the banks
## come out of the same `BridgeGeometry.bank_height_at` the abutments were
## computed from, so what is in frame is what the geometry actually agreed to
## stand on. The four kinds are shot twice -- a three-quarter aerial and a
## straight SIDE ELEVATION -- because a bridge is judged in profile and a
## three-quarter view alone will hide a bad arch springing.

const OUT := "res://artifacts/bridge_renders"
const SHOT := Vector2i(1200, 820)

var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _shots := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var manifest: Array = []

	# ---- the four kinds, three-quarter and in profile ----
	for kind in [&"stone", &"covered", &"rope", &"mobile"]:
		var spec: BridgeSpec = BridgeAssembler.showcase(kind, 4400 + _i(kind))
		BridgeGenerator.generate(spec, 4400 + _i(kind))
		manifest.append(await _shoot(spec, "%s.jpg" % kind, 0.62, -0.16, 1.0))
		manifest.append(await _shoot(spec, "%s_side.jpg" % kind, 0.0, -0.04, 1.0))

	# ---- the four mobile mechanisms, side by side ----
	for motion in BridgeGenerator.MOTIONS:
		var spec := BridgeAssembler.showcase(&"mobile", 4600)
		spec.motion = motion
		BridgeGenerator.generate(spec, 4600)
		manifest.append(await _shoot(spec, "mobile_%s.jpg" % motion, 0.0, -0.04, 1.0))

	# ---- the size range, which is where a family proves it is a family ----
	for row in [{"span": 9.0, "w": 2.2, "h": 2.2, "key": "stone_foot"},
			{"span": 120.0, "w": 7.0, "h": 9.0, "key": "stone_viaduct"},
			{"span": 180.0, "w": 9.0, "h": 14.0, "key": "rope_gorge"}]:
		var spec := BridgeAssembler.showcase(&"stone" if not String(row["key"]).begins_with("rope") else &"rope", 4800)
		spec.span = float(row["span"])
		spec.width = float(row["w"])
		spec.deck_height = float(row["h"])
		spec.bank_height = float(row["h"])
		spec.bank_run = float(row["span"]) * 0.35
		BridgeGenerator.generate(spec, 4800)
		manifest.append(await _shoot(spec, "%s.jpg" % row["key"], 0.68, -0.13, 1.0))

	var f := FileAccess.open(OUT + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("wrote %d images to %s" % [manifest.size(), OUT])
	quit()


func _i(kind: StringName) -> int:
	match kind:
		&"stone": return 0
		&"covered": return 1
		&"rope": return 2
		_: return 3


## Build the bridge, put it in its site, frame it, shoot it, report it.
func _shoot(spec: BridgeSpec, file: String, yaw: float, pitch: float,
		zoom: float) -> Dictionary:
	var node: Node3D = BridgeAssembler.build(spec)
	_root.add_child(node)
	await process_frame
	# FRAME THE BRIDGE, NOT THE SITE. `SceneBounds.of_node(node)` on the whole
	# assembly includes a hundred metres of riverbank, and the first pass of
	# this tool photographed the terrain with a bridge in the middle distance.
	# The subject is the mesh, and the site is a backdrop it stands in.
	var bridge_node: Node3D = node.get_node("Mesh")
	var aabb: AABB = SceneBounds.of_node(bridge_node)
	aabb = aabb.grow(maxf(spec.span * 0.10, 1.5))
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() * 0.5, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.1 * zoom
	# Stand at DECK height, not at the middle of the bridge's bounding box.
	# The box of a masonry arch bridge is mostly the piers, so its centre is a
	# metre or two above the road, and a camera put there looks down onto the
	# deck and hides the arches underneath it -- which are the whole reason
	# the kind exists. The eye goes where a person crossing would put it.
	centre.y = spec.deck_height * 0.62 + aabb.size.y * 0.16
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	await _capture(file)
	node.queue_free()
	await process_frame
	return {
		"key": file.get_basename(), "file": file,
		"kind": String(spec.kind),
		"motion": String(spec.motion) if spec.kind == &"mobile" else "",
		"species": "", "title": spec.variant_name,
		"span_m": spec.span, "width_m": spec.width,
		"deck_h": spec.deck_height,
		"piers": spec.piers.size(), "members": spec.members.size(),
		"built": "%d supports, %d members, %.1f m span, %.1f m wide"
			% [spec.piers.size(), spec.members.size(), spec.span, spec.width],
	}


# --------------------------------------------------------------------- stage

func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5f80ac")
	sm.sky_horizon_color = Color("cfd8e0")
	sm.ground_bottom_color = Color("54564a")
	sm.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)

	# The sun is FIXED and the camera moves, which is the one thing
	# docs/VISUAL_QA.md §4 S1 says not to do. Here every shot is a bridge in
	# its own site and a bridge is a silhouette, so a fixed key that rakes
	# across the span is deliberate: the profile shots all want the same light.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-128.0), 0.0)
	sun.light_energy = 2.0
	sun.light_color = Color("fff1d8")
	sun.shadow_enabled = true
	_root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(52.0), 0.0)
	fill.light_energy = 0.4
	fill.light_color = Color("9fb6d6")
	_root.add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.far = 4000.0
	_vp.add_child(_cam)


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	_shots += 1
	print("  ", file)
