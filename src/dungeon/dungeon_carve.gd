class_name DungeonCarve
extends RefCounted
## A dungeon room's shape as an ordered list of operations on solid rock.
##
## Engine-neutral on purpose: the consumer owns the voxels. Start from solid;
## apply each op in order; a `carve` makes its shape air, a `fill` makes it
## rock again (a column, a dais, a stair). Shapes, in room-local metres:
##
##   box        center [x,y,z], size [x,y,z] (full extents)
##   cylinder   center, axis "x"|"y"|"z", length along the axis, radii [a, b]
##              across it: axis x -> [y, z], axis y -> [x, z], axis z -> [x, y]
##   ellipsoid  center, radii [x,y,z]
##
## A shape that meets the floor reaches a metre through it (DungeonRoomPlanner.ROOT): a fill
## standing on it roots below, a carve opening beneath it rises above. A consumer that writes
## the ops as signed distances then gets every surface where it belongs.
##
## Every op carries a `tag` ("chamber", "vault", "tunnel:<portal>", "column#3",
## ...) so a check can name what it found, and an optional `material` for a
## fill whose surface is not the room's band.

static func box(op: StringName, tag: String, center: Vector3, size: Vector3) -> Dictionary:
	return {"op": String(op), "shape": "box", "tag": tag,
		"center": _a(center), "size": _a(size)}


static func cylinder(op: StringName, tag: String, center: Vector3, axis: String,
		length: float, radii: Vector2) -> Dictionary:
	return {"op": String(op), "shape": "cylinder", "tag": tag, "center": _a(center),
		"axis": axis, "length": length, "radii": [radii.x, radii.y]}


static func ellipsoid(op: StringName, tag: String, center: Vector3, radii: Vector3) -> Dictionary:
	return {"op": String(op), "shape": "ellipsoid", "tag": tag,
		"center": _a(center), "radii": _a(radii)}


## Is `p` rock after every op has been applied?
static func solid_at(ops: Array, p: Vector3) -> bool:
	var solid := true
	for op: Dictionary in ops:
		if inside(op, p):
			solid = String(op["op"]) == "fill"
	return solid


static func inside(op: Dictionary, p: Vector3) -> bool:
	var c := _v(op["center"])
	var d := p - c
	match String(op["shape"]):
		"box":
			var h := _v(op["size"]) * 0.5
			return absf(d.x) <= h.x and absf(d.y) <= h.y and absf(d.z) <= h.z
		"cylinder":
			var r: Array = op["radii"]
			var along := 0.0
			var a := 0.0
			var b := 0.0
			match String(op["axis"]):
				"x":
					along = d.x; a = d.y; b = d.z
				"y":
					along = d.y; a = d.x; b = d.z
				_:
					along = d.z; a = d.x; b = d.y
			if absf(along) > float(op["length"]) * 0.5:
				return false
			return (a * a) / (float(r[0]) * float(r[0])) + (b * b) / (float(r[1]) * float(r[1])) <= 1.0
		"ellipsoid":
			var e := _v(op["radii"])
			return (d.x * d.x) / (e.x * e.x) + (d.y * d.y) / (e.y * e.y) \
				+ (d.z * d.z) / (e.z * e.z) <= 1.0
	return false


## The op's bounding box.
static func bounds(op: Dictionary) -> AABB:
	var c := _v(op["center"])
	var h := Vector3.ZERO
	match String(op["shape"]):
		"box":
			h = _v(op["size"]) * 0.5
		"cylinder":
			var r: Array = op["radii"]
			var half := float(op["length"]) * 0.5
			match String(op["axis"]):
				"x": h = Vector3(half, float(r[0]), float(r[1]))
				"y": h = Vector3(float(r[0]), half, float(r[1]))
				_: h = Vector3(float(r[0]), float(r[1]), half)
		"ellipsoid":
			h = _v(op["radii"])
	return AABB(c - h, h * 2.0)


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
