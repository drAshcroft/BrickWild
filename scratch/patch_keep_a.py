import io

# ---------------------------------------------------------------- geometry
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()

old = 'const ROOM_ASPECT_MAX := 3.4\n'
new = '''## The most storeys the HARNESS will measure. A house stops at three and each
## family clamps itself to what it is -- but the cap belongs to the checks, not
## to the house: a castle keep is four storeys of one room each, and a check
## that stopped counting at three would report its top floor as invalid rather
## than walk it. (CAS-011)
const MAX_STOREYS := 4

const ROOM_ASPECT_MAX := 3.4
'''
assert old in s, 'aspect anchor'
s = s.replace(old, new, 1)

old = '\t&"gallery": 8.0, &"laundry": 7.0, &"great_hall": 16.0,\n}'
new = '\t&"gallery": 8.0, &"laundry": 7.0, &"great_hall": 16.0,\n\t&"lords_chamber": 10.0,\n}'
assert old in s, 'MIN_AREA'
s = s.replace(old, new)

old = '\t&"gallery": 2.4, &"laundry": 2.4, &"great_hall": 3.0,\n}'
new = '\t&"gallery": 2.4, &"laundry": 2.4, &"great_hall": 3.0,\n\t&"lords_chamber": 2.8,\n}'
assert old in s, 'MIN_SIDE'
s = s.replace(old, new)

old = '''	&"lounge", &"suite", &"gallery", &"laundry", &"great_hall"]'''
new = '''	&"lounge", &"suite", &"gallery", &"laundry", &"great_hall",
	&"lords_chamber"]'''
assert old in s, 'HABITABLE'
s = s.replace(old, new)

old = 'const SLEEPING := [&"bedroom", &"guest_room", &"suite"]'
new = 'const SLEEPING := [&"bedroom", &"guest_room", &"suite", &"lords_chamber"]'
assert old in s, 'SLEEPING'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')

# ------------------------------------------------------------------ checks
for path, count in [('qa/house_plan_check.gd', 3), ('qa/house_nav_check.gd', 1),
                    ('qa/house_qa.gd', 1)]:
    s = io.open(path, encoding='utf-8').read()
    n = s.count('storeys), 1, 3)')
    assert n == count, (path, n, count)
    s = s.replace('storeys), 1, 3)', 'storeys), 1, HouseGeometry.MAX_STOREYS)')
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print(path, 'ok', n)

# ----------------------------------------------------------- furnish check
p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	&"great_hall": ["table"],
}'''
new = '''	&"great_hall": ["table"],
	&"lords_chamber": ["bed"],
}'''
assert old in s, 'REQUIRED'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnish check ok')

# -------------------------------------------------------------- furnisher
p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()

old = '\t&"guest_room": [\n\t\t{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},'
new = '''	&"lords_chamber": [
		# The room at the top of a keep: a bed, a fire of its own, and enough
		# to sit at. The hearth comes before the bed because the flue is on a
		# named wall (LAY-001) and the bed can go anywhere else.
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "table", "rule": &"free", "n": [0, 1], "opt": 0.6},
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.8},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
	],
''' + old
assert old in s, 'recipe anchor'
s = s.replace(old, new)

old = '''	var sleeps_here: bool = not spec is ShopSpec and kind == &"hall" \\
		and not plan.has_kind(&"bedroom")'''
new = '''	var sleeps_here: bool = not spec is ShopSpec and kind == &"hall" \\
		and not _anybody_sleeps(plan)'''
assert old in s, 'sleeps_here'
s = s.replace(old, new)

old = '''static func _furnish_room(plan: HousePlan, spec: HouseSpec, room: int) -> void:'''
new = '''## Does anybody sleep anywhere in this plan?
##
## A hall doubles as a bedroom only when nothing else in the building is one --
## which is what a one-room cottage does. "Bedroom" is not the only room people
## sleep in, though: a keep's lord sleeps in his chamber at the top, and asking
## only for &"bedroom" put a bed in his hall as well.
static func _anybody_sleeps(plan: HousePlan) -> bool:
	for kind in HouseGeometry.SLEEPING:
		if plan.has_kind(kind):
			return true
	return false


static func _furnish_room(plan: HousePlan, spec: HouseSpec, room: int) -> void:'''
assert old in s, 'furnish_room'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')
