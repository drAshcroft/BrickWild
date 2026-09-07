import io

p = 'qa/castle_qa.gd'
s = io.open(p, encoding='utf-8').read()

old = '''##   3. connected_mass     flood fill: every solid voxel reachable from the
##                         anchor mass, so nothing floats detached'''
new = '''##   3. connected_mass     flood fill: every solid voxel reachable from the
##                         anchor mass -- or from a building standing on its
##                         own in the bailey -- so nothing floats detached'''
assert old in s, 'doc'
s = s.replace(old, new, 1)

old = '''	var visited: Dictionary = _grid.flood_from(seed)
	var total: int = _grid.count_solid()'''
new = '''	var visited: Dictionary = _grid.flood_from(seed)
	# A building standing on its own in the courtyard is its OWN grounded
	# component. A stable is not attached to the curtain and is not meant to
	# be (CAS-012), so the flood is seeded from each of those as well. The rule
	# keeps its teeth either way: geometry attached to nothing at all is still
	# unreachable from every seed, and `grounded` is what says a free-standing
	# building has to stand on the ground.
	for m in builder.mass_log:
		var nm: String = m["name"]
		if not (nm.begins_with("yard_") or nm == "well"):
			continue
		var extra: Vector3i = _seed_inside(m["aabb"])
		if extra.x < 0:
			continue
		for k in _grid.flood_from(extra):
			visited[k] = true
	var total: int = _grid.count_solid()'''
assert old in s, 'flood'
s = s.replace(old, new, 1)

old = '''## Every opening must sit embedded in masonry AND not cut all the way through.'''
new = '''## A solid voxel somewhere inside `box`, or (-1, -1, -1) when it holds none.
func _seed_inside(box: AABB) -> Vector3i:
	for iy in range(4):
		var y: float = box.position.y + box.size.y * (float(iy) + 0.5) / 4.0
		for ix in range(5):
			var x: float = box.position.x + box.size.x * (float(ix) + 0.5) / 5.0
			for iz in range(5):
				var z: float = box.position.z + box.size.z * (float(iz) + 0.5) / 5.0
				var g := Vector3i(_grid.vx(x), _grid.vy(y), _grid.vz(z))
				if _grid.get_voxel(g.x, g.y, g.z):
					return g
	return Vector3i(-1, -1, -1)


## Every opening must sit embedded in masonry AND not cut all the way through.'''
assert old in s, 'helper'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
