class_name ChurchFurnisher
extends RefCounted
## What the parish puts in the church once the masons have gone: an altar at
## the east end, pews down the nave either side of a processional aisle,
## candelabra and braziers at the chancel step, sconces and banners on the
## walls, a font by the west door, and a coil of bell rope in the tower.
##
## The same shape as TempleBuilder._dress(): a pure function of the spec that
## returns prop PLACEMENTS in metres and never loads a model. ChurchAssembler
## is the only thing that turns one of these into a node, which is what lets
## the dressing check run headless over hundreds of churches.
##
## Model axes are ChurchGeometry's: +X south, +Y up, +Z east, the altar end.
## A prop faces its own local -Z, so a pew whose congregation looks at the
## altar is yawed by PI.
##
## Every placement carries the plan `rect` it stands on rather than leaving the
## checks to re-derive it from the key and the yaw. DressingCheck walks that
## rectangle; re-deriving it is how a check ends up agreeing with the placer
## about a footprint they both got wrong.

# ---- how much air the dressing leaves around itself, in metres ----
const WALL_CLEAR := 0.3      # off the interior wall face
const AISLE_W := 1.5         # clear width of the central processional aisle
const PEW_PITCH := 1.15      # front of one pew to the front of the next
const PEW_GAP := 0.35        # between the outer end of a pew and the wall
const CHANCEL := 2.6         # clear floor west of the altar
const ENTRY := 2.0           # clear floor inside the west door
const ALTAR_SETBACK := 1.3   # altar face to the east wall

# ---- fire ----
const SCONCE_BAY := 4.0      # metres of nave wall per wall torch
const SCONCE_H := 2.4        # a torch is set at head height and a bit
const BANNER_MIN_H := 3.6    # a nave lower than this has no wall to hang on
const CHANDELIER_MIN_H := 5.0
const CHANDELIER_BAY := 9.0

# ---- what is not worth placing at all ----
const MIN_PEW := 1.3         # a pew shorter than this seats nobody
const MIN_ALTAR_SCALE := 0.62  # PropCatalog.SHRINKABLE says a table stops here
const MAX_PEW_ROWS := 30     # a cathedral, not a stadium

# ---- the pieces, by what they are for ----
const ALTAR := "Table_Large"
const PEW := "Bench"
const CANDELABRUM := "CandleStick_Stand"
const BRAZIER := "Cauldron"
const SCONCE := "Torch_Metal"
const LECTERN := "BookStand"
const FONT := "Cauldron"       # the only stone basin in the pack
const BELL_ROPE := "Rope_2"
const BANNERS := ["Banner_1_Cloth", "Banner_2_Cloth"]
# ---- from the Dungeon Kit, which is where the church furniture proper is ----
const RAIL := "Dungeon_Rail_Straight"
const RAIL_END := "Dungeon_Rail_Divider"
const FLOOR_CANDLES := ["Dungeon_Candles_1", "Dungeon_Candles_2"]
const STATUES := ["Dungeon_Statue_Stag", "Dungeon_Statue_Fox"]
## A statue is four and a half metres of stone: a parish church has no room to
## look up at one.
const STATUE_MIN_H := 6.0


## Everything the church is furnished with, in the order it would be installed.
static func dress(spec: ChurchSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	# Its own stream. Drawing from spec.rng would make build() depend on how
	# many numbers the generator happened to have taken, which is exactly the
	# impurity ChurchGenerator was written to avoid.
	rng.seed = spec.seed * 31 + 7
	_dress_chancel(spec, out)
	_dress_pews(spec, out)
	_dress_walls(spec, out, rng)
	_dress_crossing(spec, out)
	_dress_transept(spec, out)
	_dress_aisles(spec, out)
	_dress_west_end(spec, out)
	return out


## The altar, what stands on it, and the lights that flank it.
static func _dress_chancel(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	var half: float = _interior_half(spec)
	var scale: float = _altar_scale(spec)
	if scale <= 0.0:
		return
	var az: float = altar_z(spec)
	var aw: float = PropCatalog.footprint(ALTAR).x * scale
	_put(out, ALTAR, Vector3(0.0, 0.0, az), 0.0, scale, &"altar")

	# on the altar: a cup on the axis, candles at either end, the book beside
	var top: float = PropCatalog.height(ALTAR) * scale
	_put(out, "Chalice", Vector3(0.0, top, az), 0.0, 1.0, &"vessel")
	for side in [-1.0, 1.0]:
		_put(out, "CandleStick_Triple", Vector3(side * aw * 0.36, top, az), 0.0, 1.0,
			&"light")
	_put(out, "Book_Stack_1", Vector3(aw * 0.18, top, az - 0.22), 0.4, 1.0, &"book")

	# a pair of standing candelabra outside the altar, if the nave is wide
	# enough to hold them clear of its own walls
	var cx: float = aw / 2.0 + 0.75
	if cx + PropCatalog.footprint(CANDELABRUM).x / 2.0 <= half:
		for side2 in [-1.0, 1.0]:
			_put(out, CANDELABRUM, Vector3(side2 * cx, 0.0, az - 0.15), 0.0, 1.0, &"light")

	# the chancel step: the reader on one side, fire on the other
	var step_z: float = az - 1.5
	var off: float = AISLE_W / 2.0 + 0.5
	if off + 0.3 <= half:
		_put(out, LECTERN, Vector3(-off, 0.0, step_z), 0.0, 1.0, &"lectern")
		_put(out, BRAZIER, Vector3(off, 0.0, step_z), 0.0, 1.0, &"light")
	# Standing candles either side of the altar, outboard of the candelabra.
	# The chancel step was the obvious place and the wrong one: the lectern, the
	# brazier and the rail are already in that metre of floor, and beside the
	# altar there is nothing at all.
	for side3 in [-1.0, 1.0]:
		var cand: String = FLOOR_CANDLES[0 if side3 < 0.0 else 1]
		var candle_x: float = cx + PropCatalog.footprint(CANDELABRUM).x / 2.0 \
			+ PropCatalog.footprint(cand).x / 2.0 + 0.25
		if candle_x + PropCatalog.footprint(cand).x / 2.0 <= half:
			_put(out, cand, Vector3(side3 * candle_x, 0.0, az - 0.15), 0.0, 1.0, &"light")
	_dress_rail(spec, out, az - CHANCEL + 0.35)


## The altar rail across the chancel, with the aisle left open in the middle.
##
## Laid in whole sections from the middle outward rather than stretched to fit:
## a rail is joinery, and half a section is not a thing a carpenter makes. The
## last section on each side is dropped if it would run past the wall.
static func _dress_rail(spec: ChurchSpec, out: Array[Dictionary], z: float) -> void:
	var half: float = _interior_half(spec)
	# the section is modelled running along its own Z, so a quarter turn lays it
	# across the church
	var section: float = PropCatalog.footprint(RAIL).y
	if section <= 0.0 or half <= AISLE_W / 2.0 + section:
		return
	var yaw: float = PropCatalog.yaw_facing(Vector2(0.0, -1.0)) + PI / 2.0
	for side in [-1.0, 1.0]:
		var x: float = AISLE_W / 2.0
		var placed := 0
		while x + section <= half and placed < 6:
			_put(out, RAIL, Vector3(side * (x + section / 2.0), 0.0, z), yaw, 1.0,
				&"rail")
			x += section
			placed += 1
		if placed > 0:
			# a post to finish the run at the aisle, where a person walks through
			_put(out, RAIL_END, Vector3(side * (AISLE_W / 2.0 - 0.18), 0.0, z), yaw,
				1.0, &"rail")


## Two blocks of pews either side of the aisle, from the chancel step back
## toward the door, all of them facing the altar.
##
## The rows are pitched rather than counted: a long nave gets more of them, a
## short one fewer, and neither has to know how long the other is. A row that
## would land in the crossing is dropped rather than shortened -- the crossing
## is the transept's own floor, and a pew across it blocks both arms.
static func _dress_pews(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	var half: float = _interior_half(spec)
	var room: float = half - AISLE_W / 2.0 - PEW_GAP
	if room < MIN_PEW:
		return
	var scale: float = minf(room / PropCatalog.footprint(PEW).x, 1.0)
	scale = maxf(scale, PropCatalog.min_scale(PEW))
	var length: float = PropCatalog.footprint(PEW).x * scale
	if length > room + 0.01 or length < MIN_PEW:
		return
	var x: float = AISLE_W / 2.0 + length / 2.0
	# ENTRY is kept clear whether or not there is a narthex: the font stands
	# just inside the west door, and a narthex is another room in front of it
	# rather than licence to pew right up to the threshold.
	var z_east: float = altar_z(spec) - CHANCEL
	var z_west: float = -spec.length / 2.0 + ENTRY
	# Pews only ever run westward from the chancel, so anything still east of
	# the crossing front is standing in the crossing.
	var crossing_west: float = ChurchGeometry.transept_front_z(spec) - 0.4
	var z: float = z_east
	var rows := 0
	while z >= z_west and rows < MAX_PEW_ROWS:
		if not (spec.transept and z > crossing_west):
			for side in [-1.0, 1.0]:
				_put(out, PEW, Vector3(side * x, 0.0, z), PI, scale, &"pew")
			rows += 1
		z -= PEW_PITCH


## Torches down both nave walls, and banners between them.
##
## Spaced by the bay rather than by a count, the same rule the nave windows
## use, so the fire and the glazing march at the same rhythm instead of
## beating against each other.
static func _dress_walls(spec: ChurchSpec, out: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	if spec.height < 2.6:
		return
	var l: float = spec.length
	var x: float = spec.width / 2.0 - 0.12
	var n: int = clampi(int(l / SCONCE_BAY), 1, 12)
	var y: float = minf(SCONCE_H, spec.height * 0.6)
	var banner_y: float = clampf(spec.height * 0.72, 2.8, spec.height - 0.4)
	for i in range(n):
		var z: float = lerpf(-l / 2.0 + 1.2, l / 2.0 - 1.2, (float(i) + 0.5) / float(n))
		for side in [-1.0, 1.0]:
			var inward := Vector2(-side, 0.0)
			_put(out, SCONCE, Vector3(side * x, y, z),
				PropCatalog.mount_yaw(SCONCE, inward), 1.0, &"light")
			if i % 2 == 1 and spec.height >= BANNER_MIN_H:
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(side * x, banner_y, z + PEW_PITCH),
					PropCatalog.mount_yaw(key, inward), 1.0, &"banner")


## Lamps hung over the aisle, where a tall nave has the height for them.
static func _dress_crossing(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	if spec.height < CHANDELIER_MIN_H:
		return
	var z0: float = -spec.length / 2.0 + 2.5
	var z1: float = altar_z(spec) - 2.5
	if z1 <= z0:
		return
	var n: int = clampi(int((z1 - z0) / CHANDELIER_BAY), 1, 4)
	for i in range(n):
		var z: float = lerpf(z0, z1, (float(i) + 0.5) / float(n))
		_put(out, "Chandelier", Vector3(0.0, spec.height - 0.1, z), 0.0, 1.0, &"light")


## The transept arms: fire at the end of each, and a bench to sit on.
static func _dress_transept(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	if not spec.transept:
		return
	var tz: float = ChurchGeometry.transept_center_z(spec)
	var end_x: float = spec.transept_len / 2.0
	if end_x <= spec.width / 2.0 + 1.0:
		return
	for side in [-1.0, 1.0]:
		_put(out, BRAZIER, Vector3(side * (end_x - 1.0), 0.0, tz), 0.0, 1.0, &"light")
		_put(out, CANDELABRUM, Vector3(side * (end_x - 2.1), 0.0, tz - 1.0), 0.0, 1.0,
			&"light")
		# a statue at the end of each arm, where a side altar would stand, but
		# only where there is height to look up at one
		if spec.height >= STATUE_MIN_H:
			var statue: String = STATUES[0 if side < 0.0 else 1]
			_put(out, statue, Vector3(side * (end_x - 3.4), 0.0, tz + 1.2),
				PropCatalog.yaw_facing(Vector2(-side, 0.0)), 1.0, &"statue")
		var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
		_put(out, SCONCE, Vector3(side * (end_x - 0.12), minf(SCONCE_H, spec.height * 0.6),
			tz), yaw, 1.0, &"light")


## The side aisles: light on their outer wall, and the parish chest at the end
## of each -- the aisle is where a church keeps what it owns.
static func _dress_aisles(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	if spec.aisles <= 0:
		return
	var ring: int = spec.aisles - 1
	var zr: Vector2 = ChurchGeometry.aisle_z_range(spec)
	var ah: float = ChurchGeometry.aisle_height(spec, ring)
	var y: float = minf(2.0, ah * 0.6)
	var n: int = clampi(int((zr.y - zr.x) / SCONCE_BAY), 1, 8)
	for side in [-1.0, 1.0]:
		var cx: float = ChurchGeometry.aisle_center_x(spec, side, ring)
		var outer: float = cx + side * (spec.aisle_width / 2.0 - 0.12)
		var inward := Vector2(-side, 0.0)
		var yaw: float = PropCatalog.mount_yaw(SCONCE, inward)
		for i in range(n):
			var z: float = lerpf(zr.x + 1.0, zr.y - 1.0, (float(i) + 0.5) / float(n))
			_put(out, SCONCE, Vector3(outer, y, z), yaw, 1.0, &"light")
		if spec.aisle_width >= 1.6:
			_put(out, "Dungeon_Chest", Vector3(cx, 0.0, zr.x + 1.0),
				PropCatalog.yaw_facing(inward), 1.0, &"store")
			_put(out, "Crate_Wooden", Vector3(cx, 0.0, zr.y - 1.0), 0.0, 1.0, &"store")


## The west end: the font inside the door, and the bell rope in the tower.
static func _dress_west_end(spec: ChurchSpec, out: Array[Dictionary]) -> void:
	var half: float = _interior_half(spec)
	var fx: float = AISLE_W / 2.0 + 0.6
	if fx + PropCatalog.footprint(FONT).x / 2.0 <= half:
		_put(out, FONT, Vector3(-fx, 0.0, -spec.length / 2.0 + 1.1), 0.0, 1.0, &"font")
	if not spec.tower:
		return
	var tz: float = ChurchGeometry.tower_center_z(spec)
	for side in ChurchGeometry.west_tower_sides(spec):
		var cx: float = ChurchGeometry.tower_center_x(spec, side)
		_put(out, BELL_ROPE, Vector3(cx, 0.0, tz), 0.0, 1.0, &"rope")
		if spec.tower_width >= 3.0:
			_put(out, "Crate_Wooden", Vector3(cx + spec.tower_width * 0.28, 0.0,
				tz + spec.tower_width * 0.28), 0.6, 1.0, &"store")


# ------------------------------------------------------------------ shared

## Where the altar stands: on the axis, set back from the east wall. It stays
## INSIDE the nave even when there is an apse -- the apse drum springs from the
## east wall, so an altar pushed into it would stand behind that wall and be
## invisible from the one place anybody looks at it from.
static func altar_z(spec: ChurchSpec) -> float:
	return spec.length / 2.0 - ALTAR_SETBACK


## How far the nave's own walls let a prop stand from the axis.
static func _interior_half(spec: ChurchSpec) -> float:
	return spec.width / 2.0 - WALL_CLEAR


## The altar at the size this nave can take, or 0 if it cannot take one at all.
static func _altar_scale(spec: ChurchSpec) -> float:
	var want: float = PropCatalog.footprint(ALTAR).x
	if want <= 0.0:
		return 0.0
	var scale: float = minf((_interior_half(spec) * 2.0 - 0.6) / want, 1.0)
	return scale if scale >= MIN_ALTAR_SCALE else 0.0


static func _put(out: Array[Dictionary], key: String, pos: Vector3, yaw: float,
		scale: float, kind: StringName) -> void:
	out.append(PropCatalog.placement(key, pos, yaw, scale, kind))
