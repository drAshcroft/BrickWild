extends SceneTree
## Which emitted triangle blocks one occupied range's curtain route?
##
## Repeats CastleRouteCheck's own ray test for one range, prints the offending
## ray and every triangle it crosses, with the part the builder logged for it.
##
##   godot --headless --path . --script res://tools/castle_walk_route_probe.gd -- castle crusader 0 tower_0_corner_2
##   godot --headless --path . --script res://tools/castle_walk_route_probe.gd -- castle motte 0 tower_0_gate_0
##   arguments: tier style index [range-id]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tier := StringName(args[0] if args.size() > 0 else "castle")
	var style := StringName(args[1] if args.size() > 1 else "crusader")
	var index := int(args[2] if args.size() > 2 else 0)
	var want := String(args[3] if args.size() > 3 else "")
	# `motte` builds the castle motte-access suite's own fixture (the README hero).
	var spec: CastleSpec = preload("res://tests/suites/castle_motte_access_suite.gd").hero_spec() \
		if tier == &"motte" else CastleSweep.spec_at(style, tier, index)
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var triangles := CastleRouteCheck.masonry_triangles(mesh)
	for row in builder.interiors:
		if not want.is_empty() and String(row.get("id", "")) != want:
			continue
		if not bool(row.get("mural_tower", false)) and not bool(row.get("gate_chamber", false)):
			continue
		if bool(row.get("ground_entry", false)):
			continue
		var id := String(row.id)
		var plan: HousePlan = row.plan
		var door: Dictionary = plan.doors[plan.entrance()]
		var origin: Vector3 = row.transform.origin
		var y := origin.y + HousePlan.record_storey(door) * plan.spec.height + HouseGeometry.FLOOR_T
		var route: Array[Vector2] = []
		route.assign(row.get("walk_route", []))
		var walk_y := minf(y, float(row.walk_y))
		var diagnostics: Array = []
		var failure := CastleRouteCheck.route_failure(
			CastleRouteCheck.near_route(triangles, route, walk_y), route, walk_y, diagnostics)
		print("range %s door y=%.3f walk_y=%.3f route_y=%.3f" % [id, y,
			float(row.walk_y), walk_y])
		print("  route=%s" % str(route))
		print("  failure=%s" % ("none" if failure.is_empty() else failure))
		for diagnostic in diagnostics:
			var ray: Array = diagnostic.ray
			var from: Vector3 = ray[0]
			var to: Vector3 = ray[1]
			print("  ray %s -> %s" % [str(from), str(to)])
			for triangle in triangles:
				if Geometry3D.segment_intersects_triangle(from, to,
						triangle[0], triangle[1], triangle[2]) != null:
					print("    tri a=%s b=%s c=%s" % [str(triangle[0]),
						str(triangle[1]), str(triangle[2])])
					_nearest_parts(builder, triangle)
	quit()


static func _nearest_parts(builder: CastleBuilder, triangle: PackedVector3Array) -> void:
	var box := AABB(triangle[0], Vector3.ZERO)
	box = box.expand(triangle[1]).expand(triangle[2])
	var centre := box.get_center()
	var rows: Array = []
	for part in builder.part_log:
		var b: AABB = part.get("bounds", AABB())
		if b.size == Vector3.ZERO:
			var p: Vector3 = part.get("pos", Vector3.ZERO)
			var s: Vector3 = part.get("size", Vector3.ZERO)
			b = AABB(p - s * 0.5, s)
		if b.grow(0.03).has_point(centre):
			rows.append("%s kind=%s pos=%s size=%s" % [str(part.get("id", "")),
				str(part.get("kind", "")), str(part.get("pos", Vector3.ZERO)),
				str(part.get("size", Vector3.ZERO))])
	for component in builder.component_log:
		if String(component.get("form", "")) != "box":
			continue
		var xf: Transform3D = component.get("xf", Transform3D())
		var size: Vector3 = component.get("size", Vector3.ZERO)
		var part_box := AABB(xf * Vector3(-size.x, -size.y, -size.z) * 0.5, Vector3.ZERO)
		for corner in Poly.from_rect(Rect2(-Vector2(size.x, size.z) * 0.5,
				Vector2(size.x, size.z))):
			for height in [-size.y * 0.5, size.y * 0.5]:
				part_box = part_box.expand(xf * Vector3(corner.x, height, corner.y))
		if part_box.grow(0.05).has_point(centre):
			rows.append("COMPONENT %s host=%s pos=%s size=%s" % [
				str(component.get("role", "")), str(component.get("host", "")),
				str(xf.origin), str(size)])
	if rows.is_empty():
		print("      no logged part contains it; bounds pos=%s size=%s"
			% [str(box.position), str(box.size)])
		return
	for text in rows:
		print("      part " + text)
