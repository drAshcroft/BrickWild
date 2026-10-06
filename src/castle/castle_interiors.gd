extends RefCounted
## Plan records shared by emission, assembly and QA. Local plans stay local;
## transforms place them in the castle. No models are loaded here.

static func primary(spec: CastleSpec) -> Dictionary:
	var out := {}
	if CastleGeometry.is_ridge(spec):
		return ridge(spec)
	if CastleGeometry.is_tower_house(spec):
		var tower_plan: HousePlan = CastleTowerPlan.generate(spec, true)
		if tower_plan.spec != null:
			out["tower_house"] = record("tower_house", tower_plan,
				CastleGeometry.tower_house_aabb(spec))
			# The jogs of an L or Z plan are rooms of their own; a window cannot
			# open from one into the other's masonry.
			out.merge(preload("castle_manor_plan.gd").jog_records(spec))
			var shaft: AABB = out["tower_house"].bounds
			var jog_boxes: Array[AABB] = []
			for id in out:
				if String(id).begins_with("wing_jog_"):
					jog_boxes.append(out[id].bounds)
					var against: Array[AABB] = [shaft]
					drop_buried_windows(spec, out[id], against)
			if not jog_boxes.is_empty():
				drop_buried_windows(spec, out["tower_house"], jog_boxes)
		return out
	if CastleGeometry.is_motte(spec):
		var shell_plan: HousePlan = CastleMottePlan.generate(spec, true)
		if shell_plan.spec != null:
			out["keep_shell"] = record("keep_shell", shell_plan,
				CastleGeometry.shell_keep_aabb(spec))
		# A motte replaces the keep, not the occupied bailey ranges. Returning
		# here left the hall and chapel as windowed blocks without any way in.
	if CastleGeometry.is_enclosed(spec):
		# Every walled castle's towers, gatehouses and apse are rooms, not solid
		# masses with windows painted on them.
		out.merge(preload("castle_mural_plan.gd").records(spec))
		out.merge(preload("castle_gate_plan.gd").records(spec))
		var apse := preload("castle_apse_plan.gd").record(spec)
		if not apse.is_empty():
			out["apse"] = apse
	if CastleGeometry.is_sky(spec):
		return preload("castle_manor_plan.gd").sky_records(spec)
	for kind in ["hall", "keep", "chapel"]:
		var plan: HousePlan
		var bounds: AABB
		match kind:
			"hall":
				plan = CastleInteriorPlans.hall_plan(spec)
				bounds = CastleGeometry.hall_aabb(spec)
			"keep":
				bounds = CastleGeometry.keep_aabb(spec)
				var furnish := maxf(bounds.size.x, bounds.size.z) \
					<= CastleInteriorPlans.MAX_FURNISHED_KEEP_SIDE
				plan = CastleKeepPlan.generate(spec, furnish)
				if not furnish and plan.spec != null:
					CastleKeepPlan.furnish_minimum_programme(plan, plan.spec)
			"chapel":
				plan = CastleInteriorPlans.chapel_plan(spec)
				bounds = CastleGeometry.chapel_aabb(spec)
		if plan.spec != null:
			out[kind] = record(kind, plan, bounds)
			if kind == "keep":
				drop_buried_windows(spec, out[kind])
	if not CastleGeometry.is_enclosed(spec):
		out.merge(preload("castle_manor_plan.gd").records(spec))
		# A window cannot open into a neighbouring wing, tower or porch.
		var masses: Array[Dictionary] = []
		for id in out:
			masses.append({"id": id, "box": (out[id].bounds as AABB)})
		var porch := CastleGeometry.porch_aabb(spec)
		if porch.size.x > 0.0 and spec.courtyard and out.has("range_front"):
			# The planned front range carries its own passage; see _build_porch.
			porch.size.z = CastleGeometry.PORCH_DEPTH + 0.3
		var cheeks := preload("castle_manor_plan.gd").infill_boxes(spec)
		for stack in range(spec.chimneys if spec.chimneys > 0 else 0):
			cheeks.append(CastleGeometry.chimney_aabb(spec, stack))
		for id in out:
			var others: Array[AABB] = []
			for mass in masses:
				if mass.id != id:
					others.append(mass.box)
			if porch.size.x > 0.0:
				others.append(porch)
			others.append_array(cheeks)
			drop_buried_windows(spec, out[id], others)
			restore_daylight(out[id], others)
	return out


## A keep may stand with its back built into the curtain. A planned window on
## that face opens onto masonry, not air: drop every window whose outward reveal
## (and the daylight beyond it) would pass through a curtain wall or its coping.
static func drop_buried_windows(spec: CastleSpec, row: Dictionary,
		obstructions: Array[AABB] = []) -> int:
	var plan: HousePlan = row.plan
	var xf: Transform3D = row.transform
	var walls: Array[AABB] = []
	walls.append_array(obstructions)
	if CastleGeometry.is_enclosed(spec):
		for ring in CastleGeometry.rings(spec):
			var cap := CastleGeometry.PARAPET_RISE + spec.merlon_h + 0.1
			for segment in CastleGeometry.wall_segments(spec, ring):
				var box := CastleGeometry.segment_aabb(spec, ring, segment)
				box.size.y += cap
				walls.append(box.grow(0.05))
	if walls.is_empty():
		return 0
	var kept: Array[Dictionary] = []
	for window in plan.windows:
		if not _window_buried(row, window, walls):
			kept.append(window)
	var dropped := plan.windows.size() - kept.size()
	if dropped > 0:
		plan.windows = kept
	return dropped


## Whether a window's outward reveal (0.7 m of it) meets any of `walls`.
static func _window_buried(row: Dictionary, window: Dictionary, walls: Array[AABB]) -> bool:
	var plan: HousePlan = row.plan
	var xf: Transform3D = row.transform
	var normal := Vector2(window.normal).normalized()
	var tangent := Vector2(-normal.y, normal.x)
	var storey := HousePlan.record_storey(window)
	var y := float(storey) * plan.spec.height + (float(window.sill) + float(window.head)) * 0.5
	var centre := xf * Vector3(Vector2(window.pos).x, y, Vector2(window.pos).y)
	var out_w := xf.basis * Vector3(normal.x, 0.0, normal.y)
	var side_w := xf.basis * Vector3(tangent.x, 0.0, tangent.y)
	centre += out_w * 0.7
	var half := Vector3(absf(side_w.x) * float(window.width) * 0.5 + absf(out_w.x) * 0.7,
		(float(window.head) - float(window.sill)) * 0.5,
		absf(side_w.z) * float(window.width) * 0.5 + absf(out_w.z) * 0.7)
	var reveal := AABB(centre - half, half * 2.0)
	for wall in walls:
		if wall.intersects(reveal):
			return true
	return false


## A habitable room that lost every window to a neighbour gets one on its
## longest clear wall: daylight is part of what makes it a room.
static func restore_daylight(row: Dictionary, obstructions: Array[AABB]) -> int:
	var plan: HousePlan = row.plan
	var added := 0
	for index in range(plan.rooms.size()):
		if plan.rooms[index].kind not in HouseGeometry.HABITABLE:
			continue
		var lit := false
		for window in plan.windows:
			if int(window.get("room", -1)) == index:
				lit = true
				break
		if lit:
			continue
		var storey := plan.storey_of_room(index)
		var walls := HouseGeometry.room_walls(plan, index)
		walls.sort_custom(func(a, b): return Vector2(a.from).distance_to(a.to) > Vector2(b.from).distance_to(b.to))
		for wall in walls:
			var length := Vector2(wall.from).distance_to(wall.to)
			if length < 1.8:
				continue
			var normal := -Vector2(wall.normal)
			var window := {"room": index, "storey": storey,
				"pos": (Vector2(wall.from) + Vector2(wall.to)) * 0.5, "normal": normal,
				"width": minf(1.4, length - 1.0), "sill": 1.1,
				"head": minf(2.9, plan.spec.height - 0.2)}
			var clear := true
			var tangent := Vector2(-normal.y, normal.x)
			for door in plan.doors:
				if HousePlan.record_storey(door) != storey or Vector2(door.normal).dot(normal) < 0.99:
					continue
				var along := absf((Vector2(window.pos) - Vector2(door.pos)).dot(tangent))
				var depth := absf((Vector2(window.pos) - Vector2(door.pos)).dot(normal))
				if along < (float(window.width) + float(door.width)) * 0.5 + 0.4 and depth < 0.3:
					clear = false
			if clear and not _window_buried(row, window, obstructions):
				plan.windows.append(window)
				added += 1
				break
	return added


## Every range and tower of a ridge castle, keyed by the mass name the builder
## logs.
##
## The record carries the SEGMENT'S yaw, so the plan built in the range's own
## frame lands on the masonry the builder emits for it. Each range is planned
## between its two tower junctions (see CastleRidgePlan): the rooms stop where
## the towers' rooms begin and masonry cheeks fill the old overlap.
static func ridge(spec: CastleSpec) -> Dictionary:
	var out := {}
	var layout: Dictionary = preload("castle_ridge_plan.gd").layout(spec)
	var segs: Array = layout.ranges
	var planned: Array[bool] = []
	for i in range(segs.size()):
		var seg: Dictionary = segs[i]
		var plan: HousePlan = HousePlan.new()
		if bool(seg.usable):
			plan = CastleInteriorPlans.ridge_range_plan(spec, seg, [], {
				"buried_lo": 0.0, "buried_hi": 0.0})
		planned.append(plan.spec != null)
		if plan.spec == null:
			continue
		out[String(seg["name"])] = record(String(seg["name"]), plan,
			CastleGeometry.ridge_range_aabb(seg), float(seg["yaw"]))
	# A tower is only carved out once both ranges that meet it are planned;
	# otherwise the range is still a solid block running through its rooms.
	for tower in layout.towers:
		if not bool(tower.has_tower):
			continue
		var index: int = tower.index
		if (index > 0 and not planned[index - 1]) or (index < segs.size() and not planned[index]):
			continue
		var centre: Vector3 = tower.centre
		var plan: HousePlan = preload("castle_manor_plan.gd").tower_plan(spec, String(tower.id),
			centre, {"height": tower.height, "half": tower.half, "desired": tower.away,
			"window_dot": 0.77, "facet_facing": true})
		if plan.spec == null:
			continue
		out[String(tower.id)] = record(String(tower.id), plan, tower.bounds)
	return out


static func record(id: String, plan: HousePlan, bounds: AABB, yaw := 0.0) -> Dictionary:
	var centre := bounds.get_center()
	return {"id": id, "plan": plan, "bounds": bounds,
		"transform": Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, bounds.position.y, centre.z))}

static func yard(spec: CastleSpec, entry: Dictionary) -> Dictionary:
	var rect: Rect2 = entry.rect
	# Quarter-turn placement exchanges the local width and depth.
	var request := BuildingRequest.shop(spec.seed ^ int(String(entry.business).hash()),
		entry.business, &"longhall", rect.size.y, rect.size.x, CastleBuilder.YARD_WALL_H)
	request.material = &"stone"
	var building := BrickWild.generate(request)
	if not building.is_ok():
		return {"errors": building.errors, "request": request}
	var hs := building.spec as ShopSpec
	hs.wall_color = spec.stone_color
	hs.trim_color = spec.trim_color
	hs.floor_color = spec.stone_color.darkened(0.35)
	hs.plinth_height = 0.0
	hs.porch = false
	hs.chimney = false # The castle owns external flues and roof joins.
	hs.exterior_props = false
	var bounds := AABB(Vector3(rect.position.x, 0, rect.position.y), Vector3(rect.size.x, CastleBuilder.YARD_WALL_H, rect.size.y))
	var out := record("yard_" + String(entry.business), building.plan, bounds, entry.yaw)
	out.request = request
	return out

## The castle's old mass is replaced, not overlaid. Its roof remains owned by
## CastleBuilder so touching ranges still share the joined roof envelope.
## The same mesh with every vertex's UV projected from its castle-frame
## position on its face's own basis, exactly as MeshKit does for metric kits.
static func _metric_uvs(mesh: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
			if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if normals.size() == verts.size():
			var uv := PackedVector2Array()
			uv.resize(verts.size())
			for i in verts.size():
				var axes: Array = MeshKit._surface_uv_axes((xf.basis * normals[i]).normalized())
				uv[i] = MeshKit._project_uv(xf * verts[i], axes)
			arrays[Mesh.ARRAY_TEX_UV] = uv
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


static func emit(owner: CastleBuilder, row: Dictionary) -> void:
	var plan: HousePlan = row.plan
	var builder := HouseBuilder.new()
	builder.build(plan, false)
	var bounds: AABB = row.bounds
	# Tall ranges retain continuous perimeter masonry above occupied rooms.
	builder.extend_upper_walls(bounds.size.y)
	var mesh := builder.commit()
	# The castle's masonry is textured in metre coordinates; a house shell is
	# not, and its unit-square box UVs stretched one tile of coursing across a
	# whole gable, sheared on the second triangle of every face (walk-QA,
	# Thorncliffe pin 11, "weird lines"). Re-project in the castle frame.
	if owner._kit.metric_coordinates:
		mesh = _metric_uvs(mesh, row.transform)
	# With the house roof disabled, its roof-colour slot contains glazing.
	# Castle openings have their own material and are excluded from masonry
	# voxels. SurfaceTool omits empty slots on commit, so a windowless plan's
	# floor cannot be identified by its committed numeric index alone.
	var mapping: Array[int] = [CastleBuilder.SURF_STONE, CastleBuilder.SURF_TRIM,
		CastleBuilder.SURF_OPEN, CastleBuilder.SURF_STONE]
	owner.append_mapped_mesh(builder, mesh, mapping, row.transform)
	# Forward openings the child actually emitted, rather than recreating
	# nominal windows from the spec. Castle QA can then check their actual
	# position and facade direction alongside the legacy castle openings.
	var transform: Transform3D = row.transform
	for part in builder.part_log:
		var opening_kind := String(part.get("opening_kind", ""))
		if not opening_kind in ["window", "door"]:
			continue
		var imported: Dictionary = part.duplicate(true)
		var facing := (transform.basis * Vector3(part.facing)).normalized()
		imported.kind = opening_kind
		imported.pos = transform * Vector3(part.pos)
		imported.facing = facing
		imported.rot_y = atan2(facing.x, facing.z)
		imported.tag = String(row.id)
		imported.planned_opening = true
		owner.part_log.append(imported)
	row.builder = builder
	row.mesh = mesh
	owner.interiors.append(row)
