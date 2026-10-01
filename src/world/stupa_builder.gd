class_name StupaBuilder
extends MassBuilder
## Revolved solid dome, two walkable rings, harmika, chatra and four toranas.

const SURF_STONE := 0
const SURF_TRIM := 1
const SEGMENTS := 64


func build(spec: StupaSpec) -> ArrayMesh:
	begin_metric(2)
	if spec == null:
		return commit()
	_build_mound(spec)
	_build_paths(spec)
	_build_harmika_and_chatra(spec)
	_build_toranas(spec)
	total_height = spec.height
	return commit()


func _build_mound(spec: StupaSpec) -> void:
	tag("dome")
	host("dome", 0)
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(spec.dome_radius, 0.0),
		Vector2(spec.dome_radius * 0.98, spec.dome_rise * 0.14),
		Vector2(spec.dome_radius * 0.90, spec.dome_rise * 0.42),
		Vector2(spec.dome_radius * 0.70, spec.dome_rise * 0.70),
		Vector2(spec.dome_radius * 0.40, spec.dome_rise * 0.91),
		Vector2(0.0, spec.dome_rise),
	])
	var center := Vector3(0, spec.dome_base_y, 0)
	_kit.revolve(profile, center, SURF_STONE, SEGMENTS)
	var dome_box := AABB(Vector3(-spec.dome_radius, center.y, -spec.dome_radius),
		Vector3(spec.dome_radius * 2.0, spec.dome_rise, spec.dome_radius * 2.0))
	component_note("stupa_dome", "revolved_solid", SURF_STONE, {
		"aabb": dome_box, "profile": profile, "segments": SEGMENTS,
		"solid_volume": _dome_volume(spec), "base_capped": true})
	_log_mass("stupa_dome", dome_box, spec.dome_base_y)
	host_end()


func _build_paths(spec: StupaSpec) -> void:
	# Annular platforms and a pair of opposite flights. The paths are deliberately
	# retained as named components so QA measures emitted radii and stair links.
	for row in [
		{"name": "ground", "inner": spec.ground_ring_inner,
			"outer": spec.ground_ring_outer, "y": 0.0},
		{"name": "drum", "inner": spec.drum_ring_inner,
			"outer": spec.drum_ring_outer, "y": spec.drum_y},
	]:
		var inner := float(row["inner"])
		var outer := float(row["outer"])
		var y := float(row["y"])
		var profile := PackedVector2Array([Vector2(inner, y), Vector2(outer, y)])
		var center := Vector3.ZERO
		_kit.revolve(profile, center, SURF_STONE, SEGMENTS)
		var ring_box := AABB(Vector3(-outer, y, -outer), Vector3(outer * 2.0, 0.0, outer * 2.0))
		host(String(row["name"]), 0)
		component_note("%s_circumambulatory_ring" % row["name"], "annular_revolve",
			SURF_STONE, {"aabb": ring_box, "inner_radius": inner,
			"outer_radius": outer, "y": y, "segments": SEGMENTS})
		_log_mass("%s_circumambulatory_ring" % row["name"], ring_box, y)
		host_end()
	# Stairs rise one flight from ground path to the terrace. The diametric
	# opposite flight makes the ring connection usable from either approach.
	for side in [-1.0, 1.0]:
		var inner_x := side * (spec.drum_radius - 0.25)
	var span := 2.2
		var stair_aabb := AABB(Vector3(minf(inner_x, inner_x + side * span), 0.0, -2.0),
			Vector3(span, spec.drum_y, 4.0))
		var steps := maxi(int(ceil(spec.drum_y / 0.25)), 1)
		host("double_stair", 0)
		for i in range(steps):
			var dx := span / steps
			var step_x: float
			if side > 0:
				step_x = inner_x + dx * (float(i) + 0.5)
			else:
				step_x = inner_x - dx * (float(i) + 0.5)
			var top := spec.drum_y * (1.0 - float(i + 1) / steps)
			var step_size := Vector3(dx + 0.01, maxf(top, 0.05), 4.0)
			var step_center := Vector3(step_x, step_size.y * 0.5, 0)
			component_box("stupa_stair_tread", step_size,
				Transform3D(Basis.IDENTITY, step_center), SURF_TRIM)
		component_note("stupa_double_stair", "stair_group", SURF_TRIM,
			{"aabb": stair_aabb, "side": side, "steps": steps})
		_log_mass("stupa_stair_%s" % str(side), stair_aabb)
		host_end()


func _build_harmika_and_chatra(spec: StupaSpec) -> void:
	var dome_top := spec.dome_base_y + spec.dome_rise
	var harmika_size := Vector3(2.8, 1.1, 2.8)
	var harmika_center := Vector3(0, dome_top + harmika_size.y * 0.5, 0)
	host("harmika", 0)
	component_box("stupa_harmika", harmika_size,
		Transform3D(Basis.IDENTITY, harmika_center), SURF_TRIM)
	_log_mass("stupa_harmika", AABB(harmika_center - harmika_size * 0.5, harmika_size))
	host_end()
	var shaft_height := maxf(0.5, spec.height - (harmika_center.y + harmika_size.y * 0.5) - 0.76)
	var shaft_size := Vector3(0.48, shaft_height, 0.48)
	var shaft_center := Vector3(0, harmika_center.y + harmika_size.y * 0.5 + shaft_height * 0.5, 0)
	host("chatra", 0)
	component_box("stupa_chatra_shaft", shaft_size,
		Transform3D(Basis.IDENTITY, shaft_center), SURF_TRIM)
	_log_mass("stupa_chatra_shaft", AABB(shaft_center - shaft_size * 0.5, shaft_size))
	for i in range(3):
		var radius := 1.7 - 0.38 * i
		var y := shaft_center.y + shaft_height * 0.5 + 0.16 + 0.22 * i
		var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(radius, 0.0),
			Vector2(radius, 0.16), Vector2(0.0, 0.16)])
		_kit.revolve(profile, Vector3(0, y, 0), SURF_TRIM, 32)
		var cap_box := AABB(Vector3(-radius, y, -radius), Vector3(radius * 2.0, 0.16, radius * 2.0))
		component_note("stupa_chatra_disc", "annular_revolve", SURF_TRIM,
			{"aabb": cap_box, "radius": radius, "axis_y": y})
		_log_mass("stupa_chatra_disc_%d" % i, cap_box, y)
	var top := shaft_center.y + shaft_height * 0.5 + 0.16 + 0.44 + 0.16
	total_height = top
	host_end()


func _build_toranas(spec: StupaSpec) -> void:
	for i in range(4):
		var angle := i * PI * 0.5
		var radial := Vector3(cos(angle), 0, sin(angle))
		var center := radial * spec.torana_radius + Vector3(0, 3.4, 0)
		var width := 3.0
		var post_size := Vector3(0.38, 6.8, 0.42)
		var tangent := Vector3(-radial.z, 0, radial.x)
		var yaw := angle + PI * 0.5
		host("torana_%d" % i, 0)
		for side in [-1.0, 1.0]:
			var post_center := center + tangent * width * 0.5 * side
			component_box("torana_post", post_size,
				Transform3D(Basis(Vector3.UP, yaw), post_center), SURF_TRIM)
		var beam_size := Vector3(width + 0.5, 0.38, 0.5)
		for level in [5.4, 6.2, 7.0]:
			var beam_center := Vector3(center.x, level, center.z)
			component_box("torana_lintel", beam_size,
				Transform3D(Basis(Vector3.UP, yaw), beam_center), SURF_TRIM)
		var mass := AABB(Vector3(center.x - 2.0, 0.0, center.z - 2.0), Vector3(4.0, 7.3, 4.0))
		component_note("torana_cardinal_mass", "aabb", SURF_TRIM,
			{"aabb": mass, "angle": angle, "radius": Vector2(center.x, center.z).length()})
		_log_mass("stupa_torana_%d" % i, mass)
		host_end()


static func _dome_volume(spec: StupaSpec) -> float:
	# Revolved measured profile integral. Simpson/trapezoid sampling is exact
	# enough for the broad, piecewise-linear architectural profile.
	var heights := [0.0, 0.14, 0.42, 0.70, 0.91, 1.0]
	var radii := [1.0, 0.98, 0.90, 0.70, 0.40, 0.0]
	var volume := 0.0
	for i in range(heights.size() - 1):
		var dy := (heights[i + 1] - heights[i]) * spec.dome_rise
		var r0 := radii[i] * spec.dome_radius
		var r1 := radii[i + 1] * spec.dome_radius
		volume += PI * dy * (r0 * r0 + r0 * r1 + r1 * r1) / 3.0
	return volume
