extends SceneTree
## Run after promoting the staged silhouette files to src/house. This checks
## actual plans and emitted component/mass logs; it is not a screenshot proxy.

const SIZES := [
	{"id": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"id": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"id": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for size in SIZES:
		for seed_value in SEEDS:
			_check_witch(size, seed_value)
	for size in SIZES:
		_check_cottage_negative(size)
	_check_witch_occupation()
	_check_blocked_route_negative()
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
	_check_workshop_routes(plan, label)
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
	var chimney_exit_top := _roof_surface_height_in_footprint(roof_vertices,
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


func _roof_surface_height_in_footprint(vertices: PackedVector3Array, centre: Vector2,
		footprint: Vector2) -> float:
	if vertices.is_empty() or footprint.x <= 0.0 or footprint.y <= 0.0:
		return NAN
	var highest := -INF
	for fx in [-0.5, 0.0, 0.5]:
		for fy in [-0.5, 0.0, 0.5]:
			var sample := centre + Vector2(float(fx) * footprint.x, float(fy) * footprint.y)
			for y in _heights_at(vertices, sample):
				highest = maxf(highest, y)
	return highest if is_finite(highest) else NAN


func _chimney_fits_measured_exit(chimney_top: float, roof_exit_top: float) -> bool:
	return chimney_top <= roof_exit_top + HouseGeometry.CHIMNEY_TOP + 0.015


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


func _check_witch_occupation() -> void:
	var spec := _make_spec(&"witch_hut", SIZES[1])
	var plan := HouseGenerator.generate(spec, 8102, true)
	var shelter_group := ""
	var shelter_piece_id := ""
	var shelter_clearance: Dictionary = {}
	for piece in plan.yard_pieces:
		if String(piece.get("kind", "")) == "witch_work_lean_to":
			shelter_group = String(piece.get("group", ""))
			shelter_piece_id = String(piece.get("id", ""))
			var roof_found := false
			var roof_part: Dictionary = {}
			var post_parts: Array[Dictionary] = []
			var ledger_found := false
			var posts := 0
			for part in piece["parts"]:
				if String(part["role"]) == "witch_shelter_roof" and String(part["surf"]) == "roof":
					roof_found = true
					roof_part = part
				ledger_found = ledger_found or String(part["role"]) == "witch_shelter_ledger"
				if String(part["role"]) == "witch_shelter_post":
					posts += 1
					post_parts.append(part)
			if not roof_found or not ledger_found or posts != 2:
				failures.append("witch shelter needs a roof-material plane, wall ledger and two supports")
			elif not _supports_touch_roof(roof_part, post_parts):
				failures.append("witch shelter posts do not meet the measured roof underside")
	var expected_roles := ["witch_prep_bench", "witch_brewing_heat", "witch_cookware", "witch_water_vessel"]
	var work_props: Dictionary = {}
	for role in expected_roles:
		var found := false
		for prop in plan.yard:
			found = found or (String(prop.get("role", "")) == role \
				and String(prop.get("group", "")) == shelter_group)
			if String(prop.get("role", "")) == role \
					and String(prop.get("group", "")) == shelter_group:
				work_props[role] = prop
		if not found:
			failures.append("witch shelter is missing measured work role %s" % role)
	if not shelter_piece_id.is_empty() and work_props.size() == expected_roles.size():
		var shelter_piece: Dictionary = {}
		for piece in plan.yard_pieces:
			if String(piece.get("id", "")) == shelter_piece_id:
				shelter_piece = piece
				break
		var clearance: Dictionary = shelter_piece.get("work_clearance", {})
		shelter_clearance = clearance
		for role in ["witch_prep_bench", "witch_brewing_heat"]:
			_check_witch_approach(plan, shelter_piece, clearance, work_props[role], role)
		if not HouseYard.access_ok(plan):
			failures.append("witch work shelter blocks a yard route to a house door")
	if shelter_group.is_empty():
		failures.append("witch default yard has no service-wall work shelter")
	else:
		var builder := HouseBuilder.new()
		var shelter_mesh: ArrayMesh = builder.build(plan, true)
		var emitted := {"witch_shelter_post": 0, "witch_shelter_ledger": 0,
			"witch_shelter_roof": 0}
		var emitted_roof: Dictionary = {}
		var emitted_ledger: Dictionary = {}
		var emitted_posts: Array[Dictionary] = []
		for component in builder.component_log:
			if String(component.get("piece", "")) != shelter_piece_id:
				continue
			var component_role := String(component.get("role", ""))
			if emitted.has(component_role):
				emitted[component_role] += 1
			if component_role == "witch_shelter_roof":
				emitted_roof = component
			elif component_role == "witch_shelter_ledger":
				emitted_ledger = component
			elif component_role == "witch_shelter_post":
				emitted_posts.append(component)
		if int(emitted["witch_shelter_post"]) != 2 or int(emitted["witch_shelter_ledger"]) != 1 \
				or int(emitted["witch_shelter_roof"]) != 1:
			failures.append("witch shelter plan parts did not emit under the matched yard piece")
		else:
			var roof_kit := MeshKit.new(1)
			roof_kit.oriented_box(emitted_roof["size"], emitted_roof["xf"], 0)
			var isolated_roof: ArrayMesh = roof_kit.commit()
			var roof_triangles: PackedVector3Array = isolated_roof.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var roof_surface: PackedVector3Array = shelter_mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
			var wall_surface: PackedVector3Array = shelter_mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
			var trim_surface: PackedVector3Array = shelter_mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
			var ledger_kit := MeshKit.new(1)
			ledger_kit.oriented_box(emitted_ledger["size"], emitted_ledger["xf"], 0)
			var isolated_ledger: ArrayMesh = ledger_kit.commit()
			var ledger_triangles: PackedVector3Array = isolated_ledger.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if not ComponentCheck.contains_triangles(roof_surface, roof_triangles) \
					or not ComponentCheck.contains_triangles(trim_surface, ledger_triangles):
				failures.append("witch shelter roof or ledger log does not match emitted mesh")
			if not _emitted_posts_touch_roof(roof_triangles, emitted_posts):
				failures.append("witch shelter emitted posts miss the actual roof underside ray")
			if not _emitted_ledger_touches_wall_and_roof(emitted_ledger, roof_triangles,
					wall_surface, shelter_clearance):
				failures.append("witch shelter emitted ledger misses wall or roof contact")
			_check_shelter_contact_negatives(emitted_ledger, roof_triangles, wall_surface, emitted_posts, shelter_clearance)
			_check_shelter_cardinal_mesh_contacts(plan)
			for prefix in ["witch_work_wing"]:
				var bay_roof: Dictionary = {}
				var bay_ledger: Dictionary = {}
				var bay_posts: Array[Dictionary] = []
				for component in builder.component_log:
					if String(component.get("piece", "")) != shelter_piece_id:
						continue
					var component_role := String(component.get("role", ""))
					if component_role == prefix + "_roof":
						bay_roof = component
					elif component_role == prefix + "_ledger":
						bay_ledger = component
					elif component_role == prefix + "_post":
						bay_posts.append(component)
				var expected_posts := 0 if prefix == "witch_work_wing" else 2
				if bay_roof.is_empty() or bay_ledger.is_empty() or bay_posts.size() != expected_posts:
					failures.append("%s lacks its emitted roof, ledger or required supports" % prefix)
					continue
				var bay_kit := MeshKit.new(1)
				bay_kit.oriented_box(bay_roof["size"], bay_roof["xf"], 0)
				var bay_mesh: ArrayMesh = bay_kit.commit()
				var bay_triangles: PackedVector3Array = bay_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if not ComponentCheck.contains_triangles(roof_surface, bay_triangles):
					failures.append("%s roof log is absent from the actual roof surface" % prefix)
				if not bay_posts.is_empty() and not _emitted_posts_touch_roof(bay_triangles, bay_posts):
					failures.append("%s support posts miss the actual roof underside" % prefix)
				if not _emitted_ledger_touches_wall_and_roof(bay_ledger, bay_triangles,
						wall_surface, shelter_clearance):
					failures.append("%s ledger misses the wall or its measured roof" % prefix)
			var wing_wall_components: Array[Dictionary] = []
			var wing_header_components: Array[Dictionary] = []
			var wing_frame_components: Array[Dictionary] = []
			for component in builder.component_log:
				if String(component.get("piece", "")) != shelter_piece_id:
					continue
				if String(component.get("role", "")) == "witch_work_wing_wall":
					wing_wall_components.append(component)
				elif String(component.get("role", "")) == "witch_work_wing_header":
					wing_header_components.append(component)
				elif String(component.get("role", "")) == "witch_work_wing_frame":
					wing_frame_components.append(component)
			if wing_wall_components.size() != 18:
				failures.append("enclosed work wing emitted %d timber wall components, expected 18" % wing_wall_components.size())
			if wing_header_components.size() != 1:
				failures.append("enclosed work wing lacks its single measured yard-entry lintel")
			if wing_frame_components.size() < 6:
				failures.append("enclosed work wing lacks visible front framing around its service opening")
			for component in wing_wall_components:
				var wall_kit := MeshKit.new(1)
				wall_kit.oriented_box(component["size"], component["xf"], 0)
				var wall_mesh: ArrayMesh = wall_kit.commit()
				var wall_triangles: PackedVector3Array = wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if not ComponentCheck.contains_triangles(trim_surface, wall_triangles):
					failures.append("Witch work-wing timber wall log does not match emitted trim geometry")
					break
			for component in wing_header_components:
				var lintel_kit := MeshKit.new(1)
				lintel_kit.oriented_box(component["size"], component["xf"], 0)
				var lintel_mesh: ArrayMesh = lintel_kit.commit()
				var lintel_triangles: PackedVector3Array = lintel_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if not ComponentCheck.contains_triangles(trim_surface, lintel_triangles):
					failures.append("Witch work-wing lintel log does not match emitted trim geometry")
					break
			for component in wing_frame_components:
				var frame_kit := MeshKit.new(1)
				frame_kit.oriented_box(component["size"], component["xf"], 0)
				var frame_mesh: ArrayMesh = frame_kit.commit()
				var frame_triangles: PackedVector3Array = frame_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if not ComponentCheck.contains_triangles(wall_surface, frame_triangles):
					failures.append("Witch work-wing front frame log does not match emitted wall surface")
					break
	for role in ["herb_bed", "drying_line"]:
		var found_group := false
		for piece in plan.yard_pieces:
			if String(piece.get("role", "")) == role or String(piece.get("group", "")).begins_with(role + "#"):
				if role == "drying_line":
					var line_found := false
					var posts := 0
					for part in piece.get("parts", []):
						line_found = line_found or String(part.get("role", "")) == "line"
						if String(part.get("role", "")) == "line_post":
							posts += 1
					found_group = line_found and posts >= 2
				else:
					found_group = true
		for prop in plan.yard:
			if String(prop.get("role", "")) == role or String(prop.get("group", "")).begins_with(role + "#"):
				found_group = true
		if not found_group:
			failures.append("witch yard is missing its %s group" % role)
	var workshop := plan.rooms_of(&"workshop")
	if workshop.is_empty():
		failures.append("witch ordinary programme has no workshop for craft activity")
		return
	var room := workshop[0]
	var counts := {"workbench": 0, "hearth": 0, "alchemy": 0}
	for item in plan.furniture:
		if int(item["room"]) == room and String(item.get("activity_group", "")) == "witchwork":
			var category := String(item["cat"])
			if counts.has(category):
				counts[category] += 1
	for category in counts:
		if int(counts[category]) == 0:
			failures.append("witchwork lacks placed %s activity" % category)
	if not _has_witchwork_bottle_support(plan, room):
		failures.append("witchwork lacks its measured bottle-support wall fitting")
	else:
		var broken_support := HousePlan.new()
		broken_support.furniture = plan.furniture.duplicate(true)
		broken_support.wall_hosts = plan.wall_hosts.duplicate(true)
		for host_index in range(broken_support.wall_hosts.size() - 1, -1, -1):
			var host: Dictionary = broken_support.wall_hosts[host_index]
			if String(host.get("role", "")) == "activity_support" \
					and String(host.get("activity_group", "")) == "witchwork":
				broken_support.wall_hosts.remove_at(host_index)
		if _has_witchwork_bottle_support(broken_support, room):
			failures.append("removing the Witchwork bottle-rack wall host passed the support negative control")


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

func _check_workshop_routes(plan: HousePlan, label: String) -> void:
	var workshop := plan.rooms_of(&"workshop")
	if workshop.is_empty():
		return
	var room := workshop[0]
	var nav := HouseNavCheck.new()
	var report: Dictionary = nav.check(plan)
	if not bool(report.get("ok", false)):
		failures.append("%s HouseNavCheck failed before work-route proof: %s" % [label, str(report.get("failures", []))])
	var entrance := plan.entrance()
	if entrance < 0:
		failures.append("%s has no entrance for workshop route proof" % label)
		return
	var door: Dictionary = plan.doors[entrance]
	var storey := HousePlan.record_storey(door)
	if not nav._grids.has(storey):
		failures.append("%s entrance floor grid is missing" % label)
		return
	var grid: WalkGrid = nav._grids[storey]
	var start: Vector2 = Vector2(door["pos"]) - Vector2(door["normal"]) * (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.2)
	if not grid.flood_from(start):
		failures.append("%s cannot start body-radius route inside entrance" % label)
		return
	var targets := 0
	var alchemy_materials := 0
	for item in plan.furniture:
		if int(item.get("room", -1)) != room or String(item.get("activity_group", "")) != "witchwork":
			continue
		var category := String(item.get("cat", ""))
		if category == "alchemy":
			# Reagents are tabletop work, not additional walkable floor stations.
			var host_index := int(item.get("host", -1))
			var key := String(item.get("key", ""))
			if host_index < 0 or host_index >= plan.furniture.size() \
					or not PropCatalog.has_tag(key, PropCatalog.ON_SURFACE):
				failures.append("%s alchemy material %s is not a measured supported tabletop item" % [label, key])
				continue
			var host: Dictionary = plan.furniture[host_index]
			var host_rect: Rect2 = host.get("rect", Rect2())
			var item_rect: Rect2 = item.get("rect", Rect2())
			if int(host.get("room", -1)) != room or String(host.get("activity_group", "")) != "witchwork" \
					or String(host.get("cat", "")) != "workbench" \
					or not host_rect.grow(-0.015).encloses(item_rect):
				failures.append("%s alchemy material %s is not supported on the Witchwork workbench" % [label, key])
				continue
			alchemy_materials += 1
			continue
		if category not in ["workbench", "hearth"]:
			continue
		var zone: Rect2 = item.get("zone", Rect2())
		if not zone.has_area():
			failures.append("%s %s has no measured use zone" % [label, category])
			continue
		targets += 1
		var distance := grid.distance_to(zone.get_center(), HouseGeometry.PERSON_RADIUS)
		if not is_finite(distance) or not grid.reached(zone, HouseGeometry.PERSON_RADIUS * 0.5):
			failures.append("%s entrance cannot reach %s use zone on the body-eroded floor grid" % [label, category])
	if targets != 2:
		failures.append("%s route proof found %d of 2 required Witchwork floor stations" % [label, targets])
	if alchemy_materials != 2:
		failures.append("%s Witchwork has %d of exactly 2 alchemy materials on its measured workbench" % [label, alchemy_materials])
	var support_check := HouseFurnishPhysicalCheck.new()
	support_check.check_supported(plan)
	for support_failure in support_check.failures:
		if String(support_failure).begins_with("supported:"):
			failures.append("%s %s" % [label, String(support_failure)])

func _check_blocked_route_negative() -> void:
	var floor := Rect2(Vector2.ZERO, Vector2(6.0, 4.0))
	var start := Vector2(1.0, 2.0)
	var target := Rect2(Vector2(4.5, 1.5), Vector2(0.4, 1.0))
	var open_grid := WalkGrid.new()
	open_grid.setup(floor, HouseGeometry.NAV_CELL)
	open_grid.add_floor(floor)
	open_grid.build(HouseGeometry.PERSON_RADIUS)
	if not open_grid.flood_from(start) or not open_grid.reached(target):
		failures.append("blocked-route negative control is invalid: open floor should reach target")
	var blocked_grid := WalkGrid.new()
	blocked_grid.setup(floor, HouseGeometry.NAV_CELL)
	blocked_grid.add_floor(floor)
	blocked_grid.add_obstacle(Rect2(Vector2(2.85, 0.0), Vector2(0.3, 4.0)))
	blocked_grid.build(HouseGeometry.PERSON_RADIUS)
	if not blocked_grid.flood_from(start):
		failures.append("blocked-route negative control cannot start")
	elif blocked_grid.reached(target):
		failures.append("blocked-route negative control failed to detect a full-width barrier")
func _check_witch_approach(plan: HousePlan, shelter: Dictionary, clearance: Dictionary,
		prop: Dictionary, role: String) -> void:
	if clearance.is_empty() or not prop.has("operation_zone"):
		failures.append("%s has no measured operation-zone contract" % role)
		return
	var zone: Rect2 = prop["operation_zone"]
	var size := float(clearance.get("approach_size", 0.0))
	if absf(zone.size.x - size) > 0.001 or absf(zone.size.y - size) > 0.001:
		failures.append("%s operation zone is not a measured %.1f m square" % [role, size])
	var prep_role := role == "witch_prep_bench"
	var roof_key := "prep_roof_rect" if prep_role else "brew_roof_rect"
	var roof: Rect2 = clearance.get(roof_key, Rect2())
	if not roof.encloses(zone):
		failures.append("%s operation zone leaves its assigned service-bay roof projection" % role)
		return
	var origin: Vector2 = clearance["origin"]
	var outward: Vector2 = clearance["out"]
	var far_d := -INF
	for corner in [zone.position, Vector2(zone.end.x, zone.position.y), zone.end,
		Vector2(zone.position.x, zone.end.y)]:
		far_d = maxf(far_d, (corner - origin).dot(outward))
	var gap := float(clearance["gap"])
	var depth := float(clearance["depth"])
	var wall_y := float(clearance["wall_y"])
	var drop := float(clearance["drop"])
	var thickness := float(clearance["roof_thickness"])
	var tangent: Vector2 = clearance["tangent"]
	outward = clearance["out"]
	var out3 := Vector3(outward.x, 0.0, outward.y)
	var roof_basis := Basis(Vector3.UP.cross(out3), Vector3.UP, out3) * Basis(Vector3.RIGHT, atan2(drop, depth))
	var origin_2 := origin + outward * (gap + depth * 0.5)
	var roof_origin := Vector3(origin_2.x, wall_y - drop * 0.5, origin_2.y)
	var sample_2 := origin + outward * far_d
	var inverse := roof_basis.inverse()
	var local_at_floor := inverse * (Vector3(sample_2.x, 0.0, sample_2.y) - roof_origin)
	var local_y_per_world_y := (inverse * Vector3.UP).y
	var underside := (-thickness * 0.5 - local_at_floor.y) / local_y_per_world_y
	var required := float(clearance["required_headroom"])
	if underside < required - 0.001:
		failures.append("%s operation zone headroom is %.2f m, below %.2f m" % [role, underside, required])
	var zone_box := AABB(Vector3(zone.position.x, 0.0, zone.position.y),
		Vector3(zone.size.x, required, zone.size.y))
	for other in plan.yard:
		if String(other.get("id", "")) == String(prop.get("id", "")):
			continue
		var bounds: AABB = HouseExterior.bounds_of(other)
		if bounds.position.y + bounds.size.y <= 0.2 or bounds.position.y >= required:
			continue
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		if zone.intersects(footprint):
			failures.append("%s operation zone is blocked by yard prop %s" % [role, other.get("id", "?" )])
	for piece in plan.yard_pieces:
		for part in piece["parts"]:
			var part_role := String(part["role"])
			if part_role.ends_with("_roof") or part_role.ends_with("_ledger"):
				continue
			var bounds := HouseYard.part_aabb(part)
			if bounds.position.y + bounds.size.y <= 0.2 or bounds.position.y >= required:
				continue
			if zone_box.intersects(bounds):
				failures.append("%s operation zone is blocked by yard structure %s" % [role, part.get("role", "?")])
