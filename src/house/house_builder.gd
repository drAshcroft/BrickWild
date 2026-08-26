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
	var a := AABB(Vector3(r.position.x, 0.0, r.position.y),
		Vector3(r.size.x, t, r.size.y))
	box(a.size, a.position + a.size / 2.0, SURF_FLOOR)
	_log_mass("floor", a)


# ------------------------------------------------------------------ walls

func _build_exterior_walls() -> void:
	tag("wall")
	var h: float = spec.height
	for run in HouseGeometry.exterior_runs(spec):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var normal: Vector2 = run["normal"]
		var openings: Array[Dictionary] = []
		for d in plan.doors:
			if not d["exterior"]:
				continue
			if not _on_run(from, to, normal, d["pos"], d["normal"]):
				continue
			openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
				"bottom": 0.0, "top": HouseGeometry.DOOR_H, "kind": "door",
				"normal": normal})
		for w in plan.windows:
			if not _on_run(from, to, normal, w["pos"], w["normal"]):
				continue
			openings.append({"t": _along(from, to, w["pos"]), "w": float(w["width"]),
				"bottom": float(w["sill"]), "top": float(w["head"]), "kind": "window",
				"normal": normal})
		_wall_run(from, to, HouseGeometry.WALL_T, h, openings, SURF_WALL)
		var a: AABB = _run_aabb(from, to, HouseGeometry.WALL_T, h)
		_log_mass("wall_%s" % String(run["side"]), a)
	total_height = maxf(total_height, h)


func _build_partitions() -> void:
	tag("partition")
	var h: float = spec.height
	var seen := {}
	for i in range(plan.room_count()):
		for j in range(i + 1, plan.room_count()):
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
				if d["exterior"]:
					continue
				if not _on_run(from, to, normal, d["pos"], d["normal"]):
					continue
				openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
					"bottom": 0.0, "top": HouseGeometry.DOOR_H, "kind": "door",
					"normal": normal})
			_wall_run(from, to, HouseGeometry.INNER_WALL_T, h, openings, SURF_WALL)
			_log_mass("partition_%d_%d" % [i, j],
				_run_aabb(from, to, HouseGeometry.INNER_WALL_T, h))


## One wall, with its openings cut out of it.
##
## Piers between the openings, a panel over each head, a panel under each sill.
## The openings arrive as distances along the run, which is the only way to
## place a door on a wall that might run along either axis without writing the
## whole thing twice.
func _wall_run(from: Vector2, to: Vector2, thick: float, height: float,
		openings: Array[Dictionary], surf: int) -> void:
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
			_wall_piece(from, dir, yaw, cursor, lo, 0.0, height, thick, surf)
		var bottom: float = float(op["bottom"])
		var top: float = float(op["top"])
		if bottom > 0.01:
			_wall_piece(from, dir, yaw, lo, hi, 0.0, bottom, thick, surf)
		if top < height - 0.01:
			_wall_piece(from, dir, yaw, lo, hi, top, height, thick, surf)
		_opening_trim(from, dir, yaw, t, w, bottom, top, thick, op)
		cursor = maxf(cursor, hi)
	if cursor < run - 0.01:
		_wall_piece(from, dir, yaw, cursor, run, 0.0, height, thick, surf)


func _wall_piece(from: Vector2, dir: Vector2, yaw: float, t0: float, t1: float,
		y0: float, y1: float, thick: float, surf: int) -> void:
	var length: float = t1 - t0
	if length <= 0.01 or y1 - y0 <= 0.01:
		return
	var mid: Vector2 = from + dir * ((t0 + t1) / 2.0)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, (y0 + y1) / 2.0, mid.y))
	_kit.oriented_box(Vector3(length, y1 - y0, thick), xf, surf)


## The frame round an opening, and the log entry the QA checks read.
##
## `facing` is logged for the normals suite, which proves every opening looks
## OUT through its wall rather than along it -- the same check the churches and
## castles get, and the reason a window cut into the wrong face is caught.
func _opening_trim(from: Vector2, dir: Vector2, yaw: float, t: float, w: float,
		bottom: float, top: float, thick: float, op: Dictionary) -> void:
	var mid: Vector2 = from + dir * t
	var normal: Vector2 = op["normal"]
	var face: float = atan2(normal.x, normal.y)
	_log_part("window", Vector3(mid.x, (bottom + top) / 2.0, mid.y),
		Vector3(w, top - bottom, 0.0), face, Vector3(normal.x, 0.0, normal.y))
	var jamb := 0.09
	for side in [-1.0, 1.0]:
		var p: Vector2 = from + dir * (t + side * (w / 2.0 + jamb / 2.0))
		var xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(p.x, (bottom + top) / 2.0, p.y))
		_kit.oriented_box(Vector3(jamb, top - bottom, thick + 0.04), xf, SURF_TRIM)
	var head_xf := Transform3D(Basis(Vector3.UP, yaw),
		Vector3(mid.x, top + jamb / 2.0, mid.y))
	_kit.oriented_box(Vector3(w + jamb * 2.0, jamb, thick + 0.04), head_xf, SURF_TRIM)
	if bottom > 0.01:
		var sill_xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(mid.x, bottom - jamb / 2.0, mid.y))
		_kit.oriented_box(Vector3(w + jamb * 2.0, jamb, thick + 0.12), sill_xf, SURF_TRIM)
		if spec.window_shutters and op["kind"] == "window":
			for side2 in [-1.0, 1.0]:
				var sp: Vector2 = from + dir * (t + side2 * (w * 0.75)) \
					+ normal * (thick / 2.0 + 0.03)
				var sxf := Transform3D(Basis(Vector3.UP, yaw),
					Vector3(sp.x, (bottom + top) / 2.0, sp.y))
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


static func _run_aabb(from: Vector2, to: Vector2, thick: float, height: float) -> AABB:
	var a := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * (thick / 2.0)
	var b := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * (thick / 2.0)
	return AABB(Vector3(a.x, 0.0, a.y), Vector3(b.x - a.x, height, b.y - a.y))


# ------------------------------------------------------------------- roof

func _build_roof() -> void:
	tag("roof")
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var rise: float = HouseGeometry.roof_rise(spec)
	var along_x: bool = r.size.x > r.size.y
	var yaw: float = PI / 2.0 if along_x else 0.0
	var span: float = r.size.y if along_x else r.size.x
	var along: float = r.size.x if along_x else r.size.y
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, spec.height, 0.0))
	_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)
	total_height = maxf(total_height, spec.height + rise)


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
	var top: float = spec.height + minf(HouseGeometry.roof_rise(spec), 2.0) + 0.9
	box(Vector3(s, top, s), Vector3(c.x, top / 2.0, c.y), SURF_WALL)
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
