class_name QiblaCheck
extends RefCounted
## Seven measurable claims for a hypostyle mosque (WLD-004).

const AISLE_TOLERANCE := 0.05
const GRID_MIN_AISLES := 9

func check(plan: HousePlan, builder: MosqueBuilder = null) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"columns": plan.columns.size()}
	if builder == null:
		builder = MosqueBuilder.new()
		builder.build(plan)
	_qibla(plan, builder, failures)
	_grid(plan, builder, failures)
	_sightline(plan, builder, failures)
	_sahn(plan, builder, failures)
	_minaret(plan, builder, failures)
	_rows(plan, builder, failures, stats)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": [], "stats": stats}


func _qibla(plan: HousePlan, builder: MosqueBuilder, failures: Array[String]) -> void:
	var wall: Rect2 = plan.world_meta.get("qibla_wall", Rect2())
	if not wall.has_area():
		failures.append("qibla: no flagged prayer wall")
		return
	for door in plan.doors:
		var p := Vector2(door.get("pos", Vector2(INF, INF)))
		if absf(p.y - wall.get_center().y) <= wall.size.y * 0.5 + 0.05 and wall.position.x <= p.x and p.x <= wall.end.x:
			failures.append("qibla: prayer wall has a door")
			break
	var niche: Rect2 = plan.world_meta.get("mihrab", Rect2())
	if not niche.has_area() or absf(niche.get_center().x - wall.get_center().x) > wall.size.x * 0.02:
		failures.append("qibla: mihrab is not centred on the wall")
	var wall_mass := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("qibla_wall"):
			wall_mass = true
			break
	if not wall_mass:
		failures.append("qibla: prayer wall was not emitted")
	var hall: Rect2 = plan.world_meta.get("hall_rect", Rect2())
	if wall.size.x < hall.size.x * 0.98 or wall.size.x < wall.size.y * 5.0 \
			or absf(wall.end.y - hall.end.y) > wall.size.y * 0.1:
		failures.append("qibla: prayer wall does not span the far end of the hall")


func _grid(plan: HousePlan, builder: MosqueBuilder, failures: Array[String]) -> void:
	var meta := plan.world_meta
	var aisles := int(meta.get("aisle_count", 0))
	var row_count := int(meta.get("row_count", 0))
	var hall: Rect2 = meta.get("hall_rect", Rect2())
	var pitch := float(meta.get("file_pitch", 0.0))
	var row_pitch := float(meta.get("row_pitch", 0.0))
	var centre := float(meta.get("central_aisle", 0.0))
	var qibla: Rect2 = meta.get("qibla_wall", Rect2())
	if aisles < GRID_MIN_AISLES or aisles % 2 != 1:
		failures.append("grid: aisle count %d is not odd and at least %d" % [aisles, GRID_MIN_AISLES])
	if row_count < 2 or pitch <= 0.0 or row_pitch <= 0.0:
		failures.append("grid: invalid row/file pitches")
		return
	if centre + 0.001 < pitch * 1.2:
		failures.append("grid: central aisle is narrower than 1.2 times a side aisle")
	if qibla.get_center().y <= hall.get_center().y:
		failures.append("grid: aisles do not run perpendicular to the qibla wall")
	var by_row: Dictionary = {}
	for column in plan.columns:
		var p: Vector3 = column.get("pos", Vector3(INF, INF, INF))
		if absf(p.x) < centre * 0.5 - 0.001:
			failures.append("grid: a column occupies the central aisle")
		var key := snappedf(p.z, row_pitch * 0.2)
		if not by_row.has(key):
			by_row[key] = []
		by_row[key].append(p.x)
		if p.z < hall.position.y or p.z > hall.end.y:
			failures.append("grid: column lies outside the hall")
	var rows_seen := 0
	for z_key in by_row:
		rows_seen += 1
		var xs: Array = by_row[z_key]
		xs.sort()
		if xs.size() < 4:
			failures.append("grid: column row has too few files")
			continue
		# The central aisle is a deliberate gap. Every remaining adjacent pair
		# must respect the common file pitch.
		for i in range(xs.size() - 1):
			var gap := float(xs[i + 1]) - float(xs[i])
			if float(xs[i]) < 0.0 and float(xs[i + 1]) > 0.0:
				continue # the intentionally widened central aisle
			if absf(gap - pitch) > AISLE_TOLERANCE * pitch:
				failures.append("grid: adjacent files differ from pitch by %.3fm" % absf(gap - pitch))
				break
		var left_half := xs.filter(func(x): return float(x) < 0.0)
		var right_half := xs.filter(func(x): return float(x) > 0.0)
		if left_half.size() != (aisles - 1) / 2 or right_half.size() != (aisles - 1) / 2:
			failures.append("grid: row is not symmetric around the central aisle")
	if rows_seen != row_count:
		failures.append("grid: expected %d column rows, found %d" % [row_count, rows_seen])
	if plan.columns.size() != row_count * (aisles - 1):
		failures.append("grid: column rows are incomplete")
	var emitted_columns := 0
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("column_"):
			emitted_columns += 1
	if emitted_columns != plan.columns.size():
		failures.append("grid: emitted %d columns for %d plan columns" % [emitted_columns, plan.columns.size()])
	# Each row advances toward the qibla wall (the wall normal is +/-Z).
	var zs: Array = by_row.keys()
	zs.sort()
	for i in range(zs.size() - 1):
		if absf(float(zs[i + 1]) - float(zs[i]) - row_pitch) > AISLE_TOLERANCE * row_pitch:
			failures.append("grid: rows do not follow the authored row pitch")
			break


func _sightline(plan: HousePlan, builder: MosqueBuilder, failures: Array[String]) -> void:
	var door := Vector2(plan.world_meta.get("sahn_door", Vector2(INF, INF)))
	var niche: Rect2 = plan.world_meta.get("mihrab", Rect2())
	var from := Vector3(door.x, 1.6, door.y)
	var to := Vector3(niche.get_center().x, 0.3 + plan.spec.height * 0.18 * 0.75, niche.position.y)
	var blockers: Array[AABB] = []
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name == "hall_floor" or name == "mihrab" or name.begins_with("qibla_wall"):
			continue # floor is below eye-height; niche wall is the target opening.
		blockers.append(mass["aabb"])
	if not Sightline.clear(from, to, blockers):
		failures.append("sightline: sahn door cannot see the mihrab down the central aisle")


func _sahn(plan: HousePlan, builder: MosqueBuilder, failures: Array[String]) -> void:
	var court_check := CourtCheck.new()
	court_check._check_sky(plan)
	for failure in court_check.failures:
		failures.append("sahn: %s" % failure)
	var water_report := court_check.water(plan)
	for failure in water_report["failures"]:
		failures.append("sahn: %s" % failure)
	var hall: Rect2 = plan.world_meta.get("hall_rect", Rect2())
	var sahn: Rect2 = plan.world_meta.get("sahn_rect", Rect2())
	if not sahn.has_area() or absf(sahn.get_center().x - hall.get_center().x) > hall.size.x * 0.01:
		failures.append("sahn: court does not share the hall axis")
	if plan.courts.is_empty() or Rect2(plan.courts[0].get("rect", Rect2())) != sahn:
		failures.append("sahn: court is not represented as open plan data")
	var floor_emitted := false
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		var a: AABB = mass["aabb"]
		if name == "sahn_floor":
			floor_emitted = true
		if name.begins_with("roof") and Rect2(Vector2(a.position.x, a.position.z),
				Vector2(a.size.x, a.size.z)).intersects(sahn):
			failures.append("sahn: emitted roof covers the open court")
	if not floor_emitted:
		failures.append("sahn: court floor was not emitted")


func _minaret(plan: HousePlan, builder: MosqueBuilder, failures: Array[String]) -> void:
	var hall: Rect2 = plan.world_meta.get("hall_rect", Rect2())
	var minaret: Rect2 = plan.world_meta.get("minaret_rect", Rect2())
	var tallest := ""
	var max_top := -INF
	var minaret_top := -INF
	for mass in builder.mass_log:
		var a: AABB = mass["aabb"]
		var top := a.position.y + a.size.y
		if top > max_top:
			max_top = top
			tallest = String(mass.get("name", ""))
		if String(mass.get("name", "")) == "minaret":
			minaret_top = top
	var hall_box := AABB(Vector3(hall.position.x, 0.0, hall.position.y), Vector3(hall.size.x, plan.spec.height, hall.size.y))
	var minaret_box := AABB(Vector3(minaret.position.x, 0.0, minaret.position.y), Vector3(minaret.size.x, float(plan.world_meta.get("minaret_height", 0.0)), minaret.size.y))
	if tallest != "minaret" or minaret_top <= 0.0:
		failures.append("minaret: the tallest emitted mass is not tagged minaret")
	if hall_box.intersects(minaret_box):
		failures.append("minaret: tower intersects the hall")


func _rows(plan: HousePlan, builder: MosqueBuilder, failures: Array[String], stats: Dictionary) -> void:
	var hall: Rect2 = plan.world_meta.get("hall_rect", Rect2())
	var floor_area := 0.0
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == "hall_floor":
			var a: AABB = mass["aabb"]
			floor_area = a.size.x * a.size.z
	var occupied := 0.0
	for column in plan.columns:
		var radius := float(column.get("radius", 0.0))
		occupied += radius * radius * 4.0
	var standable := floor_area - occupied
	stats["standable_floor_ratio"] = standable / maxf(hall.size.x * hall.size.y, 0.01)
	if floor_area <= 0.0 or standable < floor_area * 0.6:
		failures.append("rows: standable floor is below 0.6 of hall area")
	var central := float(plan.world_meta.get("central_aisle", 0.0))
	for column in plan.columns:
		# Match the grid check's millimetre tolerance at the authored aisle edge;
		# symmetric floating-point multiplication can land a boundary just below it.
		if absf(Vector3(column.get("pos", Vector3.ZERO)).x) < central * 0.5 - 0.001:
			failures.append("rows: column blocks the central prayer aisle")
			break
