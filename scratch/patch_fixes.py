import io

def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)

# ---- 1. a house has an annexe; only a manor has cross wings ----
edit("src/castle/castle_furnisher.gd", [
("""	if not CastleGeometry.is_enclosed(spec):
		# a house or a manor: the range IS the building
		_dress_hall(_room_of(CastleGeometry.house_range_aabb(spec)), out, rng)
		for side in CastleGeometry.wing_sides(spec):
			_dress_chamber(_room_of(CastleGeometry.manor_wing_aabb(spec, side)), out, rng)
		return out""",
 """	if not CastleGeometry.is_enclosed(spec):
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
		return out"""),
])

# ---- 2. a prop turned by something other than a quarter turn ----
edit("src/house/prop_catalog.gd", [
("""static func height(key: String) -> float:""",
 """## Plan footprint after ANY yaw: the axis-aligned box the turned piece needs.
##
## footprint_yawed() knows quarter turns only, which is every turn the house
## furnisher makes -- rooms are rectangles and furniture is square to them. A
## range on a ridge castle runs at whatever angle its spine does, and a trestle
## in one is turned 22 degrees; asking footprint_yawed() about that gets the
## UNTURNED footprint back, which is a box the piece does not occupy.
static func footprint_rotated(key: String, yaw: float) -> Vector2:
	var f: Vector2 = footprint(key)
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	return Vector2(f.x * c + f.y * s, f.x * s + f.y * c)


static func height(key: String) -> float:"""),
("""	var rect := Rect2()
	if blocks_floor(key):
		var f: Vector2 = footprint_yawed(key, yaw) * scale
		rect = Rect2(Vector2(pos.x, pos.z) - f / 2.0, f)""",
 """	var rect := Rect2()
	if blocks_floor(key):
		var f: Vector2 = footprint_rotated(key, yaw) * scale
		rect = Rect2(Vector2(pos.x, pos.z) - f / 2.0, f)"""),
])

# ---- 3. the overlap rule judges the piece, not its bounding box ----
edit("qa/dressing_check.gd", [
("""			var ra: Rect2 = Rect2(a["rect"]).grow(-OVERLAP_TOL)
			var rb: Rect2 = Rect2(b["rect"]).grow(-OVERLAP_TOL)
			if ra.size.x <= 0.0 or rb.size.x <= 0.0 or not ra.intersects(rb):
				continue
			if not _levels_meet(a, b):
				continue""",
 """			var ra: Rect2 = Rect2(a["rect"]).grow(-OVERLAP_TOL)
			var rb: Rect2 = Rect2(b["rect"]).grow(-OVERLAP_TOL)
			if ra.size.x <= 0.0 or rb.size.x <= 0.0 or not ra.intersects(rb):
				continue
			if not _levels_meet(a, b):
				continue
			if not _boxes_meet(a, b):
				continue"""),
("""## Do two pieces share any height, or is one simply above the other?""",
 """## Do two pieces really overlap, or do only their bounding boxes?
##
## `rect` is the axis-aligned box a turned piece needs, which for anything not
## square to the world is a good deal larger than the piece. Two trestles set
## at 22 degrees down a ridge castle's hall have overlapping bounding boxes and
## a clear half metre between them. This separating-axis test asks about the
## pieces: four axes, the two of each box, and a gap on any one of them is a
## gap.
func _boxes_meet(a: Dictionary, b: Dictionary) -> bool:
	var ca: Vector2 = _centre(a)
	var cb: Vector2 = _centre(b)
	var ua: Vector2 = Vector2(cos(float(a["yaw"])), -sin(float(a["yaw"])))
	var ub: Vector2 = Vector2(cos(float(b["yaw"])), -sin(float(b["yaw"])))
	var ha: Vector2 = _half(a)
	var hb: Vector2 = _half(b)
	var d: Vector2 = cb - ca
	for axis in [ua, Vector2(-ua.y, ua.x), ub, Vector2(-ub.y, ub.x)]:
		var reach: float = _reach(ua, ha, axis) + _reach(ub, hb, axis) \
			- 2.0 * OVERLAP_TOL
		if absf(d.dot(axis)) > reach:
			return false
	return true


## How far a box reaches along `axis`, from its own centre.
func _reach(u: Vector2, half: Vector2, axis: Vector2) -> float:
	var v := Vector2(-u.y, u.x)
	return half.x * absf(u.dot(axis)) + half.y * absf(v.dot(axis))


func _centre(p: Dictionary) -> Vector2:
	var pos: Vector3 = p["pos"]
	return Vector2(pos.x, pos.z)


func _half(p: Dictionary) -> Vector2:
	return PropCatalog.footprint(p["key"]) * float(p.get("scale", 1.0)) / 2.0


## Do two pieces share any height, or is one simply above the other?"""),
])
