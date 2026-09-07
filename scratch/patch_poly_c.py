import io

p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	var inner: Rect2 = HouseGeometry.interior_rect(plan.spec)
	var sums := {}
	for i in range(n):
		var a: Rect2 = plan.rooms[i]["rect"]
		var level := HousePlan.record_storey(plan.rooms[i])
		sums[level] = float(sums.get(level, 0.0)) + a.size.x * a.size.y
		if not inner.grow(TOL).encloses(a):
			failures.append("tiling: room %d (%s) sticks out of the interior"
				% [i, String(plan.kind_of(i))])
		for j in range(i + 1, n):
			var b: Rect2 = plan.rooms[j]["rect"]
			if HousePlan.record_storey(plan.rooms[i]) != HousePlan.record_storey(plan.rooms[j]):
				continue
			var over: Rect2 = a.intersection(b)
			if over.size.x > TOL and over.size.y > TOL:
				failures.append("tiling: rooms %d (%s) and %d (%s) overlap by %.2f x %.2fm"
					% [i, String(plan.kind_of(i)), j, String(plan.kind_of(j)),
						over.size.x, over.size.y])
	var want: float = inner.size.x * inner.size.y
	stats["interior_area"] = snappedf(want, 0.01)
	for level in sums:
		var sum: float = float(sums[level])
		if absf(sum - want) > 0.05 * want:
			failures.append("tiling: storey %d rooms cover %.1f m2 of a %.1f m2 interior -- there is floor nobody owns"
				% [int(level), sum, want])'''
new = '''	var inner: Rect2 = HouseGeometry.interior_rect(plan.spec)
	var sums := {}
	var shaped := {}
	for i in range(n):
		var a: Rect2 = plan.rooms[i]["rect"]
		var level := HousePlan.record_storey(plan.rooms[i])
		sums[level] = float(sums.get(level, 0.0)) + HouseGeometry.room_area(plan, i)
		if plan.is_polygonal(i):
			shaped[level] = true
		if not inner.grow(TOL).encloses(a):
			failures.append("tiling: room %d (%s) sticks out of the interior"
				% [i, String(plan.kind_of(i))])
		for j in range(i + 1, n):
			if HousePlan.record_storey(plan.rooms[i]) != HousePlan.record_storey(plan.rooms[j]):
				continue
			# Rectangles are compared as rectangles, so a house reads exactly
			# as it always did; a room that carries an outline is compared as
			# the shape it actually is (GEO-001, GEO-002).
			if plan.is_polygonal(i) or plan.is_polygonal(j):
				var lap: float = Poly.intersection_area(plan.outline_of(i),
					plan.outline_of(j))
				if lap > TOL:
					failures.append("tiling: rooms %d (%s) and %d (%s) overlap by %.2f m2"
						% [i, String(plan.kind_of(i)), j, String(plan.kind_of(j)), lap])
				continue
			var b: Rect2 = plan.rooms[j]["rect"]
			var over: Rect2 = a.intersection(b)
			if over.size.x > TOL and over.size.y > TOL:
				failures.append("tiling: rooms %d (%s) and %d (%s) overlap by %.2f x %.2fm"
					% [i, String(plan.kind_of(i)), j, String(plan.kind_of(j)),
						over.size.x, over.size.y])
	var want: float = inner.size.x * inner.size.y
	stats["interior_area"] = snappedf(want, 0.01)
	for level in sums:
		# A storey of rectangles PARTITIONS the interior: every square metre
		# belongs to some room, and floor nobody owns is a planner bug. A
		# storey with a shaped room does not and should not -- the corners an
		# octagon cuts off are masonry, and that is what makes it a tower --
		# so the rule that stands there is "no room leaves the interior and no
		# two overlap", which has already been measured above.
		if shaped.has(level):
			continue
		var sum: float = float(sums[level])
		if absf(sum - want) > 0.05 * want:
			failures.append("tiling: storey %d rooms cover %.1f m2 of a %.1f m2 interior -- there is floor nobody owns"
				% [int(level), sum, want])'''
assert old in s, 'tiling'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
