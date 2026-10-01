class_name StupaCheck
extends RefCounted
## WLD-017: emitted dome, circumambulatory rings, axis and cardinal gates.

const RING_SAMPLES := 48
const GRID_CELL := 0.20


func check(spec: StupaSpec, builder: StupaBuilder) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"count_solid": 0, "dome_volume": 0.0, "walk_ground": 0,
		"walk_drum": 0, "toranas": 0, "torana_radius_spread": 0.0}
	if spec == null or builder == null:
		return {"ok": false, "failures": ["solid: missing stupa spec or emitted builder"],
			"warnings": [], "stats": stats, "replaced": {"walk": "StupaCheck rings and stairs"}}
	_check_solid(spec, builder, failures, stats)
	_check_dome(spec, builder, failures)
	_check_walk(spec, builder, failures, stats)
	_check_cardinal(builder, failures, stats)
	_check_dominance(spec, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": stats, "replaced": {"walk": "StupaCheck full ground/drum rings and double stair"}}


func _check_solid(spec: StupaSpec, builder: StupaBuilder,
		failures: Array[String], stats: Dictionary) -> void:
	var dome := _component(builder, "stupa_dome")
	if dome.is_empty():
		failures.append("solid: emitted revolved dome is missing")
		return
	if not bool(dome.get("base_capped", false)):
		failures.append("solid: dome base is open and outside air reaches its core")
		return
	var profile: PackedVector2Array = dome.get("profile", PackedVector2Array())
	if profile.size() < 3:
		failures.append("solid: emitted dome profile cannot enclose a solid")
		return
	var measured := _voxel_solid_volume(profile, spec.dome_radius, spec.dome_rise)
	var expected := float(dome.get("solid_volume", 0.0))
	stats["count_solid"] = int(round(measured / pow(GRID_CELL, 3)))
	stats["dome_volume"] = measured
	if expected <= 0.0 or absf(measured - expected) / expected > 0.05:
		failures.append("solid: voxel count_solid differs from revolved volume by more than 5%%")
	# The dome profile describes a closed, filled section down to a capped base.
	# Flooding its occupancy grid from the padded boundary must leave no air
	# sample inside the dome's analytic envelope.
	if _interior_air_count(profile, spec.dome_radius, spec.dome_rise) != 0:
		failures.append("solid: outside voxel flood reaches interior dome air")


func _check_dome(spec: StupaSpec, builder: StupaBuilder,
		failures: Array[String]) -> void:
	var harmika := _mass(builder, "stupa_harmika")
	var dome_top := spec.dome_base_y + spec.dome_rise
	if harmika.is_empty():
		failures.append("dome: centered harmika mass is missing")
	else:
		var h: AABB = harmika["aabb"]
		if Vector2(h.get_center().x, h.get_center().z).length() > 0.05 \
				or absf(h.position.y - dome_top) > 0.05:
			failures.append("dome: harmika is not centered on the dome crown")
	var chatra := _mass(builder, "stupa_chatra_shaft")
	var highest := -INF
	var axial_highest := -INF
	for row in builder.mass_log:
		var box: AABB = row.get("aabb", AABB())
		highest = maxf(highest, box.end.y)
		if String(row.get("name", "")).begins_with("stupa_chatra"):
			axial_highest = maxf(axial_highest, box.end.y)
	if chatra.is_empty():
		failures.append("dome: axial chatra shaft is missing")
	else:
		var c: AABB = chatra["aabb"]
		if Vector2(c.get_center().x, c.get_center().z).length() > 0.05 \
				or axial_highest <= 0.0 or highest - axial_highest > 0.05:
			failures.append("dome: chatra is not the topmost axial mass")


func _check_walk(spec: StupaSpec, builder: StupaBuilder,
		failures: Array[String], stats: Dictionary) -> void:
	var ground := _component(builder, "ground_circumambulatory_ring")
	var drum := _component(builder, "drum_circumambulatory_ring")
	if ground.is_empty() or drum.is_empty():
		failures.append("circle: both full circumambulatory rings must be emitted")
		return
	if float(ground.get("inner_radius", 0.0)) >= float(ground.get("outer_radius", 0.0)) \
			or float(drum.get("inner_radius", 0.0)) >= float(drum.get("outer_radius", 0.0)):
		failures.append("circle: a circumambulatory path has no annular width")
		return
	var grid := WalkGrid.new()
	grid.setup(Rect2(Vector2(-20, -20), Vector2(40, 40)), GRID_CELL)
	_add_ring(grid, float(ground["inner_radius"]), float(ground["outer_radius"]), 0.0)
	_add_ring(grid, float(drum["inner_radius"]), float(drum["outer_radius"]), spec.drum_y)
	var stairs := 0
	for row in builder.component_log:
		if String(row.get("role", "")) != "stupa_double_stair":
			continue
		stairs += 1
		var box: AABB = MassBuilder.component_aabb(row)
		var steps := maxi(int(ceil(spec.drum_y / 0.25)), 1)
		var side := float(row.get("side", 1.0))
		for i in range(steps):
			var dx := box.size.x / steps
			var x0: float
			if side > 0:
				x0 = box.position.x + dx * i
			else:
				x0 = box.end.x - dx * (i + 1)
			var xz := Rect2(Vector2(x0, box.position.z), Vector2(dx, box.size.z))
			grid.add_step(xz, spec.drum_y * (1.0 - float(i + 1) / steps))
	if stairs != 2:
		failures.append("circle: expected two emitted stairs between the ground and drum rings")
	grid.build(0.16)
	if not grid.flood_from(Vector2(0, -spec.ground_ring_outer + 0.8)):
		failures.append("circle: ground ring has no walkable starting point")
		return
	var ground_reached := _ring_coverage(grid, float(ground["inner_radius"]), float(ground["outer_radius"]))
	var drum_reached := _ring_coverage(grid, float(drum["inner_radius"]), float(drum["outer_radius"]))
	stats["walk_ground"] = ground_reached
	stats["walk_drum"] = drum_reached
	if ground_reached != RING_SAMPLES:
		failures.append("circle: ground path is not walkable all the way around (%d/%d)" % [ground_reached, RING_SAMPLES])
	if drum_reached != RING_SAMPLES:
		failures.append("circle: drum terrace path is not walkable all the way around (%d/%d)" % [drum_reached, RING_SAMPLES])
	if not grid.reached(Rect2(Vector2(spec.drum_radius + 0.1, -1.0), Vector2(1.4, 2.0)), 0.1) \
			and not grid.reached(Rect2(Vector2(-spec.drum_radius - 1.5, -1.0), Vector2(1.4, 2.0)), 0.1):
		failures.append("circle: double stair does not connect the ground path to the raised drum")


func _check_cardinal(builder: StupaBuilder, failures: Array[String], stats: Dictionary) -> void:
	var gates: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == "torana_cardinal_mass":
			gates.append(row)
	stats["toranas"] = gates.size()
	if gates.size() != 4:
		failures.append("cardinal: expected four torana masses, found %d" % gates.size())
		return
	var radii: Array[float] = []
	var angles: Array[float] = []
	for row in gates:
		var box: AABB = row.get("aabb", AABB())
		var centre := Vector2(box.get_center().x, box.get_center().z)
		radii.append(centre.length())
		angles.append(fposmod(atan2(centre.y, centre.x) + TAU, TAU))
	angles.sort()
	var spread: float = radii.max() - radii.min()
	stats["torana_radius_spread"] = spread
	if spread > 0.05:
		failures.append("cardinal: torana masses do not share one radius within 0.05m")
	for i in range(4):
		var expected := i * PI * 0.5
		if absf(wrapf(angles[i] - expected, -PI, PI)) > 0.01:
			failures.append("cardinal: torana masses are not at the four cardinal angles")
			break


func _check_dominance(spec: StupaSpec, builder: StupaBuilder,
		failures: Array[String]) -> void:
	var dome_top := spec.dome_base_y + spec.dome_rise
	var discs: Array[Dictionary] = []
	for row in builder.mass_log:
		if String(row.get("name", "")) == "stupa_chatra_disc_0" \
				or String(row.get("name", "")) == "stupa_chatra_disc_1" \
				or String(row.get("name", "")) == "stupa_chatra_disc_2":
			discs.append(row)
	if discs.size() != 3:
		failures.append("dominance: the three axial chatra discs are not all present")
		return
	var highest := -INF
	for row in builder.mass_log:
		var box: AABB = row.get("aabb", AABB())
		highest = maxf(highest, box.end.y)
	var chatra_top := -INF
	for row in discs:
		var box: AABB = row["aabb"]
		chatra_top = maxf(chatra_top, box.end.y)
	if chatra_top <= dome_top or highest - chatra_top > 0.05 \
			or chatra_top < spec.height - 0.1:
		failures.append("dominance: chatra is not the topmost axial feature at the requested height")


func _voxel_solid_volume(profile: PackedVector2Array, radius: float, rise: float) -> float:
	var occupied := 0
	var nr := int(ceil(radius / GRID_CELL))
	var ny := int(ceil(rise / GRID_CELL))
	for yi in range(ny):
		var y := (float(yi) + 0.5) * GRID_CELL
		var limit := _radius_at(profile, y)
		for xi in range(-nr, nr + 1):
			for zi in range(-nr, nr + 1):
				var x := (float(xi) + 0.5) * GRID_CELL
				var z := (float(zi) + 0.5) * GRID_CELL
				if x * x + z * z <= limit * limit:
					occupied += 1
	return float(occupied) * pow(GRID_CELL, 3)


func _interior_air_count(profile: PackedVector2Array, radius: float, rise: float) -> int:
	# Voxelize the emitted closed profile in a padded box, then flood air from
	# every boundary face. A cavity inside the measured dome remains unflooded;
	# an open base admits the outside flood beneath the shell.
	var nr := int(ceil(radius / GRID_CELL)) + 1
	var ny := int(ceil(rise / GRID_CELL)) + 2
	var nx := nr * 2 + 1
	var nz := nx
	var count := nx * ny * nz
	var solid := PackedByteArray()
	var reached := PackedByteArray()
	solid.resize(count)
	reached.resize(count)
	for i in range(count):
		solid[i] = 0
		reached[i] = 0
	var origin := Vector3(-float(nr) * GRID_CELL, -GRID_CELL,
		-float(nr) * GRID_CELL)
	for x_i in range(nx):
		for y_i in range(ny):
			for z_i in range(nz):
				var p := origin + Vector3((float(x_i) + 0.5) * GRID_CELL,
					(float(y_i) + 0.5) * GRID_CELL, (float(z_i) + 0.5) * GRID_CELL)
				if p.y < 0.0 or p.y > rise:
					continue
				var limit := _radius_at(profile, p.y)
				if p.x * p.x + p.z * p.z <= limit * limit:
					solid[_voxel_index(x_i, y_i, z_i, nx, ny, nz)] = 1
	var queue: Array[Vector3i] = []
	for x_i in range(nx):
		for y_i in range(ny):
			for z_i in range(nz):
				if x_i != 0 and y_i != 0 and z_i != 0 \
						and x_i != nx - 1 and y_i != ny - 1 and z_i != nz - 1:
					continue
				var index := _voxel_index(x_i, y_i, z_i, nx, ny, nz)
				if solid[index] == 0 and reached[index] == 0:
					reached[index] = 1
					queue.append(Vector3i(x_i, y_i, z_i))
	var head := 0
	while head < queue.size():
		var cell: Vector3i = queue[head]
		head += 1
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
				Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var next: Vector3i = cell + Vector3i(d)
			if next.x < 0 or next.x >= nx or next.y < 0 or next.y >= ny \
					or next.z < 0 or next.z >= nz:
				continue
			var index := _voxel_index(next.x, next.y, next.z, nx, ny, nz)
			if solid[index] != 0 or reached[index] != 0:
				continue
			reached[index] = 1
			queue.append(next)
	var interior_air := 0
	for i in range(count):
		if solid[i] == 0 and reached[i] == 0:
			interior_air += 1
	return interior_air


func _voxel_index(x: int, y: int, z: int, nx: int, ny: int, _nz: int) -> int:
	return (x * ny + y) * nx + z


func _radius_at(profile: PackedVector2Array, y_value: float) -> float:
	var y := clampf(y_value, 0.0, profile[-1].y)
	for i in range(profile.size() - 1):
		var a := profile[i]
		var b := profile[i + 1]
		if y <= b.y:
			var t := inverse_lerp(a.y, b.y, y)
			return lerpf(a.x, b.x, t)
	return 0.0


func _add_ring(grid: WalkGrid, inner: float, outer: float, y: float) -> void:
	for i in range(64):
		var a0 := TAU * float(i) / 64.0
		var a1 := TAU * float(i + 1) / 64.0
		var poly := PackedVector2Array([
			Vector2(cos(a0), sin(a0)) * inner,
			Vector2(cos(a1), sin(a1)) * inner,
			Vector2(cos(a1), sin(a1)) * outer,
			Vector2(cos(a0), sin(a0)) * outer,
		])
		grid.add_floor_poly(poly, y)


func _ring_coverage(grid: WalkGrid, inner: float, outer: float) -> int:
	var count := 0
	var radius := (inner + outer) * 0.5
	for i in range(RING_SAMPLES):
		var angle := TAU * float(i) / RING_SAMPLES
		var p := Vector2(cos(angle), sin(angle)) * radius
		if grid.reached(Rect2(p - Vector2.ONE * 0.18, Vector2.ONE * 0.36), 0.1):
			count += 1
	return count


func _component(builder: StupaBuilder, role: String) -> Dictionary:
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			return row
	return {}


func _mass(builder: StupaBuilder, name: String) -> Dictionary:
	for row in builder.mass_log:
		if String(row.get("name", "")) == name:
			return row
	return {}
