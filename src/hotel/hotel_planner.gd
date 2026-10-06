class_name HotelPlanner
extends RefCounted
## A designed palatial plan: a double-loaded GALLERY corridor running the
## length of every level, with rooms off it on both sides (LAY-008).
##
## The old plan was six rooms a level joined by fixed doors, which made guest
## room 3 reachable only through guest room 0 -- the thing HousePlanCheck's
## privacy rule exists to forbid. A hotel is a corridor building: every guest
## room has ONE door and it opens onto the gallery, the stairs join gallery to
## gallery, and the room count follows the facade's bay rhythm rather than a
## constant. The ground floor keeps the public programme along the front
## (dining room, lobby, lounge) and the service programme along the back
## (kitchen, office, laundry, stores), with the same gallery between them.

const GROUND_KINDS: Array[StringName] = [
	&"dining_room", &"lobby", &"lounge", &"kitchen", &"office", &"laundry", &"store"]

## The corridor: wide enough for two people and the stair beside them.
const GALLERY_W := 2.6
## The front rank is the deeper one -- the public rooms and the suites face
## the street -- by this share of what the gallery leaves.
const FRONT_SHARE := 0.52
const STAIR_W := 1.2
const STAIR_RUN := 3.1


static func plan(spec: HotelSpec) -> HousePlan:
	var out := HousePlan.new()
	out.spec = spec
	var inner := HouseGeometry.interior_rect(spec)
	var n: int = rooms_per_side(spec)
	var xs: Array[float] = []
	for i in range(n + 1):
		xs.append(lerpf(inner.position.x, inner.end.x, float(i) / float(n)))
	var depth: float = inner.size.y - GALLERY_W
	var z_front: float = inner.position.y
	var z_gal0: float = z_front + depth * FRONT_SHARE
	var z_gal1: float = z_gal0 + GALLERY_W
	var z_back: float = inner.end.y

	var galleries: Array[int] = []
	var lobby := -1
	var kitchen := -1
	for storey in range(spec.storeys):
		var front_rank: Array = _front_rank(spec, xs, storey == 0)
		var back_rank: Array = _back_rank(xs, storey == 0)
		var front_rooms: Array[int] = []
		var back_rooms: Array[int] = []
		for span in front_rank:
			var rect := Rect2(Vector2(xs[span["from"]], z_front),
				Vector2(xs[span["to"]] - xs[span["from"]], z_gal0 - z_front))
			front_rooms.append(out.rooms.size())
			out.rooms.append({"kind": span["kind"], "rect": rect, "storey": storey})
			if span["kind"] == &"lobby":
				lobby = out.rooms.size() - 1
		var gallery: int = out.rooms.size()
		galleries.append(gallery)
		out.rooms.append({"kind": &"gallery",
			"rect": Rect2(Vector2(inner.position.x, z_gal0), Vector2(inner.size.x, GALLERY_W)),
			"storey": storey})
		for span in back_rank:
			var rect := Rect2(Vector2(xs[span["from"]], z_gal1),
				Vector2(xs[span["to"]] - xs[span["from"]], z_back - z_gal1))
			back_rooms.append(out.rooms.size())
			out.rooms.append({"kind": span["kind"], "rect": rect, "storey": storey})
			if span["kind"] == &"kitchen" and storey == 0:
				kitchen = out.rooms.size() - 1
		_connect_level(out, front_rooms, gallery, back_rooms, z_gal0, z_gal1, storey)
		if storey == 0:
			_add_exterior_doors(out, inner, lobby, kitchen, spec)
			# the kitchen's fire is on the back wall, the one it has to the yard
			if kitchen >= 0:
				out.hearth = {"room": kitchen, "wall": 1}
		_add_windows(out, front_rooms, gallery, back_rooms, inner, storey, spec)
		if storey == 0 and kitchen >= 0:
			_settle_kitchen_fire(out, kitchen)

	_open_balconies(out, spec)
	for storey in range(spec.storeys - 1):
		_add_stair(out, galleries[storey], galleries[storey + 1], storey)
	return out


## The yard wall is the kitchen fire's first choice -- but the tall windows go
## in after it was chosen, and on a wide hotel they leave 75 cm of wall between
## them, so the furnisher could hang no fire anywhere on it and the kitchen
## came out with no hearth at all: a cabinet, a barrel rack and a chalice, which
## the walk QA took for a bar (6 Oct). A hotel raises no stack over its
## kitchen (HotelBuilder emits the breast alone), so once the glazing is known
## the fire may take whichever kitchen wall still has room for it.
static func _settle_kitchen_fire(out: HousePlan, kitchen: int) -> void:
	var need: float = HousePlanFeatures.hearth_run_needed()
	if HousePlanFeatures._clear_wall_run(out, kitchen, 1) >= need:
		return
	var best := 1
	var best_run := HousePlanFeatures._clear_wall_run(out, kitchen, 1)
	for wi in range(HouseGeometry.room_walls(out, kitchen).size()):
		var run: float = HousePlanFeatures._clear_wall_run(out, kitchen, wi)
		if run > best_run:
			best_run = run
			best = wi
	out.hearth = {"room": kitchen, "wall": best}


## The storey the balconies serve: the piano nobile above the public floor.
const BALCONY_STOREY := 1


## Three balconies on the piano nobile, each in front of a real window that is
## let down to the floor as a french window (`"balcony": true`) -- one on the
## axis and a mirrored pair, at the windows nearest the old stations a third of
## the pavilion out. The builder seats each balcony on its window, so the
## balcony and the door behind it cannot drift apart again (WALK-QA, 6 Oct,
## hotel pins 2 and 3: balconies with no door, off the window grid).
static func _open_balconies(plan: HousePlan, spec: HotelSpec) -> void:
	if spec.storeys <= BALCONY_STOREY:
		return
	var front: Array[int] = []
	for i in range(plan.windows.size()):
		var w: Dictionary = plan.windows[i]
		if HousePlan.record_storey(w) == BALCONY_STOREY and Vector2(w["normal"]).y < -0.9:
			front.append(i)
	for target in [0.0, HotelGeometry.centre_width(spec) * 0.32]:
		var best := -1
		var best_d := INF
		for i in front:
			var x: float = Vector2(plan.windows[i]["pos"]).x
			if x < -0.01 or bool(plan.windows[i].get("balcony", false)):
				continue
			if absf(x - target) < best_d:
				best_d = absf(x - target)
				best = i
		if best < 0:
			continue
		var bx: float = Vector2(plan.windows[best]["pos"]).x
		for i in front:
			var x: float = Vector2(plan.windows[i]["pos"]).x
			if absf(x - bx) < 0.02 or (bx > 0.01 and absf(x + bx) < 0.02):
				plan.windows[i]["balcony"] = true
				# Which balcony it opens onto, by its centre. An elevation with
				# no axial window gets ONE axial balcony across the central
				# pair rather than two, so there are always three.
				plan.windows[i]["balcony_x"] = 0.0 if target == 0.0 else signf(x) * bx
				# a 3 cm upstand over the floor, so the wall under the
				# opening does not end in the floor's own plane
				plan.windows[i]["sill"] = HouseGeometry.FLOOR_T + 0.03


## Rooms on each side of the gallery: two facade bays to a room, so a room is
## as wide as a pair of the tall windows outside it.
static func rooms_per_side(spec: HotelSpec) -> int:
	return maxi(spec.facade_bays / 2, 3)


## How many rooms a level has, gallery included: the ranks merge cells on
## the ground floor (the lobby, the kitchen) and for the suite above.
static func rooms_on_level(spec: HotelSpec, storey: int) -> int:
	var inner := HouseGeometry.interior_rect(spec)
	var n: int = rooms_per_side(spec)
	var xs: Array[float] = []
	for i in range(n + 1):
		xs.append(lerpf(inner.position.x, inner.end.x, float(i) / float(n)))
	return _front_rank(spec, xs, storey == 0).size() + 1 + _back_rank(xs, storey == 0).size()


## The front rank: on the ground floor the lobby takes the cells under the
## centre pavilion with the dining room to one side and the lounge to the
## other; above, one guest room a cell with the suite in the middle.
static func _front_rank(spec: HotelSpec, xs: Array[float], ground: bool) -> Array:
	var n: int = xs.size() - 1
	var half_c: float = HotelGeometry.centre_width(spec) * 0.5
	var lo: int = n / 2
	var hi: int = n / 2 + 1
	if ground:
		# widen the lobby to the cells the pavilion stands over, keeping at
		# least one cell each side for the dining room and the lounge
		while lo > 1 and xs[lo] > -half_c + 0.01:
			lo -= 1
		while hi < n - 1 and xs[hi] < half_c - 0.01:
			hi += 1
		return [
			{"kind": &"dining_room", "from": 0, "to": lo},
			{"kind": &"lobby", "from": lo, "to": hi},
			{"kind": &"lounge", "from": hi, "to": n},
		]
	var out: Array = []
	var suite_lo: int = (n - 1) / 2
	var suite_hi: int = suite_lo + 1 + (1 if n % 2 == 0 else 0)
	var i := 0
	while i < n:
		if i == suite_lo:
			out.append({"kind": &"suite", "from": suite_lo, "to": suite_hi})
			i = suite_hi
			continue
		out.append({"kind": &"guest_room", "from": i, "to": i + 1})
		i += 1
	return out


## The back rank: the service rooms on the ground floor, from the kitchen end
## inward, with whatever cells are left over let as guest rooms; above, guest
## rooms all along.
static func _back_rank(xs: Array[float], ground: bool) -> Array:
	var n: int = xs.size() - 1
	var out: Array = []
	if ground:
		var kitchen_cells: int = 2 if n >= 5 else 1
		out.append({"kind": &"kitchen", "from": 0, "to": kitchen_cells})
		var kinds: Array[StringName] = [&"office", &"laundry", &"store"]
		var i: int = kitchen_cells
		for kind in kinds:
			if i >= n:
				break
			out.append({"kind": kind, "from": i, "to": i + 1})
			i += 1
		while i < n:
			out.append({"kind": &"guest_room", "from": i, "to": i + 1})
			i += 1
		return out
	for i in range(n):
		out.append({"kind": &"guest_room", "from": i, "to": i + 1})
	return out


## One door per room, onto the gallery, at the middle of the wall they share.
## On the ground floor the dining room and the lounge also open off the lobby,
## the way they do in the reference: you come in and the rooms are either side.
static func _connect_level(plan: HousePlan, front_rooms: Array[int], gallery: int,
		back_rooms: Array[int], z_gal0: float, z_gal1: float, storey: int) -> void:
	for i in front_rooms:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_add_door(plan, i, gallery, Vector2(rect.get_center().x, z_gal0), Vector2(0, 1), storey)
	for i in back_rooms:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_add_door(plan, gallery, i, Vector2(rect.get_center().x, z_gal1), Vector2(0, 1), storey)
	if storey == 0:
		for k in range(front_rooms.size() - 1):
			var a: int = front_rooms[k]
			var b: int = front_rooms[k + 1]
			if plan.kind_of(a) != &"lobby" and plan.kind_of(b) != &"lobby":
				continue
			var ra: Rect2 = plan.rooms[a]["rect"]
			_add_door(plan, a, b, Vector2(ra.end.x, ra.get_center().y), Vector2(1, 0), storey)


static func _add_door(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, storey: int) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "storey": storey})


## The ceremonial front door into the lobby, on the axis; the back door out of
## the kitchen at the end of its wall, so it is nowhere near in line with the
## front one (LAY-006).
static func _add_exterior_doors(plan: HousePlan, inner: Rect2, lobby: int,
		kitchen: int, spec: HotelSpec) -> void:
	plan.doors.append({"a": lobby, "b": -1,
		"pos": Vector2(0.0, inner.position.y), "normal": Vector2(0, -1),
		"width": 1.8, "exterior": true, "front": true, "storey": 0})
	if kitchen >= 0:
		var rect: Rect2 = plan.rooms[kitchen]["rect"]
		var m: float = HouseGeometry.DOOR_CORNER_MARGIN + HouseGeometry.DOOR_W / 2.0
		plan.doors.append({"a": kitchen, "b": -1,
			"pos": Vector2(rect.position.x + m, inner.end.y), "normal": Vector2(0, 1),
			"width": HouseGeometry.DOOR_W, "exterior": true, "front": false, "storey": 0})
	spec.back_door = kitchen >= 0


## Every room on an outside wall is lit from it: the front rank from the
## street, the back rank from the yard, the end rooms and the gallery's two
## ends from the sides.
static func _add_windows(plan: HousePlan, front_rooms: Array[int], gallery: int,
		back_rooms: Array[int], inner: Rect2, storey: int, spec: HotelSpec) -> void:
	for i in front_rooms:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_windows_along(plan, i, rect.position.x, rect.end.x, rect.position.y,
			Vector2(0, -1), storey, spec, storey == 0 and plan.kind_of(i) == &"lobby")
	for i in back_rooms:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_windows_along(plan, i, rect.position.x, rect.end.x, rect.end.y,
			Vector2(0, 1), storey, spec, false)
	for i in [front_rooms[0], back_rooms[0]]:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_windows_along(plan, i, rect.position.y, rect.end.y, inner.position.x,
			Vector2(-1, 0), storey, spec, false)
	for i in [front_rooms[-1], back_rooms[-1]]:
		var rect: Rect2 = plan.rooms[i]["rect"]
		_windows_along(plan, i, rect.position.y, rect.end.y, inner.end.x,
			Vector2(1, 0), storey, spec, false)
	var g: Rect2 = plan.rooms[gallery]["rect"]
	_windows_along(plan, gallery, g.position.y, g.end.y, inner.position.x,
		Vector2(-1, 0), storey, spec, false)
	_windows_along(plan, gallery, g.position.y, g.end.y, inner.end.x,
		Vector2(1, 0), storey, spec, false)


## Windows evenly along one wall of a room, between `t0` and `t1` along it,
## clear of its corners and of each other by the margins HousePlanCheck asks
## for. `line` is the wall's other coordinate.
static func _windows_along(plan: HousePlan, room: int, t0: float, t1: float,
		line: float, normal: Vector2, storey: int, spec: HotelSpec,
		keep_centre_clear: bool) -> void:
	var w := 1.05
	var m: float = HouseGeometry.WINDOW_CORNER_MARGIN
	var usable: float = (t1 - t0) - 2.0 * m
	if usable < w:
		return
	var count := clampi(int((usable + HouseGeometry.WINDOW_MIN_GAP)
		/ (w + HouseGeometry.WINDOW_MIN_GAP)), 1, 12)
	for i in range(count):
		var t := lerpf(t0 + m, t1 - m, (float(i) + 0.5) / count)
		if keep_centre_clear and absf(t) < 1.58:
			continue
		var pos := Vector2(t, line) if absf(normal.y) > 0.5 else Vector2(line, t)
		# never through a doorway already cut in this wall
		var clashes := false
		for door in plan.doors:
			if Vector2(door["normal"]).dot(normal) < 0.9:
				continue
			if HousePlan.record_storey(door) != storey:
				continue
			if pos.distance_to(Vector2(door["pos"])) < (w + float(door["width"])) / 2.0 + 0.1:
				clashes = true
		if clashes:
			continue
		plan.windows.append({"room": room, "pos": pos, "normal": normal,
			"width": w, "sill": 0.9, "head": minf(2.55, spec.height - 0.3),
			"storey": storey})


## The stair rises in the gallery, against its back wall, as near the axis as
## the doors off that wall allow: clear of every door's swing and of the
## windows at the gallery ends, and out of the line of the lobby door.
static func _add_stair(plan: HousePlan, lower: int, upper: int, storey: int) -> void:
	var floor := HouseGeometry.room_floor_rect(plan, lower)
	var size := Vector2(STAIR_RUN, minf(STAIR_W, floor.size.y - HouseGeometry.PATH_MIN))
	var swings: Array[Rect2] = []
	var lines: Array[Rect2] = []
	for d in plan.doors_of(lower):
		var door: Dictionary = plan.doors[d]
		if HousePlan.record_storey(door) != storey:
			continue
		for side in [-1.0, 1.0]:
			swings.append(HouseGeometry.door_clear_rect(door, side))
		lines.append(HousePlanLevels.door_line(plan, lower, door))
	var glass: Array[Rect2] = []
	for wi in plan.windows_of(lower):
		glass.append(HouseGeometry.window_clear_rect(plan.windows[wi]))
	# Not in the well the flight below comes up through: the two flights used
	# to share one rectangle, so the first climbed into the solid foot of the
	# second and arrived nowhere (WALK-QA, 6 Oct, pin 9).
	var wells: Array[Rect2] = HousePlanLevels.arriving_wells(plan, storey)
	var best := Rect2()
	var best_d := INF
	var travel: float = floor.size.x - size.x
	var steps: int = maxi(int(travel / 0.1), 1)
	for strict in range(3):
		for s in range(steps + 1):
			var x: float = floor.position.x + travel * float(s) / float(steps)
			var rect := Rect2(Vector2(x, floor.end.y - size.y), size)
			if HousePlanLevels.hits_any(rect, wells):
				continue
			if strict < 2 and HousePlanLevels.hits_any(rect, swings):
				continue
			if strict < 1 and HousePlanLevels.hits_any(rect, lines):
				continue
			if HousePlanLevels.hits_any(rect, glass):
				continue
			var d: float = absf(rect.get_center().x)
			if d < best_d:
				best_d = d
				best = rect
		if best.size.x > 0.0:
			break
	if best.size.x <= 0.0:
		best = Rect2(Vector2(floor.get_center().x - size.x / 2.0, floor.end.y - size.y), size)
	var centre: Vector2 = best.get_center()
	plan.stairs.append({
		"a": lower, "b": upper, "storey": storey, "to_storey": storey + 1,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": best, "lower_rect": best, "upper_rect": best,
		"width": size.y, "run": size.x,
	})
