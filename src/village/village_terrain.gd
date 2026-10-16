class_name VillageTerrain
extends RefCounted
## The ground a village stands on: a regular height grid in SITE metres, the
## same frame as every VillagePlan point (origin at the site centre, +X east,
## +Y of a plan point = +Z south). Heights are metres in the caller's datum;
## nothing here assumes sea level is 0.
##
## This is the READER, not the planner. It takes the caller's ground in three
## shapes -- a `brickwild.terrain` dictionary (inline heights or a raw float32
## file beside it), or a sampler Callable for an in-process caller such as
## VoxelGames' `sample_padded_height` -- validates it, and answers questions
## about it: the height and slope at a point, and how the ground lies under a
## lot, a building or along a road. A spec without terrain is flat, exactly as
## before; see docs/VILLAGE_TERRAIN.md.
##
## A coarse cell proves only its centre (VoxelGames ARCH-DOC, 2026-08-09): the
## grid must COVER the site, and `under()` samples a footprint at half a cell,
## so a cliff crossing a lot is seen even when the lot's centre is gentle.

const SCHEMA := "brickwild.terrain"
const SCHEMA_VERSION := 1
## A grid finer than this is a voxel dump, coarser cannot see a house plot.
const CELL_MIN_M := 0.25
const CELL_MAX_M := 100.0
## 4 M samples: a 400 m site at 0.2 m. Anything bigger is a mistake, not a site.
const SAMPLES_MAX := 4_000_000
## Heights beyond this are a unit error (centimetres, millimetres, feet*1000).
const HEIGHT_ABS_MAX := 12_000.0

var origin := Vector2.ZERO          ## site position of grid node (0, 0)
var cell_m := 1.0
var cols := 0
var rows := 0
var heights := PackedFloat32Array() ## row-major: index = row * cols + col; row runs +Y (south)
## Standing water surface in the same datum, or NAN for none. Ground below it
## is wet; `under()` reports the dry share.
var water_level_m := NAN
## Where the ground came from, for the plan's notes: "inline", a file name,
## "sampler", "flat".
var source := ""
## Set only on a VILLAGE-FRAME view (`sited_view`, VTER-SITING): the caller's
## ground this view was resampled from, and where the village frame lies on
## it -- a village point p is the caller's point `site_anchor + p.rotated(site_yaw)`.
## Null / zero on every grid a caller made.
var parent: VillageTerrain = null
var site_anchor := Vector2.ZERO
var site_yaw := 0.0

var _errors: Array[String] = []
var _min := INF
var _max := -INF


# ------------------------------------------------------------ constructors

## Flat ground at `height_m` over `rect`, at `cell_m`. What a spec without
## terrain means, made explicit (tests and callers that want the type).
static func flat(rect: Rect2, height_m := 0.0, p_cell_m := 10.0) -> VillageTerrain:
	var t := VillageTerrain.new()
	t.origin = rect.position
	t.cell_m = p_cell_m
	t.cols = int(ceil(rect.size.x / p_cell_m)) + 1
	t.rows = int(ceil(rect.size.y / p_cell_m)) + 1
	t.heights.resize(t.cols * t.rows)
	t.heights.fill(height_m)
	t.source = "flat"
	t._validate()
	return t


## In-process reader: `sampler.call(x, z) -> float` in SITE metres, sampled at
## every grid node over `rect`. VoxelGames binds its world offset into the
## Callable: `func(x, z): return generator.sample_padded_height(cx + x, cz + z)`.
static func from_sampler(sampler: Callable, rect: Rect2, p_cell_m: float,
		p_water_level_m := NAN) -> VillageTerrain:
	var t := VillageTerrain.new()
	t.source = "sampler"
	t.origin = rect.position
	t.cell_m = p_cell_m
	t.water_level_m = p_water_level_m
	if not (p_cell_m >= CELL_MIN_M and p_cell_m <= CELL_MAX_M):
		t._errors.append("cell_m %s is outside [%s, %s]" % [p_cell_m, CELL_MIN_M, CELL_MAX_M])
		return t
	t.cols = int(ceil(rect.size.x / p_cell_m)) + 1
	t.rows = int(ceil(rect.size.y / p_cell_m)) + 1
	if t.cols * t.rows > SAMPLES_MAX:
		t._errors.append("%d x %d samples exceeds %d" % [t.cols, t.rows, SAMPLES_MAX])
		return t
	t.heights.resize(t.cols * t.rows)
	for r in range(t.rows):
		for c in range(t.cols):
			t.heights[r * t.cols + c] = float(sampler.call(t.origin.x + c * p_cell_m, t.origin.y + r * p_cell_m))
	t._validate()
	return t


## The `brickwild.terrain` dictionary (docs/VILLAGE_TERRAIN.md):
##   {"schema": "brickwild.terrain", "schema_version": 1,
##    "origin_m": [x, z], "cell_m": 5, "cols": 81, "rows": 81,
##    "heights_m": [...]            -- row-major, rows*cols numbers, or
##    "file": "ground.r32",          -- little-endian float32, rows*cols, beside `base_dir`
##    "water_level_m": 12.0}         -- optional
## Never throws: a bad document comes back with `errors()` filled.
static func from_dict(d: Dictionary, base_dir := "") -> VillageTerrain:
	var t := VillageTerrain.new()
	if String(d.get("schema", "")) != SCHEMA:
		t._errors.append("terrain schema is '%s', expected '%s'" % [d.get("schema", ""), SCHEMA])
		return t
	if int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		t._errors.append("terrain schema_version %s, this reader understands %d" % [
			d.get("schema_version", "?"), SCHEMA_VERSION])
		return t
	var o: Variant = d.get("origin_m", null)
	if not (o is Array and (o as Array).size() == 2 and _num(o[0]) and _num(o[1])):
		t._errors.append("origin_m must be [x, z] in site metres")
		return t
	t.origin = Vector2(float(o[0]), float(o[1]))
	if not (_num(d.get("cell_m")) and _num(d.get("cols")) and _num(d.get("rows"))):
		t._errors.append("cell_m, cols and rows must be numbers")
		return t
	t.cell_m = float(d["cell_m"])
	t.cols = int(d["cols"])
	t.rows = int(d["rows"])
	if float(d["cols"]) != float(t.cols) or float(d["rows"]) != float(t.rows):
		t._errors.append("cols and rows must be whole numbers")
		return t
	if t.cols < 2 or t.rows < 2:
		t._errors.append("a grid needs at least 2 x 2 nodes, got %d x %d" % [t.cols, t.rows])
		return t
	if t.cols * t.rows > SAMPLES_MAX:
		t._errors.append("%d x %d samples exceeds %d" % [t.cols, t.rows, SAMPLES_MAX])
		return t
	if d.has("water_level_m") and d["water_level_m"] != null:
		if not _num(d["water_level_m"]):
			t._errors.append("water_level_m must be a number or null")
			return t
		t.water_level_m = float(d["water_level_m"])
	var n := t.cols * t.rows
	if d.has("heights_m"):
		var hs: Variant = d["heights_m"]
		if not hs is Array:
			t._errors.append("heights_m must be an array")
			return t
		if (hs as Array).size() != n:
			t._errors.append("heights_m has %d values, cols x rows is %d" % [(hs as Array).size(), n])
			return t
		t.heights.resize(n)
		for i in range(n):
			if not _num(hs[i]):
				t._errors.append("heights_m[%d] is not a number" % i)
				return t
			t.heights[i] = float(hs[i])
		t.source = "inline"
	elif d.has("file"):
		var path := String(d["file"])
		if not base_dir.is_empty() and path.is_relative_path():
			path = base_dir.path_join(path)
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			t._errors.append("cannot read height file %s" % path)
			return t
		if bytes.size() != n * 4:
			t._errors.append("height file %s has %d bytes, %d x %d float32 is %d" % [
				path, bytes.size(), t.cols, t.rows, n * 4])
			return t
		t.heights = bytes.to_float32_array()   # little-endian on every platform Godot ships
		t.source = path.get_file()
	else:
		t._errors.append("terrain needs heights_m or file")
		return t
	t._validate()
	return t


## A `brickwild.terrain` JSON file; a relative `file` inside it is read from
## the JSON's own directory.
static func from_file(path: String) -> VillageTerrain:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		var t := VillageTerrain.new()
		t._errors.append("cannot read terrain %s" % path)
		return t
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		var t2 := VillageTerrain.new()
		t2._errors.append("terrain %s is not a JSON object" % path)
		return t2
	return from_dict(d, path.get_base_dir())


# ----------------------------------------------------------------- validity

func errors() -> Array[String]:
	return _errors.duplicate()


func valid() -> bool:
	return _errors.is_empty() and cols >= 2 and rows >= 2


func _validate() -> void:
	if not (cell_m >= CELL_MIN_M and cell_m <= CELL_MAX_M):
		_errors.append("cell_m %s is outside [%s, %s]" % [cell_m, CELL_MIN_M, CELL_MAX_M])
	if heights.size() != cols * rows:
		_errors.append("%d heights for %d x %d nodes" % [heights.size(), cols, rows])
		return
	for i in range(heights.size()):
		var h := heights[i]
		if is_nan(h) or is_inf(h):
			_errors.append("height %d (col %d, row %d) is not finite" % [i, i % cols, i / cols])
			return
		if absf(h) > HEIGHT_ABS_MAX:
			_errors.append("height %d is %.1f m; heights are metres (|h| <= %.0f)" % [i, h, HEIGHT_ABS_MAX])
			return
		_min = minf(_min, h)
		_max = maxf(_max, h)


## The site rectangle the grid spans.
func bounds() -> Rect2:
	return Rect2(origin, Vector2((cols - 1) * cell_m, (rows - 1) * cell_m))


## True when every point of `rect` can be answered from the grid, not clamped.
func covers(rect: Rect2) -> bool:
	return bounds().grow(0.001).encloses(rect)


func min_height() -> float:
	return _min


func max_height() -> float:
	return _max


func relief() -> float:
	return _max - _min


# ------------------------------------------------------------------ queries

## Bilinear height at a site point. Outside the grid the edge is held (and
## `covers()` is how a caller finds out it asked outside).
func height_at(p: Vector2) -> float:
	var fx := clampf((p.x - origin.x) / cell_m, 0.0, float(cols - 1))
	var fy := clampf((p.y - origin.y) / cell_m, 0.0, float(rows - 1))
	var c0 := mini(int(fx), cols - 2)
	var r0 := mini(int(fy), rows - 2)
	var tx := fx - c0
	var ty := fy - r0
	var i := r0 * cols + c0
	var top := lerpf(heights[i], heights[i + 1], tx)
	var bottom := lerpf(heights[i + cols], heights[i + cols + 1], tx)
	return lerpf(top, bottom, ty)


## Height gradient (dh/dx, dh/dy) in metres per metre, by central difference
## over one cell -- the grid's own resolution, no finer.
func gradient_at(p: Vector2) -> Vector2:
	var e := cell_m * 0.5
	return Vector2(height_at(p + Vector2(e, 0)) - height_at(p - Vector2(e, 0)),
		height_at(p + Vector2(0, e)) - height_at(p - Vector2(0, e))) / (2.0 * e)


## The ground in a village's own frame (VTER-SITING): this grid resampled
## over `rect` of the VILLAGE frame at `p_cell_m`, where village point p is
## this grid's point `anchor + p.rotated(yaw)`. The planners lay their
## axis-aligned site out in that frame; the plan carries the anchor and yaw.
## Outside this grid the edge is held, as in `height_at`.
func sited_view(anchor: Vector2, yaw: float, rect: Rect2, p_cell_m: float) -> VillageTerrain:
	var c := cos(yaw)
	var s := sin(yaw)
	var view := VillageTerrain.from_sampler(func(x: float, y: float) -> float:
			return height_at(anchor + Vector2(x * c - y * s, x * s + y * c)),
		rect, p_cell_m, water_level_m)
	view.source = source
	view.parent = self
	view.site_anchor = anchor
	view.site_yaw = yaw
	return view


## A village-frame point on the caller's grid; the identity on a caller's own.
func to_parent(p: Vector2) -> Vector2:
	if parent == null:
		return p
	return site_anchor + p.rotated(site_yaw)


## Rise over run at a point: 0.1 is a 10 % grade, 1.0 is 45 degrees.
func slope_at(p: Vector2) -> float:
	return gradient_at(p).length()


func is_wet(p: Vector2) -> bool:
	return not is_nan(water_level_m) and height_at(p) < water_level_m


## How the ground lies under a polygon (a lot, a footprint, a common):
## sampled on a half-cell lattice inside it, plus every vertex, so neither a
## small plot nor a cliff crossing a big one is missed.
##   {min_m, max_m, mean_m, span_m, slope_max, slope_mean, dry_share, samples,
##    low_m: [x, y] the lowest point, high_m: [x, y] the highest}
## `span_m` is the cut-and-fill a flat platform would need; `low_m` and
## `high_m` say which way the plot falls.
func under(poly: PackedVector2Array) -> Dictionary:
	var pts := PackedVector2Array()
	for v in poly:
		pts.append(v)
	if poly.size() >= 3:
		var box := Poly.bounding_rect(poly)
		var step := maxf(cell_m * 0.5, 0.25)
		var y := box.position.y + step * 0.5
		while y < box.end.y:
			var x := box.position.x + step * 0.5
			while x < box.end.x:
				var q := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(q, poly):
					pts.append(q)
				x += step
			y += step
	return _stats(pts)


## Heights along a polyline every `step_m` (and at every vertex), with the
## steepest grade met between consecutive samples:
##   {heights_m: [...], length_m, rise_m, fall_m, grade_max}
## The road question: can a cart climb it, and does it need steps.
func profile(points: PackedVector2Array, step_m := 0.0) -> Dictionary:
	var step := step_m if step_m > 0.0 else cell_m
	var hs: Array = []
	var length := 0.0
	var rise := 0.0
	var fall := 0.0
	var grade := 0.0
	var prev := NAN
	var prev_p := Vector2.ZERO
	for i in range(points.size()):
		var a := points[i]
		var seg_n := 1
		var seg := Vector2.ZERO
		if i + 1 < points.size():
			seg = points[i + 1] - a
			seg_n = maxi(1, int(ceil(seg.length() / step)))
		for k in range(seg_n if i + 1 < points.size() else 1):
			var p := a + seg * (float(k) / seg_n)
			var h := height_at(p)
			if not is_nan(prev):
				var d := p.distance_to(prev_p)
				length += d
				if h > prev:
					rise += h - prev
				else:
					fall += prev - h
				if d > 1e-6:
					grade = maxf(grade, absf(h - prev) / d)
			hs.append(h)
			prev = h
			prev_p = p
	return {"heights_m": hs, "length_m": length, "rise_m": rise, "fall_m": fall, "grade_max": grade}


func _stats(pts: PackedVector2Array) -> Dictionary:
	if pts.is_empty():
		return {}
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var smax := 0.0
	var ssum := 0.0
	var dry := 0
	var low_p := pts[0]
	var high_p := pts[0]
	for p in pts:
		var h := height_at(p)
		var s := slope_at(p)
		if h < lo:
			lo = h
			low_p = p
		if h > hi:
			hi = h
			high_p = p
		sum += h
		ssum += s
		smax = maxf(smax, s)
		if not (not is_nan(water_level_m) and h < water_level_m):
			dry += 1
	return {"min_m": lo, "max_m": hi, "mean_m": sum / pts.size(), "span_m": hi - lo,
		"slope_max": smax, "slope_mean": ssum / pts.size(), "dry_share": float(dry) / pts.size(),
		"samples": pts.size(), "low_m": [low_p.x, low_p.y], "high_m": [high_p.x, high_p.y]}


# ------------------------------------------------------------------- output

## The whole-site reading, for a plan's `ground` block.
func summary() -> Dictionary:
	return {"schema": SCHEMA, "schema_version": SCHEMA_VERSION, "source": source,
		"origin_m": [origin.x, origin.y], "cell_m": cell_m, "cols": cols, "rows": rows,
		"min_m": _min, "max_m": _max, "relief_m": relief(),
		"water_level_m": null if is_nan(water_level_m) else water_level_m,
		"fingerprint": fingerprint()}


## A stable hash of the grid itself: two plans made on the same ground carry
## the same number; the plan purity check compares it.
func fingerprint() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%s|%s|%d|%d|%s" % [origin.x, origin.y, cell_m, cols, rows, water_level_m]).to_utf8_buffer())
	ctx.update(heights.to_byte_array())
	return ctx.finish().hex_encode().left(16)


## The dictionary `from_dict` reads, heights inline.
func to_dict() -> Dictionary:
	var hs: Array = []
	for h in heights:
		hs.append(h)
	var d := {"schema": SCHEMA, "schema_version": SCHEMA_VERSION,
		"origin_m": [origin.x, origin.y], "cell_m": cell_m, "cols": cols, "rows": rows,
		"heights_m": hs}
	if not is_nan(water_level_m):
		d["water_level_m"] = water_level_m
	return d


## Write the grid where `from_file` reads it: `json_path` is the header, and
## with `raw` the heights go beside it as `<name>.r32` (little-endian float32,
## 4 bytes a node) instead of inline. A 400 m site at 1 m is 640 KB raw and
## about 2 MB as JSON text. Returns OK or the first file error.
func save(json_path: String, raw := true) -> Error:
	var d := to_dict()
	if raw:
		d.erase("heights_m")
		var bin := json_path.get_basename() + ".r32"
		var bf := FileAccess.open(bin, FileAccess.WRITE)
		if bf == null:
			return FileAccess.get_open_error()
		bf.store_buffer(heights.to_byte_array())
		bf.close()
		d["file"] = bin.get_file()
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "\t", true) + "\n")
	f.close()
	return OK


static func _num(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
