class_name TempleRiteCheck
extends RefCounted
## Would a rite work in this building?
##
## The structural checks in MassRules ask whether it stands up. These ask
## whether it is a temple, and every one of them is a statement about the axis
## -- the line from the gate to the god that the whole plan exists to stage.
##
##   AXIS         altar and idol on the centre line, in that order, with the
##                altar between the congregation and the god
##   SIGHTLINE    you can see the idol from the doorway. Nothing stands in the
##                way of it: not a column, not the roof, not the pit
##   PROCESSION   you can WALK that line, at a width people can process along,
##                and arrive at the altar
##   APPROACH     the celebrant can get round the altar to use it
##   CONGREGATION there is somewhere for everyone else to stand
##   DOMINANCE    the idol looms: it is the tallest thing indoors and it towers
##                over the altar in front of it
##   SYMMETRY     every mass has its twin across the axis. A temple that is not
##                symmetrical is a warehouse with ideas
##   FIRE         the way to the altar is lit the whole way, by fire, because
##                nothing here has windows worth the name
##   THE PIT      if there is a hole in the floor it is ON the axis, so the
##                procession has to cross it, and there is something to cross
##   THE CELLS    whatever is kept for the rite can be reached, and is not put
##                where the congregation would trip over it
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := 0.06
## Fraction of the hall that has to be standable floor for a congregation.
const CONGREGATION_MIN := 0.22
## The idol must be at least this many times the height of the altar top.
const DOMINANCE := 2.0
## And at least this share of the height of the room it stands in.
const IDOL_SHARE := 0.4

## The ten rules, in the order they run. A family may replace one through
## `check(spec, builder, overrides)` (RuleSet, INT-020): a replacement is
## called with (spec, builder).
const RULES: Array[StringName] = [&"axis", &"sightline", &"procession", &"approach",
	&"congregation", &"dominance", &"symmetry", &"fire", &"pit", &"cells"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}

var _spec: TempleSpec
var _builder: TempleBuilder
var _grid: WalkGrid


func check(spec: TempleSpec, builder: TempleBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	_spec = spec
	_builder = builder

	_walk()
	replaced = RuleSet.run(self, RULES, {}, overrides, [], [spec, builder],
		failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


# ------------------------------------------------------------------ walking

func _walk() -> void:
	_grid = WalkGrid.new()
	_grid.setup(TempleGeometry.plan_extent(_spec).grow(1.0), TempleGeometry.NAV_CELL)
	for r in TempleGeometry.floor_rects(_spec):
		_grid.add_floor(r)
	for o in TempleGeometry.obstacle_rects(_spec):
		_grid.add_obstacle(o)
	_grid.build(TempleGeometry.PERSON_RADIUS)
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	if not _grid.flood_from(entry, 1.2):
		failures.append("procession: there is nowhere to stand inside the gate")
	stats["walkable_area"] = snappedf(_grid.walkable_area(), 0.1)


## A picture of what the walker saw, with the gate, the altar and the idol
## marked. Reading a procession failure off the map takes a second; reading it
## off a list of coordinates does not.
func ascii_map() -> String:
	return _grid.ascii_map({
		TempleGeometry.entry_point(_spec): "G",
		Vector2(0.0, TempleGeometry.altar_center(_spec).z): "A",
		Vector2(0.0, TempleGeometry.idol_center(_spec).z): "I",
	})


# --------------------------------------------------------------------- axis

## Is the thing a room is arranged around ON THE ROOM'S AXIS, and is the way in
## on that same line?
##
## The temple asks this of its idol down a colonnade. A castle chapel asks it
## of its altar down a nave (INT-005), and a great hall of its high table down
## the hall -- it is one question, so it is answered in one place and takes
## plain geometry rather than a TempleSpec.
##
## `marks` is [[name, x], ...]: whatever has to stand on the line, named so the
## complaint can say which of them does not. Returns the complaints; an empty
## array is a building whose axis holds.
static func axis_faults(axis_x: float, marks: Array, tol: float) -> Array[String]:
	var out: Array[String] = []
	for m in marks:
		var off: float = float(m[1]) - axis_x
		if absf(off) > tol:
			out.append("axis: the %s stands %.2fm off the centre line" % [m[0], off])
	return out


## The same question asked of a HousePlan: the focus and the door both stand on
## the room's centre line, and the focus is beyond the door rather than beside
## it. This is the (plan, focus, door) form the chapel uses.
static func plan_axis_faults(plan: HousePlan, room: int, door: int,
		tol := 0.05) -> Array[String]:
	if plan == null or room < 0 or room >= plan.room_count():
		return ["axis: no room for the ceremonial axis"] as Array[String]
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var focus: Vector2 = plan.focus_pos()
	if not focus.is_finite() or door < 0 or door >= plan.doors.size():
		return ["axis: the focus or way in is missing"] as Array[String]
	var way_in: Vector2 = plan.doors[door]["pos"]
	# the axis runs the length of the room, so "off the line" is measured
	# across its SHORT side
	var lengthwise: bool = f.size.y >= f.size.x
	var axis: float = f.get_center().x if lengthwise else f.get_center().y
	var slack: float = tol * (f.size.x if lengthwise else f.size.y)
	var out: Array[String] = axis_faults(axis, [
		[String(plan.focus_cat()), focus.x if lengthwise else focus.y],
		["way in", way_in.x if lengthwise else way_in.y]], slack)
	var along_focus: float = focus.y if lengthwise else focus.x
	var along_door: float = way_in.y if lengthwise else way_in.x
	if absf(along_focus - along_door) < f.size.y * 0.25 if lengthwise \
			else absf(along_focus - along_door) < f.size.x * 0.25:
		out.append("axis: the %s is beside the way in, not down the room from it"
			% String(plan.focus_cat()))
	return out


## Named obstacles let temples and furnished rooms use exactly the same ray
## test, while each supplies its own intentional exemptions.
static func sightline_blockers(from: Vector3, to: Vector3, obstacles: Array) -> Array[String]:
	var out: Array[String] = []
	for obstacle in obstacles:
		if Sightline.hits(from, to, obstacle["aabb"]):
			out.append(String(obstacle["name"]))
	return out


## See a placed focus from a room's doorway, including on a raised sanctuary.
## `focus` is a furniture index: this checks what was placed, not just the
## point the planner hoped to furnish. Mounted decorations do not hide it.
static func plan_sightline_faults(plan: HousePlan, focus: int, door: int) -> Array[String]:
	if plan == null or focus < 0 or focus >= plan.furniture.size() \
			or door < 0 or door >= plan.doors.size():
		return ["sightline: the focus or way in is missing"] as Array[String]
	var target: Dictionary = plan.furniture[focus]
	var room: int = int(target["room"])
	var rect: Rect2 = target["rect"]
	var center: Vector2 = rect.get_center()
	var entry: Vector2 = plan.doors[door]["pos"]
	var base: float = plan.storey_of_room(room) * plan.spec.height
	var inside: Vector2 = entry + (center - entry).normalized() * 0.5
	var eye := Vector3(inside.x, base + 1.65, inside.y)
	var height: float = PropCatalog.height(String(target["key"])) * float(target.get("scale", 1.0))
	var target_y: float = Vector3(target["pos"]).y
	var aim := Vector3(center.x, target_y + height * 0.75, center.y)
	var obstacles: Array = []
	for i in plan.furniture_of(room):
		if i == focus:
			continue
		var piece: Dictionary = plan.furniture[i]
		if piece.get("mounted", false) or int(piece.get("host", -1)) >= 0:
			continue
		var bounds: Rect2 = piece["rect"]
		var h: float = PropCatalog.height(String(piece["key"])) * float(piece.get("scale", 1.0))
		obstacles.append({"name": "%s#%d" % [piece["key"], i], "aabb": AABB(
			Vector3(bounds.position.x, Vector3(piece["pos"]).y, bounds.position.y),
			Vector3(bounds.size.x, h, bounds.size.y))})
	var blocked := sightline_blockers(eye, aim, obstacles)
	if not blocked.is_empty():
		return ["sightline: %s hides the focus from the doorway" % ", ".join(blocked)] as Array[String]
	return [] as Array[String]


func _check_axis() -> void:
	var altar: Vector3 = TempleGeometry.altar_center(_spec)
	var idol: Vector3 = TempleGeometry.idol_center(_spec)
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	for f in axis_faults(0.0, [["altar", altar.x], ["idol", idol.x],
			["way in", entry.x]], TOL):
		failures.append(f)
	if not (entry.y < altar.z and altar.z < idol.z):
		failures.append("axis: gate at z=%.1f, altar at %.1f, idol at %.1f -- they must be in that order"
			% [entry.y, altar.z, idol.z])
	var gap: float = idol.z - altar.z - _spec.altar_l / 2.0 - _spec.idol_width / 2.0
	if gap < TempleGeometry.IDOL_GAP - TOL:
		failures.append("axis: only %.2fm between the altar and the idol" % gap)
	stats["axis_run"] = snappedf(idol.z - entry.y, 0.1)


## You have to be able to see the god from the door.
##
## The house equivalent of this axis is `HousePlan.focus` (INT-002): the
## hearth, counter or anvil a room is arranged around, pinned by the planner,
## scored toward by the furnisher and proved by HouseFurnishCheck's `focus`
## rule. This check is not rewritten on top of it -- a temple's focus is a
## line, not a point -- but the two are the same idea.
##
## The line is cast from a person's eye at the gate to the idol's upper half,
## and every structural mass is tested against it -- everything except the idol
## itself, the floor it all stands on, and the altar and dais, which are meant
## to be in front of it and are too low to hide it.
func _check_sightline() -> void:
	var idol: Vector3 = TempleGeometry.idol_center(_spec)
	var eye: Vector2 = TempleGeometry.sight_point(_spec)
	var from := Vector3(0.0, 1.65, eye.y)
	# aim at the FRONT of the idol, not its middle: a ray that ends inside the
	# god comes out the back of it and reports the wall behind as a blocker
	var to := Vector3(idol.x, idol.y + _spec.idol_height * 0.7,
		idol.z - _spec.idol_width / 2.0 - 0.05)
	var obstacles: Array = []
	for m in _builder.mass_log:
		var name: String = m["name"]
		if name.begins_with("column_"):
			continue
		if _exempt_from_sightline(name):
			continue
		obstacles.append({"name": name, "aabb": m["aabb"]})
	for i in range(_spec.columns.size()):
		var column: Dictionary = _spec.columns[i]
		var c: Vector3 = column["pos"]
		var r: float = float(column["radius"])
		var h: float = float(column["height"])
		var aabb := AABB(Vector3(c.x - r * 1.2, 0.0, c.z - r * 1.2),
			Vector3(r * 2.4, h + TempleGeometry.COLUMN_CAP * r, r * 2.4))
		obstacles.append({"name": "column_%d" % i, "aabb": aabb})
	var blocked := sightline_blockers(from, to, obstacles)
	stats["sightline_blockers"] = blocked.size()
	if not blocked.is_empty():
		failures.append("sightline: %s stands between the doorway and the idol"
			% ", ".join(blocked.slice(0, 3)))


static func _exempt_from_sightline(name: String) -> bool:
	for prefix in ["idol", "floor", "altar", "dais", "bridge", "terrace", "stair"]:
		if name.begins_with(prefix):
			return true
	return false


## The segment-against-boxes test itself lives in qa/sightline.gd, shared with
## the house focus rule and the courtyard checks (INT-020).


# --------------------------------------------------------------- procession

func _check_procession() -> void:
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	var altar: Vector3 = TempleGeometry.altar_center(_spec)
	var front := Vector2(0.0, altar.z - _spec.altar_l / 2.0 - TempleGeometry.ALTAR_CLEAR * 0.5)
	if not _grid.reached(TempleGeometry.altar_approach(_spec), 0.0):
		failures.append("procession: nobody can walk from the gate to the altar")
	var width: float = _grid.clearance_along(entry, front)
	stats["procession_width"] = snappedf(width, 0.01)
	if width < TempleGeometry.PROCESSION_MIN - TOL:
		failures.append("procession: the way to the altar narrows to %.2fm, and a procession needs %.2fm"
			% [width, TempleGeometry.PROCESSION_MIN])


## The celebrant has to be able to get round the altar. Three sides is a rite;
## two is a shelf.
func _check_approach() -> void:
	var a: Rect2 = TempleGeometry.altar_rect(_spec)
	var clear: float = TempleGeometry.ALTAR_CLEAR
	var sides := {
		"front": Rect2(Vector2(a.position.x, a.position.y - clear), Vector2(a.size.x, clear)),
		"back": Rect2(Vector2(a.position.x, a.end.y), Vector2(a.size.x, clear)),
		"left": Rect2(Vector2(a.position.x - clear, a.position.y), Vector2(clear, a.size.y)),
		"right": Rect2(Vector2(a.end.x, a.position.y), Vector2(clear, a.size.y)),
	}
	var open: Array[String] = []
	for side in sides:
		if _grid.standable(sides[side], 0.05):
			open.append(side)
	stats["altar_sides"] = open.size()
	if open.size() < 3:
		failures.append("approach: the altar can only be reached from %d side%s (%s)"
			% [open.size(), "" if open.size() == 1 else "s", ", ".join(open)])
	if not "front" in open:
		failures.append("approach: there is nowhere to stand in front of the altar")


## Somewhere for the congregation. A temple whose floor is all column and pit
## is a folly, however good it looks.
func _check_congregation() -> void:
	var hall: Rect2 = TempleGeometry.hall_rect(_spec)
	var area: float = hall.size.x * hall.size.y
	var walkable: float = _grid.walkable_area()
	stats["congregation"] = snappedf(walkable / maxf(area, 1.0), 0.01)
	if walkable < area * CONGREGATION_MIN:
		failures.append("congregation: only %.0f m2 of a %.0f m2 hall can be stood on"
			% [walkable, area])


# ----------------------------------------------------------------- the god

func _check_dominance() -> void:
	var apex: float = TempleGeometry.idol_apex(_spec)
	var altar_top: float = TempleGeometry.altar_center(_spec).y + _spec.altar_h
	stats["idol_apex"] = snappedf(apex, 0.1)
	if apex < altar_top * DOMINANCE:
		failures.append("dominance: the idol tops out at %.1fm over an altar at %.1fm -- it does not loom"
			% [apex, altar_top])
	var room: float = _spec.height if _spec.form != &"ziggurat" \
		else TempleGeometry.terrace_top(_spec) + _spec.idol_height
	if apex < room * IDOL_SHARE:
		warnings.append("dominance: the idol fills only %.0f%% of the height of the room"
			% [apex / maxf(room, 0.01) * 100.0])
	# and nothing in the sanctum with it may stand taller. Columns down the hall
	# may -- they hold the roof up, and a colonnade taller than the god is what
	# makes the walk toward him feel like a descent into somewhere smaller.
	var sanctum: Rect2 = TempleGeometry.sanctum_rect(_spec)
	for m in _builder.mass_log:
		var name: String = m["name"]
		if not _indoor_mass(name):
			continue
		var a: AABB = m["aabb"]
		var c: Vector3 = a.position + a.size / 2.0
		if not sanctum.has_point(Vector2(c.x, c.z)):
			continue
		var top: float = a.position.y + a.size.y
		if top > apex + TOL:
			failures.append("dominance: %s reaches %.1fm in the sanctum, above the idol at %.1fm"
				% [name, top, apex])
			break


## What counts as furniture of the rite, for the rule that the god is the
## tallest thing in his own sanctum. Columns are not on the list: they hold the
## roof up, and a colonnade taller than the idol is what makes the walk toward
## him feel like a descent into somewhere smaller.
static func _indoor_mass(name: String) -> bool:
	for prefix in ["altar", "dais", "cell", "bridge"]:
		if name.begins_with(prefix):
			return true
	return false


## Every mass has its twin across the axis, or straddles it evenly. This is the
## cheapest test there is for whether a plan was composed or merely filled.
func _check_symmetry() -> void:
	var offenders: Array[String] = []
	for i in range(_spec.columns.size()):
		var column: Dictionary = _spec.columns[i]
		var p: Vector3 = column["pos"]
		var mirrored := false
		for other in _spec.columns:
			var q: Vector3 = other["pos"]
			if absf(q.x + p.x) < TOL and absf(q.z - p.z) < TOL \
				and is_equal_approx(float(other["radius"]), float(column["radius"])) \
				and is_equal_approx(float(other["height"]), float(column["height"])):
				mirrored = true
				break
		if not mirrored:
			offenders.append("column_%d" % i)
	for m in _builder.mass_log:
		var a: AABB = m["aabb"]
		if String(m["name"]).begins_with("column_"):
			continue
		var c: Vector3 = a.position + a.size / 2.0
		if absf(c.x) < TOL:
			# it sits on the axis: then it must be even about it
			if absf(a.position.x + a.size.x / 2.0) > TOL:
				offenders.append(String(m["name"]))
			continue
		if not _has_mirror(a):
			offenders.append(String(m["name"]))
	stats["asymmetric"] = offenders.size()
	if not offenders.is_empty():
		failures.append("symmetry: %s %s no twin across the axis"
			% [", ".join(offenders.slice(0, 3)), "have" if offenders.size() > 1 else "has"])


func _has_mirror(a: AABB) -> bool:
	var want := AABB(Vector3(-(a.position.x + a.size.x), a.position.y, a.position.z),
		a.size)
	for m in _builder.mass_log:
		var b: AABB = m["aabb"]
		if (b.position - want.position).length() < 0.08 \
				and (b.size - want.size).length() < 0.08:
			return true
	return false


# --------------------------------------------------------------------- fire

## The way to the altar has to be lit, and lit by fire: there are no windows
## worth the name in any of these buildings.
func _check_fire() -> void:
	var lights: Array[Vector2] = []
	for p in _builder.prop_log:
		if p["kind"] == &"light":
			var v: Vector3 = p["pos"]
			lights.append(Vector2(v.x, v.z))
	stats["lights"] = lights.size()
	if lights.size() < 2:
		failures.append("fire: %d lights in the whole temple" % lights.size())
		return
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	var altar: float = TempleGeometry.altar_center(_spec).z
	var steps: int = maxi(int((altar - entry.y) / 1.0), 1)
	var darkest := 0.0
	var darkest_at := 0.0
	for i in range(steps + 1):
		var p := Vector2(0.0, lerpf(entry.y, altar, float(i) / float(steps)))
		var nearest := INF
		for l in lights:
			nearest = minf(nearest, p.distance_to(l))
		if nearest > darkest:
			darkest = nearest
			darkest_at = p.y
	stats["darkest_step"] = snappedf(darkest, 0.1)
	if darkest > TempleGeometry.LIGHT_REACH:
		failures.append("fire: the way is %.1fm from the nearest flame at z=%.1f"
			% [darkest, darkest_at])


# ---------------------------------------------------------------- the hole

func _check_pit() -> void:
	var p: Rect2 = TempleGeometry.pit_rect(_spec)
	stats["pit"] = p.size.x > 0.0
	if p.size.x <= 0.0:
		return
	if absf(p.get_center().x) > TOL:
		failures.append("pit: the hole is %.2fm off the axis, so nobody has to cross it"
			% p.get_center().x)
	var b: Rect2 = TempleGeometry.bridge_rect(_spec)
	if b.size.x < TempleGeometry.BRIDGE_MIN - TOL:
		failures.append("pit: there is no way across the hole")
	elif not _grid.reached(b, 0.0):
		failures.append("pit: the bridge over the hole cannot be reached")


# --------------------------------------------------------------- the cells

func _check_cells() -> void:
	var cells: Array[Rect2] = TempleGeometry.cell_rects(_spec)
	stats["cells"] = cells.size()
	var lane: float = TempleGeometry.axis_half_width(_spec)
	for i in range(cells.size()):
		var c: Rect2 = cells[i]
		if not _grid.reached(c, 0.1):
			failures.append("cells: cell %d cannot be reached from the hall" % i)
		if absf(c.get_center().x) < lane:
			failures.append("cells: cell %d opens onto the processional way" % i)
