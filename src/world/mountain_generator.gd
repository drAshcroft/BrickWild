class_name MountainGenerator
extends RefCounted
## WLD-011: three rising gallery enclosures, one moat crossing, and a summit
## quincunx. The plan is the geometry authority for both emission and QA.

const FAMILY := &"temple_mountain"
const KIND := &"angkor_mountain"
const MOAT_WIDTH := 20.0
const GALLERY_WIDTH := 4.0
const WALL_T := 1.2
const GATE_WIDTH := 5.5
const STAIR_WIDTH := 2.4
const WALK_CELL := 0.25


static func generate(_kind: StringName, seed: int, width: float, length: float,
		height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 120.0, 380.0)
	spec.length = clampf(length, 120.0, 380.0)
	spec.height = clampf(height, 30.0, 90.0)
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = WALL_T
	spec.roof_type = &"flat"
	spec.roof_pitch = 0.0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.variant_name = "Temple Mountain"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = KIND
	var outer := Rect2(Vector2(-spec.width * 0.5 + MOAT_WIDTH,
		-spec.length * 0.5 + MOAT_WIDTH),
		Vector2(spec.width - MOAT_WIDTH * 2.0, spec.length - MOAT_WIDTH * 2.0))
	var rings: Array[Dictionary] = []
	for i in range(3):
		var inset := float(i) * minf(outer.size.x, outer.size.y) * 0.15
		var rect := outer.grow(-inset)
		rings.append({"rect": rect, "level": float(i) * spec.height * 0.12,
			"gallery_width": GALLERY_WIDTH, "wall_thickness": WALL_T,
			"wall_height": clampf(spec.height * 0.1, 4.0, 6.0),
			"gate_width": GATE_WIDTH})
	var moat := outer.grow(MOAT_WIDTH)
	var causeway := Rect2(Vector2(-STAIR_WIDTH * 0.5, moat.position.y),
		Vector2(STAIR_WIDTH, outer.position.y - moat.position.y))
	var stairs := _stair_flights(rings)
	var top_level: float = rings[2]["level"]
	var inner_rect: Rect2 = rings[2]["rect"]
	var summit_inset := Vector2(GALLERY_WIDTH, GALLERY_WIDTH)
	var summit := Rect2(inner_rect.position + summit_inset,
		inner_rect.size - summit_inset * 2.0)
	var tower_offset := minf(summit.size.x, summit.size.y) * 0.3
	var central_height := spec.height * 0.72
	var towers: Array[Dictionary] = [
		{"id": "tower_center", "pos": Vector2.ZERO,
			"level": top_level, "height": central_height, "width": 5.0},
	]
	for pos in [Vector2(-tower_offset, -tower_offset), Vector2(tower_offset, -tower_offset),
			Vector2(tower_offset, tower_offset), Vector2(-tower_offset, tower_offset)]:
		towers.append({"id": "tower_corner_%d" % towers.size(),
			"pos": pos, "level": top_level,
			"height": central_height / 1.25, "width": 4.0})
	var gopuras: Array[Dictionary] = []
	for i in range(rings.size()):
		var ring: Dictionary = rings[i]
		gopuras.append({"id": "gopura_%d" % i,
			"center": Vector2(0.0, ring["rect"].position.y), "level": ring["level"],
			"width": GATE_WIDTH, "height": ring["wall_height"]})
	plan.world_meta = {"rings": rings, "moat": moat, "moat_width": MOAT_WIDTH,
		"outer": outer, "causeway": causeway, "causeway_start": Vector2(0.0, moat.position.y + 0.5),
		"stairs": stairs, "summit": summit, "summit_level": top_level,
		"towers": towers, "gopuras": gopuras, "walk_cell": WALK_CELL,
		"total_height": top_level + central_height}
	return {"spec": spec, "plan": plan}


static func gallery_segments(ring: Dictionary) -> Array[Rect2]:
	if ring.has("gallery_segments"):
		var authored: Array[Rect2] = []
		for segment in ring["gallery_segments"]:
			authored.append(segment)
		return authored
	var r: Rect2 = ring["rect"]
	var w: float = ring["gallery_width"]
	return [
		Rect2(Vector2(r.position.x, r.position.y), Vector2(r.size.x, w)),
		Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)),
		Rect2(Vector2(r.position.x, r.position.y + w), Vector2(w, r.size.y - 2.0 * w)),
		Rect2(Vector2(r.end.x - w, r.position.y + w), Vector2(w, r.size.y - 2.0 * w)),
	]


static func _stair_flights(rings: Array[Dictionary]) -> Array[Dictionary]:
	var flights: Array[Dictionary] = []
	for i in range(rings.size() - 1):
		var lower: Dictionary = rings[i]
		var upper: Dictionary = rings[i + 1]
		var lower_rect: Rect2 = lower["rect"]
		var upper_rect: Rect2 = upper["rect"]
		var z0 := lower_rect.position.y + float(lower["gallery_width"]) * 0.75
		var z1 := upper_rect.position.y + float(upper["gallery_width"]) * 0.25
		var count := maxi(int(ceil((float(upper["level"]) - float(lower["level"])) / 0.5)), 1)
		for step in range(count):
			var t0 := float(step) / float(count)
			var t1 := float(step + 1) / float(count)
			var z_start := lerpf(z0, z1, t0)
			var z_end := lerpf(z0, z1, t1)
			flights.append({"id": "stair_%d_tread_%d" % [i, step],
				"rect": Rect2(Vector2(-STAIR_WIDTH * 0.5, z_start),
					Vector2(STAIR_WIDTH, z_end - z_start)),
				"level": lerpf(float(lower["level"]), float(upper["level"]), t0),
				"rise": (float(upper["level"]) - float(lower["level"])) / float(count),
				"width": STAIR_WIDTH, "flight": i})
	return flights
