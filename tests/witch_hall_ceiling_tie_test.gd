extends SceneTree
## Measured structural and clearance contract for Witch hall ceiling ties.
## Run against the staged HouseBuilder proposal. No image count is acceptance.

const CASES := [
	{"id": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"id": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"id": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
var failures: Array[String] = []

func _init() -> void:
	for size in CASES:
		_check_witch(size)
	_check_control(&"cottage", &"none", false)
	_check_control(&"witch_hut", &"alchemist", false)
	_check_world_control()
	for failure in failures:
		printerr("FAIL " + failure)
	print("Witch hall ceiling tie contract: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _spec(style: StringName, trade: StringName, size: Dictionary) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.width = float(size["width"])
	spec.length = float(size["length"])
	spec.height = float(size["height"])
	return spec


func _check_witch(size: Dictionary) -> void:
	var plan := HouseGenerator.generate(_spec(&"witch_hut", &"none", size), 8102, false)
	var label := "witch/%s/8102" % String(size["id"])
	if not HouseGeometry.uses_witch_asymmetric_roof(plan.spec, plan.world_family):
		failures.append("%s did not select the ordinary Witch architecture path" % label)
		return
	var builder := HouseBuilder.new()
	var shell := builder.build(plan, true)
	var ties: Array = _roles(builder, "witch_hall_ceiling_tie")
	if ties.is_empty():
		failures.append("%s emitted no measured hall ceiling tie" % label)
		return
	var hall_count := 0
	for room_index in range(plan.rooms.size()):
		if plan.kind_of(room_index) == &"hall":
			hall_count += 1
	if hall_count == 0:
		failures.append("%s has no hall for this structural fixture" % label)
	for tie in ties:
		_check_tie_support(plan, builder, shell, tie, label)
	var parity: Dictionary = ComponentCheck.check(builder, shell)
	if not bool(parity.get("ok", false)):
		failures.append("%s ceiling structure differs from emitted triangles: %s" % [
			label, str(parity.get("failures", []))])
	shell.clear_surfaces()


func _check_tie_support(plan: HousePlan, builder: HouseBuilder, shell: ArrayMesh,
		tie: Dictionary, label: String) -> void:
	var host_name := String(tie.get("host", ""))
	var room_index := int(host_name.get_slice("_room", 1)) if host_name.contains("_room") else -1
	if room_index < 0 or room_index >= plan.rooms.size():
		failures.append("%s tie has no valid measured hall host" % label)
		return
	if plan.kind_of(room_index) != &"hall":
		failures.append("%s tie is attached to a non-hall room" % label)
		return
	var room: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
	var size: Vector3 = tie["size"]
	var xf: Transform3D = tie["xf"]
	var across_x := room.size.x <= room.size.y
	var short_span := minf(room.size.x, room.size.y)
	var long_span := maxf(room.size.x, room.size.y)
	var wall_t: float = HouseGeometry.wall_thickness(plan.spec)
	var end_bearing := wall_t * 0.35
	var actual_span: float = size.x if across_x else size.z
	if actual_span + 0.001 < short_span + 2.0 * end_bearing:
		failures.append("%s tie does not enter both measured hall walls" % label)
	var tie_bottom := xf.origin.y - size.y * 0.5
	var tie_top := xf.origin.y + size.y * 0.5
	var ceiling_y := float(plan.storey_of_room(room_index) + 1) * plan.spec.height
	if absf(tie_top - ceiling_y) > 0.002:
		failures.append("%s tie top does not meet the ceiling underside" % label)
	var storey_floor_top := float(plan.storey_of_room(room_index)) * plan.spec.height + HouseGeometry.FLOOR_T
	if tie_bottom - storey_floor_top < 2.18:
		failures.append("%s tie drops below 2.18 m clearance over the finished storey floor" % label)
	var ceilings: Array = _roles(builder, "ceiling")
	var supported_ceiling := false
	for ceiling in ceilings:
		if int(ceiling.get("storey", -1)) != int(tie.get("storey", -2)):
			continue
		var ceiling_xf: Transform3D = ceiling["xf"]
		var ceiling_size: Vector3 = ceiling["size"]
		var ceiling_bottom := ceiling_xf.origin.y - ceiling_size.y * 0.5
		var local := xf.origin - ceiling_xf.origin
		if absf(ceiling_bottom - tie_top) <= 0.002 and absf(local.x) <= ceiling_size.x * 0.5 and absf(local.z) <= ceiling_size.z * 0.5:
			supported_ceiling = true
	if not supported_ceiling:
		failures.append("%s tie does not bear against the actual emitted ceiling slab" % label)
	if _tie_conflicts_with_aperture(plan, room, xf.origin, size, across_x, tie_bottom, tie_top):
		failures.append("%s tie crosses a door or window aperture at a support wall" % label)
	var station := xf.origin.z if across_x else xf.origin.x
	var start := long_span * 0.15
	var finish := long_span * 0.85
	var along := station - (room.position.y if across_x else room.position.x)
	if along <= start or along >= finish:
		failures.append("%s tie is not placed inside the hall run" % label)

	# Check the actual wall triangles at both supports. Removing the triangles
	# intersecting a support ray must remove the contact evidence.
	var walls := MeshProbe.surface_triangles(builder, shell, HouseBuilder.SURF_WALL)
	if walls.is_empty():
		failures.append("%s builder emitted no wall triangles at the tie supports" % label)
		return
	for side in [-1.0, 1.0]:
		var ray := _support_ray(room, xf.origin, across_x, side, wall_t)
		if not MeshProbe.ray_blocked(walls, ray[0], ray[1]):
			failures.append("%s tie support ray misses the actual wall mesh" % label)
			continue
		var stripped: Dictionary = MeshProbe.remove_triangles(shell, HouseBuilder.SURF_WALL,
			func(a: Vector3, b: Vector3, c: Vector3) -> bool:
				return MeshProbe.ray_blocked([[a, b, c]], ray[0], ray[1]))
		var stripped_mesh: ArrayMesh = stripped.get("mesh")
		if int(stripped.get("removed_triangles", 0)) < 1:
			failures.append("%s support-ray negative removed no wall triangles" % label)
		else:
			var remaining := MeshProbe.surface_triangles(null, stripped["mesh"], HouseBuilder.SURF_WALL)
			if MeshProbe.ray_blocked(remaining, ray[0], ray[1]):
				failures.append("%s support ray remains blocked after its wall triangles are removed" % label)
		if stripped_mesh != null:
			stripped_mesh.clear_surfaces()


func _tie_conflicts_with_aperture(plan: HousePlan, room: Rect2, center: Vector3,
		size: Vector3, across_x: bool, tie_bottom: float, tie_top: float) -> bool:
	var openings: Array = []
	openings.append_array(plan.doors)
	openings.append_array(plan.windows)
	var wall_t: float = HouseGeometry.wall_thickness(plan.spec)
	var level := int(floor(center.y / maxf(plan.spec.height, 0.01)))
	var actual_conflict := HouseBuilder._witch_tie_conflicts_with_aperture(room,
		Vector2(center.x, center.z), size, across_x, tie_bottom, tie_top,
		openings, wall_t, level, float(level) * plan.spec.height)
	var lifted_opening: Dictionary
	if across_x:
		lifted_opening = {"pos": Vector2(room.position.x, center.z),
			"normal": Vector2(-1, 0), "w": size.z + 0.20,
			"bottom": tie_bottom - 0.02, "top": tie_top + 0.02, "level": level}
	else:
		lifted_opening = {"pos": Vector2(center.x, room.position.y),
			"normal": Vector2(0, -1), "w": size.x + 0.20,
			"bottom": tie_bottom - 0.02, "top": tie_top + 0.02, "level": level}
	if not HouseBuilder._witch_tie_conflicts_with_aperture(room, Vector2(center.x, center.z),
			size, across_x, tie_bottom, tie_top, [lifted_opening], wall_t, level):
		failures.append("lifted support-wall opening negative did not reject the tie")
	var below_opening: Dictionary = lifted_opening.duplicate(true)
	below_opening["top"] = tie_bottom - 0.01
	if HouseBuilder._witch_tie_conflicts_with_aperture(room, Vector2(center.x, center.z),
			size, across_x, tie_bottom, tie_top, [below_opening], wall_t, level):
		failures.append("opening below the tie was falsely reported as a conflict")
	var upper: Dictionary = lifted_opening.duplicate(true)
	upper.erase("bottom")
	upper.erase("top")
	upper["level"] = level + 1
	upper["sill"] = tie_bottom - float(level) * plan.spec.height - 0.02
	upper["head"] = tie_top - float(level) * plan.spec.height + 0.02
	if not HouseBuilder._witch_tie_conflicts_with_aperture(room, Vector2(center.x, center.z),
			size, across_x, tie_bottom + plan.spec.height, tie_top + plan.spec.height,
			[upper], wall_t, level + 1, float(level + 1) * plan.spec.height):
		failures.append("upper-storey local opening head failed to exclude a ceiling tie")
	return actual_conflict

func _support_ray(room: Rect2, center: Vector3, across_x: bool, side: float,
		wall_t: float) -> Array[Vector3]:
	var inside := center
	var outside := center
	var reach := wall_t * 0.8 + 0.04
	if across_x:
		inside.x = room.position.x + room.size.x * (0.5 + side * 0.5) - side * 0.05
		outside.x = inside.x + side * reach
	else:
		inside.z = room.position.y + room.size.y * (0.5 + side * 0.5) - side * 0.05
		outside.z = inside.z + side * reach
	return [inside, outside]


func _check_control(style: StringName, trade: StringName, expect_ties: bool) -> void:
	var size: Dictionary = CASES[1]
	var plan := HouseGenerator.generate(_spec(style, trade, size), 8102, false)
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var ties := _roles(builder, "witch_hall_ceiling_tie")
	if (not ties.is_empty()) != expect_ties:
		failures.append("%s/%s inherited ordinary Witch ceiling ties" % [String(style), String(trade)])


func _check_world_control() -> void:
	var size: Dictionary = CASES[1]
	var plan := HouseGenerator.generate(_spec(&"witch_hut", &"none", size), 8102, true)
	plan.world_family = &"village"
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	if not _roles(builder, "witch_hall_ceiling_tie").is_empty():
		failures.append("world-family Witch inherited ordinary-house ceiling ties")


func _roles(builder: HouseBuilder, wanted: String) -> Array:
	var result: Array = []
	for row in builder.component_log:
		if String(row.get("role", "")) == wanted:
			result.append(row)
	return result
