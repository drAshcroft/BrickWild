import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

anchor = '## The longest side of the biggest table the catalogue has, which is how much'
assert anchor in s

block = '''## The keep as a plan (CAS-011; CRITIQUE 3.2).
##
## A keep is the one castle building the house harness already knew how to
## describe: stacked storeys of one room each with a stair against the wall,
## which is `HouseSpec.storeys` and `HousePlanner._add_stair` and nothing new.
## What it needed was a programme of its own -- see KeepSpec -- because a keep
## puts its hall UP a stair over a blind store, which is the one thing the
## house rules forbid.
##
##   storey 0   the store: entered from the bailey, and BLIND. No windows at
##              the foot of a keep; that is the whole point of a keep.
##   storey 1   the hall
##   storey 2   a chamber, on a four-storey keep
##   the top    the lord's chamber, with a bed and a fire of its own
##
## The plan is in the keep's own frame, centred on the origin the way every
## HouseSpec is; `CastleGeometry.keep_aabb` says where that frame sits.
## Empty when the castle has no keep, or when the keep is too small to stack.
static func keep_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.keep:
		return plan
	var box: AABB = CastleGeometry.keep_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var levels: int = clampi(int(box.size.y / KEEP_STOREY_H), 3,
		HouseGeometry.MAX_STOREYS)
	var hs: KeepSpec = _keep_spec(spec, box, levels)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	if minf(floor_rect.size.x, floor_rect.size.y) < MIN_KEEP_SIDE \\
			or floor_rect.size.x * floor_rect.size.y < MIN_KEEP_AREA:
		return plan
	plan.spec = hs

	for level in range(levels):
		plan.rooms.append({"kind": hs.kind_on(level), "rect": floor_rect,
			"storey": level})

	# The way in is at the foot, in the middle of the front wall. A forebuilding
	# would put it on the first floor instead (CAS-004); there is none yet, so
	# the keep is entered at the ground the way a hall house is.
	plan.doors = [{"a": 0, "b": -1,
		"pos": Vector2(floor_rect.get_center().x, floor_rect.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]

	# Blind at the foot, lit above: one window to each long wall of every room
	# people live in.
	for level2 in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level2)):
			continue
		_keep_windows(plan, floor_rect, level2, hs)

	# One stairwell, the same well on every landing, against a wall and out of
	# the line of the door (LAY-005) -- the house planner's own placer.
	for level3 in range(levels - 1):
		HousePlanner._add_stair(plan, level3, level3 + 1, level3, level3 + 1)

	# The fire is the lord's, at the top, on the wall the flue rises up.
	plan.hearth = {"room": levels - 1, "wall": 2}
	HouseFurnisher.furnish(plan, hs)
	return plan


## How much height one storey of a keep wants, and the least a keep may
## measure inside before it is a turret rather than a tower.
const KEEP_STOREY_H := 3.6
const MIN_KEEP_SIDE := 3.2
const MIN_KEEP_AREA := 12.0


## A KeepSpec describing the keep's own box, so every house helper measures it
## the way it measures a house, and the colours come out as castle masonry.
static func _keep_spec(spec: CastleSpec, box: AABB, levels: int) -> KeepSpec:
	var out := KeepSpec.new(spec.seed ^ 0x4B_45_45_50)
	out.style = &"townhouse"
	out.width = box.size.x
	out.length = box.size.z
	out.height = clampf(box.size.y / float(levels), 2.6, 4.5)
	out.storeys = levels
	out.room_count = levels
	out.program = out.room_program(levels)
	out.variant_name = "%s: the keep" % spec.variant_name
	out.wall_color = spec.stone_color
	out.trim_color = spec.trim_color
	out.roof_color = spec.roof_color
	out.floor_color = spec.stone_color.darkened(0.35)
	out.clutter = 0.5
	return out


## A window to each long wall of one storey, clear of the corners.
static func _keep_windows(plan: HousePlan, floor_rect: Rect2, level: int,
		hs: KeepSpec) -> void:
	var room: int = level
	var head: float = minf(HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
		hs.height - 0.2)
	if head - HouseGeometry.WINDOW_SILL < 0.4:
		return
	var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
	for side in [-1.0, 1.0]:
		var pos: Vector2
		var n: Vector2
		if lengthwise:
			pos = Vector2(floor_rect.position.x if side < 0.0 else floor_rect.end.x,
				floor_rect.get_center().y)
			n = Vector2(side, 0.0)
		else:
			pos = Vector2(floor_rect.get_center().x,
				floor_rect.position.y if side < 0.0 else floor_rect.end.y)
			n = Vector2(0.0, side)
		plan.windows.append({"room": room, "pos": pos, "normal": n,
			"width": HouseGeometry.WINDOW_W, "sill": HouseGeometry.WINDOW_SILL,
			"head": head, "storey": level})


'''
s = s.replace(anchor, block + anchor)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
