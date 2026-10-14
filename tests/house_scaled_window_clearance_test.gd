extends SceneTree
## The daylight rule must measure the placed model's vertical scale.

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		_check_pose(yaw)
	for failure in failures:
		printerr("FAIL ", failure)
	print("Scaled window clearance: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_pose(yaw: float) -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [{"kind": &"kitchen", "storey": 0,
		"rect": Rect2(-2, -2, 4, 4)}]
	var inward := Vector2(-sin(yaw), -cos(yaw))
	var wall_point := -inward * 2.0
	plan.windows = [{"room": 0, "storey": 0, "pos": wall_point,
		"normal": -inward, "width": 1.4, "sill": 0.95, "head": 2.0}]
	var centre := wall_point + inward * (PropCatalog.footprint("Cabinet").y * 0.8 * 0.5 + 0.06)
	var item := HouseFurnishGeometry.candidate("Cabinet", centre, yaw, 1.0, 0.8)
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	HouseFurnishGeometry.commit(plan, 0, item, blocked, zones)
	_expect(HouseGeometry.window_clear_rect(plan.windows[0]).intersection(item["rect"]).get_area() > 0.03,
		"cabinet fixture does not stand across its window")
	var model := HouseAssembler._instance(plan.furniture[0], true)
	var bounds := SceneBounds.of_node(model)
	_expect(bounds.end.y < 0.95, "shrunken imported cabinet actually blocks the sill")
	model.free()
	var low := HouseFurnishPhysicalCheck.new()
	low.check_windows(plan)
	_expect(low.failures.is_empty(), "rule treated a shrunken cabinet as full height")
	# Keep its footprint but restore the full vertical model. The negative is
	# an actual geometry change, not an exemption flag or altered catalogue.
	plan.furniture[0]["height_scale"] = 1.0
	var raised := HouseAssembler._instance(plan.furniture[0], true)
	_expect(SceneBounds.of_node(raised).end.y > 0.95, "full-height control never crosses the sill")
	raised.free()
	var tall := HouseFurnishPhysicalCheck.new()
	tall.check_windows(plan)
	_expect(not tall.failures.is_empty(), "full vertical scale escaped the daylight rule")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
