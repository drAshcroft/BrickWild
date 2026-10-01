class_name MosqueGenerator
extends RefCounted
## WLD-004 hypostyle mosque. The grid lives on HousePlan so the builder and
## every rule read the same authored columns.

const FAMILY := &"mosque"

static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = maxf(width, 60.0)
	spec.length = maxf(length, 40.0)
	spec.height = maxf(height, 8.0)
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.8
	spec.roof_pitch = 0.0
	spec.roof_type = &"flat"
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.variant_name = "Hall of a Thousand Pillars"
	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	var hall_width := spec.width * 0.82
	var hall_depth := spec.length * 0.63
	var hall := Rect2(Vector2(-hall_width * 0.5, -hall_depth * 0.5),
		Vector2(hall_width, hall_depth))
	var court_size := minf(spec.width * 0.38, spec.length * 0.28)
	var sahn := Rect2(Vector2(-court_size * 0.5, hall.position.y - court_size),
		Vector2(court_size, court_size))
	var qibla := Rect2(Vector2(hall.position.x, hall.end.y - 0.8), Vector2(hall.size.x, 0.8))
	var aisle_count := 11
	var rows := 5
	var pitch := hall_width / float(aisle_count + 1)
	var centre_gap := pitch * 1.35
	var side_span := hall_width - centre_gap
	var side_pitch := side_span / float(aisle_count - 1)
	var usable_depth := hall_depth * 0.78
	var row_pitch := usable_depth / float(rows - 1)
	for row in range(rows):
		var z := hall.position.y + hall_depth * 0.11 + float(row) * row_pitch
		for file in range((aisle_count - 1) / 2):
			for side in [-1.0, 1.0]:
				var x: float = float(side) * (centre_gap * 0.5 + float(file) * side_pitch)
				plan.columns.append({"pos": Vector3(x, 0.0, z), "radius": 0.32,
					"height": spec.height * 0.72, "role": &"hypostyle"})
	# The two points either side of the centre aisle are symmetric; the missing
	# centre line is deliberate and leaves an uninterrupted route to the mihrab.
	plan.courts.append({"rect": sahn, "storey": 0, "id": "sahn"})
	plan.doors.append({"a": -1, "b": -1, "pos": Vector2(0.0, hall.position.y),
		"normal": Vector2(0.0, -1.0), "width": 4.2, "exterior": true,
		"front": true, "storey": 0, "role": "sahn_entry"})
	plan.roof_openings.append({"id": "sahn_sky", "kind": &"compluvium",
		"storey": 0, "face": -1, "rect": sahn, "impluvium": Rect2(
		Vector2(sahn.get_center().x - court_size * 0.12, sahn.get_center().y - court_size * 0.12),
		Vector2(court_size * 0.24, court_size * 0.24))})
	var water: Rect2 = plan.roof_openings[0]["impluvium"]
	plan.furniture.append({"key": "Fountain", "room": -1,
		"pos": Vector3(water.get_center().x, 0.04, water.get_center().y),
		"yaw": 0.0, "rect": water, "zone": water, "host": -1,
		"cat": "fountain", "storey": 0, "mounted": false, "world_water": true})
	var minaret_width := maxf(5.0, spec.width * 0.075)
	var minaret := Rect2(Vector2(hall.end.x + 2.0, hall.position.y + hall.size.y * 0.12),
		Vector2(minaret_width, minaret_width))
	plan.world_meta = {"hall_rect": hall, "qibla_wall": qibla,
		"mihrab": Rect2(Vector2(-1.8, hall.end.y - 1.8), Vector2(3.6, 1.8)),
		"sahn_rect": sahn, "sahn_door": Vector2(0.0, hall.position.y),
		"aisle_count": aisle_count, "row_count": rows, "file_pitch": side_pitch,
		"central_aisle": centre_gap, "row_pitch": row_pitch,
		"minaret_rect": minaret, "minaret_height": spec.height * 1.55,
		"standable_floor": hall.size.x * hall.size.y - plan.columns.size() * 0.64 * 0.64}
	return {"spec": spec, "plan": plan}
