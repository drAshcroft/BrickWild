class_name CutTempleBuilder
extends MassBuilder
## Emits the retained rock, gallery, bridge and monolithic temple below grade.

const ROCK := 0
const CARVING := 1
const ROOF := 2
const FLOOR_T := 0.36


func build(plan: HousePlan) -> ArrayMesh:
	begin_metric(3)
	var meta: Dictionary = plan.world_meta
	_emit_pit(meta)
	_emit_gallery(meta)
	_emit_gateway(meta)
	_emit_bridge(meta)
	_emit_temple(meta)
	total_height = 3.0
	return commit()


func _emit_pit(meta: Dictionary) -> void:
	var site: Rect2 = meta["site"]
	var floor_y := float(meta["pit_floor_y"])
	var depth := -floor_y
	var t := CutTempleGenerator.WALL_T
	_box_mass("pit_floor", Vector3(site.size.x, FLOOR_T, site.size.y),
		Vector3(site.get_center().x, floor_y - FLOOR_T * 0.5, site.get_center().y),
		ROCK, floor_y - FLOOR_T)
	_box_mass("pit_wall_front", Vector3(site.size.x, depth, t),
		Vector3(site.get_center().x, floor_y + depth * 0.5, site.position.y + t * 0.5),
		ROCK, floor_y)
	_box_mass("pit_wall_back", Vector3(site.size.x, depth, t),
		Vector3(site.get_center().x, floor_y + depth * 0.5, site.end.y - t * 0.5),
		ROCK, floor_y)
	_box_mass("pit_wall_left", Vector3(t, depth, site.size.y - 2.0 * t),
		Vector3(site.position.x + t * 0.5, floor_y + depth * 0.5, site.get_center().y),
		ROCK, floor_y)
	_box_mass("pit_wall_right", Vector3(t, depth, site.size.y - 2.0 * t),
		Vector3(site.end.x - t * 0.5, floor_y + depth * 0.5, site.get_center().y),
		ROCK, floor_y)


func _emit_gallery(meta: Dictionary) -> void:
	var y := float(meta["gallery_y"])
	var gallery: Array = meta["gallery"]
	for i in range(gallery.size()):
		var rect: Rect2 = gallery[i]
		_box_mass("gallery_floor_%d" % i, Vector3(rect.size.x, FLOOR_T, rect.size.y),
			Vector3(rect.get_center().x, y - FLOOR_T * 0.5, rect.get_center().y),
			CARVING, y - FLOOR_T)
	# The colonnade is carved against the four cut faces. Columns stop at grade.
	var site: Rect2 = meta["site"]
	var step := maxf(4.0, minf(site.size.x, site.size.y) / 8.0)
	var column_h := -y
	var seq := 0
	for z in _samples(site.position.y + 2.0, site.end.y - 2.0, step):
		for x in [site.position.x + 1.15, site.end.x - 1.15]:
			_box_mass("gallery_column_%d" % seq, Vector3(0.48, column_h, 0.48),
				Vector3(x, y + column_h * 0.5, z), CARVING, y)
			seq += 1
	for x in _samples(site.position.x + 2.0, site.end.x - 2.0, step):
		for z in [site.position.y + 1.15, site.end.y - 1.15]:
			_box_mass("gallery_column_%d" % seq, Vector3(0.48, column_h, 0.48),
				Vector3(x, y + column_h * 0.5, z), CARVING, y)
			seq += 1


func _emit_gateway(meta: Dictionary) -> void:
	var rect: Rect2 = meta["gateway_rect"]
	var base := float(meta["gallery_y"])
	var h := -base + 3.0
	_box_mass("gateway", Vector3(rect.size.x, h, rect.size.y),
		Vector3(rect.get_center().x, base + h * 0.5, rect.get_center().y), CARVING, base)


func _emit_bridge(meta: Dictionary) -> void:
	var rect: Rect2 = meta["bridge_rect"]
	var y := float(meta["gallery_y"])
	_box_mass("bridge", Vector3(rect.size.x, FLOOR_T, rect.size.y),
		Vector3(rect.get_center().x, y - FLOOR_T * 0.5, rect.get_center().y),
		CARVING, y - FLOOR_T)


func _emit_temple(meta: Dictionary) -> void:
	var floor_y := float(meta["pit_floor_y"])
	var gallery_y := float(meta["gallery_y"])
	var temple: Rect2 = meta["temple_rect"]
	var nandi: Rect2 = meta["nandi_rect"]
	_box_mass("temple_plinth", Vector3(temple.size.x, gallery_y - floor_y, temple.size.y),
		Vector3(temple.get_center().x, floor_y + (gallery_y - floor_y) * 0.5,
			temple.get_center().y), ROCK, floor_y)
	_box_mass("nandi_plinth", Vector3(nandi.size.x, gallery_y - floor_y, nandi.size.y),
		Vector3(nandi.get_center().x, floor_y + (gallery_y - floor_y) * 0.5,
			nandi.get_center().y), ROCK, floor_y)
	_emit_pavilion("nandi", nandi, gallery_y, 5.5)
	_emit_hall("porch", meta["porch_rect"], gallery_y, 6.0)
	_emit_hall("hall", meta["hall_rect"], gallery_y, 7.0)
	_emit_hall("sanctum", meta["sanctum_rect"], gallery_y, 8.0)
	_emit_shikhara(meta)


func _emit_pavilion(prefix: String, rect: Rect2, base: float, height: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pos := Vector3(rect.get_center().x + sx * (rect.size.x * 0.5 - 0.6),
				base + height * 0.5, rect.get_center().y + sz * (rect.size.y * 0.5 - 0.6))
			_box_mass("%s_column" % prefix, Vector3(0.55, height, 0.55), pos,
				CARVING, base)
	_box_mass("%s_roof" % prefix, Vector3(rect.size.x, 0.45, rect.size.y),
		Vector3(rect.get_center().x, base + height - 0.225, rect.get_center().y),
		ROOF, base + height - 0.45)


func _emit_hall(prefix: String, rect: Rect2, base: float, height: float) -> void:
	var wall_t := 0.65
	_box_mass("%s_left" % prefix, Vector3(wall_t, height, rect.size.y),
		Vector3(rect.position.x + wall_t * 0.5, base + height * 0.5, rect.get_center().y),
		CARVING, base)
	_box_mass("%s_right" % prefix, Vector3(wall_t, height, rect.size.y),
		Vector3(rect.end.x - wall_t * 0.5, base + height * 0.5, rect.get_center().y),
		CARVING, base)
	_box_mass("%s_rear" % prefix, Vector3(rect.size.x, height, wall_t),
		Vector3(rect.get_center().x, base + height * 0.5, rect.end.y - wall_t * 0.5),
		CARVING, base)
	_box_mass("%s_roof" % prefix, Vector3(rect.size.x, 0.45, rect.size.y),
		Vector3(rect.get_center().x, base + height - 0.225, rect.get_center().y),
		ROOF, base + height - 0.45)


func _emit_shikhara(meta: Dictionary) -> void:
	var sanctum: Rect2 = meta["sanctum_rect"]
	var top := -0.65
	var base := float(meta["gallery_y"]) + 7.55
	var tier_h := (top - base) / 5.0
	for i in range(5):
		var factor := 1.0 - float(i) * 0.13
		var size := Vector3(sanctum.size.x * factor, tier_h + 0.04,
			sanctum.size.y * factor)
		var y0 := base + float(i) * tier_h
		_box_mass("shikhara_tier_%d" % i, size,
			Vector3(sanctum.get_center().x, y0 + size.y * 0.5, sanctum.get_center().y),
			ROOF, y0)


func _box_mass(name: String, size: Vector3, pos: Vector3, surface: int,
		ground: float) -> void:
	box(size, pos, surface)
	_log_mass(name, AABB(pos - size * 0.5, size), ground)


static func _samples(from: float, to: float, step: float) -> Array[float]:
	var out: Array[float] = []
	var count := maxi(2, ceili((to - from) / step))
	for i in range(count + 1):
		out.append(lerpf(from, to, float(i) / float(count)))
	return out
