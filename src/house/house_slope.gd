class_name HouseSlope
extends RefCounted
## A house or shop on falling ground (VTER-HOUSE-SLOPE). The ground itself is
## `GroundFall`'s; this is what a plan-built dwelling does about it.
##
## The floor never moves. y = 0 is the ground at the uphill edge, which is
## where every flat house already stands, so a sloping house is the flat house
## -- the same plan, shell and furniture, vertex for vertex above the ground --
## plus three things under it, in three bands of fall:
##
##   1  up to PLINTH_MAX (1.2 m)  a FOUNDATION: the plinth carried down to the
##      ground under every exterior wall run, in 0.30 m courses, each course
##      clipped to the ground so its lowest edge sits on it. Where a door is
##      left more than a riser above the ground, it gets the entry steps below.
##   2  up to one storey          the same foundation, now a tall one: a raised
##      ground floor. Every exterior door above the ground gets ENTRY STEPS --
##      a landing at the threshold (or the porch or veranda deck, carried down
##      to the ground), then a straight flight of 0.17 m risers on 0.30 m
##      treads: straight out, or along the wall either way, whichever reaches
##      the ground in fewest steps without crossing the house, its chimney or
##      another door's flight.
##   3  up to two storeys         a BANK STOREY. The plan digs the house's
##      cellar (INT-016, the same lower level a cellar house has: the ground
##      partition again, every room a store, a stair down from the hall) and
##      gives it its OWN exterior door on the downhill wall, with its own
##      steps. Uphill it is dug into the bank; downhill it stands clear, on a
##      foundation of its own down to the ground. The main door stays where
##      the plan put it, at the floor: on the uphill side it opens at the
##      ground; on the downhill side it gets a flight like band 2.
##
## Why a cellar and not a new "undercroft" level: the cellar already is a real
## lower storey every part of the pipeline knows -- the planner, the furnisher,
## the nav check, the walk export, the blueprint sheet -- so the bank storey is
## a room people can walk into, not a void behind a painted door. The only
## new plan fact is that one exterior door.

const SURF_FLOOR := 3


static func ground(spec: Object) -> GroundFall:
	return GroundFall.of_spec(spec)


## 0 flat, 1 stepped plinth, 2 raised floor, 3 bank storey.
static func band(spec: HouseSpec) -> int:
	var f: float = spec.ground_fall
	if f <= GroundFall.FLAT:
		return 0
	if f <= GroundFall.PLINTH_MAX:
		return 1
	if f <= spec.height:
		return 2
	return 3


## Two storeys of fall: anything more is refused, not clamped (a house that
## floats a storey above its own downhill edge is not a house).
static func max_fall(storey_height: float) -> float:
	return storey_height * 2.0


## The floor a door opens onto: its storey's slab top.
static func threshold_y(spec: HouseSpec, door: Dictionary) -> float:
	return float(HousePlan.record_storey(door)) * spec.height + HouseGeometry.FLOOR_T


static func lowest_storey(spec: HouseSpec) -> int:
	return -maxi(0, spec.cellars)


## Every exterior door's way down to the ground, front door first, each with
## its door index under "door". Empty on flat ground. Deterministic: the
## builder, the walk export and the suite all call this and read one answer.
static func flights(plan: HousePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spec: HouseSpec = plan.spec
	var g := ground(spec)
	if g == null:
		return out
	var blocked: Array[Rect2] = [HouseGeometry.site_rect(spec).grow(-0.01)]
	var chimney := HouseGeometry.chimney_rect(plan)
	if chimney.has_area():
		blocked.append(chimney)
	var order: Array[int] = []
	var entrance := plan.entrance()
	if entrance >= 0:
		order.append(entrance)
	for i in plan.doors.size():
		if i != entrance:
			order.append(i)
	var wall_t := HouseGeometry.wall_thickness(spec)
	for i in order:
		var door: Dictionary = plan.doors[i]
		if not bool(door.get("exterior", false)) or bool(door.get("secret", false)):
			continue
		var normal: Vector2 = Vector2(door["normal"]).normalized()
		var outer: Vector2 = Vector2(door["pos"]) + normal * wall_t
		var apron := Rect2()
		if i == entrance:
			for r in [HouseGeometry.porch_rect(plan), HouseGeometry.veranda_rect(plan)]:
				if r.has_area():
					apron = r if not apron.has_area() else apron.merge(r)
		# other doors' openings stay clear of this flight
		var mine: Array[Rect2] = blocked.duplicate()
		for j in plan.doors.size():
			var other: Dictionary = plan.doors[j]
			if j == i or not bool(other.get("exterior", false)):
				continue
			if HousePlan.record_storey(other) != HousePlan.record_storey(door):
				continue
			mine.append(HouseGeometry.door_opening_rect(spec, other))
		var f := g.plan_flight(outer, normal, float(door["width"]),
			threshold_y(spec, door), apron, mine)
		if f.is_empty():
			continue
		f["door"] = i
		out.append(f)
		blocked.append_array(GroundFall.flight_rects(f))
	return out


## Band 3: the bank storey's own door, on the downhill wall of a cellar room,
## where the ground is lowest and clear of the main door's flight. Called by
## the planner after the cellar is dug and before the hearth and furniture,
## so everything after it plans round a real door.
static func add_undercroft_door(p: HousePlan, spec: HouseSpec) -> void:
	var g := ground(spec)
	if g == null or band(spec) < 3 or spec.cellars < 1:
		return
	var inner := HouseGeometry.interior_rect(spec)
	var wall_t := HouseGeometry.wall_thickness(spec)
	var best_run := {}
	var best_dot := -INF
	for run in HouseGeometry.exterior_runs(spec):
		var d: float = Vector2(run["normal"]).dot(g.dir)
		if d > best_dot + 1e-6:
			best_dot = d
			best_run = run
	if best_dot < 0.3:
		return
	var normal: Vector2 = best_run["normal"]
	# what the door's own way out must keep clear of: the house itself is
	# not in this list (the door is cut through it), only what stands outside
	var taken: Array[Rect2] = []
	var chimney := HouseGeometry.chimney_rect(p)
	if chimney.has_area():
		taken.append(chimney)
	for f in flights(p):
		taken.append_array(GroundFall.flight_rects(f))
	var stair_rooms: Array[int] = []
	for s in p.stairs:
		stair_rooms.append(int(s.get("a", -1)))
		stair_rooms.append(int(s.get("b", -1)))
	var level := -1
	var width := HouseGeometry.DOOR_W
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + width * 0.5
	var best := {}
	var best_score := INF
	for room in p.rooms_on_storey(level):
		var rect: Rect2 = p.rooms[room]["rect"]
		var lo: float
		var hi: float
		var line: float
		if absf(normal.y) > 0.5:
			line = inner.position.y if normal.y < 0.0 else inner.end.y
			if absf((rect.position.y if normal.y < 0.0 else rect.end.y) - line) > 0.02:
				continue
			lo = rect.position.x
			hi = rect.end.x
		else:
			line = inner.position.x if normal.x < 0.0 else inner.end.x
			if absf((rect.position.x if normal.x < 0.0 else rect.end.x) - line) > 0.02:
				continue
			lo = rect.position.y
			hi = rect.end.y
		if hi - lo < m * 2.0:
			continue
		for t in [lo + m, (lo + hi) * 0.5, hi - m]:
			var pos := Vector2(line, t) if absf(normal.x) > 0.5 else Vector2(t, line)
			var door := {"a": room, "b": -1, "pos": pos, "normal": normal,
				"width": width, "exterior": true, "front": false, "storey": level,
				"undercroft": true}
			var opening := HouseGeometry.door_opening_rect(spec, door)
			var clash := false
			for r in taken:
				if r.intersects(opening.grow(0.1)):
					clash = true
					break
			if clash:
				continue
			var outer: Vector2 = pos + normal * wall_t
			var walls: Array[Rect2] = taken.duplicate()
			walls.append(HouseGeometry.site_rect(spec).grow(-0.01))
			var f := g.plan_flight(outer, normal, width, threshold_y(spec, door),
				Rect2(), walls)
			var steps: int = f["steps"].size() if not f.is_empty() else 0
			var score: float = float(steps) + (100.0 if not f.is_empty() and not bool(f["feasible"]) else 0.0) \
				+ (10.0 if room in stair_rooms else 0.0)
			if score < best_score - 1e-6:
				best_score = score
				best = door
	if best.is_empty():
		p.world_meta["ground_notes"] = ["bank storey: no clear stretch of the downhill wall for its door"]
		return
	HousePlanOpenings._set_domestic_door_head(p, best)
	p.doors.append(best)


## Emit everything under the house through `b`: the coursed foundation under
## each wall run of the lowest storey, a footing under an outside chimney
## stack, and every door's landing and steps. Called last by HouseBuilder and
## only when there is a fall, so a flat house emits nothing here.
static func emit(b: HouseBuilder) -> void:
	var plan: HousePlan = b.plan
	var spec: HouseSpec = plan.spec
	var g := ground(spec)
	if g == null:
		return
	var low := lowest_storey(spec)
	var top: float = float(low) * spec.height
	b.tag("foundation")
	b.host("foundation", low)
	for run in HouseGeometry.shell_runs(plan, low):
		var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec))) \
			+ HouseGeometry.PLINTH_EXTRA * 2.0
		g.emit_run(b, "foundation_course", run["from"], run["to"], thick, top,
			SURF_FLOOR, thick * 0.5)
	b.host_end()
	var chimney := HouseGeometry.chimney_rect(plan)
	if chimney.has_area():
		b.host("chimney", 0)
		g.emit_block(b, "chimney_footing", chimney.get_center(), Vector2(1.0, 0.0),
			chimney.size.x, chimney.size.y, 0.0, SURF_FLOOR)
		b.host_end()
	b.tag("entry_steps")
	for f in flights(plan):
		var door: Dictionary = plan.doors[int(f["door"])]
		b.host("entry_%d" % int(f["door"]), HousePlan.record_storey(door))
		g.emit_flight(b, f, SURF_FLOOR, float(HousePlan.record_storey(door)) * spec.height)
		b.host_end()


## A flight a person can actually walk: the landing at the threshold, every
## riser no more than GroundFall.RISER (plus a centimetre), every tread at
## least TREAD deep, and the last step within a riser of the ground at its
## foot. Returns the reasons it cannot be walked; empty when it can.
static func flight_faults(g: GroundFall, f: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if f.is_empty():
		return out
	var y: float = float(f["landing"]["top"])
	for s in f["steps"]:
		var drop: float = y - float(s["top"])
		if drop > GroundFall.RISER + 0.01 or drop < 0.0:
			out.append("riser of %.3f m" % drop)
		if float(s["length"]) < GroundFall.TREAD - 0.001:
			out.append("tread of %.3f m" % float(s["length"]))
		y = float(s["top"])
	var foot: Vector3 = f["foot"]
	if y - foot.y > GroundFall.RISER + 0.05:
		out.append("last step %.3f m above the ground" % (y - foot.y))
	if absf(foot.y - g.ground_y(Vector2(foot.x, foot.z))) > 0.01:
		out.append("foot is not on the ground")
	return out
