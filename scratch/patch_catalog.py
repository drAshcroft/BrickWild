import io
p = 'src/house/prop_catalog.gd'
s = io.open(p, encoding='utf-8').read()

# 1. the two new tags
old = '''const CEILING := "ceiling"        # hangs from the ceiling
const LIGHT := "light"            # counts toward a room being lit
'''
new = '''const CEILING := "ceiling"        # hangs from the ceiling
const LIGHT := "light"            # counts toward a room being lit
const PLANT := "plant"            # grows: measured as a canopy and a trunk
const GROUND := "ground"          # lies on the ground and is walked over
'''
assert s.count(old) == 1
s = s.replace(old, new)

# 2. the plant rows, at the end of PROPS
rows = io.open('scratch/plant_rows.txt', encoding='utf-8').read()
old = '''	"Dungeon_BearTrap_Open": {"pack": "dungeon", "cat": "trap", "tags": [], "zone": 0.0},
}
'''
new = '''	"Dungeon_BearTrap_Open": {"pack": "dungeon", "cat": "trap", "tags": [], "zone": 0.0},

	# ---- what grows (VILLAGES 7, 8) ----
	# Two packs, because a culture plants from one palette and not from both:
	# a norse edge is birch and pine, a moorish one twisted trees and pebbles.
	# Every one of these carries a measured `canopy` and `trunk` as well as a
	# box, because a bounding box is the wrong shape for a tree -- see
	# SceneBounds.radii_of_node(). GROUND marks the ones a person walks over
	# rather than round.
''' + rows + '''}
'''
assert s.count(old) == 1
s = s.replace(old, new)

# 3. blocks_floor: ground cover is walked over
old = '''## Does this prop stand on the floor and get in a person's way?
static func blocks_floor(key: String) -> bool:
	return not (has_tag(key, WALL_MOUNTED) or has_tag(key, CEILING)
		or has_tag(key, ON_SURFACE))
'''
new = '''## Does this prop stand on the floor and get in a person's way? Ground cover
## does not: you walk over clover, pebbles and stepping stones, and a village
## whose verges were obstacles would have no walkable verges.
static func blocks_floor(key: String) -> bool:
	return not (has_tag(key, WALL_MOUNTED) or has_tag(key, CEILING)
		or has_tag(key, ON_SURFACE) or has_tag(key, GROUND))


## The crown of a plant, as a radius about its own trunk, in metres; 0 for
## anything that is not one. A tree's bounding box is mostly air, so this --
## not the box -- is what the dressing check holds off the roofs.
static func canopy(key: String) -> float:
	_load()
	return float(_sizes[key].get("canopy", 0.0)) if _sizes.has(key) else 0.0


## The stem where it meets the ground, as a radius. This is a tree's real
## footprint: what stands in the road, and what the walk grid must go round.
static func trunk(key: String) -> float:
	_load()
	return float(_sizes[key].get("trunk", 0.0)) if _sizes.has(key) else 0.0


## Everything that grows, in a stable order -- what a culture's palette is
## drawn from (VILLAGES 8).
static func plants() -> Array[String]:
	var out: Array[String] = []
	for k in keys():
		if has_tag(k, PLANT):
			out.append(k)
	return out
'''
assert s.count(old) == 1
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('patched', p)
