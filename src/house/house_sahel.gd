class_name HouseSahel
extends RefCounted
## HS-SAHEL: what makes the `african` style row a Sahel courtyard house beyond
## its flat banco roof and its court (HouseYard `court`, with flat-roofed ranges).
##
##   * BUTTRESSES: tapering pilasters on the outer walls, spaced along each wall
##     and kept clear of every door and window (`buttress`, `buttress_top`).
##   * TORON: the palm-wood stakes that stay in a banco wall, a row of them
##     under the roof edge of every wall (and through each buttress, where they
##     reach farther), clear of the openings.
##   * the DECORATED ENTRY: two pinnacled pilasters flanking the entrance door
##     (`entry_pinnacle`, a stepped shaft with a cap and a tip standing above the
##     parapet) and a raised relief frame round the door (`entry_relief`).
##
## The builder calls `emit` from `_build_culture`. Nothing here draws a random
## number: every position is read off the plan.

const SURF_WALL := HouseBuilder.SURF_WALL
const SURF_TRIM := HouseBuilder.SURF_TRIM

const BUTTRESS_W := 0.55        # across the wall, at the foot
const BUTTRESS_OUT := 0.42      # how far the foot stands off the wall's outer face
const BUTTRESS_SPACING := 2.6   # target centre spacing along a wall
const BUTTRESS_CORNER := 0.95   # nearest a buttress centre comes to a wall end
const OPENING_CLEAR := 0.3      # between a buttress and the nearest door or window
const TORON_W := 0.09
const TORON_OUT := 0.4
const TORON_SPACING := 0.55
const TORON_BELOW_TOP := 0.32
const PYLON_W := 0.62
const PYLON_RISE := 0.95        # above the wall top
const PYLON_PROUD := 0.06       # how far a pilaster stands past the roof's eave
const PYLON_TORON := 0.2        # how far a toron stands past the pilaster's face
const RELIEF_STRIP := 0.16


static func applies(spec: Object) -> bool:
	return spec != null and bool(spec.get("sahel"))


## The wall top of the storey `level` (the roof edge for the last).
static func _top(spec: HouseSpec) -> float:
	return spec.height * float(maxi(spec.storeys, 1))


## The height of the pilasters' shafts, above the floor.
static func pylon_height(spec: HouseSpec) -> float:
	return _top(spec) + HouseGeometry.PARAPET_BASE + HouseGeometry.PARAPET_H + 0.45


## The highest point of the house: the tip of a pinnacle (a cap of 0.4 m and a tip of 0.34 m).
static func top_height(spec: HouseSpec) -> float:
	return pylon_height(spec) + 0.4 + 0.34


## How far the entry pilasters stand past the wall's outer face: a hand's
## breadth past the roof's eave.
static func pylon_reach(spec: HouseSpec) -> float:
	return minf(HouseGeometry.roof_span_out(spec), HouseGeometry.roof_along_out(spec)) + PYLON_PROUD


## How far anything of the style stands past the wall's outer face (the exterior
## bound reads it): the toron that run through the pilasters, a little past them.
static func reach(spec: HouseSpec) -> float:
	return pylon_reach(spec) + PYLON_TORON


static func emit(b: HouseBuilder) -> void:
	var plan: HousePlan = b.plan
	var spec: HouseSpec = plan.spec
	if not applies(spec) or plan.world_family != &"" or HouseGeometry.is_shaped(plan) or plan.has_court():
		return
	var e := plan.entrance()
	var skip := {}   # run index -> the entry zone [t0, t1] no buttress may take
	var runs := HouseGeometry.shell_runs(plan, 0)
	var spots: Array = []   # [run index, t, width] of every buttress, for the toron
	var entry := _entry_zone(plan, runs, e)
	b.tag("buttress")
	b.host("buttress", 0)
	for ri in range(runs.size() if not "buttress" in spec.sahel_skip else 0):
		var run: Dictionary = runs[ri]
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec)))
		var ops := b._openings_on(from, to, run["normal"], 0, thick)
		for t in _buttress_spots(from, to, ops, entry.get(ri, []), _court_band(plan, run, e)):
			spots.append([ri, t])
			_buttress(b, spec, run, thick, t)
	b.host_end()
	b.tag("toron")
	b.host("toron", 0)
	for ri in range(runs.size() if not "toron" in spec.sahel_skip else 0):
		var run: Dictionary = runs[ri]
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec)))
		var ops := b._openings_on(from, to, run["normal"], 0, thick)
		var mine: Array = []
		for s in spots:
			if int(s[0]) == ri:
				mine.append(float(s[1]))
		_toron_rows(b, spec, run, thick, ops, mine, _court_band(plan, run, e), entry.get(ri, []))
	b.host_end()
	if e >= 0 and not "entry" in spec.sahel_skip:
		b.tag("entry")
		b.host("entry", 0)
		_entry(b, plan, spec, e)
		b.host_end()


## Where along each run the entrance door's pylons stand (t0, t1), so no
## buttress is taken there. {run index: [t0, t1]}
static func _entry_zone(plan: HousePlan, runs: Array, e: int) -> Dictionary:
	var out := {}
	if e < 0:
		return out
	var d: Dictionary = plan.doors[e]
	var n := Vector2(d["normal"]).normalized()
	var half := float(d["width"]) * 0.5 + PYLON_W + RELIEF_STRIP + 0.5
	for ri in range(runs.size()):
		var run: Dictionary = runs[ri]
		if Vector2(run["normal"]).dot(n) < 0.9:
			continue
		var from: Vector2 = run["from"]
		var dir: Vector2 = (Vector2(run["to"]) - from).normalized()
		var t := (Vector2(d["pos"]) - from).dot(dir)
		out[ri] = [t - half, t + half]
	return out


## The wall that faces the court has the court's ranges standing against its two
## ends; only the middle of it, between them, is wall in the open. [lo, hi] along
## the run, or [] for any other wall.
static func _court_band(plan: HousePlan, run: Dictionary, e: int) -> Array:
	if e < 0 or not bool(plan.spec.court_ranges):
		return []
	if Vector2(run["normal"]).dot(Vector2(plan.doors[e]["normal"]).normalized()) > -0.9:
		return []
	var length := Vector2(run["from"]).distance_to(Vector2(run["to"]))
	var edge := HouseYard.RANGE_DEPTH + 0.35
	return [edge, length - edge]


static func _buttress_spots(from: Vector2, to: Vector2, ops: Array, zone: Array, band: Array) -> Array[float]:
	var out: Array[float] = []
	var length := from.distance_to(to)
	var n := maxi(int(round(length / BUTTRESS_SPACING)), 1)
	for i in range(n):
		var t := length * (float(i) + 0.5) / float(n)
		# a buttress gives way to an opening by sliding along the wall
		var placed := false
		for shift in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05]:
			var tt: float = t + float(shift)
			if tt < BUTTRESS_CORNER or tt > length - BUTTRESS_CORNER:
				continue
			if band.size() == 2 and (tt - BUTTRESS_W * 0.5 < float(band[0]) or tt + BUTTRESS_W * 0.5 > float(band[1])):
				continue
			if not _clear(tt, ops, zone, out):
				continue
			out.append(tt)
			placed = true
			break
		if not placed:
			continue
	return out


static func _clear(t: float, ops: Array, zone: Array, taken: Array[float]) -> bool:
	for op in ops:
		if absf(t - float(op["t"])) < float(op["w"]) * 0.5 + BUTTRESS_W * 0.5 + OPENING_CLEAR:
			return false
	if zone.size() == 2 and t > float(zone[0]) and t < float(zone[1]):
		return false
	for o in taken:
		if absf(t - o) < BUTTRESS_W + 0.6:
			return false
	return true


static func _frame(run: Dictionary, t: float, off: float, y: float) -> Transform3D:
	var from: Vector2 = run["from"]
	var dir: Vector2 = (Vector2(run["to"]) - from).normalized()
	var p: Vector2 = from + dir * t + Vector2(run["normal"]) * off
	return Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(p.x, y, p.y))


## A buttress is two blocks: a broad foot up to 62 % of the wall and a narrower,
## shallower shaft above it that ends a little over the eave, inside the parapet.
static func _buttress(b: HouseBuilder, spec: HouseSpec, run: Dictionary, thick: float, t: float) -> void:
	var face := thick * 0.5
	var top := _top(spec) + 0.3
	var foot_h := top * 0.62
	# both blocks reach back into the wall by 0.1 m, so neither floats
	var foot_d := BUTTRESS_OUT + 0.1
	b.component_box("buttress", Vector3(BUTTRESS_W, foot_h, foot_d),
		_frame(run, t, face + foot_d * 0.5 - 0.1, foot_h * 0.5), SURF_WALL)
	var shaft_w := BUTTRESS_W * 0.72
	var shaft_d := BUTTRESS_OUT * 0.62 + 0.1
	var shaft_h := top - foot_h
	b.component_box("buttress_top", Vector3(shaft_w, shaft_h, shaft_d),
		_frame(run, t, face + shaft_d * 0.5 - 0.1, foot_h + shaft_h * 0.5), SURF_WALL)


static func _toron_rows(b: HouseBuilder, spec: HouseSpec, run: Dictionary, thick: float,
		ops: Array, buttresses: Array, band: Array, zone: Array) -> void:
	var from: Vector2 = run["from"]
	var length := from.distance_to(Vector2(run["to"]))
	var face := thick * 0.5
	for level in range(maxi(spec.storeys, 1)):
		var y := spec.height * float(level + 1) - TORON_BELOW_TOP
		var t := 0.55
		while t < length - 0.45:
			var blocked := false
			# a stake may stand above an opening, but not cross its frame
			for op in ops:
				if absf(t - float(op["t"])) < float(op["w"]) * 0.5 + 0.3 + TORON_W 						and float(op["top"]) + 0.15 > y - TORON_W * 0.5:
					blocked = true
					break
			# the entry's own toron are on its pilasters
			if zone.size() == 2 and t > float(zone[0]) and t < float(zone[1]):
				blocked = true
			if band.size() == 2 and (t < float(band[0]) or t > float(band[1])):
				blocked = true
			if not blocked:
				var reach := TORON_OUT
				for bt in buttresses:
					if absf(t - float(bt)) < BUTTRESS_W * 0.5:
						reach = TORON_OUT + BUTTRESS_OUT * 0.62
				# the stake runs through the wall (0.2 m of it inside) and out
				var len := reach + 0.2
				b.component_box("toron", Vector3(TORON_W, TORON_W, len),
					_frame(run, t, face + len * 0.5 - 0.2, y), SURF_TRIM)
			t += TORON_SPACING


## The decorated entry: two pinnacled pilasters and a relief frame round the door.
static func _entry(b: HouseBuilder, plan: HousePlan, spec: HouseSpec, e: int) -> void:
	var d: Dictionary = plan.doors[e]
	var n := Vector2(d["normal"]).normalized()
	var xf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)),
		Vector3(d["pos"].x, 0.0, d["pos"].y))
	# a door is recorded on the INNER face of its wall: the outer face is a whole
	# wall's thickness out from it
	var face := HouseGeometry.wall_thickness(spec)
	# the pilasters stand a hand's breadth past the eave, so the roof's edge does
	# not hide them and they read as towers beside the door
	var pylon_out := pylon_reach(spec)
	var dw := float(d["width"])
	var top := _top(spec)
	var door_h := minf(HouseGeometry.DOOR_H, spec.height - 0.2)
	var pylon_h := pylon_height(spec)
	var px := dw * 0.5 + RELIEF_STRIP + PYLON_W * 0.5 + 0.04
	for s in [-1.0, 1.0]:
		var x := float(s) * px
		# a stepped shaft: a broad foot, a narrower shaft through the parapet
		var foot_h := pylon_h * 0.55
		b.component_box("entry_pinnacle", Vector3(PYLON_W, foot_h, pylon_out + 0.1),
			xf * Transform3D(Basis(), Vector3(x, foot_h * 0.5, face + pylon_out * 0.5 - 0.05)), SURF_WALL)
		var up_h := pylon_h - foot_h
		var up_w := PYLON_W * 0.78
		var up_d := pylon_out * 0.78
		b.component_box("entry_pinnacle", Vector3(up_w, up_h, up_d + 0.1),
			xf * Transform3D(Basis(), Vector3(x, foot_h + up_h * 0.5, face + up_d * 0.5 - 0.05)), SURF_WALL)
		# the cap, then the tip: the pinnacle narrows to a point in two steps
		var cap_w := PYLON_W * 0.5
		var cap_h := 0.4
		b.component_box("entry_pinnacle_cap", Vector3(cap_w, cap_h, cap_w),
			xf * Transform3D(Basis(), Vector3(x, pylon_h + cap_h * 0.5 - 0.02, face + up_d * 0.5 - 0.05)), SURF_WALL)
		var tip_w := cap_w * 0.5
		b.component_box("entry_pinnacle_tip", Vector3(tip_w, 0.34, tip_w),
			xf * Transform3D(Basis(), Vector3(x, pylon_h + cap_h + 0.17 - 0.04, face + up_d * 0.5 - 0.05)), SURF_WALL)
		# toron through the pilaster
		for k in range(3 if not "toron" in spec.sahel_skip else 0):
			var ty := door_h * 0.45 + float(k) * 0.42 if k < 2 else top - TORON_BELOW_TOP
			b.component_box("toron", Vector3(TORON_W, TORON_W, pylon_out + PYLON_TORON + 0.2),
				xf * Transform3D(Basis(), Vector3(x, ty, face + (pylon_out + PYLON_TORON) * 0.5 - 0.1)), SURF_TRIM)
	# the relief frame: a strip each side of the door, a header over it, and a
	# row of three raised blocks above the header
	var rel_out := 0.09
	for s in [-1.0, 1.0]:
		b.component_box("entry_relief", Vector3(RELIEF_STRIP, door_h + 0.22, rel_out + 0.1),
			xf * Transform3D(Basis(), Vector3(float(s) * (dw * 0.5 + RELIEF_STRIP * 0.5),
				(door_h + 0.22) * 0.5, face + rel_out * 0.5 - 0.05)), SURF_WALL)
	var head_w := dw + RELIEF_STRIP * 2.0 + 0.1
	b.component_box("entry_relief", Vector3(head_w, RELIEF_STRIP, rel_out + 0.14),
		xf * Transform3D(Basis(), Vector3(0.0, door_h + 0.22 + RELIEF_STRIP * 0.5 - 0.1, face + (rel_out + 0.04) * 0.5 - 0.05)), SURF_WALL)
	for k in range(3):
		var bx := (float(k) - 1.0) * (head_w / 3.0)
		b.component_box("entry_relief", Vector3(head_w / 3.0 - 0.16, 0.2, rel_out + 0.04),
			xf * Transform3D(Basis(), Vector3(bx, door_h + 0.22 + RELIEF_STRIP + 0.1, face + rel_out * 0.5 - 0.05)), SURF_WALL)
