class_name MosqueBuilder
extends MassBuilder
## Emits the authored mosque plan. Surfaces: stone, roof, dark openings.

const STONE := 0
const ROOF := 1
const DARK := 2

var plan: HousePlan

func build(p_plan: HousePlan) -> ArrayMesh:
	plan = p_plan
	begin_metric(3)
	var hall: Rect2 = plan.world_meta["hall_rect"]
	var qibla: Rect2 = plan.world_meta["qibla_wall"]
	var mihrab: Rect2 = plan.world_meta["mihrab"]
	var h := plan.spec.height
	# The worship floor includes the complete prayer room.
	box(Vector3(hall.size.x, 0.3, hall.size.y), Vector3(hall.get_center().x, 0.15, hall.get_center().y), STONE)
	_log_mass("hall_floor", AABB(Vector3(hall.position.x, 0.0, hall.position.y), Vector3(hall.size.x, 0.3, hall.size.y)))
	# Side and qibla walls are continuous. The front wall has a single central door.
	box(Vector3(0.8, h, hall.size.y), Vector3(hall.position.x + 0.4, h * 0.5, hall.get_center().y), STONE)
	box(Vector3(0.8, h, hall.size.y), Vector3(hall.end.x - 0.4, h * 0.5, hall.get_center().y), STONE)
	_log_mass("wall_side_left", AABB(Vector3(hall.position.x, 0.3, hall.position.y), Vector3(0.8, h, hall.size.y)))
	_log_mass("wall_side_right", AABB(Vector3(hall.end.x - 0.8, 0.3, hall.position.y), Vector3(0.8, h, hall.size.y)))
	var niche_width := float(mihrab.size.x)
	for side in [-1.0, 1.0]:
		var width := (qibla.size.x - niche_width) * 0.5
		var x := qibla.position.x + width * 0.5 if side < 0.0 else qibla.end.x - width * 0.5
		box(Vector3(width, h, qibla.size.y), Vector3(x, h * 0.5, qibla.get_center().y), STONE)
		_log_mass("qibla_wall_%s" % ("left" if side < 0.0 else "right"), AABB(Vector3(x - width * 0.5, 0.3, qibla.position.y), Vector3(width, h, qibla.size.y)))
	var lintel_h := h * 0.42
	box(Vector3(niche_width, lintel_h, qibla.size.y), Vector3(0.0, h - lintel_h * 0.5, qibla.get_center().y), STONE)
	_log_mass("qibla_wall_lintel", AABB(Vector3(-niche_width * 0.5, h - lintel_h, qibla.position.y), Vector3(niche_width, lintel_h, qibla.size.y)))
	var front_z := hall.position.y + 0.4
	var door_width := minf(4.2, hall.size.x * 0.12)
	for side in [-1.0, 1.0]:
		var width := (hall.size.x - door_width) * 0.5
		var x := hall.position.x + width * 0.5 if side < 0.0 else hall.end.x - width * 0.5
		box(Vector3(width, h, 0.8), Vector3(x, h * 0.5, front_z), STONE)
		_log_mass("front_pier_%s" % ("left" if side < 0.0 else "right"), AABB(Vector3(x - width * 0.5, 0.3, front_z - 0.4), Vector3(width, h, 0.8)))
	# Flat roof is a ring of mass: the sahn stays open to the sky.
	var roof_t := 0.35
	box(Vector3(hall.size.x, roof_t, hall.size.y * 0.09), Vector3(hall.get_center().x, h + roof_t * 0.5, hall.position.y + hall.size.y * 0.045), ROOF)
	box(Vector3(hall.size.x, roof_t, hall.size.y * 0.09), Vector3(hall.get_center().x, h + roof_t * 0.5, hall.end.y - hall.size.y * 0.045), ROOF)
	box(Vector3(hall.size.x * 0.09, roof_t, hall.size.y * 0.82), Vector3(hall.position.x + hall.size.x * 0.045, h + roof_t * 0.5, hall.get_center().y), ROOF)
	box(Vector3(hall.size.x * 0.09, roof_t, hall.size.y * 0.82), Vector3(hall.end.x - hall.size.x * 0.045, h + roof_t * 0.5, hall.get_center().y), ROOF)
	for i in range(plan.columns.size()):
		var column: Dictionary = plan.columns[i]
		var p: Vector3 = column["pos"]
		var radius := float(column["radius"])
		var height := float(column["height"])
		box(Vector3(radius * 2.0, height, radius * 2.0), Vector3(p.x, height * 0.5, p.z), STONE)
		_log_mass("column_%02d" % i, AABB(Vector3(p.x - radius, 0.0, p.z - radius), Vector3(radius * 2.0, height, radius * 2.0)))
	box(Vector3(mihrab.size.x, mihrab.size.y, 0.8), Vector3(mihrab.get_center().x, h * 0.18, mihrab.get_center().y), STONE)
	_log_mass("mihrab", AABB(Vector3(mihrab.position.x, 0.3, mihrab.position.y), Vector3(mihrab.size.x, mihrab.size.y, 0.8)))
	var sahn: Rect2 = plan.world_meta["sahn_rect"]
	box(Vector3(sahn.size.x, 0.2, sahn.size.y), Vector3(sahn.get_center().x, 0.1, sahn.get_center().y), STONE)
	_log_mass("sahn_floor", AABB(Vector3(sahn.position.x, 0.0, sahn.position.y), Vector3(sahn.size.x, 0.2, sahn.size.y)))
	var water: Rect2 = plan.roof_openings[0]["impluvium"]
	box(Vector3(water.size.x, 0.18, water.size.y), Vector3(water.get_center().x, 0.12, water.get_center().y), DARK)
	_log_mass("fountain", AABB(Vector3(water.position.x, 0.03, water.position.y), Vector3(water.size.x, 0.18, water.size.y)))
	var tower: Rect2 = plan.world_meta["minaret_rect"]
	var tower_h := float(plan.world_meta["minaret_height"])
	box(Vector3(tower.size.x, tower_h, tower.size.y), Vector3(tower.get_center().x, tower_h * 0.5, tower.get_center().y), STONE)
	_log_mass("minaret", AABB(Vector3(tower.position.x, 0.0, tower.position.y), Vector3(tower.size.x, tower_h, tower.size.y)))
	total_height = tower_h
	return commit()
