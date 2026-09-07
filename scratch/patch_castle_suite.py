import io

p = 'tests/suites/castle_suite.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		var got: StringName = CastleSpec.tier_for(band[0], band[1])
		if got != band[2]:
			res.fail("tier_for(%.0f, %.0f) = %s, expected %s"
				% [band[0], band[1], String(got), String(band[2])])
	return res'''
new = '''		var got: StringName = CastleSpec.tier_for(band[0], band[1])
		if got != band[2]:
			res.fail("tier_for(%.0f, %.0f) = %s, expected %s"
				% [band[0], band[1], String(got), String(band[2])])

	_great_hall(res)
	return res


## The great hall has an inside (CAS-010).
##
## The hall used to be a logged mass with nothing in it. It is now a
## single-room HousePlan, which means the whole house harness judges it: the
## plan check for the room and its openings, the furnishing check for what
## stands in it, the nav check for whether a person can walk it. So the
## assertions below are only the ones the house harness has no name for -- the
## things that make a hall a HALL rather than a large room:
##
##   the room IS the hall range, less its walls
##   the dais is at the end away from the door, a step high, a fifth deep
##   the high table stands on the dais and is what the plan is arranged around
##   nobody sits between the high table and the hall
##   the trestles are rows, and there is a screens passage inside the door
##
## Everything else is delegated, on purpose. A hall that failed `tiling` or
## `row` or `steps` should be reported by the rule that owns those words.
static func _great_hall(res: SuiteResult) -> void:
	var halls := 0
	var two_rows := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.hall_plan(spec)
		var who := "great hall: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			# a range too small to feast in gets no plan rather than a bad one
			continue
		halls += 1

		if plan.room_count() != 1 or plan.kind_of(0) != &"great_hall":
			res.fail("%s: %d rooms, first is %s -- a hall is one room"
				% [who, plan.room_count(), String(plan.kind_of(0))])
			continue
		# the room is the hall range, less the wall it is inside
		var box: AABB = CastleGeometry.hall_aabb(spec)
		var want := Vector2(box.size.x, box.size.z) - Vector2.ONE * HouseGeometry.WALL_T * 2.0
		var floor_rect: Rect2 = plan.rooms[0]["rect"]
		if not floor_rect.size.is_equal_approx(want):
			res.fail("%s: the room is %.2f x %.2fm, the range inside its walls is %.2f x %.2fm"
				% [who, floor_rect.size.x, floor_rect.size.y, want.x, want.y])

		# the dais: at the far end from the door, a step up, a fifth of the hall
		var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
		var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
		var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
		var dais: Rect2 = plan.dais_rect()
		var rise: float = plan.dais_rise()
		if dais.size.x <= 0.0:
			res.fail("%s: no dais" % who)
			continue
		if rise < 0.3 or rise > 0.6:
			res.fail("%s: the dais rises %.2fm -- that is a stair, or nothing"
				% [who, rise])
		if rise > WalkGrid.MAX_STEP:
			res.fail("%s: the dais rises %.2fm and WalkGrid walks up %.2fm"
				% [who, rise, WalkGrid.MAX_STEP])
		var depth: float = dais.size.y if lengthwise else dais.size.x
		if depth < run * 0.2 - 0.01:
			res.fail("%s: the dais is %.2fm of a %.2fm hall -- under a fifth"
				% [who, depth, run])
		var door: Vector2 = plan.doors[plan.entrance()]["pos"]
		if (dais.get_center() - door).dot(up) < run * 0.4:
			res.fail("%s: the dais is at the same end of the hall as the door" % who)

		# the high table stands ON it, and is what the hall is arranged around
		if plan.focus_cat() != "table" or plan.focus_room() != 0:
			res.fail("%s: the hall is not arranged around a table" % who)
			continue
		var high := -1
		for f in range(plan.furniture.size()):
			var q: Dictionary = plan.furniture[f]
			if PropCatalog.category(String(q["key"])) != "table":
				continue
			if dais.has_point(Rect2(q["rect"]).get_center()):
				high = f
		if high < 0:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: nothing stands on the dais" % who)
			continue
		var hc: Vector2 = Rect2(plan.furniture[high]["rect"]).get_center()
		# on the dais means ON it: the piece is lifted by the rise
		var lifted: float = float(plan.furniture[high]["pos"].y)
		if not is_equal_approx(lifted, rise):
			res.fail("%s: the high table stands at y=%.2f on a %.2fm dais"
				% [who, lifted, rise])
		# and nobody sits between it and the hall
		for f2 in range(plan.furniture.size()):
			var seat: Dictionary = plan.furniture[f2]
			var cat: String = PropCatalog.category(String(seat["key"]))
			if cat != "seat" and cat != "bench":
				continue
			var sc: Vector2 = Rect2(seat["rect"]).get_center()
			if sc.distance_to(hc) > HIGH_TABLE_REACH:
				continue
			if (sc - hc).dot(up) < -0.05:
				res.fail("%s: a %s sits between the high table and the hall"
					% [who, String(seat["key"])])
				break

		# the trestles are rows
		var groups := {}
		for q2 in plan.furniture:
			var g: String = String(q2.get("row", ""))
			if g != "":
				groups[g] = int(groups.get(g, 0)) + 1
		if groups.is_empty() and not plan.was_dropped(0, "table"):
			res.fail("%s: no trestle row and no note of why not" % who)
		for g2 in groups:
			if int(groups[g2]) < 2:
				res.fail("%s: row %s is one table -- that is not a row" % [who, g2])
		if groups.size() >= 2:
			two_rows += 1

		# the fire is on a long wall, where the flue can rise
		var long_walls := [2, 3] if lengthwise else [0, 1]
		if not plan.hearth_wall() in long_walls:
			res.fail("%s: the fire is on wall %d, an end wall of the hall"
				% [who, plan.hearth_wall()])

		# and the screens passage is inside the door, and empty
		var strip := Rect2()
		for z in plan.zones:
			if String(z.get("why", "")) == "screens passage":
				strip = Rect2(z["rect"])
		if strip.size.x <= 0.0:
			res.fail("%s: no screens passage" % who)
		else:
			var deep: float = strip.size.y if lengthwise else strip.size.x
			if deep < HouseGeometry.PATH_MIN:
				res.fail("%s: the screens passage is %.2fm -- you cannot walk it"
					% [who, deep])
			if (strip.get_center() - door).dot(up) > run * 0.5:
				res.fail("%s: the screens passage is not by the door" % who)

		# and the house harness has its say
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("great hall  %2d of %d ranges furnished, %d with two trestle rows"
		% [halls, ranges.size(), two_rows])


## How near the high table a seat has to be before it counts as being AT it.
const HIGH_TABLE_REACH := 2.5'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
