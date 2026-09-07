import io

# ---- the nave, as a room kind
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()
for a, b in [
    ('\t&"lords_chamber": 10.0,\n}', '\t&"lords_chamber": 10.0, &"nave": 12.0,\n}'),
    ('\t&"lords_chamber": 2.8,\n}', '\t&"lords_chamber": 2.8, &"nave": 2.8,\n}'),
    ('\t&"lords_chamber"]', '\t&"lords_chamber", &"nave"]'),
    ("const ASPECT_MAX := {&\"great_hall\": 6.0}",
     "const ASPECT_MAX := {&\"great_hall\": 6.0, &\"nave\": 6.0}"),
]:
    assert a in s, a[:40]
    s = s.replace(a, b, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')

p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()
a = '\t&"lords_chamber": ["bed"],\n}'
b = '\t&"lords_chamber": ["bed"],\n\t&"nave": ["table"],\n}'
assert a in s, 'REQUIRED'
io.open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(a, b, 1))
print('furnish check ok')

# ---- the recipe
p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()
anchor = '\t&"lords_chamber": ['
assert anchor in s, 'anchor'
recipe = '''	&"nave": [
		# A chapel is a hall with one thing at the end of it. The altar is a
		# table, because in this catalogue that is what an altar is -- the
		# castle dressing has said so since CAS-003 -- and the pews are rows
		# either side of a centre aisle, which is the row rule doing what it
		# was written for (INT-001).
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 1.2,
			"aisle": 1.2, "seat_clearance": 0.0, "along": "wall", "opt": 1.0},
		{"cat": "bench", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 1.2,
			"aisle": 1.2, "seat_clearance": 0.0, "along": "wall", "opt": 1.0},
		{"cat": "candelabrum", "rule": &"free", "n": [0, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 4], "opt": 1.0},
		{"cat": "tableware", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
	],
'''
s = s.replace(anchor, recipe + anchor, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')
