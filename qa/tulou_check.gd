class_name TulouCheck
extends RefCounted
## Structural rules for the Hakka clan ring (WLD-010).

const RULES: Array[StringName] = [&"ring", &"thickness", &"blind",
	&"inward", &"equal", &"centre", &"stairs", &"storeys"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(plan: HousePlan, builder: TulouBuilder = null) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	for rule in RULES:
		call("_check_%s" % String(rule), plan, builder)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


func _check_ring(plan: HousePlan, builder: TulouBuilder) -> void:
	var levels := int(plan.world_meta.get("storeys", 0))
	var expected := levels * int(plan.world_meta.get("wall_segments", 96))
	var emitted := 0
	if builder != null:
		var angles_by_level: Dictionary = {}
		for component in builder.component_log:
			if component.get("host", "").begins_with("outer_wall"):
				emitted += 1
				var points: PackedVector3Array = component.get("points", PackedVector3Array())
				if points.size() >= 2:
					var angle := wrapf(Vector2(points[0].x, points[0].z).angle(), 0.0, TAU)
					var level := int(component.get("storey", -1))
					if not angles_by_level.has(level):
						angles_by_level[level] = []
					angles_by_level[level].append(angle)
		# The two missing lower panels are the intentional gate aperture.
		if emitted != expected - 2:
			failures.append("ring: outer wall emitted %d of %d required segments" %
				[emitted, expected - 2])
		for level2 in range(levels):
			var angles: Array = angles_by_level.get(level2, [])
			angles.sort()
			var large_gaps := 0
			for i in range(angles.size()):
				var next := float(angles[(i + 1) % angles.size()])
				var gap := wrapf(next - float(angles[i]), 0.0, TAU)
				if level2 == 0 and absf(gap - TAU * 3.0 / 96.0) < 0.002:
					large_gaps += 1
				elif absf(gap - TAU / 96.0) > 0.002:
					large_gaps += 2
			if (level2 == 0 and large_gaps != 1) or (level2 > 0 and large_gaps != 0):
				failures.append("ring: emitted wall segments do not form a closed storey %d ring" % level2)
	var closed := bool(plan.world_meta.get("ring_closed", false))
	if not closed:
		failures.append("ring: outer wall polygon is not a closed loop")
	stats["outer_wall_segments"] = emitted


func _check_thickness(plan: HousePlan, builder: TulouBuilder) -> void:
	var ground := float(plan.world_meta.get("wall_ground_thickness", 0.0))
	var top := float(plan.world_meta.get("wall_top_thickness", 0.0))
	if builder != null:
		var depths: Array[float] = []
		for component in builder.component_log:
			if String(component.get("host", "")) == "outer_wall":
				depths.append(float(component.get("depth", 0.0)))
		if not depths.is_empty():
			ground = depths[0]
			top = depths[0]
			for depth in depths:
				ground = maxf(ground, depth)
				top = minf(top, depth)
	if ground < 1.2:
		failures.append("thickness: ground wall is %.2fm, below 1.2m" % ground)
	if top <= 0.0 or ground < top * 1.4:
		failures.append("thickness: ground wall is not at least 1.4x the crown")


func _check_blind(plan: HousePlan, builder: TulouBuilder) -> void:
	var gates: Array[Dictionary] = []
	for door in plan.doors:
		if String(door.get("role", "")) == "main_gate":
			gates.append(door)
	var axis: Vector2 = plan.world_meta.get("gate_axis", Vector2.ZERO)
	var aligned := not gates.is_empty() and axis.length_squared() > 0.9
	if aligned:
		aligned = absf(Vector2(gates[0]["normal"]).normalized().dot(axis.normalized())) > 0.98
	var low_windows := 0
	for window in plan.windows:
		if HousePlan.record_storey(window) < 3 and bool(window.get("outer_wall", true)):
			low_windows += 1
	if low_windows > 0 or gates.size() > 2 or gates.size() != 1 or not aligned:
		failures.append("blind: outer wall below storey 3 must be blind except one axial gate")
	if builder != null:
		var outer_by_storey: Dictionary = {}
		for component in builder.component_log:
			if String(component.get("host", "")) == "outer_wall":
				var level := int(component.get("storey", -1))
				outer_by_storey[level] = int(outer_by_storey.get(level, 0)) + 1
		for level2 in range(int(plan.world_meta.get("storeys", 0))):
			var wanted := int(plan.world_meta.get("wall_segments", 96))
			if level2 == 0:
				wanted -= 2 # the only permitted opening: the main gate
			if int(outer_by_storey.get(level2, 0)) != wanted:
				failures.append("blind: emitted outer wall has an unpermitted opening on storey %d" % level2)
	stats["low_outer_windows"] = low_windows
	stats["gates"] = gates.size()


func _check_inward(plan: HousePlan, builder: TulouBuilder) -> void:
	var expected_rooms := int(plan.world_meta.get("room_count_per_storey", 0)) * int(plan.world_meta.get("storeys", 0))
	var found := 0
	var inward := 0
	for i in range(plan.rooms.size()):
		if String(plan.rooms[i].get("role", "")) != "clan_room":
			continue
		found += 1
		var doors := 0
		for door_index in plan.doors_of(i):
			var door: Dictionary = plan.doors[door_index]
			if String(door.get("role", "")) != "inward_clan_door":
				continue
			doors += 1
			var gallery := int(door.get("b", -1))
			var normal: Vector2 = door.get("normal", Vector2.ZERO)
			var point: Vector2 = door.get("pos", Vector2.ZERO)
			if gallery >= 0 and String(plan.rooms[gallery].get("role", "")) == "gallery" \
					and normal.normalized().dot(-point.normalized()) > 0.95:
				inward += 1
		if doors != 1:
			failures.append("inward: clan room %d has %d inward gallery doors, expected one" % [i, doors])
	var galleries := 0
	for room in plan.rooms:
		if String(room.get("role", "")) == "gallery":
			galleries += 1
	if found != expected_rooms or galleries != int(plan.world_meta.get("storeys", 0)) \
			or not bool(plan.world_meta.get("gallery_open", false)):
		failures.append("inward: rooms or continuous gallery rings are missing")
	if inward != expected_rooms:
		failures.append("inward: %d of %d clan doors face the centre" % [inward, expected_rooms])
	if builder != null:
		var floor_angles: Dictionary = {}
		for component in builder.component_log:
			if String(component.get("host", "")).begins_with("gallery_floor_"):
				var points: PackedVector3Array = component.get("points", PackedVector3Array())
				if points.size() < 3:
					continue
				var p: Vector3 = points[1]
				var angle := wrapf(Vector2(p.x, p.z).angle(), 0.0, TAU)
				var level := int(component.get("storey", -1))
				if not floor_angles.has(level):
					floor_angles[level] = []
				floor_angles[level].append(angle)
		for level2 in range(int(plan.world_meta.get("storeys", 0))):
			var angles: Array = floor_angles.get(level2, [])
			angles.sort()
			var closed := angles.size() == int(plan.world_meta.get("wall_segments", 96))
			for i in range(angles.size()):
				var next := float(angles[(i + 1) % angles.size()])
				var gap := wrapf(next - float(angles[i]), 0.0, TAU)
				if absf(gap - TAU / 96.0) > 0.002:
					closed = false
			if not closed:
				failures.append("inward: gallery floor storey %d does not flood the full circle" % level2)
	stats["clan_rooms"] = found
	stats["gallery_rings"] = galleries


func _check_equal(plan: HousePlan, _builder: TulouBuilder) -> void:
	var expected := int(plan.world_meta.get("room_count_per_storey", 0))
	var counts: Dictionary = {}
	var widths: Array[float] = []
	for room in plan.rooms:
		if String(room.get("role", "")) != "clan_room":
			continue
		var level := HousePlan.record_storey(room)
		counts[level] = int(counts.get(level, 0)) + 1
		widths.append(float(room.get("width", 0.0)))
	var mean := 0.0
	for width in widths:
		mean += float(width)
	mean /= maxf(float(widths.size()), 1.0)
	var deviation := 0.0
	for width2 in widths:
		deviation = maxf(deviation, absf(float(width2) - mean) / maxf(mean, 0.001))
	if counts.size() != int(plan.world_meta.get("storeys", 0)) or deviation > 0.05:
		failures.append("equal: room count differs by storey or widths vary over 5 percent")
	for level2 in counts:
		if int(counts[level2]) != expected:
			failures.append("equal: storey %d has %d rooms, expected %d" % [level2, counts[level2], expected])
	stats["maximum_width_deviation"] = deviation


func _check_centre(plan: HousePlan, builder: TulouBuilder) -> void:
	var hall := -1
	for i in range(plan.rooms.size()):
		if String(plan.rooms[i].get("role", "")) == "ancestral_hall":
			hall = i
			break
	if hall < 0 or plan.courts.is_empty():
		failures.append("centre: central ancestral hall or open court is missing")
		return
	var rect: Rect2 = plan.rooms[hall]["rect"]
	if rect.get_center().length() > 0.02:
		failures.append("centre: ancestral hall is offset from the centre")
	# Reuse CourtCheck's sky rule for the court. Tulou roofs are annular, with
	# no emitted roof component inside the court's bounds.
	var court := CourtCheck.new()
	court._check_sky(plan)
	for failure in court.failures:
		failures.append("centre: %s" % failure)
	if builder != null:
		for component in builder.component_log:
			if String(component.get("host", "")) != "roof_ring":
				continue
			var points: PackedVector3Array = component.get("points", PackedVector3Array())
			for point in points:
				if Vector2(point.x, point.z).length() < float(plan.world_meta.get("gallery_inner_radius", 0.0)) - 0.01:
					failures.append("centre: roof ring intrudes into the open ancestral court")
					return


func _check_stairs(plan: HousePlan, _builder: TulouBuilder) -> void:
	var angles: Array[float] = []
	for stair in plan.stairs:
		var index := int(stair.get("index", -1))
		var angle := TAU * float(index) / maxf(float(plan.world_meta.get("stair_count", 1)), 1.0)
		if index >= 0 and not angles.has(angle):
			angles.append(angle)
	angles.sort()
	var count := int(plan.world_meta.get("stair_count", 0))
	var target := TAU / maxf(float(count), 1.0)
	var ok := count >= 2 and angles.size() == count
	for i in range(angles.size()):
		var gap := wrapf(angles[(i + 1) % angles.size()] - angles[i], 0.0, TAU)
		if absf(gap - target) > deg_to_rad(15.0):
			ok = false
	if not ok:
		failures.append("stairs: fewer than two stairs or spacing exceeds 15 degrees")
	stats["stair_positions"] = angles.size()


func _check_storeys(plan: HousePlan, _builder: TulouBuilder) -> void:
	var levels := int(plan.world_meta.get("storeys", 0))
	if levels < 3 or levels > 5 or spec_height(plan) <= 0.0:
		failures.append("storeys: tulou must have three to five usable storeys")
	stats["storeys"] = levels


static func spec_height(plan: HousePlan) -> float:
	return plan.spec.height * float(plan.spec.storeys)


static func negative_controls() -> Array[String]:
	var out: Array[String] = []
	for rule in RULES:
		var clone := TulouGenerator.generate(60710, 60.0, 60.0, 15.0, 4)
		var test_plan: HousePlan = clone["plan"]
		match rule:
			&"ring":
				test_plan.world_meta["ring_closed"] = false
			&"thickness":
				test_plan.world_meta["wall_ground_thickness"] = 0.8
			&"blind":
				test_plan.windows.append({"room": 0, "storey": 0, "outer_wall": true})
			&"inward":
				test_plan.doors.erase(0)
			&"equal":
				test_plan.rooms[1]["width"] = float(test_plan.rooms[1]["width"]) * 1.2
			&"centre":
				test_plan.rooms.erase(int(test_plan.world_meta["hall_room"]))
			&"stairs":
				test_plan.world_meta["stair_count"] = 1
			&"storeys":
				test_plan.world_meta["storeys"] = 2
		var report: Dictionary = TulouCheck.new().check(test_plan)
		var caught := false
		for failure in report["failures"]:
			if String(failure).begins_with(String(rule) + ":"):
				caught = true
		if not caught:
			out.append("negative control %s was not caught" % String(rule))
	return out
