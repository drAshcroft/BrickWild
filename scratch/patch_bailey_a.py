import io

p = 'src/castle/castle_geometry.gd'
s = io.open(p, encoding='utf-8').read()

anchor = '# -------------------------------------------------------------------- keep'
assert anchor in s, 'keep anchor'

block = '''# ------------------------------------------------------------------ bailey

## The strip a castle keeps clear from the gate to the keep.
##
## A bailey is a yard, and the one thing a yard may not have built across it is
## the way in: a cart has to get from the gate to the back of the ward. Its
## width is the gate plus a wagon either side.
static func gate_axis_strip(spec: CastleSpec) -> Rect2:
	var b: Rect2 = bailey_rect(spec)
	var half: float = gate_width(spec, 0) / 2.0 + AXIS_SHOULDER
	return Rect2(Vector2(-half, b.position.y), Vector2(half * 2.0, b.size.y))


## How much room a cart wants either side of the gate opening.
const AXIS_SHOULDER := 1.0


## The buildings already standing in the bailey, as plan rectangles: whatever
## the castle put there before the yard was laid out.
static func bailey_obstacles(spec: CastleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for box in [keep_aabb(spec), hall_aabb(spec), chapel_aabb(spec),
			apse_aabb(spec)]:
		if box.size.x > 0.01 and box.size.z > 0.01:
			out.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	return out


''' + anchor
s = s.replace(anchor, block, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')
