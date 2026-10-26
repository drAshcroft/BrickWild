class_name HouseMinka
extends RefCounted
## HS-MINKA: what makes the `asian` style row a Japanese minka beyond its roof.
##
##   * a RAISED FLOOR on a stone plinth. The floor never moves (local y = 0 is
##     its underside, as for HouseSlope and HousePiles); the ground is
##     `HouseGeometry.floor_raise` BELOW it. The stone stylobate runs from the
##     ground up to the floor under every exterior wall, the entry doors have
##     stone steps down to the ground, and HouseAssembler lifts the house by
##     the same amount so the ground lands at the root's y = 0.
##   * the ENGAWA: a floor-level timber veranda along one LONG side, carried on
##     posts under the deep eave of the roof (no separate rooflet).
##   * SLIDING LATTICE SCREENS (shoji) in the engawa-side wall, in place of its
##     windows, and the MAIN ROOM (the parlour, else the hall) opening through
##     a wide sliding screen onto the engawa and the garden beyond.
##
## Planning (`plan_engawa`) writes `plan.engawa` and `plan.entry_steps`; the
## builder emits from them (`emit`, `emit_screen`). Nothing here draws a random
## number: the side is read off the plan.

const SURF_WALL := HouseBuilder.SURF_WALL
const SURF_TRIM := HouseBuilder.SURF_TRIM
const SURF_FLOOR := HouseBuilder.SURF_FLOOR
## Vertex colour that selects the large masonry cells of the floor shader.
const STONE := Color(1, 0, 1)

const SCREEN_MARGIN := 0.4
const SCREEN_PIER := 0.3
const DOOR_MIN := 1.5
const DOOR_MAX := 2.4
const WINDOW_MIN := 0.9
const WINDOW_MAX := 3.0
const POST_W := 0.14
const POST_SPACING := 1.9
const BEAM_H := 0.18
const STEP_RISER := 0.17
const STEP_TREAD := 0.3
const STEP_W := 1.3
const KUMIKO := 0.15     # centre spacing of the lattice bars
const BAR := 0.022


static func applies(spec: Object) -> bool:
	return spec != null and bool(spec.get("engawa"))


## The planner's step: choose the engawa side and fit the screens. Called once,
## after the windows are placed and before the hearth and the furniture.
static func plan_engawa(p: HousePlan, spec: HouseSpec) -> void:
	p.engawa = {}
	p.entry_steps = []
	if not applies(spec) or p.world_family != &"" or p.rooms.is_empty():
		return
	var inner := HouseGeometry.interior_rect(spec)
	var long_x := spec.length >= spec.width
	var normals: Array[Vector2] = []
	normals.append(Vector2(1, 0) if long_x else Vector2(0, 1))
	normals.append(Vector2(-1, 0) if long_x else Vector2(0, -1))
	var entrance := p.entrance()
	var door_pos := Vector2(p.doors[entrance]["pos"]) if entrance >= 0 else Vector2.ZERO
	var best := {}
	var best_score := -INF
	var front_n := Vector2(p.doors[entrance]["normal"]) if entrance >= 0 else Vector2.ZERO
	for n in normals:
		# never on the wall the way in is on: the engawa would be the approach
		if n.dot(front_n) > 0.9:
			continue
		var line := _line(inner, n)
		var touching := _touching(p, n, inner)
		var main := _main_room(p, touching, n, line)
		if main < 0:
			continue
		var score := _rank(p, main) * 10.0
		# the side away from the front door, when the rooms are otherwise equal
		score += absf((door_pos * n.abs()).length() - absf(line)) * 0.01
		if score > best_score + 1e-6:
			best_score = score
			best = {"normal": n, "line": line, "main": main, "rooms": touching}
	if best.is_empty():
		return
	var n: Vector2 = best["normal"]
	var line: float = best["line"]
	var main: int = best["main"]
	var screens := 0
	for room in best["rooms"]:
		var kind: StringName = p.kind_of(room)
		if kind == &"kitchen" and room != main:
			continue
		if _has_exterior_door(p, room, n):
			continue
		var span := _span(p, room, n)
		var u: float = span.y - span.x - SCREEN_MARGIN * 2.0
		_drop_windows(p, room, n)
		var added := _fit(p, spec, room, n, line, span, u, room == main)
		screens += added
		if room == main:
			HousePlanOpenings.glaze_remaining(p, spec, [room] as Array[int])
	var site := HouseGeometry.site_rect(spec)
	var depth := spec.engawa_depth
	var deck := Rect2()
	if absf(n.x) > 0.5:
		deck = Rect2(Vector2(site.end.x if n.x > 0.0 else site.position.x - depth, site.position.y),
			Vector2(depth, site.size.y))
	else:
		deck = Rect2(Vector2(site.position.x, site.end.y if n.y > 0.0 else site.position.y - depth),
			Vector2(site.size.x, depth))
	var rise := HouseGeometry.floor_raise(spec)
	var count := maxi(1, int(ceil((rise + HouseGeometry.FLOOR_T) / STEP_RISER)))
	# The way down to the garden is a flight off the END of the deck that is
	# farther from the front door, running along the wall: a flight out from
	# the middle would square the whole veranda up to 2.4 m deep in every bound.
	var mid := deck.get_center()
	var tan_v := Vector2(n.y, -n.x)
	var along := deck.size.y if absf(n.x) > 0.5 else deck.size.x
	var end_dir := tan_v
	if entrance >= 0 and (door_pos - mid).dot(tan_v) > 0.0:
		end_dir = -tan_v
	var run := float(count - 1) * STEP_TREAD
	var end_edge := mid + end_dir * (along * 0.5)
	var step_rect := _rect_out(end_edge, end_dir, n.abs(), depth, run)
	p.engawa = {"normal": n, "line": line, "main_room": main, "rooms": best["rooms"],
		"rect": deck, "depth": depth, "step_rect": step_rect, "step_count": count,
		"step_base": end_edge, "step_dir": end_dir,
		"screens": screens}
	_plan_entry_steps(p, spec)


## The entry doors' stone steps down to the ground.
static func _plan_entry_steps(p: HousePlan, spec: HouseSpec) -> void:
	var rise := HouseGeometry.floor_raise(spec)
	if rise <= 0.0:
		return
	var count := maxi(1, int(ceil((rise + HouseGeometry.FLOOR_T) / STEP_RISER)))
	var wall_t := HouseGeometry.wall_thickness(spec)
	for i in range(p.doors.size()):
		var d: Dictionary = p.doors[i]
		if not bool(d.get("exterior", false)) or bool(d.get("screen", false)) \
				or bool(d.get("secret", false)) or HousePlan.record_storey(d) != 0:
			continue
		var n := Vector2(d["normal"]).normalized()
		var tan := Vector2(n.y, -n.x).abs()
		var base := Vector2(d["pos"]) + n * wall_t
		var width := float(d["width"]) + 0.4
		p.entry_steps.append({"door": i, "count": count, "normal": n, "width": width,
			"base": base, "rect": _rect_out(base, n, tan, width, float(count - 1) * STEP_TREAD)})


static func _rect_out(base: Vector2, n: Vector2, tan: Vector2, width: float, run: float) -> Rect2:
	var c := base + n * (run * 0.5)
	var size := tan * width + n.abs() * run
	return Rect2(c - size * 0.5, size)


static func _line(inner: Rect2, n: Vector2) -> float:
	if absf(n.x) > 0.5:
		return inner.end.x if n.x > 0.0 else inner.position.x
	return inner.end.y if n.y > 0.0 else inner.position.y


static func _span(p: HousePlan, room: int, n: Vector2) -> Vector2:
	var r: Rect2 = p.rooms[room]["rect"]
	return Vector2(r.position.y, r.end.y) if absf(n.x) > 0.5 else Vector2(r.position.x, r.end.x)


static func _touching(p: HousePlan, n: Vector2, inner: Rect2) -> Array[int]:
	var out: Array[int] = []
	var line := _line(inner, n)
	for i in p.rooms_on_storey(0):
		var r: Rect2 = p.rooms[i]["rect"]
		var edge := (r.end.x if n.x > 0.0 else r.position.x) if absf(n.x) > 0.5 \
			else (r.end.y if n.y > 0.0 else r.position.y)
		if absf(edge - line) < 0.02:
			out.append(i)
	return out


static func _rank(p: HousePlan, room: int) -> float:
	match p.kind_of(room):
		&"parlour":
			return 4.0
		&"hall":
			return 3.0
		&"bedroom":
			return 2.0
		&"study", &"dining":
			return 2.5
	return 0.0


static func _main_room(p: HousePlan, touching: Array[int], n: Vector2, _line_v: float) -> int:
	var best := -1
	var best_score := 0.0
	for room in touching:
		if _has_exterior_door(p, room, n):
			continue
		var span := _span(p, room, n)
		var score := _rank(p, room) + (span.y - span.x) * 0.01
		if _rank(p, room) > 0.0 and span.y - span.x - SCREEN_MARGIN * 2.0 >= DOOR_MIN \
				and score > best_score:
			best = room
			best_score = score
	return best


static func _has_exterior_door(p: HousePlan, room: int, n: Vector2) -> bool:
	for d in p.doors:
		if int(d["a"]) == room and bool(d.get("exterior", false)) \
				and absf(Vector2(d["normal"]).dot(n)) > 0.5 and not bool(d.get("screen", false)):
			return true
	return false


static func _drop_windows(p: HousePlan, room: int, n: Vector2) -> void:
	for i in range(p.windows.size() - 1, -1, -1):
		var w: Dictionary = p.windows[i]
		if int(w["room"]) == room and Vector2(w["normal"]).dot(n) > 0.5:
			p.windows.remove_at(i)


static func _at(line: float, t: float, n: Vector2) -> Vector2:
	return Vector2(line, t) if absf(n.x) > 0.5 else Vector2(t, line)


## Fit the screens of one room on the wall. The main room gets a wide sliding
## door and, when the wall has the length, a fixed-width screen beside it; any
## other room gets one screen. Returns how many openings were added.
static func _fit(p: HousePlan, spec: HouseSpec, room: int, n: Vector2, line: float,
		span: Vector2, u: float, is_main: bool) -> int:
	var head := minf(spec.height - 0.1, HouseGeometry.FLOOR_T + 2.1)
	var t0 := span.x + SCREEN_MARGIN
	var added := 0
	if is_main:
		var door_w := clampf(u * 0.6, DOOR_MIN, DOOR_MAX)
		var rest := u - door_w - SCREEN_PIER
		var has_window := rest >= WINDOW_MIN
		if not has_window:
			door_w = clampf(u, DOOR_MIN, DOOR_MAX)
		var flip := posmod(spec.seed, 2) == 1
		var door_t := 0.0
		var win_t := 0.0
		var win_w := minf(rest, WINDOW_MAX)
		# on the wall facing the front door the screen door must not be in line with it
		var front := p.entrance()
		var opposite := front >= 0 and Vector2(p.doors[front]["normal"]).dot(n) < -0.9
		var best_sep := -INF
		for attempt in range(2):
			var f := flip if attempt == 0 else not flip
			var dt := t0 + u * 0.5
			var wt := 0.0
			if has_window and not f:
				dt = t0 + door_w * 0.5
				wt = t0 + door_w + SCREEN_PIER + win_w * 0.5
			elif has_window:
				dt = t0 + u - door_w * 0.5
				wt = t0 + win_w * 0.5
			var sep := 99.0
			if opposite:
				var ft: float = Vector2(p.doors[front]["pos"]).x if absf(n.y) > 0.5 else Vector2(p.doors[front]["pos"]).y
				sep = absf(dt - ft) - (door_w + float(p.doors[front]["width"])) * 0.5
			if sep > best_sep:
				best_sep = sep
				door_t = dt
				win_t = wt
		if opposite and best_sep < 0.1 and not has_window:
			# a narrower door at whichever end is farther from the front door
			door_w = DOOR_MIN
			var ft2: float = Vector2(p.doors[front]["pos"]).x if absf(n.y) > 0.5 else Vector2(p.doors[front]["pos"]).y
			var lo_t := t0 + door_w * 0.5
			var hi_t := t0 + u - door_w * 0.5
			door_t = lo_t if absf(lo_t - ft2) >= absf(hi_t - ft2) else hi_t
		p.doors.append({"a": room, "b": -1, "pos": _at(line, door_t, n), "normal": n,
			"width": door_w, "exterior": true, "front": false, "storey": 0,
			"head": head, "screen": true, "sliding": true})
		added += 1
		if has_window:
			p.windows.append(_screen_window(room, _at(line, win_t, n), n, win_w, head))
			added += 1
	else:
		if u < WINDOW_MIN:
			return 0
		# a long wall is several screens between narrow piers, not one great pane
		var count := maxi(1, int(ceil(u / WINDOW_MAX)))
		var w := (u - SCREEN_PIER * float(count - 1)) / float(count)
		for k in range(count):
			var tc := t0 + w * 0.5 + (w + SCREEN_PIER) * float(k)
			p.windows.append(_screen_window(room, _at(line, tc, n), n, w, head))
			added += 1
	return added


static func _screen_window(room: int, pos: Vector2, n: Vector2, w: float, head: float) -> Dictionary:
	return {"room": room, "pos": pos, "normal": n, "width": w, "sill": 0.0,
		"head": head, "storey": 0, "balcony": true, "screen": true}


# ------------------------------------------------------------------ geometry

## The engawa's footprint in plan (the deck and its steps), or an empty rect.
static func engawa_rect(plan: HousePlan) -> Rect2:
	if plan.engawa.is_empty():
		return Rect2()
	return Rect2(plan.engawa["rect"]).merge(Rect2(plan.engawa["step_rect"]))


## The engawa deck alone, or an empty rect.
static func deck_rect(plan: HousePlan) -> Rect2:
	return Rect2(plan.engawa["rect"]) if not plan.engawa.is_empty() else Rect2()


## The stone steps from the engawa down to the garden, or an empty rect.
static func garden_steps_rect(plan: HousePlan) -> Rect2:
	return Rect2(plan.engawa["step_rect"]) if not plan.engawa.is_empty() else Rect2()


## Everything the stone steps of the entry doors cover, merged.
static func steps_rect(plan: HousePlan) -> Rect2:
	var r := Rect2()
	for s in plan.entry_steps:
		var sr := Rect2(s["rect"])
		r = sr if not r.has_area() else r.merge(sr)
	return r


## Emit everything under and beside the floor through `b`: the stone
## stylobate, the entry steps, the engawa. A plan with none of it emits none.
static func emit(b: HouseBuilder) -> void:
	var plan: HousePlan = b.plan
	var spec: HouseSpec = plan.spec
	var rise := HouseGeometry.floor_raise(spec)
	if rise > 0.0:
		_emit_stylobate(b, plan, spec, rise)
		_emit_steps(b, plan, spec, rise)
	if not plan.engawa.is_empty():
		_emit_engawa(b, plan, spec, rise)


static func _emit_stylobate(b: HouseBuilder, plan: HousePlan, spec: HouseSpec, rise: float) -> void:
	b.tag("stylobate")
	b.host("stylobate", 0)
	b._kit.surface(SURF_FLOOR).set_color(STONE)
	for run in HouseGeometry.shell_runs(plan, 0):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec))) \
			+ HouseGeometry.PLINTH_EXTRA * 2.0
		var seg := to - from
		var len := seg.length()
		if len < 0.01:
			continue
		var dir := seg / len
		var mid := (from + to) * 0.5
		var xf := Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)),
			Vector3(mid.x, -rise * 0.5 + 0.0, mid.y))
		b.component_box("stylobate", Vector3(len + thick, rise, thick), xf, SURF_FLOOR)
		# the coping: a flat stone cap a hand's breadth proud of the course
		var cap := Transform3D(xf.basis, Vector3(mid.x, -0.04, mid.y))
		b.component_box("stylobate_cap", Vector3(len + thick + 0.1, 0.08, thick + 0.1), cap, SURF_FLOOR)
	b._kit.surface(SURF_FLOOR).set_color(Color.WHITE)
	b.host_end()


static func _emit_steps(b: HouseBuilder, plan: HousePlan, spec: HouseSpec, rise: float) -> void:
	if plan.entry_steps.is_empty():
		return
	b.tag("entry_steps")
	b._kit.surface(SURF_FLOOR).set_color(STONE)
	for s in plan.entry_steps:
		b.host("entry_%d" % int(s["door"]), 0)
		_flight(b, Vector2(s["base"]), Vector2(s["normal"]), float(s["width"]), int(s["count"]), rise)
		b.host_end()
	b._kit.surface(SURF_FLOOR).set_color(Color.WHITE)


## A stone flight: `count` risers from the threshold (the floor's top) to the
## ground, of which the last is the ground itself. Each tread is a solid block
## down to the ground, so none floats.
static func _flight(b: HouseBuilder, base: Vector2, n: Vector2, width: float, count: int,
		rise: float) -> void:
	var total := rise + HouseGeometry.FLOOR_T
	var riser := total / float(count)
	var yaw := atan2(n.x, n.y)
	for j in range(count - 1):
		var top := HouseGeometry.FLOOR_T - float(j + 1) * riser
		var c := base + n * (STEP_TREAD * (float(j) + 0.5))
		var h := top + rise
		b.component_box("entry_step", Vector3(width, h, STEP_TREAD),
			Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, top - h * 0.5, c.y)), SURF_FLOOR)


static func _emit_engawa(b: HouseBuilder, plan: HousePlan, spec: HouseSpec, rise: float) -> void:
	var e := plan.engawa
	var n: Vector2 = e["normal"]
	var deck: Rect2 = e["rect"]
	b.tag("engawa")
	b.host("engawa", 0)
	var t := HouseGeometry.FLOOR_T
	var yaw := atan2(n.x, n.y)
	var basis := Basis(Vector3.UP, yaw)
	var c := deck.get_center()
	# local frame: +Z out of the wall, +X along it
	var along := deck.size.y if absf(n.x) > 0.5 else deck.size.x
	var depth := float(e["depth"])
	b.component_box("engawa_deck", Vector3(along, t, depth),
		Transform3D(basis, Vector3(c.x, t * 0.5, c.y)), SURF_FLOOR)
	# the front edge beam and the posts' stone footings
	var edge := c + n * (depth * 0.5)
	b.component_box("engawa_edge", Vector3(along, 0.1, 0.08),
		Transform3D(basis, Vector3(edge.x, 0.02, edge.y)), SURF_TRIM)
	var posts := maxi(2, int(ceil(along / POST_SPACING)) + 1)
	var post_h := spec.height - BEAM_H - 0.04 - t
	var tan := Vector2(n.y, -n.x)
	for i in range(posts):
		var s := -along * 0.5 + 0.12 + (along - 0.24) * float(i) / float(posts - 1)
		var at := edge - n * 0.12 + tan * s
		b.component_box("engawa_post", Vector3(POST_W, post_h, POST_W),
			Transform3D(basis, Vector3(at.x, t + post_h * 0.5, at.y)), SURF_TRIM)
		if rise > 0.0:
			b._kit.surface(SURF_FLOOR).set_color(STONE)
			b.component_box("engawa_footing", Vector3(0.3, rise, 0.3),
				Transform3D(basis, Vector3(at.x, -rise * 0.5, at.y)), SURF_FLOOR)
			b._kit.surface(SURF_FLOOR).set_color(Color.WHITE)
	var beam_at := edge - n * 0.12
	b.component_box("engawa_beam", Vector3(along, BEAM_H, 0.16),
		Transform3D(basis, Vector3(beam_at.x, t + post_h + BEAM_H * 0.5, beam_at.y)), SURF_TRIM)
	# the stepping stone down to the garden, in the middle of the edge
	if rise > 0.0:
		b._kit.surface(SURF_FLOOR).set_color(STONE)
		_flight(b, Vector2(e["step_base"]), Vector2(e["step_dir"]), depth, int(e["step_count"]), rise)
		b._kit.surface(SURF_FLOOR).set_color(Color.WHITE)
	b.host_end()


## One sliding lattice screen filling an opening of the wall: a header track
## (kamoi) and sill track, then panels each a frame, a lattice of fine bars and
## a pale paper face. Panels slide on two tracks; a sliding DOOR is drawn with
## its panels pulled apart to the two ends, leaving the middle open.
static func emit_screen(b: HouseBuilder, from: Vector2, dir: Vector2, yaw: float,
		t: float, w: float, bottom: float, top: float, thick: float, normal: Vector2,
		y_offset: float, open: bool) -> void:
	var mid := from + dir * t
	var h := top - bottom
	var cy := y_offset + (bottom + top) * 0.5
	# a frame with +Z out of the wall (the normal), +X along it, whichever way
	# the run happens to be drawn
	var z_axis := Vector3(normal.x, 0.0, normal.y)
	var frame := Basis(Vector3(normal.y, 0.0, -normal.x), Vector3.UP, z_axis)
	var rail := Transform3D(frame, Vector3(mid.x, y_offset + top - 0.03, mid.y))
	b.component_box("screen_track", Vector3(w, 0.06, thick * 0.55), rail, SURF_TRIM)
	var sill := Transform3D(frame, Vector3(mid.x, y_offset + bottom + 0.015, mid.y))
	b.component_box("screen_track", Vector3(w, 0.03, thick * 0.55), sill, SURF_TRIM)
	var panels := maxi(2, int(round(w / 0.85)))
	var pw := w / float(panels) + 0.04
	var inner_h := h - 0.12
	var half := panels / 2
	for i in range(panels):
		var cx := -w * 0.5 + (float(i) + 0.5) * w / float(panels)
		if open:
			# half the panels stacked at each end, the middle open
			var k := i if i < half else i - half
			var stack := (float(k) + 0.5) * pw * 0.5
			cx = -w * 0.5 + stack if i < half else w * 0.5 - stack
		var lane := (-1.0 if i % 2 == 0 else 1.0) * 0.045
		var pc := from + dir * (t + cx) + normal * lane
		# local +X of this panel runs along `dir` or against it: the panels are
		# symmetric, so only the side faces (+Z / -Z) matter, and those are `frame`'s
		var base := Transform3D(frame, Vector3(pc.x, cy, pc.y))
		# the frame
		for sx in [-1.0, 1.0]:
			b.component_box("screen_stile", Vector3(0.04, inner_h, 0.05),
				base * Transform3D(Basis(), Vector3(float(sx) * (pw * 0.5 - 0.02), 0.0, 0.0)), SURF_TRIM)
		for sy in [-1.0, 1.0]:
			b.component_box("screen_rail", Vector3(pw, 0.05, 0.05),
				base * Transform3D(Basis(), Vector3(0.0, float(sy) * (inner_h * 0.5 - 0.025), 0.0)), SURF_TRIM)
		# the paper, pale, in the middle of the lattice
		b.component_box("screen_paper", Vector3(pw - 0.08, inner_h - 0.1, 0.008), base, SURF_WALL)
		# the lattice, on both faces of the paper: fine verticals and a grid of horizontals
		var bars := int(floor((pw - 0.08) / KUMIKO))
		var rows := int(floor((inner_h - 0.1) / (KUMIKO * 2.6)))
		for face in [-1.0, 1.0]:
			var zf := float(face) * 0.016
			for k2 in range(1, bars):
				var x := -(pw - 0.08) * 0.5 + (pw - 0.08) * float(k2) / float(bars)
				b.component_box("screen_kumiko", Vector3(BAR, inner_h - 0.1, 0.02),
					base * Transform3D(Basis(), Vector3(x, 0.0, zf)), SURF_TRIM)
			for k3 in range(1, rows):
				var y := -(inner_h - 0.1) * 0.5 + (inner_h - 0.1) * float(k3) / float(rows)
				b.component_box("screen_kumiko", Vector3(pw - 0.08, BAR, 0.02),
					base * Transform3D(Basis(), Vector3(0.0, y, zf)), SURF_TRIM)
