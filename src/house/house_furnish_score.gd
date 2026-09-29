class_name HouseFurnishScore
extends RefCounted
## Scores candidate placements and measures their wall relationships.

# ---- affinity: how strongly a piece's wishes outweigh a coin toss ----
## The dice are the last word only between placements the rules cannot tell
## apart. Before LAY-002 the jitter was 0.5 against a 0.6 centring term, which
## is not a tie-break, it is the decision.
const JITTER := 0.1
## Beyond this many metres "near" and "far" stop caring.
const AFF_REACH := 4.0
const NEAR_W := 2.0
const FAR_W := 2.0
## Clutter out of the traffic. Softened rather than clamped, so that of four
## corners the one furthest from every door always scores highest.
const DOOR_W := 4.0
const DOOR_SOFT := 3.0
const DAYLIGHT_W := 2.5
## How hard a daylit piece is pushed along the wall to stand beside the window
## rather than square across it, and over what distance.
const BESIDE_W := 1.5
const BESIDE_REACH := 1.5
## The penalty for a wall a piece asked not to be on -- big enough that any
## other wall wins, small enough that the piece still goes in if none does.
const WRONG_WALL := 3.0
## How close a back has to be to a wall to count as standing against it.
const BACK_TOL := 0.14
## A table draws up to the fire: it stands off the middle of the room toward
## the hearth wall by this fraction of the room's half-depth, and wants no
## more than that -- a table in the fireplace is not a table by the fire.
const FOCUS_W := 6.0
const FOCUS_WANT := 0.36
## A shelf over the bench it serves; a chandelier over the table.
const OVER_W := 5.0
## A pair of sconces, mirrored about the door or the fire.
const FLANK_W := 6.0
const FLANK_IDEAL := 0.9
## Wall a pair needs either side of what it flanks: the lamp's own half width
## and the clearance _on_opening() keeps around a door, with a little over.
const FLANK_REACH := 1.5
const FLANK_TOL := 0.6
## Step along a wall when hunting for somewhere to hang something. Finer than
## PROBE_STEP because the mirror of a sconce is judged in centimetres.
const MOUNT_STEP := 0.06
## The focus piece is pinned to HousePlan.focus: it loses this much per metre
## it stands from the point the planner chose, which beats the wall-middle
## term and the jitter within a hand's breadth. A piece that must look at the
## door is pushed to face it by FACE_W; a table in the focus room is pushed to
## lie broadside to the focus by the same weight. (INT-002)
const PIN_W := 4.0
## How far either side of the pin a pinned piece is searched for.
const PIN_SEARCH := 0.9
const FACE_W := 6.0
## How far off the planner's point the focus piece may stand and still count
## as being there. HouseFurnishCheck measures with the same figure.
const FOCUS_TOL := 0.3


## What a piece WANTS, over and above fitting: one number per candidate
## position, read from the `affinity` block PropCatalog carries per prop.
##
## Before this, every placer ended in "does it fit, plus a random number", and
## the random number was half the score. A dozen rules that anybody would say
## out loud -- the bench goes by the window, the bookcase does not go by the
## fire, the barrels go where nobody walks, the second sconce mirrors the
## first -- are all one expression here, so the placers stay five short
## searches over the positions the room allows.
##
## Pure: the same plan, room and candidate always give the same score. Nothing
## in here draws on an RNG, which is what lets the checks re-derive it.
static func _affinity(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var key: String = String(cand["key"])
	var aff: Dictionary = PropCatalog.affinity(key)
	if aff.is_empty():
		# a counter or a cauldron has no wishes of its own, but it may still
		# be the piece the plan is arranged around
		return _pin_bonus(plan, room, cand)
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	# Only these preferences inspect a wall. Free-standing tables ask about
	# the fire/focus instead, so rebuilding the room floor for every table
	# probe cannot change their score.
	var wall := -1
	if aff.has("daylight") or bool(aff.get("avoid_window_wall", false)) \
			or bool(aff.get("avoid_hearth_wall", false)):
		wall = _back_wall_index(plan, room, rect, cand)
		if PropCatalog.category(key) == "bed":
			wall = _bed_head_wall(plan, room, cand)
	var score := 0.0

	# daylight: a workbench wants the window wall, a bookcase wants any other
	if aff.has("daylight"):
		var want: float = float(aff["daylight"])
		if wall >= 0:
			if _wall_has_window(plan, room, wall):
				score += want * DAYLIGHT_W
				# Beside the window, not across it. A bench dead in front of
				# the glass has the same light and leaves no wall above it
				# for the shelf that serves it -- worth a nudge along the
				# wall, never worth a different wall.
				if want > 0.0:
					score -= BESIDE_W * _window_crowding(plan, room, rect, wall)
		else:
			var wd: float = _nearest_window_dist(plan, room, c)
			if wd >= 0.0:
				score += want * DAYLIGHT_W * clampf(1.0 - wd / AFF_REACH, 0.0, 1.0)

	for near_cat in aff.get("near", []):
		var nd: float = _nearest_cat_dist(plan, room, String(near_cat), c)
		if nd >= 0.0:
			score += NEAR_W * clampf(1.0 - nd / AFF_REACH, 0.0, 1.0)
	for far_cat in aff.get("far", []):
		var fd: float = _nearest_cat_dist(plan, room, String(far_cat), c)
		if fd >= 0.0:
			score += FAR_W * (fd / (fd + AFF_REACH))

	# Out of the traffic. Softened rather than clamped: of four corners the one
	# furthest from every door has to score strictly highest, however big the
	# room is, or the rule decides nothing in a large one.
	if bool(aff.get("away_from_doors", false)):
		var dd: float = _nearest_door_dist(plan, room, c)
		if dd < INF:
			score += DOOR_W * (dd / (dd + DOOR_SOFT))

	if wall >= 0 and bool(aff.get("avoid_window_wall", false)) \
			and _wall_has_window(plan, room, wall):
		score -= WRONG_WALL
	if wall >= 0 and bool(aff.get("avoid_hearth_wall", false)) \
			and plan.hearth_room() == room and plan.hearth_wall() == wall:
		score -= WRONG_WALL

	if String(aff.get("focus", "")) == "hearth":
		# the placer looks the fire up once for the whole search; a caller
	# scoring a single candidate has not, and pays for it here
		var h := Vector2(INF, INF)
		if cand.has("focus_point"):
			h = cand["focus_point"]
		else:
			h = _hearth_point(plan, room)
		score += _focus_bonus(plan, room, c, h)
	if aff.has("over"):
		score += _over_bonus(plan, room, cand, aff["over"])
	if aff.has("flank"):
		score += _flank_bonus(plan, room, cand)
	if PropCatalog.category(key) == "bed":
		score += _bed_bonus(plan, room, cand)
	if String(aff.get("face", "")) == "focus":
		score += _broadside_bonus(plan, room, rect)
	return score + _pin_bonus(plan, room, cand)


## The focus piece itself: pinned to the point the planner chose, and turned
## to look at the door when the plan says it must. Every other piece scores 0
## here, so this is outside the affinity block -- a hearth has no affinity of
## its own and is still the focus of the room it is in.
static func _pin_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	if plan.focus_room() != room or plan.focus.get("placed", false):
		return 0.0
	if PropCatalog.category(String(cand["key"])) != plan.focus_cat():
		return 0.0
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	var score: float = -PIN_W * c.distance_to(plan.focus_pos())
	if plan.focus_faces_door():
		var door: int = focus_door(plan, room)
		if door >= 0:
			var to: Vector2 = Vector2(plan.doors[door]["pos"]) - c
			if to.length() > 0.01:
				score += FACE_W * _facing_of(float(cand["yaw"])).dot(to.normalized())
	return score


## A table in the focus room lies broadside to the focus: its long axis at
## right angles to the line the focus looks along, so a side of it faces the
## fire. A square table has no long axis and no preference.
static func _broadside_bonus(plan: HousePlan, room: int, rect: Rect2) -> float:
	if plan.focus_room() != room or plan.focus_cat() == "table":
		return 0.0
	if absf(rect.size.x - rect.size.y) < 0.1:
		return 0.0
	var axis := Vector2(1, 0) if rect.size.x > rect.size.y else Vector2(0, 1)
	return FACE_W * (1.0 - absf(axis.dot(_facing_of(plan.focus_facing()))))


## The door the focus is judged against: the front door when it opens into
## this room, else the room's first door, else -1.
static func focus_door(plan: HousePlan, room: int) -> int:
	var e: int = plan.entrance()
	if e >= 0 and int(plan.doors[e]["a"]) == room:
		return e
	var doors: Array[int] = plan.doors_of(room)
	return doors[0] if not doors.is_empty() else -1


## The four walls of a room, in the order HouseGeometry.room_walls() gives
## them, as inward normals.
static func _wall_normal(plan: HousePlan, room: int, wi: int) -> Vector2:
	return HouseGeometry.room_walls(plan, room)[wi].normal


## Which wall a rectangle has its back to, or -1 when it stands free. Measured
## rather than passed in, because _affinity() is handed a candidate and has to
## give the same answer wherever the candidate came from.
static func _back_wall_index(plan: HousePlan, room: int, rect: Rect2, piece: Dictionary = {}) -> int:
	if plan.is_polygonal(room):
		var walls := HouseGeometry.room_walls(plan, room)
		var found := -1
		var nearest := BACK_TOL
		for i in range(walls.size()):
			var wall: Dictionary = walls[i]
			var normal: Vector2 = wall.normal
			if not piece.is_empty() and normal.dot(_facing_of(float(piece.yaw))) < 0.999:
				continue
			var extent := _piece_projection(rect, normal, piece)
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
	var best_gap := BACK_TOL
	for i in range(4):
		if float(gaps[i]) < best_gap:
			best_gap = float(gaps[i])
			best = i
	return best


## Signed projection of an oriented measured footprint. Taking abs() of a
## diagonal tangent changes its direction and silently chooses another wall.
static func _piece_projection(rect: Rect2, axis: Vector2, piece: Dictionary = {}) -> Vector2:
	var middle := rect.get_center().dot(axis)
	var half := rect.size.dot(axis.abs()) * 0.5
	if not piece.is_empty():
		var yaw: float = float(piece.yaw)
		var size: Vector2 = PropCatalog.footprint(piece.key) * float(piece.get("scale", 1.0))
		half = (size.x * absf(Vector2(cos(yaw), -sin(yaw)).dot(axis)) \
			+ size.y * absf(_facing_of(yaw).dot(axis))) * 0.5
	return Vector2(middle - half, middle + half)


## A corner bed can touch two walls. Its headboard, rather than whichever
## side happens to have the smaller rounding gap, determines daylight.
static func _bed_head_wall(plan: HousePlan, room: int, piece: Dictionary) -> int:
	var back := -_facing_of(float(piece.yaw))
	var depth: float = PropCatalog.footprint(piece.key).y * float(piece.get("scale", 1.0))
	var head: Vector2 = Rect2(piece.rect).get_center() + back * depth * 0.5
	var walls := HouseGeometry.room_walls(plan, room)
	var best := -1
	var gap := HouseGeometry.BED_HEAD_TOL
	for i in range(walls.size()):
		var wall: Dictionary = walls[i]
		if Vector2(wall.normal).dot(back) > -0.999:
			continue
		var distance := head.distance_to(Geometry2D.get_closest_point_to_segment(head, wall.from, wall.to))
		if distance < gap:
			gap = distance
			best = i
	return best


## How squarely this piece stands in front of the glass, 1 for dead centre and
## 0 once it is BESIDE_REACH along the wall from it. Continuous rather than a
## yes-or-no: a bench nudged just clear of the window still leaves no room for
## the shelf that serves it, because a shelf is kept a shelf-width off the
## opening as well.
static func _window_crowding(plan: HousePlan, room: int, rect: Rect2,
		wi: int) -> float:
	var n: Vector2 = _wall_normal(plan, room, wi)
	var along := Vector2(n.y, -n.x)
	var c: float = rect.get_center().dot(along)
	var worst := 0.0
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if Vector2(win["normal"]).dot(n) > -0.999:
			continue
		var d: float = absf(c - Vector2(win["pos"]).dot(along))
		worst = maxf(worst, clampf(1.0 - d / BESIDE_REACH, 0.0, 1.0))
	return worst


## A window record carries the OUTWARD normal of the wall it pierces, so it
## belongs to the wall whose inward normal is its opposite.
static func _wall_has_window(plan: HousePlan, room: int, wi: int) -> bool:
	var n: Vector2 = _wall_normal(plan, room, wi)
	for w in plan.windows_of(room):
		if Vector2(plan.windows[w]["normal"]).dot(n) < -0.999:
			return true
	return false


static func _nearest_window_dist(plan: HousePlan, room: int, c: Vector2) -> float:
	var best := -1.0
	for w in plan.windows_of(room):
		var d: float = c.distance_to(Vector2(plan.windows[w]["pos"]))
		if best < 0.0 or d < best:
			best = d
	return best


static func _nearest_door_dist(plan: HousePlan, room: int, c: Vector2) -> float:
	var best := INF
	for d in plan.doors_of(room):
		best = minf(best, c.distance_to(Vector2(plan.doors[d]["pos"])))
	return best


## Distance to the nearest piece of a category standing in this room, or -1
## when the room holds none. The fire is the exception: the planner names its
## wall before any furniture exists, so a bookcase can be kept away from it
## even while the hearth is still only a plan.
static func _nearest_cat_dist(plan: HousePlan, room: int, cat: String,
		c: Vector2) -> float:
	if cat == "focus":
		if plan.focus_room() != room or not plan.focus_pos().is_finite():
			return -1.0
		return c.distance_to(plan.focus_pos())
	var best := -1.0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat:
			continue
		var d: float = c.distance_to(Rect2(p["rect"]).get_center())
		if best < 0.0 or d < best:
			best = d
	if cat == "hearth" and best < 0.0:
		var h: Vector2 = _hearth_point(plan, room)
		if h.is_finite():
			best = c.distance_to(h)
	return best


## Where the fire in this room is, or an infinite vector when there is none:
## the hearth itself if it has been placed, otherwise the middle of the wall
## the planner gave the chimney.
static func _hearth_point(plan: HousePlan, room: int) -> Vector2:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) == "hearth":
			return Rect2(p["rect"]).get_center()
	if plan.hearth_room() != room or plan.hearth_wall() < 0:
		return Vector2(INF, INF)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var wall: Dictionary = walls[plan.hearth_wall()]
	return (Vector2(wall["from"]) + Vector2(wall["to"])) / 2.0


## A table in a room with a fire in it does not sit in the middle of the room:
## it draws up toward the fire. Rewarded up to FOCUS_WANT of the room's half
## depth and no further, so the table stops where a table would stop.
static func _focus_bonus(plan: HousePlan, room: int, c: Vector2,
		h: Vector2) -> float:
	if not h.is_finite():
		return 0.0
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var mid: Vector2 = f.get_center()
	var dir: Vector2 = h - mid
	if dir.length() < 0.01:
		return 0.0
	dir = dir.normalized()
	var half: float = absf(dir.x) * f.size.x / 2.0 + absf(dir.y) * f.size.y / 2.0
	var want: float = maxf(FOCUS_WANT * half, 0.05)
	return FOCUS_W * clampf((c - mid).dot(dir) / want, 0.0, 1.0)


## Above something: a chandelier over the table it lights, a shelf over the
## bench it serves. The ceiling case is a distance, the wall case is how much
## of the shelf actually overhangs the piece, along the wall they share.
static func _over_bonus(plan: HousePlan, room: int, cand: Dictionary,
		cats: Array) -> float:
	var key: String = String(cand["key"])
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	var hanging: bool = PropCatalog.has_tag(key, PropCatalog.CEILING)
	var wall: int = -1 if hanging else _back_wall_index(plan, room, rect, cand)
	var n: Vector2 = _wall_normal(plan, room, wall) if wall >= 0 else Vector2(1, 0)
	var along := Vector2(n.y, -n.x)
	var width: float = maxf(PropCatalog.size(key).x, 0.05)
	var best := 0.0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not PropCatalog.category(p["key"]) in cats:
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var host: Rect2 = p["rect"]
		if hanging:
			best = maxf(best, clampf(1.0 - c.distance_to(host.get_center()) / 2.0, 0.0, 1.0))
			continue
		if wall < 0 or _back_wall_index(plan, room, host, p) != wall:
			continue
		var interval := _piece_projection(host, along, p)
		var span: float = maxf(interval.y - interval.x, 0.05)
		var lo: float = maxf(c.dot(along) - width / 2.0, interval.x)
		var hi: float = minf(c.dot(along) + width / 2.0, interval.y)
		# against the narrower of the two: a shelf half a metre wider than the
		# bench it serves still hangs over the whole of it
		best = maxf(best, clampf((hi - lo) / minf(width, span), 0.0, 1.0))
	return OVER_W * best


## Sconces come in pairs, one either side of the door or the fire. The pair's
## station -- how far out from the centre the two of them hang -- is settled
## once, by _flank_anchor(), so the first lamp cannot take a spot its mate is
## unable to answer. The first is scored on reaching that station and the
## second on mirroring the first, which is what makes the pair read as a pair
## rather than as two lamps that happen to share a wall.
static func _flank_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var key: String = String(cand["key"])
	var cat: String = PropCatalog.category(key)
	# The widest lamp of the kind, not this one: the two halves of a pair are
	# drawn separately and need not be the same prop, and a station worked out
	# from one width is a station the other cannot answer.
	#
	# The placer hands the anchor in, having found it once for the whole wall
	# search; a caller that has not is given the same answer the slow way.
	# An explicitly empty anchor has already proved no pair station exists.
	var anchor: Dictionary = cand.get("flank_anchor", {})
	if not cand.has("flank_anchor"):
		anchor = _flank_anchor(plan, room, _widest_of(cat), cat)
	if anchor.is_empty():
		return 0.0
	var rect: Rect2 = cand["rect"]
	var wall: int = _flank_wall(plan, room, rect)
	if wall < 0:
		return 0.0
	var n: Vector2 = _wall_normal(plan, room, wall)
	var same_wall_cos := 0.999 if plan.is_polygonal(room) else 0.9
	if n.dot(Vector2(anchor["normal"])) < same_wall_cos:
		return -1.0                  # the pair belongs on the wall the door is in
	var along := Vector2(n.y, -n.x)
	var t: float = (rect.get_center() - Vector2(anchor["pos"])).dot(along)
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat or not p.get("mounted", false):
			continue
		var mate: Rect2 = p["rect"]
		if _flank_wall(plan, room, mate) != wall:
			continue
		# mirrored means the two offsets cancel: same distance, opposite sides
		var t2: float = (mate.get_center() - Vector2(anchor["pos"])).dot(along)
		return FLANK_W * clampf(1.0 - absf(t + t2) / FLANK_TOL, 0.0, 1.0)
	var dist: float = float(anchor.get("dist", FLANK_IDEAL))
	return FLANK_W * 0.5 * clampf(1.0 - absf(absf(t) - dist) / FLANK_TOL, 0.0, 1.0)


static func _flank_wall(plan: HousePlan, room: int, rect: Rect2) -> int:
	if plan.is_polygonal(room):
		return HouseGeometry.backing_wall(plan, room, rect, BACK_TOL)
	return _back_wall_index(plan, room, rect)


## The widest prop of a category, so a rule that has to hold for a pair drawn
## from it does not depend on which of them was drawn first.
static func _widest_of(cat: String) -> float:
	var w := 0.05
	for k in PropCatalog.of_category(cat):
		w = maxf(w, PropCatalog.size(k).x)
	return w


## What a pair of sconces is arranged about, and how far out the two of them
## stand: the fire if the room has one, otherwise a door, and failing both the
## middle of a wall -- a room whose only door is jammed into a corner has no
## symmetry to hang a pair about, and two lamps evenly set out on one wall
## still read as a pair where two lamps dropped wherever they fit do not.
##
## An anchor is only taken if BOTH stations are real wall: inside the room and
## clear of every other opening. Skipping that test is how one lamp ended up
## an arm's length from the door and its mate a metre and a half the other
## way, on the far side of a second doorway.
static func _flank_anchor(plan: HousePlan, room: int, width: float,
		cat: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	for i in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i]
		if PropCatalog.category(p["key"]) != "hearth":
			continue
		var wi: int = _flank_wall(plan, room, Rect2(p["rect"]))
		if wi < 0:
			continue
		var n: Vector2 = _wall_normal(plan, room, wi)
		var hc: Vector2 = Rect2(p["rect"]).get_center()
		var q: Vector2 = f.position if wi == 0 or wi == 2 else f.end
		if plan.is_polygonal(room):
			q = HouseGeometry.room_walls(plan, room)[wi].from
		# the point on the wall in line with the fire, so the pair is measured
		# along the wall it hangs on rather than out into the room
		var on_wall: Vector2 = hc + n * ((q - hc).dot(n))
		var reach: float = (absf(n.y) * Rect2(p["rect"]).size.x
			+ absf(n.x) * Rect2(p["rect"]).size.y) / 2.0
		candidates.append({"pos": on_wall, "normal": n, "reach": reach})
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		var dn: Vector2 = door["normal"]
		if (f.get_center() - Vector2(door["pos"])).dot(dn) < 0.0:
			dn = -dn
		candidates.append({"pos": door["pos"], "normal": dn,
			"reach": float(door["width"]) / 2.0})
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	for wi2 in range(walls.size()):
		candidates.append({
			"pos": (Vector2(walls[wi2]["from"]) + Vector2(walls[wi2]["to"])) / 2.0,
			"normal": Vector2(walls[wi2]["normal"]), "reach": 0.0,
		})
	for cand in candidates:
		var dist: float = _flank_station(plan, room, cand, width, cat)
		if dist > 0.0:
			cand["dist"] = dist
			return cand
	return {}


## How far either side of an anchor a pair can actually hang, or 0 when it
## cannot. Nearest first: a pair belongs close about what it flanks.
static func _flank_station(plan: HousePlan, room: int, anchor: Dictionary,
		width: float, cat: String) -> float:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var n: Vector2 = anchor["normal"]
	var pos: Vector2 = anchor["pos"]
	var along := Vector2(n.y, -n.x)
	var axis := along.abs()
	var lo: float = f.position.dot(axis) + width / 2.0 + 0.2
	var hi: float = f.end.dot(axis) - width / 2.0 - 0.2
	var t: float = pos.dot(axis)
	var first: float = maxf(float(anchor["reach"]) + width / 2.0 + 0.2, FLANK_IDEAL)
	var d: float = first
	var host := {}
	if plan.is_polygonal(room):
		for wall in HouseGeometry.room_walls(plan, room):
			if Vector2(wall.normal).dot(n) > 0.999 and absf((pos - Vector2(wall.from)).dot(n)) < 0.05:
				host = wall
				break
		if host.is_empty():
			return 0.0
	while d <= maxf(hi - lo, 0.0):
		var ok := true
		for side in [-1.0, 1.0]:
			var p: Vector2 = pos + along * (d * side)
			if not host.is_empty():
				var edge := Vector2(host.to) - Vector2(host.from)
				var station := (p - Vector2(host.from)).dot(edge.normalized())
				if station < width / 2.0 + 0.2 or station > edge.length() - width / 2.0 - 0.2:
					ok = false
					break
			if (host.is_empty() and (p.dot(axis) < lo or p.dot(axis) > hi)) 					or _on_opening(plan, room, p, n, width) 					or _crowds_mounted(plan, room, p, width, cat):
				# the pair's own half already hanging there does not count
				ok = false
				break
		if ok:
			return d
		d += MOUNT_STEP
	return 0.0


## Feng shui, and common sense: you want to see the door from the bed, but you
## do not want the bed in the doorway. The commanding position is out of the
## line of the door, with the headboard against solid wall -- which is also
## simply where a bed is out of the way. Folded into _affinity() by LAY-002.
static func _bed_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var bonus := 0.0
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		var dp: Vector2 = door["pos"]
		var dn: Vector2 = door["normal"]
		var rect: Rect2 = cand["rect"]
		var c: Vector2 = rect.get_center()
		# in the line of the door: the bed sits in the swim of everything
		# coming through it
		var along: float = absf((c - dp).dot(dn))
		var across: float = absf((c - dp).dot(Vector2(dn.y, -dn.x)))
		if across < (float(door["width"]) + rect.size.x) / 2.0:
			bonus -= 1.5
		else:
			bonus += 0.4
		bonus += clampf(along / 4.0, 0.0, 0.5)
	return bonus


## Is something already hanging here? Nothing else on a wall keeps mounted
## pieces apart -- they have no footprint on the floor for _fits() to test --
## and now that every one of them is scored rather than dropped at random, two
## shelves that both want the wall over the bench would hang in one another.
static func _crowds_mounted(plan: HousePlan, room: int, pos: Vector2,
		width: float, ignore_cat := "") -> bool:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not p.get("mounted", false):
			continue
		if not ignore_cat.is_empty() and PropCatalog.category(p["key"]) == ignore_cat:
			continue
		var other: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
		var c := Vector2(p["pos"].x, p["pos"].z)
		if c.distance_to(pos) < (width + other) / 2.0 + 0.1:
			return true
	return false


## Is this stretch of wall taken up by a door or a window?
static func _on_opening(plan: HousePlan, room: int, pos: Vector2, normal: Vector2,
		width: float) -> bool:
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and int(breast["room"]) == room and normal.dot(Vector2(breast["normal"])) > 0.99:
		var along := Vector2(-normal.y, normal.x)
		if absf((pos - Vector2(breast["centre"])).dot(along)) < (width + float(breast["width"])) * 0.5 + 0.05:
			return true # The room wall behind full-height masonry is not a mount.
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		if door["pos"].distance_to(pos) < (float(door["width"]) + width) / 2.0 + 0.15:
			return true
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if win["pos"].distance_to(pos) < (float(win["width"]) + width) / 2.0 + 0.15:
			return true
	return false


static func _facing_of(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))
