extends RefCounted
## Plan records shared by emission, assembly and QA. Local plans stay local;
## transforms place them in the castle. No models are loaded here.

static func primary(spec: CastleSpec) -> Dictionary:
	var out := {}
	if CastleGeometry.is_ridge(spec):
		return ridge(spec)
	if CastleGeometry.is_tower_house(spec) or CastleGeometry.is_sky(spec):
		return out # Their own multi-storey contracts are handled separately.
	for kind in ["hall", "keep", "chapel"]:
		var plan: HousePlan
		var bounds: AABB
		match kind:
			"hall":
				plan = CastleGenerator.hall_plan(spec)
				bounds = CastleGeometry.hall_aabb(spec)
			"keep":
				plan = CastleGenerator.keep_plan(spec)
				bounds = CastleGeometry.keep_aabb(spec)
			"chapel":
				plan = CastleGenerator.chapel_plan(spec)
				bounds = CastleGeometry.chapel_aabb(spec)
		if plan.spec != null:
			out[kind] = record(kind, plan, bounds)
	return out

## Every range of a ridge castle, keyed by the mass name the builder logs.
##
## The record carries the SEGMENT\'S yaw, so the plan built in the range\'s own
## frame lands on the masonry the builder emits for it. ridge_range_aabb is
## centred on the segment midpoint, which is where record() puts the transform.
static func ridge(spec: CastleSpec) -> Dictionary:
	var out := {}
	var segs: Array[Dictionary] = CastleGeometry.ridge_ranges(spec)
	for i in range(segs.size()):
		var seg: Dictionary = segs[i]
		# A segment touches its predecessor at its start and its successor at
		# its end; the chain\'s two outermost ends open on nothing.
		var links: Array[int] = []
		if i > 0:
			links.append(-1)
		if i < segs.size() - 1:
			links.append(1)
		var plan: HousePlan = CastleGenerator.ridge_range_plan(spec, seg, links)
		if plan.spec == null:
			continue
		out[String(seg["name"])] = record(String(seg["name"]), plan,
			CastleGeometry.ridge_range_aabb(seg), float(seg["yaw"]))
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
	var building := BigGlade.generate(request)
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
static func emit(owner: CastleBuilder, row: Dictionary) -> void:
	var plan: HousePlan = row.plan
	var builder := HouseBuilder.new()
	builder.build(plan, false)
	var occupied_top := plan.spec.height * plan.spec.storeys
	var bounds: AABB = row.bounds
	# Existing plans cap ceiling height in very tall ranges. The remaining
	# volume is an empty roof void with continuous perimeter masonry.
	if bounds.size.y > occupied_top + 0.001:
		for run in HouseGeometry.shell_runs(plan, plan.spec.storeys - 1):
			builder._wall_run(run.from, run.to, HouseGeometry.wall_thickness(plan.spec),
				bounds.size.y - occupied_top, [], 0, occupied_top, false)
	var mesh := builder.commit()
	# With the house roof disabled, its roof-colour slot contains glazing.
	# Castle openings have their own material and are excluded from masonry
	# voxels. SurfaceTool omits empty slots on commit, so a windowless plan's
	# floor cannot be identified by its committed numeric index alone.
	var mapping := [CastleBuilder.SURF_STONE, CastleBuilder.SURF_TRIM,
		CastleBuilder.SURF_OPEN, CastleBuilder.SURF_STONE]
	var committed_surface := 0
	for source in mapping.size():
		var arrays := builder._kit.surface(source).commit_to_arrays()
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty():
			continue
		owner._kit.surface(mapping[source]).append_from(mesh, committed_surface, row.transform)
		committed_surface += 1
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
