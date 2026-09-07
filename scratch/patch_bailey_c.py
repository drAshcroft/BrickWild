import io

# ---- 1. a mass may stand on its own, the way `grounded` already allows one
#         to be carried
p = 'qa/mass_rules.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## Every mass must be reachable from `anchor` through touching neighbours.
## Returns {"failures": [...], "joined": int}.
static func gaps(masses: Array[Dictionary], anchor: String) -> Dictionary:'''
new = '''## Every mass must be reachable from `anchor` through touching neighbours.
##
## Except those whose names begin with one of `free`. This rule is about a mass
## that FLOATS -- a buttress that reaches nothing, a roof over no wall -- and a
## building standing on its own in a courtyard is not floating: it is a
## separate building, and `grounded` is the rule that says it must stand on
## something. A castle bailey is a yard with sheds in it.
## Returns {"failures": [...], "joined": int}.
static func gaps(masses: Array[Dictionary], anchor: String,
		free: Array = []) -> Dictionary:'''
assert old in s, 'gaps sig'
s = s.replace(old, new)

old = '''	for i in range(n):
		if seen.has(i):
			continue
		# nearest neighbour, to describe the gap usefully'''
new = '''	for i in range(n):
		if seen.has(i):
			continue
		if _named(String(masses[i]["name"]), free):
			continue
		# nearest neighbour, to describe the gap usefully'''
assert old in s, 'gaps loop'
s = s.replace(old, new)

old = '''## Masses may interpenetrate only where a joint declares it, and only that deep.'''
new = '''## Does this mass name begin with any of `prefixes`?
static func _named(name: String, prefixes: Array) -> bool:
	for p in prefixes:
		if name.begins_with(String(p)):
			return true
	return false


## Masses may interpenetrate only where a joint declares it, and only that deep.'''
assert old in s, 'named helper'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('mass_rules ok')

# ---- 2. the castle passes the bailey prefixes through
p = 'qa/castle_massing_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	var g: Dictionary = MassRules.gaps(builder.mass_log, _anchor(spec))'''
new = '''	# A yard building and the well stand on their own in the bailey: they are
	# buildings in a courtyard, not part of the fortification (CAS-012).
	var g: Dictionary = MassRules.gaps(builder.mass_log, _anchor(spec),
		["yard_", "well"])'''
assert old in s, 'gaps call'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('castle check ok')
