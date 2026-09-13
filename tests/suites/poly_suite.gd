class_name PolySuite
extends RefCounted
## GEO-001: Poly's static helpers, and WalkGrid's polygon rasterisation
## against the rectangle path it has to stay identical to.

static func run() -> SuiteResult:
	var res := SuiteResult.new("poly")
	_check_area(res)
	_check_edge_point(res)
	_check_closed_polygon(res)
	_check_intersection(res)
	_check_offset(res)
	_check_hull(res)
	_check_walk_grid_rect_equivalence(res)
	_check_walk_grid_octagon(res)
	return res


static func _unit_square() -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(0, 0))
	p.append(Vector2(1, 0))
	p.append(Vector2(1, 1))
	p.append(Vector2(0, 1))
	return p


static func _check_area(res: SuiteResult) -> void:
	res.checked += 1
	var a: float = Poly.area(_unit_square())
	if not is_equal_approx(a, 1.0):
		res.fail("unit square area = %f, want 1.0" % a)


static func _check_edge_point(res: SuiteResult) -> void:
	var sq: PackedVector2Array = _unit_square()
	for p in [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.0, 0.0)]:
		res.checked += 1
		if not Poly.contains_point(sq, p):
			res.fail("point on edge %s did not count as inside" % p)
	res.checked += 1
	if Poly.contains_point(sq, Vector2(1.5, 0.5)):
		res.fail("point clearly outside the square counted as inside")


static func _check_intersection(res: SuiteResult) -> void:
	var a: PackedVector2Array = _unit_square()
	var b := PackedVector2Array()
	b.append(Vector2(0.5, 0.0))
	b.append(Vector2(1.5, 0.0))
	b.append(Vector2(1.5, 1.0))
	b.append(Vector2(0.5, 1.0))
	res.checked += 1
	var overlap: float = Poly.intersection_area(a, b)
	if not is_equal_approx(overlap, 0.5):
		res.fail("half-overlapping unit squares intersect at %f, want 0.5" % overlap)


static func _check_closed_polygon(res: SuiteResult) -> void:
	var open := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(0, 2)])
	var hull := Geometry2D.convex_hull(open)
	var repeated := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, 0)])
	for row in [
		[Vector2(0.25, 0.25), true], [Vector2(1, 1), true],
		[Vector2.ZERO, true], [Vector2(1.5, 1.5), false],
		[Vector2(2.05, 1), false], [Vector2(-0.05, 1), false]]:
		res.checked += 1
		for poly in [open, hull, repeated]:
			if Poly.contains_point(poly, row[0]) != row[1]:
				res.fail("closed/repeated polygon misclassified %s (expected %s)" % [row[0], row[1]])
	var a := WalkGrid.new()
	var b := WalkGrid.new()
	for grid in [a, b]:
		grid.setup(Rect2(-1, -1, 4, 4), 0.12)
	a.add_floor_poly(open)
	b.add_floor_poly(hull)
	res.checked += 1
	if a._free != b._free:
		res.fail("closed hull changed polygon floor rasterization")


static func _check_offset(res: SuiteResult) -> void:
	var sq: PackedVector2Array = _unit_square()
	var grown: PackedVector2Array = Poly.offset(sq, 1.0)
	var got: float = Poly.area(grown)
	# Exact for a convex polygon grown with rounded corners: old area, plus
	# perimeter * d (the four strips along the edges), plus pi * d^2 (the
	# four quarter-circles at the corners, which together make one full
	# circle of radius d).
	var perimeter := 4.0
	var d := 1.0
	var want: float = 1.0 + perimeter * d + PI * d * d
	res.checked += 1
	if absf(got - want) / want > 0.02:
		res.fail("offset square area = %f, want ~%f (within 2%%)" % [got, want])


static func _check_hull(res: SuiteResult) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var cloud := PackedVector2Array()
	for i in range(60):
		cloud.append(Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)))
	var hull: PackedVector2Array = Poly.convex_hull(cloud)
	res.checked += 1
	if hull.size() < 3:
		res.fail("hull of 60-point cloud degenerated to %d points" % hull.size())
		return
	var missed := 0
	for p in cloud:
		if not Poly.contains_point(hull, p):
			missed += 1
	res.checked += 1
	if missed > 0:
		res.fail("hull does not contain %d of %d cloud points" % [missed, cloud.size()])


static func _check_walk_grid_rect_equivalence(res: SuiteResult) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(10):
		var w: float = rng.randf_range(1.0, 6.0)
		var h: float = rng.randf_range(1.0, 6.0)
		var rect := Rect2(Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)), Vector2(w, h))
		var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))

		var grid_rect := WalkGrid.new()
		grid_rect.setup(bounds, 0.12)
		grid_rect.add_floor(rect)

		var grid_poly := WalkGrid.new()
		grid_poly.setup(bounds, 0.12)
		grid_poly.add_floor_poly(Poly.from_rect(rect))

		res.checked += 1
		if grid_rect._free != grid_poly._free:
			res.fail("rect polygon rasterisation != add_floor(Rect2) on rect #%d %s" % [i, rect])


static func _check_walk_grid_octagon(res: SuiteResult) -> void:
	# A regular octagon: radius r, so area = 2 * (1 + sqrt(2)) * s^2 where
	# s = r * sin(pi/8) * 2 ... simplest to just use the standard closed form
	# for a regular n-gon: area = 0.5 * n * r^2 * sin(2*pi/n).
	var r := 3.0
	var n := 8
	var octagon := PackedVector2Array()
	for i in range(n):
		var ang: float = TAU * float(i) / float(n)
		octagon.append(Vector2(cos(ang), sin(ang)) * r)
	var analytic: float = 0.5 * float(n) * r * r * sin(TAU / float(n))

	var cell := 0.1
	var bounds := Rect2(Vector2(-4, -4), Vector2(8, 8))
	var grid := WalkGrid.new()
	grid.setup(bounds, cell)
	grid.add_floor_poly(octagon)

	var measured: float = grid.walkable_area()
	# walkable_area() reads _walk, which needs build() first to be populated;
	# read _free directly via the floor area instead.
	var free_cells := 0
	for b in grid._free:
		if b == 1:
			free_cells += 1
	var free_area: float = float(free_cells) * cell * cell

	var perimeter: float = 0.0
	for i in range(n):
		perimeter += octagon[i].distance_to(octagon[(i + 1) % n])
	var tolerance: float = perimeter * cell

	res.checked += 1
	if absf(free_area - analytic) > tolerance:
		res.fail("octagon rasterised area %f vs analytic %f, outside one cell-row tolerance %f" \
			% [free_area, analytic, tolerance])

	# No holes: every row of the bounding box that touches the octagon at all
	# is a single contiguous run of filled cells (true for any convex shape;
	# a hole or a broken run would show up as filled cells outside the run).
	var x0: int = grid.cell_of(Vector2(-4, -4)).x
	var x1: int = grid.cell_of(Vector2(4, 4)).x
	var z0: int = grid.cell_of(Vector2(-4, -4)).y
	var z1: int = grid.cell_of(Vector2(4, 4)).y
	var broken_rows := 0
	for z in range(z0, z1 + 1):
		var xs: Array[int] = []
		for x in range(x0, x1 + 1):
			if grid.at(grid._free, x, z) == 1:
				xs.append(x)
		if xs.is_empty():
			continue
		var run: int = xs[xs.size() - 1] - xs[0] + 1
		if run != xs.size():
			broken_rows += 1
	res.checked += 1
	if broken_rows > 0:
		res.fail("octagon rasterisation has %d row(s) with a hole" % broken_rows)
