import io

p = 'tests/suites/house_archetype_suite.gd'
s = io.open(p, encoding='utf-8').read()

# call it at the end of run()
idx = s.rindex('\treturn res')
s = s[:idx] + '\t_round_tower(res)\n' + s[idx:]

body = '''

## The round tower: one octagonal room to a storey, three storeys (GEO-002).
##
## The archetypes above all come out of `HouseGenerator`, which partitions a
## rectangle -- so none of them can be this. The tower is built here instead,
## which is the honest place for it: the planner does not yet lay out shaped
## rooms, and what GEO-002 delivered is the REPRESENTATION and every rule that
## reads it. This is the demo that proves those rules hold on a plan a
## rectangle cannot describe, judged by the same HouseQA every house is.
const TOWER_SIDES := 8
const TOWER_STOREYS := 3

static func _round_tower(res: SuiteResult) -> void:
	for across in [8.0, 11.0]:
		var plan: HousePlan = _tower_plan(across, TOWER_STOREYS,
			int(4400 + across * 10.0))
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "round_tower %.0fm" % across
		res.checked += 1

		for i in range(plan.room_count()):
			if not plan.is_polygonal(i):
				res.fail("%s: room %d lost its outline" % [who, i])
				continue
			var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, i)
			if walls.size() != TOWER_SIDES:
				res.fail("%s: room %d has %d walls, not %d"
					% [who, i, walls.size(), TOWER_SIDES])
		# nothing may stand outside the shape, which is the whole point of
		# carrying an outline rather than a box
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			var poly: PackedVector2Array = plan.outline_of(int(p["room"]))
			var r: Rect2 = p["rect"]
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end,
					Vector2(r.position.x, r.end.y)]:
				if not Poly.contains_point(poly, c, 0.02):
					res.fail("%s: %s stands outside the outline of room %d"
						% [who, String(p["key"]), int(p["room"])])
					break

		var rep: Dictionary = HouseQA.new().check(plan, builder)
		if not rep["ok"]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
		for w in rep["warnings"]:
			res.warn("%s: %s" % [who, str(w)])


## An octagon to a storey, inscribed in the spec's own square, with a door on
## the edge nearest the front and a window every other edge.
static func _tower_plan(across: float, storeys: int, sd: int) -> HousePlan:
	var spec := HouseSpec.new(sd)
	spec.style = &"townhouse"
	spec.width = across
	spec.length = across
	spec.height = 2.8
	spec.storeys = storeys
	spec.room_count = storeys
	spec.variant_name = "Round Tower"
	spec.clutter = 0.5
	var plan := HousePlan.new()
	plan.spec = spec
	var poly: PackedVector2Array = _octagon(HouseGeometry.interior_rect(spec))
	var kinds: Array[StringName] = [&"hall", &"bedroom", &"bedroom"]
	for level in range(storeys):
		plan.rooms.append({"kind": kinds[level % kinds.size()],
			"rect": Poly.bounding_rect(poly), "outline": poly, "storey": level})

	var walls: Array[Dictionary] = HouseGeometry.polygon_walls(poly)
	var front := 0
	for k in range(walls.size()):
		if walls[k]["normal"].y > walls[front]["normal"].y:
			front = k
	var w: Dictionary = walls[front]
	plan.doors = [{"a": 0, "b": -1,
		"pos": (Vector2(w["from"]) + Vector2(w["to"])) / 2.0,
		"normal": -Vector2(w["normal"]), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	for level2 in range(storeys):
		for k2 in range(walls.size()):
			if (level2 == 0 and k2 == front) or k2 % 2 != 0:
				continue
			var wall: Dictionary = walls[k2]
			plan.windows.append({"room": level2,
				"pos": (Vector2(wall["from"]) + Vector2(wall["to"])) / 2.0,
				"normal": -Vector2(wall["normal"]),
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": level2})
	for level3 in range(storeys - 1):
		HousePlanner._add_stair(plan, level3, level3 + 1, level3, level3 + 1)
	HouseFurnisher.furnish(plan, spec)
	return plan


static func _octagon(inner: Rect2) -> PackedVector2Array:
	var c: Vector2 = inner.get_center()
	var k: float = 1.0 / cos(PI / float(TOWER_SIDES))
	var out := PackedVector2Array()
	for i in range(TOWER_SIDES):
		var a: float = TAU * (float(i) + 0.5) / float(TOWER_SIDES)
		out.append(c + Vector2(cos(a) * inner.size.x / 2.0 * k,
			sin(a) * inner.size.y / 2.0 * k))
	return out
'''
s = s.rstrip('\n') + body
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
