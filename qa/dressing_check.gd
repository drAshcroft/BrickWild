class_name DressingCheck
extends RefCounted
## Is the dressing in the building, and can anybody get past it?
##
## The massing suites judge the stone. This judges what was set down on it, for
## the families that dress a shell rather than a HousePlan -- the churches and
## the castles today, and the temple whenever it is moved over. It measures the
## placements the builder actually logged; it never re-derives them from the
## spec, because a check that re-derives agrees with the placer even when they
## are both wrong.
##
## Four things go wrong with dressing, and there is a rule for each:
##
##   known     a key nobody measured is a prop that will not load, and a
##             silently missing pew is worse than a loud one
##   inside    a barrel outside the curtain is a barrel in a field
##   clear     two things in the same place, at the same height
##   walk      the aisle of a church and the gate of a castle are the two
##             pieces of floor that exist to be walked on. Furnishing either
##             shut is the failure this check was written for.
##
## A fifth, `lit`, is a warning rather than a failure: a dark church is a
## defect in the dressing, but it is not a broken building.

const PERSON_RADIUS := HouseGeometry.PERSON_RADIUS
## How far two solid pieces may interpenetrate before it reads as a mistake
## rather than as a mesh with a wide bounding box.
const OVERLAP_TOL := 0.06
## A wall piece hung lower than this is on the skirting, not on the wall.
const MOUNT_MIN := 0.8

var failures: Array[String] = []
var warnings: Array[String] = []
var checked := 0


func ok() -> bool:
	return failures.is_empty()


## The rules that hold for any dressed shell. `bounds` is the ground the
## building stands on in plan and `height` its tallest point; `label` names the
## building in every complaint, since a sweep reports on hundreds of them.
##
## `lit_extra` is light the shell did not place: the furniture of the planned
## interiors (`builder.interiors`), which is judged by the house checks rather
## than here, but which still counts when asking whether anything burns.
func check(props: Array, bounds: Rect2, height: float, label: String,
		lit_extra: Array = []) -> void:
	_known(props, label)
	_inside(props, bounds, height, label)
	_clear(props, label)
	_lit(props + lit_extra, label)


## Every key is a prop the catalogue describes AND measured.
func _known(props: Array, label: String) -> void:
	for p in props:
		checked += 1
		var key: String = p["key"]
		if not PropCatalog.known(key):
			fail("%s: '%s' is placed but the catalogue does not know it" % [label, key])


## Nothing is dressed onto ground the building does not stand on, and nothing
## is hung above its own roof or below its own floor.
func _inside(props: Array, bounds: Rect2, height: float, label: String) -> void:
	var room: Rect2 = bounds.grow(0.05)
	for p in props:
		checked += 1
		var key: String = p["key"]
		var pos: Vector3 = p["pos"]
		var rect: Rect2 = p["rect"]
		var where: Rect2 = rect if rect.size.x > 0.0 else Rect2(Vector2(pos.x, pos.z),
			Vector2.ZERO)
		if not room.encloses(where):
			fail("%s: %s stands at %.1f, %.1f, outside the building" % [label, key,
				pos.x, pos.z])
		if pos.y < -0.01:
			fail("%s: %s is placed %.2fm underground" % [label, key, pos.y])
		elif pos.y > height + 0.5:
			fail("%s: %s is placed at %.1fm, above the %.1fm building"
				% [label, key, pos.y, height])
		if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED):
			# Judged by where the piece ENDS UP, not by where its pivot is. The
			# MegaKit banners hang below their mounting point and the Dungeon
			# Kit arch flags sit two metres above theirs; a rule about pos.y
			# alone calls one of those two conventions a fault.
			var s: float = float(p.get("scale", 1.0))
			var top: float = pos.y + (PropCatalog.floor_offset(key)
				+ PropCatalog.height(key)) * s
			if top < MOUNT_MIN:
				fail("%s: %s reaches only %.2fm, which is not on a wall"
					% [label, key, top])


## No two solid pieces occupy the same floor at the same height.
##
## The height matters: a brazier on the wall walk stands directly over the
## barrels in the yard below it, and calling that a collision would fail every
## castle in the sweep for being a castle.
func _clear(props: Array, label: String) -> void:
	var solid: Array[Dictionary] = []
	for p in props:
		if Rect2(p["rect"]).size.x > 0.0:
			solid.append(p)
	for i in range(solid.size()):
		for j in range(i + 1, solid.size()):
			checked += 1
			var a: Dictionary = solid[i]
			var b: Dictionary = solid[j]
			var ra: Rect2 = Rect2(a["rect"]).grow(-OVERLAP_TOL)
			var rb: Rect2 = Rect2(b["rect"]).grow(-OVERLAP_TOL)
			if ra.size.x <= 0.0 or rb.size.x <= 0.0 or not ra.intersects(rb):
				continue
			if not _levels_meet(a, b):
				continue
			if not _boxes_meet(a, b):
				continue
			var pa: Vector3 = a["pos"]
			fail("%s: %s and %s are both standing at %.1f, %.1f"
				% [label, a["key"], b["key"], pa.x, pa.z])
			return   # one report per building; the rest would be the same news


## Do two pieces really overlap, or do only their bounding boxes?
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
		var reach: float = _reach(ua, ha, axis) + _reach(ub, hb, axis) - OVERLAP_TOL * 2.0
		if absf(d.dot(axis)) > reach:
			return false
	return true


## How far a box reaches along `axis`, from its own centre.
func _reach(u: Vector2, half: Vector2, axis: Vector2) -> float:
	var v := Vector2(-u.y, u.x)
	return half.x * absf(u.dot(axis)) + half.y * absf(v.dot(axis))


func _centre(p: Dictionary) -> Vector2:
	return PropCatalog.plan_centre(p["key"], p["pos"], float(p["yaw"]),
		float(p.get("scale", 1.0)))


func _half(p: Dictionary) -> Vector2:
	return PropCatalog.footprint(p["key"]) * float(p.get("scale", 1.0)) / 2.0


## Do two pieces share any height, or is one simply above the other?
func _levels_meet(a: Dictionary, b: Dictionary) -> bool:
	var a0: float = (a["pos"] as Vector3).y
	var b0: float = (b["pos"] as Vector3).y
	var a1: float = a0 + PropCatalog.height(a["key"]) * float(a.get("scale", 1.0))
	var b1: float = b0 + PropCatalog.height(b["key"]) * float(b.get("scale", 1.0))
	return minf(a1, b1) - maxf(a0, b0) > 0.05


## Somewhere in it, something is burning.
func _lit(props: Array, label: String) -> void:
	checked += 1
	for p in props:
		if StringName(p.get("kind", &"")) == &"light" \
				or PropCatalog.has_tag(p["key"], PropCatalog.LIGHT):
			return
	warn("%s: nothing in it is lit" % label)


# ------------------------------------------------------------------ walking

## Can a person get from `from` to `to` across `floors`, with the dressing in
## the way? `extra` blocks the floor without being dressing -- the buildings
## standing in a castle courtyard.
##
## Same body and the same grid as the house nav check and the temple rite
## check: one distance transform, not a third copy of one.
func walk(props: Array, floors: Array[Rect2], extra: Array[Rect2], from: Vector2,
		to: Rect2, label: String, what: String) -> bool:
	checked += 1
	var bounds: Rect2 = floors[0]
	for f in floors:
		bounds = bounds.merge(f)
	var grid := WalkGrid.new()
	# A fortress bailey is 200 m by 300 m, and rasterising that at the house's
	# 12 cm would be four million cells to answer a yes/no question about a
	# three metre gate. The cell grows with the building, to a quarter of the
	# body being walked, which is still finer than anything it has to squeeze
	# between.
	grid.setup(bounds.grow(0.5), clampf(maxf(bounds.size.x, bounds.size.y) / 400.0,
		0.12, PERSON_RADIUS))
	for f2 in floors:
		grid.add_floor(f2)
	for e in extra:
		grid.add_obstacle(e)
	for p in props:
		var rect: Rect2 = p["rect"]
		if rect.size.x > 0.0 and (p["pos"] as Vector3).y < 1.0:
			grid.add_obstacle(rect)
	grid.build(PERSON_RADIUS)
	if not grid.flood_from(from, 1.2):
		fail("%s: %s -- nobody can even stand in the doorway" % [label, what])
		return false
	if not grid.reached(to, PERSON_RADIUS):
		fail("%s: %s -- the way is blocked by the dressing" % [label, what])
		return false
	return true


func fail(msg: String) -> void:
	failures.append(msg)


func warn(msg: String) -> void:
	warnings.append(msg)
