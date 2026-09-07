import io

# ---- 1. a focus the room gave up is a compromise, not a defect -- even when
#         other pieces of the same category are still standing
p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	if pos.is_finite() and best_d > FOCUS_TOL:
		failures.append("focus: %s stands %.2fm from the focus the plan recorded"
			% [_who(plan, best), best_d])
	if not plan.focus_faces_door():
		return'''
new = '''	# A room that gave up the piece it was arranged around wrote that down, and
	# what is left of the category is not that piece: a great hall whose high
	# table went so the hall could be walked still has its trestles, and
	# measuring one of THOSE against the dais is measuring the wrong table.
	var gave_up: bool = plan.was_dropped(room, cat)
	if pos.is_finite() and best_d > FOCUS_TOL:
		var said := "focus: %s stands %.2fm from the focus the plan recorded" \\
			% [_who(plan, best), best_d]
		if gave_up:
			warnings.append(said + ", and the room gave up the one that stood there")
			return
		failures.append(said)
	if not plan.focus_faces_door():
		return'''
assert old in s, 'focus distance'
s = s.replace(old, new)

old = '''	if off > FOCUS_FACE_DEG and not squarely:
		failures.append("focus: the %s in room %d faces away from the door" % [cat, room])'''
new = '''	if off > FOCUS_FACE_DEG and not squarely:
		var said2 := "focus: the %s in room %d faces away from the door" % [cat, room]
		if gave_up:
			warnings.append(said2 + ", and the room gave up the one that faced it")
		else:
			failures.append(said2)'''
assert old in s, 'focus facing'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnish check ok')

# ---- 2. a hall too narrow to stand the high table across it does not ask for
#         a view down the hall it cannot give
p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	plan.focus = {"room": 0, "cat": "table",
		"pos": dais.get_center() - up * (depth * HIGH_TABLE_SET_IN),
		"facing": atan2(up.x, up.y), "faces_door": true}'''
new = '''	#
	# A hall narrower than the high table is long has to stand the table
	# LENGTHWISE, and a table standing lengthwise cannot look down the hall at
	# anything. Ask for the view only where the room can give it: the table
	# across the hall, and a way past it either side.
	var faces: bool = across >= _longest_table() + HouseGeometry.PATH_MIN * 2.0
	plan.focus = {"room": 0, "cat": "table",
		"pos": dais.get_center() - up * (depth * HIGH_TABLE_SET_IN),
		"facing": atan2(up.x, up.y), "faces_door": faces}'''
assert old in s, 'focus record'
s = s.replace(old, new)

old = '''## A HouseSpec describing the hall own box, so every house helper --'''
new = '''## The longest side of the biggest table the catalogue has, which is how much
## of the hall's width a high table standing across it takes up.
static func _longest_table() -> float:
	var out := 0.0
	for key in PropCatalog.of_category("table"):
		var f: Vector2 = PropCatalog.footprint(key)
		out = maxf(out, maxf(f.x, f.y))
	return out


## A HouseSpec describing the hall own box, so every house helper --'''
assert old in s, 'longest table'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('castle ok')
