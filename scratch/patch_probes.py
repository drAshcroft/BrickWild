import io

p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()

old = '''const PROBE_STEP := 0.12'''
new = '''const PROBE_STEP := 0.12
## And the most probe positions any one search takes along a line or across a
## floor. A house room is a few metres across, so this never binds there --
## but a castle great hall is sixty metres across, and at 12 cm that is five
## hundred offsets on one wall and a quarter of a million on the floor, for an
## answer that stopped changing after the first few dozen. The step stays 12 cm
## and the SPACING opens up when the room is too big to sample at 12 cm.
const MAX_PROBES := 64'''
assert old in s
s = s.replace(old, new)

old = '''		var steps: int = maxi(int((run - small) / PROBE_STEP), 1)'''
new = '''		var steps: int = clampi(int((run - small) / PROBE_STEP), 1, MAX_PROBES)'''
assert old in s
s = s.replace(old, new)

old = '''				var slides: int = maxi(int(slack / PROBE_STEP), 0)'''
new = '''				var slides: int = clampi(int(slack / PROBE_STEP), 0, MAX_PROBES)'''
assert old in s
s = s.replace(old, new)

old = '''	var nx: int = maxi(int((hi.x - lo.x) / PROBE_STEP), 1)
	var nz: int = maxi(int((hi.y - lo.y) / PROBE_STEP), 1)'''
new = '''	var nx: int = clampi(int((hi.x - lo.x) / PROBE_STEP), 1, MAX_PROBES)
	var nz: int = clampi(int((hi.y - lo.y) / PROBE_STEP), 1, MAX_PROBES)'''
assert old in s
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')
