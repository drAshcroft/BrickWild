class_name CastleFurnisher
extends RefCounted
## What a garrison puts in a castle: a high table on the dais and trestles down
## the great hall, an altar in the chapel, chests and arms in the keep, the
## working clutter of a courtyard -- carts, barrels, an anvil, a training dummy
## -- and fire on the wall walk, the tower tops and either side of the gate.
##
## Same contract as ChurchFurnisher and TempleBuilder._dress(): a pure function
## of the spec that returns placements in metres and never loads a model.
## CastleAssembler is the only thing that turns one into a node, which is what
## lets the dressing check sweep hundreds of castles headless.
##
## Model axes are CastleGeometry's: +X east, +Y up, +Z north (the back). The
## gate is always at -Z, so the courtyard clutter has to keep off that axis or
## it is standing in the only way in.
##
## A prop faces its own local -Z. `_yaw_facing` turns a direction into the yaw
## that points a prop down it; `_mount_yaw` does the same for the wall pieces,
## which carry a half-turn face correction in the catalogue.

# ---- clearances, in metres ----
const INSET := 0.4          # off the inside face of a range wall
const TABLE_PITCH := 2.8    # one row of trestles to the next
const BENCH_OFF := 1.0      # bench centre from the table it serves
const GATE_CLEAR := 3.5     # width of the way in that stays empty
const YARD_STEP := 2.6      # spacing of the courtyard standing places
const YARD_MARGIN := 0.35   # air between two pieces of yard clutter

# ---- fire ----
const SCONCE_H := 2.4
const SCONCE_BAY := 4.5
const WALL_FIRE_BAY := 9.0  # metres of wall walk per brazier
const MAX_WALL_FIRES := 24
const BANNER_MIN_H := 3.6
const CHANDELIER_MIN_H := 5.0

## What the dressing may treat as the ceiling of the room it is dressing.
##
## A range is logged as one mass from the ground to its eaves, and a keep is
## twenty metres of it. The dressing furnishes the GROUND FLOOR, so a banner
## hung at three quarters of the height of a keep would fly four storeys above
## the only floor there is anything standing on.
const ROOM_CEILING := 5.5

# ---- what is not worth dressing at all ----
const MIN_ROOM := 2.4       # a range narrower than this holds nothing
const MAX_TRESTLES := 8

# ---- the pieces ----
const HIGH_TABLE := "Table_Large"
const TRESTLE := "Table_Large"
const BENCH := "Bench"
const BRAZIER := "Cauldron"
const SCONCE := "Torch_Metal"
const CANDELABRUM := "CandleStick_Stand"
const BANNERS := ["Banner_1", "Banner_2", "Banner_1_Cloth", "Banner_2_Cloth"]
# ---- from the Dungeon Kit ----
## The big flags, for the curtain and the gatehouse: outdoor heraldry, where the
## MegaKit cloth would be lost against a fifteen metre wall.
const WAR_BANNERS := ["Dungeon_Flag_Wall", "Dungeon_Flag_Wall2"]
const MONUMENT := ["Dungeon_Statue_Stag", "Dungeon_Statue_Fox"]
const TREASURE := "Dungeon_Chest_Gold"
const LIBRARY := "Dungeon_Bookcase_Full"

## The working yard, in the order a castle would fill it: the cart and the
## smithy first, because they are what a bailey is FOR, then the stores.
const YARD_PROGRAMME := [
	{"key": "Stall_Cart_Empty", "kind": &"cart"},
	{"key": "Anvil", "kind": &"forge"},
	{"key": "Cauldron", "kind": &"light"},
	{"key": "Barrel_Holder", "kind": &"store"},
	{"key": "Dummy", "kind": &"yard"},
	{"key": "WeaponStand", "kind": &"arms"},
	{"key": "Barrel", "kind": &"store"},
	{"key": "Crate_Wooden", "kind": &"store"},
	{"key": "FarmCrate_Apple", "kind": &"store"},
	{"key": "Bag", "kind": &"store"},
	{"key": "Barrel_Apples", "kind": &"store"},
	{"key": "Crate_Metal", "kind": &"store"},
	{"key": "Rope_3", "kind": &"yard"},
	{"key": "Dungeon_Cart", "kind": &"cart"},
	{"key": "Dungeon_Pot1", "kind": &"urn"},
	{"key": "Bucket_Wooden_1", "kind": &"yard"},
	{"key": "Dungeon_Pot3", "kind": &"urn"},
	{"key": "Dungeon_Bricks", "kind": &"rubble"},
	{"key": "FarmCrate_Empty", "kind": &"store"},
	{"key": "Chest_Wood", "kind": &"store"},
	{"key": "Dungeon_Pot2_Broken", "kind": &"urn"},
]


## Everything the castle is furnished with.
static func dress(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	# Its own stream, for the same reason ChurchFurnisher has one: build() must
	# not depend on how far the generator happened to advance spec.rng.
	rng.seed = spec.seed * 31 + 11

	if CastleGeometry.is_tower_house(spec):
		_dress_hall(_room_of(CastleGeometry.tower_storey_aabb(spec, 0)), out, rng)
		return out
	if CastleGeometry.is_ridge(spec):
		for seg in CastleGeometry.ridge_ranges(spec):
			var room: Dictionary = _room_of_segment(seg)
			if String(seg.get("name", "")) == "hall":
				_dress_hall(room, out, rng)
			else:
				_dress_chamber(room, out, rng)
		return out
	if CastleGeometry.is_sky(spec):
		return out # open turret-islands have no conventional ground-floor rooms
	if not CastleGeometry.is_enclosed(spec):
		# a house or a manor: the range IS the building
		_dress_hall(_room_of(CastleGeometry.house_range_aabb(spec)), out, rng)
		# CastleGeometry.wing_sides() answers for any tier with wings > 0, but a
		# HOUSE builds an annexe and no wings at all -- furnishing its wings put
		# a stool through the hall table, in a room the builder never emitted.
		if spec.tier == &"house":
			_dress_chamber(_room_of(CastleGeometry.annexe_aabb(spec)), out, rng)
		else:
			for side in CastleGeometry.wing_sides(spec):
				_dress_chamber(_room_of(CastleGeometry.manor_wing_aabb(spec, side)),
					out, rng)
		return out

	_dress_hall(_room_of(CastleGeometry.hall_aabb(spec)), out, rng)
	_dress_chapel(spec, out)
	_dress_chamber(_room_of(CastleGeometry.keep_aabb(spec)), out, rng)
	_dress_yard(spec, out)
	_dress_defences(spec, out)
	return out


# --------------------------------------------------------------- great hall

## The hall: a high table across the dais end, trestles and benches down the
## length, fire on the wall, and banners over the whole of it.
##
## The dais end is the +along end, which for every range in this generator is
## the end furthest from the gate -- and that distance is what a lord's end IS:
## the length of the room between him and whoever has just walked in.
static func _dress_hall(room: Dictionary, out: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	if not _usable(room):
		return
	var c: Vector2 = room["c"]
	var along: Vector2 = room["along"]
	var across: Vector2 = room["across"]
	var half_len: float = room["half_len"]
	var half_wide: float = room["half_wide"]

	# the high table, across the dais end, looking down the hall
	var scale: float = _fit_scale(HIGH_TABLE, half_wide * 2.0 - 0.6)
	if scale > 0.0:
		var dais: Vector2 = c + along * (half_len - 1.4)
		var yaw: float = _yaw_facing(-along)
		_put(out, HIGH_TABLE, _v3(dais), yaw, scale, &"table")
		# what is set on it stands at the height the catalogue measured its top
		var top: float = PropCatalog.height(HIGH_TABLE) * scale
		_on(out, "Chalice", dais, top, yaw, &"vessel")
		_on(out, "Table_Plate", dais + across * 0.7, top, yaw, &"vessel")
		_on(out, "CandleStick_Triple", dais - across * 0.8, top, yaw, &"light")
		for side in [-1.0, 1.0]:
			_put(out, "Chair_1", _v3(dais + along * 0.9 + across * side * 0.7), yaw,
				1.0, &"seat")

	# Trestles across the hall in rows, benches fore and aft of each. The rows
	# march down the length at TABLE_PITCH, so the boards have to run ACROSS
	# it -- laid the other way, a 2.85 m trestle would overrun the 2.8 m
	# between one row and the next.
	var t_scale: float = _fit_scale(TRESTLE, half_wide * 2.0 - 0.6)
	var b_scale: float = _fit_scale(BENCH, half_wide * 2.0 - 0.6)
	var n: int = clampi(int((half_len * 2.0 - 4.0) / TABLE_PITCH), 0, MAX_TRESTLES)
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var p: Vector2 = c + along * lerpf(half_len - 3.4, -half_len + 1.2, t)
		if t_scale > 0.0:
			_put(out, TRESTLE, _v3(p), _yaw_facing(-along), t_scale, &"table")
		if b_scale > 0.0:
			for side2 in [-1.0, 1.0]:
				_put(out, BENCH, _v3(p + along * side2 * BENCH_OFF),
					_yaw_facing(-along * side2), b_scale, &"bench")

	# the hearth against a long wall, and the stores in the low corners
	_put(out, BRAZIER, _v3(c + across * (half_wide - 0.5) + along * (half_len - 3.0)),
		0.0, 1.0, &"light")
	for side3 in [-1.0, 1.0]:
		_put(out, "Barrel", _v3(c - along * (half_len - 0.5)
			+ across * side3 * (half_wide - 0.5)), 0.0, 1.0, &"store")

	_dress_room_walls(room, out, rng)


# ---------------------------------------------------- keep, wings, lodgings

## A chamber: what a keep floor, a manor wing or a lodging range holds. A table
## to work at, a chest for what is worth locking up, arms on a stand, light.
static func _dress_chamber(room: Dictionary, out: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	if not _usable(room):
		return
	var c: Vector2 = room["c"]
	var along: Vector2 = room["along"]
	var across: Vector2 = room["across"]
	var half_len: float = room["half_len"]
	var half_wide: float = room["half_wide"]

	var scale: float = _fit_scale(HIGH_TABLE, half_wide * 2.0 - 0.8)
	if scale > 0.0:
		_put(out, HIGH_TABLE, _v3(c), _yaw_facing(-along), scale, &"table")
		_on(out, "Book_Stack_2", c, PropCatalog.height(HIGH_TABLE) * scale, 0.0, &"book")
		for side in [-1.0, 1.0]:
			if half_len > BENCH_OFF + 0.8:
				_put(out, "Stool", _v3(c + along * side * BENCH_OFF),
					_yaw_facing(-along * side), 1.0, &"seat")
	var back: Vector2 = c + along * (half_len - 0.6)
	_put(out, TREASURE, _v3(back - across * (half_wide - 0.9)),
		_yaw_facing(-along), 1.0, &"store")
	# A tall bookcase against the long wall, where the room is tall enough to
	# stand two and a half metres of it up and long enough to stand it clear of
	# the table. Its own long axis runs ALONG the room, so how far down the room
	# it has to go is its half length plus the table half depth -- measured, not
	# guessed: at a guessed 1.2 m it stood through the table in every manor.
	var case_half: float = PropCatalog.footprint(LIBRARY).x / 2.0
	var table_half: float = PropCatalog.footprint(HIGH_TABLE).y * scale / 2.0
	var case_off: float = table_half + case_half + 0.35
	if float(room["ceiling"]) >= 3.2 and half_len > case_off + case_half + 0.8:
		_put(out, LIBRARY, _v3(c + across * (half_wide - 0.4) - along * case_off),
			_yaw_facing(-across), 1.0, &"store")
	_put(out, "WeaponStand", _v3(back + across * (half_wide - 0.9)),
		_yaw_facing(-along), 1.0, &"arms")
	_put(out, "Barrel", _v3(c - along * (half_len - 0.5) + across * (half_wide - 0.5)),
		0.0, 1.0, &"store")
	_dress_room_walls(room, out, rng)


## Torches on both long walls of a room, banners between them, and a lamp hung
## over the middle where the room is tall enough to carry one.
static func _dress_room_walls(room: Dictionary, out: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var c: Vector2 = room["c"]
	var along: Vector2 = room["along"]
	var across: Vector2 = room["across"]
	var half_len: float = room["half_len"]
	var half_wide: float = room["half_wide"]
	var ceiling: float = room["ceiling"]
	var y: float = minf(SCONCE_H, ceiling * 0.6)
	if y < 1.4:
		return
	var n: int = clampi(int(half_len * 2.0 / SCONCE_BAY), 1, 8)
	var banner_y: float = clampf(ceiling * 0.72, 2.6, ceiling - 0.4)
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var p: Vector2 = c + along * lerpf(half_len - 0.8, -half_len + 0.8, t)
		for side in [-1.0, 1.0]:
			var at: Vector2 = p + across * side * (half_wide - 0.12)
			var inward: Vector2 = -across * side
			_put(out, SCONCE, Vector3(at.x, y, at.y),
				_mount_yaw(SCONCE, inward), 1.0, &"light")
			if i % 2 == 0 and ceiling >= BANNER_MIN_H:
				var b: Vector2 = at + along * 1.0
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(b.x, banner_y, b.y),
					_mount_yaw(key, inward), 1.0, &"banner")
	if ceiling >= CHANDELIER_MIN_H:
		var lamps: int = clampi(int(half_len * 2.0 / 8.0), 1, 3)
		for i2 in range(lamps):
			var t2: float = (float(i2) + 0.5) / float(lamps)
			var p2: Vector2 = c + along * lerpf(half_len - 2.0, -half_len + 2.0, t2)
			_put(out, "Chandelier", Vector3(p2.x, ceiling - 0.1, p2.y), 0.0, 1.0,
				&"light")


# ------------------------------------------------------------------- chapel

## The chapel: an altar at the apse end -- which on a castle is the end toward
## the GATE, since the other end runs back to meet the keep -- with benches
## facing it and a candelabrum either side.
##
## The chapel range is always axis-aligned (CastleGeometry.chapel_aabb builds
## it against the ward wall), so this one lays out in world axes rather than in
## a room frame: the altar looks up +Z, the way a person walking in from the
## gate is already looking.
static func _dress_chapel(spec: CastleSpec, out: Array[Dictionary]) -> void:
	var a: AABB = CastleGeometry.chapel_aabb(spec)
	if a.size.x <= 0.0:
		return
	var room: Rect2 = _plan(a).grow(-INSET)
	if room.size.x < MIN_ROOM or room.size.y < MIN_ROOM:
		return
	var c: Vector2 = room.get_center()
	var half_wide: float = room.size.x / 2.0
	var altar_z: float = room.position.y + 1.2
	var scale: float = _fit_scale(HIGH_TABLE, half_wide * 2.0 - 0.6)
	if scale <= 0.0:
		return
	var yaw: float = _yaw_facing(Vector2(0.0, 1.0))
	_put(out, HIGH_TABLE, Vector3(c.x, 0.0, altar_z), yaw, scale, &"altar")
	_on(out, "Chalice", Vector2(c.x, altar_z), PropCatalog.height(HIGH_TABLE) * scale,
		yaw, &"vessel")
	for side in [-1.0, 1.0]:
		var cx: float = c.x + side * (PropCatalog.footprint(HIGH_TABLE).x * scale / 2.0 + 0.6)
		if absf(cx - c.x) + PropCatalog.footprint(CANDELABRUM).x / 2.0 <= half_wide:
			_put(out, CANDELABRUM, Vector3(cx, 0.0, altar_z + 0.2), 0.0, 1.0, &"light")
	var b_scale: float = _fit_scale(BENCH, half_wide * 2.0 - 0.8)
	var z: float = altar_z + 2.2
	while b_scale > 0.0 and z <= room.end.y - 0.6:
		_put(out, BENCH, Vector3(c.x, 0.0, z), _yaw_facing(Vector2(0.0, -1.0)),
			b_scale, &"pew")
		z += 1.15
	var y: float = minf(SCONCE_H, _ceiling(a) * 0.6)
	for side2 in [-1.0, 1.0]:
		_put(out, SCONCE, Vector3(c.x + side2 * (half_wide - 0.12), y, c.y),
			_mount_yaw(SCONCE, Vector2(-side2, 0.0)), 1.0, &"light")


# ----------------------------------------------------------------- courtyard

## The working yard.
##
## Standing places are dealt round the inside of the curtain and the programme
## is dealt into them in order: whatever will not fit in the next place is
## tried in the one after. Everything the castle is already built of -- keep,
## hall, chapel, mound, gatehouse, towers -- is reserved before a single barrel
## is set down, and so is the way in from the gate, because a courtyard nobody
## can cross is not a courtyard.
static func _dress_yard(spec: CastleSpec, out: Array[Dictionary]) -> void:
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	if bailey.size.x < 6.0 or bailey.size.y < 6.0:
		return
	var taken: Array[Rect2] = _reserved(spec)
	var next := 0
	for spot in _yard_spots(bailey):
		if next >= YARD_PROGRAMME.size():
			break
		var row: Dictionary = YARD_PROGRAMME[next]
		var key: String = String(row["key"])
		# everything in a yard is turned toward the middle of it: the cart to
		# be unloaded, the anvil to be worked at, the dummy to be hit
		var yaw: float = _yaw_facing(bailey.get_center() - spot)
		var rect: Rect2 = _foot(key, spot, yaw, 1.0)
		if not bailey.grow(-0.2).encloses(rect) or _clashes(rect, taken):
			continue
		taken.append(rect)
		_put(out, key, _v3(spot), yaw, 1.0, StringName(row["kind"]))
		next += 1


## Every standing place in the yard, in a ring inside the curtain: a castle
## keeps the middle of its own courtyard clear and stacks what it owns against
## the walls.
static func _yard_spots(bailey: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var ring: Rect2 = bailey.grow(-(CastleGeometry.BAILEY_CLEAR + 0.6))
	if ring.size.x <= 0.0 or ring.size.y <= 0.0:
		return out
	var corners: Array[Vector2] = [ring.position, Vector2(ring.end.x, ring.position.y),
		ring.end, Vector2(ring.position.x, ring.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var steps: int = maxi(int(a.distance_to(b) / YARD_STEP), 1)
		for k in range(steps):
			out.append(a.lerp(b, float(k) / float(steps)))
	return out


## The floor that is spoken for before the dressing starts.
static func _reserved(spec: CastleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec), CastleGeometry.gatehouse_aabb(spec, 0),
			CastleGeometry.barbican_aabb(spec)]:
		if a.size.x > 0.0:
			out.append(_plan(a).grow(CastleGeometry.BAILEY_CLEAR * 0.5))
	if CastleGeometry.is_motte(spec):
		out.append(_plan(CastleGeometry.motte_aabb(spec)))
	# the way in: from the gate, straight up the axis, the whole depth of the
	# bailey. Nothing stands in it.
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	var w: float = maxf(CastleGeometry.gate_width(spec, 0), GATE_CLEAR)
	out.append(Rect2(Vector2(-w / 2.0, bailey.position.y), Vector2(w, bailey.size.y)))
	for r in CastleGeometry.rings(spec):
		var i := 0
		for t in CastleGeometry.vertex_tower_centers(spec, r):
			var s: float = CastleGeometry.tower_base_half_at(spec, r, i)
			out.append(Rect2(Vector2(t.x - s, t.z - s), Vector2(s * 2.0, s * 2.0)))
			i += 1
	return out


# ------------------------------------------------------------------ defences

## Fire where the watch is: along the wall walk, on the tower tops, and either
## side of the gate passage.
static func _dress_defences(spec: CastleSpec, out: Array[Dictionary]) -> void:
	var fires := 0
	for r in CastleGeometry.rings(spec):
		var t: float = CastleGeometry.wall_thickness(spec, r)
		var walk_y: float = CastleGeometry.wall_height(spec, r)
		for seg in CastleGeometry.wall_segments(spec, r):
			if fires >= MAX_WALL_FIRES:
				break
			var a: Vector2 = seg["a"]
			var b: Vector2 = seg["b"]
			var o: Vector3 = seg["outward"]
			var n: int = maxi(int(float(seg["length"]) / WALL_FIRE_BAY), 1)
			for i in range(n):
				if fires >= MAX_WALL_FIRES:
					break
				var m: Vector2 = a.lerp(b, (float(i) + 0.5) / float(n))
				# the walk runs along the middle of the wall, not its outer face
				_put(out, BRAZIER, Vector3(m.x - o.x * t / 2.0, walk_y,
					m.y - o.z * t / 2.0), 0.0, 1.0, &"light")
				fires += 1
		var i2 := 0
		for tower in CastleGeometry.vertex_tower_centers(spec, r):
			_put(out, BRAZIER, Vector3(tower.x,
				CastleGeometry.tower_height_at(spec, r, i2), tower.z), 0.0, 1.0, &"light")
			i2 += 1

	# the gate passage, lit from inside
	var g: AABB = CastleGeometry.gatehouse_aabb(spec, 0)
	if g.size.x <= 0.0:
		return
	var y: float = minf(SCONCE_H, CastleGeometry.gate_height(spec, 0) * 0.5)
	for side in [-1.0, 1.0]:
		var x: float = g.position.x + (g.size.x - 0.14 if side > 0.0 else 0.14)
		_put(out, SCONCE, Vector3(x, y, g.position.z + g.size.z * 0.6),
			_mount_yaw(SCONCE, Vector2(-side, 0.0)), 1.0, &"light")
	# heraldry either side of the way in, on the front of the gatehouse
	var flag_y: float = CastleGeometry.gate_height(spec, 0) * 0.55
	for side2 in [-1.0, 1.0]:
		var key: String = WAR_BANNERS[0 if side2 < 0.0 else 1]
		var fx: float = g.position.x + (g.size.x + 0.16 if side2 > 0.0 else -0.16)
		_put(out, key, Vector3(fx, flag_y, g.position.z + g.size.z * 0.5),
			_mount_yaw(key, Vector2(side2, 0.0)), 1.0, &"banner")


# --------------------------------------------------------------- the room

## An oriented room: where its middle is, which way it is long, how far it
## reaches inside its own walls, and what it has for a ceiling.
##
## Not a Rect2, because a ridge castle's ranges run at an angle to the world
## and the bounding box of one of those is a good deal larger than the range.
## Furnishing the box puts the trestles outside the wall.
static func _room(centre: Vector2, along: Vector2, length: float, width: float,
		height: float) -> Dictionary:
	var dir: Vector2 = along.normalized() if along.length_squared() > 0.000001 \
		else Vector2(0.0, 1.0)
	return {"c": centre, "along": dir, "across": Vector2(dir.y, -dir.x),
		"half_len": length / 2.0 - INSET, "half_wide": width / 2.0 - INSET,
		"ceiling": _ceiling_of(height)}


## An axis-aligned range, long down whichever of its sides is longer.
static func _room_of(a: AABB) -> Dictionary:
	if a.size.x <= 0.0:
		return {}
	var p: Rect2 = _plan(a)
	var along := Vector2(0.0, 1.0) if p.size.y >= p.size.x else Vector2(1.0, 0.0)
	var length: float = maxf(p.size.x, p.size.y)
	var width: float = minf(p.size.x, p.size.y)
	return _room(p.get_center(), along, length, width, a.size.y)


## One run of a ridge castle's spine, in its own frame.
static func _room_of_segment(seg: Dictionary) -> Dictionary:
	var a: Vector2 = seg["from"]
	var b: Vector2 = seg["to"]
	return _room((a + b) / 2.0, seg["dir"], float(seg["length"]),
		float(seg["width"]), float(seg["height"]))


static func _usable(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	return float(room["half_len"]) * 2.0 >= MIN_ROOM \
		and float(room["half_wide"]) * 2.0 >= MIN_ROOM


# ------------------------------------------------------------------- shared

static func _ceiling(a: AABB) -> float:
	return _ceiling_of(a.size.y)


static func _ceiling_of(h: float) -> float:
	return minf(h, ROOM_CEILING)


static func _plan(a: AABB) -> Rect2:
	return Rect2(Vector2(a.position.x, a.position.z), Vector2(a.size.x, a.size.z))


## The scale a piece has to come down to before it fits in `room_for` metres,
## or 0 when even the catalogue's smallest allowed size will not go in.
static func _fit_scale(key: String, room_for: float) -> float:
	var want: float = PropCatalog.footprint(key).x
	if want <= 0.0 or room_for <= 0.0:
		return 0.0
	var scale: float = minf(room_for / want, 1.0)
	return scale if scale >= PropCatalog.min_scale(key) else 0.0


## The yaw that points a prop's face down `d`. A prop faces its own local -Z,
## which a yaw of y turns to (-sin y, -cos y).
static func _yaw_facing(d: Vector2) -> float:
	if d.length_squared() < 0.000001:
		return 0.0
	return atan2(-d.x, -d.y)


## The same, for a wall piece. The MegaKit turns every wall prop by a half turn
## (they are modelled with their mass behind their mounting point) and the
## Dungeon Kit flags by none, so the correction is read from the catalogue
## rather than assumed.
static func _mount_yaw(key: String, inward: Vector2) -> float:
	return _yaw_facing(inward) - PropCatalog.face_offset(key)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


static func _foot(key: String, at: Vector2, yaw: float, scale: float) -> Rect2:
	var f: Vector2 = PropCatalog.footprint_yawed(key, yaw) * scale
	return Rect2(at - f / 2.0, f)


static func _clashes(rect: Rect2, taken: Array[Rect2]) -> bool:
	var grown: Rect2 = rect.grow(YARD_MARGIN)
	for t in taken:
		if t.intersects(grown):
			return true
	return false


static func _put(out: Array[Dictionary], key: String, pos: Vector3, yaw: float,
		scale: float, kind: StringName) -> void:
	out.append(PropCatalog.placement(key, pos, yaw, scale, kind))


## A piece set on top of something, at the measured height of that top.
static func _on(out: Array[Dictionary], key: String, at: Vector2, top: float,
		yaw: float, kind: StringName) -> void:
	_put(out, key, Vector3(at.x, top, at.y), yaw, 1.0, kind)
