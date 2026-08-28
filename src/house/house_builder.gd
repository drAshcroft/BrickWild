class_name HouseBuilder
extends MassBuilder
## HousePlan -> ArrayMesh: the shell only. The furniture is not mesh at all --
## it is a list of prop instances that HouseAssembler adds to the scene, so the
## same plan can be measured headlessly by the QA suites and dressed with real
## art in the viewer.
##
## Walls are emitted run by run, with the doors and windows cut out of them as
## actual holes: piers either side, a panel over the head, a panel under the
## sill. That matters beyond looks -- the navigation check walks the rasterized
## shell, so a "door" painted on a solid wall would be a door nobody can use,
## and it would say so.
##
## Surfaces: 0 = wall, 1 = trim (frames, sills, posts), 2 = roof, 3 = floor.

const SURF_WALL := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_FLOOR := 3

var plan: HousePlan
var spec: HouseSpec


## `with_roof` is the one thing a caller may switch off: a furnished interior
## cannot be photographed through its own thatch. Nothing else changes, so the
## walls and the openings the checks measure are the same either way.
func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	plan = p_plan
	spec = p_plan.spec
	begin(4)
	total_height = spec.height

	_build_floor()
	_build_exterior_walls()
	_build_partitions()
	_build_timber_frame()
	if with_roof:
		_build_roof()
	_build_porch()
	_build_chimney()
	return commit()


# ------------------------------------------------------------------ floor

func _build_floor() -> void:
	tag("floor")
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var t: float = HouseGeometry.FLOOR_T
	for level in range(_storeys()):
		var y0 := float(level) * spec.height
		var a := AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y))
		var opening := _stair_opening(level)
		if opening.size.x > 0.01 and opening.size.y > 0.01:
			_emit_floor_around(r, opening, y0, t, level)
		else:
			box(a.size, a.position + a.size / 2.0, SURF_FLOOR)
			_log_mass("floor" if _storeys() == 1 else "floor_%d" % level, a)
	_emit_stairs()


func _emit_floor_around(r: Rect2, hole: Rect2, y0: float, t: float,
		level: int) -> void:
	var pieces := [
		Rect2(r.position, Vector2(r.size.x, maxf(hole.position.y - r.position.y, 0.0))),
		Rect2(Vector2(r.position.x, hole.end.y), Vector2(r.size.x,
			maxf(r.end.y - hole.end.y, 0.0))),
		Rect2(Vector2(r.position.x, hole.position.y), Vector2(
			maxf(hole.position.x - r.position.x, 0.0), hole.size.y)),
		Rect2(Vector2(hole.end.x, hole.position.y), Vector2(
			maxf(r.end.x - hole.end.x, 0.0), hole.size.y)),
	]
	var emitted := 0
	for p in pieces:
		if p.size.x > 0.01 and p.size.y > 0.01:
			var size := Vector3(p.size.x, t, p.size.y)
			var centre := Vector3(p.get_center().x, y0 + t / 2.0, p.get_center().y)
			box(size, centre, SURF_FLOOR)
			_log_mass("floor_%d_%d" % [level, emitted], AABB(centre - size / 2.0, size))
			emitted += 1


func _stair_opening(level: int) -> Rect2:
	if level <= 0:
		return Rect2()
	var stairs = plan.get("stairs")
	if stairs == null:
		return Rect2()
	for stair in stairs:
		if not (stair is Dictionary):
			continue
		var from_level := int(stair.get("storey",
			stair.get("from_storey", stair.get("from_level", level - 1))))
		if from_level + 1 != level:
			continue
		var raw = stair.get("upper_rect", stair.get("rect", stair.get("opening", Rect2())))
		if raw is Rect2:
			return raw
	return Rect2()


func _emit_stairs() -> void:
	var stairs = plan.get("stairs")
	if stairs == null:
		return
	tag("stair")
	for index in range(stairs.size()):
		var stair = stairs[index]
		if not (stair is Dictionary):
			continue
		var raw = stair.get("lower_rect", stair.get("rect", stair.get("opening", Rect2())))
		if not (raw is Rect2):
			continue
		var footprint: Rect2 = raw
		var from_level := int(stair.get("storey",
			stair.get("from_storey", stair.get("from_level", 0))))
		var steps := maxi(4, int(stair.get("steps", 10)))
		var step_h := spec.height / float(steps)
		var run: float = footprint.size.y
		for s in range(steps):
			var z: float = footprint.position.y + run * (float(s) + 0.5) / steps
			var h := step_h * float(s + 1)
			var step_size := Vector3(footprint.size.x, h, run / steps)
			var step_center := Vector3(footprint.get_center().x,
				from_level * spec.height + h / 2.0, z)
			box(step_size, step_center, SURF_FLOOR)
			_log_mass("stair_%d_step_%d" % [index, s],
				AABB(step_center - step_size / 2.0, step_size))


# ------------------------------------------------------------------ walls

func _build_exterior_walls() -> void:
	tag("wall")
	var h: float = spec.height
	for level in range(_storeys()):
		var y0 := float(level) * h
		for run in HouseGeometry.exterior_runs(spec):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var normal: Vector2 = run["normal"]
			var openings: Array[Dictionary] = _openings_on(from, to, normal, level)
			_wall_run(from, to, HouseGeometry.WALL_T, h, openings, SURF_WALL, y0)
			var a: AABB = _run_aabb(from, to, HouseGeometry.WALL_T, h, y0)
			var suffix := "" if _storeys() == 1 else "_%d" % level
			_log_mass("wall_%s%s" % [String(run["side"]), suffix], a)
	total_height = maxf(total_height, h * _storeys())


func _build_partitions() -> void:
	tag("partition")
	var h: float = spec.height
	for level in range(_storeys()):
		var y0 := float(level) * h
		var seen := {}
		for i in range(plan.room_count()):
			if _room_storey(plan.rooms[i]) != level and _has_storey_metadata(plan.rooms[i]):
				continue
			for j in range(i + 1, plan.room_count()):
				if _room_storey(plan.rooms[j]) != level and _has_storey_metadata(plan.rooms[j]):
					continue
				var edge: Array = HousePlanner._shared_edge(plan, i, j)
				if edge.is_empty():
					continue
				var normal: Vector2 = edge[0]
				var line: float = edge[1]
				var t0: float = edge[2]
				var t1: float = edge[3]
				# one partition per shared edge, however many rooms lie along it
				var key: String = "%.2f|%.2f|%.2f|%.2f" % [normal.x, line, t0, t1]
				if seen.has(key):
					continue
				seen[key] = true
				var from: Vector2
				var to: Vector2
				if normal.x > 0.5:
					from = Vector2(line, t0)
					to = Vector2(line, t1)
				else:
					from = Vector2(t0, line)
					to = Vector2(t1, line)
				var openings: Array[Dictionary] = []
				for d in plan.doors:
					if _opening_storey(d) != level and _has_storey_metadata(d):
						continue
					if d["exterior"]:
						continue
					if not _on_run(from, to, normal, d["pos"], d["normal"]):
						continue
					openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
						"bottom": 0.0, "top": HouseGeometry.DOOR_H, "kind": "door",
						"normal": normal})
				_wall_run(from, to, HouseGeometry.INNER_WALL_T, h, openings, SURF_WALL, y0)
				var suffix := "" if _storeys() == 1 else "_%d" % level
				_log_mass("partition_%d_%d%s" % [i, j, suffix],
					_run_aabb(from, to, HouseGeometry.INNER_WALL_T, h, y0))


## Every door and window cut into one exterior wall run, as distances along it.
## Shared by the wall builder and the timber frame, so a stud can never be
## planted across a window the wall knows about.
func _openings_on(from: Vector2, to: Vector2, normal: Vector2, level := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in plan.doors:
		if _opening_storey(d) != level and _has_storey_metadata(d):
			continue
		if not d["exterior"]:
			continue
		if not _on_run(from, to, normal, d["pos"], d["normal"]):
			continue
		out.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
			"bottom": 0.0, "top": HouseGeometry.DOOR_H, "kind": "door",
			"normal": normal})
	for w in plan.windows:
		if _opening_storey(w) != level and _has_storey_metadata(w):
			continue
		if not _on_run(from, to, normal, w["pos"], w["normal"]):
			continue
		out.append({"t": _along(from, to, w["pos"]), "w": float(w["width"]),
			"bottom": float(w["sill"]), "top": float(w["head"]), "kind": "window",
			"normal": normal})
	return out


## One wall, with its openings cut out of it.
##
## Piers between the openings, a panel over each head, a panel under each sill.
## The openings arrive as distances along the run, which is the only way to
## place a door on a wall that might run along either axis without writing the
## whole thing twice.
func _wall_run(from: Vector2, to: Vector2, thick: float, height: float,
		openings: Array[Dictionary], surf: int, y_offset := 0.0) -> void:
	var seg: Vector2 = to - from
	var run: float = seg.length()
	if run < 0.01:
		return
	var dir: Vector2 = seg / run
	var yaw: float = atan2(-dir.y, dir.x)
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))

	var cursor := 0.0
	for op in openings:
		var t: float = float(op["t"])
		var w: float = float(op["w"])
		var lo: float = t - w / 2.0
		var hi: float = t + w / 2.0
		if lo > cursor + 0.01:
			_wall_piece(from, dir, yaw, cursor, lo, 0.0, height, thick, surf, y_offset)
		var bottom: float = float(op["bottom"])
		var top: float = float(op["top"])
		if bottom > 0.01:
			_wall_piece(from, dir, yaw, lo, hi, 0.0, bottom, thick, surf, y_offset)
		if top < height - 0.01:
			_wall_piece(from, dir, yaw, lo, hi, top, height, thick, surf, y_offset)
		_opening_trim(from, dir, yaw, t, w, bottom, top, thick, op, y_offset)
		cursor = maxf(cursor, hi)
	if cursor < run - 0.01:
		_wall_piece(from, dir, yaw, cursor, run, 0.0, height, thick, surf, y_offset)


func _wall_piece(from: Vector2, dir: Vector2, yaw: float, t0: float, t1: float,
		y0: float, y1: float, thick: float, surf: int, y_offset := 0.0) -> void:
	var length: float = t1 - t0
	if length <= 0.01 or y1 - y0 <= 0.01:
		return
	var mid: Vector2 = from + dir * ((t0 + t1) / 2.0)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y_offset + (y0 + y1) / 2.0, mid.y))
	_kit.oriented_box(Vector3(length, y1 - y0, thick), xf, surf)


## The frame round an opening, and the log entry the QA checks read.
##
## `facing` is logged for the normals suite, which proves every opening looks
## OUT through its wall rather than along it -- the same check the churches and
## castles get, and the reason a window cut into the wrong face is caught.
func _opening_trim(from: Vector2, dir: Vector2, yaw: float, t: float, w: float,
		bottom: float, top: float, thick: float, op: Dictionary, y_offset := 0.0) -> void:
	var mid: Vector2 = from + dir * t
	var normal: Vector2 = op["normal"]
	var face: float = atan2(normal.x, normal.y)
	_log_part("window", Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y),
		Vector3(w, top - bottom, 0.0), face, Vector3(normal.x, 0.0, normal.y))
	var jamb := 0.09
	for side in [-1.0, 1.0]:
		var p: Vector2 = from + dir * (t + side * (w / 2.0 + jamb / 2.0))
		var xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(p.x, y_offset + (bottom + top) / 2.0, p.y))
		_kit.oriented_box(Vector3(jamb, top - bottom, thick + 0.04), xf, SURF_TRIM)
	var head_xf := Transform3D(Basis(Vector3.UP, yaw),
		Vector3(mid.x, y_offset + top + jamb / 2.0, mid.y))
	_kit.oriented_box(Vector3(w + jamb * 2.0, jamb, thick + 0.04), head_xf, SURF_TRIM)
	if bottom > 0.01:
		var sill_xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(mid.x, y_offset + bottom - jamb / 2.0, mid.y))
		_kit.oriented_box(Vector3(w + jamb * 2.0, jamb, thick + 0.12), sill_xf, SURF_TRIM)
		if spec.window_shutters and op["kind"] == "window":
			for side2 in [-1.0, 1.0]:
				var sp: Vector2 = from + dir * (t + side2 * (w * 0.75)) \
					+ normal * (thick / 2.0 + 0.03)
				var sxf := Transform3D(Basis(Vector3.UP, yaw),
					Vector3(sp.x, y_offset + (bottom + top) / 2.0, sp.y))
				_kit.oriented_box(Vector3(w * 0.45, top - bottom, 0.05), sxf, SURF_TRIM)


## Is an opening on this wall run: same line, and between its ends?
static func _on_run(from: Vector2, to: Vector2, normal: Vector2, pos: Vector2,
		op_normal: Vector2) -> bool:
	if absf(absf(normal.x) - absf(op_normal.x)) > 0.01:
		return false
	var seg: Vector2 = to - from
	var run: float = seg.length()
	if run < 0.01:
		return false
	var dir: Vector2 = seg / run
	var rel: Vector2 = pos - from
	var t: float = rel.dot(dir)
	var off: float = absf(rel.dot(Vector2(dir.y, -dir.x)))
	# an exterior opening is recorded on the INNER face of its wall, so allow
	# half a wall's slack across the run
	return off <= HouseGeometry.WALL_T / 2.0 + 0.02 and t >= -0.01 and t <= run + 0.01


static func _along(from: Vector2, to: Vector2, pos: Vector2) -> float:
	var seg: Vector2 = to - from
	return (pos - from).dot(seg / maxf(seg.length(), 0.01))


static func _run_aabb(from: Vector2, to: Vector2, thick: float, height: float,
		y_offset := 0.0) -> AABB:
	var a := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * (thick / 2.0)
	var b := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * (thick / 2.0)
	return AABB(Vector3(a.x, y_offset, a.y), Vector3(b.x - a.x, height, b.y - a.y))


## Plans made before the upper-floor schema default all records to ground level.
func _storeys() -> int:
	var raw = spec.get("storeys")
	return maxi(1, int(raw)) if raw != null else 1


static func _has_storey_metadata(record: Dictionary) -> bool:
	return record.has("storey") or record.has("level")


static func _room_storey(record: Dictionary) -> int:
	return int(record.get("storey", record.get("level", 0)))


static func _opening_storey(record: Dictionary) -> int:
	return int(record.get("storey", record.get("level", 0)))


# ---------------------------------------------------------------- timber

## Exposed beams on the outside walls: the half-timbering that makes a
## plastered box read as medieval.
##
## Laid out the way a carpenter would lay it out rather than as a pattern
## stamped on the wall -- sill along the bottom, wall plate along the top,
## heavier posts at the corners, studs between them at the style's own
## spacing, a mid rail at sill height, and a brace across each corner. The
## studs read the same opening list the wall itself was built from, so one can
## never end up planted across a window.
func _build_timber_frame() -> void:
	for level in range(_storeys()):
		_build_timber_frame_level(level)


func _build_timber_frame_level(level := 0) -> void:
	if not spec.timber_frame:
		return
	tag("timber")
	var h: float = spec.height
	var y0 := float(level) * h
	for run in HouseGeometry.exterior_runs(spec):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var normal: Vector2 = run["normal"]
		var seg: Vector2 = to - from
		var length: float = seg.length()
		if length < 0.5:
			continue
		var dir: Vector2 = seg / length
		var yaw: float = atan2(-dir.y, dir.x)
		var openings: Array[Dictionary] = _openings_on(from, to, normal, level)

		# sill and wall plate, the full length of the wall
		_beam(from, dir, yaw, normal, length / 2.0, length,
			0.0, HouseGeometry.SILL_BEAM_H, 0.0, y0)
		_beam(from, dir, yaw, normal, length / 2.0, length,
			h - HouseGeometry.PLATE_H, h, 0.0, y0)
		if spec.frame_rail:
			var rail_y: float = HouseGeometry.WINDOW_SILL - HouseGeometry.RAIL_H
			_rail_between(from, dir, yaw, normal, length, openings,
				rail_y, rail_y + HouseGeometry.RAIL_H, y0)

		# corner posts, then studs between them
		var post: float = HouseGeometry.POST_W
		for t in [post / 2.0, length - post / 2.0]:
			_beam(from, dir, yaw, normal, t, post, 0.0, h, post * 0.55, y0)
		var pitch: float = spec.stud_pitch
		var bays: int = maxi(int((length - post * 2.0) / pitch), 1)
		for i in range(1, bays):
			var t2: float = post + (length - post * 2.0) * float(i) / float(bays)
			if _blocked_by_opening(openings, t2, HouseGeometry.BEAM_W):
				continue
			_beam(from, dir, yaw, normal, t2, HouseGeometry.BEAM_W,
				HouseGeometry.SILL_BEAM_H, h - HouseGeometry.PLATE_H, 0.0, y0)

		if spec.frame_braces:
			_corner_braces(from, dir, yaw, normal, length, h, openings, y0)


## A horizontal beam broken by the openings it runs into: it passes over a
## window head or under a sill where it can, and stops at a doorway.
func _rail_between(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, openings: Array[Dictionary], y0: float, y1: float,
		y_offset := 0.0) -> void:
	var cuts: Array = []
	for op in openings:
		if float(op["bottom"]) > y1 or float(op["top"]) < y0:
			continue          # the rail passes clear above or below it
		cuts.append([float(op["t"]) - float(op["w"]) / 2.0,
			float(op["t"]) + float(op["w"]) / 2.0])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cursor := 0.0
	for cut in cuts:
		var lo: float = float(cut[0])
		if lo > cursor + 0.1:
			_beam(from, dir, yaw, normal, (cursor + lo) / 2.0, lo - cursor,
				y0, y1, 0.0, y_offset)
		cursor = maxf(cursor, float(cut[1]))
	if cursor < length - 0.1:
		_beam(from, dir, yaw, normal, (cursor + length) / 2.0, length - cursor,
			y0, y1, 0.0, y_offset)


## The diagonals that stop a timber frame racking, one across each corner of
## the wall. Emitted as a tilted beam, which is what they are.
func _corner_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset := 0.0) -> void:
	var run: float = minf(HouseGeometry.BRACE_RUN, length * 0.3)
	var rise: float = run * 1.15
	if rise > h - HouseGeometry.PLATE_H - HouseGeometry.SILL_BEAM_H:
		return
	for side in [1.0, -1.0]:
		var foot: float = HouseGeometry.POST_W + run if side > 0.0 \
			else length - HouseGeometry.POST_W - run
		if _blocked_by_opening(openings, foot, run):
			continue
		var mid_t: float = foot - side * run / 2.0
		var mid_y: float = h - HouseGeometry.PLATE_H - rise / 2.0
		var span: float = sqrt(run * run + rise * rise)
		var tilt: float = atan2(rise, run) * side
		var p: Vector2 = from + dir * mid_t + normal * _proud(HouseGeometry.BEAM_D)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + mid_y, p.y))
		xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt), Vector3.ZERO)
		_kit.oriented_box(Vector3(span, HouseGeometry.BEAM_W * 0.9,
			HouseGeometry.BEAM_D), xf, SURF_TRIM)


## Is a beam of this width going to land on a door or a window?
static func _blocked_by_opening(openings: Array[Dictionary], t: float,
		width: float) -> bool:
	for op in openings:
		var half: float = float(op["w"]) / 2.0 + width / 2.0 + HouseGeometry.STUD_CLEAR
		if absf(t - float(op["t"])) < half:
			return true
	return false


## One beam, standing proud of the wall face it is fixed to.
func _beam(from: Vector2, dir: Vector2, yaw: float, normal: Vector2, t: float,
		length: float, y0: float, y1: float, depth := 0.0, y_offset := 0.0) -> void:
	if length <= 0.02 or y1 - y0 <= 0.02:
		return
	var d: float = depth if depth > 0.0 else HouseGeometry.BEAM_D
	var p: Vector2 = from + dir * t + normal * _proud(d)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + (y0 + y1) / 2.0, p.y))
	_kit.oriented_box(Vector3(length, y1 - y0, d), xf, SURF_TRIM)


## How far out from the wall centre-line a beam of this depth sits: against the
## plaster, with a hair of overlap so no seam shows.
static func _proud(depth: float) -> float:
	return HouseGeometry.WALL_T / 2.0 + depth / 2.0 - 0.015


# ------------------------------------------------------------------- roof

func _build_roof() -> void:
	tag("roof")
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var rise: float = HouseGeometry.roof_rise(spec)
	var along_x: bool = r.size.x > r.size.y
	var yaw: float = PI / 2.0 if along_x else 0.0
	var span: float = r.size.y if along_x else r.size.x
	var along: float = r.size.x if along_x else r.size.y
	var wall_top := spec.height * _storeys()
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, wall_top, 0.0))
	_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)
	var overhang_x := 0.25 if along_x else 0.35
	var overhang_z := 0.35 if along_x else 0.25
	_log_mass("roof" if _storeys() == 1 else "roof_%d" % (_storeys() - 1),
		AABB(Vector3(r.position.x - overhang_x, wall_top, r.position.y - overhang_z),
			Vector3(r.size.x + overhang_x * 2.0, rise + 0.25,
				r.size.y + overhang_z * 2.0)))
	total_height = maxf(total_height, wall_top + rise)
	if spec.timber_frame:
		_gable_frame(xf, span, along, rise)


## The frame in the gable end: a king post up to the ridge with a strut either
## side of it. A blank plastered triangle over a framed wall is the one thing
## that gives away a frame drawn rather than built.
func _gable_frame(xf: Transform3D, span: float, along: float, rise: float) -> void:
	var half: float = span / 2.0
	for end_v in [-1.0, 1.0]:
		var z: float = end_v * (along / 2.0 + HouseGeometry.BEAM_D / 2.0 - 0.01)
		# king post
		_kit.oriented_box(Vector3(HouseGeometry.BEAM_W, rise * 0.94,
			HouseGeometry.BEAM_D),
			xf * Transform3D(Basis(), Vector3(0.0, rise * 0.47, z)), SURF_TRIM)
		# a strut either side, following the pitch of the roof above it
		for side in [-1.0, 1.0]:
			var run: float = half * 0.55
			var lift: float = rise * 0.5
			var length: float = sqrt(run * run + lift * lift)
			var tilt: float = -atan2(lift, run) * side
			var t := xf * Transform3D(Basis(Vector3(0, 0, 1), tilt),
				Vector3(side * run / 2.0, lift / 2.0, z))
			_kit.oriented_box(Vector3(length, HouseGeometry.BEAM_W * 0.85,
				HouseGeometry.BEAM_D), t, SURF_TRIM)


func _build_porch() -> void:
	if not spec.porch:
		return
	var d: int = plan.entrance()
	if d < 0:
		return
	tag("porch")
	var door: Dictionary = plan.doors[d]
	var depth: float = HouseGeometry.porch_depth(spec)
	var w: float = float(door["width"]) + 1.1
	var c: Vector2 = door["pos"] + door["normal"] * (depth / 2.0)
	var head: float = HouseGeometry.DOOR_H + 0.35
	# a step for the porch to stand on: without it the posts are two sticks in
	# the garden, which is exactly what the no-gaps check called them
	var step := AABB(Vector3(c.x - w / 2.0, 0.0, c.y - depth / 2.0 - 0.1),
		Vector3(w, HouseGeometry.FLOOR_T, depth + 0.2 + HouseGeometry.WALL_T))
	box(step.size, step.position + step.size / 2.0, SURF_FLOOR)
	_log_mass("porch_step", step)
	for side in [-1.0, 1.0]:
		var p: Vector2 = c + Vector2(side * (w / 2.0 - 0.1), 0.0) \
			+ door["normal"] * (depth / 2.0 - 0.12)
		box(Vector3(0.14, head, 0.14), Vector3(p.x, head / 2.0, p.y), SURF_TRIM)
		_log_mass("porch_post_%s" % ("left" if side < 0.0 else "right"),
			AABB(Vector3(p.x - 0.07, 0.0, p.y - 0.07), Vector3(0.14, head, 0.14)))
	var xf := Transform3D(Basis(), Vector3(c.x, head, c.y))
	_kit.ridge_roof(xf, w, depth + 0.2, 0.42, SURF_ROOF)


func _build_chimney() -> void:
	if not spec.chimney:
		return
	tag("chimney")
	var s: float = HouseGeometry.chimney_size(spec)
	var host: int = _hearth_room()
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var c := Vector2(r.end.x + s / 2.0 - 0.15, 0.0)
	if host >= 0:
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, host)
		# put the stack on whichever long wall of the hearth room is outside
		var on_right: bool = absf(f.end.x - HouseGeometry.interior_rect(spec).end.x) < 0.02
		c = Vector2(r.end.x + s / 2.0 - 0.15 if on_right else r.position.x - s / 2.0 + 0.15,
			f.get_center().y)
	# A stack clears the roof beside it, not the ridge at the far end of the
	# house. On a steeply pitched hut the ridge is six metres up, and a chimney
	# built to that reads as a factory.
	var wall_top: float = spec.height * _storeys()
	var top: float = wall_top + minf(HouseGeometry.roof_rise(spec), 2.0) + 0.9
	# stone rather than plaster: a chimney is the one part of a timber-framed
	# house that is neither, and the floor colour is the nearest thing this
	# palette has to masonry
	box(Vector3(s, top, s), Vector3(c.x, top / 2.0, c.y), SURF_FLOOR)
	_log_mass("chimney", AABB(Vector3(c.x - s / 2.0, 0.0, c.y - s / 2.0),
		Vector3(s, top, s)))
	box(Vector3(s + 0.2, 0.16, s + 0.2), Vector3(c.x, top + 0.08, c.y), SURF_TRIM)
	total_height = maxf(total_height, top + 0.16)


## The room the chimney serves: the kitchen if there is one, else the hall.
func _hearth_room() -> int:
	for kind in [&"kitchen", &"hall", &"workshop"]:
		var rooms: Array[int] = plan.rooms_of(kind)
		if not rooms.is_empty():
			return rooms[0]
	return -1
