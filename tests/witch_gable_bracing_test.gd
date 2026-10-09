extends SceneTree
## Structural contract for the Witch's asymmetric gable braces.
## Run against the staged HouseBuilder proposal, not as a visual acceptance proxy.

const CASES := [
	{"id": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"id": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"id": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
var failures: Array[String] = []

func _init() -> void:
	for size in CASES:
		_check_witch(size)
	_check_non_witch_control(&"cottage", &"none", false)
	_check_non_witch_control(&"witch_hut", &"alchemist", false)
	_check_world_control()
	for failure in failures:
		printerr("FAIL " + failure)
	print("Witch asymmetric gable structural fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _retained_stations(layout: Dictionary) -> Array[float]:
	var result: Array[float] = []
	var along := float(layout.get("along", 0.0))
	var station_offset := along * 0.5 + HouseGeometry.BEAM_D * 0.5 - 0.01
	var bay: Dictionary = layout.get("witch_bay", {})
	for end_sign in [-1.0, 1.0]:
		var station := float(end_sign) * station_offset
		if bay.is_empty() or station < float(bay.get("along_lo", INF)) - 0.001 or station > float(bay.get("along_hi", -INF)) + 0.001:
			result.append(station)
	return result


func _rows_at_station(rows: Array, inverse: Transform3D, station: float) -> Array:
	var result: Array = []
	for row in rows:
		var xf: Transform3D = row["xf"]
		var local := inverse * xf.origin
		if absf(local.z - station) <= 0.025:
			result.append(row)
	return result


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
	# This is the legacy asymmetric-gable bracing test. Generated built-in Witch
	# plans now resolve to an upper half-hip and have their own measured end-frame
	# contact fixture; pin this fixture to its stated gable contract explicitly.
	plan.spec.roof_type = &"gable"
	var label := "witch/%s/8102" % String(size["id"])
	if not HouseGeometry.uses_witch_asymmetric_roof(plan.spec, plan.world_family):
		failures.append("%s did not select the protected asymmetric roof path" % label)
		return
	var layout := HouseGeometry.roof_layout(plan)
	var retained := _retained_stations(layout)
	var builder := HouseBuilder.new()
	var shell := builder.build(plan, true)
	var components: Dictionary = _roles(builder, "witch_gable_raking_brace")
	var braces: Array = components.get("witch_gable_raking_brace", [])
	var collars: Array = components.get("witch_collar", [])
	var rafters: Array = components.get("witch_rafter", [])
	if braces.size() != retained.size() * 2:
		failures.append("%s emitted %d raking braces; %d actual gable stations require two each" % [label, braces.size(), retained.size()])
	if collars.size() != retained.size() or rafters.size() != retained.size() * 2:
		failures.append("%s lost retained-end collar or principal-rafter supports" % label)
	var roof_transform: Transform3D = layout["transform"]
	var inverse := roof_transform.affine_inverse()
	for station in retained:
		var station_braces := _rows_at_station(braces, inverse, station)
		var station_collars := _rows_at_station(collars, inverse, station)
		var station_rafters := _rows_at_station(rafters, inverse, station)
		if station_braces.size() != 2 or station_collars.size() != 1 or station_rafters.size() != 2:
			failures.append("%s retained gable station %.3f has brace/collar/rafter=%d/%d/%d; expected 2/1/2" % [label, station, station_braces.size(), station_collars.size(), station_rafters.size()])
			continue
		var lengths := [float(station_braces[0]["size"].x), float(station_braces[1]["size"].x)]
		if absf(lengths[0] - lengths[1]) < 0.05:
			failures.append("%s retained gable station %.3f braces do not express unequal measured roof runs" % [label, station])
	for brace in braces:
		if String(brace.get("host", "")) != "roof":
			failures.append("%s raking brace is not hosted by the emitted main roof" % label)
		if not _brace_bears_on_collar_and_rafter(brace, collars, rafters):
			failures.append("%s brace lacks measured collar and principal-rafter contact" % label)
		var displaced: Dictionary = brace.duplicate(true)
		var displaced_xf: Transform3D = displaced["xf"]
		var brace_depth: float = Vector3(brace["size"]).z
		var support_depth := 0.0
		for support in collars + rafters:
			support_depth = maxf(support_depth, Vector3(support["size"]).z)
		displaced_xf.origin += displaced_xf.basis.z.normalized() * ((brace_depth + support_depth) * 0.5 + 0.02)
		displaced["xf"] = displaced_xf
		if _brace_bears_on_collar_and_rafter(displaced, collars, rafters):
			failures.append("%s displaced-brace negative still found structural contacts" % label)
	var parity: Dictionary = ComponentCheck.check(builder, shell)
	if not bool(parity.get("ok", false)):
		failures.append("%s emitted gable components do not match the committed mesh: %s" % [
			label, str(parity.get("failures", []))])
	shell.clear_surfaces()


func _check_non_witch_control(style: StringName, trade: StringName, expect_braces: bool) -> void:
	var size: Dictionary = CASES[1]
	var plan := HouseGenerator.generate(_spec(style, trade, size), 8102, false)
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var braces: Array = _roles(builder, "witch_gable_raking_brace").get("witch_gable_raking_brace", [])
	if (not braces.is_empty()) != expect_braces:
		failures.append("%s/%s inherited Witch-only gable braces" % [String(style), String(trade)])


func _check_world_control() -> void:
	var size: Dictionary = CASES[1]
	var plan := HouseGenerator.generate(_spec(&"witch_hut", &"none", size), 8102, true)
	plan.world_family = &"village"
	plan.spec.roof_type = &"gable"
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var braces: Array = _roles(builder, "witch_gable_raking_brace").get("witch_gable_raking_brace", [])
	if not braces.is_empty():
		failures.append("world-family Witch plan inherited the ordinary-house gable brace treatment")


func _roles(builder: HouseBuilder, prefix: String) -> Dictionary:
	var result := {}
	for row in builder.component_log:
		var role := String(row.get("role", ""))
		if role == prefix or role in ["witch_collar", "witch_rafter"]:
			var values: Array = result.get(role, [])
			values.append(row)
			result[role] = values
	return result


func _brace_bears_on_collar_and_rafter(brace: Dictionary, collars: Array,
		rafters: Array) -> bool:
	var brace_xf: Transform3D = brace["xf"]
	var plane_normal := brace_xf.basis.z.normalized()
	var touches_collar := false
	var touches_rafter := false
	for collar in collars:
		var collar_xf: Transform3D = collar["xf"]
		if absf((collar_xf.origin - brace_xf.origin).dot(plane_normal)) <= 0.002 \
				and _member_centerlines_touch(brace, collar, 0.01):
			touches_collar = true
	for rafter in rafters:
		var rafter_xf: Transform3D = rafter["xf"]
		if absf((rafter_xf.origin - brace_xf.origin).dot(plane_normal)) <= 0.002 \
				and _member_centerlines_touch(brace, rafter, 0.01):
			touches_rafter = true
	return touches_collar and touches_rafter


func _member_centerlines_touch(first: Dictionary, second: Dictionary,
		tolerance: float) -> bool:
	var first_start := _member_endpoint(first, -1.0)
	var first_end := _member_endpoint(first, 1.0)
	return _point_segment_distance(first_start, second) <= tolerance \
			or _point_segment_distance(first_end, second) <= tolerance


func _member_endpoint(row: Dictionary, direction: float) -> Vector3:
	var xf: Transform3D = row["xf"]
	var size: Vector3 = row["size"]
	return xf.origin + xf.basis.x.normalized() * size.x * 0.5 * direction


func _point_segment_distance(point: Vector3, row: Dictionary) -> float:
	var a := _member_endpoint(row, -1.0)
	var b := _member_endpoint(row, 1.0)
	var segment := b - a
	var t := clampf((point - a).dot(segment) / maxf(segment.length_squared(), 1e-8), 0.0, 1.0)
	return point.distance_to(a + segment * t)
