import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()
cut = s.index('# ------------------------------------------------------------- the interior')
s = s[:cut].rstrip('\n') + '\n'

s += r'''

# ------------------------------------------------------------- the interior

## The great hall as a plan (CAS-010; CRITIQUE 3.2).
##
## The keep, the hall and the chapel are logged masses with nothing inside
## them. This gives the hall an inside, in the representation the whole house
## harness already understands: a single-room HousePlan, so HousePlanCheck can
## judge it, HouseFurnisher can furnish it by the same rules a farmhouse gets,
## HouseNavCheck can walk it, and CastleBuilder can raise it (CAS-013) without
## a second furnishing engine growing up beside the first.
##
## What a great hall IS -- and every one of these is a rule the house harness
## already has a name for:
##
##   the DAIS at the upper end, a step up, the lord end of the room
##   the HIGH TABLE on it, looking down the hall -- plan.focus (INT-002)
##   the LORD BENCH behind the high table, and nobody in front of it
##   the TRESTLE ROWS down the length, benches drawn up to them (INT-001)
##   the HEARTH on a long wall, which the flue rises on (LAY-001)
##   the SCREENS PASSAGE inside the door: floor the plan keeps clear, so the
##     way in is not through the middle of dinner
##
## The plan is in the hall OWN frame -- centred on the origin, the way every
## HouseSpec is -- and `hall_aabb` says where that frame sits in the castle.
## Empty when the castle has no hall range, or when the range is too small to
## be a hall rather than a lean-to.
static func hall_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.hall:
		return plan
	var box: AABB = CastleGeometry.hall_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var hs: HouseSpec = _hall_spec(spec, box)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	if minf(floor_rect.size.x, floor_rect.size.y) < MIN_HALL_SIDE \
			or floor_rect.size.x * floor_rect.size.y < MIN_HALL_AREA:
		return plan
	plan.spec = hs
	plan.rooms = [{"kind": &"great_hall", "rect": floor_rect, "storey": 0}]

	# The hall runs along its longer side: the door at the lower end, the dais
	# at the upper. `up` points from the one to the other.
	var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
	var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	_hall_door(plan, floor_rect, up)
	_hall_windows(plan, floor_rect, up, hs)

	# The dais at the upper end: deep enough to stand the high table and the
	# bench behind it on, and never less than the fifth of the hall that makes
	# it read as an end rather than a step in the floor.
	var depth: float = maxf(run * DAIS_SHARE, minf(DAIS_MIN_D, run * 0.4))
	var far: Vector2 = floor_rect.end if lengthwise else floor_rect.end
	var dais := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		dais.position.y = far.y - depth
		dais.size.y = depth
	else:
		dais.position.x = far.x - depth
		dais.size.x = depth
	plan.dais = {"room": 0, "rect": dais, "rise": DAIS_RISE}

	# The screens passage: a strip inside the door that stays floor. A short
	# hall gets a shorter one -- two metres of passage in a six metre hall
	# would be a third of the room -- and it is never less than a way through.
	var screens: float = clampf(run * SCREENS_SHARE, HouseGeometry.PATH_MIN + 0.5,
		SCREENS_MAX)
	var strip := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		strip.size.y = screens
	else:
		strip.size.x = screens
	plan.zones = [{"room": 0, "rect": strip, "why": "screens passage"}]

	# The fire on a long wall, where the flue can rise up the outside face.
	plan.hearth = {"room": 0, "wall": (2 if lengthwise else 0)}
	# And the high table on the dais, looking down the hall at the door.
	plan.focus = {"room": 0, "cat": "table", "pos": dais.get_center(),
		"facing": atan2(up.x, up.y), "faces_door": true}
	HouseFurnisher.furnish(plan, hs)
	return plan


## The narrowest and the smallest a range may be and still be furnished as a
## great hall. Below this it is a lean-to with a roof on, and it gets no plan
## rather than a plan of a hall nobody could hold a feast in.
const MIN_HALL_SIDE := 3.0
const MIN_HALL_AREA := 16.0
## How much of the hall length the dais takes, how deep it is at the least,
## and how far it rises. The rise is a step: WalkGrid.MAX_STEP is 0.6, so a
## person walks up onto it, which is the whole point of a dais.
const DAIS_SHARE := 0.22
const DAIS_MIN_D := 1.9
const DAIS_RISE := 0.4
## And the strip inside the door that stays clear.
const SCREENS_SHARE := 0.18
const SCREENS_MAX := 2.4


## A HouseSpec describing the hall own box, so every house helper --
## `interior_rect`, `room_walls`, `room_floor_rect` -- measures the hall the
## way it measures a room, and the colours come out as the castle masonry
## rather than as a cottage.
static func _hall_spec(spec: CastleSpec, box: AABB) -> HouseSpec:
	var out := HouseSpec.new()
	out.seed = spec.seed
	out.style = &"longhall"
	out.width = box.size.x
	out.length = box.size.z
	out.height = clampf(box.size.y, 2.6, 6.0)
	out.storeys = 1
	out.room_count = 1
	out.program = [&"great_hall"]
	out.variant_name = "%s: the great hall" % spec.variant_name
	out.wall_color = spec.stone_color
	out.trim_color = spec.trim_color
	out.roof_color = spec.roof_color
	out.floor_color = spec.stone_color.darkened(0.35)
	out.rng = RandomNumberGenerator.new()
	out.rng.seed = spec.seed ^ 0x4841_4C4C
	return out


## The way in, at the lower end, in the middle of the end wall.
static func _hall_door(plan: HousePlan, floor_rect: Rect2, up: Vector2) -> void:
	var lengthwise: bool = up.y > 0.5
	var mid: Vector2 = floor_rect.get_center()
	var pos := Vector2(mid.x, floor_rect.position.y) if lengthwise \
		else Vector2(floor_rect.position.x, mid.y)
	plan.doors = [{"a": 0, "b": -1, "pos": pos, "normal": -up,
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": true,
		"storey": 0}]


## Windows down both long walls, evenly spaced and clear of the corners: a
## hall is lit from the sides, because its ends are the dais and the screens.
static func _hall_windows(plan: HousePlan, floor_rect: Rect2, up: Vector2,
		hs: HouseSpec) -> void:
	var lengthwise: bool = up.y > 0.5
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + HouseGeometry.WINDOW_W
	var usable: float = run - margin * 2.0
	if usable <= HouseGeometry.WINDOW_W:
		return
	var count: int = clampi(int(usable / 2.6), 1, 6)
	var head: float = minf(HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
		hs.height - 0.15)
	if head - HouseGeometry.WINDOW_SILL < 0.4:
		return
	for k in range(count):
		var t: float = (float(k) + 0.5) / float(count)
		var along: float = lerpf(floor_rect.position.y + margin,
			floor_rect.end.y - margin, t) if lengthwise \
			else lerpf(floor_rect.position.x + margin, floor_rect.end.x - margin, t)
		for side in [-1.0, 1.0]:
			var pos: Vector2
			var n: Vector2
			if lengthwise:
				pos = Vector2(floor_rect.position.x if side < 0.0 else floor_rect.end.x,
					along)
				n = Vector2(side, 0.0)
			else:
				pos = Vector2(along,
					floor_rect.position.y if side < 0.0 else floor_rect.end.y)
				n = Vector2(0.0, side)
			plan.windows.append({"room": 0, "pos": pos, "normal": n,
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL, "head": head, "storey": 0})
'''

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
