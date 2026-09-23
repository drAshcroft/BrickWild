extends SceneTree
## Actual edge geometry must survive polygon vertex ordering and winding.

var result := SuiteResult.new("polygon affinity")

func _init() -> void:
	for count in [4, 8, 14]:
		for reverse in [false, true]:
			var plan := _plan(count, reverse)
			var walls := HouseGeometry.room_walls(plan, 0)
			var lit: int = int(count) - 2
			var blind: int = int(count) - 1
			var window_wall: Dictionary = walls[lit]
			plan.windows = [{"room": 0, "storey": 0, "pos": (Vector2(window_wall.from) + Vector2(window_wall.to)) * 0.5,
				"normal": -Vector2(window_wall.normal), "width": 1.0, "sill": 0.95, "head": 2.0}]
			plan.hearth = {"room": 0, "wall": blind}
			var bed := PropCatalog.of_category("bed")[0]
			var good := _piece(plan, bed, blind)
			var bad := _piece(plan, bed, lit)
			_expect(HouseFurnisher._affinity(plan, 0, good) > HouseFurnisher._affinity(plan, 0, bad), "blind bed wall loses affinity")
			plan.furniture = [good]
			var checker := HouseFurnishCheck.new()
			checker._check_bed_window(plan)
			_expect(checker.failures.is_empty(), "blind headboard rejected: " + str(checker.failures))
			plan.furniture = [bad]
			checker = HouseFurnishCheck.new()
			checker._check_bed_window(plan)
			_expect(not checker.failures.is_empty(), "glazed headboard mutation accepted")
			var bookcase := PropCatalog.of_category("bookcase")[0]
			plan.furniture = [_piece(plan, bookcase, blind)]
			checker = HouseFurnishCheck.new()
			checker._check_bookcase_heat(plan)
			_expect(not checker.failures.is_empty(), "bookcase/fireplace mutation accepted")
			var bench := _piece(plan, PropCatalog.of_category("workbench")[0], blind)
			var shelf := _piece(plan, PropCatalog.of_category("shelf")[0], blind, true)
			plan.furniture = [bench, shelf]
			checker = HouseFurnishCheck.new()
			checker._check_shelf_over(plan)
			_expect(checker.failures.is_empty() and checker.warnings.is_empty(), "shelf above oblique bench rejected: " + str(checker.failures))
			var over := HouseFurnisher._over_bonus(plan, 0, shelf, ["workbench"])
			plan.furniture[1] = _piece(plan, shelf.key, lit, true)
			_expect(over > HouseFurnisher._over_bonus(plan, 0, plan.furniture[1], ["workbench"]), "shelf misplaced affinity unchanged")
			checker = HouseFurnishCheck.new()
			checker._check_shelf_over(plan)
			_expect(not checker.failures.is_empty(), "shelf moved off host accepted")
	_backing_precision()
	_square_invariance()
	preload("res://tests/suites/polygon_sconce_suite.gd")._synthetic(result)
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)

func _expect(ok: bool, message: String) -> void:
	result.checked += 1
	if not ok:
		result.fail(message)

func _plan(count: int, reverse: bool) -> HousePlan:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new(42)
	plan.spec.width = 28
	plan.spec.length = 28
	plan.spec.height = 3
	plan.spec.material = &"stone"
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float((i + 2) % count) / count + PI / count
		points.append(Vector2(cos(angle), sin(angle)) * 14)
	if reverse:
		points.reverse()
	plan.rooms = [{"kind": &"workshop", "rect": Poly.bounding_rect(points), "outline": points, "storey": 0}]
	return plan

func _piece(plan: HousePlan, key: String, wall_index: int, mounted := false) -> Dictionary:
	var wall: Dictionary = HouseGeometry.room_walls(plan, 0)[wall_index]
	var normal: Vector2 = wall.normal
	var yaw := atan2(-normal.x, -normal.y)
	var center := (Vector2(wall.from) + Vector2(wall.to)) * 0.5
	if not mounted:
		center += normal * (PropCatalog.footprint(key).y * 0.5 + HouseGeometry.WALL_GAP)
	var size := Vector2.ONE * 0.1 if mounted else PropCatalog.footprint_rotated(key, yaw)
	return {"key": key, "room": 0, "storey": 0, "rect": Rect2(center - size * 0.5, size),
		"pos": Vector3(center.x, 1.6 if mounted else 0, center.y), "yaw": yaw,
		"zone": Rect2(), "host": -1, "mounted": mounted, "scale": 1.0}

func _square_invariance() -> void:
	var rectangle := HousePlan.new()
	rectangle.spec = HouseSpec.new()
	rectangle.spec.width = 14
	rectangle.spec.length = 14
	var floor_rect := HouseGeometry.interior_rect(rectangle.spec)
	rectangle.rooms = [{"kind": &"workshop", "rect": floor_rect, "storey": 0}]
	rectangle.windows = [{"room": 0, "pos": Vector2(0, floor_rect.position.y), "normal": Vector2(0, -1), "width": 1.0, "sill": 0.95, "head": 2.0}]
	var key := PropCatalog.of_category("workbench")[0]
	var piece := _piece(rectangle, key, 0)
	var baseline := HouseFurnisher._affinity(rectangle, 0, piece)
	var points := PackedVector2Array([floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)])
	for reverse in [false, true]:
		for start in range(4):
			var outline := PackedVector2Array()
			for i in range(4):
				outline.append(points[(i + start) % 4])
			if reverse:
				outline.reverse()
			rectangle.rooms[0].outline = outline
			_expect(is_equal_approx(HouseFurnisher._affinity(rectangle, 0, piece), baseline), "square affinity changed with vertex order")
			rectangle.furniture = [piece]
			var checker := HouseFurnishCheck.new()
			checker._check_workbench_daylight(rectangle)
			_expect(checker.failures.is_empty(), "square daylight changed with vertex order")

## Vector2 coordinates are float32: an exactly authored tolerance boundary
## can round by nanometres. Two millimetres beyond it is still a defect.
func _backing_precision() -> void:
	var plan := _plan(14, false)
	var piece := _piece(plan, "Bed_Twin1", 5)
	var wall: Dictionary = HouseGeometry.room_walls(plan, 0)[5]
	var normal: Vector2 = wall.normal
	var inset := normal * HouseGeometry.BED_HEAD_TOL
	piece.rect.position += inset
	piece.pos += Vector3(inset.x, 0.0, inset.y)
	plan.furniture = [piece]
	var checker := HouseFurnishCheck.new()
	checker._check_against_wall(plan)
	_expect(checker.failures.is_empty(), "exact backing limit rejected by float32 roundoff")
	piece.rect.position += normal * 0.002
	piece.pos += Vector3(normal.x, 0.0, normal.y) * 0.002
	checker = HouseFurnishCheck.new()
	checker._check_against_wall(plan)
	_expect(not checker.failures.is_empty(), "bed two millimetres beyond backing limit accepted")
