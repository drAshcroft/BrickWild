import io
p = "src/house/prop_catalog.gd"
s = io.open(p, encoding="utf-8").read()

old = '''## One prop placed somewhere, in the form every family that is NOT a HousePlan
## records its dressing in: the temple, the church and the castle all build a
## list of these and hand it to their assembler.
##
## `rect` is the plan floor the piece actually stands on, computed here rather
## than left to the checks: a check that re-derives the footprint from the key
## and the yaw agrees with the placer even when they are both wrong, which is
## the failure mode this whole harness exists to avoid. A wall-mounted,
## ceiling-hung or on-surface piece takes no floor and carries an empty rect.
static func placement(key: String, pos: Vector3, yaw: float, scale: float,
		kind: StringName) -> Dictionary:
	var rect := Rect2()
	if blocks_floor(key):
		var f: Vector2 = footprint_rotated(key, yaw) * scale
		rect = Rect2(Vector2(pos.x, pos.z) - f / 2.0, f)
	return {"key": key, "pos": pos, "yaw": yaw, "scale": scale, "kind": kind,
		"rect": rect}'''

new = '''## The yaw that points a prop\'s face down `d` (a direction in plan). A prop
## faces its own local -Z, which a yaw of y turns to (-sin y, -cos y).
static func yaw_facing(d: Vector2) -> float:
	if d.length_squared() < 0.000001:
		return 0.0
	return atan2(-d.x, -d.y)


## The yaw to store for a wall piece so that it ends up facing `inward`, off
## the wall it hangs on.
##
## Every wall prop in the MegaKit is modelled with its mass behind its mounting
## point and carries a half-turn `face` correction; the Dungeon Kit\'s flags are
## modelled centred on theirs and carry none. Reading the correction from the
## catalogue rather than assuming PI is what lets both hang the right way round
## on the same wall.
static func mount_yaw(key: String, inward: Vector2) -> float:
	return yaw_facing(inward) - face_offset(key)


## Where a placed prop\'s mass actually sits in plan, which is not always where
## its origin is: the stag statue carries its mass half a metre off its own
## pivot, and a rect centred on the pivot describes a stag that is not there.
static func plan_centre(key: String, pos: Vector3, yaw: float, scale: float) -> Vector2:
	var c: Vector3 = centre_offset(key) * scale
	var turned := Vector2(c.x * cos(yaw) + c.z * sin(yaw),
		-c.x * sin(yaw) + c.z * cos(yaw))
	return Vector2(pos.x, pos.z) + turned


## One prop placed somewhere, in the form every family that is NOT a HousePlan
## records its dressing in: the temple, the church and the castle all build a
## list of these and hand it to their assembler.
##
## `rect` is the plan floor the piece actually stands on, computed here rather
## than left to the checks: a check that re-derives the footprint from the key
## and the yaw agrees with the placer even when they are both wrong, which is
## the failure mode this whole harness exists to avoid. A wall-mounted,
## ceiling-hung or on-surface piece takes no floor and carries an empty rect.
static func placement(key: String, pos: Vector3, yaw: float, scale: float,
		kind: StringName) -> Dictionary:
	var rect := Rect2()
	if blocks_floor(key):
		var f: Vector2 = footprint_rotated(key, yaw) * scale
		rect = Rect2(plan_centre(key, pos, yaw, scale) - f / 2.0, f)
	return {"key": key, "pos": pos, "yaw": yaw, "scale": scale, "kind": kind,
		"rect": rect}'''
assert s.count(old) == 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old, new))
print("patched")
