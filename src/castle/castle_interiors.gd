extends RefCounted
## Plan records shared by emission, assembly and QA. Local plans stay local;
## transforms place them in the castle. No models are loaded here.

static func primary(spec: CastleSpec) -> Dictionary:
	var out := {}
	if CastleGeometry.is_ridge(spec) or CastleGeometry.is_tower_house(spec):
		return out # Their own multi-range/storey contracts are handled separately.
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
	owner._kit.append_mesh(mesh, row.transform, [0, 1, 2, 0])
	row.builder = builder
	row.mesh = mesh
	owner.interiors.append(row)

