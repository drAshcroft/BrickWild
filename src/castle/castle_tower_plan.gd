class_name CastleTowerPlan
extends RefCounted
## Pure HousePlan for a tower-house shaft.
##
## The castle builder owns the stone emission.  This file owns only the local
## floor programme: one actual storey outline per level, the raised entrance,
## windows on those outlines, and the stair wells between adjacent floors.
## The outlines deliberately carry the per-storey wall thickness and outer
## footprint so an emitter cannot quietly substitute the tower's AABB.

const OVAL_SIDES := 24
const NARROW_OVAL_SIDES := 12
const MIN_WINDOW_EDGE := 0.9
const MIN_WINDOW_WIDTH := 0.3
const STAIR_RUN := 1.8
const STAIR_WIDTH := 0.9


## HousePlanCheck's ordinary upstairs rule is for dwellings.  A tower-house
## has a store at the foot, a hall above it, and chambers at the top, so expose
## the same explicit room-programme hook as KeepSpec without changing the
## shared house checker.
class TowerSpec extends HouseSpec:
	func max_storeys() -> int:
		return 6

	func allows_hearth_furniture() -> bool:
		return false

	func room_program(count: int) -> Array[StringName]:
		var out: Array[StringName] = []
		for level in range(maxi(count, 1)):
			if level == 0:
				out.append(&"store")
			elif level == 1:
				out.append(&"hall")
			elif level == count - 1:
				out.append(&"lords_chamber")
			else:
				out.append(&"parlour")
		return out

	func kind_on(level: int) -> StringName:
		var rows := room_program(storeys)
		return rows[level] if level >= 0 and level < rows.size() else &"store"


static func generate(source: CastleSpec, with_furniture := true) -> HousePlan:
	var plan := HousePlan.new()
	if not CastleGeometry.is_tower_house(source):
		return plan

	var levels := maxi(source.tower_storeys, 1)
	var storey_h := CastleGeometry.tower_storey_height(source)
	var top := CastleGeometry.tower_storey_aabb(source, levels - 1)
	var hs := TowerSpec.new(source.seed ^ 0x54_4F_57_52)
	hs.material = &"stone"
	hs.style = &"townhouse"
	hs.width = top.size.x
	hs.length = top.size.z
	hs.height = storey_h
	hs.storeys = levels
	hs.room_count = levels
	hs.program = hs.room_program(levels)
	hs.variant_name = "%s: tower-house shaft" % source.variant_name
	hs.wall_color = source.stone_color
	hs.trim_color = source.trim_color
	hs.roof_color = source.roof_color
	hs.floor_color = source.stone_color.darkened(0.35)
	hs.plinth_height = 0.0
	hs.porch = false
	hs.chimney = false
	hs.exterior_props = false
	hs.clutter = 0.35
	plan.spec = hs

	for level in range(levels):
		var outer := CastleGeometry.tower_storey_aabb(source, level)
		var thickness := CastleGeometry.tower_wall_thickness(source, level)
		var clear := _inner_outline(source, outer, thickness)
		plan.rooms.append({
			"kind": hs.kind_on(level),
			"storey": level,
			"rect": Poly.bounding_rect(clear),
			"outline": clear,
			"outer_aabb": outer,
			"outer_outline": _outer_outline(source, outer),
			"wall_thickness": thickness,
		})

	# The tower is entered at the real sill, not at a fictitious ground door.
	var sill := CastleGeometry.tower_door_sill(source)
	var door_h := minf(storey_h * 0.7, 2.6)
	var door_level := clampi(int(floor(sill / maxf(storey_h, 0.01))), 0, levels - 1)
	var front := _front_wall(plan, door_level)
	# Use the actual faceted wall chord. A small wizard shaft has a short
	# front chord even when its AABB suggests room for a full-size door.
	var front_length := Vector2(front["from"]).distance_to(Vector2(front["to"]))
	var door_width := minf(minf(source.width * 0.25, 1.4),
		maxf(0.45, front_length - 2.0 * HouseGeometry.DOOR_CORNER_MARGIN))
	var local_sill := sill - float(door_level) * storey_h
	var door_pos := (Vector2(front["from"]) + Vector2(front["to"])) * 0.5
	var door_normal := -Vector2(front["normal"])
	plan.doors.append({
		"a": door_level,
		"b": -1,
		"pos": door_pos,
		"normal": door_normal,
		"width": door_width,
		"exterior": true,
		"front": true,
		"storey": door_level,
		"sill": local_sill,
		"head": local_sill + door_h,
		"elevated": true,
	})

	_add_windows(plan, source, storey_h, door_level, door_width)
	_add_stairs(plan, levels)

	# Jog blocks are real exterior masses with partial height.  They are not
	# silently reported as rooms until a later emitter has a matching L-shaped
	# shell path; retain an explicit omission for every one.
	for index in range(CastleGeometry.tower_jog_aabbs(source).size()):
		plan.exterior_omissions.append("tower_jog_%d: exterior solid retained; no occupied room" % index)

	if with_furniture:
		HouseFurnisher.furnish(plan, hs)
	return plan


## A narrow shaft needs enough wall run for a human-width entrance while
## retaining the same faceted outline in the plan and emitted drum.
static func oval_sides(source: CastleSpec) -> int:
	var box := CastleGeometry.tower_house_aabb(source)
	return NARROW_OVAL_SIDES if maxf(box.size.x, box.size.z) <= 10.0 else OVAL_SIDES


## Clear-floor outline for a storey.  The wizard shaft is the same 24-facet
## ellipse used by the oval-ring emitter; other tower houses remain rectangles.
static func _inner_outline(source: CastleSpec, outer: AABB,
		thickness: float) -> PackedVector2Array:
	if source.style == &"wizard":
		return _ellipse(outer.size.x * 0.5 - thickness,
			outer.size.z * 0.5 - thickness, oval_sides(source))
	var clear := Vector2(maxf(outer.size.x - 2.0 * thickness, 0.2),
		maxf(outer.size.z - 2.0 * thickness, 0.2))
	return Poly.from_rect(Rect2(-clear * 0.5, clear))


static func _outer_outline(source: CastleSpec, outer: AABB) -> PackedVector2Array:
	if source.style == &"wizard":
		return _ellipse(outer.size.x * 0.5, outer.size.z * 0.5, oval_sides(source))
	return Poly.from_rect(Rect2(-Vector2(outer.size.x, outer.size.z) * 0.5,
		Vector2(outer.size.x, outer.size.z)))


static func _ellipse(rx: float, rz: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	# The 12-facet narrow variant puts a full face on the entrance axis; with
	# a vertex on the axis the front face would turn 15 degrees off square.
	var phase := -PI / 2.0 - PI / float(sides) if sides == NARROW_OVAL_SIDES else 0.0
	for i in range(sides):
		var a := phase + TAU * float(i) / float(sides)
		out.append(Vector2(cos(a) * maxf(rx, 0.1), sin(a) * maxf(rz, 0.1)))
	return out


static func _front_wall(plan: HousePlan, level: int) -> Dictionary:
	var walls := HouseGeometry.room_walls(plan, level)
	var best: Dictionary = walls[0] if not walls.is_empty() else {
		"from": Vector2(-1, 0), "to": Vector2(1, 0), "normal": Vector2(0, 1)}
	var score := -INF
	for wall in walls:
		var outward := -Vector2(wall["normal"])
		var candidate := outward.dot(Vector2(0, -1))
		if candidate > score:
			score = candidate
			best = wall
	return best


static func _add_windows(plan: HousePlan, source: CastleSpec, storey_h: float,
		door_level: int, door_width: float) -> void:
	# The foot is blind, and every higher storey receives openings on its actual
	# polygon edges.  The door edge is left clear on the entry storey.
	for level in range(plan.room_count()):
		if level == 0:
			continue
		var height := minf(source.window_h, storey_h * 0.42)
		var sill := minf(maxf(0.8, storey_h * 0.30), storey_h - height - 0.15)
		if height < 0.35 or sill < 0.2:
			continue
		for wall in HouseGeometry.room_walls(plan, level):
			var from: Vector2 = wall["from"]
			var to: Vector2 = wall["to"]
			var length := from.distance_to(to)
			if length < MIN_WINDOW_EDGE:
				continue
			var outward := -Vector2(wall["normal"])
			if level == door_level and outward.dot(Vector2(0, -1)) > 0.9:
				continue
			var pos := (from + to) * 0.5
			var width := minf(source.window_w, length * 0.45)
			if width < MIN_WINDOW_WIDTH:
				continue
			plan.windows.append({"room": level, "pos": pos, "normal": outward,
				"width": width, "sill": sill, "head": sill + height,
				"storey": level})


static func _add_stairs(plan: HousePlan, levels: int) -> void:
	for level in range(levels - 1):
		var lower := HouseGeometry.room_floor_poly(plan, level)
		var upper := HouseGeometry.room_floor_poly(plan, level + 1)
		var lower_box := Poly.bounding_rect(lower)
		var upper_box := Poly.bounding_rect(upper)
		var min_side := minf(minf(lower_box.size.x, lower_box.size.y),
			minf(upper_box.size.x, upper_box.size.y))
		var run := minf(STAIR_RUN, maxf(0.8, min_side * 0.35))
		var width := minf(STAIR_WIDTH, maxf(0.55, min_side * 0.22))
		var best := Rect2()
		var best_score := -INF
		var entry := plan.doors[plan.entrance()]
		var door_line := HousePlanLevels.door_line(plan, int(entry["storey"]), entry)
		var walls := HouseGeometry.room_walls(plan, level)
		walls.append_array(HouseGeometry.room_walls(plan, level + 1))
		for size in [Vector2(run, width), Vector2(width, run)]:
			for wall in walls:
				var normal: Vector2 = wall["normal"]
				var support: float = (absf(normal.x) * size.x + absf(normal.y) * size.y) * 0.5
				var from: Vector2 = wall["from"]
				var to: Vector2 = wall["to"]
				var length := from.distance_to(to)
				var samples := maxi(int(length / 0.12), 1)
				for step in range(samples + 1):
					var centre: Vector2 = from.lerp(to, float(step) / float(samples)) + normal * support
					var candidate := Rect2(centre - size * 0.5, size)
					if not _inside(lower, candidate) or not _inside(upper, candidate):
						continue
					if level == int(entry["storey"]) and _overlap(candidate, door_line):
						continue
					var score: float = centre.distance_to(Vector2(entry["pos"]))
					for prior in plan.stairs:
						if int(prior["b"]) == level or int(prior["a"]) == level + 1:
							if candidate.intersects(Rect2(prior["rect"])):
								score -= 1000.0
							else:
								score += centre.distance_to(Rect2(prior["rect"]).get_center())
					if score > best_score:
						best = candidate
						best_score = score
		if best.size.x <= 0.0:
			# The absence is explicit. HousePlanCheck will report the missing
			# storey transition instead of claiming a stair in solid masonry.
			continue
		var footprint := best
		plan.stairs.append({"a": level, "b": level + 1, "storey": level,
			"to_storey": level + 1, "pos": footprint.get_center(),
			"lower_pos": footprint.get_center(), "upper_pos": footprint.get_center(),
			"rect": footprint, "lower_rect": footprint, "upper_rect": footprint,
			"width": width, "run": run})


static func _inside(outline: PackedVector2Array, rect: Rect2) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(outline, point, 0.001):
			return false
	return true


static func _overlap(a: Rect2, b: Rect2) -> bool:
	var overlap := a.intersection(b)
	return overlap.size.x > 0.02 and overlap.size.y > 0.02
