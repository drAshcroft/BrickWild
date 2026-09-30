extends "res://tools/render_shots.gd"
## Same fixed gate-side cameras for CAS-REG-002 baseline and repaired geometry.

const RENDER_DIR := "res://artifacts/cas_reg_002/renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RENDER_DIR))
	_build_stage()
	await process_frame
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.width = 90.0
	spec.length = 140.0
	spec.height = 20.0
	CastleGenerator.generate(spec, 9118)
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	var mesh := builder.commit()
	var args := OS.get_cmdline_user_args()
	var prefix := String(args[0]) if not args.is_empty() else "after"
	for shot in [
		{"name": "clearance_overhead", "yaw": 0.15, "pitch": -1.22, "focus": Vector3(-18, 10, -62), "radius": 18.0},
		{"name": "clearance_raking", "yaw": 0.75, "pitch": -0.72, "focus": Vector3(-18, 12, -63), "radius": 16.0},
	]:
		var path := RENDER_DIR + "/%s_%s.jpg" % [prefix, shot.name]
		_mesh_inst.mesh = mesh
		var colours := [spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")]
		for surface in mesh.get_surface_count():
			var material := StandardMaterial3D.new()
			material.albedo_color = colours[surface]
			material.roughness = 0.92
			_mesh_inst.set_surface_override_material(surface, material)
		var direction := Vector3(sin(shot.yaw) * cos(shot.pitch), -sin(shot.pitch),
			cos(shot.yaw) * cos(shot.pitch))
		var distance: float = float(shot.radius) / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12
		_cam.position = shot.focus + direction * distance
		_cam.look_at(shot.focus, Vector3.UP)
		_set_shot_lighting(shot.yaw)
		for frame in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = _vp.get_texture().get_image()
		image.save_jpg(ProjectSettings.globalize_path(path), 0.94)
		print("CAS_REG_002_RENDER ", path, " prefix=", prefix, " camera=", shot.name)
	quit()
