extends RefCounted
## The processional sequence of a church: door, aisle, altar (LIVE-SACRED).
##
## TempleRiteCheck already asks this of a temple (axis, sightline, procession,
## congregation) and is reused as it stands. A church has no such judge: its
## altar is a prop on the axis and its piers are components, so the same four
## questions are asked here of what the builder actually emitted, with the
## same primitives -- TempleRiteCheck.axis_faults / sightline_blockers
## (Sightline) and one WalkGrid. There is no second distance transform.
##
##   AXIS          the altar and the way in stand on the centre line, and the
##                 altar is down the nave from the door, not beside it
##   SIGHTLINE     from the eye of someone just inside the door, nothing
##                 floor-standing (pew, rail, candelabrum, statue, pier,
##                 column) stands between them and the altar top
##   PROCESSION    the aisle can be walked, at a width a procession fits, from
##                 the door to the foot of the altar
##   CONGREGATION  a standable zone between the door and the chancel, sized by
##                 the hall, with seating in it
##
## Sparse floor is not a fault: the chancel is empty on purpose.
## report = {"ok": bool, "failures": [..], "stats": {...}}

const EYE := 1.65
## Clear width of the aisle a procession needs; the furnisher leaves 1.5 m.
const PROCESSION_MIN := 1.0
const CONGREGATION_MIN := 0.22
const TOL := 0.06
## Components that are bodies in the nave, not wall-hung or overhead trim.
const BODY_ROLES: Array[String] = ["pier", "column", "pillar", "screen", "iconostas"]


static func check(spec: ChurchSpec, builder: ChurchBuilder, props: Array = [],
		extra_bodies: Array = []) -> Dictionary:
	var failures: Array[String] = []
	var stats := {}
	var dressed: Array = builder.prop_log if props.is_empty() else props
	var altar := _altar(dressed)
	if altar.is_empty():
		failures.append("focus: the church has no altar to process to")
		return {"ok": false, "failures": failures, "stats": stats}

	var door_x := 0.0
	var doors := ChurchGeometry.west_door_layout(spec)
	for d in doors:
		door_x += float(d["x"])
	door_x /= maxf(float(doors.size()), 1.0)
	var west_z: float = -spec.length / 2.0
	var arect: Rect2 = altar["rect"]
	var altar_x: float = arect.get_center().x

	# AXIS
	for f in TempleRiteCheck.axis_faults(0.0, [["altar", altar_x], ["way in", door_x]], TOL):
		failures.append(f)
	if not (west_z < arect.position.y and arect.position.y > 0.0):
		failures.append("axis: the altar is not down the nave from the door")
	stats["axis_run"] = snappedf(arect.position.y - west_z, 0.1)

	# SIGHTLINE
	var altar_h: float = PropCatalog.height(String(altar["key"])) * float(altar["scale"])
	var from := Vector3(door_x, EYE, west_z + 0.6)
	var to := Vector3(altar_x, altar_h, arect.position.y - 0.02)
	var bodies: Array = _bodies(builder, dressed, altar, altar_h)
	bodies.append_array(extra_bodies)
	var blocked := TempleRiteCheck.sightline_blockers(from, to, bodies)
	stats["sightline_blockers"] = blocked.size()
	if not blocked.is_empty():
		failures.append("sightline: %s stands between the door and the altar"
			% ", ".join(blocked.slice(0, 3)))

	# PROCESSION and CONGREGATION share one grid
	var nave := Rect2(Vector2(-spec.width / 2.0 + 0.15, west_z + 0.15),
		Vector2(spec.width - 0.3, spec.length - 0.3))
	var grid := WalkGrid.new()
	grid.setup(nave.grow(0.5), 0.12)
	grid.add_floor(nave)
	for p in dressed:
		var r: Rect2 = p["rect"]
		if r.size.x > 0.0 and (p["pos"] as Vector3).y < 1.0:
			grid.add_obstacle(r)
	for e in extra_bodies:
		var b: AABB = e["aabb"]
		if b.position.y < 1.0:
			grid.add_obstacle(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	for row in _pier_rects(builder):
		grid.add_obstacle(row)
	grid.build(TempleGeometry.PERSON_RADIUS)
	var entry := Vector2(door_x, west_z + 0.6)
	var foot := Vector2(altar_x, arect.position.y - 0.7)
	if not grid.flood_from(entry, 1.2):
		failures.append("procession: there is nowhere to stand inside the door")
	elif not grid.reached(Rect2(foot - Vector2(0.2, 0.2), Vector2(0.4, 0.4)), 0.0):
		failures.append("procession: nobody can walk from the door to the altar")
	else:
		var width: float = grid.clearance_along(entry, foot)
		stats["procession_width"] = snappedf(width, 0.01)
		if width < PROCESSION_MIN - TOL:
			failures.append("procession: the aisle narrows to %.2fm; a procession needs %.2fm"
				% [width, PROCESSION_MIN])

	var zone := Rect2(Vector2(-spec.width / 2.0 + 0.3, west_z + ChurchFurnisher.ENTRY),
		Vector2(spec.width - 0.6, maxf(arect.position.y - ChurchFurnisher.CHANCEL
			- (west_z + ChurchFurnisher.ENTRY), 0.5)))
	var area: float = zone.size.x * zone.size.y
	var standable := 0.0
	var step := 0.25
	var y: float = zone.position.y
	while y < zone.end.y:
		var x: float = zone.position.x
		while x < zone.end.x:
			if grid.standable(Rect2(Vector2(x, y), Vector2(step, step)), 0.0):
				standable += step * step
			x += step
		y += step
	stats["congregation"] = snappedf(standable / maxf(area, 0.01), 0.01)
	if standable < area * CONGREGATION_MIN:
		failures.append("congregation: only %.0f m2 of a %.0f m2 nave zone can be stood on"
			% [standable, area])
	var pews := 0
	for p in dressed:
		if p["kind"] == &"pew":
			pews += 1
	stats["pews"] = pews
	if pews == 0:
		failures.append("congregation: nowhere for the congregation to sit")
	return {"ok": failures.is_empty(), "failures": failures, "stats": stats}


static func _altar(props: Array) -> Dictionary:
	for p in props:
		if p["kind"] == &"altar" and (p["rect"] as Rect2).size.x > 0.0:
			return p
	return {}


## Floor-standing bodies that could hide the altar. Things on the altar and
## things hung from a wall or ceiling have no floor rect and are not bodies.
static func _bodies(builder: ChurchBuilder, props: Array, altar: Dictionary,
		altar_h: float) -> Array:
	var out: Array = []
	for i in range(props.size()):
		var p: Dictionary = props[i]
		var r: Rect2 = p["rect"]
		var pos: Vector3 = p["pos"]
		if p == altar or r.size.x <= 0.0 or pos.y >= altar_h - 0.01:
			continue
		var h: float = PropCatalog.height(String(p["key"])) * float(p["scale"])
		out.append({"name": "%s#%d" % [p["key"], i],
			"aabb": AABB(Vector3(r.position.x, pos.y, r.position.y), Vector3(r.size.x, h, r.size.y))})
	for c in builder.component_log:
		var role := String(c["role"])
		var is_body := false
		for key in BODY_ROLES:
			if role.contains(key):
				is_body = true
		if not is_body or role.contains("capital"):
			continue
		var a := _component_aabb(c)
		out.append({"name": String(c["id"]), "aabb": a})
	return out


static func _component_aabb(c: Dictionary) -> AABB:
	var xf: Transform3D = c["xf"]
	var size: Vector3 = c["size"]
	var half := size / 2.0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var v: Vector3 = xf * Vector3(half.x * sx, half.y * sy, half.z * sz)
				lo = lo.min(v)
				hi = hi.max(v)
	return AABB(lo, hi - lo)


static func _pier_rects(builder: ChurchBuilder) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in builder.component_log:
		var role := String(c["role"])
		var is_body := false
		for key in BODY_ROLES:
			if role.contains(key):
				is_body = true
		if not is_body or role.contains("capital"):
			continue
		var a := _component_aabb(c)
		if a.position.y < 1.0:
			out.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	return out
