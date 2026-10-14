extends SceneTree
## Ordinary ceiling joists must meet actual wall and ceiling triangles.
var failures: Array[String] = []
var members_checked := 0

func _initialize() -> void:
	for style in [&"cottage", &"farmhouse", &"thatch_cottage", &"townhouse"]:
		for dimensions in [Vector2(9, 12), Vector2(12, 9), Vector2(7, 9), Vector2(14, 18)]:
			var spec := HouseSpec.new(8102)
			spec.style = style
			spec.width = dimensions.x
			spec.length = dimensions.y
			spec.height = 2.4 if dimensions == Vector2(7, 9) else 2.6
			spec.storeys = 2 if dimensions.x > 12.0 else 1
			var plan := HouseGenerator.generate(spec, 8102, false)
			var builder := HouseBuilder.new()
			var mesh := builder.build(plan)
			var rows := builder.components("domestic_ceiling_joist")
			if rows.is_empty():
				failures.append("%s/%s has no exposed ceiling structure" % [style, dimensions])
			var backing := MeshProbe.surface_triangles(builder, mesh, HouseBuilder.SURF_WALL)
			backing.append_array(MeshProbe.surface_triangles(builder, mesh, HouseBuilder.SURF_FLOOR))
			for row in rows:
				var box := MassBuilder.component_aabb(row)
				var floor_y := float(row.get("storey", 0)) * spec.height + HouseGeometry.FLOOR_T
				if box.position.y - floor_y < HouseGeometry.CEILING_MIN - 0.00001:
					failures.append("a joist violates measured walking headroom")
				if not _connected(box, backing):
					failures.append("%s/%s unsupported joist %s" % [style, dimensions, box])
				var shortened := box
				if box.size.x > box.size.z:
					shortened.position.x += 0.4
					shortened.size.x -= 0.8
				else:
					shortened.position.z += 0.4
					shortened.size.z -= 0.8
				if _connected(shortened, backing):
					failures.append("Short joist negative still claims wall bearing")
				var lowered := box
				lowered.position.y -= 0.3
				if _connected(lowered, backing):
					failures.append("Lowered joist negative still claims ceiling contact")
				members_checked += 1
			if spec.storeys > 1:
				var lower_count := 0
				for row in rows:
					if MassBuilder.component_aabb(row).position.y < spec.height:
						lower_count += 1
				if lower_count == 0:
					failures.append("multistorey house leaves its ground-floor ceiling bare")
			var parity := ComponentCheck.check(builder, mesh)
			if not parity["ok"]:
				failures.append("component parity: " + str(parity["failures"]))
			var cutaway := HouseBuilder.new()
			cutaway.build(plan, false)
			if not cutaway.components("domestic_ceiling_joist").is_empty():
				failures.append("cutaway retained ceiling joists")
			_check_reserved_space(plan)
			plan.spec.height = 2.3
			if not HouseGeometry.domestic_ceiling_ties(plan, 0, 2.3).is_empty():
				failures.append("low room lost required headroom to a joist")
	for spec: HouseSpec in [ShopSpec.new(), HotelSpec.new(), InsulaSpec.new()]:
		var plan := HousePlan.new()
		plan.spec = spec
		if not HouseGeometry.domestic_ceiling_ties(plan, 0, spec.height).is_empty():
			failures.append("ordinary ceiling changed a specialist family")
	for issue in failures:
		push_error(issue)
	print("Domestic ceilings: 16 rotated/small/multistorey households, %d measured members, %d failures" % [members_checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _connected(box: AABB, backing: Array) -> bool:
	var centre := box.get_center()
	if not MeshProbe.ray_blocked(backing, Vector3(centre.x, box.end.y - 0.01, centre.z),
			Vector3(centre.x, box.end.y + 0.01, centre.z)):
		return false
	var axis := Vector3.RIGHT if box.size.x > box.size.z else Vector3.BACK
	var half := maxf(box.size.x, box.size.z) * 0.5
	for sign_value in [-1.0, 1.0]:
		var end: Vector3 = centre + axis * sign_value * half
		if not MeshProbe.ray_blocked(backing, end - axis * sign_value * 0.10, end):
			return false
	return true


func _check_reserved_space(plan: HousePlan) -> void:
	var rows := HouseGeometry.domestic_ceiling_ties(plan, 0, plan.spec.height)
	if rows.is_empty():
		return
	var selected: Dictionary = rows[0]
	var xf: Transform3D = selected["xf"]
	var centre := Vector2(xf.origin.x, xf.origin.z)
	var opening := {"storey": 0, "rect": Rect2(centre - Vector2.ONE * 0.5, Vector2.ONE)}
	plan.stairs.append(opening)
	for member in HouseGeometry.domestic_ceiling_ties(plan, 0, plan.spec.height):
		var box: AABB = member["xf"] * AABB(-Vector3(member["size"]) * 0.5, member["size"])
		if Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).intersects(opening["rect"]):
			failures.append("a ceiling member crosses an actual stair opening")
	plan.stairs.pop_back()
	# A ceiling-hung prop has an empty walk footprint. Its visible mesh still
	# owns volume and must not be speared by the new woodwork.
	var chandelier := {"key": "Chandelier", "pos": Vector3(centre.x, plan.spec.height, centre.y),
		"yaw": 0.0, "scale": 1.0, "storey": 0, "rect": Rect2()}
	plan.furniture.append(chandelier)
	if _has_member(HouseGeometry.domestic_ceiling_ties(plan, 0, plan.spec.height), xf):
		failures.append("ceiling-hung fixture was ignored because its floor rectangle is empty")
	plan.furniture.pop_back()
	var size: Vector3 = selected["size"]
	var across_x := size.x > size.z
	var wall_point := centre + (Vector2.RIGHT * size.x if across_x else Vector2.DOWN * size.z) * 0.5
	var window := {"pos": wall_point, "normal": Vector2.RIGHT if across_x else Vector2.DOWN,
		"width": 1.0, "sill": 0.9, "head": plan.spec.height, "storey": 0}
	plan.windows.append(window)
	if _has_member(HouseGeometry.domestic_ceiling_ties(plan, 0, plan.spec.height), xf):
		failures.append("ceiling member crosses a high window aperture")
	plan.windows[-1]["head"] = 2.0
	if not _has_member(HouseGeometry.domestic_ceiling_ties(plan, 0, plan.spec.height), xf):
		failures.append("ordinary low window incorrectly removes ceiling bearing")
	plan.windows.pop_back()
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty():
		for member in rows:
			var box: AABB = member["xf"] * AABB(-Vector3(member["size"]) * 0.5, member["size"])
			if Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).intersects(breast["rect"]):
				failures.append("timber passes through the masonry chimney")


func _has_member(members: Array[Dictionary], xf: Transform3D) -> bool:
	for member in members:
		if Transform3D(member["xf"]).is_equal_approx(xf):
			return true
	return false
