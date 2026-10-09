class_name HouseFurnishSpatialCheck
extends RefCounted
## Command position, hearth, and row alignment rules.

const TOL := 0.03

var failures: Array = []
var warnings: Array = []


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])


## The commanding position: headboard against solid wall, and out of the line
## of the door. It is a feng shui rule and also plain sense -- a bed in the
## line of a door is a bed in a corridor.
func check_command_position(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bed":
			continue
		var gap: float = HouseFurnishArrangementCheck.back_gap(plan, p)
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + BACKING_EPS:
			failures.append("command: the headboard of the %s stands %.2fm off the wall"
				% [HouseFurnishCheck.who(plan, f), gap])
		var rect: Rect2 = p["rect"]
		var c: Vector2 = rect.get_center()
		for d in plan.doors_of(p["room"]):
			var door: Dictionary = plan.doors[d]
			var dn: Vector2 = door["normal"]
			var across: float = absf((c - Vector2(door["pos"])).dot(Vector2(dn.y, -dn.x)))
			var half: float = (absf(dn.y) * rect.size.x + absf(dn.x) * rect.size.y) / 2.0
			if across < (float(door["width"]) / 2.0 + half) * 0.5:
				warnings.append("command: the %s lies in the line of door %d"
					% [HouseFurnishCheck.who(plan, f), d])
		# and you have to be able to get into it: its own side is kept clear by
		# the furnisher, so this only re-checks that the zone is real floor
		var zone: Rect2 = p["zone"]
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
		if zone.size.x <= 0.0:
			failures.append("command: the %s has no side to get into it from" % HouseFurnishCheck.who(plan, f))
		elif not room_rect.grow(0.05).encloses(zone):
			failures.append("command: the only side of the %s you could get in from is inside a wall"
				% HouseFurnishCheck.who(plan, f))


## A fire needs a flue. HousePlan.hearth is the one record of where the two of
## them meet: the planner names a room and a wall, the builder raises the stack
## on it, and the furnisher stands the hearth against it. This rule is what
## proves the three of them still agree.
func check_hearth(plan: HousePlan) -> void:
	var lit: Array[int] = []
	for f in range(plan.furniture.size()):
		if PropCatalog.category(plan.furniture[f]["key"]) == "hearth":
			lit.append(f)
	var room: int = plan.hearth_room()
	if room < 0:
		for f in lit:
			failures.append("hearth: the %s stands in a house with no chimney planned"
				% HouseFurnishCheck.who(plan, f))
		return
	var wall: int = plan.hearth_wall()
	var wants_one: bool = "hearth" in HouseFurnishCheck.REQUIRED.get(plan.kind_of(room), [])
	var here: Array[int] = []
	for f in lit:
		if plan.furniture[f]["room"] == room:
			here.append(f)
	var native_host: bool = HouseFurnisher._uses_native_domestic_fireplace(plan) \
		and not HouseGeometry.hearth_breast(plan).is_empty()
	if here.is_empty() and wants_one and native_host:
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if int(breast.get("room", -1)) != room or int(breast.get("wall", -1)) != wall \
				or absf(float(breast.get("depth", 0.0)) - HouseGeometry.BREAST_DEPTH) > 0.001:
			failures.append("hearth: ordinary fireplace host is detached from its planned flue wall")
	elif here.is_empty() and wants_one:
		if plan.was_dropped(room, "hearth") or not HouseFurnishProgrammeCheck.could_hold(plan, room, "hearth"):
			warnings.append("hearth: room %d has the chimney on wall %d and no fire under it"
				% [room, wall])
		else:
			failures.append("hearth: room %d has the chimney on wall %d and no fire under it"
				% [room, wall])
	for f in here:
		var on: int = wall_of(plan, plan.furniture[f])
		if on != wall:
			failures.append("hearth: the hearth in room %d stands on wall %d but the chimney is on wall %d"
				% [room, on, wall])


## Which of the room's four walls a piece has its back to, indexed the way
## HouseGeometry.room_walls() indexes them. Its facing says it: a piece in a
## corner touches two walls and only one of them is behind it.
static func wall_of(plan: HousePlan, p: Dictionary) -> int:
	var yaw: float = float(p["yaw"])
	var back := Vector2(sin(yaw), cos(yaw))
	var room := int(p.get("room", -1))
	if room >= 0 and room < plan.room_count() and plan.is_polygonal(room):
		var walls := HouseGeometry.room_walls(plan, room)
		var best := -1
		var facing := -INF
		for index in range(walls.size()):
			var dot := back.dot(-Vector2(walls[index].normal))
			if dot > facing:
				best = index
				facing = dot
		return best
	if absf(back.y) >= absf(back.x):
		return 1 if back.y > 0.0 else 0
	return 3 if back.x > 0.0 else 2


## A row is straight, evenly pitched, all facing the same way, and every
## copy's use zone is the same shared aisle strip. `HouseFurnishPlacement.place_row`
## builds a row that way by construction; this measures the result the way
## every other rule here is measured -- from the placements alone, trusting
## nothing about how they got there.
const ROW_STRAIGHT_TOL := 0.05
const ROW_PITCH_TOL := 0.02

func check_row(plan: HousePlan) -> void:
	var groups: Dictionary = {}
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var group: String = String(p.get("row", ""))
		if group == "":
			continue
		if not groups.has(group):
			groups[group] = []
		groups[group].append(f)
	for group in groups:
		_check_one_row(plan, groups[group])


func _check_one_row(plan: HousePlan, members: Array) -> void:
	if members.size() < 2:
		return
	var pts: Array[Vector2] = []
	var yaw0: float = float(plan.furniture[members[0]]["yaw"])
	var zone0: Rect2 = plan.furniture[members[0]]["zone"]
	var who0: String = HouseFurnishCheck.who(plan, members[0])
	for f in members:
		var p: Dictionary = plan.furniture[f]
		pts.append(Rect2(p["rect"]).get_center())
		if not is_equal_approx(float(p["yaw"]), yaw0) \
				and absf(float(p["yaw"]) - yaw0) > 0.01:
			failures.append("row: %s does not face the same way as %s"
				% [HouseFurnishCheck.who(plan, f), who0])
		var zone: Rect2 = p["zone"]
		if not zone.is_equal_approx(zone0):
			failures.append("row: %s does not share the same aisle as %s"
				% [HouseFurnishCheck.who(plan, f), who0])
	# collinearity: how far each centre strays from the line through the two ends
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var along: Vector2 = (b - a)
	var len: float = along.length()
	if len > 0.01:
		var dir: Vector2 = along / len
		var normal := Vector2(-dir.y, dir.x)
		for i in range(pts.size()):
			var off: float = absf((pts[i] - a).dot(normal))
			if off > ROW_STRAIGHT_TOL:
				failures.append("row: %s is %.2fm off the line of its row"
					% [HouseFurnishCheck.who(plan, members[i]), off])
	# even pitch: consecutive centres (sorted along the row) the same distance apart
	var order: Array = members.duplicate()
	order.sort_custom(func(x: int, y: int) -> bool:
		return Rect2(plan.furniture[x]["rect"]).get_center().distance_to(a) \
			< Rect2(plan.furniture[y]["rect"]).get_center().distance_to(a))
	var pitches: Array[float] = []
	for i in range(1, order.size()):
		var d: float = Rect2(plan.furniture[order[i]]["rect"]).get_center() \
			.distance_to(Rect2(plan.furniture[order[i - 1]]["rect"]).get_center())
		pitches.append(d)
	if pitches.size() > 1:
		var ref: float = pitches[0]
		for i in range(1, pitches.size()):
			if absf(pitches[i] - ref) > ROW_PITCH_TOL:
				failures.append("row: the pitch between %s varies (%.2fm vs %.2fm)"
					% [who0, pitches[i], ref])
	# the shared aisle has to be real floor, deep enough to walk, and every
	# member's own use zone has to be exactly it -- not a private zone that
	# happens to overlap
	if zone0.size.x > 0.0:
		var depth: float = minf(zone0.size.x, zone0.size.y)
		if depth < HouseGeometry.PATH_MIN - TOL:
			failures.append("row: the aisle behind %s is only %.2fm wide"
				% [who0, depth])


## Which of the room's four walls a rectangle has its BACK to, or -1 when it
## stands free of all of them. Measured from the gaps, the way LAY-002's
## placer measures it -- yaw says which way a piece looks, not what it is
## pushed up against, and a corner piece looks whichever way it was authored.
const FS_BACK_TOL := 0.14
const BACKING_EPS := 0.000001

static func fs_back_wall(plan: HousePlan, room: int, rect: Rect2, piece: Dictionary = {}) -> int:
	if plan.is_polygonal(room):
		var walls := HouseGeometry.room_walls(plan, room)
		var found := -1
		var nearest := FS_BACK_TOL
		for i in range(walls.size()):
			var wall: Dictionary = walls[i]
			var normal: Vector2 = wall.normal
			if not piece.is_empty():
				var yaw: float = float(piece.yaw)
				if normal.dot(Vector2(-sin(yaw), -cos(yaw))) < 0.999:
					continue
			var extent := fs_projection(rect, normal, piece)
			var gap: float = absf(extent.x - Vector2(wall.from).dot(normal))
			if not piece.is_empty() and piece.get("mounted", false):
				gap = absf((rect.get_center() - Vector2(wall.from)).dot(normal))
			if gap < nearest:
				nearest = gap
				found = i
		return found
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var gaps := [rect.position.y - f.position.y, f.end.y - rect.end.y,
		rect.position.x - f.position.x, f.end.x - rect.end.x]
	var best := -1
	var best_gap := FS_BACK_TOL
	for i in range(4):
		if float(gaps[i]) < best_gap:
			best_gap = float(gaps[i])
			best = i
	return best


static func fs_wall_normal(plan: HousePlan, room: int, wi: int) -> Vector2:
	return HouseGeometry.room_walls(plan, room)[wi].normal


static func fs_projection(rect: Rect2, axis: Vector2, piece: Dictionary = {}) -> Vector2:
	var center := rect.get_center().dot(axis)
	var half := rect.size.dot(axis.abs()) * 0.5
	if not piece.is_empty():
		var yaw: float = float(piece.yaw)
		var size: Vector2 = PropCatalog.footprint(piece.key) * float(piece.get("scale", 1.0))
		half = (size.x * absf(Vector2(cos(yaw), -sin(yaw)).dot(axis)) \
			+ size.y * absf(Vector2(-sin(yaw), -cos(yaw)).dot(axis))) * 0.5
	return Vector2(center - half, center + half)


static func fs_wall_lit(plan: HousePlan, room: int, wi: int) -> bool:
	for w in plan.windows_of(room):
		if Vector2(plan.windows[w]["normal"]).dot(fs_wall_normal(plan, room, wi)) < -0.999:
			return true
	return false
