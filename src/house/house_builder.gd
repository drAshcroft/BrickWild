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
## Actual emitted architectural faces, including cut host pieces and dormer joins.
## Each row is also a row of `component_log`; see MassBuilder.
var roof_components: Array[Dictionary] = []
## Emission counter that names each opening's surround, so the trim round the
## third window is identifiably the third window's on every rebuild.
var _opening_seq := 0


## `with_roof` is the one thing a caller may switch off: a furnished interior
## cannot be photographed through its own thatch. Nothing else changes, so the
## walls and the openings the checks measure are the same either way.
func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	plan = p_plan
	spec = p_plan.spec
	begin(4)
	total_height = spec.height

	_build_floor()
	_build_plinth()
	_build_exterior_walls()
	_build_partitions()
	if spec.material != &"stone":
		_build_jetty()
		_build_timber_frame()
	if with_roof:
		_build_roof()
	_build_porch()
	_build_chimney()
	return commit()


# ------------------------------------------------------------------ floor

## Reset the house's own per-build records alongside the shared logs. This
## belongs on begin() rather than on build(): HotelBuilder overrides build()
## and does not call super, so a subclass would otherwise carry the previous
## run's opening numbering into the next one and its component identities
## would drift.
func begin(surface_count: int) -> void:
	super.begin(surface_count)
	roof_components.clear()
	_opening_seq = 0


func _build_floor() -> void:
	tag("floor")
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var t: float = HouseGeometry.FLOOR_T
	for level in _levels():
		var y0 := float(level) * spec.height
		var a := AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y))
		var holes: Array[int] = plan.courts_on(level)
		if not holes.is_empty():
			# The floor is laid round the yard, band by band, so the court is
			# left as open ground for the walk grid to rasterise.
			_emit_floor_round_courts(r, y0, t, level, holes)
			continue
		var shaped: int = _shaped_room(level)
		if shaped >= 0:
			# The floor of a shaped storey is the shape, pushed out to the
			# middle of its own wall so the slab and the masonry meet.
			var poly: PackedVector2Array = Poly.offset(plan.outline_of(shaped),
				HouseGeometry.wall_thickness(spec) / 2.0)
			var pieces: Array[PackedVector2Array] = [poly]
			var stair_hole := _stair_opening(level)
			if stair_hole.has_area():
				pieces = RoofShape.subtract(poly, Poly.from_rect(stair_hole))
			for pi in pieces.size():
				_kit.slab_poly(_lift(pieces[pi], y0 + t / 2.0), t, SURF_FLOOR)
				var bounds := Poly.bounding_rect(pieces[pi])
				var floor_name := "floor" if _levels().size() == 1 else "floor_%d" % level
				if pieces.size() > 1:
					floor_name += "_%d" % pi
				_log_mass(floor_name, AABB(Vector3(bounds.position.x, y0, bounds.position.y),
					Vector3(bounds.size.x, t, bounds.size.y)), y0)
			continue
		var opening := _stair_opening(level)
		if opening.size.x > 0.01 and opening.size.y > 0.01:
			_emit_floor_around(r, opening, y0, t, level)
		else:
			box(a.size, a.position + a.size / 2.0, SURF_FLOOR)
			_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level, a, y0)
	_build_pits()
	_emit_stairs()


## A storey below the ground is dug, not raised (INT-016): the pit is logged
## as a negative mass, `dug`, the size of the site and a storey deep, so the
## structural rules know there is earth outside the cellar's walls rather
## than air. The walls and floor inside it stand on the pit floor.
func _build_pits() -> void:
	var r: Rect2 = HouseGeometry.site_rect(spec)
	for level in _levels():
		if level >= 0:
			continue
		var y0 := float(level) * spec.height
		var pit := AABB(Vector3(r.position.x - HouseGeometry.wall_thickness(spec), y0, r.position.y - HouseGeometry.wall_thickness(spec)),
			Vector3(r.size.x + 2.0 * HouseGeometry.wall_thickness(spec), spec.height, r.size.y + 2.0 * HouseGeometry.wall_thickness(spec)))
		mass_log.append({"name": "pit_%d" % level, "aabb": pit, "ground": y0, "kind": "dug"})


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
			_log_mass("floor_%d_%d" % [level, emitted], AABB(centre - size / 2.0, size), y0)
			emitted += 1


func _stair_opening(level: int) -> Rect2:
	if level <= _lowest():
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
		# the flight climbs along the footprint's long side, which is the axis
		# the planner laid the well on (it runs the room's long way, LAY-005)
		var along_x: bool = footprint.size.x > footprint.size.y
		var run: float = footprint.size.x if along_x else footprint.size.y
		for s in range(steps):
			var t: float = run * (float(s) + 0.5) / steps
			var h := step_h * float(s + 1)
			var step_size := Vector3(run / steps, h, footprint.size.y) if along_x \
				else Vector3(footprint.size.x, h, run / steps)
			var step_center := Vector3(footprint.position.x + t,
					from_level * spec.height + h / 2.0, footprint.get_center().y) \
				if along_x else Vector3(footprint.get_center().x,
					from_level * spec.height + h / 2.0, footprint.position.y + t)
			box(step_size, step_center, SURF_FLOOR)
			_log_mass("stair_%d_step_%d" % [index, s],
				AABB(step_center - step_size / 2.0, step_size), from_level * spec.height)


# ------------------------------------------------------------------ plinth

func _build_plinth() -> void:
	tag("plinth")
	var plinth_h: float = minf(spec.plinth_height, HouseGeometry.WINDOW_SILL - 0.18)
	if plinth_h <= 0.05 or (spec.stone_ground_floor and _storeys() > 1):
		return
	var thick: float = HouseGeometry.wall_thickness(spec) + HouseGeometry.PLINTH_EXTRA * 2.0
	for run in HouseGeometry.exterior_runs(spec):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var normal: Vector2 = run["normal"]
		var openings: Array[Dictionary] = []
		# Leave gaps for exterior doors on level 0
		for d in plan.doors:
			if _opening_storey(d) != 0 and _has_storey_metadata(d):
				continue
			if not d["exterior"]:
				continue
			if not _on_run(from, to, normal, d["pos"], d["normal"]):
				continue
			openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]) + 0.12,
				"bottom": 0.0, "top": plinth_h + 0.05, "kind": "door", "normal": normal})
		# These are clearances, not additional framed doors. Framing the short
		# plinth opening used to put a second lintel across the real doorway.
		_wall_run(from, to, thick, plinth_h, openings, SURF_FLOOR, 0.0, false)
		# Chamfered stone water-table moulding at the top of the plinth
		var seg: Vector2 = to - from
		var run_len: float = seg.length()
		if run_len > 0.1:
			_wall_run(from, to, thick + 0.04, 0.06, openings, SURF_FLOOR,
				plinth_h - 0.03, false)


# ------------------------------------------------------------------ walls

func _build_exterior_walls() -> void:
	tag("wall")
	var h: float = spec.height
	for level in _levels():
		var y0 := float(level) * h
		var surf: int = SURF_FLOOR if (spec.stone_ground_floor and level == 0) else SURF_WALL
		for run in HouseGeometry.shell_runs(plan, level):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var normal: Vector2 = run["normal"]
			var openings: Array[Dictionary] = _openings_on(from, to, normal, level)
			_wall_run(from, to, HouseGeometry.wall_thickness(spec), h, openings, surf, y0)
			var a: AABB = _run_aabb(from, to, HouseGeometry.wall_thickness(spec), h, y0)
			var suffix := "" if _levels().size() == 1 else "_%d" % level
			_log_mass("wall_%s%s" % [String(run["side"]), suffix], a, y0)
	total_height = maxf(total_height, h * _storeys())


# ------------------------------------------------------------------ jetty

func _build_jetty() -> void:
	if not spec.jetty or _storeys() <= 1:
		return
	tag("jetty")
	host("jetty", 1)
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var j_depth: float = spec.jetty_depth
	var bressummer_y: float = spec.height
	var beam_h := 0.22
	var beam_w := 0.20

	# 1. Bressummer beam running along the front wall at y = spec.height
	var bw_len: float = r.size.x + 0.35
	box(Vector3(bw_len, beam_h, beam_w),
		Vector3(0.0, bressummer_y - beam_h / 2.0, r.position.y - j_depth / 2.0), SURF_TRIM)

	# 2. Exposed floor joist ends projecting under the bressummer
	var joist_spacing := 0.65
	var joist_count := maxi(int(r.size.x / joist_spacing), 3)
	for i in range(joist_count + 1):
		var jx: float = r.position.x + float(i) * (r.size.x / float(joist_count))
		box(Vector3(0.12, 0.14, j_depth + 0.10),
			Vector3(jx, bressummer_y - beam_h - 0.07, r.position.y - j_depth / 2.0), SURF_TRIM)

	# 3. Carved knee brackets / corner corbels supporting the bressummer
	for px in [r.position.x + 0.35, r.end.x - 0.35]:
		var bracket_span: float = minf(j_depth * 1.2, 0.35)
		var bracket_lift: float = bracket_span * 1.4
		var span_len: float = sqrt(bracket_span * bracket_span + bracket_lift * bracket_lift)
		var tilt: float = atan2(bracket_lift, bracket_span)
		var xf := Transform3D(Basis(), Vector3(px, bressummer_y - beam_h - bracket_lift / 2.0, r.position.y - j_depth / 2.0))
		xf = xf * Transform3D(Basis(Vector3(1, 0, 0), -tilt), Vector3.ZERO)
		component_box("jetty_bracket", Vector3(0.15, span_len, 0.12), xf, SURF_TRIM)
	host_end()


func _build_partitions() -> void:
	tag("partition")
	var h: float = spec.height
	for level in _levels():
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
				var suffix := "" if _levels().size() == 1 else "_%d" % level
				_log_mass("partition_%d_%d%s" % [i, j, suffix],
					_run_aabb(from, to, HouseGeometry.INNER_WALL_T, h, y0), y0)


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
			"bottom": float(w["sill"]), "top": float(w["head"]),
			"kind": "hatch" if w.get("hatch", false) else "window",
			"normal": normal})
	return out


## One wall, with its openings cut out of it.
##
## Piers between the openings, a panel over each head, a panel under each sill.
## The openings arrive as distances along the run, which is the only way to
## place a door on a wall that might run along either axis without writing the
## whole thing twice.
func _wall_run(from: Vector2, to: Vector2, thick: float, height: float,
		openings: Array[Dictionary], surf: int, y_offset := 0.0, decorate := true) -> void:
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
		if decorate:
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
	# Keep the legacy log category for house consumers, while allowing family
	# composition to distinguish an emitted door from an emitted window.
	part_log[part_log.size() - 1]["opening_kind"] = String(op["kind"])
	# The surround belongs to THIS opening. HOUSE-EXT-008 and -010 both need to
	# ask what trim sits beside a given door; a flat list of trim boxes cannot
	# answer that, and reconstructing the answer from the spec would agree with
	# a sill that was never split.
	var outer_host := _comp_host
	var outer_storey := _comp_storey
	host("%s_%d" % [String(op["kind"]), _opening_seq], int(y_offset / maxf(spec.height, 0.01) + 0.5))
	_opening_seq += 1
	var jamb := 0.09
	for side in [-1.0, 1.0]:
		var p: Vector2 = from + dir * (t + side * (w / 2.0 + jamb / 2.0))
		var xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(p.x, y_offset + (bottom + top) / 2.0, p.y))
		component_box("opening_jamb", Vector3(jamb, top - bottom, thick + 0.04), xf, SURF_TRIM)
	var head_xf := Transform3D(Basis(Vector3.UP, yaw),
		Vector3(mid.x, y_offset + top + jamb / 2.0, mid.y))
	component_box("opening_head", Vector3(w + jamb * 2.0, jamb, thick + 0.04), head_xf, SURF_TRIM)
	if bottom > 0.01:
		var sill_xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(mid.x, y_offset + bottom - jamb / 2.0, mid.y))
		component_box("opening_sill", Vector3(w + jamb * 2.0, jamb, thick + 0.12), sill_xf, SURF_TRIM)
		if op["kind"] == "window":
			# Inset dark lattice glazing panel
			var pane_xf := Transform3D(Basis(Vector3.UP, yaw),
				Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y))
			component_box("opening_glazing", Vector3(w, top - bottom, 0.04), pane_xf, SURF_ROOF)

			# Vertical timber mullions for wide windows (2-light / 3-light)
			if spec.window_mullions and w >= 0.8:
				if w >= 1.35:
					for mside in [-1.0, 1.0]:
						var mp: Vector2 = from + dir * (t + mside * (w / 3.0))
						var mxf := Transform3D(Basis(Vector3.UP, yaw),
							Vector3(mp.x, y_offset + (bottom + top) / 2.0, mp.y))
						component_box("opening_mullion", Vector3(HouseGeometry.MULLION_W, top - bottom, thick + 0.06), mxf, SURF_TRIM)
				else:
					var mxf := Transform3D(Basis(Vector3.UP, yaw),
						Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y))
					component_box("opening_mullion", Vector3(HouseGeometry.MULLION_W, top - bottom, thick + 0.06), mxf, SURF_TRIM)

			# Dripstone hood moulding over window head
			if spec.window_hoods:
				var hood_xf := Transform3D(Basis(Vector3.UP, yaw),
					Vector3(mid.x, y_offset + top + jamb + 0.05, mid.y))
				component_box("opening_hood", Vector3(w + jamb * 2.4, 0.07, thick + HouseGeometry.HOOD_PROJECTION * 2.0),
					hood_xf, SURF_TRIM)

			# Board-and-batten shutters with strap hinges
			if spec.window_shutters:
				for side2 in [-1.0, 1.0]:
					var sp: Vector2 = from + dir * (t + side2 * (w * 0.75)) \
						+ normal * (thick / 2.0 + 0.03)
					var sxf := Transform3D(Basis(Vector3.UP, yaw),
						Vector3(sp.x, y_offset + (bottom + top) / 2.0, sp.y))
					component_box("opening_shutter", Vector3(w * 0.45, top - bottom, 0.05), sxf, SURF_TRIM)
					# Horizontal strap hinges
					for hy in [0.25, 0.75]:
						var hxf := Transform3D(Basis(Vector3.UP, yaw),
							Vector3(sp.x, y_offset + bottom + (top - bottom) * hy, sp.y + normal.y * 0.01))
						component_box("opening_hinge", Vector3(w * 0.40, 0.04, 0.07), hxf, SURF_TRIM)
	host(outer_host, outer_storey)


## Is an opening on this wall run: same line, and between its ends?
func _on_run(from: Vector2, to: Vector2, normal: Vector2, pos: Vector2,
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
	return off <= HouseGeometry.wall_thickness(spec) / 2.0 + 0.02 and t >= -0.01 and t <= run + 0.01


static func _along(from: Vector2, to: Vector2, pos: Vector2) -> float:
	var seg: Vector2 = to - from
	return (pos - from).dot(seg / maxf(seg.length(), 0.01))


static func _run_aabb(from: Vector2, to: Vector2, thick: float, height: float,
		y_offset := 0.0) -> AABB:
	var a := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * (thick / 2.0)
	var b := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * (thick / 2.0)
	return AABB(Vector3(a.x, y_offset, a.y), Vector3(b.x - a.x, height, b.y - a.y))


## Plans made before the upper-floor schema default all records to ground level.
## Storeys above the ground; the roof and the chimney are measured off them.
## The floor of a storey with a yard in it: four bands round the hole, so the
## court itself is left as ground.
func _emit_floor_round_courts(r: Rect2, y0: float, t: float, level: int,
		holes: Array[int]) -> void:
	var court: Rect2 = plan.courts[holes[0]]["rect"]
	for band in [
			Rect2(r.position.x, r.position.y, r.size.x, court.position.y - r.position.y),
			Rect2(r.position.x, court.end.y, r.size.x, r.end.y - court.end.y),
			Rect2(r.position.x, court.position.y, court.position.x - r.position.x, court.size.y),
			Rect2(court.end.x, court.position.y, r.end.x - court.end.x, court.size.y)]:
		if band.size.x < 0.05 or band.size.y < 0.05:
			continue
		box(Vector3(band.size.x, t, band.size.y),
			Vector3(band.get_center().x, y0 + t / 2.0, band.get_center().y),
			SURF_FLOOR)
	_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level,
		AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y)), y0)
	# and the yard itself, as paving a hand's breadth down
	if level == 0:
		var pav := 0.08
		box(Vector3(court.size.x, pav, court.size.y),
			Vector3(court.get_center().x, y0 - pav / 2.0, court.get_center().y),
			SURF_FLOOR)


## The shaped room on `level`, or -1 when that storey is rectangular.
func _shaped_room(level: int) -> int:
	for i in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[i]) == level and plan.is_polygonal(i):
			return i
	return -1


## A plan polygon lifted to a height, for the slab emitters.
static func _lift(poly: PackedVector2Array, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in poly:
		out.append(Vector3(p.x, y, p.y))
	return out


func _storeys() -> int:
	var raw = spec.get("storeys")
	return maxi(1, int(raw)) if raw != null else 1


## Storeys dug below the ground (INT-016), 0 for a house without a cellar.
func _lowest() -> int:
	var raw = spec.get("cellars")
	return -maxi(0, int(raw)) if raw != null else 0


## Every level the shell is built on, lowest first.
func _levels() -> Array[int]:
	var out: Array[int] = []
	for level in range(_lowest(), _storeys()):
		out.append(level)
	return out


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
	if spec.stone_ground_floor and level == 0:
		_build_stone_quoins(level)
		return
	tag("timber")
	host("frame_%d" % level, level)
	var h: float = spec.height
	var y0 := float(level) * h
	var plinth_offset := (minf(spec.plinth_height, HouseGeometry.WINDOW_SILL - 0.18) if (level == 0 and not spec.stone_ground_floor and spec.plinth_height > 0.05) else 0.0)
	var y_sill := plinth_offset

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
		_rail_between(from, dir, yaw, normal, length, openings,
			y_sill, y_sill + HouseGeometry.SILL_BEAM_H, y0)
		_beam(from, dir, yaw, normal, length / 2.0, length,
			h - HouseGeometry.PLATE_H, h, 0.0, y0)
		if spec.frame_rail:
			var rail_y: float = HouseGeometry.WINDOW_SILL - HouseGeometry.RAIL_H
			_rail_between(from, dir, yaw, normal, length, openings,
				rail_y, rail_y + HouseGeometry.RAIL_H, y0)

		# corner posts, then studs between them
		var post: float = HouseGeometry.POST_W
		for t in [post / 2.0, length - post / 2.0]:
			_beam(from, dir, yaw, normal, t, post, y_sill, h, post * 0.55, y0)
		var pitch: float = spec.stud_pitch
		var bays: int = maxi(int((length - post * 2.0) / pitch), 1)
		for i in range(1, bays):
			var t2: float = post + (length - post * 2.0) * float(i) / float(bays)
			if _blocked_by_opening(openings, t2, HouseGeometry.BEAM_W):
				continue
			_beam(from, dir, yaw, normal, t2, HouseGeometry.BEAM_W,
				y_sill + HouseGeometry.SILL_BEAM_H, h - HouseGeometry.PLATE_H, 0.0, y0)

		# Bracing patterns
		match spec.framing_pattern:
			&"saltire":
				_saltire_braces(from, dir, yaw, normal, length, h, openings, y0, y_sill)
			&"arch_brace":
				_arch_braces(from, dir, yaw, normal, length, h, openings, y0, y_sill)
			_:
				if spec.frame_braces:
					_corner_braces(from, dir, yaw, normal, length, h, openings, y0)
	host_end()


func _build_stone_quoins(level: int) -> void:
	tag("quoins")
	var h: float = spec.height
	var y0 := float(level) * h
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var corners := [
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.end.x, r.end.y),
	]
	var quoin_h := 0.38
	var courses := int(h / quoin_h)
	for c in corners:
		for i in range(courses):
			var qw := 0.42 if (i % 2 == 0) else 0.56
			var qd := 0.56 if (i % 2 == 0) else 0.42
			box(Vector3(qw, quoin_h - 0.04, qd),
				Vector3(c.x, y0 + float(i) * quoin_h + quoin_h / 2.0, c.y), SURF_FLOOR)


func _saltire_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset: float, y_sill: float) -> void:
	var post: float = HouseGeometry.POST_W
	var pitch: float = spec.stud_pitch
	var bays: int = maxi(int((length - post * 2.0) / pitch), 1)
	var bay_w: float = (length - post * 2.0) / float(bays)
	var bottom: float = y_sill + HouseGeometry.SILL_BEAM_H
	var top: float = h - HouseGeometry.PLATE_H
	var bay_h: float = top - bottom
	var brace_len: float = sqrt(bay_w * bay_w + bay_h * bay_h)
	var tilt: float = atan2(bay_h, bay_w)

	for i in range(bays):
		var t_center: float = post + float(i + 0.5) * bay_w
		if _blocked_by_opening(openings, t_center, bay_w * 0.75):
			continue
		for sign in [1.0, -1.0]:
			var p: Vector2 = from + dir * t_center + normal * _proud(HouseGeometry.BEAM_D)
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + (bottom + top) / 2.0, p.y))
			xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt * sign), Vector3.ZERO)
			component_box("timber_brace", Vector3(brace_len * 0.95,
				HouseGeometry.BEAM_W * 0.72, HouseGeometry.BEAM_D * 0.88), xf, SURF_TRIM)


func _arch_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset: float, y_sill: float) -> void:
	var run: float = minf(HouseGeometry.BRACE_RUN * 1.1, length * 0.28)
	var rise: float = run * 1.2
	if rise > h - HouseGeometry.PLATE_H - y_sill:
		return
	for side in [1.0, -1.0]:
		var foot: float = HouseGeometry.POST_W + run if side > 0.0 else length - HouseGeometry.POST_W - run
		if _blocked_by_opening(openings, foot, run):
			continue
		var mid_t: float = foot - side * run / 2.0
		var mid_y: float = h - HouseGeometry.PLATE_H - rise / 2.0
		var span: float = sqrt(run * run + rise * rise)
		var tilt: float = atan2(rise, run) * side
		var p: Vector2 = from + dir * mid_t + normal * _proud(HouseGeometry.BEAM_D)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + mid_y, p.y))
		xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt), Vector3.ZERO)
		component_box("timber_brace", Vector3(span, HouseGeometry.BEAM_W * 0.9,
			HouseGeometry.BEAM_D), xf, SURF_TRIM)


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
		component_box("timber_brace", Vector3(span, HouseGeometry.BEAM_W * 0.9,
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
		length: float, y0: float, y1: float, depth := 0.0, y_offset := 0.0,
		role := "timber") -> void:
	if length <= 0.02 or y1 - y0 <= 0.02:
		return
	var d: float = depth if depth > 0.0 else HouseGeometry.BEAM_D
	var p: Vector2 = from + dir * t + normal * _proud(d)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + (y0 + y1) / 2.0, p.y))
	component_box(role, Vector3(length, y1 - y0, d), xf, SURF_TRIM)


## How far out from the wall centre-line a beam of this depth sits: against the
## plaster, with a hair of overlap so no seam shows.
func _proud(depth: float) -> float:
	return HouseGeometry.wall_thickness(spec) / 2.0 + depth / 2.0 - 0.015


# ------------------------------------------------------------------- roof

## How far the roof runs past the end wall at the gable: the verge.
const VERGE := 0.25
## How much of a half-hipped roof is still gable, measured up from the wall
## head. The rest is hipped off.
const HIP_CUT := 0.62


## A court is SKY. The roof is the footprint MINUS the courts, and with only
## slabs and boxes to build from, the honest way to say that is to roof each
## RANGE rather than the whole box: a lean-to falling from the outer wall in
## to the courtyard eaves, which is what a range round a yard actually has
## (GEO-003).
func _build_court_roofs() -> void:
	tag("roof")
	host("roof", _storeys() - 1)
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var wall_top: float = spec.height * _storeys()
	var rise: float = HouseGeometry.roof_rise(spec) * 0.7
	for ci in range(plan.courts.size()):
		var court: Rect2 = plan.courts[ci]["rect"]
		for side in range(4):
			var band: Rect2
			var outer: float
			var inner: float
			var horizontal: bool = side <= 1
			match side:
				0:
					band = Rect2(site.position.x, site.position.y,
						site.size.x, court.position.y - site.position.y)
					outer = site.position.y
					inner = court.position.y
				1:
					band = Rect2(site.position.x, court.end.y,
						site.size.x, site.end.y - court.end.y)
					outer = site.end.y
					inner = court.end.y
				2:
					band = Rect2(site.position.x, court.position.y,
						court.position.x - site.position.x, court.size.y)
					outer = site.position.x
					inner = court.position.x
				_:
					band = Rect2(court.end.x, court.position.y,
						site.end.x - court.end.x, court.size.y)
					outer = site.end.x
					inner = court.end.x
			if band.size.x < 0.3 or band.size.y < 0.3:
				continue
			# One sloping plate to a range, falling from the outer wall in to
			# the courtyard eaves -- which is what a cloister range has, and
			# the only roof shape that leaves the yard open.
			var lo: float = band.position.x if horizontal else band.position.y
			var hi: float = band.end.x if horizontal else band.end.y
			var quad := PackedVector3Array()
			if horizontal:
				quad.append(Vector3(lo, wall_top + rise, outer))
				quad.append(Vector3(hi, wall_top + rise, outer))
				quad.append(Vector3(hi, wall_top, inner))
				quad.append(Vector3(lo, wall_top, inner))
			else:
				quad.append(Vector3(outer, wall_top + rise, lo))
				quad.append(Vector3(outer, wall_top + rise, hi))
				quad.append(Vector3(inner, wall_top, hi))
				quad.append(Vector3(inner, wall_top, lo))
			roof_components.append(
				component_slab("roof_court_%d_%d" % [ci, side], quad, 0.24, SURF_ROOF))
			_log_mass("roof_court_%d_%d" % [ci, side],
				AABB(Vector3(band.position.x, wall_top, band.position.y),
					Vector3(band.size.x, rise + 0.25, band.size.y)))
			total_height = maxf(total_height, wall_top + rise)
	host_end()


func _build_roof() -> void:
	if plan.has_court():
		_build_court_roofs()
		return
	tag("roof")
	host("roof", _storeys() - 1)
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var faces: Array[PackedVector3Array] = layout["faces"]
	var span: float = layout["span"]
	var along: float = layout["along"]
	var rise: float = layout["rise"]
	for fi in range(faces.size()):
		var pieces: Array[PackedVector2Array] = [RoofShape.footprint(faces[fi])]
		for dormer in layout["dormers"]:
			if int(dormer["face"]) != fi:
				continue
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(RoofShape.subtract(piece, dormer["opening"]))
			pieces = next
		for piece in pieces:
			_roof_face(xf, RoofShape.lift(piece, faces[fi]), SURF_ROOF, "roof_face_%d" % fi)

	# Close the wall head to the roof UNDERSIDE on every facade. This also
	# fills the small raised eave band on hip roofs, not just gable triangles.
	var h := span * 0.5
	var f := along * 0.5
	for run in [[Vector2(-h, -f), Vector2(h, -f), Vector2(0, 1)],
			[Vector2(-h, f), Vector2(h, f), Vector2(0, -1)],
			[Vector2(-h, -f), Vector2(-h, f), Vector2(1, 0)],
			[Vector2(h, -f), Vector2(h, f), Vector2(-1, 0)]]:
		var profile := RoofShape.wall_profile(faces, run[0], run[1])
		var inward: Vector2 = run[2] * HouseGeometry.wall_thickness(spec) * 0.5
		var shift := Transform3D(Basis(), Vector3(inward.x, 0, inward.y))
		_roof_face(xf * shift, profile, SURF_WALL, "roof_wall", false, HouseGeometry.wall_thickness(spec))

	var ridge_half := along * 0.5 + 0.25
	if spec.roof_type != &"gable":
		var cut := RoofShape.HALF_HIP if spec.roof_type == &"half_hipped" else 0.0
		ridge_half = maxf(ridge_half - (span * 0.5 + 0.35) * (1.0 - cut), 0.0)
	if ridge_half > 0.05:
		component_box("ridge_cap", Vector3(0.22, 0.16, ridge_half * 2.0),
			xf * Transform3D(Basis(), Vector3(0, rise + 0.14, 0)), SURF_ROOF)
	var roof_bounds: AABB = xf * AABB(Vector3(-h - 0.35, -RoofShape.DEPTH * 0.5, -f - 0.25),
		Vector3(span + 0.7, rise + RoofShape.DEPTH * 0.5 + 0.22, along + 0.5))
	_log_mass("roof" if _storeys() == 1 else "roof_%d" % (_storeys() - 1), roof_bounds)
	total_height = maxf(total_height, xf.origin.y + rise + 0.22)
	if spec.roof_type != &"hipped":
		var wall_peak := RoofShape.height_at(faces, Vector2(0, f))
		if spec.timber_frame:
			_gable_frame(xf, span, along, rise, wall_peak)
		var verge_top := rise * RoofShape.HALF_HIP if spec.roof_type == &"half_hipped" else rise
		_build_bargeboards(xf, span, along, rise, verge_top)
	_build_eaves_tails(xf, span, along, rise)
	_build_dormers(xf, layout["dormers"])
	host_end()


func _roof_face(xf: Transform3D, local: PackedVector3Array, surface: int,
		role: String, vertical := true, depth := RoofShape.DEPTH) -> void:
	var world := PackedVector3Array()
	for p in local:
		world.append(xf * p)
	# One row, two readers: roof_components is the roof-shaped view the roof
	# suites already measure, component_log is the whole-exterior view. They
	# are the SAME dictionary, so they cannot drift apart.
	roof_components.append(component_slab(role, world, depth, surface, vertical))


func _build_bargeboards(xf: Transform3D, span: float, along: float, rise: float,
		top: float) -> void:
	if not spec.bargeboards:
		return
	tag("bargeboards")
	var half := (span + 0.7) / 2.0
	var ang := atan2(rise, half)
	var bb_w: float = HouseGeometry.BARGEBOARD_W
	var bb_thick := 0.05
	var kick := 0.10
	# where the board finishes: the apex, or the hip line on a half hip
	var up := Vector2(half * (1.0 - top / rise), top)
	for end_v in [-1.0, 1.0]:
		var z: float = float(end_v) * (along / 2.0 + 0.28)
		for side in [-1.0, 1.0]:
			var a := Vector2(float(side) * half, 0.0)
			var b := Vector2(float(side) * up.x, up.y)
			var dir: Vector2 = (a - b).normalized()
			var foot: Vector2 = a + dir * kick
			var mid: Vector2 = (foot + b) / 2.0
			var t := xf * Transform3D(Basis(Vector3(0, 0, 1), -float(side) * ang),
				Vector3(mid.x, mid.y, z))
			component_box("verge_board", Vector3((foot - b).length(), bb_w, bb_thick),
				t, SURF_TRIM)
		# A finial stands on an apex. A half hip has none, so it gets none.
		if is_equal_approx(top, rise):
			component_box("verge_finial", Vector3(0.12, 0.55, 0.12),
				xf * Transform3D(Basis(), Vector3(0.0, rise + 0.22, z)), SURF_TRIM)
		# Drop pendants at the eaves
		for side2 in [-1.0, 1.0]:
			component_box("verge_pendant", Vector3(0.09, 0.24, 0.09),
				xf * Transform3D(Basis(), Vector3(float(side2) * half, -0.05, z)),
				SURF_TRIM)


func _build_eaves_tails(xf: Transform3D, span: float, along: float, rise: float) -> void:
	tag("eaves")
	var half := span / 2.0
	var tail_spacing := 0.75
	var count := maxi(int(along / tail_spacing), 3)
	for side in [-1.0, 1.0]:
		var ex: float = float(side) * (half + 0.15)
		for i in range(count + 1):
			var ez: float = -along / 2.0 + float(i) * (along / float(count))
			component_box("eave_tail", Vector3(0.12, 0.09, 0.22),
				xf * Transform3D(Basis(), Vector3(ex, -0.05, ez)), SURF_TRIM)


func _build_dormers(xf: Transform3D, dormers: Array) -> void:
	# A dormer is a BUILDING PART, not three loose boxes on the roof: give it
	# its own host so QA can ask what dormer_1 is made of, and notice when one
	# of its pieces goes missing or slides off the slope it sits on.
	for d in dormers:
		host(String(d["id"]), _storeys() - 1)
		var front: float = d["front"]
		var z: float = d["z"]
		var base: float = d["base"] - RoofShape.DEPTH * 0.5
		var eave: float = d["eave"]
		var hw: float = float(d["width"]) * 0.5
		var rh: float = d["roof_half"]
		var peak: float = eave + 0.45
		var side_top := eave + 0.45 * (1.0 - hw / rh) - RoofShape.DEPTH * 0.5
		var role: String = d["id"]
		# Rooflets end on the actual valley line, not in a rectangular box
		# behind the host slope. Cheeks taper to zero at that same intersection.
		for side in [-1.0, 1.0]:
			_roof_face(xf, PackedVector3Array([
				Vector3(front - 0.12, eave, z + side * rh),
				Vector3(d["side_x"], eave, z + side * rh),
				Vector3(d["peak_x"], peak, z),
				Vector3(front - 0.12, peak, z)]), SURF_ROOF, role + "_roof")
			_roof_face(xf, PackedVector3Array([
				Vector3(front, base, z + side * hw),
				Vector3(front, side_top, z + side * hw),
				Vector3(d["cheek_x"], side_top, z + side * hw)]),
				SURF_WALL, role + "_cheek", false, 0.08)
		var head := eave - RoofShape.DEPTH * 0.5
		_roof_face(xf, PackedVector3Array([
			Vector3(front, head, z - hw), Vector3(front, head, z + hw),
			Vector3(front, side_top, z + hw),
			Vector3(front, peak - RoofShape.DEPTH * 0.5, z),
			Vector3(front, side_top, z - hw)]), SURF_WALL, role + "_gable", false, 0.10)
		var win_bottom := base + 0.20
		var win_top := head - 0.13
		var win_w := float(d["width"]) * 0.65
		for side in [-1.0, 1.0]:
			component_box("dormer_jamb", Vector3(0.10, head - base, hw - win_w * 0.5),
				xf * Transform3D(Basis(), Vector3(front, (head + base) * 0.5,
					z + side * (hw + win_w * 0.5) * 0.5)), SURF_TRIM)
		for band in [[base, win_bottom], [win_top, head]]:
			component_box("dormer_panel", Vector3(0.10, band[1] - band[0], win_w),
				xf * Transform3D(Basis(), Vector3(front, (band[0] + band[1]) * 0.5, z)), SURF_TRIM)
		component_box("dormer_glazing", Vector3(0.04, win_top - win_bottom, win_w),
			xf * Transform3D(Basis(), Vector3(front - 0.04, (win_top + win_bottom) * 0.5, z)), SURF_ROOF)
		component_box("dormer_mullion", Vector3(0.05, win_top - win_bottom, 0.055),
			xf * Transform3D(Basis(), Vector3(front - 0.065, (win_top + win_bottom) * 0.5, z)), SURF_TRIM)
		host("roof", _storeys() - 1)


## The frame in the gable -- and every member of it stays UNDER THE RAFTERS.
##
## Each strut used to be stated as a run, a lift and a tilt that all had to
## agree with a roof pitch stated somewhere else, and they did not. A
## queen-post strut ran up-and-OUT from its post while the rafter it braces
## runs down-and-out, so the strut left the roof and finished three and a half
## metres out in the open air, reading as a stray roof plane crossing the real
## ones. Members are stated by their two ENDS now, and the outer end is put ON
## the rafter line rather than guessed at, so a member cannot escape the roof
## whatever the pitch turns out to be.
func _gable_frame(xf: Transform3D, span: float, along: float, rise: float,
		top: float) -> void:
	var half: float = span / 2.0
	# The slabs overhang the wall, so the rafter over the wall face is a little
	# higher than the wall head: this is the roof's half span, not the wall's.
	var roof_half: float = (span + 0.7) / 2.0
	_frame_top = top
	for end_v in [-1.0, 1.0]:
		var z: float = end_v * (along / 2.0 + HouseGeometry.BEAM_D / 2.0 - 0.01)
		# Tie beam across the base of the gable
		component_box("gable_tie", Vector3(span, HouseGeometry.PLATE_H, HouseGeometry.BEAM_D),
			xf * Transform3D(Basis(), Vector3(0.0, HouseGeometry.PLATE_H / 2.0, z)),
			SURF_TRIM)

		match spec.gable_truss:
			&"queen_post":
				var qx: float = half * 0.42
				var collar_h: float = minf(rise * 0.52, _under_rafter(qx, roof_half, rise))
				for qs in [-1.0, 1.0]:
					_member(xf, Vector2(qs * qx, 0.0), Vector2(qs * qx, collar_h),
						z, HouseGeometry.BEAM_W)
				_member(xf, Vector2(-qx, collar_h), Vector2(qx, collar_h), z,
					HouseGeometry.BEAM_W * 0.9)
				# and the strut down from the collar onto the rafter, which is
				# the direction a rafter actually goes
				for qs2 in [-1.0, 1.0]:
					var foot: float = qx + half * 0.45
					_member(xf, Vector2(qs2 * qx, collar_h),
						Vector2(qs2 * foot, _under_rafter(foot, roof_half, rise)),
						z, HouseGeometry.BEAM_W * 0.8)
			&"collar_strut":
				var ch: float = minf(rise * 0.45,
					_under_rafter(span * 0.275, roof_half, rise))
				_member(xf, Vector2(-span * 0.275, ch), Vector2(span * 0.275, ch), z,
					HouseGeometry.BEAM_W * 0.9)
				_member(xf, Vector2(0.0, ch),
					Vector2(0.0, _under_rafter(0.0, roof_half, rise)), z,
					HouseGeometry.BEAM_W)
				for side in [-1.0, 1.0]:
					var run: float = half * 0.35
					_member(xf, Vector2(0.0, 0.0),
						Vector2(side * run,
							minf(ch * 0.9, _under_rafter(run, roof_half, rise))),
						z, HouseGeometry.BEAM_W * 0.8)
			_: # &"king_post"
				_member(xf, Vector2(0.0, 0.0),
					Vector2(0.0, _under_rafter(0.0, roof_half, rise)), z,
					HouseGeometry.BEAM_W)
				for side2 in [-1.0, 1.0]:
					var run2: float = half * 0.55
					_member(xf, Vector2(0.0, 0.0),
						Vector2(side2 * run2, _under_rafter(run2, roof_half, rise)),
						z, HouseGeometry.BEAM_W * 0.85)


## The underside of the rafter over `x`, in the gable's own space, with the
## member's own depth already taken off -- a beam whose centre line lands here
## does not poke through the slates.
func _under_rafter(x: float, roof_half: float, rise: float) -> float:
	return clampf(rise * (1.0 - absf(x) / roof_half) - RoofShape.DEPTH * 0.5 - HouseGeometry.BEAM_W * 0.5 - 0.02,
		0.0, maxf(_frame_top - RoofShape.DEPTH * 0.5 - HouseGeometry.BEAM_W * 0.5 - 0.02, 0.0))


## Where the gable the frame stands in stops, set by _gable_frame before it
## places anything. A truss inside a half-hipped gable may not climb past the
## hip any more than the wall may.
var _frame_top := INF


## One member of a gable frame, between two points in the gable's own plane.
##
## Stating a beam by its ends rather than by a run, a lift and a tilt is the
## whole point: the three could disagree, and did.
func _member(xf: Transform3D, a: Vector2, b: Vector2, z: float,
		width: float) -> void:
	var d: Vector2 = b - a
	var run: float = d.length()
	if run < 0.05:
		return
	var mid: Vector2 = (a + b) / 2.0
	component_box("gable_member", Vector3(run, width, HouseGeometry.BEAM_D),
		xf * Transform3D(Basis(Vector3(0, 0, 1), atan2(d.y, d.x)),
			Vector3(mid.x, mid.y, z)), SURF_TRIM)


func _build_porch() -> void:
	if not spec.porch:
		return
	var d: int = plan.entrance()
	if d < 0:
		return
	tag("porch")
	# A porch has a roof, and it is NOT the house's roof. Giving it its own
	# host is what keeps the vertical-shell check counting one main roof.
	host("porch", 0)
	var door: Dictionary = plan.doors[d]
	var depth: float = HouseGeometry.porch_depth(spec)
	var w: float = float(door["width"]) + 1.1
	var c: Vector2 = door["pos"] + door["normal"] * (depth / 2.0)
	var head: float = HouseGeometry.DOOR_H + 0.35
	var step := AABB(Vector3(c.x - w / 2.0, 0.0, c.y - depth / 2.0 - 0.1),
		Vector3(w, HouseGeometry.FLOOR_T, depth + 0.2 + HouseGeometry.wall_thickness(spec)))
	box(step.size, step.position + step.size / 2.0, SURF_FLOOR)
	_log_mass("porch_step", step)
	for side in [-1.0, 1.0]:
		var p: Vector2 = c + Vector2(side * (w / 2.0 - 0.1), 0.0) \
			+ door["normal"] * (depth / 2.0 - 0.12)
		box(Vector3(0.14, head, 0.14), Vector3(p.x, head / 2.0, p.y), SURF_TRIM)
		_log_mass("porch_post_%s" % ("left" if side < 0.0 else "right"),
			AABB(Vector3(p.x - 0.07, 0.0, p.y - 0.07), Vector3(0.14, head, 0.14)))
	var xf := Transform3D(Basis(), Vector3(c.x, head, c.y))
	var porch_along: float = depth + 0.2
	component_note("porch_roof", "ridge", SURF_ROOF, {"xf": xf, "span": w,
		"along": porch_along, "rise": 0.42,
		"aabb": xf * AABB(Vector3(-w * 0.5, 0.0, -porch_along * 0.5),
			Vector3(w, 0.42, porch_along))})
	_kit.ridge_roof(xf, w, porch_along, 0.42, SURF_ROOF)
	host_end()


## How far a flue finishes above the ridge it comes out of.
const CHIMNEY_CLEAR := 0.6


func _build_chimney() -> void:
	if not spec.chimney:
		return
	tag("chimney")
	var s: float = HouseGeometry.chimney_size(spec)
	var c := HouseGeometry.chimney_center(plan)

	var wall_top: float = spec.height * _storeys()
	# Above the RIDGE, not above an assumed two-metre roof. The old
	# minf(roof_rise, 2.0) sized every stack as though no roof rose higher than
	# that, so a longhall with a 5.4 m rise got a flue that stopped two and a
	# half metres short of its own ridge -- a chimney you could see the roof
	# over, which both looks wrong and would smoke back down itself.
	var top: float = wall_top + HouseGeometry.roof_rise(spec) + CHIMNEY_CLEAR

	# Stepped chimney stack
	var base_h: float = minf(top * 0.45, 2.5)
	if spec.chimney_style == &"stepped":
		var base_s: float = s + HouseGeometry.CHIMNEY_BASE_EXTRA
		box(Vector3(base_s, base_h, base_s), Vector3(c.x, base_h / 2.0, c.y), SURF_FLOOR)
		var sh_h := 0.25
		box(Vector3(base_s - 0.08, sh_h, base_s - 0.08), Vector3(c.x, base_h + sh_h / 2.0, c.y), SURF_FLOOR)
		var flue_h: float = top - (base_h + sh_h)
		if flue_h > 0.05:
			box(Vector3(s, flue_h, s), Vector3(c.x, base_h + sh_h + flue_h / 2.0, c.y), SURF_FLOOR)
	else:
		box(Vector3(s, top, s), Vector3(c.x, top / 2.0, c.y), SURF_FLOOR)

	_log_mass("chimney", AABB(Vector3(c.x - s / 2.0, 0.0, c.y - s / 2.0),
		Vector3(s, top, s)))
	box(Vector3(s + 0.22, 0.18, s + 0.22), Vector3(c.x, top + 0.09, c.y), SURF_TRIM)
	total_height = maxf(total_height, top + 0.18)

	# Flue pots at the top
	var pot_r: float = HouseGeometry.CHIMNEY_POT_R
	var pot_h: float = HouseGeometry.CHIMNEY_POT_H
	var pots: int = clampi(spec.chimney_pots, 1, 2)
	if pots == 1:
		_kit.drum(Vector3(c.x, top + 0.18, c.y), pot_r, pot_r, pot_h, SURF_FLOOR, 10)
		_kit.drum(Vector3(c.x, top + 0.18 + pot_h - 0.06, c.y), pot_r * 1.15, pot_r * 1.15, 0.06, SURF_TRIM, 10)
	else:
		var off: float = s * 0.22
		for pside in [-1.0, 1.0]:
			var px: float = c.x + (off * pside if plan.hearth_wall() <= 1 else 0.0)
			var pz: float = c.y + (off * pside if plan.hearth_wall() > 1 else 0.0)
			_kit.drum(Vector3(px, top + 0.18, pz), pot_r, pot_r, pot_h, SURF_FLOOR, 10)
			_kit.drum(Vector3(px, top + 0.18 + pot_h - 0.06, pz), pot_r * 1.15, pot_r * 1.15, 0.06, SURF_TRIM, 10)
	total_height = maxf(total_height, top + 0.18 + pot_h)


