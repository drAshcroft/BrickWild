extends SceneTree
## Artifact-only focused controls for a metric, closed floor-edge tolerance.

var failures: Array[String] = []


func _initialize() -> void:
	_check_split_floor_seam(Vector2(-2.0, -3.9), 0.00002, "local")
	_check_split_floor_seam(Vector2(498.0, -503.9), 0.00003, "translated_500m")
	_check_real_gap_remains_open()
	_check_pit_remains_open()
	_check_obstacle_remains_blocking()
	_check_step_remains_blocking()
	for failure in failures:
		push_error(failure)
	print("walkgrid closed-edge fixture: 6 controls, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_split_floor_seam(origin: Vector2, seam_gap: float, label: String) -> void:
	var grid := WalkGrid.new()
	grid.setup(Rect2(origin, Vector2(4.0, 8.0)), 0.12)
	var x0: float = origin.x + 1.0
	grid.add_floor(Rect2(Vector2(x0, origin.y + 0.9), Vector2(2.0, 3.0)))
	grid.add_floor(Rect2(Vector2(x0, origin.y + 3.9 + seam_gap),
		Vector2(2.0, 3.0 - seam_gap)))
	grid.build(0.25)
	var start := Vector2(x0 + 1.0, origin.y + 1.9)
	if not grid.flood_from(start, 0.6):
		_fail("%s split floor has no valid route start" % label)
		return
	var requested := Vector2(x0 + 1.0, origin.y + 3.9)
	var cell := grid.cell_of(requested)
	var center: Vector2 = grid.world_of(cell.x, cell.y)
	if absf(center.y - (origin.y + 3.9)) > 0.001:
		_fail("%s seam witness cell centre %s is not actually on the split edge" % [label, center])
	if grid.at(grid._free, cell.x, cell.y) != 1 \
			or grid.at(grid._walk, cell.x, cell.y) != 1 \
			or grid.at(grid._seen, cell.x, cell.y) != 1:
		_fail("%s shared floor edge at %s is not body-walkable and reached (center %s)" % [label, requested, center])
	var far := grid.cell_of(Vector2(center.x, origin.y + 5.0))
	if grid.at(grid._seen, far.x, far.y) != 1:
		_fail("%s route did not continue onto the far side of the floor seam" % label)


func _check_real_gap_remains_open() -> void:
	var origin := Vector2(-2.0, -3.8995)
	var grid := WalkGrid.new()
	grid.setup(Rect2(origin, Vector2(4.0, 8.0)), 0.12)
	var x0: float = origin.x + 1.0
	grid.add_floor(Rect2(Vector2(x0, -3.0), Vector2(2.0, 3.0)))
	grid.add_floor(Rect2(Vector2(x0, 0.001), Vector2(2.0, 2.999)))
	grid.build(0.25)
	var cell := grid.cell_of(Vector2(x0 + 1.0, 0.0005))
	var center: Vector2 = grid.world_of(cell.x, cell.y)
	if absf(center.y - 0.0005) > 0.000001:
		_fail("1 mm gap negative does not sample its actual midpoint: %s" % center)
	if grid.at(grid._free, cell.x, cell.y) != 0:
		_fail("1 mm physical floor gap was closed by the metric edge tolerance")


func _check_pit_remains_open() -> void:
	var grid := WalkGrid.new()
	grid.setup(Rect2(Vector2(-2.0, -3.9), Vector2(4.0, 8.0)), 0.12)
	grid.add_floor(Rect2(Vector2(-1.0, -3.0), Vector2(2.0, 2.6)))
	grid.add_floor(Rect2(Vector2(-1.0, 0.4), Vector2(2.0, 2.6)))
	grid.build(0.25)
	var cell := grid.cell_of(Vector2(0.0, 0.0))
	if grid.at(grid._free, cell.x, cell.y) != 0 or grid.at(grid._walk, cell.x, cell.y) != 0:
		_fail("Rotunda pit floor cut was filled by the closed-edge tolerance")


func _check_obstacle_remains_blocking() -> void:
	var grid := WalkGrid.new()
	grid.setup(Rect2(Vector2(-2.0, -3.9), Vector2(4.0, 8.0)), 0.12)
	grid.add_floor(Rect2(Vector2(-1.0, -3.0), Vector2(2.0, 6.0)))
	grid.add_obstacle(Rect2(Vector2(-1.0, -0.24), Vector2(2.0, 0.48)))
	grid.build(0.25)
	grid.flood_from(Vector2(0.0, -2.0), 0.6)
	var cell := grid.cell_of(Vector2(0.0, 0.0))
	if grid.at(grid._free, cell.x, cell.y) != 0 or grid.at(grid._seen, cell.x, cell.y) != 0:
		_fail("real obstacle across the corridor was bridged as a floor seam")


func _check_step_remains_blocking() -> void:
	var origin := Vector2(-2.0, -3.9)
	var grid := WalkGrid.new()
	grid.setup(Rect2(origin, Vector2(4.0, 8.0)), 0.12)
	grid.add_floor(Rect2(Vector2(-1.0, -3.0), Vector2(2.0, 3.0)), 0.0)
	grid.add_floor(Rect2(Vector2(-1.0, 0.00002), Vector2(2.0, 2.99998)), 2.0)
	grid.build(0.25)
	if not grid.flood_from(Vector2(0.0, -2.0), 0.6):
		_fail("2 m rise control has no reachable lower floor")
		return
	var upper := grid.cell_of(Vector2(0.0, 0.6))
	if grid.at(grid._free, upper.x, upper.y) != 1 \
			or grid.at(grid._walk, upper.x, upper.y) != 1 \
			or grid.at(grid._seen, upper.x, upper.y) != 0:
		_fail("closed-edge floor coverage bridged a real 2 m rise beyond MAX_STEP")


func _fail(message: String) -> void:
	failures.append(message)
