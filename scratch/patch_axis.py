import io

p = 'qa/temple_rite_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''# --------------------------------------------------------------------- axis

func _check_axis() -> void:
	var altar: Vector3 = TempleGeometry.altar_center(_spec)
	var idol: Vector3 = TempleGeometry.idol_center(_spec)
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	if absf(altar.x) > TOL:
		failures.append("axis: the altar stands %.2fm off the centre line" % altar.x)
	if absf(idol.x) > TOL:
		failures.append("axis: the idol stands %.2fm off the centre line" % idol.x)
	if absf(entry.x) > TOL:
		failures.append("axis: the way in is %.2fm off the centre line" % entry.x)'''
new = '''# --------------------------------------------------------------------- axis

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
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var focus: Vector2 = plan.focus_pos()
	if not focus.is_finite() or door < 0 or door >= plan.doors.size():
		return [] as Array[String]
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
	if absf(along_focus - along_door) < f.size.y * 0.25 if lengthwise \\
			else absf(along_focus - along_door) < f.size.x * 0.25:
		out.append("axis: the %s is beside the way in, not down the room from it"
			% String(plan.focus_cat()))
	return out


func _check_axis() -> void:
	var altar: Vector3 = TempleGeometry.altar_center(_spec)
	var idol: Vector3 = TempleGeometry.idol_center(_spec)
	var entry: Vector2 = TempleGeometry.entry_point(_spec)
	for f in axis_faults(0.0, [["altar", altar.x], ["idol", idol.x],
			["way in", entry.x]], TOL):
		failures.append(f)'''
assert old in s, 'axis'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
