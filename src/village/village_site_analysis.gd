class_name VillageSiteAnalysis
extends RefCounted
## Reading the ground before a village planner places anything
## (docs/VILLAGE_TERRAIN.md, "Reading the ground: VillageSiteAnalysis").
##
## A pure, deterministic analysis of a VillageTerrain over a site Rect2 at an
## analysis cell (default 5 m, never finer than the terrain cell / 2). Per cell:
## slope (rise over run), wet, distance to water, topographic position (TPI)
## and a LANDFORM CLASS. Over the site: contour polylines, D8 drainage and the
## streams it implies, connected level regions. The frame is the terrain's:
## SITE metres, x east, the second coordinate +Z south; row 0 is the north row.
##
## The analysis is computed on a PADDED grid: the site plus up to
## TPI_OUTER_M of the terrain around it (where the terrain has it), so a cell
## at the site edge is judged against the ground beyond the edge, and water
## just outside the site still makes a shore inside it. Where the terrain
## itself ends, the TPI annulus is clipped and the reading near that edge is
## biased; leave a margin of ground round a site.
##
## Classes, in the order they are decided (first that applies):
##   water         ground at or below water_level_m (a DEM flattens a lake or
##                 the sea to exactly its surface, so equality is wet; this is
##                 deliberately inclusive where VillageTerrain.is_wet is strict)
##   shore         dry, within SHORE_M of a wet cell
##   crest         TPI >= TPI_HIGH_M and within SUMMIT_DROP_M of the highest
##                 ground within SUMMIT_REACH_M: the top of a hill
##   spur          TPI >= TPI_HIGH_M, not a summit, and a RIDGE: in one of the
##                 four axis directions the ground RIDGE_REACH_M away on both
##                 sides is at least RIDGE_DROP_M lower
##   valley_floor  TPI <= TPI_LOW_M and gentle (< VALLEY_FLOOR_MAX) or a
##                 TROUGH (both sides RIDGE_DROP_M higher in one direction)
##   bench         slope < LEVEL_MAX with steep ground (>= BENCH_STEEP) both
##                 BENCH_RELIEF_M above and BENCH_RELIEF_M below within
##                 BENCH_REACH_M: a level shelf in a slope
##   flat          slope < FLAT_MAX (= CART_MAX) otherwise: gentle, no notable relief
##   open_slope    everything else
## A saddle (pass) centre reads `flat`: level, and its ridge and trough cancel
## in the TPI. The suite states that.
##
## Slope: each cell is cut into k x k facets (k = ceil(cell / terrain cell)),
## each facet's gradient taken from its four corners; `slope` is the mean
## facet slope (the landform), `slope_max` the steepest facet (buildability).
## A coarse centre proves only its centre; the steepest facet proves the cell.

const CART_MAX := 0.12          ## a loaded cart climbs it (12 %)
const PLOT_MAX := 0.35          ## a house plot, stepped plinth at most (35 %)
const PATH_MAX := 0.60          ## a footpath; beyond this, steps or nothing
const LEVEL_MAX := 0.08         ## level ground: a bench, a level region (8 %)
## `flat` is ground a cart crosses in any direction: below CART_MAX, with no
## notable relief round it. 8 % would leave Monpazier's rolling plateau
## (median slope 10 % on the 30 m grid) two-thirds open_slope.
const FLAT_MAX := CART_MAX
const VALLEY_FLOOR_MAX := 0.20  ## a low cell steeper than this is a valley SIDE
const BENCH_STEEP := 0.15       ## the slope above and below a bench
const BENCH_REACH_M := 60.0
const BENCH_RELIEF_M := 2.0
const TPI_INNER_M := 30.0       ## TPI annulus: square ring 30..150 m
const TPI_OUTER_M := 150.0
const TPI_HIGH_M := 10.0        ## above its surroundings by this: crest/spur candidate
const TPI_LOW_M := -10.0        ## below by this: valley candidate
const SUMMIT_REACH_M := 60.0
const SUMMIT_DROP_M := 3.0
const RIDGE_REACH_M := 30.0
const RIDGE_DROP_M := 3.0
const SHORE_M := 30.0
const STREAM_AREA_M2 := 50000.0  ## 5 ha of catchment makes a stream
const STREAM_MIN_RELIEF_M := 2.0 ## below this the ground has no drainage to read
const CACHE_MAX := 8

const WATER := &"water"
const SHORE := &"shore"
const CREST := &"crest"
const SPUR := &"spur"
const VALLEY_FLOOR := &"valley_floor"
const BENCH := &"bench"
const FLAT := &"flat"
const OPEN_SLOPE := &"open_slope"
const CLASSES: Array[StringName] = [&"water", &"shore", &"crest", &"spur", &"valley_floor",
	&"bench", &"flat", &"open_slope"]
const _GLYPH := ["~", ",", "^", "A", "v", "=", "_", "."]
## buildable(p, use): the slope cap for each use.
const USES := {&"cart": CART_MAX, &"plot": PLOT_MAX, &"path": PATH_MAX, &"steps": INF}

static var _cache := {}
static var _cache_order: Array[String] = []

var terrain: VillageTerrain
var rect := Rect2()          ## the site as asked
var cell_m := 5.0            ## the analysis cell actually used
var nx := 0                  ## site cells east
var ny := 0                  ## site cells south
var water_level_m := NAN

var _errors: Array[String] = []
# padded grid: site cell (i, j) lives at padded (i - _i0, j - _j0)
var _i0 := 0
var _j0 := 0
var _pnx := 0
var _pny := 0
var _h := PackedFloat64Array()
var _slope := PackedFloat32Array()
var _slope_max := PackedFloat32Array()
var _tpi := PackedFloat32Array()
var _wet := PackedByteArray()
var _wdist := PackedFloat32Array()
var _summit := PackedFloat64Array()
var _steep_hi := PackedFloat64Array()
var _steep_lo := PackedFloat64Array()
var _class := PackedByteArray()   # site cells, index into CLASSES
var _hs := PackedFloat64Array()   # site cell heights, row-major
# drainage, lazily
var _drained := false
var _dir := PackedInt32Array()
var _acc := PackedInt32Array()


# ------------------------------------------------------------ construction

## The analysis of `ground` over `site` at `p_cell_m`, from the cache when the
## same ground, rectangle and cell were read before.
static func of(ground: VillageTerrain, site: Rect2, p_cell_m := 5.0) -> VillageSiteAnalysis:
	if ground == null:
		return compute(ground, site, p_cell_m)
	var key := "%s|%s|%s|%s|%s|%s" % [ground.fingerprint(), site.position.x, site.position.y,
		site.size.x, site.size.y, p_cell_m]
	if _cache.has(key):
		return _cache[key]
	var a := compute(ground, site, p_cell_m)
	_cache[key] = a
	_cache_order.append(key)
	while _cache_order.size() > CACHE_MAX:
		_cache.erase(_cache_order.pop_front())
	return a


static func clear_cache() -> void:
	_cache.clear()
	_cache_order.clear()


static func cache_size() -> int:
	return _cache.size()


## Uncached. Never throws: unreadable input comes back with errors() filled.
static func compute(ground: VillageTerrain, site: Rect2, p_cell_m := 5.0) -> VillageSiteAnalysis:
	var a := VillageSiteAnalysis.new()
	a.rect = site
	if ground == null or not ground.valid():
		a._errors.append("site analysis needs valid terrain")
		return a
	if site.size.x <= 0.0 or site.size.y <= 0.0:
		a._errors.append("site rectangle %s is empty" % site)
		return a
	a.terrain = ground
	a.water_level_m = ground.water_level_m
	a.cell_m = maxf(p_cell_m if p_cell_m > 0.0 else 5.0, ground.cell_m * 0.5)
	a.nx = maxi(1, int(ceil(site.size.x / a.cell_m - 1e-9)))
	a.ny = maxi(1, int(ceil(site.size.y / a.cell_m - 1e-9)))
	if a.nx * a.ny > 1_000_000:
		a._errors.append("%d x %d analysis cells; use a coarser cell" % [a.nx, a.ny])
		return a
	a._run()
	return a


func valid() -> bool:
	return _errors.is_empty() and terrain != null


func errors() -> Array[String]:
	return _errors.duplicate()


func _run() -> void:
	var a := cell_m
	var b := terrain.bounds()
	var kp := int(ceil(TPI_OUTER_M / a))
	_i0 = mini(0, maxi(-kp, int(ceil((b.position.x - rect.position.x) / a - 0.5 - 1e-9))))
	_j0 = mini(0, maxi(-kp, int(ceil((b.position.y - rect.position.y) / a - 0.5 - 1e-9))))
	var i1 := maxi(nx, mini(nx + kp, int(floor((b.end.x - rect.position.x) / a - 0.5 + 1e-9)) + 1))
	var j1 := maxi(ny, mini(ny + kp, int(floor((b.end.y - rect.position.y) / a - 0.5 + 1e-9)) + 1))
	_pnx = i1 - _i0
	_pny = j1 - _j0
	_heights_and_slopes()
	_water()
	_tpi_pass()
	_windows()
	_classify()


# ------------------------------------------------------------ the passes

func _heights_and_slopes() -> void:
	var a := cell_m
	var n := _pnx * _pny
	_h.resize(n)
	_slope.resize(n)
	_slope_max.resize(n)
	var ox := rect.position.x + _i0 * a
	var oy := rect.position.y + _j0 * a
	for pj in range(_pny):
		for pi in range(_pnx):
			_h[pj * _pnx + pi] = terrain.height_at(Vector2(ox + (pi + 0.5) * a, oy + (pj + 0.5) * a))
	# facet lattice: k sub-facets a cell, corners shared
	var k := maxi(1, int(ceil(a / terrain.cell_m - 1e-6)))
	var s := a / k
	var lx := _pnx * k + 1
	var ly := _pny * k + 1
	var lat := PackedFloat64Array()
	lat.resize(lx * ly)
	for y in range(ly):
		for x in range(lx):
			lat[y * lx + x] = terrain.height_at(Vector2(ox + x * s, oy + y * s))
	for pj in range(_pny):
		for pi in range(_pnx):
			var sum := 0.0
			var mx := 0.0
			for fy in range(k):
				for fx in range(k):
					var q := (pj * k + fy) * lx + pi * k + fx
					var h00 := lat[q]
					var h10 := lat[q + 1]
					var h01 := lat[q + lx]
					var h11 := lat[q + lx + 1]
					var gx := ((h10 + h11) - (h00 + h01)) / (2.0 * s)
					var gy := ((h01 + h11) - (h00 + h10)) / (2.0 * s)
					var sl := sqrt(gx * gx + gy * gy)
					sum += sl
					mx = maxf(mx, sl)
			_slope[pj * _pnx + pi] = sum / (k * k)
			_slope_max[pj * _pnx + pi] = mx


func _water() -> void:
	var n := _pnx * _pny
	_wet.resize(n)
	_wdist.resize(n)
	var any := false
	for c in range(n):
		var w := not is_nan(water_level_m) and _h[c] <= water_level_m
		_wet[c] = 1 if w else 0
		_wdist[c] = 0.0 if w else INF
		any = any or w
	if not any:
		return
	# two-pass chamfer distance between cell centres
	var a := cell_m
	var d := a * sqrt(2.0)
	for pj in range(_pny):
		for pi in range(_pnx):
			var c := pj * _pnx + pi
			var v := _wdist[c]
			if pi > 0:
				v = minf(v, _wdist[c - 1] + a)
			if pj > 0:
				v = minf(v, _wdist[c - _pnx] + a)
				if pi > 0:
					v = minf(v, _wdist[c - _pnx - 1] + d)
				if pi + 1 < _pnx:
					v = minf(v, _wdist[c - _pnx + 1] + d)
			_wdist[c] = v
	for pj in range(_pny - 1, -1, -1):
		for pi in range(_pnx - 1, -1, -1):
			var c := pj * _pnx + pi
			var v := _wdist[c]
			if pi + 1 < _pnx:
				v = minf(v, _wdist[c + 1] + a)
			if pj + 1 < _pny:
				v = minf(v, _wdist[c + _pnx] + a)
				if pi + 1 < _pnx:
					v = minf(v, _wdist[c + _pnx + 1] + d)
				if pi > 0:
					v = minf(v, _wdist[c + _pnx - 1] + d)
			_wdist[c] = v


## TPI = height minus the mean height in the square annulus TPI_INNER_M ..
## TPI_OUTER_M, by a summed-area table: O(cells), whatever the annulus.
func _tpi_pass() -> void:
	var w := _pnx + 1
	var sat := PackedFloat64Array()
	sat.resize(w * (_pny + 1))
	for pj in range(_pny):
		var row := 0.0
		for pi in range(_pnx):
			row += _h[pj * _pnx + pi]
			sat[(pj + 1) * w + pi + 1] = sat[pj * w + pi + 1] + row
	var ko := maxi(1, int(round(TPI_OUTER_M / cell_m)))
	var ki := maxi(0, int(round(TPI_INNER_M / cell_m)) - 1)
	_tpi.resize(_pnx * _pny)
	for pj in range(_pny):
		for pi in range(_pnx):
			var o := _box(sat, pi - ko, pj - ko, pi + ko, pj + ko)
			var inn := _box(sat, pi - ki, pj - ki, pi + ki, pj + ki)
			var cnt := o.y - inn.y
			var c := pj * _pnx + pi
			_tpi[c] = 0.0 if cnt <= 0.0 else _h[c] - (o.x - inn.x) / cnt


## (sum, count) over the inclusive padded box, clipped to the grid.
func _box(sat: PackedFloat64Array, i0: int, j0: int, i1: int, j1: int) -> Vector2:
	i0 = maxi(i0, 0)
	j0 = maxi(j0, 0)
	i1 = mini(i1, _pnx - 1)
	j1 = mini(j1, _pny - 1)
	if i1 < i0 or j1 < j0:
		return Vector2.ZERO
	var w := _pnx + 1
	var s := sat[(j1 + 1) * w + i1 + 1] - sat[j0 * w + i1 + 1] - sat[(j1 + 1) * w + i0] + sat[j0 * w + i0]
	return Vector2(s, (i1 - i0 + 1) * (j1 - j0 + 1))


func _windows() -> void:
	var n := _pnx * _pny
	var steep_h := PackedFloat64Array()
	var steep_l := PackedFloat64Array()
	steep_h.resize(n)
	steep_l.resize(n)
	for c in range(n):
		var st := _slope[c] >= BENCH_STEEP
		steep_h[c] = _h[c] if st else -INF
		steep_l[c] = _h[c] if st else INF
	_summit = _window(_h, int(round(SUMMIT_REACH_M / cell_m)), true)
	var kb := int(round(BENCH_REACH_M / cell_m))
	_steep_hi = _window(steep_h, kb, true)
	_steep_lo = _window(steep_l, kb, false)


## Separable square-window max (or min) of radius r cells, by van Herk /
## Gil-Werman: O(1) a cell whatever the radius.
func _window(src: PackedFloat64Array, r: int, want_max: bool) -> PackedFloat64Array:
	var sign := 1.0 if want_max else -1.0
	var tmp := PackedFloat64Array()
	tmp.resize(src.size())
	var out := PackedFloat64Array()
	out.resize(src.size())
	var line := PackedFloat64Array()
	line.resize(_pnx)
	for pj in range(_pny):
		for pi in range(_pnx):
			line[pi] = sign * src[pj * _pnx + pi]
		var m := _line_max(line, r)
		for pi in range(_pnx):
			tmp[pj * _pnx + pi] = m[pi]
	line.resize(_pny)
	for pi in range(_pnx):
		for pj in range(_pny):
			line[pj] = tmp[pj * _pnx + pi]
		var m := _line_max(line, r)
		for pj in range(_pny):
			out[pj * _pnx + pi] = sign * m[pj]
	return out


## Sliding max over [i - r, i + r] of a line, clipped at its ends.
static func _line_max(v: PackedFloat64Array, r: int) -> PackedFloat64Array:
	var n := v.size()
	var w := 2 * r + 1
	var e := n + 2 * r
	var g := PackedFloat64Array()
	var h := PackedFloat64Array()
	g.resize(e)
	h.resize(e)
	for i in range(e):
		var x := v[i - r] if i >= r and i - r < n else -INF
		g[i] = x if i % w == 0 else maxf(g[i - 1], x)
	for i in range(e - 1, -1, -1):
		var x := v[i - r] if i >= r and i - r < n else -INF
		h[i] = x if (i % w == w - 1 or i == e - 1) else maxf(h[i + 1], x)
	var out := PackedFloat64Array()
	out.resize(n)
	for i in range(n):
		out[i] = maxf(h[i], g[i + w - 1])
	return out


## +1 ridge, -1 trough, 0 neither: in any of the four axis directions both
## neighbours RIDGE_REACH_M away are RIDGE_DROP_M lower (higher).
func _ridge(pi: int, pj: int) -> int:
	var c := pj * _pnx + pi
	var h := _h[c]
	var ka := maxi(1, int(round(RIDGE_REACH_M / cell_m)))
	var kd := maxi(1, int(round(RIDGE_REACH_M / (cell_m * sqrt(2.0)))))
	var trough := false
	for d: Vector2i in [Vector2i(ka, 0), Vector2i(0, ka), Vector2i(kd, kd), Vector2i(kd, -kd)]:
		var ax := pi + d.x
		var ay := pj + d.y
		var bx := pi - d.x
		var by := pj - d.y
		if ax < 0 or ay < 0 or bx < 0 or by < 0 or ax >= _pnx or bx >= _pnx or ay >= _pny or by >= _pny:
			continue
		var ha := _h[ay * _pnx + ax]
		var hb := _h[by * _pnx + bx]
		if h - ha >= RIDGE_DROP_M and h - hb >= RIDGE_DROP_M:
			return 1
		if ha - h >= RIDGE_DROP_M and hb - h >= RIDGE_DROP_M:
			trough = true
	return -1 if trough else 0


func _classify() -> void:
	_class.resize(nx * ny)
	_hs.resize(nx * ny)
	for j in range(ny):
		for i in range(nx):
			var pi := i - _i0
			var pj := j - _j0
			var c := pj * _pnx + pi
			_class[j * nx + i] = CLASSES.find(_class_of_cell(pi, pj, c))
			_hs[j * nx + i] = _h[c]


func _class_of_cell(pi: int, pj: int, c: int) -> StringName:
	if _wet[c] == 1:
		return WATER
	if _wdist[c] <= SHORE_M + 1e-6:
		return SHORE
	var h := _h[c]
	var s := _slope[c]
	var t := _tpi[c]
	if t >= TPI_HIGH_M:
		if h >= _summit[c] - SUMMIT_DROP_M:
			return CREST
		if _ridge(pi, pj) == 1:
			return SPUR
	elif t <= TPI_LOW_M:
		if s < VALLEY_FLOOR_MAX or _ridge(pi, pj) == -1:
			return VALLEY_FLOOR
	if s < LEVEL_MAX and _steep_hi[c] >= h + BENCH_RELIEF_M and _steep_lo[c] <= h - BENCH_RELIEF_M:
		return BENCH
	if s < FLAT_MAX:
		return FLAT
	return OPEN_SLOPE


# ------------------------------------------------------------ cell access

## Site cell index (j * nx + i) of a site point, or -1 outside the site.
func cell_at(p: Vector2) -> int:
	var i := int(floor((p.x - rect.position.x) / cell_m))
	var j := int(floor((p.y - rect.position.y) / cell_m))
	if i < 0 or j < 0 or i >= nx or j >= ny:
		return -1
	return j * nx + i


func cell_center(idx: int) -> Vector2:
	return rect.position + Vector2((idx % nx) + 0.5, (idx / nx) + 0.5) * cell_m


func cell_count() -> int:
	return nx * ny


func _pad(idx: int) -> int:
	return ((idx / nx) - _j0) * _pnx + (idx % nx) - _i0


func class_of(idx: int) -> StringName:
	return CLASSES[_class[idx]] if idx >= 0 and idx < _class.size() else &""


func height_of(idx: int) -> float:
	return _h[_pad(idx)]


func slope_of(idx: int) -> float:
	return _slope[_pad(idx)]


func slope_max_of(idx: int) -> float:
	return _slope_max[_pad(idx)]


func tpi_of(idx: int) -> float:
	return _tpi[_pad(idx)]


func wet_of(idx: int) -> bool:
	return _wet[_pad(idx)] == 1


## Metres from this cell's centre to the nearest wet cell centre (chamfer);
## INF when there is no water within the padded ground.
func water_distance_of(idx: int) -> float:
	return _wdist[_pad(idx)]


func buildable_of(idx: int, use: StringName) -> bool:
	if idx < 0 or not USES.has(use):
		return false
	var c := _pad(idx)
	return _wet[c] == 0 and _slope_max[c] <= float(USES[use])


# ------------------------------------------------------------ point helpers

## The landform class at a site point, or &"" outside the site.
func class_at(p: Vector2) -> StringName:
	return class_of(cell_at(p))


## The cell's mean slope (rise over run) at a site point; NAN outside.
func slope_at(p: Vector2) -> float:
	var idx := cell_at(p)
	return NAN if idx < 0 else slope_of(idx)


func wet_at(p: Vector2) -> bool:
	var idx := cell_at(p)
	return idx >= 0 and wet_of(idx)


func water_distance_at(p: Vector2) -> float:
	var idx := cell_at(p)
	return NAN if idx < 0 else water_distance_of(idx)


func tpi_at(p: Vector2) -> float:
	var idx := cell_at(p)
	return NAN if idx < 0 else tpi_of(idx)


## Can `use` (&"cart", &"plot", &"path", &"steps") go here: dry, and the
## STEEPEST facet of the cell within the use's cap.
func buildable(p: Vector2, use: StringName) -> bool:
	return buildable_of(cell_at(p), use)


## {class: cell count} over the site.
func histogram() -> Dictionary:
	var out := {}
	for k in CLASSES:
		out[k] = 0
	for v in _class:
		out[CLASSES[v]] += 1
	return out


# ------------------------------------------------------------ regions

## Connected (4-neighbour) components of dry site cells with slope <=
## `max_slope`, of at least `min_area_m2`, largest first:
##   {cells: PackedInt32Array, area_m2, mean_m, min_m, max_m, centroid: Vector2,
##    bounds: Rect2, bench_cells: int}
func level_regions(max_slope := LEVEL_MAX, min_area_m2 := 0.0) -> Array:
	var n := nx * ny
	var seen := PackedByteArray()
	seen.resize(n)
	var out: Array = []
	var bench_k := CLASSES.find(BENCH)
	for start in range(n):
		if seen[start] == 1 or not _level(start, max_slope):
			continue
		var cells := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		while head < cells.size():
			var c := cells[head]
			head += 1
			var i := c % nx
			var j := c / nx
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var a := i + d.x
				var b := j + d.y
				if a < 0 or b < 0 or a >= nx or b >= ny:
					continue
				var q := b * nx + a
				if seen[q] == 0 and _level(q, max_slope):
					seen[q] = 1
					cells.append(q)
		var area := cells.size() * cell_m * cell_m
		if area < min_area_m2:
			continue
		var sum := 0.0
		var lo := INF
		var hi := -INF
		var cen := Vector2.ZERO
		var benches := 0
		var box := Rect2(cell_center(cells[0]), Vector2.ZERO)
		for c in cells:
			var h := height_of(c)
			sum += h
			lo = minf(lo, h)
			hi = maxf(hi, h)
			var p := cell_center(c)
			cen += p
			box = box.expand(p)
			if _class[c] == bench_k:
				benches += 1
		out.append({"cells": cells, "area_m2": area, "mean_m": sum / cells.size(),
			"min_m": lo, "max_m": hi, "centroid": cen / cells.size(),
			"bounds": box.grow(cell_m * 0.5), "bench_cells": benches})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["area_m2"] != y["area_m2"]:
			return x["area_m2"] > y["area_m2"]
		return x["cells"][0] < y["cells"][0])
	return out


func _level(idx: int, max_slope: float) -> bool:
	var c := _pad(idx)
	return _wet[c] == 0 and _slope[c] <= max_slope


## The centre of the highest cell of a region (a level_regions() entry or a
## PackedInt32Array of site cells); ties go to the first cell. NAN if empty.
func highest_point(region: Variant) -> Vector2:
	var cells: PackedInt32Array = region["cells"] if region is Dictionary else region
	var best := -1
	var best_h := -INF
	for c in cells:
		var h := height_of(c)
		if h > best_h:
			best_h = h
			best = c
	return Vector2(NAN, NAN) if best < 0 else cell_center(best)


## The level region (slope < LEVEL_MAX, dry, >= min_area_m2) with the most
## `bench` cells -- a shelf in a slope to put a church or a green on.
## {} when the site has no bench at all.
func best_bench(min_area_m2 := 0.0) -> Dictionary:
	var best := {}
	for r in level_regions(LEVEL_MAX, min_area_m2):
		if int(r["bench_cells"]) == 0:
			continue
		if best.is_empty() or int(r["bench_cells"]) > int(best["bench_cells"]):
			best = r
	return best


# ------------------------------------------------------------ contours

## Contour polylines through the site cell centres (marching squares), every
## `interval_m` from `base_m`:  [{height_m, points: PackedVector2Array, closed}]
## ordered by height, then by first point.
func contours(interval_m := 5.0, base_m := 0.0) -> Array:
	var out: Array = []
	if interval_m <= 0.0 or nx < 2 or ny < 2:
		return out
	var lo := INF
	var hi := -INF
	for v in _hs:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var k0 := int(ceil((lo - base_m) / interval_m))
	var k1 := int(floor((hi - base_m) / interval_m))
	for k in range(k0, k1 + 1):
		var lv := base_m + k * interval_m
		for line in _contour_level(lv):
			out.append(line)
	return out


func _edge_point(e: int, lv: float) -> Vector2:
	var c := e >> 1
	var i := c % nx
	var j := c / nx
	var a := Vector2i(i, j)
	var b := Vector2i(i + 1, j) if (e & 1) == 0 else Vector2i(i, j + 1)
	var ha := _hs[a.y * nx + a.x]
	var hb := _hs[b.y * nx + b.x]
	var t := 0.5 if absf(hb - ha) < 1e-12 else clampf((lv - ha) / (hb - ha), 0.0, 1.0)
	return cell_center(a.y * nx + a.x).lerp(cell_center(b.y * nx + b.x), t)


func _contour_level(lv: float) -> Array:
	var segs: Array[Vector2i] = []
	for j in range(ny - 1):
		for i in range(nx - 1):
			var v0 := _hs[j * nx + i]
			var v1 := _hs[j * nx + i + 1]
			var v2 := _hs[(j + 1) * nx + i + 1]
			var v3 := _hs[(j + 1) * nx + i]
			var bits := (1 if v0 >= lv else 0) | (2 if v1 >= lv else 0) | (4 if v2 >= lv else 0) | (8 if v3 >= lv else 0)
			if bits == 0 or bits == 15:
				continue
			var e0 := (j * nx + i) * 2           # top
			var e1 := (j * nx + i + 1) * 2 + 1   # right
			var e2 := ((j + 1) * nx + i) * 2     # bottom
			var e3 := (j * nx + i) * 2 + 1       # left
			var centre_up := (v0 + v1 + v2 + v3) * 0.25 >= lv
			match bits:
				1, 14:
					segs.append(Vector2i(e3, e0))
				2, 13:
					segs.append(Vector2i(e0, e1))
				3, 12:
					segs.append(Vector2i(e3, e1))
				4, 11:
					segs.append(Vector2i(e1, e2))
				6, 9:
					segs.append(Vector2i(e0, e2))
				7, 8:
					segs.append(Vector2i(e3, e2))
				5:
					if centre_up:
						segs.append(Vector2i(e0, e1))
						segs.append(Vector2i(e2, e3))
					else:
						segs.append(Vector2i(e3, e0))
						segs.append(Vector2i(e1, e2))
				10:
					if centre_up:
						segs.append(Vector2i(e3, e0))
						segs.append(Vector2i(e1, e2))
					else:
						segs.append(Vector2i(e0, e1))
						segs.append(Vector2i(e2, e3))
	# chain segments through shared edges
	var by_edge := {}
	for s in range(segs.size()):
		for e: int in [segs[s].x, segs[s].y]:
			if not by_edge.has(e):
				by_edge[e] = []
			by_edge[e].append(s)
	var used := PackedByteArray()
	used.resize(segs.size())
	var lines: Array = []
	for pass_open in [true, false]:
		for s in range(segs.size()):
			if used[s] == 1:
				continue
			var start := segs[s].x
			if pass_open:
				# begin only at an open end
				if by_edge[segs[s].x].size() == 1:
					start = segs[s].x
				elif by_edge[segs[s].y].size() == 1:
					start = segs[s].y
				else:
					continue
			var edges := PackedInt32Array([start])
			var cur := s
			var at := start
			while cur >= 0:
				used[cur] = 1
				var nxt_e := segs[cur].y if segs[cur].x == at else segs[cur].x
				edges.append(nxt_e)
				at = nxt_e
				cur = -1
				for t in by_edge[at]:
					if used[t] == 0:
						cur = t
						break
			var pts := PackedVector2Array()
			for e in edges:
				pts.append(_edge_point(e, lv))
			lines.append({"height_m": lv, "points": pts, "closed": not pass_open and edges[0] == edges[edges.size() - 1]})
	return lines


# ------------------------------------------------------------ drainage

## Catchment area (m^2) draining through the cell at a site point, by D8 over
## the depression-filled padded grid; 0 outside the site.
func flow_area_at(p: Vector2) -> float:
	var idx := cell_at(p)
	if idx < 0:
		return 0.0
	_drainage()
	return _acc[_pad(idx)] * cell_m * cell_m


## Where water would run, for ground given WITHOUT water: polylines (site cell
## centres, downstream order) through cells draining at least STREAM_AREA_M2.
## Empty when the caller gave a water level (the water is already known) or
## the ground has less than STREAM_MIN_RELIEF_M of relief.
func streams() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not valid() or not is_nan(water_level_m):
		return out
	var lo := INF
	var hi := -INF
	for v in _h:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if hi - lo < STREAM_MIN_RELIEF_M:
		return out
	_drainage()
	var thr := int(ceil(STREAM_AREA_M2 / (cell_m * cell_m)))
	var n := nx * ny
	var on := PackedByteArray()
	on.resize(n)
	for idx in range(n):
		on[idx] = 1 if _acc[_pad(idx)] >= thr else 0
	var donors := PackedInt32Array()
	donors.resize(n)
	for idx in range(n):
		if on[idx] == 1:
			var t := _site_of_pad(_dir[_pad(idx)])
			if t >= 0 and on[t] == 1:
				donors[t] += 1
	var visited := PackedByteArray()
	visited.resize(n)
	for idx in range(n):
		if on[idx] == 0 or donors[idx] > 0:
			continue
		var pts := PackedVector2Array()
		var c := idx
		while c >= 0 and on[c] == 1:
			pts.append(cell_center(c))
			if visited[c] == 1:
				break
			visited[c] = 1
			c = _site_of_pad(_dir[_pad(c)])
		if pts.size() >= 2:
			out.append(pts)
	return out


func _site_of_pad(pc: int) -> int:
	if pc < 0:
		return -1
	var i := (pc % _pnx) + _i0
	var j := (pc / _pnx) + _j0
	if i < 0 or j < 0 or i >= nx or j >= ny:
		return -1
	return j * nx + i


const _NB: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]


## Priority-flood fill (Barnes 2014), D8 on the filled ground, flats drained
## toward their outlets and away from higher ground (Barnes, Lehman & Mulla
## 2014), then accumulation in cells. Directions: target padded index, -1 out
## of the grid, -2 none.
func _drainage() -> void:
	if _drained:
		return
	_drained = true
	var n := _pnx * _pny
	var f := PackedFloat64Array()
	f.resize(n)
	var done := PackedByteArray()
	done.resize(n)
	var hk := PackedFloat64Array()
	var hv := PackedInt32Array()
	for c in range(n):
		var pi := c % _pnx
		var pj := c / _pnx
		if pi == 0 or pj == 0 or pi == _pnx - 1 or pj == _pny - 1:
			f[c] = _h[c]
			done[c] = 1
			_heap_push(hk, hv, f[c], c)
	while hv.size() > 0:
		var c := hv[0]
		_heap_pop(hk, hv)
		var pi := c % _pnx
		var pj := c / _pnx
		for d in _NB:
			var a := pi + d.x
			var b := pj + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var q := b * _pnx + a
			if done[q] == 1:
				continue
			done[q] = 1
			f[q] = maxf(_h[q], f[c])
			_heap_push(hk, hv, f[q], q)
	# D8 on the filled surface
	_dir.resize(n)
	var diag := sqrt(2.0)
	for c in range(n):
		var pi := c % _pnx
		var pj := c / _pnx
		var best := -2
		var best_drop := 0.0
		for d in _NB:
			var a := pi + d.x
			var b := pj + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var q := b * _pnx + a
			var drop := (f[c] - f[q]) / (diag if d.x != 0 and d.y != 0 else 1.0)
			if drop > best_drop:
				best_drop = drop
				best = q
		if best == -2 and (pi == 0 or pj == 0 or pi == _pnx - 1 or pj == _pny - 1):
			best = -1
		_dir[c] = best
	_resolve_flats(f)
	# accumulation, upstream first
	_acc.resize(n)
	_acc.fill(1)
	var indeg := PackedInt32Array()
	indeg.resize(n)
	for c in range(n):
		if _dir[c] >= 0:
			indeg[_dir[c]] += 1
	var queue := PackedInt32Array()
	for c in range(n):
		if indeg[c] == 0:
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var t := _dir[c]
		if t >= 0:
			_acc[t] += _acc[c]
			indeg[t] -= 1
			if indeg[t] == 0:
				queue.append(t)


func _resolve_flats(f: PackedFloat64Array) -> void:
	var n := _pnx * _pny
	var low := PackedInt32Array()
	var high := PackedInt32Array()
	for c in range(n):
		var pi := c % _pnx
		var pj := c / _pnx
		var is_low := false
		var is_high := false
		for d in _NB:
			var a := pi + d.x
			var b := pj + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var q := b * _pnx + a
			if _dir[c] != -2 and _dir[q] == -2 and f[q] == f[c]:
				is_low = true
			if _dir[c] == -2 and f[q] > f[c]:
				is_high = true
		if is_low:
			low.append(c)
		if is_high:
			high.append(c)
	if low.is_empty():
		return
	var is_low_edge := PackedByteArray()
	is_low_edge.resize(n)
	for c in low:
		is_low_edge[c] = 1
	var label := PackedInt32Array()
	label.resize(n)
	var next_label := 1
	for s in low:
		if label[s] != 0:
			continue
		label[s] = next_label
		var q := PackedInt32Array([s])
		var head := 0
		while head < q.size():
			var c := q[head]
			head += 1
			for d in _NB:
				var a := (c % _pnx) + d.x
				var b := (c / _pnx) + d.y
				if a < 0 or b < 0 or a >= _pnx or b >= _pny:
					continue
				var t := b * _pnx + a
				if label[t] == 0 and f[t] == f[s] and (_dir[t] == -2 or is_low_edge[t] == 1):
					label[t] = next_label
					q.append(t)
		next_label += 1
	# away from higher ground
	var away := PackedInt32Array()
	away.resize(n)
	var flat_h := PackedInt32Array()
	flat_h.resize(next_label)
	var q2 := PackedInt32Array()
	for c in high:
		if label[c] != 0:
			away[c] = 1
			q2.append(c)
	var head2 := 0
	while head2 < q2.size():
		var c := q2[head2]
		head2 += 1
		flat_h[label[c]] = maxi(flat_h[label[c]], away[c])
		for d in _NB:
			var a := (c % _pnx) + d.x
			var b := (c / _pnx) + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var t := b * _pnx + a
			if label[t] == label[c] and _dir[t] == -2 and away[t] == 0:
				away[t] = away[c] + 1
				q2.append(t)
	# toward the outlet
	var tow := PackedInt32Array()
	tow.resize(n)
	tow.fill(-1)
	var q3 := PackedInt32Array()
	for c in low:
		tow[c] = 0
		q3.append(c)
	var head3 := 0
	while head3 < q3.size():
		var c := q3[head3]
		head3 += 1
		for d in _NB:
			var a := (c % _pnx) + d.x
			var b := (c / _pnx) + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var t := b * _pnx + a
			if label[t] == label[c] and _dir[t] == -2 and tow[t] < 0:
				tow[t] = tow[c] + 1
				q3.append(t)
	var mask := PackedInt32Array()
	mask.resize(n)
	for c in range(n):
		if label[c] != 0 and tow[c] >= 0:
			mask[c] = 2 * tow[c] + (flat_h[label[c]] - away[c] if away[c] > 0 else 0)
	for c in range(n):
		if _dir[c] != -2 or label[c] == 0:
			continue
		var best := -2
		var best_m := mask[c]
		for d in _NB:
			var a := (c % _pnx) + d.x
			var b := (c / _pnx) + d.y
			if a < 0 or b < 0 or a >= _pnx or b >= _pny:
				continue
			var t := b * _pnx + a
			if label[t] == label[c] and tow[t] >= 0 and mask[t] < best_m:
				best_m = mask[t]
				best = t
		_dir[c] = best


static func _heap_push(hk: PackedFloat64Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hv.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if not (hk[i] < hk[p] or (hk[i] == hk[p] and hv[i] < hv[p])):
			break
		var tk := hk[i]
		hk[i] = hk[p]
		hk[p] = tk
		var tv := hv[i]
		hv[i] = hv[p]
		hv[p] = tv
		i = p


static func _heap_pop(hk: PackedFloat64Array, hv: PackedInt32Array) -> void:
	var last := hv.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := 2 * i + 1
		if l >= last:
			break
		var m := l
		if l + 1 < last and (hk[l + 1] < hk[l] or (hk[l + 1] == hk[l] and hv[l + 1] < hv[l])):
			m = l + 1
		if not (hk[m] < hk[i] or (hk[m] == hk[i] and hv[m] < hv[i])):
			break
		var tk := hk[i]
		hk[i] = hk[m]
		hk[m] = tk
		var tv := hv[i]
		hv[i] = hv[m]
		hv[m] = tv
		i = m


# ------------------------------------------------------------ debug

## One character a cell, row 0 north:  ~ water  , shore  ^ crest  A spur
## v valley_floor  = bench  _ flat  . open_slope;  # where a footpath cannot
## go (dry, steeper than PATH_MAX) overrides the class; `marks` maps a site
## point (Vector2) to a character drawn over its cell; `with_streams` draws *.
func ascii_map(marks := {}, with_streams := false) -> String:
	var grid: Array = []
	for j in range(ny):
		var row: Array = []
		for i in range(nx):
			var idx := j * nx + i
			var g: String = _GLYPH[_class[idx]]
			if not wet_of(idx) and slope_max_of(idx) > PATH_MAX:
				g = "#"
			row.append(g)
		grid.append(row)
	if with_streams:
		for line in streams():
			for p in line:
				var idx := cell_at(p)
				if idx >= 0:
					grid[idx / nx][idx % nx] = "*"
	for p in marks:
		var idx := cell_at(Vector2(p))
		if idx >= 0:
			grid[idx / nx][idx % nx] = String(marks[p]).left(1)
	var out := PackedStringArray()
	for row in grid:
		out.append("".join(PackedStringArray(row)))
	return "\n".join(out)


## A short reading for notes: cells, cell size, class shares.
func summary() -> Dictionary:
	var h := histogram()
	var shares := {}
	for k in h:
		shares[String(k)] = snappedf(float(h[k]) / maxi(1, nx * ny), 0.001)
	return {"nx": nx, "ny": ny, "cell_m": cell_m, "classes": shares,
		"water_level_m": null if is_nan(water_level_m) else water_level_m}
