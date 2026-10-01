class_name HouseQA
extends RefCounted
## The whole house harness in one call: the plan, the furnishing, the walking,
## and the shell the mesh actually came out as.
##
## The four are deliberately separate modules -- a plan can be sound and its
## furnishing nonsense, and the failure should say which -- but nothing outside
## qa/ should have to know that, so this runs them all and merges the reports.
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

## Shell masses are all joined by design: a partition dies into the exterior
## wall, the floor slab carries everything. So the shell only gets the two
## structural rules that can still fail -- nothing floating, nothing hovering.
# A pitched roof is carried by the wall plates even in a one-storey house.
const SHELL_CARRIED: Array = ["roof"]


## `overrides` lets a family replace a rule of the plan or furnishing check
## by name (RuleSet, INT-020); the report says which under "replaced".
func check(plan: HousePlan, builder: HouseBuilder, overrides: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}
	# which rule belongs to which section of the report; the parts that name
	# their groups (the furnishing check does) hand them up unchanged
	var groups := {}
	var replaced := {}
	failures.append_array(HouseExterior.check(plan))
	for bad in RuleSet.unknown(overrides, [HousePlanCheck.RULES, HouseFurnishCheck.RULES]):
		failures.append("rules: no house rule is called %s" % bad)

	for part in [
		HousePlanCheck.new().check(plan, overrides),
		HouseFurnishCheck.new().check(plan, overrides),
		HouseNavCheck.new().check(plan),
	]:
		for f in part["failures"]:
			failures.append(str(f))
		for w in part["warnings"]:
			warnings.append(str(w))
		for k in part["stats"]:
			stats[k] = part["stats"][k]
		for g in part.get("groups", {}):
			groups[g] = part["groups"][g]
		for r in part.get("replaced", {}):
			replaced[r] = part["replaced"][r]

	if builder != null:
		failures.append_array(check_interior_details(plan, builder))
		failures.append_array(check_exterior_geometry(plan, builder))
		for f2 in _check_shell(plan, builder):
			failures.append(f2)
		for f3 in _check_vertical_shell(plan, builder):
			failures.append(f3)
		for f4 in _check_opening_elevations(plan, builder):
			failures.append(f4)
		stats["masses"] = builder.mass_log.size()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "groups": groups, "replaced": replaced}


## Structural interior additions are real occupied space. Legacy hand-authored
## plans may omit their records; once authored, their mesh and contacts must agree.
static func check_interior_details(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var errors: Array[String] = []
	var breast := HouseGeometry.hearth_breast(plan)
	if builder.emitted_mesh == null:
		if not breast.is_empty() or not plan.rugs.is_empty():
			errors.append("interior_details: authored additions have no emitted mesh")
		return errors
	if not breast.is_empty():
		var room := int(breast["room"])
		var normal: Vector2 = breast["normal"]
		var centre: Vector2 = breast["centre"]
		var depth := float(breast["depth"])
		var y0 := int(breast["storey"]) * plan.spec.height
		var wall: Dictionary = HouseGeometry.room_walls(plan, room)[int(breast["wall"])]
		if depth < 0.4 or depth > 0.6 or absf((centre - Vector2(wall["from"])).dot(normal) - depth * 0.5) > 0.02:
			errors.append("hearth_breast: invalid depth or wall contact")
		var found := false
		for mass in builder.mass_log:
			if String(mass["name"]) == "chimney_breast":
				found = absf(AABB(mass["aabb"]).size.y - plan.spec.height) < 0.001
		if not found:
			errors.append("hearth_breast: missing full-storey structural mass")
		var triangles := _mesh_triangles(builder.emitted_mesh, HouseBuilder.SURF_WALL)
		for rise in [0.3, plan.spec.height * 0.5, plan.spec.height - 0.05]:
			var face := Vector3(centre.x + normal.x * depth * 0.5, y0 + rise, centre.y + normal.y * depth * 0.5)
			var delta := Vector3(normal.x, 0, normal.y) * 0.02
			var hit := false
			for triangle in triangles:
				if Geometry3D.segment_intersects_triangle(face - delta, face + delta, triangle[0], triangle[1], triangle[2]) != null:
					hit = true
					break
			if not hit:
				errors.append("hearth_breast: actual masonry missing at " + str(face))
		for item in plan.furniture:
			if int(item["room"]) != room:
				continue
			if Poly.intersection_area(Poly.from_rect(item["rect"]), breast["outline"]) > 0.002:
				errors.append("hearth_breast: furniture intersects masonry: " + String(item["key"]))
			if PropCatalog.category(item["key"]) == "hearth":
				var width := PropCatalog.footprint(item["key"]).x * float(item.get("scale", 1.0))
				if float(breast["width"]) < width + 0.399 or HouseFurnishArrangementCheck.back_gap(plan, item) > 0.02:
					errors.append("hearth_breast: measured hearth does not fit or touch its surround")
	if not plan.rugs.is_empty():
		if builder.emitted_mesh.get_surface_count() <= HouseBuilder.SURF_FLOOR:
			errors.append("rug: floor material surface missing")
			return errors
		var arrays := builder.emitted_mesh.surface_get_arrays(HouseBuilder.SURF_FLOOR)
		if arrays[Mesh.ARRAY_COLOR] == null:
			errors.append("rug: textile material region attributes missing")
			return errors
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var total := 0
		for i in vertices.size():
			if colours[i].r < 0.5:
				total += 1
		if total != plan.rugs.size() * 6:
			errors.append("rug: actual textile region does not match planned quad count")
		for rug in plan.rugs:
			var rect: Rect2 = rug["rect"]
			var y := int(rug["storey"]) * plan.spec.height + HouseGeometry.FLOOR_T + 0.002
			if plan.on_dais(int(rug["room"]), rect.get_center()):
				y += plan.dais_rise()
			var count := 0
			for i in vertices.size():
				if colours[i].r < 0.5 and absf(vertices[i].y - y) < 0.0001 and rect.grow(0.001).has_point(Vector2(vertices[i].x, vertices[i].z)):
					count += 1
			if count < 6:
				errors.append("rug: no actual quad 2 mm above floor for " + String(rug["id"]))
	return errors


## Geometry-backed exterior rules, also callable by the fast mesh-only lane.
## Component evidence ties the measured polygons to actual mesh triangles;
## the envelope rule then compares those polygons with the requested hosts.
static func check_exterior_geometry(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var failures: Array[String] = []
	var mesh := builder.emitted_mesh
	if mesh == null:
		return failures
	var who := "exterior seed=%d style=%s " % [plan.spec.seed, plan.spec.style]
	for f in ComponentCheck.check(builder, mesh)["failures"]:
		failures.append(who + "components: " + str(f))
	# Shaped and courtyard hosts have their own outline/sky/support rules;
	# the rectangular envelope below must never cover their intentional holes.
	if plan.has_court() or HouseGeometry.is_shaped(plan) or plan.spec.has_method("room_program"):
		return failures
	if builder.roof_enabled:
		for f in RoofOpeningCheck.check(plan, builder, mesh)["failures"]:
			failures.append(who + "roof_opening: " + str(f))
		for f in _roof_envelope(plan, builder):
			failures.append(who + f)
	var bounds := HouseGeometry.exterior_bounds(plan)
	if plan.spec.cellars > 0:
		bounds.position.y -= plan.spec.cellars * plan.spec.height
		bounds.size.y += plan.spec.cellars * plan.spec.height
	if not bounds.grow(0.025).encloses(mesh.get_aabb()):
		failures.append(who + "bounds: actual shell leaves planned exterior (tolerance=0.025m)")
	if plan.spec.jetty:
		for f in check_jetty_geometry(plan, mesh):
			failures.append(who + f)
	var trim := _mesh_triangles(mesh, HouseBuilder.SURF_TRIM)
	for di in plan.doors.size():
		var door: Dictionary = plan.doors[di]
		if not door["exterior"] or HousePlan.record_storey(door) != 0:
			continue
		var pos: Vector2 = door["pos"]
		var n: Vector2 = door["normal"]
		var blocked := false
		for h in [0.35, 0.62, 1.35]:
			var start := Vector3(pos.x + n.x * 0.8, h, pos.y + n.y * 0.8)
			var end := Vector3(pos.x - n.x * 0.05, h, pos.y - n.y * 0.05)
			for tri in trim:
				if Geometry3D.segment_intersects_triangle(start, end, tri[0], tri[1], tri[2]) != null:
					blocked = true
		if blocked:
			failures.append(who + "door_trim: door=%d storey=0 trim blocks the approach" % di)
	return failures


static func check_jetty_geometry(plan: HousePlan, mesh: ArrayMesh) -> Array[String]:
	var errors: Array[String] = []
	var s := plan.spec
	var vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_FLOOR)[Mesh.ARRAY_VERTEX]
	var walls := _mesh_triangles(mesh, HouseBuilder.SURF_WALL)
	for level in range(1, s.storeys):
		var found := INF
		for v in vertices:
			if absf(v.y - (float(level) * s.height + HouseGeometry.FLOOR_T)) < 0.001:
				found = minf(found, v.z)
		var expected := HouseGeometry.storey_rect(plan, level).position.y
		if absf(found - expected) > 0.01:
			errors.append("jetty_floor: storey=%d front=%.3f expected=%.3f tolerance=0.010m" % [level, found, expected])
		for x in [-s.width * 0.3, 0.0, s.width * 0.3]:
			var at := Vector3(x, float(level) * s.height + 0.45, expected)
			var touched := false
			for tri in walls:
				if Geometry3D.segment_intersects_triangle(at - Vector3(0, 0, 0.06),
						at + Vector3(0, 0, 0.06), tri[0], tri[1], tri[2]) != null:
					touched = true
					break
			if not touched:
				errors.append("jetty_wall: storey=%d x=%.2f expected_z=%.3f tolerance=0.060m" % [level, x, expected])
	return errors


static func _roof_envelope(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var failures: Array[String] = []
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var inverse: Transform3D = Transform3D(layout["transform"]).affine_inverse()
	var observed: Dictionary = {}
	var pieces: Array[PackedVector2Array] = []
	for row in builder.components("roof_face_"):
		var face_id := int(String(row["role"]).trim_prefix("roof_face_"))
		if face_id < 0 or face_id >= faces.size():
			failures.append("roof_host: component=%s has invalid face=%d" % [row["id"], face_id])
			continue
		var poly := PackedVector2Array()
		var host := RoofShape.footprint(faces[face_id])
		for world in row["points"]:
			var p: Vector3 = inverse * world
			var at := Vector2(p.x, p.z)
			poly.append(at)
			var error := absf(p.y - RoofShape.plane_height(faces[face_id], at))
			if not Poly.contains_point(host, at, 0.015) or error > 0.015:
				failures.append("roof_host: component=%s host=%d plane_error=%.3f tolerance=0.015m" % [row["id"], face_id, error])
				break
		if not observed.has(face_id):
			observed[face_id] = []
		observed[face_id].append(poly)
		for prior in pieces:
			if Poly.intersection_area(prior, poly) > 0.002:
				failures.append("roof_overlap: component=%s overlaps another main face (tolerance=0.002m2)" % row["id"])
		pieces.append(poly)
	var openings := HouseGeometry.roof_openings(plan)
	for fi in faces.size():
		var host := RoofShape.footprint(faces[fi])
		var box := Poly.bounding_rect(host)
		for ix in range(1, 6):
			for iz in range(1, 6):
				var at := box.position + box.size * Vector2(float(ix) / 6.0, float(iz) / 6.0)
				if not Poly.contains_point(host, at):
					continue
				var intentional := false
				for opening in openings:
					if Poly.contains_point(opening["polygon"], at, 0.02):
						intentional = true
				if intentional:
					continue
				var covered := false
				for poly in observed.get(fi, []):
					if Poly.contains_point(poly, at, 0.015):
						covered = true
				if not covered:
					failures.append("roof_envelope: host=%d storey=%d missing sample=%s" % [fi, plan.spec.storeys - 1, at])
	# Top profile follows the underside at the OUTER wall, while its slab's
	# centre is shifted half a wall inward. Undo that inset for the query.
	for row in builder.components("roof_wall"):
		var local := PackedVector3Array()
		for world in row["points"]:
			local.append(inverse * world)
		var flat_x := true
		for p in local:
			flat_x = flat_x and absf(p.x - local[0].x) < 0.005
		for p in local:
			if p.y <= 0.001:
				continue
			var at := Vector2(p.x, p.z)
			if flat_x:
				at.x = signf(p.x) * float(layout["span"]) * 0.5
			else:
				at.y = signf(p.z) * float(layout["along"]) * 0.5
			var expected := RoofShape.height_at(faces, at) - RoofShape.DEPTH * 0.5
			if absf(p.y - expected) > 0.02:
				failures.append("roof_wall: component=%s join_error=%.3f tolerance=0.020m" % [row["id"], absf(p.y - expected)])
	return failures


static func _mesh_triangles(mesh: ArrayMesh, surface: int) -> Array:
	var out: Array = []
	if surface >= mesh.get_surface_count():
		return out
	var arrays := mesh.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(0, points.size() - 2, 3):
			out.append([points[i], points[i + 1], points[i + 2]])
	else:
		for i in range(0, indices.size() - 2, 3):
			out.append([points[indices[i]], points[indices[i + 1]], points[indices[i + 2]]])
	return out


## The shell: every mass stands on the ground and touches the rest of the
## house. The floor slab is the anchor, because everything is built on it.
static func _check_shell(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var masses: Array[Dictionary] = builder.mass_log
	if masses.is_empty():
		out.append("shell: the builder logged no structural masses")
		return out
	# the ground floor slab, or its first piece when a stair down to a cellar
	# has cut a hole in it (INT-016)
	var anchor := ""
	for m0 in masses:
		var nm0: String = m0["name"]
		if nm0 == "floor" or nm0 == "floor_0":
			anchor = nm0
			break
		if anchor == "" and nm0.begins_with("floor_0"):
			anchor = nm0
	if anchor == "":
		anchor = "floor"
	var gaps: Dictionary = MassRules.gaps(masses, anchor)
	for f in gaps["failures"]:
		out.append(str(f))
	var carried: Array = SHELL_CARRIED.duplicate()
	# Ground-floor plans retain the original strict grounding rule. Upper
	# storeys are intentionally carried by the walls/floors below; gaps() still
	# requires every one to join the structural assembly. Every mass carries
	# its own ground level (a cellar's is a storey down, INT-016), so the
	# per-storey masses are measured against that rather than exempted.
	if int(plan.spec.storeys) > 1:
		carried += ["roof", "stair_"]
		for m in masses:
			var nm: String = m["name"]
			if (nm.begins_with("floor_") or nm.begins_with("wall_") or nm.begins_with("partition_")) \
					and not m.has("ground"):
				carried.append(nm)
	for g in MassRules.grounded(masses, carried):
		out.append(str(g))
	# and the rooms the mesh was built from must be the rooms the plan claims
	var wall_masses := 0
	var colonnade_walls := {}
	for m in masses:
		var mass_name := String(m["name"])
		if mass_name.begins_with("wall_") or mass_name.begins_with("partition_"):
			wall_masses += 1
		elif mass_name.begins_with("colonnade_lintel_"):
			var pieces := mass_name.split("_")
			if pieces.size() >= 5:
				colonnade_walls["%s|%s" % [pieces[2], pieces[3]]] = true
	var wall_sides := wall_masses + colonnade_walls.size()
	if wall_sides < 4:
		out.append("shell: only %d wall masses or structural colonnade sides -- a house has four sides" % wall_sides)
	return out


## Structural vertical contract. Builders may keep the legacy `floor` name for
## level zero or use `floor_0`; upper levels must be represented explicitly.
## Roofs are required for multi-storey builds and must start at the top wall
## band, which catches a roof accidentally left at the first storey.
static func _check_vertical_shell(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var wanted: int = clampi(int(plan.spec.storeys), 1, plan.spec.max_storeys())
	var lowest := 0
	if plan.spec.has_method("lowest_storey"):
		lowest = int(plan.spec.lowest_storey())
	var floor_names := {}
	var roofs: Array[AABB] = []
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm == "floor" or nm.begins_with("floor_"):
			floor_names[nm] = true
		if nm.begins_with("roof"):
			roofs.append(m["aabb"])
	for level in range(lowest, wanted):
		var ground_slab := floor_names.has("floor") or floor_names.has("floor_0")
		for floor_name0 in floor_names:
			if String(floor_name0).begins_with("floor_0"):
				ground_slab = true
		if level == 0 and ground_slab:
			continue
		if level != 0:
			var prefix := "floor_%d" % level
			var found_level := false
			for floor_name in floor_names:
				if String(floor_name).begins_with(prefix):
					found_level = true
					break
			if found_level:
				continue
		if wanted > 1 or lowest < 0:
			out.append("shell: missing floor mass for storey %d" % level)
	if roofs.is_empty():
		out.append("shell: house has no logged roof mass")
	elif roofs.size() > 1 and plan.world_family != &"courtyard_house":
		out.append("shell: %d main roof masses logged; expected exactly one" % roofs.size())
	var top_wall: float = float(wanted) * plan.spec.height
	if not roofs.is_empty():
		var roof_top := -INF
		var roof_bottom := INF
		for roof in roofs:
			roof_top = maxf(roof_top, (roof as AABB).end.y)
			roof_bottom = minf(roof_bottom, (roof as AABB).position.y)
		var expected_bottom := top_wall
		if plan.world_family == &"courtyard_house":
			# The shallow courtyard ring meets the wall head at its inner eave;
			# only slab depth extends below that support line.
			expected_bottom = top_wall - 0.12
		if absf(roof_bottom - expected_bottom) > 0.15:
			out.append("shell: roof begins at Y %.2f, expected wall band %.2f" % [roof_bottom, expected_bottom])
	return out


## The plan check validates a window's relative sill/head. This companion check
## ties the emitted `window` records back to the actual storey Y offset, so a
## builder cannot cut every upper window at ground level.
static func _check_opening_elevations(plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	for wi in range(plan.windows.size()):
		var win: Dictionary = plan.windows[wi]
		var room: int = int(win.get("room", -1))
		if room < 0 or room >= plan.room_count():
			continue
		var level := HousePlan.record_storey(win)
		var expected: float = float(level) * plan.spec.height \
			+ (float(win["sill"]) + float(win["head"])) / 2.0
		var found := false
		for part in builder.part_log:
			if part["kind"] != "window":
				continue
			var pp: Vector3 = part["pos"]
			var wp: Vector2 = win["pos"]
			# Plan openings sit on the interior wall face while trim is logged on
			# the wall centreline, so their plan-space separation is half a wall.
			if Vector2(pp.x, pp.z).distance_to(wp) < HouseGeometry.wall_thickness(plan.spec) / 2.0 + 0.04 \
					and absf(pp.y - expected) < 0.06:
				found = true
				break
		if not found:
			out.append("opening: window %d has no emitted trim at storey %d elevation %.2f" % [wi, level, expected])
	return out
