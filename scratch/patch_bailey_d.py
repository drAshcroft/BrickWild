import io

p = 'src/castle/castle_builder.gd'
s = io.open(p, encoding='utf-8').read()

# find where the hall and chapel are emitted, and add the yard after them
old = '''		_range(chapel, "chapel", SURF_STONE, true, [Vector3(-1, 0, 0)], RANGE_BAY)'''
assert old in s, 'chapel'
s = s.replace(old, old + '\n\t_build_yard()', 1)

anchor = '''func _range(a: AABB, mass_name: String, surf: int, roofed: bool,'''
assert anchor in s, 'range anchor'

block = '''## What stands in the bailey besides the keep, the hall and the chapel
## (CAS-012). The layout is the generator's -- see `CastleGenerator
## .bailey_buildings` -- and all this does is raise the shell of each and log
## it, so the massing check has something to measure and the assembler has
## somewhere to set the real shop down.
func _build_yard() -> void:
	tag("yard")
	for b in CastleGenerator.bailey_buildings(spec):
		var rect: Rect2 = b["rect"]
		var h: float = YARD_WALL_H
		var a := AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, h, rect.size.y))
		_range(a, "yard_%s" % String(b["business"]), SURF_STONE, true, [], RANGE_BAY)
	var well: Dictionary = CastleGenerator.bailey_well(spec)
	if well.is_empty():
		return
	var at: Vector2 = well["pos"]
	var kit := PropKit.new(_kit, SURF_STONE, SURF_TRIM, SURF_ROOF, SURF_OPEN)
	var box: AABB = kit.well(Vector3(at.x, 0.0, at.y), 0.0, float(well["radius"]))
	if box.size.x > 0.01:
		_log_mass("well", box)
		total_height = maxf(total_height, box.position.y + box.size.y)


## How high a yard building stands to its eaves. A stable and a cookshop are
## single-storey buildings in a courtyard, not ranges against the wall.
const YARD_WALL_H := 3.2


''' + anchor
s = s.replace(anchor, block, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('builder ok')
