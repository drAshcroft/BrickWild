extends SceneTree
## Which emitted triangle blocks a castle range's exterior door clearance?
##
## Reproduces CastleOccupancyCheck's own ray test for one range id and prints
## every triangle that crosses it, with the part the builder logged for it.
##
##   godot --headless --path . --script res://tools/castle_door_block_probe.gd -- crusader castle 0 tower_0_corner_0
##   arguments: style tier index range-id
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var style := StringName(args[0] if args.size() > 0 else "crusader")
	var tier := StringName(args[1] if args.size() > 1 else "castle")
	var index := int(args[2] if args.size() > 2 else 0)
	var want := String(args[3] if args.size() > 3 else "tower_0_corner_0")
	var spec := CastleSweep.spec_at(style, tier, index)
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var geometry := CastleOccupancyCheck.prepare_mesh(mesh)
	var row := {}
	for r in builder.interiors:
		if String(r.id) == want:
			row = r
			break
	if row.is_empty():
		print("no range %s; have %s" % [want, str(builder.interiors.map(func(r): return String(r.id)))])
		quit()
		return
	var plan: HousePlan = row.plan
	print("range %s %s plan doors=%d windows=%d rooms=%d ground_entry=%s" % [want,
		String(plan.spec.style), plan.doors.size(), plan.windows.size(), plan.rooms.size(),
		str(row.get("ground_entry", false))])
	print("  spec w=%.2f l=%.2f h=%.2f storeys=%d entry=%d" % [plan.spec.width,
		plan.spec.length, plan.spec.height, plan.spec.storeys, plan.spec.entry_storey])
	print("  row transform origin=%s  bounds=%s" % [str(row.transform.origin),
		str(row.bounds)])
	for ring in CastleGeometry.rings(spec):
		print("  ring %d enceinte_rect=%s" % [ring,
			str(CastleGeometry.enceinte_rect(spec, ring))])
	print("  ring0 centre=%s tower_aabb=%s" % [
		str(CastleGeometry.enceinte_rect(spec, 0).get_center()),
		str(CastleGeometry.tower_aabb(spec, 0, row.transform.origin,
			int(want.get_slice("_", -1)) if want.contains("corner") else -1))])
	var mural = preload("res://src/castle/castle_mural_plan.gd")
	var vertex := int(want.get_slice("_", -1))
	var targets: Array = mural._corner_targets(spec, 0, row.transform.origin, vertex)
	print("  corner targets=%d" % targets.size())
	for t in targets:
		print("    target=%s inward=%s edge=%d" % [str(t.target), str(t.inward), int(t.edge)])
	print("  corner gallery links=%d" % mural._corner_gallery(spec, 0,
		row.transform.origin, vertex, row.bounds).size())
	print("  walk_landing=%s walk_y=%.2f outer=%s inside=%s" % [
		str(row.get("walk_landing", Rect2())), float(row.get("walk_y", 0.0)),
		str(row.get("walk_outer", Vector2.ZERO)), str(row.get("walk_inside", Vector2.ZERO))])
	print("  walk_route=%s" % str(row.get("walk_route", [])))
	for span in row.get("walk_gallery", []):
		print("    gallery a=%s b=%s width=%.2f guarded=%s" % [str(span.a), str(span.b),
			float(span.width), str(span.get("guarded", false))])
	print("  wall thickness top=%.2f base=%.2f wall_height=%.2f walk_y=%.2f" % [
		CastleGeometry.wall_thickness(spec, 0),
		CastleGeometry.wall_base_thickness(spec, 0),
		CastleGeometry.wall_height(spec, 0),
		CastleGeometry.wall_height(spec, 0) + CastleGeometry.PARAPET_RISE])
	var raised_door: Dictionary = mural._door(plan, spec, 0, row.transform.origin,
		plan.spec.entry_storey, vertex)
	print("  raised door (entry %d): %s" % [plan.spec.entry_storey,
		"found" if not raised_door.is_empty() else "EMPTY"])
	var room0: Dictionary = plan.rooms[0]
	print("  room0 rect=%s outline_n=%d" % [str(room0.get("rect", Rect2())),
		(room0.get("outline", PackedVector2Array()) as PackedVector2Array).size()])
	for wall in HouseGeometry.room_walls(plan, 0):
		print("    wall %s -> %s normal=%s len=%.2f" % [str(wall.from), str(wall.to),
			str(wall.normal), Vector2(wall.from).distance_to(Vector2(wall.to))])
	print("  emitted openings:")
	for part in builder.part_log:
		if String(part.get("tag", "")) != want:
			continue
		print("    %s %s pos=%s size=%s facing=%s" % [str(part.get("kind", "")),
			str(part.get("opening_kind", "")), str(part.get("pos", Vector3.ZERO)),
			str(part.get("size", Vector3.ZERO)), str(part.get("facing", Vector3.ZERO))])
	for door in plan.doors:
		if not bool(door.get("exterior", false)):
			continue
		var room := int(door.get("a", 0))
		var opening := CastleOccupancyCheck._pose(plan, row.transform, door, room, true)
		print("  door storey=%d pos=%s facing=%s width=%.2f height=%.2f floor_y=%.2f" % [
			int(door.get("storey", 0)), str(opening.pos), str(opening.facing),
			float(opening.width), float(opening.height), float(opening.floor_y)])
		var normal: Vector3 = opening.facing
		var reach := float(opening.thickness) + 0.20
		var half_width := maxf(0.0, float(opening.width) * 0.5 - 0.12)
		var centre: Vector3 = opening.pos
		var aperture_bottom := centre.y - float(opening.height) * 0.5
		var aperture_top := centre.y + float(opening.height) * 0.5
		print("  aperture y %.2f..%.2f (floor %.2f)" % [aperture_bottom, aperture_top,
			float(opening.floor_y)])
		_print_support(builder, geometry, centre, normal, reach, half_width,
			aperture_bottom, float(opening.floor_y))
		var low := maxf(aperture_bottom, float(opening.floor_y)) + 0.15
		var high := aperture_top - 0.15
		var bounds := AABB(centre, Vector3.ZERO)
		for across in [-half_width, half_width]:
			for height in [low, high]:
				for depth in [-reach, reach]:
					var point: Vector3 = centre + Vector3(normal.z, 0, -normal.x) * across + normal * depth
					point.y = height
					bounds = bounds.expand(point)
		var nearby := _nearby(geometry, bounds.grow(0.001))
		print("  nearby triangles %d" % nearby.size())
		for across in [-half_width, 0.0, half_width]:
			for height in [low, (low + high) * 0.5, high]:
				var point: Vector3 = centre + Vector3(normal.z, 0, -normal.x) * float(across)
				point.y = height
				for triangle in nearby:
					if Geometry3D.segment_intersects_triangle(point - normal * reach,
							point + normal * reach, triangle.a, triangle.b, triangle.c) != null:
						var tri_bounds: AABB = triangle.bounds
						print("  BLOCK at %s surface=%d tri bounds pos=%s size=%s" % [
							str(point), int(triangle.surface), str(tri_bounds.position),
							str(tri_bounds.size)])
						print("     verts a=%s b=%s c=%s" % [str(triangle.a),
							str(triangle.b), str(triangle.c)])
						_nearest_part(builder, tri_bounds)
						_containing_parts(builder, triangle)
						break
	quit()


static func _print_support(builder: CastleBuilder, geometry: Dictionary, centre: Vector3,
		normal: Vector3, reach: float, half_width: float, aperture_bottom: float,
		nominal_floor: float) -> void:
	var tangent := Vector3(normal.z, 0.0, -normal.x)
	var support_bounds := AABB(centre - Vector3.ONE * (reach + half_width),
		Vector3.ONE * (reach + half_width) * 2.0)
	support_bounds.position.y = nominal_floor - 0.31
	support_bounds.size.y = 0.62
	var support := _nearby(geometry, support_bounds)
	var floor_y := nominal_floor
	var best: Dictionary = {}
	for across in [-half_width, 0.0, half_width]:
		for depth in [-reach, 0.0, reach]:
			var foot: Vector3 = centre + tangent * float(across) + normal * float(depth)
			for triangle in support:
				var upward: Vector3 = (triangle.c - triangle.a).cross(
					triangle.b - triangle.a).normalized()
				if upward.y < 0.9:
					continue
				var hit: Variant = Geometry3D.segment_intersects_triangle(
					Vector3(foot.x, nominal_floor + 0.3, foot.z),
					Vector3(foot.x, nominal_floor - 0.3, foot.z),
					triangle.a, triangle.b, triangle.c)
				if hit != null and Vector3(hit).y > floor_y:
					floor_y = Vector3(hit).y
					best = triangle
	print("  support floor_y=%.3f (nominal %.3f) standing=%.3f" % [floor_y, nominal_floor,
		(centre.y + (centre.y - aperture_bottom)) - maxf(aperture_bottom, floor_y)])
	if not best.is_empty():
		print("    highest support tri bounds pos=%s size=%s surface=%d" % [
			str(best.bounds.position), str(best.bounds.size), int(best.surface)])
		for part in builder.part_log:
			var p: Vector3 = part.get("pos", Vector3.ZERO)
			var s: Vector3 = part.get("size", Vector3.ZERO)
			if not AABB(p - s * 0.5, s).grow(0.05).has_point(best.bounds.get_center()):
				continue
			print("    support part: %s kind=%s pos=%s size=%s rot=%s" % [
				str(part.get("id", "")), str(part.get("kind", "")), str(p), str(s),
				str(part.get("rot_y", 0.0))])


static func _nearby(geometry: Dictionary, bounds: AABB) -> Array:
	var out: Array = []
	var seen := {}
	var lo := Vector2i(floori(bounds.position.x / 8.0), floori(bounds.position.z / 8.0))
	var hi := Vector2i(floori(bounds.end.x / 8.0), floori(bounds.end.z / 8.0))
	for index in geometry.wide:
		seen[index] = true
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			for index in geometry.cells.get(Vector2i(x, z), []):
				seen[index] = true
	for index in seen:
		var triangle: Dictionary = geometry.triangles[index]
		if bounds.intersects(triangle.bounds):
			out.append(triangle)
	return out


static func _nearest_part(builder: CastleBuilder, tri: AABB) -> void:
	var best := INF
	var best_part := ""
	for part in builder.part_log:
		var b: AABB = part.get("bounds", AABB())
		if b.size == Vector3.ZERO:
			var p: Vector3 = part.get("pos", Vector3.ZERO)
			var s: Vector3 = part.get("size", Vector3.ZERO)
			b = AABB(p - s * 0.5, s)
		var d := b.get_center().distance_to(tri.get_center())
		if d < best:
			best = d
			best_part = "%s kind=%s pos=%s size=%s" % [str(part.get("id", "")),
				str(part.get("kind", "")), str(part.get("pos", Vector3.ZERO)),
				str(part.get("size", Vector3.ZERO))]
	print("     nearest part d=%.2f %s" % [best, best_part])


static func _containing_parts(builder: CastleBuilder, triangle: Dictionary) -> void:
	var centre: Vector3 = (triangle.a + triangle.b + triangle.c) / 3.0
	var hits := 0
	for part in builder.part_log:
		var p: Vector3 = part.get("pos", Vector3.ZERO)
		var s: Vector3 = part.get("size", Vector3.ZERO)
		var b := AABB(p - s * 0.5, s).grow(0.05)
		if not b.has_point(centre):
			continue
		hits += 1
		if hits <= 6:
			print("     part in box: %s kind=%s pos=%s size=%s rot=%s" % [
				str(part.get("id", "")), str(part.get("kind", "")), str(p), str(s),
				str(part.get("rot_y", 0.0))])
	if hits == 0:
		print("     no logged part box contains the tri centre %s" % str(centre))
	else:
		print("     %d logged part boxes contain the tri centre" % hits)
