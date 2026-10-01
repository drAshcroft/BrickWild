class_name MountainBuilder
extends MassBuilder
## Emits the temple mountain's measured walls, galleries, stair treads and towers.

const STONE := 0
const ROOF := 1
const WATER := 2

var plan: HousePlan


func build(p_plan: HousePlan) -> ArrayMesh:
	plan = p_plan
	begin_metric(3)
	var meta: Dictionary = plan.world_meta
	_emit_moat(meta)
	_emit_causeway(meta)
	for i in range(meta["rings"].size()):
		var ring: Dictionary = meta["rings"][i]
		_emit_gallery(i, ring)
		_emit_enclosure(i, ring)
		_emit_gopura(i, ring, meta["gopuras"][i])
	_emit_stairs(meta["stairs"])
	_emit_summit(meta)
	_emit_towers(meta["towers"])
	total_height = float(meta["total_height"])
	return commit()


func _emit_moat(meta: Dictionary) -> void:
	var outer: Rect2 = meta["outer"]
	var moat: Rect2 = meta["moat"]
	var w: float = meta["moat_width"]
	var causeway: Rect2 = meta["causeway"]
	var bands: Array[Rect2] = [
		Rect2(Vector2(moat.position.x, moat.position.y), Vector2(moat.size.x, w)),
		Rect2(Vector2(moat.position.x, outer.end.y), Vector2(moat.size.x, w)),
		Rect2(Vector2(moat.position.x, outer.position.y), Vector2(w, outer.size.y)),
		Rect2(Vector2(outer.end.x, outer.position.y), Vector2(w, outer.size.y)),
	]
	var south_left := Rect2(Vector2(moat.position.x, moat.position.y),
		Vector2(causeway.position.x - moat.position.x, w))
	var south_right := Rect2(Vector2(causeway.end.x, moat.position.y),
		Vector2(moat.end.x - causeway.end.x, w))
	var all: Array[Rect2] = [bands[1], bands[2], bands[3], south_left, south_right]
	for i in range(all.size()):
		_emit_mass("water_%d" % i, all[i], -0.8, 0.08, WATER, "moat_water")


func _emit_causeway(meta: Dictionary) -> void:
	var r: Rect2 = meta["causeway"]
	_emit_mass("causeway", r, -0.08, 0.16, STONE, "causeway")


func _emit_gallery(index: int, ring: Dictionary) -> void:
	var level: float = ring["level"]
	var segments := MountainGenerator.gallery_segments(ring)
	for i in range(segments.size()):
		_emit_mass("gallery_%d_%d" % [index, i], segments[i], level - 0.18,
			0.18, STONE, "gallery_%d" % index)


func _emit_enclosure(index: int, ring: Dictionary) -> void:
	var r: Rect2 = ring["rect"]
	var level: float = ring["level"]
	var t: float = ring["wall_thickness"]
	var h: float = ring["wall_height"]
	var gate: float = ring["gate_width"]
	var half_gate: float = gate * 0.5
	var wall_rects: Array[Rect2] = [
		Rect2(Vector2(r.position.x, r.end.y - t), Vector2(r.size.x, t)),
		Rect2(Vector2(r.position.x, r.position.y + t), Vector2(t, r.size.y - 2.0 * t)),
		Rect2(Vector2(r.end.x - t, r.position.y + t), Vector2(t, r.size.y - 2.0 * t)),
		Rect2(Vector2(r.position.x, r.position.y), Vector2(r.size.x * 0.5 - half_gate, t)),
		Rect2(Vector2(half_gate, r.position.y), Vector2(r.size.x * 0.5 - half_gate, t)),
	]
	for i in range(wall_rects.size()):
		_emit_mass("enclosure_%d_wall_%d" % [index, i], wall_rects[i],
			level, h, STONE, "enclosure_%d" % index)


func _emit_gopura(index: int, ring: Dictionary, gate: Dictionary) -> void:
	var level: float = ring["level"]
	var r: Rect2 = ring["rect"]
	var pillar_w := 1.0
	var pillar_h: float = float(gate["height"]) - 0.75
	var x_offset: float = float(gate["width"]) * 0.5 - pillar_w * 0.5
	var z: float = r.position.y + float(ring["wall_thickness"]) * 0.5
	for side in [-1.0, 1.0]:
		_emit_mass("gopura_%d_pillar_%s" % [index, "left" if side < 0.0 else "right"],
			Rect2(Vector2(side * x_offset - pillar_w * 0.5, z - 0.7),
				Vector2(pillar_w, 1.4)), level, pillar_h, STONE,
			"gopura_%d" % index)
	# The lintel spans the gate above a person-height opening. Its AABB leaves
	# the ceremonial axis clear from the causeway to the upper half of the god.
	var lintel_h := 0.75
	var lintel_level: float = level + float(gate["height"]) - lintel_h
	_emit_mass("gopura_%d_lintel" % index,
		Rect2(Vector2(-float(gate["width"]) * 0.5, z - 0.7),
			Vector2(float(gate["width"]), 1.4)), lintel_level, lintel_h,
		STONE, "gopura_%d" % index)


func _emit_stairs(stairs: Array) -> void:
	for stair in stairs:
		var r: Rect2 = stair["rect"]
		_emit_mass(String(stair["id"]), r, float(stair["level"]),
			float(stair["rise"]), STONE, String(stair["id"]))


func _emit_summit(meta: Dictionary) -> void:
	var r: Rect2 = meta["summit"]
	var level: float = meta["summit_level"]
	_emit_mass("summit_platform", r, level - 0.18, 0.18, STONE, "summit")


func _emit_towers(towers: Array) -> void:
	for tower in towers:
		var p: Vector2 = tower["pos"]
		var width: float = tower["width"]
		var h: float = tower["height"]
		var footprint := Rect2(Vector2(p.x - width * 0.5, p.y - width * 0.5),
			Vector2(width, width))
		_emit_mass(String(tower["id"]), footprint, float(tower["level"]),
			h, ROOF, "summit_towers")


func _emit_mass(name: String, footprint: Rect2, y: float, height: float,
		surface: int, host_name: String) -> void:
	if footprint.size.x <= 0.001 or footprint.size.y <= 0.001 or height <= 0.001:
		return
	var size := Vector3(footprint.size.x, height, footprint.size.y)
	var center := Vector3(footprint.get_center().x, y + height * 0.5,
		footprint.get_center().y)
	host(host_name)
	component_box(name, size, Transform3D(Basis.IDENTITY, center), surface)
	host_end()
	_log_mass(name, AABB(Vector3(footprint.position.x, y, footprint.position.y),
		Vector3(footprint.size.x, height, footprint.size.y)), y)
