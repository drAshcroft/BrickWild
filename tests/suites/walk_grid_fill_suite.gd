extends RefCounted
## `wgridfill`: WalkGrid's polygon fill (VILLAGE-DRESS-STRAND-COST).
##
## `_fill_poly` is a scanline; `_fill_poly_exact` is the point test per cell it
## replaced. The scanline must paint exactly the cells the point test does, on
## every polygon a village hands the grid (concave stars, road ribbons, L-shaped
## yards, rectangles on the cell lines, a repeated closing vertex), floor and
## obstacle, over a grid that already holds something. And it must be fast: the
## point test took 15 s to paint a walk grid of the islet's 310 x 123 m site,
## and the fishing strand's dressing built that grid for every boat it placed.

## The same two outlines painted both ways on a grid of this size: the scanline
## must be at least this many times faster than the point test (13x on the
## islet's 310 x 123 m site, loaded host). A relative figure, so a busy host
## does not move it; the point test itself would read 1x.
const SPEED_CELL := 0.25
const SPEED_VERTICES := 120
const SPEED_MIN_RATIO := 5.0
const SPEED_SIZE := Vector2(50.0, 30.0)


static func run() -> SuiteResult:
	var res := SuiteResult.new("wgridfill")
	var t0 := Time.get_ticks_msec()
	_same(res)
	_fast(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _grid(cell: float, origin: Vector2, size: Vector2) -> WalkGrid:
	var g := WalkGrid.new()
	g.setup(Rect2(origin, size), cell)
	return g


## Both grids start with the same scatter, so a fill that clears what it should
## leave (or leaves what it should paint) shows.
static func _scatter(a: WalkGrid, b: WalkGrid, rng: RandomNumberGenerator) -> void:
	for i in range(a._free.size()):
		var v: int = 1 if rng.randf() < 0.5 else 0
		a._free[i] = v
		b._free[i] = v
		a._level[i] = 0.5 if v == 1 else 0.0
		b._level[i] = a._level[i]


static func _star(rng: RandomNumberGenerator, centre: Vector2, r: float, n: int, snap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var ang: float = TAU * float(i) / float(n)
		var rr: float = r * rng.randf_range(0.3, 1.0)
		var p := centre + Vector2(cos(ang), sin(ang)) * rr
		if snap > 0.0:
			p = p.snapped(Vector2(snap, snap))
		out.append(p)
	return out


static func _polys(rng: RandomNumberGenerator, cell: float, origin: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var c := origin + Vector2(20.0, 15.0)
	for n in [8, 9, 12, 25, 60]:
		out.append(_star(rng, c, 12.0, n, 0.0))
		out.append(_star(rng, c + Vector2(3.0, 2.0), 9.0, n, 0.05))      # on a 5 cm lattice
		out.append(_star(rng, c, 10.0, n, cell * 0.5))                   # vertices on cell centres and lines
	# an L-shaped yard and a rectangle with edges ON the cell centres' lines
	var x: float = origin.x + 10.0 * cell + cell * 0.5
	var z: float = origin.y + 12.0 * cell + cell * 0.5
	out.append(PackedVector2Array([Vector2(x, z), Vector2(x + 20 * cell, z), Vector2(x + 20 * cell, z + 6 * cell),
		Vector2(x + 8 * cell, z + 6 * cell), Vector2(x + 8 * cell, z + 18 * cell), Vector2(x, z + 18 * cell),
		Vector2(x, z + 9 * cell), Vector2(x, z + 4 * cell)]))
	out.append(Poly.from_rect(Rect2(x, z, 30 * cell, 24 * cell)))
	# a road ribbon along a wandering line, and with the closing vertex repeated
	var line := PackedVector2Array()
	for i in range(12):
		line.append(origin + Vector2(4.0 + 3.0 * i, 20.0 + 4.0 * sin(float(i) * 0.9) + rng.randf_range(-0.3, 0.3)))
	out.append(Poly.ribbon(line, 1.6))
	var rib: PackedVector2Array = Poly.ribbon(line, 2.6)
	rib.append(rib[0])
	out.append(rib)
	# a near-horizontal sliver and a thin diagonal
	out.append(PackedVector2Array([c + Vector2(-15, 0), c + Vector2(15, 0.0004), c + Vector2(15, 2.0),
		c + Vector2(-15, 2.0), c + Vector2(-16, 1.0), c + Vector2(-17, 0.5), c + Vector2(-17, 0.2), c + Vector2(-16, 0.1)]))
	out.append(PackedVector2Array([c, c + Vector2(30, 30), c + Vector2(30.4, 29.7), c + Vector2(0.4, -0.3),
		c + Vector2(0.2, -0.4), c + Vector2(0.1, -0.2), c + Vector2(0.05, -0.1), c + Vector2(0.01, -0.05)]))
	return out


static func _same(res: SuiteResult) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var polys_n := 0
	var cells_n := 0
	for cell in [0.125, 0.4]:
		for origin in [Vector2(-33.3, -20.0), Vector2(0.0, 0.0), Vector2(-40.0125, -25.0125)]:
			var polys := _polys(rng, cell, origin)
			for value in [1, 0]:
				for p in polys:
					var a := _grid(cell, origin, Vector2(40.0, 30.0))
					var b := _grid(cell, origin, Vector2(40.0, 30.0))
					_scatter(a, b, rng)
					a._fill_poly(p, value, 0.3)
					b._fill_poly_exact(p, value, 0.3)
					polys_n += 1
					res.checked += 1
					if a._free != b._free or a._level != b._level:
						var diff := 0
						for i in range(a._free.size()):
							if a._free[i] != b._free[i]:
								diff += 1
						res.fail("cell %.2f origin %s value %d, %d vertices: the scanline differs from the point test in %d cells" % [
							cell, str(origin), value, p.size(), diff])
					cells_n += a._free.size()
	res.note("%d polygons painted both ways, %d cells compared" % [polys_n, cells_n])


static func _fast(res: SuiteResult) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var origin := -SPEED_SIZE * 0.5
	var poly := _star(rng, Vector2.ZERO, 12.0, SPEED_VERTICES, 0.0)
	var big := PackedVector2Array()
	for i in range(SPEED_VERTICES):                    # a shore outline: wide, many vertices
		var t: float = float(i) / float(SPEED_VERTICES) * TAU
		big.append(Vector2(cos(t) * 23.0, sin(t) * (13.0 + 1.0 * sin(t * 17.0))))
	var g := _grid(SPEED_CELL, origin, SPEED_SIZE)
	var t0 := Time.get_ticks_usec()
	g._fill_poly(big, 1)
	g._fill_poly(poly, 0)
	var fast_s := (Time.get_ticks_usec() - t0) / 1e6
	var h := _grid(SPEED_CELL, origin, SPEED_SIZE)
	t0 = Time.get_ticks_usec()
	h._fill_poly_exact(big, 1)
	h._fill_poly_exact(poly, 0)
	var exact_s := (Time.get_ticks_usec() - t0) / 1e6
	res.checked += 2
	if g._free != h._free:
		res.fail("the two %d-vertex outlines painted differently" % SPEED_VERTICES)
	if fast_s * SPEED_MIN_RATIO > exact_s:
		res.fail("two %d-vertex outlines over %d cells: the scanline took %.2f s, the point test %.2f s; wants %.0fx faster" % [
			SPEED_VERTICES, g._free.size(), fast_s, exact_s, SPEED_MIN_RATIO])
	res.note("two %d-vertex outlines over %d cells: scanline %.2f s, point test %.2f s (%.0fx)" % [
		SPEED_VERTICES, g._free.size(), fast_s, exact_s, exact_s / maxf(fast_s, 1e-6)])
