extends RefCounted
## Voxel aperture checks must accept a real hole and reject invented opening
## logs or missing surrounds. Large openings separate the four support probes
## despite the voxel grid's deliberate one-cell dilation.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle apertures")
	for yaw in [0.0, PI * 0.5, 0.37]:
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(13, 2, -7))
		var qa := _fixture(xf)
		qa._check_openings()
		_want(res, qa.failures.is_empty(), "real aperture rejected at yaw %s: %s" % [yaw, qa.failures])
		_want(res, qa.stats.openings_checked == 1, "planned aperture not counted")
		qa.builder.part_log[0].pos += Vector3(100, 0, 100)
		qa.failures.clear()
		qa._check_openings()
		_want(res, qa.failures.size() == 4, "moved window borrowed boundary masonry")
	for missing in ["left jamb", "right jamb", "head", "sill"]:
		var qa := _fixture(Transform3D.IDENTITY, missing)
		qa._check_openings()
		_want(res, _contains(qa.failures, missing), "missing %s was accepted" % missing)
	var invalid := _fixture(Transform3D.IDENTITY)
	invalid.builder.part_log[0].facing = Vector3.ZERO
	invalid._check_openings()
	_want(res, _contains(invalid.failures, "invalid"), "zero facing accepted")
	# Recesses still require backing; the real-aperture branch must not make
	# the existing painted slit rule accept a floating overlay.
	var legacy := CastleQA.new()
	legacy.builder = CastleBuilder.new()
	legacy.builder.begin(1)
	legacy.builder.box(Vector3(4, 4, 1), Vector3.ZERO, 0)
	legacy.builder.part_log.append({"kind": "window", "tag": "legacy", "pos": Vector3(0, 0, -0.5)})
	legacy._grid = VoxelGrid.new()
	legacy._grid.rasterize(legacy.builder.commit(), -1, 0.25)
	legacy._check_openings()
	_want(res, legacy.failures.is_empty(), "embedded legacy slit rejected")
	legacy.builder.part_log[-1].pos = Vector3(0, 10, 0)
	legacy.failures.clear()
	legacy._check_openings()
	_want(res, not legacy.failures.is_empty(), "floating legacy slit accepted")
	_keep_triangle_rays(res)
	_curtain_triangle_rays(res)
	_polygon_curtain_triangle_rays(res)
	_tower_triangle_rays(res)
	return res


## A dark opening box still intersects its own ray. Restricting this probe to
## stone triangles proves the masonry itself has been removed through the wall.
static func _keep_triangle_rays(res: SuiteResult) -> void:
	var builder := CastleBuilder.new()
	builder.begin_metric(4)
	builder.spec = CastleSpec.new()
	builder.spec.window_w = 2.0
	builder.spec.window_h = 2.5
	var bounds := AABB(Vector3(-5, 0, -5), Vector3(10, 12, 10))
	builder._cut_keep_shell(bounds, 6.0)
	builder._keep_windows(bounds, 6.0, &"square")
	var mesh := builder.commit()
	var clear := not _stone_ray_hits(mesh, 0, Vector3(0, 6, -8), Vector3.BACK, 16.0)
	var no_insert := not _any_surface_ray_hits(mesh, Vector3(0, 6, -8), Vector3.BACK, 6.0)
	var full_route_clear := not _any_surface_ray_hits(mesh,
		Vector3(0, 6, -8), Vector3.BACK, 16.0)
	var blocked := _stone_ray_hits(mesh, 0, Vector3(1.2, 6, -8), Vector3.BACK, 16.0)
	_want(res, clear, "keep window still has stone behind its dark opening face")
	_want(res, no_insert, "keep window contains a dark surface insert in the opening")
	_want(res, full_route_clear,
		"keep window route is blocked before reaching the opposite exterior")
	_want(res, blocked, "adjacent keep masonry was lost with the window aperture")
	_check_logged_returns(res, builder, mesh, "keep")


static func _tower_triangle_rays(res: SuiteResult) -> void:
	var builder := CastleBuilder.new()
	builder.begin_metric(4)
	builder.spec = CastleSpec.new()
	var c := Vector3.ZERO
	var details: Dictionary = builder._battered_tower_skin(c, 4.0, 3.4, 10.0,
		4, PI / 4.0, Vector3(0, 0, -1))
	builder._opening(details.pos, details.angle, details.width, details.height,
		&"slit", false, true, details.depth)
	var mesh := builder.commit()
	var normal := Vector3(sin(details.angle), 0, cos(details.angle))
	var tangent := Vector3(cos(details.angle), 0, -sin(details.angle))
	var clear := not _stone_ray_hits(mesh, 0, details.pos + normal * 3.0,
		-normal, 6.0)
	var no_insert := not _any_surface_ray_hits(mesh, details.pos + normal * 3.0,
		-normal, 6.0)
	var adjacent := _stone_ray_hits(mesh, 0, details.pos + tangent * 0.6 + normal * 3.0,
		-normal, 6.0)
	var far_face := _stone_first_hit(mesh, 0, details.pos + normal * 3.0, -normal, 30.0)
	_want(res, clear, "battered tower facet still has stone behind the slit")
	_want(res, no_insert, "battered tower slit contains a surface insert")
	_want(res, adjacent, "battered tower slit removed adjacent facet masonry")
	_want(res, far_face > 6.0 and far_face < 14.0,
		"tower ray should pass the near face and hit only the far shell (distance %.2f)" % far_face)
	_check_logged_returns(res, builder, mesh, "battered tower")


static func _polygon_curtain_triangle_rays(res: SuiteResult) -> void:
	var builder := CastleBuilder.new()
	builder.begin_metric(5)
	builder.spec = CastleSpec.new()
	CastleGenerator.generate(builder.spec, 6003)
	var seg := {
		"a": Vector2(-8.0, 0.0), "b": Vector2(8.0, 0.0),
		"length": 16.0, "yaw": 0.0, "outward": Vector3(0, 0, 1),
		"name": "aperture_fixture",
	}
	builder.tag("curtain")
	builder._wall_run(seg, 0)
	var mesh := builder.commit()
	var slit: Dictionary = {}
	for part in builder.part_log:
		if part.get("kind") == "window" and part.get("tag") == "curtain":
			slit = part
			break
	_want(res, not slit.is_empty(), "polygon curtain slit was not logged")
	if slit.is_empty():
		return
	var pos: Vector3 = slit.pos
	var normal: Vector3 = slit.facing.normalized()
	var tangent := Vector3(normal.z, 0.0, -normal.x)
	var origin := pos + normal * 3.0
	var clear := not _any_surface_ray_hits(mesh, origin, -normal, 6.0)
	var adjacent := _stone_ray_hits(mesh, 0, origin + tangent * 0.55, -normal, 6.0)
	_want(res, clear, "polygon curtain slit still contains a mesh surface")
	_want(res, adjacent, "polygon curtain slit removed adjacent masonry")
	_check_logged_returns(res, builder, mesh, "polygon curtain")


static func _curtain_triangle_rays(res: SuiteResult) -> void:
	var builder := CastleBuilder.new()
	builder.begin_metric(4)
	builder.spec = CastleSpec.new()
	var bounds := AABB(Vector3(-8, 0, -8), Vector3(16, 8, 1.5))
	var outward := Vector3(0, 0, -1)
	var points := builder._wall_slit_positions(bounds, outward, 1.5)
	builder._battered_wall(bounds, 1.5, outward, points)
	builder._emit_wall_slits(points, outward, true, 1.15)
	var mesh := builder.commit()
	var slit: Vector3 = points[0]
	var clear := not _stone_ray_hits(mesh, 0, slit + Vector3(0, 0, -3), Vector3.BACK, 6.0)
	var no_insert := not _any_surface_ray_hits(mesh, slit + Vector3(0, 0, -3), Vector3.BACK, 6.0)
	var adjacent := _stone_ray_hits(mesh, 0, slit + Vector3(0.55, 0, -3), Vector3.BACK, 6.0)
	_want(res, clear, "straight curtain slit still has stone behind its dark face")
	_want(res, no_insert, "straight curtain slit contains a surface insert")
	_want(res, adjacent, "straight curtain slit removed adjacent masonry")
	_check_logged_returns(res, builder, mesh, "straight curtain")


static func _check_logged_returns(res: SuiteResult, builder: CastleBuilder,
		mesh: ArrayMesh, label: String) -> void:
	var qa := CastleQA.new()
	qa.builder = builder
	qa._grid = VoxelGrid.new()
	qa._grid.rasterize(mesh, -1, 0.25)
	qa._check_openings()
	_want(res, qa.failures.is_empty(), "%s through opening has mismatched returns/logs: %s" % [label, qa.failures])


static func _stone_ray_hits(mesh: ArrayMesh, surface: int, origin: Vector3,
		direction: Vector3, distance: float) -> bool:
	return _stone_first_hit(mesh, surface, origin, direction, distance) <= distance


static func _stone_first_hit(mesh: ArrayMesh, surface: int, origin: Vector3,
		direction: Vector3, distance: float) -> float:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	return _triangle_first_hit(vertices, origin, direction, distance)


static func _any_surface_ray_hits(mesh: ArrayMesh, origin: Vector3,
		direction: Vector3, distance: float) -> bool:
	for surface in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if _triangle_first_hit(vertices, origin, direction, distance) <= distance:
			return true
	return false


static func _triangle_first_hit(vertices: PackedVector3Array, origin: Vector3,
		direction: Vector3, distance: float) -> float:
	var nearest := INF
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		var e1 := b - a
		var e2 := c - a
		var p := direction.cross(e2)
		var det := e1.dot(p)
		if absf(det) < 0.000001:
			continue
		var inv := 1.0 / det
		var tvec := origin - a
		var u := tvec.dot(p) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := tvec.cross(e1)
		var v := direction.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var t := e2.dot(q) * inv
		if t >= 0.0 and t <= distance:
			nearest = minf(nearest, t)
	return nearest


static func _fixture(xf: Transform3D, missing := "") -> CastleQA:
	var kit := MeshKit.new(2)
	var pieces := {
		"left jamb": [Vector3(0.5, 5, 0.6), Vector3(-3.25, 0, 0)],
		"right jamb": [Vector3(0.5, 5, 0.6), Vector3(3.25, 0, 0)],
		"head": [Vector3(6, 0.5, 0.6), Vector3(0, 2.25, 0)],
		"sill": [Vector3(6, 0.5, 0.6), Vector3(0, -2.25, 0)],
	}
	for side in pieces:
		if side != missing:
			kit.oriented_box(pieces[side][0], xf * Transform3D(Basis(), pieces[side][1]), 0)
	# The glass cannot supply masonry where a surround was removed.
	kit.oriented_box(Vector3(6, 4, 0.04), xf, 1)
	var qa := CastleQA.new()
	qa.builder = CastleBuilder.new()
	qa.builder.part_log.append({"kind": "window", "tag": "fixture", "planned_opening": true,
		"pos": xf.origin, "size": Vector3(6, 4, 0), "facing": xf.basis * Vector3.BACK})
	qa._grid = VoxelGrid.new()
	qa._grid.rasterize(kit.commit(), 1, 0.25)
	return qa


static func _contains(messages: Array, text: String) -> bool:
	for message in messages:
		if text in String(message):
			return true
	return false


static func _want(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
