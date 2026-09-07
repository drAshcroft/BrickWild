import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

anchor = '## The keep as a plan (CAS-011; CRITIQUE 3.2).'
assert anchor in s, 'anchor'

block = '''## The chapel as a plan (CAS-014; CRITIQUE 3.2).
##
## A chapel is a hall with one thing at the end of it, so it is built from the
## same parts the great hall is: a single room, a focus the room is arranged
## around, and rows either side of a centre aisle. What makes it a chapel
## rather than a hall is the AXIS -- the way in, the aisle and the altar on one
## line, which is the temple's own rule brought indoors
## (`TempleRiteCheck.axis_faults`).
##
##   the ALTAR at the far end, on the centre line, looking down the nave
##   the PEWS in two rows with a centre aisle to walk up
##   the WAY IN at the near end, on that same line
##
## The plan is in the chapel's own frame; `chapel_aabb` says where it sits.
## Empty when the castle has no chapel range, or when the range is not the
## size of one.
static func chapel_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.chapel:
		return plan
	var box: AABB = CastleGeometry.chapel_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var hs: HouseSpec = _chapel_spec(spec, box)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	var across: float = minf(floor_rect.size.x, floor_rect.size.y)
	var along: float = maxf(floor_rect.size.x, floor_rect.size.y)
	if across < MIN_NAVE_SIDE or along > MAX_NAVE_RUN:
		return plan
	if floor_rect.size.x * floor_rect.size.y < MIN_NAVE_AREA:
		return plan
	plan.spec = hs
	plan.rooms = [{"kind": &"nave", "rect": floor_rect, "storey": 0}]

	# The nave runs along its longer side, the way in at one end and the altar
	# at the other.
	var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
	var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
	_hall_door(plan, floor_rect, up)
	_hall_windows(plan, floor_rect, up, hs)

	# The altar stands a pace off the end wall, ON THE CENTRE LINE, looking
	# back down the nave at the door -- which is the whole of what an axis is.
	var mid: Vector2 = floor_rect.get_center()
	var far: Vector2 = mid + up * (along / 2.0 - ALTAR_SET_IN)
	plan.focus = {"room": 0, "cat": "table",
		"pos": Vector2(mid.x, far.y) if lengthwise else Vector2(far.x, mid.y),
		"facing": atan2(up.x, up.y), "faces_door": true}
	HouseFurnisher.furnish(plan, hs)
	return plan


## What a range has to measure to be furnished as a chapel, and how far off
## the end wall the altar stands.
const MIN_NAVE_SIDE := 2.8
const MIN_NAVE_AREA := 12.0
const MAX_NAVE_RUN := 60.0
const ALTAR_SET_IN := 1.4


## A HouseSpec describing the chapel's own box, so every house helper measures
## it the way it measures a room.
static func _chapel_spec(spec: CastleSpec, box: AABB) -> HouseSpec:
	var out := HouseSpec.new(spec.seed ^ 0x43_48_50_4C)
	out.style = &"longhall"
	out.width = box.size.x
	out.length = box.size.z
	out.height = clampf(box.size.y, 2.6, 6.0)
	out.storeys = 1
	out.room_count = 1
	out.program = [&"nave"] as Array[StringName]
	out.variant_name = "%s: the chapel" % spec.variant_name
	out.wall_color = spec.stone_color
	out.trim_color = spec.trim_color
	out.roof_color = spec.roof_color
	out.floor_color = spec.stone_color.darkened(0.35)
	out.clutter = 0.5
	return out


''' + anchor
s = s.replace(anchor, block, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
