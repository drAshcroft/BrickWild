class_name CruciformBuilder
extends MassBuilder
## Emits the cruciform shrine from the plan's measured ring and image data.

const STONE := 0
const ROOF := 1
const DARK := 2

var plan: HousePlan

func build(p_plan: HousePlan) -> ArrayMesh:
	plan = p_plan
	begin_metric(3)
	var meta: Dictionary = plan.world_meta
	var hall: Rect2 = meta["hall_rect"]
	var h := float(meta["hall_height"])
	box(Vector3(hall.size.x, 0.25, hall.size.y),
		Vector3(0.0, 0.125, 0.0), STONE)
	_log_mass("hall_floor", AABB(Vector3(hall.position.x, 0.0, hall.position.y),
		Vector3(hall.size.x, 0.25, hall.size.y)))
	_build_perimeter(hall, meta["entrances"], h)
	_build_rings(meta["outer_ring"], "outer_ring", h)
	_build_rings(meta["inner_ring"], "inner_ring", h)
	_build_links(meta["ring_links"], h)
	for item in meta["images"]:
		var p: Vector3 = item["pos"]
		var image_h := float(item["height"])
		box(Vector3(1.5, image_h, 1.0), Vector3(p.x, image_h * 0.5, p.z), STONE)
		_log_mass(String(item["id"]), AABB(Vector3(p.x - 0.75, 0.0, p.z - 0.5),
			Vector3(1.5, image_h, 1.0)))
	var sikhara_h := float(meta["sikhara_height"])
	var center: Vector3 = meta["sikhara_center"]
	box(Vector3(8.0, sikhara_h, 8.0), Vector3(center.x, sikhara_h * 0.5, center.z), ROOF)
	_log_mass("sikhara", AABB(Vector3(center.x - 4.0, 0.0, center.z - 4.0),
		Vector3(8.0, sikhara_h, 8.0)))
	total_height = sikhara_h
	return commit()


func _build_perimeter(hall: Rect2, doors: Array, h: float) -> void:
	var t := CruciformGenerator.WALL_T
	var north: Dictionary = doors[0]
	var east: Dictionary = doors[1]
	var south: Dictionary = doors[2]
	var west: Dictionary = doors[3]
	# Each side is split around its own opening. The openings sit on the actual wall.
	_wall_with_door(Vector2(hall.position.x, hall.position.y), hall.size.x, true, north, h, t, "north")
	_wall_with_door(Vector2(hall.position.x, hall.end.y - t), hall.size.x, true, south, h, t, "south")
	_wall_with_door(Vector2(hall.position.x, hall.position.y), hall.size.y, false, west, h, t, "west")
	_wall_with_door(Vector2(hall.end.x - t, hall.position.y), hall.size.y, false, east, h, t, "east")


func _wall_with_door(start: Vector2, span: float, horizontal: bool,
		door: Dictionary, h: float, t: float, side: String) -> void:
	var center_coord := float((door["pos"] as Vector2).x if horizontal else (door["pos"] as Vector2).y)
	var lo := float(start.x if horizontal else start.y)
	var opening := float(door["width"])
	var first := center_coord - opening * 0.5 - lo
	var last := span - first - opening
	if first > 0.01:
		_wall_piece(start, first, horizontal, h, t, side + "_a")
	if last > 0.01:
		var end_start := start + (Vector2(first + opening, 0.0) if horizontal else Vector2(0.0, first + opening))
		_wall_piece(end_start, last, horizontal, h, t, side + "_b")


func _wall_piece(start: Vector2, span: float, horizontal: bool, h: float,
		t: float, label: String) -> void:
	var center2 := start + (Vector2(span * 0.5, t * 0.5) if horizontal else Vector2(t * 0.5, span * 0.5))
	var size := Vector3(span, h, t) if horizontal else Vector3(t, h, span)
	box(size, Vector3(center2.x, h * 0.5, center2.y), STONE)
	_log_mass("wall_%s" % label, AABB(Vector3(center2.x - size.x * 0.5, 0.0,
		center2.y - size.z * 0.5), size))


func _build_rings(rings: Array, prefix: String, h: float) -> void:
	for i in range(rings.size()):
		var r: Rect2 = rings[i]
		box(Vector3(r.size.x, h * 0.35, r.size.y),
			Vector3(r.get_center().x, h * 0.175, r.get_center().y), STONE)
		_log_mass("%s_%d" % [prefix, i], AABB(Vector3(r.position.x, 0.0, r.position.y),
			Vector3(r.size.x, h * 0.35, r.size.y)))


func _build_links(links: Array, h: float) -> void:
	for i in range(links.size()):
		var r: Rect2 = links[i]
		box(Vector3(r.size.x, h * 0.35, r.size.y),
			Vector3(r.get_center().x, h * 0.175, r.get_center().y), DARK)
		_log_mass("ring_link_%d" % i, AABB(Vector3(r.position.x, 0.0, r.position.y),
			Vector3(r.size.x, h * 0.35, r.size.y)))
