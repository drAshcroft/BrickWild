class_name CastleInteriorPlans
extends RefCounted
## Occupied hall, chapel, keep and ridge-range plans for a castle.

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
## Empty when the castle has no hall range, or when the range is not the size
## of a hall at all -- see MIN_HALL_SIDE and MAX_HALL_SIDE.
static func hall_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.hall:
		return plan
	var box: AABB = CastleGeometry.hall_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var hs: HouseSpec = _hall_spec(spec, box)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	var across: float = minf(floor_rect.size.x, floor_rect.size.y)
	var along: float = maxf(floor_rect.size.x, floor_rect.size.y)
	if across < MIN_HALL_SIDE or across > MAX_HALL_SIDE or along > MAX_HALL_RUN:
		return plan
	if floor_rect.size.x * floor_rect.size.y < MIN_HALL_AREA:
		return plan
	plan.spec = hs
	plan.rooms = [{"kind": &"great_hall", "rect": floor_rect, "storey": 0}]

	# The hall runs along its longer side: the door at the lower end, the dais
	# at the upper. `up` points from the one to the other.
	var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
	var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	_hall_door(plan, floor_rect, up)
	if CastleGeometry.is_enclosed(spec):
		# The west range is backed by the curtain; only its east face sees
		# the bailey. Decide this before furnishing so light and wall fittings
		# use the same openings the stone shell will cut.
		_courtyard_windows(plan, floor_rect, Vector2.RIGHT, hs,
			mini(3, int(box.size.z / CastleBuilder.RANGE_BAY)))
	else:
		_hall_windows(plan, floor_rect, up, hs)
		# A short, broad hall has one bay on the door's own wall: a window in the
		# doorway is two openings in one piece of masonry.
		var clear: Array[Dictionary] = []
		for window in plan.windows:
			var clash := false
			for door in plan.doors:
				if Vector2(door["normal"]).dot(window["normal"]) < 0.99:
					continue
				var tangent := Vector2(-Vector2(window["normal"]).y, Vector2(window["normal"]).x)
				var gap := absf((Vector2(window["pos"]) - Vector2(door["pos"])).dot(tangent))
				if gap < (float(window["width"]) + float(door["width"])) * 0.5 + 0.3:
					clash = true
			if not clash:
				clear.append(window)
		plan.windows = clear

	# The dais at the upper end: deep enough to stand the high table and the
	# bench behind it on, and never less than the fifth of the hall that makes
	# it read as an end rather than a step in the floor.
	var depth: float = maxf(run * DAIS_SHARE, minf(DAIS_MIN_D, run * 0.4))
	var dais := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		dais.position.y = floor_rect.end.y - depth
		dais.size.y = depth
	else:
		dais.position.x = floor_rect.end.x - depth
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
	# And the high table on the dais, looking down the hall at the door. It
	# stands toward the FRONT of the dais rather than in the middle of it,
	# because the lord sits behind it and a bench needs room to be pushed back
	# into -- put the table on the centre line and the bench ends up with its
	# back half a metre inside the end wall, and does not get placed at all.
	#
	# A hall narrower than the high table is long has to stand the table
	# LENGTHWISE, and a table standing lengthwise cannot look down the hall at
	# anything. Ask for the view only where the room can give it: the table
	# across the hall, and a way past it either side.
	var faces: bool = across >= _longest_table() + HouseGeometry.PATH_MIN * 2.0
	plan.focus = {"room": 0, "cat": "table",
		"pos": dais.get_center() - up * (depth * HIGH_TABLE_SET_IN),
		"facing": atan2(up.x, up.y), "faces_door": faces}
	HouseFurnisher.furnish(plan, hs)
	return plan


## What a range has to measure to be furnished as a great hall.
##
## Below the minimum it is a lean-to with a roof on. Above the maximum it is
## not a hall either: a great hall is ONE ROOM under ONE ROOF, spanned by a
## truss, and the widest ever built is Westminster at 20.7 m. A fortress
## range is sixty metres across and a hundred and fifty long, which is a
## courtyard block the massing happens to draw as one mass -- furnishing it
## with a high table and a row of trestles would be a lie about the building,
## and an expensive one: the walk grid alone would be six hundred thousand
## cells.
##
## Either way the range still gets its mass. What it does not get is an
## inside.
const MIN_HALL_SIDE := 3.0
const MIN_HALL_AREA := 16.0
const MAX_HALL_SIDE := 25.0
const MAX_HALL_RUN := 80.0
## How much of the hall length the dais takes, how deep it is at the least,
## and how far it rises. The rise is a step: WalkGrid.MAX_STEP is 0.6, so a
## person walks up onto it, which is the whole point of a dais.
const DAIS_SHARE := 0.22
const DAIS_MIN_D := 1.9
const DAIS_RISE := 0.4
## How far in from the middle of the dais the high table stands, as a fraction
## of the dais depth, to leave the lord somewhere to sit.
const HIGH_TABLE_SET_IN := 0.18
## And the strip inside the door that stays clear.
const SCREENS_SHARE := 0.18
const SCREENS_MAX := 2.4
## A hall is lit by hall windows: tall, wide, and one to a bay. A cottage
## casement (0.95 x 1.05 m) in a room seventy metres long is an arrow slit --
## fifty of them still leave the floor under a twentieth of its area in glass,
## which is what the plan check calls too dark to live in.
const WINDOW_W := 1.4
const WINDOW_SILL := 1.1
const WINDOW_H := 3.4
const WINDOW_PITCH := 3.2


## The chapel as a plan (CAS-014; CRITIQUE 3.2).
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
	# The chapel is the east range: its west face looks into the bailey.
	_courtyard_windows(plan, floor_rect, Vector2.LEFT, hs)

	# The altar stands a pace off the end wall, ON THE CENTRE LINE, looking
	# back down the nave at the door -- which is the whole of what an axis is.
	var mid: Vector2 = floor_rect.get_center()
	var far: Vector2 = mid + up * (along / 2.0 - ALTAR_SET_IN)
	# A nave narrower than the altar is long has to stand it lengthwise, and a
	# table standing lengthwise cannot look down the nave at anything. Ask for
	# the view only where the room can give it -- the same measurement the
	# great hall makes of its high table.
	var faces: bool = across >= _longest_table() + HouseGeometry.PATH_MIN * 2.0
	plan.focus = {"room": 0, "cat": "table",
		"pos": Vector2(mid.x, far.y) if lengthwise else Vector2(far.x, mid.y),
		"facing": atan2(up.x, up.y), "faces_door": faces}

	# The SANCTUARY: the end the altar stands in, and a DAIS rather than a
	# keep-clear zone, because it belongs TO the altar. A chancel step is a
	# dais, `plan.dais` already means "the focus stands here and nothing else
	# does after it" (CAS-010), and a zone would have kept the altar out of
	# its own sanctuary -- which it did, until this said dais.
	#
	# Without it the pews run the length of the nave, their aisle reaches the
	# altar, and the row rule rightly refuses a row whose aisle is occupied:
	# a chapel with an altar and nothing to sit on.
	var sanctuary := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		sanctuary.position.y = floor_rect.end.y - SANCTUARY_DEPTH
		sanctuary.size.y = SANCTUARY_DEPTH
	else:
		sanctuary.position.x = floor_rect.end.x - SANCTUARY_DEPTH
		sanctuary.size.x = SANCTUARY_DEPTH
	plan.dais = {"room": 0, "rect": sanctuary, "rise": CHANCEL_RISE}
	# The processional aisle belongs to the congregation. Reserving actual
	# floor keeps tall candle stands out of the altar sightline as well as
	# leaving enough room to walk between the pews.
	var aisle := floor_rect
	if lengthwise:
		aisle.position.x = mid.x - 0.6
		aisle.size.x = 1.2
		aisle.size.y = sanctuary.position.y - aisle.position.y
	else:
		aisle.position.y = mid.y - 0.6
		aisle.size.y = 1.2
		aisle.size.x = sanctuary.position.x - aisle.position.x
	plan.zones.append({"room": 0, "rect": aisle, "why": "chapel centre aisle"})
	preload("castle_apse_plan.gd").connect_chapel(plan, spec)
	HouseFurnisher.furnish(plan, hs)
	return plan


## What a range has to measure to be furnished as a chapel, and how far off
## the end wall the altar stands.
const MIN_NAVE_SIDE := 2.8
const MIN_NAVE_AREA := 12.0
const MAX_NAVE_RUN := 60.0
const ALTAR_SET_IN := 1.4
## And how much of the nave the sanctuary takes: enough for the altar and for
## the celebrant to get round the front of it.
const SANCTUARY_DEPTH := 3.0
## A chancel step is a step, not a stage.
const CHANCEL_RISE := 0.15


## A HouseSpec describing the chapel's own box, so every house helper measures
## it the way it measures a room.
static func _chapel_spec(spec: CastleSpec, box: AABB) -> HouseSpec:
	var out := HouseSpec.new(spec.seed ^ 0x43_48_50_4C)
	out.exterior_props = false   # the ward is the castle yard; no house yard here
	out.material = &"stone"
	out.plinth_height = 0.0
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
	out.exterior_props = false # inside the castle masonry: no yard, no road edge
	return out


## The keep as a plan (CAS-011; CRITIQUE 3.2).
##
## A keep is the one castle building the house harness already knew how to
## describe: stacked storeys of one room each with a stair against the wall,
## which is `HouseSpec.storeys` and `HousePlanLevels.add_stair` and nothing new.
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
## How much height one storey of a keep wants, and the least a keep may
## measure inside before it is a turret rather than a tower.
const KEEP_STOREY_H := 3.6
const MIN_KEEP_SIDE := 3.2
const MIN_KEEP_AREA := 12.0
## The planner also provides the door and stair for oversized fortress keeps.
## This upper bound covers the largest fixed fortress sweep keep (64.3 m).
const MAX_KEEP_SIDE := 66.0
## Furniture search scales poorly in a room this large. Large keeps retain a
## full access plan and shell, but do not run the house furnishing search.
const MAX_FURNISHED_KEEP_SIDE := 36.0
## How far apart a keep sets its windows along a wall. Wider than the hall
## pitch on purpose: the gap between two of them is where the bed goes.
const KEEP_WINDOW_PITCH := 5.0


## A KeepSpec describing the keep's own box, so every house helper measures it
## the way it measures a house, and the colours come out as castle masonry.
static func _keep_spec(spec: CastleSpec, box: AABB, levels: int) -> KeepSpec:
	var out := KeepSpec.new(spec.seed ^ 0x4B_45_45_50)
	out.material = &"stone"
	out.plinth_height = 0.0
	out.style = &"townhouse"
	out.width = box.size.x
	out.length = box.size.z
	# These storeys are the occupied keep itself; a ceiling-height cap would
	# strand the lord's chamber beneath an unplanned multi-storey attic.
	out.height = box.size.y / float(levels)
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
		hs: KeepSpec, blind_wall := -1) -> void:
	var head: float = minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)
	if head - WINDOW_SILL < 0.4:
		return
	# FEW AND TALL, not many and small. A keep floor is twelve metres across at
	# the least, so one cottage casement to a wall leaves it too dark to live
	# in -- but a ribbon of them along every wall is worse: it still does not
	# glaze the floor, and it leaves nowhere to put a bed that is not under a
	# window. Castle windows, five metres apart, do both jobs at once.
	var default_margin: float = HouseGeometry.DOOR_CORNER_MARGIN + WINDOW_W
	for axis in [0, 1]:
		var margin: float = default_margin
		var run: float = floor_rect.size.x if axis == 0 else floor_rect.size.y
		var usable: float = run - margin * 2.0
		var window_width: float = WINDOW_W
		if usable <= WINDOW_W:
			# A compact fighting tower cannot take a full hall window. Centre a
			# narrow light on the wall while keeping real corner clearance.
			window_width = minf(0.9, run - 2.0 * HouseGeometry.WINDOW_CORNER_MARGIN)
			if window_width < 0.5:
				continue
			margin = (run - window_width) * 0.5
			usable = window_width
		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)
		for k in range(count):
			var t: float = (float(k) + 0.5) / float(count)
			for side in [-1.0, 1.0]:
				# HouseGeometry.room_walls order: front, back, left, right
				var wall: int = (0 if side < 0.0 else 1) if axis == 0 \
					else (2 if side < 0.0 else 3)
				if wall == blind_wall:
					continue
				var pos: Vector2
				var n: Vector2
				if axis == 0:
					pos = Vector2(lerpf(floor_rect.position.x + margin,
							floor_rect.end.x - margin, t),
						floor_rect.position.y if side < 0.0 else floor_rect.end.y)
					n = Vector2(0.0, side)
				else:
					pos = Vector2(
						floor_rect.position.x if side < 0.0 else floor_rect.end.x,
						lerpf(floor_rect.position.y + margin,
							floor_rect.end.y - margin, t))
					n = Vector2(side, 0.0)
				plan.windows.append({"room": level, "pos": pos, "normal": n,
					"width": window_width, "sill": WINDOW_SILL, "head": head,
					"storey": level})


## The longest side of the biggest table the catalogue has, which is how much
## of the hall's width a high table standing across it takes up.
static func _longest_table() -> float:
	var out := 0.0
	for key in PropCatalog.of_category("table"):
		var f: Vector2 = PropCatalog.footprint(key)
		out = maxf(out, maxf(f.x, f.y))
	return out


## A HouseSpec describing the hall own box, so every house helper --
## `interior_rect`, `room_walls`, `room_floor_rect` -- measures the hall the
## way it measures a room, and the colours come out as the castle masonry
## rather than as a cottage.
static func _hall_spec(spec: CastleSpec, box: AABB) -> HouseSpec:
	var out := HouseSpec.new(spec.seed)
	out.exterior_props = false   # the ward is the castle yard; no house yard here
	out.material = &"stone"
	out.plinth_height = 0.0
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
	out.clutter = 0.5
	out.exterior_props = false # inside the castle masonry: no yard, no road edge
	return out


## ------------------------------------------------------------- ridge ranges
##
## A ridge castle is a chain of ranges walking along a spine, each one turned
## to its own segment. Its rooms therefore cannot come from `hall_aabb`, which
## is an axis-aligned box somewhere else entirely -- feeding that plan to a
## rotated range puts every floor, door and prop outside its host.
##
## Each range is planned in ITS OWN FRAME: local X runs along the segment,
## local Z across it, and CastleInteriors.record carries the segment's yaw so
## the same numbers land on the emitted masonry. Occupied floors follow the
## emitted range storey bands; CastleInteriors.emit closes the remaining wall
## height with continuous perimeter masonry.

## A range narrower or shorter than this is masonry, not a room.
const MIN_RANGE_SIDE := 3.0
const MIN_RANGE_RUN := 5.0
## One rotated range of a ridge castle, in its own frame. `neighbours` is the
## count of ranges this one touches (its segment's two ends), used to place the
## doors that connect the chain.
static func ridge_range_plan(spec: CastleSpec, seg: Dictionary,
		links: Array[int], opts := {}) -> HousePlan:
	var plan := HousePlan.new()
	var run: float = float(seg["length"])
	var across: float = float(seg["width"])
	if run < MIN_RANGE_RUN or across < MIN_RANGE_SIDE:
		return plan
	var box := AABB(Vector3(-run * 0.5, 0.0, -across * 0.5),
		Vector3(run, float(seg["height"]), across))
	var hs: HouseSpec = _hall_spec(spec, box)
	# `opts` lets a manor wing reuse this planner: `levels`, and how much of each
	# end ("buried_lo"/"buried_hi", local x) is masonry shared with a neighbour.
	var levels: int = int(opts.get("levels", CastleGeometry.ridge_storeys(spec)))
	var band_height: float = float(seg["height"]) / float(levels)
	hs.height = band_height
	hs.storeys = levels
	var is_hall: bool = String(seg["name"]) == "hall"
	hs.variant_name = "%s: %s" % [spec.variant_name,
		"the great hall" if is_hall else "a range"]
	hs.program = [&"great_hall" if is_hall else StringName(opts.get("kind", &"lords_chamber"))]
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	var min_side: float = float(opts.get("min_side", MIN_RANGE_SIDE)) - 0.001
	if floor_rect.size.x < MIN_RANGE_RUN or floor_rect.size.y < min_side:
		return plan
	var kind: StringName = hs.program[0]
	if floor_rect.size.x * floor_rect.size.y < float(HouseGeometry.MIN_AREA[kind]):
		return plan

	# A long range is BAYS, not one enormous room. A 75 m hall 14 m wide is a
	# corridor by every rule the house harness has, and rejecting it outright
	# left the biggest ridge castles hollow. Divide it until each bay is a
	# room-shaped room, and put a door through every partition.
	var bays: int = maxi(int(ceil(floor_rect.size.x
		/ (floor_rect.size.y * HouseGeometry.aspect_max(kind)))), 1)
	var bay_run: float = floor_rect.size.x / float(bays)
	if bay_run < MIN_RANGE_RUN or bay_run * floor_rect.size.y \
			< float(HouseGeometry.MIN_AREA[kind]):
		return plan
	plan.spec = hs
	plan.rooms = []
	plan.doors = []
	plan.windows = []
	hs.program = []
	for level in range(levels):
		for i in range(bays):
			# The entrance-level principal bay remains the great hall. Above it,
			# private rooms must sit at the end of a route, never between a stair
			# and another occupied floor or bay.
			var bay_kind: StringName = kind
			if is_hall and level == 0 and i == 0:
				bay_kind = &"great_hall"
			elif i == 0 and not (bays == 1 and level == levels - 1):
				# This room leads to a later bay, or the stair above it. It is a
				# public circulation room. Only a one-bay top floor is terminal.
				bay_kind = &"parlour"
			elif i > 0:
				bay_kind = &"guest_room" if i == bays - 1 else &"parlour"
			if bay_run * floor_rect.size.y < float(HouseGeometry.MIN_AREA[bay_kind]) \
					or minf(bay_run, floor_rect.size.y) < float(HouseGeometry.MIN_SIDE[bay_kind]):
				bay_kind = kind
			var room_index := level * bays + i
			var room_rect := Rect2(Vector2(floor_rect.position.x + bay_run * float(i),
				floor_rect.position.y), Vector2(bay_run, floor_rect.size.y))
			plan.rooms.append({"kind": bay_kind, "storey": level, "rect": room_rect})
			hs.program.append(bay_kind)
			var window_start := plan.windows.size()
			_hall_windows(plan, room_rect, Vector2(1, 0), hs, room_index,
				band_height - 0.2)
			for wi in range(window_start, plan.windows.size()):
				plan.windows[wi]["storey"] = level
		for i in range(1, bays):
			var left_room := level * bays + i - 1
			var right_room := level * bays + i
			plan.doors.append({"a": left_room, "b": right_room,
				"pos": Vector2(floor_rect.position.x + bay_run * float(i),
					floor_rect.get_center().y),
				"normal": Vector2(1, 0), "width": HouseGeometry.INNER_DOOR_W,
				"exterior": false, "front": false, "storey": level})

	# The way in is on a LONG face, because a range's ends are where it meets
	# its neighbours. `up` is across the range, so the door faces out of it.
	_hall_door(plan, plan.rooms[0]["rect"], Vector2(0, 1))

	# And the doors that make the chain a building rather than a row of sheds:
	# one in each end the segment shares with another range.
	for end_v in links:
		# This is an aperture in the end wall. Keep it on the local room edge;
		# the castle transform then carries that wall plane onto the shared tower.
		var x: float = floor_rect.position.x if end_v < 0 else floor_rect.end.x
		# When both ends connect, offset the openings to opposite sides of the
		# range. The passage then turns inside the range instead of reading as a
		# straight corridor through the whole building.
		var side_offset: float = minf(floor_rect.size.y * 0.25,
			HouseGeometry.INNER_DOOR_W * 1.25)
		var door_y: float = floor_rect.get_center().y + float(end_v) * side_offset
		plan.doors.append({"a": 0 if end_v < 0 else bays - 1, "b": -1,
			"pos": Vector2(x, door_y),
			"normal": Vector2(float(end_v), 0.0),
			"width": HouseGeometry.INNER_DOOR_W, "exterior": true,
			"front": false, "storey": 0})
	# A real stair connects each occupied range floor. Room indices differ from
	# storey indices when the range has more than one bay.
	var previous_stair := Rect2()
	for level in range(levels - 1):
		var lower_room := level * bays
		var upper_room := (level + 1) * bays
		var stair := _ridge_add_stair(plan, level, level + 1,
			lower_room, upper_room, previous_stair)
		if not stair.is_empty():
			plan.stairs.append(stair)
			previous_stair = stair.rect
	# The front door belongs on the exposed part of its bay's long facade. A
	# short first bay can put its midpoint inside the solid tower dive, where the
	# buried-opening pass below correctly removes it. Slide along the SAME wall
	# to the nearest point clear of both the room corners and that dive.
	var buried: float = floor_rect.size.x * 0.5 \
		- (float(seg.get("roof_length", run)) * 0.5 - CastleGeometry.tower_half(spec, 0))
	var buried_lo: float = float(opts.get("buried_lo", buried))
	var buried_hi: float = float(opts.get("buried_hi", buried))
	var any_buried: bool = buried_lo > 0.0 or buried_hi > 0.0
	if any_buried:
		_relocate_range_front_door(plan, floor_rect, maxf(buried_lo, 0.0), maxf(buried_hi, 0.0))
	# A range's door is on a LONG wall, and so are its windows: unlike a hall,
	# whose door is on an end wall and can never meet one. Drop any window that
	# lands on top of a door. Two openings in one piece of wall leave the
	# builder cutting one hole and dressing two, which reads as a wall standing
	# across the glazing.
	var clear_windows: Array[Dictionary] = []
	for wdw in plan.windows:
		var wp: Vector2 = wdw["pos"]
		var clash := false
		for d in plan.doors:
			if HousePlan.record_storey(d) != HousePlan.record_storey(wdw):
				continue
			var dp: Vector2 = d["pos"]
			if (wdw["normal"] as Vector2).dot(d["normal"]) < 0.5:
				continue          # different wall
			var gap: float = (wp - dp).length()
			if gap < (float(d["width"]) + HouseGeometry.WINDOW_W) * 0.5 + 0.6:
				clash = true
		if not clash:
			clear_windows.append(wdw)
	plan.windows = clear_windows

	# The ends of a range are INSIDE ITS TOWERS. ridge_ranges extends every
	# segment by RIDGE_DIVE x tower_half at both ends so the masonry buries
	# itself in the vertex towers, and a tower is solid: an opening placed out
	# there is a window with a tower behind it. Drop the ones that land in the
	# dive rather than pretend the wall is free.
	if any_buried:
		var exposed_lo: float = -floor_rect.size.x * 0.5 + maxf(buried_lo, 0.0)
		var exposed_hi: float = floor_rect.size.x * 0.5 - maxf(buried_hi, 0.0)
		var keep_windows: Array[Dictionary] = []
		for wdw in plan.windows:
			var wx: float = float((wdw["pos"] as Vector2).x)
			if wx >= exposed_lo and wx <= exposed_hi:
				keep_windows.append(wdw)
		plan.windows = keep_windows
		var keep_doors: Array[Dictionary] = []
		for d in plan.doors:
			# A link door belongs in the dive on purpose: it is how one range
			# reaches the next THROUGH the tower they share.
			var dx: float = float((d["pos"] as Vector2).x)
			if absf(float(d["normal"].x)) > 0.5 or (dx >= exposed_lo and dx <= exposed_hi):
				keep_doors.append(d)
		plan.doors = keep_doors

	# A block that leans on another building has no light on that wall (local
	# +Z), and a short one has no room beside its door: say where the light
	# comes from now, before the furnisher has stood a bed under it.
	if bool(opts.get("lean", false)):
		var exposed: Array[Dictionary] = []
		for window in plan.windows:
			if Vector2(window["normal"]).y <= 0.0:
				exposed.append(window)
		plan.windows = exposed
	if bool(opts.get("end_windows", false)):
		_ridge_end_windows(plan)

	# The selected first room always owns the range hearth and its flue. Later
	# bays are guest rooms and do not claim a second chimney the range cannot
	# describe.
	plan.hearth = {"room": 0, "wall": 2}
	hs.room_count = plan.rooms.size()
	HouseFurnisher.furnish(plan, hs)
	return plan


## A habitable room without a window gets a light in each end wall.
static func _ridge_end_windows(plan: HousePlan) -> void:
	for index in range(plan.rooms.size()):
		var kind: StringName = plan.rooms[index].kind
		if kind not in HouseGeometry.HABITABLE:
			continue
		var has_light := false
		for window in plan.windows:
			if int(window.get("room", -1)) == index:
				has_light = true
		if has_light:
			continue
		var rect: Rect2 = HouseGeometry.room_floor_rect(plan, index)
		var storey := plan.storey_of_room(index)
		var head := minf(2.3, plan.spec.height - 0.2)
		for end in [-1.0, 1.0]:
			var x := rect.position.x if end < 0.0 else rect.end.x
			plan.windows.append({"room": index, "storey": storey,
				"pos": Vector2(x, rect.get_center().y), "normal": Vector2(end, 0.0),
				"width": 1.0, "sill": 1.1, "head": head})


static func _ridge_add_stair(plan: HousePlan, lower_storey: int,
		upper_storey: int, lower_room: int, upper_room: int,
		avoid: Rect2) -> Dictionary:
	var floor_rect := HouseGeometry.room_floor_rect(plan, upper_room)
	var run := minf(2.4, maxf(HouseGeometry.PATH_MIN,
		maxf(floor_rect.size.x, floor_rect.size.y) - 0.3))
	var width := minf(1.0, maxf(HouseGeometry.PATH_MIN,
		minf(floor_rect.size.x, floor_rect.size.y) - 0.3))
	var entrance := plan.entrance()
	if entrance < 0:
		return {}
	var front := Vector2(plan.doors[entrance]["pos"])
	var walls := HouseGeometry.room_walls(plan, upper_room)
	walls.append_array(HouseGeometry.room_walls(plan, lower_room))
	var best := Rect2()
	var best_score := -INF
	for size in [Vector2(run, width), Vector2(width, run)]:
		for wall in walls:
			var normal: Vector2 = wall.normal
			var support: float = (absf(normal.x) * size.x + absf(normal.y) * size.y) * 0.5
			var length: float = Vector2(wall.from).distance_to(wall.to)
			var samples := maxi(int(length / 0.2), 1)
			for sample in range(samples + 1):
				var centre: Vector2 = Vector2(wall.from).lerp(wall.to,
					float(sample) / float(samples)) + normal * support
				var rect := Rect2(centre - size * 0.5, size)
				if not _ridge_stair_fits(plan, lower_room, rect) \
						or not _ridge_stair_fits(plan, upper_room, rect):
					continue
				if avoid.has_area() and rect.intersects(avoid, true):
					continue
				var blocked := false
				for door in plan.doors:
					if HousePlan.record_storey(door) != lower_storey:
						continue
					if int(door.get("a", -1)) != lower_room \
							and int(door.get("b", -1)) != lower_room:
						continue
					if _ridge_rects_overlap(rect, HouseGeometry.door_clear_rect(door, -1.0)):
						blocked = true
						break
				if blocked:
					continue
				var score := centre.distance_to(front)
				if avoid.has_area():
					score += centre.distance_to(avoid.get_center())
				# The foot of a stair must not look straight back at the front
				# door: a penalty, so a cramped room can still place one.
				var entry: Dictionary = plan.doors[entrance]
				if int(entry["a"]) == lower_room and _ridge_rects_overlap(rect,
						HousePlanLevels.door_line(plan, lower_room, entry)):
					score -= 1000.0
				if score > best_score:
					best = rect
					best_score = score
	if not best.has_area():
		return {}
	var centre := best.get_center()
	return {"a": lower_room, "b": upper_room,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": best, "lower_rect": best, "upper_rect": best,
		"width": width, "run": run}


static func _ridge_stair_fits(plan: HousePlan, room: int, rect: Rect2) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(HouseGeometry.room_floor_poly(plan, room), point, 0.001):
			return false
	return true


static func _ridge_rects_overlap(a: Rect2, b: Rect2) -> bool:
	var overlap := a.intersection(b)
	return overlap.size.x > 0.02 and overlap.size.y > 0.02


static func _relocate_range_front_door(plan: HousePlan, floor_rect: Rect2,
		buried_lo: float, buried_hi: float) -> void:
	var half_run: float = floor_rect.size.x * 0.5
	var exposed_lo: float = -half_run + buried_lo
	var exposed_hi: float = half_run - buried_hi
	for door in plan.doors:
		if not bool(door.get("front", false)):
			continue
		var room: int = int(door.get("a", -1))
		if room < 0 or room >= plan.rooms.size():
			return
		var rect: Rect2 = plan.rooms[room]["rect"]
		var margin: float = HouseGeometry.DOOR_CORNER_MARGIN \
			+ float(door["width"]) * 0.5
		var lo: float = maxf(rect.position.x + margin, exposed_lo + margin)
		var hi: float = minf(rect.end.x - margin, exposed_hi - margin)
		if lo <= hi:
			var pos: Vector2 = door["pos"]
			pos.x = clampf(pos.x, lo, hi)
			door["pos"] = pos
		return


## The way in, at the lower end, in the middle of the end wall.
static func _hall_door(plan: HousePlan, floor_rect: Rect2, up: Vector2) -> void:
	var lengthwise: bool = up.y > 0.5
	var mid: Vector2 = floor_rect.get_center()
	var pos := Vector2(mid.x, floor_rect.position.y) if lengthwise \
		else Vector2(floor_rect.position.x, mid.y)
	# append, not assign: a multi-bay range has already recorded the doors
	# through its own partitions and this is one more way in, not the only one.
	plan.doors.append({"a": 0, "b": -1, "pos": pos, "normal": -up,
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": true,
		"storey": 0})


## Windows down both long walls, evenly spaced and clear of the corners: a
## hall is lit from the sides, because its ends are the dais and the screens.
static func _hall_windows(plan: HousePlan, floor_rect: Rect2, up: Vector2,
		hs: HouseSpec, room := 0, max_head: float = INF) -> void:
	var lengthwise: bool = up.y > 0.5
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	# A reduced range may have a valid room but no full-sized window bay
	# between its corners. Fit one narrower opening to the available wall.
	var width: float = minf(WINDOW_W,
		maxf(run - 2.0 * HouseGeometry.DOOR_CORNER_MARGIN, 0.0))
	if width < 0.45:
		return
	var margin: float = minf(HouseGeometry.DOOR_CORNER_MARGIN + width,
		maxf((run - width) * 0.5, 0.0))
	var usable: float = run - margin * 2.0
	var count: int = maxi(int(usable / WINDOW_PITCH), 1)
	var head: float = minf(minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2), max_head)
	var sill: float = minf(WINDOW_SILL, head - 0.4)
	if head - sill < 0.4:
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
			plan.windows.append({"room": room, "pos": pos, "normal": n,
				"width": width, "sill": sill, "head": head,
				"storey": 0})


## Enclosed ranges borrow one wall from the curtain. Their windows belong on
## the opposite X face even when a short, broad room runs across the range.
## Window bays share the available wall; a door on that face splits the run.
static func _courtyard_windows(plan: HousePlan, floor_rect: Rect2, normal: Vector2,
		hs: HouseSpec, minimum := 1) -> void:
	var head := minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)
	if head - WINDOW_SILL < 0.4:
		return
	var margin := HouseGeometry.DOOR_CORNER_MARGIN
	var gap := 0.2
	var spans: Array[Vector2] = [Vector2(floor_rect.position.y + margin,
		floor_rect.end.y - margin)]
	for door in plan.doors:
		if not door.exterior or Vector2(door.normal).dot(normal) < 0.9:
			continue
		var centre: float = door.pos.y
		var half := float(door.width) * 0.5 + gap
		var pieces: Array[Vector2] = []
		for span in spans:
			if centre + half <= span.x or centre - half >= span.y:
				pieces.append(span)
			else:
				if centre - half > span.x:
					pieces.append(Vector2(span.x, centre - half))
				if centre + half < span.y:
					pieces.append(Vector2(centre + half, span.y))
		spans = pieces
	var wall_x := floor_rect.end.x if normal.x > 0.0 else floor_rect.position.x
	for span in spans:
		var run := span.y - span.x
		# Keep a masonry jamb at both ends of each span. A window that exactly
		# fills the remnant beside a door would erase the stone pier that carries
		# its lintel.
		var width: float = minf(WINDOW_W, run - 2.0 * gap)
		if width < 0.45:
			continue
		var capacity := maxi(int((run + gap) / (width + gap)), 1)
		var count := mini(maxi(int(run / WINDOW_PITCH), minimum), capacity)
		for k in count:
			var along := lerpf(span.x, span.y, (float(k) + 0.5) / float(count))
			plan.windows.append({"room": 0, "pos": Vector2(wall_x, along),
				"normal": normal, "width": width, "sill": WINDOW_SILL,
				"head": head, "storey": 0})
