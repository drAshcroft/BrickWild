import io


def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " :: anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)


# ---------------------------------------------------------------- the check
edit("qa/dressing_check.gd", [
# a wall piece is judged by where its MASS lands, not by where its pivot is
("""		if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) and pos.y < MOUNT_MIN:
			fail("%s: %s hangs at %.2fm, which is not on a wall" % [label, key, pos.y])""",
 """		if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED):
			# Judged by where the piece ENDS UP, not by where its pivot is. The
			# MegaKit banners hang below their mounting point and the Dungeon
			# Kit arch flags sit two metres above theirs; a rule about pos.y
			# alone calls one of those two conventions a fault.
			var s: float = float(p.get("scale", 1.0))
			var top: float = pos.y + (PropCatalog.floor_offset(key)
				+ PropCatalog.height(key)) * s
			if top < MOUNT_MIN:
				fail("%s: %s reaches only %.2fm, which is not on a wall"
					% [label, key, top])"""),
# the overlap test measures the mass too
("""func _centre(p: Dictionary) -> Vector2:
	var pos: Vector3 = p["pos"]
	return Vector2(pos.x, pos.z)""",
 """func _centre(p: Dictionary) -> Vector2:
	return PropCatalog.plan_centre(p["key"], p["pos"], float(p["yaw"]),
		float(p.get("scale", 1.0)))"""),
])


# ------------------------------------------------------------- the church
edit("src/church/church_furnisher.gd", [
("""const FONT := "Cauldron"       # the only stone basin in the pack
const BELL_ROPE := "Rope_2"
const BANNERS := ["Banner_1_Cloth", "Banner_2_Cloth"]""",
 """const FONT := "Cauldron"       # the only stone basin in the pack
const BELL_ROPE := "Rope_2"
const BANNERS := ["Banner_1_Cloth", "Banner_2_Cloth"]
# ---- from the Dungeon Kit, which is where the church furniture proper is ----
const RAIL := "Dungeon_Rail_Straight"
const RAIL_END := "Dungeon_Rail_Divider"
const FLOOR_CANDLES := ["Dungeon_Candles_1", "Dungeon_Candles_2"]
const STATUES := ["Dungeon_Statue_Stag", "Dungeon_Statue_Fox"]
## A statue is four and a half metres of stone: a parish church has no room to
## look up at one.
const STATUE_MIN_H := 6.0"""),

# the sconce and banner yaws come from the catalogue now
("""		for side in [-1.0, 1.0]:
			var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
			_put(out, SCONCE, Vector3(side * x, y, z), yaw, 1.0, &"light")
			if i % 2 == 1 and spec.height >= BANNER_MIN_H:
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(side * x, banner_y, z + PEW_PITCH), yaw, 1.0,
					&"banner")""",
 """		for side in [-1.0, 1.0]:
			var inward := Vector2(-side, 0.0)
			_put(out, SCONCE, Vector3(side * x, y, z),
				PropCatalog.mount_yaw(SCONCE, inward), 1.0, &"light")
			if i % 2 == 1 and spec.height >= BANNER_MIN_H:
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(side * x, banner_y, z + PEW_PITCH),
					PropCatalog.mount_yaw(key, inward), 1.0, &"banner")"""),

# the chancel gains a rail and standing candles
("""	# the chancel step: the reader on one side, fire on the other
	var step_z: float = az - 1.5
	var off: float = AISLE_W / 2.0 + 0.5
	if off + 0.3 <= half:
		_put(out, LECTERN, Vector3(-off, 0.0, step_z), 0.0, 1.0, &"lectern")
		_put(out, BRAZIER, Vector3(off, 0.0, step_z), 0.0, 1.0, &"light")""",
 """	# the chancel step: the reader on one side, fire on the other
	var step_z: float = az - 1.5
	var off: float = AISLE_W / 2.0 + 0.5
	if off + 0.3 <= half:
		_put(out, LECTERN, Vector3(-off, 0.0, step_z), 0.0, 1.0, &"lectern")
		_put(out, BRAZIER, Vector3(off, 0.0, step_z), 0.0, 1.0, &"light")
	# candles on the floor at the foot of the chancel, and the rail across it
	for side3 in [-1.0, 1.0]:
		var cand: String = FLOOR_CANDLES[0 if side3 < 0.0 else 1]
		var candle_x: float = AISLE_W / 2.0 + 0.55
		if candle_x + PropCatalog.footprint(cand).x / 2.0 <= half:
			_put(out, cand, Vector3(side3 * candle_x, 0.0, az - 2.2), 0.0, 1.0, &"light")
	_dress_rail(spec, out, az - CHANCEL + 0.35)"""),

# and the rail itself, plus statues in the transept
("""## Two blocks of pews either side of the aisle, from the chancel step back""",
 '''## The altar rail across the chancel, with the aisle left open in the middle.
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


## Two blocks of pews either side of the aisle, from the chancel step back'''),

("""		_put(out, CANDELABRUM, Vector3(side * (end_x - 2.1), 0.0, tz - 1.0), 0.0, 1.0,
			&"light")""",
 """		_put(out, CANDELABRUM, Vector3(side * (end_x - 2.1), 0.0, tz - 1.0), 0.0, 1.0,
			&"light")
		# a statue at the end of each arm, where a side altar would stand, but
		# only where there is height to look up at one
		if spec.height >= STATUE_MIN_H:
			var statue: String = STATUES[0 if side < 0.0 else 1]
			_put(out, statue, Vector3(side * (end_x - 3.4), 0.0, tz + 1.2),
				PropCatalog.yaw_facing(Vector2(-side, 0.0)), 1.0, &"statue")"""),

# the aisle sconces too
("""		var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
		for i in range(n):
			var z: float = lerpf(zr.x + 1.0, zr.y - 1.0, (float(i) + 0.5) / float(n))
			_put(out, SCONCE, Vector3(outer, y, z), yaw, 1.0, &"light")
		if spec.aisle_width >= 1.6:
			_put(out, "Chest_Wood", Vector3(cx, 0.0, zr.x + 1.0), yaw, 1.0, &"store")""",
 """		var inward := Vector2(-side, 0.0)
		var yaw: float = PropCatalog.mount_yaw(SCONCE, inward)
		for i in range(n):
			var z: float = lerpf(zr.x + 1.0, zr.y - 1.0, (float(i) + 0.5) / float(n))
			_put(out, SCONCE, Vector3(outer, y, z), yaw, 1.0, &"light")
		if spec.aisle_width >= 1.6:
			_put(out, "Dungeon_Chest", Vector3(cx, 0.0, zr.x + 1.0),
				PropCatalog.yaw_facing(inward), 1.0, &"store")"""),
])


# ------------------------------------------------------------- the castle
edit("src/castle/castle_furnisher.gd", [
("""const BANNERS := ["Banner_1", "Banner_2", "Banner_1_Cloth", "Banner_2_Cloth"]""",
 """const BANNERS := ["Banner_1", "Banner_2", "Banner_1_Cloth", "Banner_2_Cloth"]
# ---- from the Dungeon Kit ----
## The big flags, for the curtain and the gatehouse: outdoor heraldry, where the
## MegaKit cloth would be lost against a fifteen metre wall.
const WAR_BANNERS := ["Dungeon_Flag_Wall", "Dungeon_Flag_Wall2"]
const MONUMENT := ["Dungeon_Statue_Stag", "Dungeon_Statue_Fox"]
const TREASURE := "Dungeon_Chest_Gold"
const LIBRARY := "Dungeon_Bookcase_Full\""""),

# the yard gains the wagon, the urns and the rubble
("""	{"key": "Rope_3", "kind": &"yard"},
	{"key": "Bucket_Wooden_1", "kind": &"yard"},
	{"key": "FarmCrate_Empty", "kind": &"store"},
	{"key": "Chest_Wood", "kind": &"store"},
]""",
 """	{"key": "Rope_3", "kind": &"yard"},
	{"key": "Dungeon_Cart", "kind": &"cart"},
	{"key": "Dungeon_Pot1", "kind": &"urn"},
	{"key": "Bucket_Wooden_1", "kind": &"yard"},
	{"key": "Dungeon_Pot3", "kind": &"urn"},
	{"key": "Dungeon_Bricks", "kind": &"rubble"},
	{"key": "FarmCrate_Empty", "kind": &"store"},
	{"key": "Chest_Wood", "kind": &"store"},
	{"key": "Dungeon_Pot2_Broken", "kind": &"urn"},
]"""),

# the keep chamber gets the treasury and the library
("""	var back: Vector2 = c + along * (half_len - 0.6)
	_put(out, "Chest_Wood", _v3(back - across * (half_wide - 0.9)),
		_yaw_facing(-along), 1.0, &"store")""",
 """	var back: Vector2 = c + along * (half_len - 0.6)
	_put(out, TREASURE, _v3(back - across * (half_wide - 0.9)),
		_yaw_facing(-along), 1.0, &"store")
	# a tall bookcase against the long wall, where the room is tall enough to
	# stand two and a half metres of it up
	if float(room["ceiling"]) >= 3.2 and half_len > 2.4:
		_put(out, LIBRARY, _v3(c + across * (half_wide - 0.4) - along * 1.2),
			_yaw_facing(-across), 1.0, &"store")"""),

# the wall yaws come from the catalogue
("""	return _yaw_facing(inward) - PI""",
 """	return _yaw_facing(inward) - PropCatalog.face_offset(key)"""),
("""static func _mount_yaw(inward: Vector2) -> float:""",
 """static func _mount_yaw(key: String, inward: Vector2) -> float:"""),
("""## The same, for a wall piece: the catalogue turns every wall-mounted prop by a
## half turn (they are modelled with their mass behind their mounting point),
## so the yaw stored has to be that much short of the facing.""",
 """## The same, for a wall piece. The MegaKit turns every wall prop by a half turn
## (they are modelled with their mass behind their mounting point) and the
## Dungeon Kit flags by none, so the correction is read from the catalogue
## rather than assumed."""),
("""			var yaw: float = _mount_yaw(-across * side)
			_put(out, SCONCE, Vector3(at.x, y, at.y), yaw, 1.0, &"light")
			if i % 2 == 0 and ceiling >= BANNER_MIN_H:
				var b: Vector2 = at + along * 1.0
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(b.x, banner_y, b.y), yaw, 1.0, &"banner")""",
 """			var inward: Vector2 = -across * side
			_put(out, SCONCE, Vector3(at.x, y, at.y),
				_mount_yaw(SCONCE, inward), 1.0, &"light")
			if i % 2 == 0 and ceiling >= BANNER_MIN_H:
				var b: Vector2 = at + along * 1.0
				var key: String = BANNERS[rng.randi_range(0, BANNERS.size() - 1)]
				_put(out, key, Vector3(b.x, banner_y, b.y),
					_mount_yaw(key, inward), 1.0, &"banner")"""),
("""		_put(out, SCONCE, Vector3(c.x + side2 * (half_wide - 0.12), y, c.y),
			_mount_yaw(Vector2(-side2, 0.0)), 1.0, &"light")""",
 """		_put(out, SCONCE, Vector3(c.x + side2 * (half_wide - 0.12), y, c.y),
			_mount_yaw(SCONCE, Vector2(-side2, 0.0)), 1.0, &"light")"""),
("""		_put(out, SCONCE, Vector3(x, y, g.position.z + g.size.z * 0.6),
			_mount_yaw(Vector2(-side, 0.0)), 1.0, &"light")""",
 """		_put(out, SCONCE, Vector3(x, y, g.position.z + g.size.z * 0.6),
			_mount_yaw(SCONCE, Vector2(-side, 0.0)), 1.0, &"light")
	# heraldry either side of the way in, on the front of the gatehouse
	var flag_y: float = CastleGeometry.gate_height(spec, 0) * 0.55
	for side2 in [-1.0, 1.0]:
		var key: String = WAR_BANNERS[0 if side2 < 0.0 else 1]
		var fx: float = g.position.x + (g.size.x + 0.16 if side2 > 0.0 else -0.16)
		_put(out, key, Vector3(fx, flag_y, g.position.z + g.size.z * 0.5),
			_mount_yaw(key, Vector2(side2, 0.0)), 1.0, &"banner")"""),
])
