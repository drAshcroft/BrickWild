class_name HouseFurnishAffinityCheck
extends RefCounted
## Measurable prop affinity and plan focus rules.

const TOL := 0.03

var failures: Array = []
var warnings: Array = []


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])


## Every feng shui rule below reports the same way: a piece the furnisher had
## to compromise over -- one it dropped for walkability, or one it could find
## no wall for -- is a warning, and anything else is a defect. Exactly the
## shape the programme rule uses.
func _fs_report(plan: HousePlan, p: Dictionary, cat: String, msg: String) -> void:
	if p.get("free_standing", false) or plan.was_dropped(int(p["room"]), cat):
		warnings.append(msg)
	else:
		failures.append(msg)


## A bench is worked at, and a person works in the light. A workbench in a room
## with a window backs onto the wall that window is in, or at the very least
## stands within reach of it.
##
## The strict form -- the window wall itself -- is only possible if the room
## can give it. "Beside the window, not across it" means the run has to clear
## the window's own keep-clear as well as be long enough for the piece, and a
## workshop three metres deep with its window in the middle of a wall cannot
## do that however the bench is turned. Demanding it anyway is a failure the
## planner could not have avoided, and reporting it as a failure teaches
## nothing; this is the same shape the `shelf_over` rule already uses, where a
## station found but unused is a failure and no station at all is a warning.
const FS_WINDOW_REACH := 2.5
## Slack on the run test, so a bench that IS on the window wall is never
## reported as one that could not have been.
const FS_LIT_RUN_TOL := 0.12

func check_workbench_daylight(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "workbench":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		if plan.windows_of(room).is_empty():
			continue
		var wi: int = HouseFurnishSpatialCheck.fs_back_wall(plan, room, p["rect"], p)
		if wi >= 0 and HouseFurnishSpatialCheck.fs_wall_lit(plan, room, wi):
			continue
		var c: Vector2 = Rect2(p["rect"]).get_center()
		var near := INF
		for w in plan.windows_of(room):
			near = minf(near, c.distance_to(Vector2(plan.windows[w]["pos"])))
		if near <= FS_WINDOW_REACH:
			continue
		if _lit_run_takes_bench(plan, room, p):
			_fs_report(plan, p, "workbench",
				"workbench_daylight: %s works %.2fm from the nearest window, with its back to a blind wall"
				% [HouseFurnishCheck.who(plan, f), near])
		else:
			warnings.append("workbench_daylight: %s works %.2fm from the nearest window, and this room "
				% [HouseFurnishCheck.who(plan, f), near]
				+ "has no clear stretch of its window wall long enough for the bench")


## Could this room have put the bench on a wall that has a window?
##
## The run a piece is offered on is the wall LESS whatever the window in it
## keeps clear, because a bench stood in front of a window is the one
## arrangement this whole rule exists to prevent. Both pieces are measured, so
## a room that could have done it and did not still fails.
static func _lit_run_takes_bench(plan: HousePlan, room: int, p: Dictionary) -> bool:
	var rect: Rect2 = p["rect"]
	var span: float = maxf(rect.size.x, rect.size.y) + FS_LIT_RUN_TOL
	for wi in plan.windows_of(room):
		if not _lit_wall_of_window(plan, room, wi):
			continue
		if _clear_run(plan, room, wi) >= span:
			return true
	return false


## Which of this room's walls, if any, carries the window `wi`.
static func _lit_wall_of_window(plan: HousePlan, room: int, wi: int) -> int:
	var walls := HouseGeometry.room_walls(plan, room)
	var w: Dictionary = plan.windows[wi]
	var pos: Vector2 = w["pos"]
	var n: Vector2 = w["normal"]
	for i in walls.size():
		if absf((walls[i]["normal"] as Vector2).dot(n)) < 0.9:
			continue
		var seg: Vector2 = (walls[i]["to"] as Vector2) - (walls[i]["from"] as Vector2)
		if seg.length_squared() <= 0.0:
			continue
		var t: float = (pos - (walls[i]["from"] as Vector2)).dot(seg) / seg.length_squared()
		if t >= 0.0 and t <= 1.0:
			return i
	return -1


## The longest unbroken stretch of window wall `wi`, measured along the wall and
## with the window's own clear area taken out of it.
static func _clear_run(plan: HousePlan, room: int, wi: int) -> float:
	var walls := HouseGeometry.room_walls(plan, room)
	var lit := _lit_wall_of_window(plan, room, wi)
	if lit < 0 or lit >= walls.size():
		return 0.0
	var a: Vector2 = walls[lit]["from"]
	var b: Vector2 = walls[lit]["to"]
	var run: float = (b - a).length()
	if run <= 0.0:
		return 0.0
	var along: Vector2 = (b - a) / run
	var clear := HouseGeometry.window_clear_rect(plan.windows[wi])
	var lo := INF
	var hi := -INF
	for corner in [clear.position, Vector2(clear.end.x, clear.position.y),
			Vector2(clear.position.x, clear.end.y), clear.end]:
		var s: float = (corner - a).dot(along)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	lo = maxf(lo, 0.0)
	hi = minf(hi, run)
	return maxf(0.0, lo + (run - hi))


## Heat and parchment do not mix: a bookcase keeps off the wall the chimney is
## in. No generated house has ever put one there; the rule is kept honest by
## the records-room fixture, where the fire is walked round all four walls.
func check_bookcase_heat(plan: HousePlan) -> void:
	var room: int = plan.hearth_room()
	if room < 0 or plan.hearth_wall() < 0:
		return
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bookcase":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		if HouseFurnishSpatialCheck.fs_back_wall(plan, room, p["rect"], p) != plan.hearth_wall():
			continue
		_fs_report(plan, p, "bookcase",
			"bookcase_heat: %s stands against wall %d, which is the chimney wall"
			% [HouseFurnishCheck.who(plan, f), plan.hearth_wall()])


## You do not sleep with the draught and the daylight at your head. A bed takes
## any wall in the room except the one the window is in.
## Generated houses hold this in 100% of cases, so it fails outright.
func check_bed_window(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bed":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		if plan.windows_of(room).is_empty():
			continue
		# Measure the headboard plane; the bed's SIDE may also touch a
		# window wall in a corner without putting glazing behind its head.
		var yaw: float = float(p.yaw)
		var back := Vector2(sin(yaw), cos(yaw))
		var depth: float = PropCatalog.footprint(p.key).y * float(p.get("scale", 1.0))
		var head: Vector2 = Rect2(p.rect).get_center() + back * depth * 0.5
		var wi := -1
		var best := HouseGeometry.BED_HEAD_TOL
		var walls := HouseGeometry.room_walls(plan, room)
		for wall_index in range(walls.size()):
			var wall: Dictionary = walls[wall_index]
			if Vector2(wall.normal).dot(back) > -0.999:
				continue
			var gap := head.distance_to(Geometry2D.get_closest_point_to_segment(head, wall.from, wall.to))
			if gap < best:
				best = gap
				wi = wall_index
		if wi < 0 or not HouseFurnishSpatialCheck.fs_wall_lit(plan, room, wi):
			continue
		var msg := "bed_window: the head of %s is under the window in wall %d" % [HouseFurnishCheck.who(plan, f), wi]
		# a room whose every other wall is glazed or carries the chimney has
		# no dark wall to offer the bed: that is the room, not the placer
		var dark := false
		var span: float = maxf(Rect2(p["rect"]).size.x, Rect2(p["rect"]).size.y)
		for other in range(walls.size()):
			if other == wi or HouseFurnishSpatialCheck.fs_wall_lit(plan, room, other):
				continue
			if plan.hearth_room() == room and plan.hearth_wall() == other:
				continue
			# and long enough, clear of its doors, to take the bed
			if _fs_clear_wall_run(plan, room, other) < span + 0.1:
				continue
			dark = true
		if dark:
			_fs_report(plan, p, "bed", msg)
		else:
			warnings.append(msg)


## Length of real masonry available on an edge. The rectangular planner's
## axis-coordinate span is intentionally retained for rectangular rooms.
static func _fs_clear_wall_run(plan: HousePlan, room: int, wi: int) -> float:
	if not plan.is_polygonal(room):
		var span := HousePlanFeatures.clear_wall_span(plan, room, wi)
		return span.y - span.x
	var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wi]
	var a: Vector2 = wall.from
	var b: Vector2 = wall.to
	var normal: Vector2 = wall.normal
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var cuts: Array[Vector2] = []
	for door_index in plan.doors_of(room):
		var door: Dictionary = plan.doors[door_index]
		var position: Vector2 = door.pos
		if absf((position - a).dot(normal)) > HouseGeometry.DOOR_CLEAR:
			continue
		var station := (position - a).dot(along)
		var half := float(door.width) * 0.5 + HouseGeometry.DOOR_CLEAR
		cuts.append(Vector2(station - half, station + half))
	cuts.sort_custom(func(x: Vector2, y: Vector2): return x.x < y.x)
	var cursor := 0.0
	var longest := 0.0
	for cut in cuts:
		longest = maxf(longest, clampf(cut.x, 0, length) - cursor)
		cursor = maxf(cursor, clampf(cut.y, 0, length))
	return maxf(longest, length - cursor)


## The table in the room with the fire in it is drawn up toward the fire, not
## pushed away from it: its centre sits off the middle of the room, along the
## line to the hearth.
##
## Tolerance. LAY-002's placer achieves the full offset (0.30 of the room's
## half-depth, the figure `_affinity_sweep` measures) in 89.5% of cases. The
## rest are halls where the fire side of the room is already taken -- by the
## seats drawn round it, by the dresser, by the stair -- and the table is where
## the floor was. Measured on the offset alone those are indistinguishable from
## a table that simply ignored the fire, so the offset decides the warning and
## the FLOOR decides the defect: a table on the far side of the room whose
## mirror image on the fire side is empty floor could have stood by the fire
## and did not.
const FS_FOCUS_WANT := 0.30
const FS_FOCUS_FAIL := -0.15

func check_table_focus(plan: HousePlan) -> void:
	var room: int = plan.hearth_room()
	if room < 0 or plan.hearth_wall() < 0:
		return
	var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var focus := Vector2(INF, INF)
	for i in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i]["key"]) == "hearth":
			focus = Rect2(plan.furniture[i]["rect"]).get_center()
	if not focus.is_finite():
		var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
		focus = (Vector2(walls[plan.hearth_wall()]["from"])
			+ Vector2(walls[plan.hearth_wall()]["to"])) / 2.0
	var mid: Vector2 = f_rect.get_center()
	var dir: Vector2 = focus - mid
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var half: float = absf(dir.x) * f_rect.size.x / 2.0 + absf(dir.y) * f_rect.size.y / 2.0
	for i2 in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i2]
		if PropCatalog.category(p["key"]) != "table" or p.get("mounted", false):
			continue
		if int(p["host"]) >= 0 or String(p.get("row", "")) != "":
			continue
		# A table the PLAN pinned is where the plan put it. A great hall high
		# table stands on the dais at the upper end and the fire is on a side
		# wall behind the trestles: measuring that table against the fire is
		# measuring the plan against a rule the plan already answered (INT-002).
		if plan.focus_cat() == "table" and plan.focus_room() == room \
				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) \
					< FOCUS_TOL:
			continue
		var off: float = (Rect2(p["rect"]).get_center() - mid).dot(dir)
		if off >= FS_FOCUS_WANT * half:
			continue
		if off >= FS_FOCUS_FAIL * half:
			warnings.append("table_focus: %s stands %.2fm toward the fire, short of the %.2fm the room allows"
				% [HouseFurnishCheck.who(plan, i2), off, FS_FOCUS_WANT * half])
		elif _fs_mirror_free(plan, room, i2, dir, -off):
			_fs_report(plan, p, "table",
				"table_focus: %s stands %.2fm on the far side of the room from the fire"
				% [HouseFurnishCheck.who(plan, i2), -off])
		else:
			warnings.append("table_focus: %s stands %.2fm on the far side of the room from the fire, and the fire side of it is full"
				% [HouseFurnishCheck.who(plan, i2), -off])


## Could this piece have stood the same distance the OTHER side of the middle
## of the room, toward the fire? Its own seats move with it, so they do not
## count as being in its way.
static func _fs_mirror_free(plan: HousePlan, room: int, me: int, dir: Vector2,
		back: float) -> bool:
	var rect: Rect2 = plan.furniture[me]["rect"]
	var moved: Rect2 = Rect2(rect.position + dir * (2.0 * back), rect.size)
	if not HouseGeometry.room_floor_rect(plan, room).grow(0.05).encloses(moved):
		return false
	for f in plan.furniture_of(room):
		if f == me:
			continue
		var q: Dictionary = plan.furniture[f]
		if q.get("mounted", false) or int(q["host"]) >= 0:
			continue
		var cat: String = PropCatalog.category(q["key"])
		if cat == "seat" or cat == "bench":
			continue
		var over: Rect2 = Rect2(q["rect"]).intersection(moved)
		if over.size.x > TOL and over.size.y > TOL:
			return false
		var zone: Rect2 = q["zone"]
		if zone.size.x > 0.0:
			var zover: Rect2 = zone.intersection(moved)
			if zover.size.x > TOL and zover.size.y > TOL:
				return false
	# and it would have to be out of the way of every door, which is the other
	# reason the placer leaves the middle of a hall alone
	for d in plan.doors_of(room):
		for side in [-1.0, 1.0]:
			var clear: Rect2 = HouseGeometry.door_clear_rect(plan.doors[d], side)
			var dover: Rect2 = clear.intersection(moved)
			if dover.size.x > TOL and dover.size.y > TOL:
				return false
	return true


## Two lamps in a room are a pair: one wall, and the same distance either side
## of something -- the door, the fire, or the middle of the wall they share.
## One lamp is a lamp and three are a scatter; only a pair can be lopsided.
##
## Tolerance. LAY-002 measures the strict form -- same wall AND mirrored -- at
## 96%; the shortfall is rooms with no wall long enough to hang a pair on,
## where the furnisher has no station to mirror about and puts the two lamps
## wherever there is masonry. So a pair that is half right (same wall, or
## mirrored across two of them) warns, and a pair that is neither is a defect
## only when some wall of the room could actually have carried the two of them
## either side of its door, its fire or its own middle.
const FS_MIRROR_TOL := 0.15
## The station a pair hangs at, matching the furnisher's own FLANK_IDEAL and
## FLANK_REACH: it settles on one station for the whole room before it hangs
## either lamp, so a room where only some far wider or narrower spacing would
## have fitted is a room where it had no pair to hang.
const FS_PAIR_MIN := 0.9
const FS_PAIR_MAX := 2.1

func check_sconce_pair(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var sc: Array[int] = []
		for i in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[i]["key"]) == "sconce":
				sc.append(i)
		if sc.size() != 2:
			continue
		var w1: int = _fs_pair_wall(plan, room, plan.furniture[sc[0]]["rect"])
		var w2: int = _fs_pair_wall(plan, room, plan.furniture[sc[1]]["rect"])
		var same: bool = w1 >= 0 and w1 == w2
		var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var n := Vector2.UP
		if plan.is_polygonal(room) and w1 >= 0:
			n = HouseGeometry.room_walls(plan, room)[w1].normal
		elif not plan.is_polygonal(room):
			n = HouseFurnishSpatialCheck.fs_wall_normal(plan, room, w1 if w1 >= 0 else 0)
		var along := Vector2(n.y, -n.x)
		var anchors: Array[Vector2] = [(f_rect.position + f_rect.end) / 2.0]
		if plan.is_polygonal(room) and w1 >= 0:
			var wall: Dictionary = HouseGeometry.room_walls(plan, room)[w1]
			anchors.append((Vector2(wall.from) + Vector2(wall.to)) / 2.0)
		for i2 in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[i2]["key"]) == "hearth":
				anchors.append(Rect2(plan.furniture[i2]["rect"]).get_center())
		for d in plan.doors_of(room):
			anchors.append(plan.doors[d]["pos"])
		var t1: float = Rect2(plan.furniture[sc[0]]["rect"]).get_center().dot(along)
		var t2: float = Rect2(plan.furniture[sc[1]]["rect"]).get_center().dot(along)
		var mirrored := false
		for a in anchors:
			if absf(t1 + t2 - 2.0 * a.dot(along)) <= FS_MIRROR_TOL:
				mirrored = true
		if same and mirrored:
			continue
		var where := "lopsided on wall %d" % w1 if same else "on walls %d and %d" % [w1, w2]
		var msg := "sconce_pair: the two lamps in room %d (%s) are %s" \
			% [room, String(plan.kind_of(room)), where]
		if same or mirrored or not pair_fits(plan, room):
			warnings.append(msg)
		else:
			failures.append(msg)


static func _fs_pair_wall(plan: HousePlan, room: int, rect: Rect2) -> int:
	if plan.is_polygonal(room):
		return HouseGeometry.backing_wall(plan, room, rect, HouseFurnishSpatialCheck.FS_BACK_TOL)
	return HouseFurnishSpatialCheck.fs_back_wall(plan, room, rect)


## Could a pair have hung on one wall at all? The same question again, asked
## of two lamps at once: a wall, a station on it -- its door, its fire or its
## own middle -- and two spots the same distance either side of that station,
## both far enough from the lamp's own width, both clear of the openings and of
## what is already on the wall. A room with no such wall has no pair to be had,
## and the two lamps it was given hang wherever there was masonry.
static func pair_fits(plan: HousePlan, room: int) -> bool:
	# the WIDEST lamp in the catalogue, not the one that was hung: the
	# furnisher works its station out from that (_widest_of), because the two
	# halves of a pair need not be the same prop, so a station this room could
	# not have offered the widest is a station it never had
	var width := 0.05
	for key in PropCatalog.of_category("sconce"):
		width = maxf(width, PropCatalog.size(key).x)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	for wi in range(walls.size()):
		var a: Vector2 = walls[wi]["from"]
		var b: Vector2 = walls[wi]["to"]
		var run: float = (b - a).length()
		if run < width + 0.4:
			continue
		var along: Vector2 = (b - a) / run
		var lo: float = width / 2.0 + 0.2
		var hi: float = run - width / 2.0 - 0.2
		var anchors: Array[float] = [run / 2.0]
		for d in plan.doors_of(room):
			var dp: Vector2 = plan.doors[d]["pos"]
			if absf((dp - a).cross(along)) < 0.2:
				anchors.append((dp - a).dot(along))
		for f2 in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[f2]["key"]) != "hearth":
				continue
			if _fs_pair_wall(plan, room, plan.furniture[f2]["rect"]) != wi:
				continue
			anchors.append((Rect2(plan.furniture[f2]["rect"]).get_center() - a).dot(along))
		for anchor in anchors:
			var gap: float = maxf(width + 0.1, FS_PAIR_MIN)
			while gap <= minf(run / 2.0, FS_PAIR_MAX):
				var t1: float = anchor - gap
				var t2: float = anchor + gap
				if t1 >= lo and t2 <= hi:
					var p1: Vector2 = a + along * t1
					var p2: Vector2 = a + along * t2
					var ok1: bool = not _fs_on_opening(plan, room, p1, width) and not _fs_crowded(plan, room, p1, width, "sconce")
					var ok2: bool = not _fs_on_opening(plan, room, p2, width) and not _fs_crowded(plan, room, p2, width, "sconce")
					if ok1 and ok2:
						return true
				gap += 0.06
	return false


## A shelf serves the bench or counter under it: it hangs on the same wall,
## over the piece it belongs to.
##
## Tolerance. The strict form -- half the shelf's width over the host's span,
## which is what `_affinity_sweep` counts -- holds in 85.5% of generated rooms.
## The rest are benches with nothing hangable over them: the window the bench
## was put under (workbench_daylight, above, asks for exactly that wall), or
## the rack, banner or lamp that took the stretch first. So a shelf that missed
## its bench is a defect only when the wall over that bench was empty and
## waiting, and a warning when something else already had it.
const FS_SHELF_COVER := 0.5
## Masonry a shelf needs either side of an opening before it counts as free.
const FS_SHELF_CLEAR := 0.3

func check_shelf_over(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var hosts: Array[int] = []
		var shelves: Array[int] = []
		for i in plan.furniture_of(room):
			var cat: String = PropCatalog.category(plan.furniture[i]["key"])
			if cat == "workbench" or cat == "counter":
				hosts.append(i)
			elif cat == "shelf":
				shelves.append(i)
		if hosts.is_empty() or shelves.is_empty():
			continue
		var best_cover := 0.0
		var best_dist := INF
		for s in shelves:
			var p: Dictionary = plan.furniture[s]
			var sc: Vector2 = Rect2(p["rect"]).get_center()
			var wi: int = HouseFurnishSpatialCheck.fs_back_wall(plan, room, p["rect"], p)
			for h in hosts:
				var host: Rect2 = plan.furniture[h]["rect"]
				var near := Vector2(clampf(sc.x, host.position.x, host.end.x),
					clampf(sc.y, host.position.y, host.end.y))
				best_dist = minf(best_dist, sc.distance_to(near))
				var hw: int = HouseFurnishSpatialCheck.fs_back_wall(plan, room, host, plan.furniture[h])
				if hw < 0 or hw != wi:
					continue
				var normal := HouseFurnishSpatialCheck.fs_wall_normal(plan, room, hw)
				var axis := Vector2(normal.y, -normal.x)
				var width: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
				var interval := HouseFurnishSpatialCheck.fs_projection(host, axis, plan.furniture[h])
				var span: float = maxf(interval.y - interval.x, 0.05)
				var c: float = sc.dot(axis)
				var over: float = minf(c + width / 2.0, interval.y) \
					- maxf(c - width / 2.0, interval.x)
				best_cover = maxf(best_cover, over / minf(width, span))
		if best_cover >= FS_SHELF_COVER:
			continue
		var widest := 0.05
		for s2 in shelves:
			widest = maxf(widest, PropCatalog.size(plan.furniture[s2]["key"]).x)
		var free := false
		for h2 in hosts:
			if _fs_could_hang_over(plan, room, plan.furniture[h2], widest):
				free = true
		var msg := "shelf_over: no shelf in room %d (%s) hangs over the bench it serves (%.0f%% cover, %.2fm away)" \
			% [room, String(plan.kind_of(room)), best_cover * 100.0, best_dist]
		if free:
			failures.append(msg)
		else:
			warnings.append(msg)


## Could a shelf have hung over this bench at all? Not "is the wall bare" but
## the question the placer itself asks: is there a station on the bench's wall,
## clear of the doors and windows by the margin `_on_opening()` keeps and clear
## of whatever else is already screwed up there, from which the shelf would
## cover the bench. A bench under the window it was put beside, or a wall run
## shorter than the shelf, has no such station -- and a check that called that
## a defect would be reporting the size of the room again.
static func _fs_could_hang_over(plan: HousePlan, room: int, piece: Dictionary,
		width: float) -> bool:
	var host: Rect2 = piece.rect
	var wi: int = HouseFurnishSpatialCheck.fs_back_wall(plan, room, host, piece)
	if wi < 0:
		return false
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var a: Vector2 = walls[wi]["from"]
	var b: Vector2 = walls[wi]["to"]
	var run: float = (b - a).length()
	if run < width + 0.4:
		return false
	var along: Vector2 = (b - a) / run
	var axis: Vector2 = along
	var interval := HouseFurnishSpatialCheck.fs_projection(host, axis, piece)
	var span: float = maxf(interval.y - interval.x, 0.05)
	var lo: float = width / 2.0 + 0.2
	var hi: float = run - width / 2.0 - 0.2
	var t: float = lo
	while t <= hi + 0.001:
		var pos: Vector2 = a + along * t
		var clear_here: bool = not _fs_on_opening(plan, room, pos, width)
		if clear_here and not _fs_crowded(plan, room, pos, width, "shelf"):
			var c: float = pos.dot(axis)
			var hi_edge: float = minf(c + width / 2.0, interval.y)
			var lo_edge: float = maxf(c - width / 2.0, interval.x)
			var over: float = hi_edge - lo_edge
			if over / minf(width, span) >= FS_SHELF_COVER:
				return true
		t += 0.06
	return false


## The two clearances `HouseFurnishSurface.place_mounted` keeps, measured the same
## way: nothing may hang across an opening, and nothing may hang into what is
## already on the wall.
static func _fs_on_opening(plan: HousePlan, room: int, pos: Vector2,
		width: float) -> bool:
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		if Vector2(door["pos"]).distance_to(pos) < (float(door["width"]) + width) / 2.0 + 0.15:
			return true
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if Vector2(win["pos"]).distance_to(pos) < (float(win["width"]) + width) / 2.0 + 0.15:
			return true
	return false


static func _fs_crowded(plan: HousePlan, room: int, pos: Vector2, width: float,
		ignore_cat: String) -> bool:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not p.get("mounted", false):
			continue
		if PropCatalog.category(p["key"]) == ignore_cat:
			continue
		var other: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
		var c := Vector2(p["pos"].x, p["pos"].z)
		if c.distance_to(pos) < (width + other) / 2.0 + 0.1:
			return true
	return false


## A chandelier hangs over the table, not over the middle of a room whose table
## stands somewhere else. Generated houses hold this in 100% of cases, so
## anything outside the tolerance is a defect.
const FS_CHANDELIER_TOL := 0.35

func check_chandelier_over(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var tables: Array[int] = []
		for i in plan.furniture_of(room):
			var p: Dictionary = plan.furniture[i]
			if PropCatalog.category(p["key"]) == "table" and not p.get("mounted", false):
				tables.append(i)
		if tables.is_empty():
			continue
		for i2 in plan.furniture_of(room):
			var q: Dictionary = plan.furniture[i2]
			if PropCatalog.category(q["key"]) != "chandelier":
				continue
			var c := Vector2(q["pos"].x, q["pos"].z)
			var near := INF
			for t in tables:
				near = minf(near, c.distance_to(Rect2(plan.furniture[t]["rect"]).get_center()))
			if near <= FS_CHANDELIER_TOL:
				continue
			_fs_report(plan, q, "chandelier",
				"chandelier_over: %s hangs %.2fm from the nearest table"
				% [HouseFurnishCheck.who(plan, i2), near])


## Barrels, crates and sacks belong out of the traffic: a corner piece stands
## no nearer than a metre to a door.
##
## Tolerance. In the traffic means in the LINE of the door as well as near it:
## a crate half a metre in front of a doorway is what the rule is about, and a
## crate the same distance away but tucked against the jamb, beside the opening
## rather than across it, is a warning. (The doorway rule already guarantees
## neither of them stands in the swing.) A room whose every corner is inside
## the metre is a room too small to obey the rule at all, and warns too.
const FS_CLUTTER_CLEAR := 1.0

func check_corner_clutter(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if not PropCatalog.has_tag(p["key"], PropCatalog.CORNER):
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		var doors: Array[int] = plan.doors_of(room)
		if doors.is_empty():
			continue
		var c: Vector2 = Rect2(p["rect"]).get_center()
		var d := INF
		for di in doors:
			d = minf(d, c.distance_to(Vector2(plan.doors[di]["pos"])))
		if d >= FS_CLUTTER_CLEAR:
			continue
		var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var roomy := false
		for corner in [f_rect.position, Vector2(f_rect.end.x, f_rect.position.y),
				Vector2(f_rect.position.x, f_rect.end.y), f_rect.end]:
			var cd := INF
			for di2 in doors:
				cd = minf(cd, Vector2(corner).distance_to(Vector2(plan.doors[di2]["pos"])))
			if cd >= FS_CLUTTER_CLEAR:
				roomy = true
		var across := false
		for di3 in doors:
			var door: Dictionary = plan.doors[di3]
			var dn: Vector2 = door["normal"]
			var side: float = absf((c - Vector2(door["pos"])).dot(Vector2(dn.y, -dn.x)))
			var half_r: float = (absf(dn.y) * Rect2(p["rect"]).size.x
				+ absf(dn.x) * Rect2(p["rect"]).size.y) / 2.0
			if c.distance_to(Vector2(door["pos"])) < FS_CLUTTER_CLEAR 					and side < float(door["width"]) / 2.0 + half_r:
				across = true
		var msg := "corner_clutter: %s stands %.2fm from a door, in the traffic" \
			% [HouseFurnishCheck.who(plan, f), d]
		if roomy and across:
			_fs_report(plan, p, PropCatalog.category(p["key"]), msg)
		else:
			warnings.append(msg)


## The plan names one piece the room is arranged around -- the fire in a hall,
## the counter in a shop, the anvil in a smithy -- and where it stands. This
## is the temple's axis rule brought indoors: the focus exists, it is where
## the plan says (the furnisher writes back where it put it, so this is the
## plan against the furniture, not the plan against itself), and when the
## family says it must -- a counter, a bar -- it looks at the way in.
const FOCUS_TOL := 0.3
const FOCUS_FACE_DEG := 45.0

func check_focus(plan: HousePlan) -> void:
	var room: int = plan.focus_room()
	if room < 0 or room >= plan.room_count():
		return
	var cat: String = plan.focus_cat()
	if cat == "":
		return
	var pieces: Array[int] = []
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat:
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		pieces.append(f)
	if pieces.is_empty():
		if plan.was_dropped(room, cat) or not HouseFurnishProgrammeCheck.could_hold(plan, room, cat):
			warnings.append("focus: room %d (%s) gave up the %s it was arranged around"
				% [room, String(plan.kind_of(room)), cat])
		else:
			failures.append("focus: room %d (%s) has no %s to be arranged around"
				% [room, String(plan.kind_of(room)), cat])
		return
	var pos: Vector2 = plan.focus_pos()
	var best: int = pieces[0]
	var best_d := INF
	for f2 in pieces:
		var d: float = Rect2(plan.furniture[f2]["rect"]).get_center().distance_to(pos)
		if d < best_d:
			best_d = d
			best = f2
	# A room that gave up the piece it was arranged around wrote that down, and
	# what is left of the category is not that piece: a great hall whose high
	# table went so the hall could be walked still has its trestles, and
	# measuring one of THOSE against the dais is measuring the wrong table.
	var gave_up: bool = plan.was_dropped(room, cat)
	if pos.is_finite() and best_d > FOCUS_TOL:
		var said := "focus: %s stands %.2fm from the focus the plan recorded" \
			% [HouseFurnishCheck.who(plan, best), best_d]
		if gave_up:
			warnings.append(said + ", and the room gave up the one that stood there")
			return
		failures.append(said)
	if not plan.focus_faces_door():
		return
	var door: int = HouseFurnishScore.focus_door(plan, room)
	if door < 0:
		return
	var c: Vector2 = Rect2(plan.furniture[best]["rect"]).get_center()
	var to: Vector2 = Vector2(plan.doors[door]["pos"]) - c
	if to.length() < 0.01:
		return
	# Internal doors carry a partition-axis normal, which need not point out
	# of this room. Measure the room's wall before deciding whether a piece
	# faces the doorway squarely; the opposite direction is its back.
	var door_pos := Vector2(plan.doors[door]["pos"])
	var outward := Vector2(plan.doors[door]["normal"])
	var nearest := INF
	for wall in HouseGeometry.room_walls(plan, room):
		var point := Geometry2D.get_closest_point_to_segment(door_pos, wall.from, wall.to)
		var distance := door_pos.distance_to(point)
		if distance < nearest:
			nearest = distance
			outward = -Vector2(wall.normal)
	var yaw: float = float(plan.furniture[best]["yaw"])
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var off: float = rad_to_deg(acos(clampf(facing.dot(to.normalized()), -1.0, 1.0)))
	# a counter set square to the door's wall a little way along it looks at
	# the doorway well enough: the customer walks in and sees its front
	var squarely: bool = facing.dot(outward) > 0.9
	if off > FOCUS_FACE_DEG and not squarely:
		var said2 := "focus: the %s in room %d faces away from the door" % [cat, room]
		if gave_up:
			warnings.append(said2 + ", and the room gave up the one that faced it")
		else:
			failures.append(said2)
	# and it can be SEEN from the door: the temple's sightline rule, cast from
	# a person's eye inside the doorway to the top of the piece, past every
	# other piece standing in the room (Sightline, INT-020)
	var d: Dictionary = plan.doors[door]
	var base: float = float(plan.storey_of_room(room)) * plan.spec.height
	var inside: Vector2 = Vector2(d["pos"]) - outward * 0.5
	var eye := Vector3(inside.x, base + 1.6, inside.y)
	var top: float = base + PropCatalog.height(plan.furniture[best]["key"]) \
		* float(plan.furniture[best].get("scale", 1.0)) * 0.9
	var aim := Vector3(c.x, top, c.y)
	var boxes: Array = []
	var names: Array[String] = []
	for f3 in plan.furniture_of(room):
		if f3 == best:
			continue
		var q: Dictionary = plan.furniture[f3]
		if q.get("mounted", false) or int(q["host"]) >= 0:
			continue
		var qr: Rect2 = q["rect"]
		var qh: float = PropCatalog.height(q["key"]) * float(q.get("scale", 1.0))
		boxes.append(AABB(Vector3(qr.position.x, base, qr.position.y),
			Vector3(qr.size.x, qh, qr.size.y)))
		names.append(String(q["key"]))
	for ci in plan.columns.size():
		var column: Dictionary = plan.columns[ci]
		if int(column.get("room", -1)) != room or int(column.get("storey", 0)) != plan.storey_of_room(room):
			continue
		var column_pos: Vector2 = column["pos"]
		var size: Vector2 = column["size"]
		boxes.append(AABB(Vector3(column_pos.x - size.x * 0.5, base, column_pos.y - size.y * 0.5),
			Vector3(size.x, float(column["height"]), size.y)))
		names.append("column_%d" % ci)
	var hit: Array[int] = Sightline.blockers(eye, aim, boxes)
	if not hit.is_empty():
		warnings.append("focus: the %s in room %d cannot be seen from the door past the %s"
			% [cat, room, names[hit[0]]])


## Floor the plan keeps clear stays clear.
##
## A screens passage is not furniture, and nothing about the pieces standing in
## a hall says where it was: only the plan does. So this is the one rule that
## reads a plan-level zone -- and it reads it against what was actually placed,
## which is the whole point. A passage the plan drew and the furnishing filled
## in is a passage that was never there.
