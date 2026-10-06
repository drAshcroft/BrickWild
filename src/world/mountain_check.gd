class_name MountainCheck
extends TempleRiteCheck
## Structural acceptance for the nested temple mountain (WLD-011).

const LEVEL_RISE_MIN := 1.5
const MOAT_MIN := 20.0
const WALK_WIDTH_MIN := 1.2
const TOWER_RATIO := 1.2

var _plan: HousePlan
var _mountain_builder: MountainBuilder
var _climb_grid: WalkGrid


func check_mountain(plan: HousePlan, builder: MountainBuilder,
		emitted_mesh: ArrayMesh = null) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	_plan = plan
	_mountain_builder = builder
	_check_nest()
	_check_quincunx()
	_check_axis()
	_check_moat()
	_check_climb()
	_check_pradakshina()
	_check_rite_rules()
	_check_mesh(emitted_mesh)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


func _check_nest() -> void:
	var rings: Array = _plan.world_meta.get("rings", [])
	if rings.size() != 3:
		failures.append("nest: expected three enclosure rings")
		return
	for i in range(rings.size()):
		var row: Dictionary = rings[i]
		var rect: Rect2 = row.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("nest: enclosure %d has no positive footprint" % i)
			continue
		if i > 0:
			var previous: Rect2 = rings[i - 1]["rect"]
			var rise: float = float(row["level"]) - float(rings[i - 1]["level"])
			if not (previous.position.x < rect.position.x and previous.position.y < rect.position.y \
					and previous.end.x > rect.end.x and previous.end.y > rect.end.y):
				failures.append("nest: enclosure %d is not strictly inside the previous ring" % i)
			if rise < LEVEL_RISE_MIN:
				failures.append("nest: enclosure %d rises only %.2fm" % [i, rise])
		var floor_count := 0
		var wall_count := 0
		for mass in _mountain_builder.mass_log:
			var name := String(mass.get("name", ""))
			if name.begins_with("gallery_%d_" % i):
				floor_count += 1
				if absf((mass["aabb"] as AABB).end.y - float(row["level"])) > 0.05:
					failures.append("nest: emitted gallery %d is not at its authored level" % i)
			if name.begins_with("enclosure_%d_wall_" % i):
				wall_count += 1
		if floor_count != 4 or wall_count < 4:
			failures.append("nest: enclosure %d is missing emitted gallery or wall masses" % i)
	var overlap_report := MassRules.overlaps(_mountain_builder.mass_log,
		func(a: String, b: String) -> float:
			return INF if a.begins_with("stair") or b.begins_with("stair") else 0.0,
		["stair"])
	for issue in overlap_report["failures"]:
		failures.append("nest: %s" % str(issue))


func _check_quincunx() -> void:
	var towers: Array[Dictionary] = []
	for mass in _mountain_builder.mass_log:
		if String(mass.get("name", "")).begins_with("tower_"):
			towers.append(mass)
	if towers.size() != 5:
		failures.append("quincunx: expected five tower masses, found %d" % towers.size())
		return
	var center_index := -1
	var center: AABB
	var corners: Array[AABB] = []
	var summit: Rect2 = _plan.world_meta.get("summit", Rect2())
	var summit_level: float = _plan.world_meta.get("summit_level", -INF)
	for mass in towers:
		var box: AABB = mass["aabb"]
		if box.position.x < summit.position.x - 0.05 \
				or box.position.z < summit.position.y - 0.05 \
				or box.end.x > summit.end.x + 0.05 or box.end.z > summit.end.y + 0.05 \
				or absf(box.position.y - summit_level) > 0.05:
			failures.append("quincunx: %s is not on the top terrace" % String(mass["name"]))
		if String(mass["name"]) == "tower_center":
			center_index = towers.find(mass)
			center = box
		else:
			corners.append(box)
	if center_index < 0 or corners.size() != 4:
		failures.append("quincunx: central tower or four corner towers are missing")
		return
	var origin := Vector2(center.get_center().x, center.get_center().z)
	var radii: Array[float] = []
	for corner in corners:
		var point := Vector2(corner.get_center().x, corner.get_center().z)
		if point.distance_to(origin) < 0.01:
			failures.append("quincunx: a corner tower occupies the centre")
		else:
			radii.append(point.distance_to(origin))
	if radii.size() == 4:
		for radius in radii:
			if absf(radius - radii[0]) > 0.05:
				failures.append("quincunx: corner towers are not equidistant")
				break
	var center_height: float = center.size.y
	for corner in corners:
		if center_height + 0.001 < corner.size.y * TOWER_RATIO:
			failures.append("quincunx: centre tower is less than 1.2 times a corner tower")
			break


func _check_axis() -> void:
	var causeway: Rect2 = _plan.world_meta.get("causeway", Rect2())
	var start: Vector2 = _plan.world_meta.get("causeway_start", Vector2.ZERO)
	if absf(causeway.get_center().x) > 0.05 or absf(start.x) > 0.05:
		failures.append("axis: causeway is not centred on the temple axis")
	var gates: Array = _plan.world_meta.get("gopuras", [])
	if gates.size() != 3:
		failures.append("axis: each enclosure must have an axial gopura")
	for gate in gates:
		var point: Vector2 = gate.get("center", Vector2.INF)
		if absf(point.x) > 0.05:
			failures.append("axis: %s is off the processional axis" % String(gate.get("id", "gopura")))
		var gate_id := String(gate.get("id", ""))
		if gate_id.is_empty() or _mass(gate_id + "_lintel").is_empty():
			failures.append("axis: an axial gopura was not emitted")
	var center_mass: Dictionary = _mass("tower_center")
	if center_mass.is_empty():
		failures.append("axis: central tower mass is missing")
		return
	var target_box: AABB = center_mass["aabb"]
	var to := Vector3(target_box.get_center().x,
		target_box.position.y + target_box.size.y * 0.75, target_box.get_center().z)
	var from := Vector3(start.x, 1.65, start.y)
	var blockers: Array[AABB] = []
	for mass in _mountain_builder.mass_log:
		var name := String(mass["name"])
		if name == "tower_center" or name.begins_with("gallery_") \
				or name.begins_with("water_") or name == "causeway" \
				or name == "summit_platform" or name.begins_with("stair_"):
			continue
		blockers.append(mass["aabb"])
	if not Sightline.clear(from, to, blockers):
		failures.append("axis: obstruction between the causeway and the tower's upper half")


func _check_moat() -> void:
	var meta: Dictionary = _plan.world_meta
	var moat: Rect2 = meta.get("moat", Rect2())
	var outer: Rect2 = meta.get("outer", Rect2())
	var widths := [outer.position.x - moat.position.x, outer.position.y - moat.position.y,
		moat.end.x - outer.end.x, moat.end.y - outer.end.y]
	for width in widths:
		if float(width) < MOAT_MIN - 0.001:
			failures.append("moat: water is only %.2fm wide at one side" % float(width))
			break
	var water_count := 0
	var water_bounds := AABB()
	for mass in _mountain_builder.mass_log:
		if String(mass["name"]).begins_with("water_"):
			var water_aabb: AABB = mass["aabb"]
			water_bounds = water_aabb if water_count == 0 else water_bounds.merge(water_aabb)
			water_count += 1
	if water_count < 5:
		failures.append("moat: emitted water does not surround the enclosure")
	else:
		var measured := [outer.position.x - water_bounds.position.x,
			outer.position.y - water_bounds.position.z,
			water_bounds.end.x - outer.end.x, water_bounds.end.z - outer.end.y]
		for width in measured:
			if float(width) < MOAT_MIN - 0.001:
				failures.append("moat: emitted water leaves only %.2fm at one side" % float(width))
				break
	var causeway: Rect2 = meta.get("causeway", Rect2())
	var crosses: bool = causeway.position.y <= moat.position.y and causeway.end.y >= outer.position.y
	var causeway_count := 0
	for mass in _mountain_builder.mass_log:
		if String(mass.get("name", "")) == "causeway":
			causeway_count += 1
			var emitted: AABB = mass["aabb"]
			if absf(emitted.get_center().x - causeway.get_center().x) > 0.05:
				crosses = false
	if causeway_count != 1 or not crosses or causeway.size.x < WALK_WIDTH_MIN:
		failures.append("moat: causeway does not cross the water at walkable width")
	stats["moat_crossings"] = causeway_count if crosses else 0


func _check_climb() -> void:
	var meta: Dictionary = _plan.world_meta
	var bounds: Rect2 = meta["moat"].grow(1.0)
	_climb_grid = WalkGrid.new()
	_climb_grid.setup(bounds, float(meta.get("walk_cell", 0.25)))
	_climb_grid.add_floor(meta["causeway"], 0.0)
	for ring in meta.get("rings", []):
		for segment in MountainGenerator.gallery_segments(ring):
			_climb_grid.add_floor(segment, float(ring["level"]))
	for stair in meta.get("stairs", []):
		var rect: Rect2 = stair["rect"]
		if rect.size.x < WALK_WIDTH_MIN:
			failures.append("climb: %s is narrower than 1.2m" % String(stair["id"]))
		var rise: float = stair.get("rise", 0.0)
		if rise <= 0.0 or rise > WalkGrid.MAX_STEP + 0.001:
			failures.append("climb: %s has an unwalkable %.2fm riser" % [String(stair["id"]), rise])
		_climb_grid.add_floor(rect, float(stair["level"]))
	_climb_grid.add_floor(meta["summit"], float(meta["summit_level"]))
	_climb_grid.build(0.35)
	var start: Vector2 = meta["causeway_start"]
	if not _climb_grid.flood_from(start, 0.75):
		failures.append("climb: no standable start on the causeway")
	elif not _climb_grid.reached(meta["summit"]):
		failures.append("climb: linked walks and stairs do not reach the summit")
	stats["climb_walkable_area"] = snappedf(_climb_grid.walkable_area(), 0.1)


func _check_pradakshina() -> void:
	var rings: Array = _plan.world_meta.get("rings", [])
	for i in range(rings.size()):
		var ring: Dictionary = rings[i]
		var rect: Rect2 = ring["rect"]
		var grid := WalkGrid.new()
		grid.setup(rect.grow(1.0), float(_plan.world_meta.get("walk_cell", 0.25)))
		var segments := MountainGenerator.gallery_segments(ring)
		if segments.size() != 4:
			failures.append("pradakshina: gallery %d is missing a loop segment" % i)
			continue
		for segment in segments:
			grid.add_floor(segment, float(ring["level"]))
		grid.build(0.35)
		var start := Vector2(0.0, rect.position.y + float(ring["gallery_width"]) * 0.5)
		if not grid.flood_from(start, 0.75):
			failures.append("pradakshina: gallery %d has no start" % i)
			continue
		for segment in segments:
			if not grid.reached(segment):
				failures.append("pradakshina: gallery %d does not return to its start" % i)
				break


func _check_rite_rules() -> void:
	# Reuse TempleRiteCheck's own measured symmetry and dominance procedures.
	# Its temple-specific input is a small ziggurat projection of this mountain;
	# the separate quincunx rule below checks the actual summit towers.
	_spec = TempleSpec.new()
	_spec.form = &"ziggurat"
	_spec.width = _plan.spec.width
	_spec.length = _plan.spec.length
	_spec.height = 15.0
	_spec.terraces = 3
	_spec.idol_height = 4.0
	_spec.altar_w = 1.5
	_spec.altar_l = 1.2
	_spec.altar_h = 0.8
	_spec.dais_height = 1.0
	_spec.dais_steps = 2
	_spec.idol_width = 1.5
	_spec.pit = false
	_builder = TempleBuilder.new()
	_builder.mass_log = _mountain_builder.mass_log.duplicate(true)
	_check_symmetry()
	var symmetry_failures := failures.duplicate()
	failures.clear()
	_check_dominance()
	var inherited_dominance_failures := failures.duplicate()
	failures.clear()
	# Preserve the inherited rule results while measuring the actual tower family.
	failures.append_array(symmetry_failures)
	failures.append_array(inherited_dominance_failures)
	var center_mass := _mass("tower_center")
	if center_mass.is_empty():
		failures.append("dominance: central tower is missing")
		return
	var center_box: AABB = center_mass["aabb"]
	for mass in _mountain_builder.mass_log:
		var name := String(mass["name"])
		if name == "tower_center" or name.begins_with("water_") or name == "causeway":
			continue
		var other: AABB = mass["aabb"]
		if other.end.y > center_box.end.y + 0.05:
			failures.append("dominance: %s reaches above the central tower" % name)
			break


## WORLD-MESH-VERIFY. The walks, gates and walls above are judged on the mass
## log; here the emitted triangles must really carry them. `emitted_mesh` is
## optional: without it the builder's own surfaces are read.
func _check_mesh(emitted_mesh: ArrayMesh) -> void:
	var stone := MeshProbe.surface_triangles(_mountain_builder, emitted_mesh, MountainBuilder.STONE)
	var roof := MeshProbe.surface_triangles(_mountain_builder, emitted_mesh, MountainBuilder.ROOF)
	var water := MeshProbe.surface_triangles(_mountain_builder, emitted_mesh, MountainBuilder.WATER)
	if stone.is_empty() or roof.is_empty() or water.is_empty():
		failures.append("mesh_support: an emitted stone, roof or water surface has no triangles")
		return
	var meta: Dictionary = _plan.world_meta
	var all := stone + roof + water
	# Floors: causeway, every gallery side, every stair step, the summit.
	_require_floor(stone, "causeway", meta["causeway"], 0.08, [0.15, 0.5, 0.85], [0.5])
	var rings: Array = meta["rings"]
	for i in range(rings.size()):
		var segments := MountainGenerator.gallery_segments(rings[i])
		for j in range(segments.size()):
			_require_floor(stone, "gallery %d side %d" % [i, j], segments[j],
				float(rings[i]["level"]), [0.2, 0.5, 0.8], [0.5])
	for stair in meta["stairs"]:
		var stair_rect: Rect2 = stair["rect"]
		_require_floor(stone, String(stair["id"]), stair_rect,
			float(stair["level"]) + float(stair["rise"]), [0.5], [0.25, 0.75])
	var summit: Rect2 = meta["summit"]
	_require_floor(stone, "summit", summit, float(meta["summit_level"]),
		[0.1, 0.5, 0.9], [0.1, 0.5, 0.9])
	for mass in _mountain_builder.mass_log:
		var name := String(mass.get("name", ""))
		if name.begins_with("water_"):
			var box: AABB = mass["aabb"]
			var water_rect := Rect2(Vector2(box.position.x, box.position.z),
				Vector2(box.size.x, box.size.z))
			_require_floor(water, name, water_rect, box.end.y, [0.25, 0.75], [0.5])
	# Occupied volume: wall tops and tower roofs exist, and each wall really
	# stops a body walking out of its ring (the gate gap is tested separately).
	for i in range(rings.size()):
		var ring: Dictionary = rings[i]
		var r: Rect2 = ring["rect"]
		var level := float(ring["level"])
		var t := float(ring["wall_thickness"])
		var h := float(ring["wall_height"])
		var mid := level + h * 0.5
		var half_gate := float(ring["gate_width"]) * 0.5
		var cz := r.get_center().y
		var rays: Array = [
			["east", Vector3(r.end.x - t - 0.3, mid, cz), Vector3(r.end.x + 0.3, mid, cz)],
			["west", Vector3(r.position.x + t + 0.3, mid, cz), Vector3(r.position.x - 0.3, mid, cz)],
			["south", Vector3(0.0, mid, r.end.y - t - 0.3), Vector3(0.0, mid, r.end.y + 0.3)],
			["north_left", Vector3(-half_gate - 2.0, mid, r.position.y + t + 0.3),
				Vector3(-half_gate - 2.0, mid, r.position.y - 0.3)],
			["north_right", Vector3(half_gate + 2.0, mid, r.position.y + t + 0.3),
				Vector3(half_gate + 2.0, mid, r.position.y - 0.3)],
		]
		for ray in rays:
			if not MeshProbe.ray_blocked(all, ray[1], ray[2]):
				failures.append("mesh_enclosure: ring %d %s wall does not stop the walk out" %
					[i, ray[0]])
		var wall_rect := Rect2(Vector2(r.position.x, r.end.y - t), Vector2(r.size.x, t))
		_require_floor(stone, "ring %d south wall top" % i, wall_rect, level + h,
			[0.2, 0.5, 0.8], [0.5])
		# Aperture: the axial gate is open at body height through the wall.
		var gate: Dictionary = meta["gopuras"][i]
		var gate_h := float(gate["height"])
		var clear_x := (float(gate["width"]) - 2.0) * 0.3
		var z := r.position.y + t * 0.5
		var closed := 0
		for x in [-clear_x, 0.0, clear_x]:
			for y in [level + 0.9, level + gate_h - 1.2]:
				if MeshProbe.ray_blocked(all, Vector3(x, y, z - 2.5), Vector3(x, y, z + 2.5)):
					closed += 1
		if closed > 0:
			failures.append("mesh_aperture: gopura %d is closed at %d/6 body-height rays" % [i, closed])
	for mass in _mountain_builder.mass_log:
		var name := String(mass.get("name", ""))
		if name.begins_with("tower_"):
			var box: AABB = mass["aabb"]
			var tower_rect := Rect2(Vector2(box.position.x, box.position.z),
				Vector2(box.size.x, box.size.z))
			_require_floor(roof, name + " roof", tower_rect, box.end.y, [0.25, 0.75], [0.25, 0.75])
			var mid_y := box.get_center().y
			var c := box.get_center()
			if not MeshProbe.ray_blocked(roof, Vector3(box.position.x - 0.5, mid_y, c.z),
					Vector3(box.end.x + 0.5, mid_y, c.z)):
				failures.append("mesh_enclosure: %s is not a solid emitted volume" % name)


func _require_floor(triangles: Array, label: String, rect: Rect2, y: float,
		along: Array, across: Array) -> void:
	var samples := MeshProbe.rect_samples(rect, along, across)
	var hits := MeshProbe.supported_count(triangles, samples, y)
	if hits != samples.size():
		failures.append("mesh_support: %s has top triangles at %d/%d probes" %
			[label, hits, samples.size()])


func _mass(name: String) -> Dictionary:
	for mass in _mountain_builder.mass_log:
		if String(mass.get("name", "")) == name:
			return mass
	return {}
