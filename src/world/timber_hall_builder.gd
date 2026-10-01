class_name TimberHallBuilder
extends MassBuilder
## Timber hall plan -> mesh. Surfaces: timber, stone, roof, dark openings
## (the pond), and plaster -- the wall panels between the posts. Plaster is
## its own surface so the assembler can paint a white wall between dark
## timber; the geometry, logs and sizes are unchanged.

const SURF_TIMBER := 0
const SURF_STONE := 1
const SURF_ROOF := 2
const SURF_DARK := 3
const SURF_PLASTER := 4
const SURF_TRIM := 0

var spec: TimberHallSpec
var with_roof := true
var fill_door := false

func build(p_spec: TimberHallSpec, p_with_roof := true, p_fill_door := false) -> ArrayMesh:
	spec = p_spec
	with_roof = p_with_roof
	fill_door = p_fill_door
	begin(5)
	_build_platform()
	_build_hall()
	_build_columns()
	_build_dais_and_image()
	_build_wings()
	if with_roof:
		_build_roof()
	# the great hall has no pond, so slot 3 is empty and plaster would move down
	return commit_named()

func _build_platform() -> void:
	var p := TimberHallGeometry.platform_rect(spec)
	box(Vector3(p.size.x, spec.platform_h, p.size.y),
		Vector3(p.get_center().x, spec.platform_h / 2.0, p.get_center().y), SURF_STONE)
	_log_mass("platform", AABB(Vector3(p.position.x, 0.0, p.position.y),
		Vector3(p.size.x, spec.platform_h, p.size.y)))
	var s := TimberHallGeometry.front_stair_rect(spec)
	for i in range(ceil(s.size.y / TimberHallGeometry.STAIR_TREAD)):
		var depth := TimberHallGeometry.STAIR_TREAD * float(i + 1)
		var r := Rect2(Vector2(s.position.x, s.end.y - depth), Vector2(s.size.x, depth))
		var h := TimberHallGeometry.STAIR_RISE * float(i + 1)
		box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, h / 2.0, r.get_center().y), SURF_STONE)
	_log_mass("front_stair", AABB(Vector3(s.position.x, 0.0, s.position.y), Vector3(s.size.x, spec.platform_h, s.size.y)))

func _build_hall() -> void:
	var h := TimberHallGeometry.hall_rect(spec)
	var floor_y := spec.platform_h
	box(Vector3(h.size.x, 0.12, h.size.y), Vector3(h.get_center().x, floor_y + 0.06, h.get_center().y), SURF_TIMBER)
	_log_mass("floor", AABB(Vector3(h.position.x, floor_y, h.position.y), Vector3(h.size.x, 0.12, h.size.y)))
	var door_w := 3.0
	var door_h := minf(5.0, spec.height * 0.42)
	var front_z := h.position.y + spec.wall_t / 2.0
	if fill_door:
		box(Vector3(h.size.x, spec.height, spec.wall_t), Vector3(0.0, floor_y + spec.height / 2.0, front_z), SURF_PLASTER)
		_log_mass("wall_front_filled", AABB(Vector3(h.position.x, floor_y, h.position.y), Vector3(h.size.x, spec.height, spec.wall_t)))
		return
	for side in [-1.0, 1.0]:
		var w := (h.size.x - door_w) / 2.0
		var x := h.position.x if side < 0.0 else door_w / 2.0
		box(Vector3(w, spec.height, spec.wall_t), Vector3(x + w / 2.0, floor_y + spec.height / 2.0, front_z), SURF_PLASTER)
	_log_part("door", Vector3(0.0, floor_y + door_h / 2.0, front_z), Vector3(door_w, door_h, 0.0), PI, Vector3(0, 0, -1))
	box(Vector3(door_w, spec.height - door_h, spec.wall_t), Vector3(0.0, floor_y + door_h + (spec.height - door_h) / 2.0, front_z), SURF_PLASTER)
	_log_mass("wall_front_left", AABB(Vector3(h.position.x, floor_y, h.position.y), Vector3((h.size.x - door_w) / 2.0, spec.height, spec.wall_t)))
	_log_mass("wall_front_right", AABB(Vector3(door_w / 2.0, floor_y, h.position.y), Vector3((h.size.x - door_w) / 2.0, spec.height, spec.wall_t)))
	_log_mass("wall_front_lintel", AABB(Vector3(-door_w / 2.0, floor_y + door_h, h.position.y), Vector3(door_w, spec.height - door_h, spec.wall_t)))
	# Back wall carries the image; the side walls are split around true windows.
	var back_z := h.end.y - spec.wall_t / 2.0
	box(Vector3(h.size.x, spec.height, spec.wall_t), Vector3(0.0, floor_y + spec.height / 2.0, back_z), SURF_PLASTER)
	_log_mass("wall_back", AABB(Vector3(h.position.x, floor_y, h.end.y - spec.wall_t), Vector3(h.size.x, spec.height, spec.wall_t)))
	for side in [-1.0, 1.0]:
		var x: float = side * (h.size.x / 2.0 - spec.wall_t / 2.0)
		var windows_on_side: Array[float] = []
		for w0 in spec.windows:
			if signf(float(w0["normal"].x)) == signf(side):
				windows_on_side.append(float((w0["pos"] as Vector3).z))
		windows_on_side.sort()
		var cursor := h.position.y
		for z0 in windows_on_side:
			var half := 0.6
			var seg := maxf(z0 - half - cursor, 0.0)
			if z0 - half > cursor:
				box(Vector3(spec.wall_t, spec.height, seg), Vector3(x, floor_y + spec.height / 2.0, cursor + seg / 2.0), SURF_PLASTER)
			_log_mass("wall_side_%s_%d" % ["left" if side < 0.0 else "right", windows_on_side.find(z0)], AABB(Vector3(x - spec.wall_t / 2.0, floor_y, cursor), Vector3(spec.wall_t, spec.height, maxf(seg, 0.01))))
			var window_y: float = spec.platform_h + (9.0 if spec.wings else 5.0)
			var bottom: float = window_y - spec.platform_h - 1.0
			var top: float = spec.height - bottom - 2.0
			box(Vector3(spec.wall_t, bottom, 1.2), Vector3(x, floor_y + bottom / 2.0, z0), SURF_PLASTER)
			box(Vector3(spec.wall_t, top, 1.2), Vector3(x, floor_y + bottom + 2.0 + top / 2.0, z0), SURF_PLASTER)
			_log_part("window", Vector3(side * h.size.x / 2.0, window_y, z0), Vector3(0.0, 2.0, 1.2), 0.0, Vector3(side, 0, 0))
			cursor = z0 + half
		if h.end.y > cursor:
			var seg2 := h.end.y - cursor
			box(Vector3(spec.wall_t, spec.height, seg2), Vector3(x, floor_y + spec.height / 2.0, cursor + seg2 / 2.0), SURF_PLASTER)

func _build_columns() -> void:
	for i in range(spec.columns.size()):
		var c: Dictionary = spec.columns[i]
		var p: Vector3 = c["pos"]
		var r: float = c["radius"]
		var h: float = c["height"]
		box(Vector3(r * 2.0, 0.22, r * 2.0), Vector3(p.x, p.y + 0.11, p.z), SURF_STONE)
		box(Vector3(r * 1.45, h, r * 1.45), Vector3(p.x, p.y + h / 2.0, p.z), SURF_TIMBER)
		box(Vector3(r * 2.3, 0.25, r * 2.3), Vector3(p.x, p.y + h + 0.12, p.z), SURF_TIMBER)
		_log_mass("column_%d" % i, AABB(Vector3(p.x - r, p.y, p.z - r), Vector3(r * 2.0, h + 0.25, r * 2.0)))
		_log_part("bracket", Vector3(p.x, p.y + h + 0.25, p.z), Vector3(r * 2.3, 0.25, r * 2.3))

func _build_dais_and_image() -> void:
	var d := TimberHallGeometry.dais_rect(spec)
	box(Vector3(d.size.x, spec.dais_h, d.size.y), Vector3(d.get_center().x, spec.platform_h + spec.dais_h / 2.0, d.get_center().y), SURF_STONE)
	_log_mass("dais", AABB(Vector3(d.position.x, spec.platform_h, d.position.y), Vector3(d.size.x, spec.dais_h, d.size.y)))
	var ip := TimberHallGeometry.image_center(spec)
	box(Vector3(spec.width * 0.12, spec.image_h, 0.5), ip, SURF_TRIM)
	_log_mass("image", AABB(ip - Vector3(spec.width * 0.06, spec.image_h / 2.0, 0.25), Vector3(spec.width * 0.12, spec.image_h, 0.5)))

func _build_wings() -> void:
	if not spec.wings:
		return
	var h := TimberHallGeometry.hall_rect(spec)
	for side in [-1.0, 1.0]:
		var x: float = side * (h.size.x / 2.0 + spec.wing_w / 2.0)
		box(Vector3(spec.wing_w, spec.height * 0.55, h.size.y), Vector3(x, spec.platform_h + spec.height * 0.275, h.get_center().y), SURF_PLASTER)
		_log_mass("wing_%s" % ("left" if side < 0.0 else "right"), AABB(Vector3(x - spec.wing_w / 2.0, spec.platform_h, h.position.y), Vector3(spec.wing_w, spec.height * 0.55, h.size.y)))
		var roof_y := spec.platform_h + spec.height * 0.55
		_kit.hip_roof_at(Transform3D(Basis(), Vector3(x, roof_y, h.get_center().y)),
			spec.wing_w + 1.0, h.size.y + 1.0, spec.roof_rise * 0.42, SURF_ROOF)
		_log_mass("wing_roof_%s" % ("left" if side < 0.0 else "right"),
			AABB(Vector3(x - (spec.wing_w + 1.0) / 2.0, roof_y, h.position.y - 0.5),
			Vector3(spec.wing_w + 1.0, spec.roof_rise * 0.42, h.size.y + 1.0)))
	var w := spec.water
	box(Vector3(w.size.x, 0.12, w.size.y), Vector3(w.get_center().x, 0.12, w.get_center().y), SURF_DARK)
	_log_mass("water", AABB(Vector3(w.position.x, 0.06, w.position.y), Vector3(w.size.x, 0.12, w.size.y)))

func _build_roof() -> void:
	var h := TimberHallGeometry.hall_rect(spec)
	var span_x := h.size.x + spec.roof_overhang * 2.0
	var along := h.size.y + spec.roof_overhang * 2.0
	var y := spec.platform_h + spec.height
	_kit.hip_roof(span_x, along, spec.roof_rise, 0.0, SURF_ROOF, y)
	_log_mass("roof", AABB(Vector3(-span_x / 2.0, y, -along / 2.0), Vector3(span_x, spec.roof_rise, along)))
