extends SceneTree
## Run after promoting the staged silhouette files to src/house. This checks
## actual plans and emitted component/mass logs; it is not a screenshot proxy.

const SIZES := [
	{"id": "small", "width": 7.0, "length": 9.0, "height": 2.6},
]
const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for size in SIZES:
		for seed_value in SEEDS:
			_check_witch(size, seed_value)
	for size in SIZES:
		_check_cottage_negative(size)
	for failure in failures:
		printerr("FAIL " + failure)
	print("witch silhouette fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _make_spec(style: StringName, size: Dictionary) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.width = float(size["width"])
	spec.length = float(size["length"])
	spec.height = float(size["height"])
	return spec


func _check_witch(size: Dictionary, seed_value: int) -> void:
	var spec := _make_spec(&"witch_hut", size)
	var plan := HouseGenerator.generate(spec, seed_value, true)
	var label := "%s seed=%d" % [size["id"], seed_value]
	if not plan.spec.porch:
		failures.append("%s lost the protected witch entry" % label)
	var span := minf(spec.width, spec.length)
	var cap := clampf(span * 0.52, 3.6, 5.6)
	if HouseGeometry.roof_rise(plan.spec) > cap + 0.001:
		failures.append("%s roof exceeds the witch silhouette cap" % label)
	if absf(HouseGeometry.porch_depth(plan.spec) - 1.8) > 0.001:
		failures.append("%s entry shelter is not deep enough" % label)
	var door_id := plan.entrance()
	if door_id < 0:
		failures.append("%s has no entrance for its shelter" % label)
		return
	var door: Dictionary = plan.doors[door_id]
	if HouseGeometry.porch_center(plan).distance_to(Vector2(door["pos"])) < 0.2:
		failures.append("%s entry roof lost its deliberate offset" % label)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	_check_witch_porch_bounds(plan, builder, label)
	var found_roof := false
	var found_supports := 0
	for part in builder.component_log:
		if part.get("role", "") == "witch_entry_lean_to" and part.get("host", "") == "porch":
			found_roof = true
		if str(part.get("role", "")).begins_with("witch_entry_support_"):
			found_supports += 1
	if not found_roof or found_supports != 2:
		failures.append("%s shelter lacks named roof and two emitted supports" % label)
	var chimney_found := false
	var roof_vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX] \
		if mesh.get_surface_count() > HouseBuilder.SURF_ROOF else PackedVector3Array()
	var chimney_flue_size := HouseGeometry.chimney_flue_size(plan.spec, plan.world_family)
	var chimney_exit_top := _roof_surface_height_in_footprint(mesh,
		HouseGeometry.chimney_center(plan), Vector2.ONE * chimney_flue_size)
	var ridge_surface_top := -INF
	for vertex in roof_vertices:
		ridge_surface_top = maxf(ridge_surface_top, vertex.y)
	for mass in builder.mass_log:
		if mass.get("name", "") == "chimney":
			chimney_found = true
			var bounds: AABB = mass["aabb"]
			var chimney_top := bounds.position.y + bounds.size.y
			if not is_finite(chimney_exit_top):
				failures.append("%s chimney footprint has no emitted roof surface exit" % label)
			elif not _chimney_fits_measured_exit(chimney_top, chimney_exit_top):
				failures.append("%s chimney extends above its measured roof exit by more than the emitted crown, pot and clearance" % label)
			# Negative control: the old ridge-height stack must fail this same
			# local-exit rule whenever the ridge is measurably higher than the
			# actual roof under the flue.
			if is_finite(chimney_exit_top) and ridge_surface_top > chimney_exit_top + 0.05 \
					and _chimney_fits_measured_exit(ridge_surface_top + HouseGeometry.CHIMNEY_TOP,
						chimney_exit_top):
				failures.append("%s chimney ridge-height negative control was incorrectly accepted" % label)
	if not chimney_found:
		failures.append("%s did not emit its required chimney" % label)


## The highest emitted roof surface anywhere under the flue's footprint.
##
## Nine point samples can straddle a thatch bundle that crosses the footprint:
## the service eave runs along the ridge, its crown stands THATCH_EAVE_H above
## the plane, and it can fall between two stations. Clipping every emitted roof
## triangle to the square and measuring at the clipped corners is exact for
## planar triangles, and it measures the same surface the stack is sized from.
func _roof_surface_height_in_footprint(mesh : ArrayMesh, centre: Vector2,
		footprint: Vector2) -> float:
	if mesh == null or HouseBuilder.SURF_ROOF >= mesh.get_surface_count() \
			or footprint.x <= 0.0 or footprint.y <= 0.0:
		return NAN
	var vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	var square := Poly.from_rect(Rect2(centre - footprint * 0.5, footprint))
	var highest := -INF
	for index in range(0, vertices.size() - 2, 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var triangle := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
		var clipped := Poly.clip_convex(triangle, square)
		if clipped.size() < 3:
			continue
		for point in clipped:
			for y in _heights_at(vertices, point):
				highest = maxf(highest, y)
	return highest if is_finite(highest) else NAN


func _chimney_fits_measured_exit(chimney_top: float, roof_exit_top: float) -> bool:
	# A Witch stack leaves the roof at CHIMNEY_TOP above its measured exit and
	# then climbs HouseBuilder.WITCH_STACK_EXTRA as its crooked upper courses --
	# the hut's one deliberately over-tall mass. The bound is the emitted
	# design, not an older stack that stopped at the exit.
	return chimney_top <= roof_exit_top + HouseGeometry.CHIMNEY_TOP \
		+ HouseBuilder.WITCH_STACK_EXTRA + 0.015


func _check_witch_porch_bounds(plan: HousePlan, builder: HouseBuilder, label: String) -> void:
	var expected := HouseGeometry.porch_rect(plan)
	for mass in builder.mass_log:
		if String(mass.get("name", "")) != "porch_step":
			continue
		var bounds: AABB = mass["aabb"]
		var actual := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		if actual.position.distance_to(expected.position) > 0.002 \
				or actual.size.distance_to(expected.size) > 0.002:
			failures.append("%s emitted Witch entry step does not match its asymmetric wall footprint" % label)
		return
	failures.append("%s did not emit Witch entry step bounds" % label)


func _check_cottage_negative(size: Dictionary) -> void:
	var spec := _make_spec(&"cottage", size)
	var plan := HouseGenerator.generate(spec, 8102, false)
	var expected := minf(plan.spec.width, plan.spec.length) * plan.spec.roof_pitch * 0.5
	if absf(HouseGeometry.roof_rise(plan.spec) - expected) > 0.001:
		failures.append("cottage/%s was changed by the witch-only roof bound" % size["id"])
	if absf(HouseGeometry.porch_depth(plan.spec) - 1.35) > 0.001:
		failures.append("cottage/%s inherited the witch-only entry depth" % size["id"])
	for piece in plan.yard_pieces:
		if String(piece.get("kind", "")) == "witch_work_lean_to":
			failures.append("cottage/%s inherited the witch work shelter" % size["id"])


func _has_witchwork_bottle_support(plan: HousePlan, room: int) -> bool:
	for item in plan.furniture:
		if int(item.get("room", -1)) != room or String(item.get("key", "")) != "Shelf_Small_Bottles" \
				or String(item.get("activity_group", "")) != "witchwork" \
				or not bool(item.get("mounted", false)):
			continue
		var anchor_id := String(item.get("activity_anchor_id", ""))
		var wall_host_id := String(item.get("wall_host_id", ""))
		if anchor_id.is_empty() or wall_host_id.is_empty():
			continue
		for wall_host in plan.wall_hosts:
			if String(wall_host.get("id", "")) == wall_host_id \
					and int(wall_host.get("room", -1)) == room \
					and String(wall_host.get("role", "")) == "activity_support" \
					and String(wall_host.get("activity_group", "")) == "witchwork" \
					and String(wall_host.get("anchor_id", "")) == anchor_id \
					and String(wall_host.get("target_category", "")) == "shelf" \
					and String(wall_host.get("content_kind", "")) == "integrated_ingredient_rack" \
					and String(wall_host.get("content_asset_key", "")) == "Shelf_Small_Bottles":
				return true
	return false

func _check_shelter_contact_negatives(ledger: Dictionary, roof: PackedVector3Array,
		wall: PackedVector3Array, posts: Array[Dictionary], clearance: Dictionary) -> void:
	var lifted_roof := roof.duplicate()
	for index in range(lifted_roof.size()):
		lifted_roof[index] += Vector3.UP * 0.02
	if _emitted_posts_touch_roof(lifted_roof, posts):
		failures.append("20 mm lifted shelter roof passed the emitted-post contact control")
	if _emitted_ledger_touches_wall_and_roof(ledger, lifted_roof, wall, clearance):
		failures.append("20 mm lifted shelter roof passed the emitted-ledger contact control")
	var dropped_posts: Array[Dictionary] = []
	for index in range(posts.size()):
		var moved: Dictionary = posts[index].duplicate(true)
		if index == 0:
			var xf: Transform3D = moved["xf"]
			xf.origin.y -= 0.03
			moved["xf"] = xf
		dropped_posts.append(moved)
	if _emitted_posts_touch_roof(roof, dropped_posts):
		failures.append("30 mm dropped shelter post passed the emitted-roof contact control")
	var detached: Dictionary = ledger.duplicate(true)
	var ledger_xf: Transform3D = detached["xf"]
	var outward: Vector2 = clearance["out"]
	ledger_xf.origin += Vector3(outward.x, 0.0, outward.y) * 0.03
	detached["xf"] = ledger_xf
	if _emitted_ledger_touches_wall_and_roof(detached, roof, wall, clearance):
		failures.append("30 mm detached shelter ledger passed wall/roof contact control")


func _check_shelter_cardinal_mesh_contacts(plan: HousePlan) -> void:
	for outward in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var tangent := Vector2(-outward.y, outward.x)
		var cell := {"o": Vector2(20.0, 30.0), "tan": tangent, "out": outward, "host": "cardinal_wall_%s" % str(outward)}
		var made: Dictionary = HouseYard._witch_work_shelter(
			{"plan": plan, "accepted": []}, cell, 0.2)
		if made.is_empty() or made.get("pieces", []).is_empty():
			failures.append("Witch shelter cardinal mesh fixture could not build for outward=%s" % str(outward))
			continue
		var piece: Dictionary = made["pieces"][0]
		var roof_part: Dictionary = {}
		var cardinal_posts: Array[Dictionary] = []
		for part in piece["parts"]:
			if String(part.get("role", "")) == "witch_shelter_roof":
				roof_part = part
			elif String(part.get("role", "")) == "witch_shelter_post":
				cardinal_posts.append({"xf": HouseYard.part_xform(part), "size": part["size"]})
		if roof_part.is_empty() or cardinal_posts.size() != 2:
			failures.append("Witch shelter cardinal mesh fixture lacks roof/two posts for outward=%s" % str(outward))
			continue
		var roof_kit := MeshKit.new(1)
		roof_kit.oriented_box(roof_part["size"], HouseYard.part_xform(roof_part), 0)
		var roof_mesh: ArrayMesh = roof_kit.commit()
		var roof_triangles: PackedVector3Array = roof_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if not _emitted_posts_touch_roof(roof_triangles, cardinal_posts):
			failures.append("Witch shelter roof/post mesh contact failed cardinal outward=%s" % str(outward))


func _supports_touch_roof(roof_part: Dictionary, post_parts: Array[Dictionary]) -> bool:
	if roof_part.is_empty() or post_parts.size() != 2:
		return false
	var roof_xf := HouseYard.part_xform(roof_part)
	var roof_size: Vector3 = roof_part["size"]
	var roof_inverse := roof_xf.basis.inverse()
	var local_y_per_world_y: float = (roof_inverse * Vector3.UP).y
	if absf(local_y_per_world_y) < 0.001:
		return false
	for post in post_parts:
		var bounds := HouseYard.part_aabb(post)
		var top := bounds.position.y + bounds.size.y
		var centre := bounds.get_center()
		var local_at_floor: Vector3 = roof_inverse * (
			Vector3(centre.x, 0.0, centre.z) - roof_xf.origin)
		var roof_y: float = (-roof_size.y * 0.5 - local_at_floor.y) / local_y_per_world_y
		var contact := roof_inverse * (Vector3(centre.x, roof_y, centre.z) - roof_xf.origin)
		if absf(top - roof_y) > 0.005 \
				or absf(contact.x) > roof_size.x * 0.5 + 0.005 \
				or absf(contact.z) > roof_size.z * 0.5 + 0.005:
			return false
	return true


func _emitted_posts_touch_roof(roof: PackedVector3Array, posts: Array[Dictionary]) -> bool:
	if roof.is_empty() or posts.size() != 2:
		return false
	for post in posts:
		var xf: Transform3D = post["xf"]
		var size: Vector3 = post["size"]
		var centre: Vector3 = xf * Vector3.ZERO
		var top: float = centre.y + size.y * 0.5
		var heights := _heights_at(roof, Vector2(centre.x, centre.z))
		if heights.is_empty() or absf(top - heights.min()) > 0.005:
			return false
	return true


func _emitted_ledger_touches_wall_and_roof(ledger: Dictionary, roof: PackedVector3Array,
		wall: PackedVector3Array, clearance: Dictionary) -> bool:
	if ledger.is_empty() or roof.is_empty() or wall.is_empty() \
			or not clearance.has("out") or not clearance.has("tangent"):
		return false
	var xf: Transform3D = ledger["xf"]
	var size: Vector3 = ledger["size"]
	var centre: Vector3 = xf * Vector3.ZERO
	var outward: Vector2 = clearance["out"]
	var tangent: Vector2 = clearance["tangent"]
	var top: float = centre.y + size.y * 0.5
	for tangent_offset in [-0.35, 0.0, 0.35]:
		var tangent3: Vector3 = Vector3(tangent.x, 0.0, tangent.y) * float(tangent_offset)
		var inner := Vector3(centre.x, centre.y, centre.z) \
			- Vector3(outward.x, 0.0, outward.y) * 0.06 + tangent3
		if _point_mesh_distance(inner, wall) > 0.005:
			return false
		var outer := Vector3(centre.x, top, centre.z) \
			+ Vector3(outward.x, 0.0, outward.y) * 0.06 + tangent3
		var heights := _heights_at(roof, Vector2(outer.x, outer.z))
		if heights.is_empty() or absf(top - heights.min()) > 0.005:
			return false
	return true


func _heights_at(vertices: PackedVector3Array, point: Vector2) -> Array[float]:
	var heights: Array[float] = []
	if vertices.size() % 3 != 0:
		return heights
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var u := Vector2(b.x - a.x, b.z - a.z)
		var v := Vector2(c.x - a.x, c.z - a.z)
		var q := point - Vector2(a.x, a.z)
		var determinant := u.cross(v)
		if absf(determinant) < 0.000001:
			continue
		var first := q.cross(v) / determinant
		var second := u.cross(q) / determinant
		if first < -0.0001 or second < -0.0001 or first + second > 1.0001:
			continue
		heights.append(a.y + first * (b.y - a.y) + second * (c.y - a.y))
	return heights


func _point_mesh_distance(point: Vector3, vertices: PackedVector3Array) -> float:
	if vertices.is_empty() or vertices.size() % 3 != 0:
		return INF
	var best := INF
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var ab := b - a
		var ac := c - a
		var normal := ab.cross(ac)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		var projected := point - normal * (point - a).dot(normal)
		var d00 := ac.dot(ac)
		var d01 := ac.dot(ab)
		var d11 := ab.dot(ab)
		var d20 := (projected - a).dot(ac)
		var d21 := (projected - a).dot(ab)
		var denom := d00 * d11 - d01 * d01
		if absf(denom) > 0.0000001:
			var u := (d11 * d20 - d01 * d21) / denom
			var v := (d00 * d21 - d01 * d20) / denom
			if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
				best = minf(best, absf((point - a).dot(normal)))
		best = minf(best, _point_segment_distance(point, a, b))
		best = minf(best, _point_segment_distance(point, b, c))
		best = minf(best, _point_segment_distance(point, c, a))
	return best


func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0000001:
		return point.distance_to(a)
	var fraction := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * fraction)
