import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

old = ('\tvar floor_rect: Rect2 = HouseGeometry.interior_rect(hs)\n'
       '\tif minf(floor_rect.size.x, floor_rect.size.y) < MIN_HALL_SIDE \\\n'
       '\t\t\tor floor_rect.size.x * floor_rect.size.y < MIN_HALL_AREA:\n'
       '\t\treturn plan\n')
new = ('\tvar floor_rect: Rect2 = HouseGeometry.interior_rect(hs)\n'
       '\tvar across: float = minf(floor_rect.size.x, floor_rect.size.y)\n'
       '\tvar along: float = maxf(floor_rect.size.x, floor_rect.size.y)\n'
       '\tif across < MIN_HALL_SIDE or across > MAX_HALL_SIDE or along > MAX_HALL_RUN:\n'
       '\t\treturn plan\n'
       '\tif floor_rect.size.x * floor_rect.size.y < MIN_HALL_AREA:\n'
       '\t\treturn plan\n')
assert old in s, 'guard block'
s = s.replace(old, new)

old = ('## The narrowest and the smallest a range may be and still be furnished as a\n'
       '## great hall. Below this it is a lean-to with a roof on, and it gets no plan\n'
       '## rather than a plan of a hall nobody could hold a feast in.\n'
       'const MIN_HALL_SIDE := 3.0\n'
       'const MIN_HALL_AREA := 16.0\n')
new = ('## What a range has to measure to be furnished as a great hall.\n'
       '##\n'
       '## Below the minimum it is a lean-to with a roof on. Above the maximum it is\n'
       '## not a hall either: a great hall is ONE ROOM under ONE ROOF, spanned by a\n'
       '## truss, and the widest ever built is Westminster at 20.7 m. A fortress\n'
       '## range is sixty metres across and a hundred and fifty long, which is a\n'
       '## courtyard block the massing happens to draw as one mass -- furnishing it\n'
       '## with a high table and a row of trestles would be a lie about the building,\n'
       '## and an expensive one: the walk grid alone would be six hundred thousand\n'
       '## cells.\n'
       '##\n'
       '## Either way the range still gets its mass. What it does not get is an\n'
       '## inside.\n'
       'const MIN_HALL_SIDE := 3.0\n'
       'const MIN_HALL_AREA := 16.0\n'
       'const MAX_HALL_SIDE := 25.0\n'
       'const MAX_HALL_RUN := 80.0\n')
assert old in s, 'const block'
s = s.replace(old, new)

old = ('## Empty when the castle has no hall range, or when the range is too small to\n'
       '## be a hall rather than a lean-to.\n')
new = ('## Empty when the castle has no hall range, or when the range is not the size\n'
       '## of a hall at all -- see MIN_HALL_SIDE and MAX_HALL_SIDE.\n')
assert old in s, 'doc line'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
