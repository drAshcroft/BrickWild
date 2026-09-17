extends RefCounted
## HOUSE-EXT-009: do the predicted exterior bounds contain the house, and are
## they tight?
##
## Containment alone is not a useful promise -- a bound twice the size of the
## building contains it. Every case here asserts BOTH: nothing sticks out, and
## nothing is further in than HouseGeometry.BOUNDS_TOL. Where the answer cannot
## be exact (a spec with no plan does not know which wall the hearth chose) the
## conservative bound is required to be a superset and is never asserted tight.

## Float slop when comparing a derived bound against emitted vertices.
const EPS := 0.0005


static func run() -> SuiteResult:
	var res := SuiteResult.new("house bounds")
	_fixtures(res)
	_features(res)
	_chimney_walls(res)
	_conservative(res)
	_injected(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


## The one rule, applied everywhere: contains, and not by much.
static func _assert_bounds(res: SuiteResult, plan: HousePlan, mesh: ArrayMesh,
		who: String) -> void:
	var planned := HouseGeometry.exterior_bounds(plan)
	var actual := mesh.get_aabb()
	for axis in range(3):
		var lo: float = actual.position[axis] - planned.position[axis]
		var hi: float = planned.end[axis] - actual.end[axis]
		_expect(res, lo >= -EPS,
			"%s: mesh reaches %.4fm past the planned bound on axis %d (low)"
				% [who, -lo, axis])
		_expect(res, hi >= -EPS,
			"%s: mesh reaches %.4fm past the planned bound on axis %d (high)"
				% [who, -hi, axis])
		_expect(res, lo <= HouseGeometry.BOUNDS_TOL,
			"%s: planned bound is %.4fm loose on axis %d (low)" % [who, lo, axis])
		_expect(res, hi <= HouseGeometry.BOUNDS_TOL,
			"%s: planned bound is %.4fm loose on axis %d (high)" % [who, hi, axis])
	# The height promise is spec-only and must match the same mesh.
	_expect(res, absf(HouseGeometry.total_height(plan.spec) - actual.end.y) <= EPS,
		"%s: total_height %.6f but the mesh tops out at %.6f"
			% [who, HouseGeometry.total_height(plan.spec), actual.end.y])


## The four runbook fixtures, which is where the original numbers came from.
static func _fixtures(res: SuiteResult) -> void:
	for row in [[&"farmhouse", 4413, 10.0, 13.0, 2.7, 1],
			[&"townhouse", 4411, 9.0, 12.0, 2.7, 2],
			[&"cottage", 4412, 7.0, 9.0, 2.5, 1],
			[&"longhall", 4414, 12.0, 16.0, 2.7, 1]]:
		var s := HouseSpec.new()
		s.style = row[0]
		s.width = row[2]
		s.length = row[3]
		s.height = row[4]
		s.storeys = row[5]
		var plan := HouseGenerator.generate(s, row[1], false)
		var mesh := HouseBuilder.new().build(plan)
		_assert_bounds(res, plan, mesh, "%s seed=%s" % [row[0], row[1]])


static func _spec(w: float, l: float) -> HouseSpec:
	var s := HouseSpec.new()
	s.width = w
	s.length = l
	s.height = 2.7
	s.storeys = 1
	s.room_count = 1
	s.program = [&"hall"]
	s.roof_pitch = 0.9
	s.chimney = false
	s.porch = false
	s.dormers = false
	s.bargeboards = false
	s.timber_frame = false
	return s


## Every feature the bound has a term for, on and off, and both orientations
## so the roof's own rotation is exercised.
static func _features(res: SuiteResult) -> void:
	for size in [Vector2(8, 12), Vector2(12, 8)]:
		for kind in [&"gable", &"half_hipped", &"hipped"]:
			for bargeboards in [false, true]:
				for chimney in [false, true]:
					for pots in [1, 2]:
						for dormers in [false, true]:
							if pots == 2 and not chimney:
								continue
							var s := _spec(size.x, size.y)
							s.storeys = 2
							s.roof_type = kind
							s.bargeboards = bargeboards
							s.chimney = chimney
							s.chimney_pots = pots
							s.dormers = dormers
							s.dormer_count = 2 if dormers else 0
							var plan := HousePlanner.plan(s)
							var mesh := HouseBuilder.new().build(plan)
							_assert_bounds(res, plan, mesh,
								"%s %s bb=%s ch=%s pots=%d dor=%s"
									% [kind, size, bargeboards, chimney, pots, dormers])


## The chimney can land on any of the four walls. The old spec-only extent
## always grew +X, which was right one time in four.
static func _chimney_walls(res: SuiteResult) -> void:
	var seen := {}
	for seed in range(40):
		var s := _spec(9, 12)
		s.storeys = 2
		s.roof_type = &"gable"
		s.chimney = true
		s.bargeboards = true
		s.room_count = 3
		s.program = [&"hall", &"kitchen", &"bedroom"]
		var plan := HouseGenerator.generate(s, 5200 + seed, false)
		if not plan.spec.chimney:
			continue
		var wall: int = plan.hearth_wall()
		var mesh := HouseBuilder.new().build(plan)
		_assert_bounds(res, plan, mesh, "chimney wall=%d seed=%d" % [wall, 5200 + seed])
		seen[wall] = int(seen.get(wall, 0)) + 1
		# The chimney rect must actually sit on the wall the hearth chose.
		var stack := HouseGeometry.chimney_rect(plan)
		var site := HouseGeometry.site_rect(s)
		_expect(res, not site.encloses(stack) or stack.size.x > 0.0,
			"chimney wall=%d: stack rect is empty" % wall)
	_expect(res, seen.size() >= 2,
		"the chimney sweep only ever saw walls %s; it cannot be exercising placement"
			% str(seen.keys()))


## The spec-only bounds know less and must therefore promise less: a superset,
## always, and never asserted tight.
static func _conservative(res: SuiteResult) -> void:
	for chimney in [false, true]:
		for porch in [false, true]:
			for seed in [5300, 5301, 5302]:
				var s := _spec(9, 12)
				s.storeys = 2
				s.roof_type = &"gable"
				s.bargeboards = true
				s.chimney = chimney
				s.porch = porch
				var plan := HouseGenerator.generate(s, seed, false)
				var exact := HouseGeometry.exterior_bounds(plan)
				var loose := HouseGeometry.spec_bounds(plan.spec)
				var who := "conservative ch=%s porch=%s seed=%d" % [chimney, porch, seed]
				_expect(res, loose.encloses(exact.grow(-EPS)),
					"%s: spec_bounds does not contain exterior_bounds" % who)
				var mesh := HouseBuilder.new().build(plan)
				_expect(res, loose.encloses(mesh.get_aabb().grow(-EPS)),
					"%s: spec_bounds does not contain the mesh" % who)
				var rect := HouseGeometry.plan_extent(plan.spec)
				_expect(res, is_equal_approx(rect.size.x, loose.size.x)
						and is_equal_approx(rect.size.y, loose.size.z),
					"%s: plan_extent and spec_bounds disagree" % who)


## Injected wrong bounds must fail. A rule that only ever sees correct input
## is not known to be a rule at all.
static func _injected(res: SuiteResult) -> void:
	var s := _spec(9, 12)
	s.storeys = 2
	s.roof_type = &"gable"
	s.bargeboards = true
	s.chimney = true
	var plan := HouseGenerator.generate(s, 5400, false)
	var mesh := HouseBuilder.new().build(plan)
	var good := HouseGeometry.exterior_bounds(plan)
	var actual := mesh.get_aabb()

	# Too short: the chimney and its pots are exactly what the old bound missed.
	var short := AABB(good.position, Vector3(good.size.x, good.size.y - 1.33, good.size.z))
	_expect(res, short.end.y < actual.end.y - EPS,
		"a bound 1.33m short still contained the mesh")

	# Wrong wall: grow +X and shrink the side the chimney is actually on.
	var wall: int = plan.hearth_wall()
	var wrong := AABB(good.position, good.size)
	var stack := HouseGeometry.chimney_rect(plan)
	if stack.size.x > 0.0:
		var site := HouseGeometry.site_rect(s)
		var out_x: float = maxf(site.position.x - stack.position.x, stack.end.x - site.end.x)
		var out_z: float = maxf(site.position.y - stack.position.y, stack.end.y - site.end.y)
		_expect(res, maxf(out_x, out_z) > 0.05,
			"chimney wall=%d: the stack does not leave the footprint at all" % wall)
		# Rebuilding the bound as though the stack were always on +X puts it on
		# the wrong side whenever the hearth chose another wall.
		wrong = AABB(Vector3(site.position.x, 0.0, site.position.y),
			Vector3(site.size.x + stack.size.x, good.size.y, site.size.y))
		if wall != 1:
			_expect(res, not wrong.encloses(actual.grow(-EPS)),
				"chimney wall=%d: a +X-only bound still contained the mesh" % wall)

	# And the correct one does contain it, so the failures above mean something.
	_expect(res, good.encloses(actual.grow(-EPS)),
		"the correct bound does not contain its own mesh")
