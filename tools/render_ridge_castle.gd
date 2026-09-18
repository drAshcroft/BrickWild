extends SceneTree
## CASTLE-INTERIOR-FORMS reference renders for ridge castles, written to
## artifacts/renders/ridge/.
##
##   *_roof_on.jpg    the chain of ranges walking along its spine
##   *_roof_off.jpg   the same castle cut away: every range is now rooms,
##                    doors and furniture instead of a solid block of stone
##   *_hall.jpg       down into the great hall, the longest range
##   *_bays.jpg       overhead on a long range, where the bay partitions and
##                    the doors through them are legible
##
##   godot --path . --script res://tools/render_ridge_castle.gd
## Must NOT be headless: the dummy renderer writes no image.

const OUT := "res://artifacts/renders/ridge"
const SIZE := Vector2i(1400, 950)

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	for row in [["small", &"castle", 0], ["default", &"castle", 2],
			["large", &"fortress", 2]]:
		await _shots(String(row[0]), row[1], int(row[2]))
	print("done")
	quit()


func _ridge_spec(tier: StringName, index: int) -> CastleSpec:
	var spec: CastleSpec = CastleSweep.spec_at(&"norman", tier, index)
	spec.plan_kind = &"ridge"
	CastleGenerator.refit(spec)
	return spec


func _shots(label: String, tier: StringName, index: int) -> void:
	var spec := _ridge_spec(tier, index)
	if not CastleGeometry.is_ridge(spec):
		print("  %s is not a ridge castle; skipped" % label)
		return
	var rows: Dictionary = preload("res://src/castle/castle_interiors.gd").primary(spec)
	var segs: Array[Dictionary] = CastleGeometry.ridge_ranges(spec)
	var rooms := 0
	var furniture := 0
	for k in rows:
		var p: HousePlan = rows[k].plan
		rooms += p.rooms.size()
		furniture += p.furniture.size()
	print("  %s %sx%s: %d ranges, %d planned, %d rooms, %d pieces"
		% [label, spec.width, spec.length, segs.size(), rows.size(), rooms, furniture])

	# The spine runs along the longer side; frame the whole chain from off one
	# shoulder of it.
	var whole := CastleGeometry.enceinte_rect(spec, 0)
	var reach: float = maxf(whole.size.x, whole.size.y)
	var eye := Vector3(reach * 0.75, reach * 0.62, -reach * 0.85)
	var at := Vector3(0.0, spec.height * 0.35, 0.0)

	for cutaway in [false, true]:
		var castle := CastleAssembler.build(spec, cutaway)
		_stage.add_child(castle)
		# Roof on reads best from off one shoulder. Roof OFF has to look DOWN
		# into the ranges, or it is the same picture with different tiles: the
		# range walls stand full height either way.
		_cam.position = eye if not cutaway else Vector3(reach * 0.42, reach * 1.15, -reach * 0.42)
		_cam.look_at(at if not cutaway else Vector3.ZERO)
		await _save("ridge_%s_%s.jpg" % [label, "roof_off" if cutaway else "roof_on"])
		if not cutaway:
			# A straight elevation, PERPENDICULAR TO THE SPINE. The spine runs
			# along the longer side, so a camera parked on -Z looks straight
			# down the length of the chain and shows one range end with
			# everything else hidden behind it.
			var along_x: bool = spec.width >= spec.length
			var run: float = spec.width if along_x else spec.length
			var roof_y: float = spec.height * 0.62
			var back: float = run * 0.78
			_cam.position = Vector3(0.0, roof_y, -back) if along_x 				else Vector3(-back, roof_y, 0.0)
			_cam.look_at(Vector3(0.0, roof_y, 0.0))
			await _save("ridge_%s_front.jpg" % label)
		if cutaway:
			# Down into the great hall: the longest range, and the one with the
			# fire in it.
			var hall := _named(segs, "hall")
			if not hall.is_empty():
				var mid: Vector2 = (Vector2(hall["from"]) + Vector2(hall["to"])) * 0.5
				var span: float = float(hall["length"])
				var dir: Vector2 = hall["dir"]
				var side: Vector2 = Vector2(-dir.y, dir.x)
				# Along the hall from above one end, so the dais, the fire and
				# the rows of furniture are all in shot.
				var from_end: Vector2 = mid - dir * span * 0.62 + side * span * 0.18
				_cam.position = Vector3(from_end.x, spec.height * 1.25, from_end.y)
				_cam.look_at(Vector3(mid.x, spec.height * 0.15, mid.y))
				await _save("ridge_%s_hall.jpg" % label)
				# Straight down, far enough back to hold the whole range, so
				# the bay partitions read as walls rather than as shading.
				_cam.position = Vector3(mid.x, span * 1.15, mid.y)
				_cam.look_at(Vector3(mid.x + dir.x * 0.01, 0.0, mid.y + dir.y * 0.01))
				await _save("ridge_%s_bays.jpg" % label)
		castle.free()


static func _named(segs: Array[Dictionary], want: String) -> Dictionary:
	for s in segs:
		if String(s["name"]) == want:
			return s
	return {}


func _save(file: String) -> void:
	for _f in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT + "/" + file, 0.93)
	print("    ", file)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5c7ea8")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("52584a")
	sky_mat.ground_horizon_color = Color("97a08c")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -36, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	_stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 140, 0)
	fill.light_energy = 0.4
	_stage.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	ground.mesh = plane
	ground.position.y = -0.03
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("65705a")
	gm.roughness = 1.0
	ground.material_override = gm
	_stage.add_child(ground)

	_cam = Camera3D.new()
	_cam.fov = 48
	_cam.far = 2000
	_vp.add_child(_cam)
