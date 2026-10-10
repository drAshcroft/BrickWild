class_name HouseGeometry
extends RefCounted
## Single source of truth for a house's shell: where the walls, doors and
## windows are, and the dimensions everything else is measured against.
##
## Same contract as ChurchGeometry and CastleGeometry -- pure functions of an
## explicit plan, so the builder that emits the mesh, the furnisher that fills
## the rooms and the checks that judge the result all read the same numbers.
##
## Model axes: +X right, +Y up, +Z back. The front door is on the -Z wall, so
## "front" always means -Z, the way "the gate is at -Z" does for a castle.
##
## The clearance numbers below come from ordinary interior-design practice --
## a 36 in main walkway, 36 in of pull-back behind a dining chair, 30 in beside
## a bed -- relaxed a little, because these are fantasy cottages and a peasant
## hall built to a modern corridor standard reads as an office.

# ---- shell, in metres ----
const WALL_T := 0.35          # exterior wall thickness
const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")
const INNER_WALL_T := 0.16    # partition thickness
const FLOOR_T := 0.12
const CEILING_MIN := 2.2      # a room shorter than this is a crawlspace

# ---- openings ----
const DOOR_W := 0.95          # front door leaf width
const INNER_DOOR_W := 0.85
const DOOR_H := 2.02
const DOOR_CORNER_MARGIN := 0.32   # clear wall either side of a door opening
const WINDOW_W := 0.95
const WINDOW_NARROW := 0.6    # the last-resort window, for a wall with no room
const WINDOW_H := 1.05
const WINDOW_SILL := 0.95     # floor to sill
const WINDOW_CORNER_MARGIN := 0.45
const WINDOW_MIN_GAP := 0.8   # clear wall between neighbouring windows
## Window area as a fraction of floor area, per habitable room. Modern codes
## ask for eight to ten per cent; a medieval cottage had a fraction of that,
## because glass was dear and the wall was holding the roof up. Five per cent
## is generous for the buildings this generator makes, and the check warns
## rather than fails when a room falls short.
const GLAZING_MIN := 0.05

# ---- circulation ----
const PERSON_RADIUS := 0.24   # half a shoulder width, plus a little
const PATH_MIN := 0.70        # narrowest gap that still counts as a way through
const DOOR_CLEAR := 0.85      # clear floor in front of a door, BOTH sides
const NAV_CELL := 0.12        # walkability grid resolution

# ---- timber framing ----
##
## Half-timbering is the one thing that makes a plastered box read as medieval,
## and it is almost free: a frame of beams standing proud of the wall face, in
## the trim colour, laid out the way a carpenter would lay it out. Sill at the
## bottom, wall plate at the top, posts at the corners, studs between them, a
## mid rail at sill height, and a brace across each corner.
const BEAM_W := 0.15          # a stud, seen face on
const BEAM_D := 0.085         # how far a beam stands proud of the plaster
const POST_W := 0.22          # corner posts are heavier than the studs
const PLATE_H := 0.2          # the beam along the top of a wall
const SILL_BEAM_H := 0.18     # and the one along the bottom
const RAIL_H := 0.15          # the mid rail
const STUD_CLEAR := 0.1       # air kept between a stud and an opening
const BRACE_RUN := 1.15       # how far a corner brace reaches along the wall

# ---- exterior details ----
const PLINTH_EXTRA := 0.04    # how far the masonry plinth stands proud of the wall
const MULLION_W := 0.08       # width of window timber mullion
const MULLION_D := 0.12       # depth of window timber mullion
const HOOD_PROJECTION := 0.12 # dripstone hood moulding projection
const BARGEBOARD_W := 0.16    # verge board width along gable slope
const CHIMNEY_BASE_EXTRA := 0.35 # stepped chimney base extra thickness
const CHIMNEY_POT_R := 0.13   # terracotta flue pot radius
const CHIMNEY_POT_H := 0.55   # flue pot height

# ---- furnishing ----
const WALL_GAP := 0.06        # how close a wall-hugging piece sits to the wall
const FURNITURE_DENSITY_MAX := 0.42   # of a room's floor, before it reads as a junk shop
const SHELF_HEIGHT := 1.55    # mounting height of a wall shelf or rack
const SCONCE_HEIGHT := 1.85
const BED_HEAD_TOL := 0.35    # how far a headboard may sit off its wall

# ---- rooms ----
const MIN_ROOM_SIDE := 2.1
## The most storeys the HARNESS will measure. A house stops at three and each
## family clamps itself to what it is -- but the cap belongs to the checks, not
## to the house: a castle keep is four storeys of one room each, and a check
## that stopped counting at three would report its top floor as invalid rather
## than walk it. (CAS-011)
const MAX_STOREYS := 4

const ROOM_ASPECT_MAX := 3.4
## Except where length IS the room. A great hall is long on purpose --
## Westminster is 20.7 x 73 m, three and a half to one -- and a castle range is
## narrower than that again, so measuring one against a parlour reports every
## hall ever built as a corridor.
const ASPECT_MAX := {&"great_hall": 6.0, &"nave": 6.0, &"corridor": 20.0}


## The longest a room of `kind` may be for its width before it stops being a
## room and starts being a passage.
static func aspect_max(kind: StringName) -> float:
	return float(ASPECT_MAX.get(kind, ROOM_ASPECT_MAX))

## Floor area a room of each kind needs to be worth calling that.
const MIN_AREA := {
	&"hall": 9.0, &"kitchen": 6.0, &"bedroom": 11.0, &"workshop": 8.0,
	&"store": 2.4, &"parlour": 8.0, &"sales_floor": 9.0,
	&"stable": 11.0, &"tack_room": 5.0, &"dining_room": 10.0,
	&"guest_room": 9.0, &"office": 6.0, &"records": 5.0,
	&"council_chamber": 12.0, &"meeting_hall": 12.0,
	&"lobby": 16.0, &"lounge": 10.0, &"suite": 14.0,
	&"gallery": 8.0, &"laundry": 7.0, &"great_hall": 16.0,
	&"lords_chamber": 10.0, &"nave": 12.0, &"sanctuary": 6.0,
	&"reading_room": 14.0, &"stacks": 20.0, &"scriptorium": 8.0,
	&"antechamber": 10.0, &"throne_room": 18.0, &"treasury": 6.0,
	&"royal_chamber": 11.0,
	&"guardroom": 8.0, &"corridor": 2.4, &"cell": 4.0, &"oubliette": 4.0,
}

## And the narrowest it may be. Area alone is not enough: a bed is 1.9 x 2.4 m
## and wants three quarters of a metre down one side, so a 2 x 6 m room has the
## floor area of a bedroom and cannot hold a bed. A house that fails this test
## does not get a smaller bedroom -- it gets no bedroom, and the bed goes in the
## hall, which is what a one-room cottage has always done.
const MIN_SIDE := {
	&"hall": 2.6, &"kitchen": 2.2, &"bedroom": 3.3, &"workshop": 2.6,
	&"store": 1.6, &"parlour": 2.6, &"sales_floor": 2.8,
	&"stable": 3.0, &"tack_room": 2.1, &"dining_room": 2.8,
	&"guest_room": 3.0, &"office": 2.2, &"records": 2.0,
	&"council_chamber": 3.0, &"meeting_hall": 3.0,
	&"lobby": 3.2, &"lounge": 2.8, &"suite": 3.4,
	&"gallery": 2.4, &"laundry": 2.4, &"great_hall": 3.0,
	&"lords_chamber": 2.8, &"nave": 2.8, &"sanctuary": 2.0,
	&"reading_room": 3.0, &"stacks": 3.6, &"scriptorium": 2.6,
	&"antechamber": 2.6, &"throne_room": 3.0, &"treasury": 2.0,
	&"royal_chamber": 3.3,
	&"guardroom": 2.4, &"corridor": 1.15, &"cell": 2.0, &"oubliette": 2.0,
}


## Can room `i` be called `kind` -- big enough, and not a corridor?
static func room_suits(plan: HousePlan, i: int, kind: StringName) -> bool:
	var f: Rect2 = room_floor_rect(plan, i)
	if kind == &"corridor":
		return minf(f.size.x, f.size.y) >= 1.15 \
			and maxf(f.size.x, f.size.y) >= 2.0 * minf(f.size.x, f.size.y)
	if kind == &"cell":
		return minf(f.size.x, f.size.y) >= 2.0 \
			and maxf(f.size.x, f.size.y) <= 3.0
	if f.size.x * f.size.y < float(MIN_AREA.get(kind, 4.0)):
		return false
	return minf(f.size.x, f.size.y) >= float(MIN_SIDE.get(kind, 1.6))

## Rooms people live in. A store room needs neither a window nor a chair.
const HABITABLE := [&"hall", &"kitchen", &"bedroom", &"workshop", &"parlour",
	&"sales_floor", &"stable", &"tack_room", &"dining_room", &"guest_room",
	&"office", &"records", &"council_chamber", &"meeting_hall", &"lobby",
	&"lounge", &"suite", &"gallery", &"laundry", &"great_hall",
	&"lords_chamber", &"nave", &"sanctuary", &"reading_room", &"stacks", &"scriptorium",
	&"antechamber", &"throne_room", &"royal_chamber",
	&"guardroom"]

## Rooms someone sleeps in. Nobody should have to walk through one of these
## to reach anywhere else -- not just the house's own "bedroom".
const SLEEPING := [&"bedroom", &"guest_room", &"suite", &"lords_chamber", &"royal_chamber"]



# ------------------------------------------------------------------- shell

## Outer footprint of the house at wall-top level.
static func site_rect(spec: HouseSpec, level := 0) -> Rect2:
	var r := Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))
	# A single front cantilever: every upper level shares the same envelope.
	# Derived family programmes and stone shells do not acquire a house jetty.
	if level > 0 and spec.jetty and spec.material != &"stone" and not spec.has_method("room_program"):
		r.position.y -= spec.jetty_depth
		r.size.y += spec.jetty_depth
	return r


## The ground the rooms partition: inside the exterior walls.
static func interior_rect(spec: HouseSpec, level := 0) -> Rect2:
	return site_rect(spec, level).grow(-wall_thickness(spec))


## Plan-aware rectangular envelope. Polygon and courtyard families explicitly
## opt out of the ordinary front cantilever; their outlines own their shape.
static func storey_rect(plan: HousePlan, level: int) -> Rect2:
	return site_rect(plan.spec, 0 if plan.has_court() or is_shaped(plan) else level)


static func wall_thickness(spec: HouseSpec) -> float:
	if spec.wall_thickness_override > 0.0:
		return spec.wall_thickness_override
	return 0.6 if spec.material == &"stone" else WALL_T


## The four exterior wall runs, each as
## {"from": Vector2, "to": Vector2, "normal": Vector2, "side": StringName}.
## `from`/`to` run along the wall's CENTRE LINE, and `normal` points outdoors.
static func exterior_runs(spec: HouseSpec, level := 0) -> Array[Dictionary]:
	var r: Rect2 = site_rect(spec, level).grow(-wall_thickness(spec) / 2.0)
	return [
		{"from": Vector2(r.position.x, r.position.y), "to": Vector2(r.end.x, r.position.y),
			"normal": Vector2(0, -1), "side": &"front"},
		{"from": Vector2(r.position.x, r.end.y), "to": Vector2(r.end.x, r.end.y),
			"normal": Vector2(0, 1), "side": &"back"},
		{"from": Vector2(r.position.x, r.position.y), "to": Vector2(r.position.x, r.end.y),
			"normal": Vector2(-1, 0), "side": &"left"},
		{"from": Vector2(r.end.x, r.position.y), "to": Vector2(r.end.x, r.end.y),
			"normal": Vector2(1, 0), "side": &"right"},
	]


## The wall centre-lines of a shell that is not a rectangle (GEO-002).
##
## Same shape of answer as `exterior_runs`, so the builder does not care which
## it got: from, to, an OUTWARD normal and a side name. The outline is the
## clear floor, so the centre-line is the outline pushed out by half a wall --
## exactly what `exterior_runs` does to the site rectangle.
static func polygon_runs(outline: PackedVector2Array, thickness := WALL_T) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if outline.size() < 3:
		return out
	var centre: PackedVector2Array = Poly.offset(outline, thickness / 2.0)
	if centre.size() < 3:
		centre = outline
	var turn: float = 1.0 if Poly.signed_area(centre) > 0.0 else -1.0
	for k in range(centre.size()):
		var a: Vector2 = centre[k]
		var b: Vector2 = centre[(k + 1) % centre.size()]
		var d: Vector2 = b - a
		if d.length() < 0.001:
			continue
		d = d.normalized()
		out.append({"from": a, "to": b,
			"normal": -Vector2(-d.y, d.x) * turn, "side": StringName("e%d" % k)})
	return out


## The shell runs for one storey of a plan: the polygon's edges when the storey
## is shaped, the site rectangle's four sides when it is not.
static func shell_runs(plan: HousePlan, level: int) -> Array[Dictionary]:
	for i in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[i]) == level and plan.is_polygonal(i):
			var thick := float(plan.rooms[i].get("wall_thickness", wall_thickness(plan.spec)))
			var shaped := polygon_runs(plan.outline_of(i), thick)
			for run in shaped:
				run["thickness"] = thick
			return shaped
	var rectangular := exterior_runs(plan.spec, 0 if plan.has_court() else level)
	var thick := wall_thickness(plan.spec)
	for run in rectangular:
		run["thickness"] = thick
	return rectangular


## Does any room of this plan carry an outline?
static func is_shaped(plan: HousePlan) -> bool:
	for i in range(plan.room_count()):
		if plan.is_polygonal(i):
			return true
	return false


## Is this plan-space line (on a room's edge) an exterior wall?
static func is_exterior_edge(spec: HouseSpec, axis: int, value: float) -> bool:
	var inner: Rect2 = interior_rect(spec)
	var lo: float = inner.position.x if axis == 0 else inner.position.y
	var hi: float = inner.end.x if axis == 0 else inner.end.y
	return absf(value - lo) < 0.01 or absf(value - hi) < 0.01


# -------------------------------------------------------------------- rooms

## A room's CLEAR FLOOR: its share of the interior, pulled back by half a
## partition on every edge it shares with another room. Furniture is placed in
## this rectangle, never in the raw partition rect, or every wall-hugging piece
## would be buried half a partition deep in the wall beside it.
## The floor a body needs in front of a stair's first step: its radius.
const STAIR_APPROACH := 0.3
## A domestic straight flight needs a real, clear floor square at either end.
## This is the usable landing depth, not the sliver the route check samples.
const STAIR_LANDING := 0.9
const STAIR_WIDTH_MIN := 1.1
const STAIR_WIDTH_CLEAR_MIN := 0.9
const STAIR_WIDTH_TARGET := 1.1
const STAIR_GUARD_EDGE_OFFSET := 0.045
const STAIR_GUARD_THICKNESS := 0.075
const STAIR_RISER_MAX := 0.22
const STAIR_GOING_MIN := 0.22
const STAIR_STRIDE_MAX := 0.70
const STAIR_PITCH_MAX := 42.0


## Which way a straight flight climbs along its long axis: +1.0 from its low
## coordinate end, -1.0 from its high end. The FOOT is the end with floor in
## front of it. The builder used to climb toward +x/+z whatever stood at the
## other end, and a flight laid against the hall's end wall began in the wall
## itself, with nowhere to stand to get on it (WALK-QA, 6 Oct, Wolfmarch Green
## house_9 pin 5). A record may say so itself with "climb".
static func stair_climb(plan: HousePlan, stair: Dictionary) -> float:
	if stair.has("climb"):
		return signf(float(stair["climb"])) if float(stair["climb"]) != 0.0 else 1.0
	var r := Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
	var room := int(stair.get("a", -1))
	if room < 0 or room >= plan.room_count() or not is_straight_flight(r):
		return 1.0
	var floor := room_floor_rect(plan, room).grow(0.01)
	if floor.encloses(stair_approach(r, 1.0)):
		return 1.0
	if floor.encloses(stair_approach(r, -1.0)):
		return -1.0
	return 1.0


## A well at least half again as long as it is wide holds a straight flight;
## a squarer one is a newel or a spiral, which has no single foot end.
static func is_straight_flight(r: Rect2) -> bool:
	return r.has_area() and maxf(r.size.x, r.size.y) >= minf(r.size.x, r.size.y) * 1.5


## The strip of floor in front of the foot of a flight laid on `r` and
## climbing `climb` (see stair_climb).
static func stair_approach(r: Rect2, climb: float, depth := STAIR_APPROACH) -> Rect2:
	if r.size.x > r.size.y:
		var x := r.position.x - depth if climb > 0.0 else r.end.x
		return Rect2(Vector2(x, r.position.y), Vector2(depth, r.size.y))
	var z := r.position.y - depth if climb > 0.0 else r.end.y
	return Rect2(Vector2(r.position.x, z), Vector2(r.size.x, depth))


## Pick the smallest whole number of equal risers that respects the measured
## domestic stair limits. Zero means the given run cannot be walked.
static func stair_step_count(height: float, run: float) -> int:
	if height <= 0.0 or run <= 0.0 \
			or rad_to_deg(atan2(height, run)) > STAIR_PITCH_MAX + 0.001:
		return 0
	var first := maxi(4, ceili(height / STAIR_RISER_MAX))
	var last := floori(run / STAIR_GOING_MIN)
	for count in range(first, last + 1):
		var riser := height / float(count)
		var going := run / float(count)
		if riser <= STAIR_RISER_MAX + 0.001 and going >= STAIR_GOING_MIN - 0.001 \
				and 2.0 * riser + going <= STAIR_STRIDE_MAX + 0.001:
			return count
	return 0


static func room_floor_rect(plan: HousePlan, i: int) -> Rect2:
	# An outline is the clear floor already: there is no partition to give half
	# of, so the floor rectangle is simply what the outline spans.
	if plan.is_polygonal(i):
		return Poly.bounding_rect(plan.outline_of(i))
	var rect: Rect2 = plan.rooms[i]["rect"]
	var inner := storey_rect(plan, plan.storey_of_room(i)).grow(-wall_thickness(plan.spec))
	var half: float = INNER_WALL_T / 2.0
	var x0: float = rect.position.x + (0.0 if absf(rect.position.x - inner.position.x) < 0.01 else half)
	var x1: float = rect.end.x - (0.0 if absf(rect.end.x - inner.end.x) < 0.01 else half)
	var z0: float = rect.position.y + (0.0 if absf(rect.position.y - inner.position.y) < 0.01 else half)
	var z1: float = rect.end.y - (0.0 if absf(rect.end.y - inner.end.y) < 0.01 else half)
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))


## One wall per edge of an outline, wound so `normal` points into the polygon.
static func polygon_walls(poly: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = poly.size()
	if n < 3:
		return out
	# The inward normal of an edge depends on which way round the outline is
	# wound, and callers should not have to know or care which that was.
	var turn: float = 1.0 if Poly.signed_area(poly) > 0.0 else -1.0
	for k in range(n):
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % n]
		var d: Vector2 = b - a
		if d.length() < 0.001:
			continue
		d = d.normalized()
		out.append({"from": a, "to": b,
			"normal": Vector2(-d.y, d.x) * turn})
	return out


## The physical room edge nearest the back of a footprint. A mounted item
## deliberately straddles its wall by a few centimetres, so compare the
## support of its rectangle rather than its centre to the inward wall plane.
static func backing_wall(plan: HousePlan, room: int, rect: Rect2, tolerance: float) -> int:
	var walls := room_walls(plan, room)
	var best := -1
	var closest := tolerance
	var centre := rect.get_center()
	for index in walls.size():
		var wall: Dictionary = walls[index]
		var normal: Vector2 = wall.normal
		var a: Vector2 = wall.from
		var b: Vector2 = wall.to
		var along := (b - a).normalized()
		var station := (centre - a).dot(along)
		if station < 0.0 or station > a.distance_to(b):
			continue
		var support := (absf(normal.x) * rect.size.x + absf(normal.y) * rect.size.y) * 0.5
		var gap := absf((centre - a).dot(normal) - support)
		if gap < closest:
			closest = gap
			best = index
	return best


## The clear floor of a room as a polygon: its outline, or its floor rectangle
## when it has none. What furniture has to stay inside and what the walk grid
## rasterises.
static func room_floor_poly(plan: HousePlan, i: int) -> PackedVector2Array:
	if plan.is_polygonal(i):
		return plan.outline_of(i)
	return Poly.from_rect(room_floor_rect(plan, i))


static func room_area(plan: HousePlan, i: int) -> float:
	if plan.is_polygonal(i):
		return Poly.area(plan.outline_of(i))
	var f: Rect2 = room_floor_rect(plan, i)
	return f.size.x * f.size.y


static func room_aspect(plan: HousePlan, i: int) -> float:
	var f: Rect2 = room_floor_rect(plan, i)
	var lo: float = minf(f.size.x, f.size.y)
	var hi: float = maxf(f.size.x, f.size.y)
	return hi / maxf(lo, 0.01)


static func is_habitable(kind: StringName) -> bool:
	return kind in HABITABLE


## The walls of a room's clear floor, as
## {"from": Vector2, "to": Vector2, "normal": Vector2} with `normal` pointing
## INTO the room. This is what a piece of furniture puts its back against.
##
## Four of them for a rectangular room, in the order every table in this
## project indexes by -- front, back, left, right -- and ONE PER EDGE for a
## room that carries an outline (GEO-002). The four-sided order is a labelling,
## not a traversal, which is why the two paths are written out separately: a
## hearth on "wall 2" means the left wall, and it has to keep meaning that.
static func room_walls(plan: HousePlan, i: int) -> Array[Dictionary]:
	var out: Array[Dictionary]
	if plan.is_polygonal(i):
		out = polygon_walls(plan.outline_of(i))
	else:
		var f: Rect2 = room_floor_rect(plan, i)
		out = [
		{"from": f.position, "to": Vector2(f.end.x, f.position.y), "normal": Vector2(0, 1)},
		{"from": Vector2(f.position.x, f.end.y), "to": f.end, "normal": Vector2(0, -1)},
		{"from": f.position, "to": Vector2(f.position.x, f.end.y), "normal": Vector2(1, 0)},
		{"from": Vector2(f.end.x, f.position.y), "to": f.end, "normal": Vector2(-1, 0)},
		]
	var room: Dictionary = plan.rooms[i]
	var kinds: Array = room.get("wall_kinds", [])
	var portals: Dictionary = room.get("wall_portals", {})
	for wi in out.size():
		out[wi]["index"] = wi
		out[wi]["kind"] = StringName(kinds[wi]) if wi < kinds.size() else &"solid"
		if portals.has(wi):
			out[wi]["portal"] = portals[wi]
	return out


# ------------------------------------------------------------------ doors

## World-space plan rectangle of the floor a door needs kept clear, on one
## side of it. Both sides are checked: a door you can open into a room but not
## out of it is still a door you cannot use.
static func door_clear_rect(door: Dictionary, side: float) -> Rect2:
	var c: Vector2 = door["pos"]
	var n: Vector2 = door["normal"] * side
	var w: float = float(door["width"])
	var d: float = DOOR_CLEAR
	var along := Vector2(n.y, -n.x).abs()
	var half_w: Vector2 = along * (w / 2.0)
	var deep: Vector2 = n * d
	var a: Vector2 = c - half_w
	var b: Vector2 = c + half_w + deep
	return Rect2(a.min(b), (b - a).abs())


## The point a person stands on to pass through a door, one step to `side`.
static func door_threshold(door: Dictionary, side: float) -> Vector2:
	return door["pos"] + door["normal"] * side * (WALL_T * 0.5 + PERSON_RADIUS + 0.05)


# ----------------------------------------------------------------- windows

## World plan segment a window occupies, as a thin rectangle on the wall face.
static func window_rect(win: Dictionary) -> Rect2:
	var c: Vector2 = win["pos"]
	var n: Vector2 = win["normal"]
	var along := Vector2(n.y, -n.x).abs()
	var half: Vector2 = along * (float(win["width"]) / 2.0)
	var a: Vector2 = c - half - n.abs() * 0.05
	var b: Vector2 = c + half + n.abs() * 0.05
	return Rect2(a.min(b), (b - a).abs())


## Floor a window needs kept clear of tall furniture, so it still lets light in
## and can be opened.
static func window_clear_rect(win: Dictionary) -> Rect2:
	var c: Vector2 = win["pos"]
	var n: Vector2 = -win["normal"]           # into the room
	var along := Vector2(n.y, -n.x)
	var half: Vector2 = along * (float(win["width"]) / 2.0)
	return Poly.bounding_rect(PackedVector2Array([
		c - half, c + half, c + half + n * 0.35, c - half + n * 0.35]))


static func window_area(win: Dictionary) -> float:
	return float(win["width"]) * float(win["head"] - win["sill"])


# ---------------------------------------------------------------- envelope

static func roof_rise(spec: HouseSpec) -> float:
	var raw := minf(spec.width, spec.length) * spec.roof_pitch * 0.5
	if spec.style == &"witch_hut":
		# Retain a steep small hut, while preventing a broad lot from becoming
		# one enormous blank gable. This cap is in metres and leaves the locked
		# wall envelope unchanged.
		var span := minf(spec.width, spec.length)
		return minf(raw, clampf(span * 0.52, 3.6, 5.6))
	return raw


## Art direction, not a structural limit. Broad houses gain roof rise more
## slowly than width; the witch row retains a steep small roof while its
## dimension-specific rise bound prevents a huge blank roof on a large lot.
## Applied only to generated pitch, never to an explicit emitter fixture.
static func art_pitch_scale(spec: HouseSpec) -> float:
	var row: Dictionary = HouseSpec.STYLES.get(spec.style, {})
	var reference := float(row.get("pitch_reference", 8.0))
	var span := minf(spec.width, spec.length)
	if span <= reference:
		return 1.0
	return pow(reference / span, float(row.get("pitch_exponent", 0.5)))


## Pure plan-space roof layout. Attachments and the emitter read the same
## face coordinates; rebuilding a mutable spec never leaves cached holes on
## a former roof. The transform's origin is the top storey's wall head.
static func uses_witch_asymmetric_roof(spec: HouseSpec, world_family: StringName = &"") -> bool:
	if spec == null or world_family != &"":
		return false
	var spec_script := spec.get_script() as Script
	return spec_script != null \
		and spec_script.resource_path.ends_with("/src/house/house_spec.gd") \
		and spec.style == &"witch_hut" and spec.trade == &"none" \
		and spec.roof_type in [&"gable", &"half_hipped"]


## Put the shifted ridge opposite the ordinary Workshop wing. The roof layout
## and the Workshop-side validation share this value, so a bay cannot pass a
## separate, hand-copied ridge test.
static func witch_ridge_x(plan: HousePlan, full_span: float) -> float:
	var offset := full_span * 0.18
	if plan == null or plan.world_family != &"" or not uses_witch_asymmetric_roof(plan.spec, plan.world_family):
		return offset
	var top := storey_rect(plan, 0)
	var xf := Transform3D(Basis(Vector3.UP, PI / 2.0 if top.size.x > top.size.y else 0.0), Vector3(top.get_center().x, plan.spec.height, top.get_center().y))
	var workshop_side := 0.0
	for room_index in plan.rooms_of(&"workshop"):
		var room: Rect2 = plan.rooms[room_index]["rect"]
		var local_center := _witch_bay_local_point(xf, room.get_center())
		workshop_side += local_center.x
	if workshop_side > 0.02:
		return -offset
	return offset


## The occupied unmarked rooms form the high Witch roof mass. Marked service
## rooms sit beside them under their own lower roof. This derives the upper
## footprint from the actual plan rather than the lot AABB.
static func witch_high_core_rect(plan: HousePlan) -> Rect2:
	if plan == null or plan.world_family != &"" \
			or not uses_witch_asymmetric_roof(plan.spec, plan.world_family):
		return Rect2()
	var has_service_wing := false
	for room in plan.rooms:
		if bool(room.get("witch_service_wing", false)):
			has_service_wing = true
			break
	if not has_service_wing:
		return Rect2()
	var bounds := Rect2()
	var found_core := false
	for room_index in plan.room_count():
		if plan.storey_of_room(room_index) != 0 \
				or bool(plan.rooms[room_index].get("witch_service_wing", false)):
			continue
		var room: Rect2 = plan.rooms[room_index]["rect"]
		if room.size.x < 0.01 or room.size.y < 0.01:
			return Rect2()
		bounds = bounds.merge(room) if found_core else room
		found_core = true
	return bounds if found_core else Rect2()


const WITCH_WORKSHOP_MIN_SITE_SPAN := 8.5


static func witch_workshop_bay(plan: HousePlan) -> Dictionary:
	if plan == null or not uses_witch_asymmetric_roof(plan.spec, plan.world_family) \
			or plan.spec.storeys != 1 or plan.spec.cellars != 0 \
			or minf(plan.spec.width, plan.spec.length) < WITCH_WORKSHOP_MIN_SITE_SPAN:
		return {}
	var inner := interior_rect(plan.spec)
	var candidates: Array[Dictionary] = []
	for room_index in plan.rooms_of(&"workshop"):
		if plan.storey_of_room(room_index) != 0 or plan.is_polygonal(room_index):
			continue
		var room: Rect2 = plan.rooms[room_index]["rect"]
		var floor := room_floor_rect(plan, room_index)
		if not room_suits(plan, room_index, &"workshop") or floor.get_area() < 8.0 or minf(floor.size.x, floor.size.y) < 2.45:
			continue
		var edges := [
			{"normal": Vector2(0, -1), "line": inner.position.y, "lo": room.position.x, "hi": room.end.x, "on": absf(room.position.y - inner.position.y) < 0.02, "rank": 1},
			{"normal": Vector2(0, 1), "line": inner.end.y, "lo": room.position.x, "hi": room.end.x, "on": absf(room.end.y - inner.end.y) < 0.02, "rank": 4},
			{"normal": Vector2(-1, 0), "line": inner.position.x, "lo": room.position.y, "hi": room.end.y, "on": absf(room.position.x - inner.position.x) < 0.02, "rank": 3},
			{"normal": Vector2(1, 0), "line": inner.end.x, "lo": room.position.y, "hi": room.end.y, "on": absf(room.end.x - inner.end.x) < 0.02, "rank": 3},
		]
		var top := witch_high_core_rect(plan)
		if top.size.x < 0.01 or top.size.y < 0.01:
			top = storey_rect(plan, 0)
		var span := minf(top.size.x, top.size.y)
		var along := maxf(top.size.x, top.size.y)
		var ridge := witch_ridge_x(plan, span + roof_span_out(plan.spec) * 2.0)
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0 if top.size.x > top.size.y else 0.0), Vector3(top.get_center().x, plan.spec.height, top.get_center().y))
		for edge in edges:
			if not edge["on"] or float(edge.hi) - float(edge.lo) < 3.3:
				continue
			var local_n := xf.basis.inverse() * Vector3(edge.normal.x, 0.0, edge.normal.y)
			if absf(local_n.x) < 0.95:
				continue # the shed must follow one eave, parallel to the ridge
			var shell := site_rect(plan.spec, 0)
			var roof_line := float(shell.position.x) if edge.normal.x < 0.0 else float(shell.end.x) if edge.normal.x > 0.0 else float(shell.position.y) if edge.normal.y < 0.0 else float(shell.end.y)
			var outer_world := Vector2(roof_line, float(edge.lo)) if absf(edge.normal.x) > 0.5 else Vector2(float(edge.lo), roof_line)
			var floor_inner_line := float(floor.end.x) if edge.normal.x < 0.0 else float(floor.position.x) if edge.normal.x > 0.0 else float(floor.end.y) if edge.normal.y < 0.0 else float(floor.position.y)
			var inside_world := Vector2(floor_inner_line, float(edge.lo)) if absf(edge.normal.x) > 0.5 else Vector2(float(edge.lo), floor_inner_line)
			var outer_local := xf.affine_inverse() * Vector3(outer_world.x, 0.0, outer_world.y)
			var inner_local := xf.affine_inverse() * Vector3(inside_world.x, 0.0, inside_world.y)
			if (outer_local.x - ridge) * (inner_local.x - ridge) <= 0.0:
				continue # keep the bay join wholly on one roof plane
			edge["room"] = room_index
			edge["room_bounds"] = room
			edge["rect"] = floor
			edge["rank"] = int(edge.rank) * 100 + float(edge.hi - edge.lo)
			candidates.append(edge)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.rank) > float(b.rank))
	var chosen: Dictionary = candidates[0]
	# The service roof follows the plan-marked connected wing, not only the
	# Workshop room. This lets an adjoining kitchen/store share one honest
	# lower roof while the yard threshold remains hosted by the Workshop.
	if bool(plan.rooms[int(chosen.room)].get("witch_service_wing", false)):
		var normal: Vector2 = chosen.normal
		var service_lo := float(chosen.lo)
		var service_hi := float(chosen.hi)
		var wing_lo := service_lo
		var wing_hi := service_hi
		var wing_rect: Rect2 = chosen.rect
		var wing_floor: Rect2 = chosen.rect
		var wing_room_indices: Array[int] = [int(chosen.room)]
		var room_bounds: Rect2 = chosen.get("room_bounds", wing_rect)
		var wing_left := normal.x < -0.5 and absf(room_bounds.position.x - inner.position.x) < 0.03
		var wing_right := normal.x > 0.5 and absf(room_bounds.end.x - inner.end.x) < 0.03
		var wing_front := normal.y < -0.5 and absf(room_bounds.position.y - inner.position.y) < 0.03
		var wing_back := normal.y > 0.5 and absf(room_bounds.end.y - inner.end.y) < 0.03
		var expanded := true
		while expanded:
			expanded = false
			for room_index in range(plan.rooms.size()):
				if room_index == int(chosen.room) or not bool(plan.rooms[room_index].get("witch_service_wing", false)):
					continue
				var raw: Rect2 = plan.rooms[room_index]["rect"]
				var floor := room_floor_rect(plan, room_index)
				var same_exterior_edge := (wing_left and absf(raw.position.x - inner.position.x) < 0.03) \
					or (wing_right and absf(raw.end.x - inner.end.x) < 0.03) \
					or (wing_front and absf(raw.position.y - inner.position.y) < 0.03) \
					or (wing_back and absf(raw.end.y - inner.end.y) < 0.03)
				if not same_exterior_edge:
					continue
				var lo := raw.position.y if absf(normal.x) > 0.5 else raw.position.x
				var hi := raw.end.y if absf(normal.x) > 0.5 else raw.end.x
				if hi < wing_lo - 0.03 or lo > wing_hi + 0.03:
					continue
				if lo < wing_lo - 0.03 or hi > wing_hi + 0.03:
					expanded = true
				wing_lo = minf(wing_lo, lo)
				wing_hi = maxf(wing_hi, hi)
				wing_rect = wing_rect.merge(raw)
				wing_floor = wing_floor.merge(floor)
				if not wing_room_indices.has(room_index):
					wing_room_indices.append(room_index)
		chosen["service_lo"] = service_lo
		chosen["service_hi"] = service_hi
		chosen["lo"] = wing_lo
		chosen["hi"] = wing_hi
		chosen["rect"] = wing_floor
		chosen["wing_rect"] = wing_floor
		chosen["wing_rooms"] = wing_room_indices
	chosen["wall_thickness"] = wall_thickness(plan.spec)
	return chosen


## A compact Witch shared hall can reach the service yard through its own
## exterior side wall. This is only a threshold descriptor. It does not grant
## the Hall a shed-roof bay: the asymmetric main roof's structural Workshop
## eligibility remains exclusively in witch_workshop_bay().
static func witch_compact_service_threshold(plan: HousePlan) -> Dictionary:
	if plan == null or plan.spec == null or plan.spec.get_script() != BASE_HOUSE_SPEC \
			or plan.spec.style != &"witch_hut" or plan.spec.trade != &"none" \
			or plan.spec.storeys != 1 or plan.spec.cellars != 0 or not plan.world_family.is_empty() \
			or plan.spec.has_method("room_program") or plan.spec.has_method("custom_room_rects") \
			or plan.spec.has_method("landmark_footprint") \
			or not HouseSpec.STYLES.get(plan.spec.style, {}).has("domestic_program"):
		return {}
	var inner := interior_rect(plan.spec)
	var preferred_wall := 3 if posmod(plan.spec.seed, 2) == 0 else 2
	var preferred_normal: Vector2 = exterior_runs(plan.spec)[preferred_wall]["normal"]
	for room_index in plan.rooms_of(&"hall"):
		var room_data: Dictionary = plan.rooms[room_index]
		var functions: Array = room_data.get("domestic_functions", [])
		if not bool(room_data.get("shared_witchwork", false)) \
				or not functions.has(&"cooking") or not functions.has(&"witchwork"):
			continue
		var room: Rect2 = room_data["rect"]
		var edge_length := room.size.y
		var width := DOOR_W
		var margin := DOOR_CORNER_MARGIN + width * 0.5
		if edge_length < width + margin * 2.0:
			continue
		# The compact Witch grammar makes the shared Hall full-width at the
		# front. Only a side edge that truly lies on the exterior wall qualifies.
		for side in [2, 3]:
			var run: Dictionary = exterior_runs(plan.spec)[side]
			var normal: Vector2 = run["normal"]
			if normal != preferred_normal:
				continue
			var exterior_x: float = inner.position.x if side == 2 else inner.end.x
			var room_x: float = room.position.x if side == 2 else room.end.x
			if absf(room_x - exterior_x) > 0.02:
				continue
			return {"room": room_index, "normal": normal, "line": exterior_x,
				"lo": room.position.y, "hi": room.end.y,
				"door_line_parameter": room.position.y + margin + 0.58,
				"compact_shared_hall": true,
				"wall_thickness": wall_thickness(plan.spec)}
	return {}


static func _witch_bay_local_point(xf: Transform3D, p: Vector2) -> Vector2:
	var local := xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
	return Vector2(local.x, local.z)


static func roof_layout(plan: HousePlan) -> Dictionary:
	var s := plan.spec
	var bay_candidate := witch_workshop_bay(plan)
	var high_core := witch_high_core_rect(plan) if not bay_candidate.is_empty() else Rect2()
	var has_high_core := high_core.size.x >= 0.01 and high_core.size.y >= 0.01
	var top := high_core if has_high_core else storey_rect(plan, maxi(s.storeys - 1, 0))
	var span := minf(top.size.x, top.size.y)
	var along := maxf(top.size.x, top.size.y)
	var rise := roof_rise(s)
	if has_high_core:
		# Keep the generated Witch pitch, but apply it to the measured high-core
		# span. The lower service roof joins the actual core plane separately.
		# A modest public Witch-only rise correction makes the high gable lead the
		# silhouette. The independent metre cap and measured seam/headroom gates
		# remain authoritative; trade/world/custom houses never enter this branch.
		rise = minf(span * s.roof_pitch * 0.64, clampf(span * 0.52, 3.6, 5.6))
	var xf := Transform3D(Basis(Vector3.UP, PI / 2.0 if top.size.x > top.size.y else 0.0),
		Vector3(top.get_center().x, s.height * maxi(s.storeys, 1), top.get_center().y))
	var span_out := roof_span_out(s)
	var full_span := span + span_out * 2.0
	var full_along := along + roof_along_out(s) * 2.0
	var ridge_x := 0.0
	var ridge_half := ridge_half_for(s, span, along, plan.world_family)
	var roof: Array[PackedVector3Array]
	if uses_witch_asymmetric_roof(s, plan.world_family):
		# Preserve the structural off-axis ridge and cut only its end planes. The
		# bay remains joined to the measured side planes; no room or roof type changes.
		ridge_x = witch_ridge_x(plan, full_span)
		if uses_witch_half_hip_roof(s, plan.world_family):
			roof = RoofShape.asymmetric_half_hip(full_span, full_along, rise,
				ridge_x, ridge_half)
		else:
			roof = RoofShape.asymmetric_gable(full_span, full_along, rise, ridge_x)
	else:
		roof = RoofShape.faces(full_span, full_along, rise, s.roof_type)
	var layout := {"transform": xf, "span": span, "along": along, "rise": rise,
		"ridge_x": ridge_x, "ridge_half": ridge_half, "faces": roof,
		"dormers": [], "rejections": [], "requested": 0}
	var witch_bay := bay_candidate
	if not witch_bay.is_empty():
		var normal: Vector2 = witch_bay["normal"]
		var shell := site_rect(s, 0)
		var roof_line := float(shell.position.x) if normal.x < 0.0 else float(shell.end.x) if normal.x > 0.0 else float(shell.position.y) if normal.y < 0.0 else float(shell.end.y)
		var outer_a := Vector2(roof_line, float(witch_bay.lo)) if absf(normal.x) > 0.5 else Vector2(float(witch_bay.lo), roof_line)
		var outer_b := Vector2(roof_line, float(witch_bay.hi)) if absf(normal.x) > 0.5 else Vector2(float(witch_bay.hi), roof_line)
		var inner_line := float(witch_bay.rect.end.x) if normal.x < 0.0 else float(witch_bay.rect.position.x) if normal.x > 0.0 else float(witch_bay.rect.end.y) if normal.y < 0.0 else float(witch_bay.rect.position.y)
		var inner_a := Vector2(inner_line, float(witch_bay.lo)) if absf(normal.x) > 0.5 else Vector2(float(witch_bay.lo), inner_line)
		var inner_b := Vector2(inner_line, float(witch_bay.hi)) if absf(normal.x) > 0.5 else Vector2(float(witch_bay.hi), inner_line)
		var local_normal3 := xf.basis.inverse() * Vector3(normal.x, 0.0, normal.y)
		var axis := 0 if absf(local_normal3.x) > 0.5 else 1
		var outer_pad := span_out if axis == 0 else roof_along_out(s)
		var local_outer_a := _witch_bay_local_point(xf, outer_a + normal * outer_pad)
		var local_outer_b := _witch_bay_local_point(xf, outer_b + normal * outer_pad)
		var local_inner_a := _witch_bay_local_point(xf, inner_a)
		var local_inner_b := _witch_bay_local_point(xf, inner_b)
		var local_poly := PackedVector2Array([local_outer_a, local_outer_b, local_inner_b, local_inner_a])
		var outer_coord := local_outer_a.x if axis == 0 else local_outer_a.y
		var inner_coord := local_inner_a.x if axis == 0 else local_inner_a.y
		var wall_station_world := (float(witch_bay.lo) + float(witch_bay.hi)) * 0.5
		var core_wall_world := Vector2(top.position.x if normal.x < 0.0 else top.end.x, wall_station_world) if absf(normal.x) > 0.5 else Vector2(wall_station_world, top.position.y if normal.y < 0.0 else top.end.y)
		var core_wall_local := _witch_bay_local_point(xf, core_wall_world)
		var wall_outer_coord := core_wall_local.x if axis == 0 else core_wall_local.y
		var source_a_along: float = local_outer_a.y if axis == 0 else local_outer_a.x
		var source_b_along: float = local_outer_b.y if axis == 0 else local_outer_b.x
		var source_lo := minf(source_a_along, source_b_along)
		var source_hi := maxf(source_a_along, source_b_along)
		var interior_bounds := interior_rect(s)
		var along_world_lo := float(interior_bounds.position.y) if absf(normal.x) > 0.5 else float(interior_bounds.position.x)
		var along_world_hi := float(interior_bounds.end.y) if absf(normal.x) > 0.5 else float(interior_bounds.end.x)
		var edge_lo_external := absf(float(witch_bay.lo) - along_world_lo) <= 0.035
		var edge_hi_external := absf(float(witch_bay.hi) - along_world_hi) <= 0.035
		var source_a_is_lo := source_a_along <= source_b_along
		var source_lo_external := edge_lo_external if source_a_is_lo else edge_hi_external
		var source_hi_external := edge_hi_external if source_a_is_lo else edge_lo_external
		var full_along_half := full_along * 0.5
		var along_lo := -full_along_half if source_lo_external else source_lo
		var along_hi := full_along_half if source_hi_external else source_hi
		var mid_along := (along_lo + along_hi) * 0.5
		var eave_y := RoofShape.height_at(roof, Vector2(outer_coord, mid_along) if axis == 0 else Vector2(mid_along, outer_coord))
		if not is_finite(eave_y):
			eave_y = 0.0
		# The service-room boundary is at the high roof's eave. Move its join
		# into the measured main plane until the whole half-hip seam has enough
		# fall to meet the lower roof. At the half-hip end stations the side-plane
		# intersection is shared with the end triangles, so one constant joining
		# line remains a real, continuous roof seam.
		var join_found := false
		var join_host := NAN
		var join_coord := inner_coord
		var join_direction := signf(ridge_x - inner_coord)
		var required_host_height := eave_y + 0.54
		if absf(join_direction) > 0.5:
			for step in range(0, 1000):
				var candidate_coord := inner_coord + join_direction * float(step) * 0.005
				if (ridge_x - candidate_coord) * join_direction <= 0.025:
					break
				var heights: Array[float] = []
				for station in [along_lo, mid_along, along_hi]:
					var probe := Vector2(candidate_coord, float(station)) if axis == 0 else Vector2(float(station), candidate_coord)
					heights.append(RoofShape.height_at(roof, probe))
				if heights.any(func(y: float) -> bool: return not is_finite(y)):
					continue
				var minimum_host := minf(heights[0], minf(heights[1], heights[2]))
				if minimum_host >= required_host_height:
					join_found = true
					join_coord = candidate_coord
					join_host = heights[1]
					break
		if join_found:
			inner_coord = join_coord
			if axis == 0:
				local_inner_a.x = join_coord
				local_inner_b.x = join_coord
			else:
				local_inner_a.y = join_coord
				local_inner_b.y = join_coord
		var host_point := Vector2(inner_coord, mid_along) if axis == 0 else Vector2(mid_along, inner_coord)
		var host_height := RoofShape.height_at(roof, host_point)
		var host_a := RoofShape.height_at(roof, Vector2(inner_coord, along_lo) if axis == 0 else Vector2(along_lo, inner_coord))
		var host_b := RoofShape.height_at(roof, Vector2(inner_coord, along_hi) if axis == 0 else Vector2(along_hi, inner_coord))
		var floor_rect: Rect2 = witch_bay["rect"]
		var floor_local_a := _witch_bay_local_point(xf, floor_rect.position)
		var floor_local_b := _witch_bay_local_point(xf, Vector2(floor_rect.end.x, floor_rect.position.y))
		var floor_local_c := _witch_bay_local_point(xf, floor_rect.end)
		var floor_local_d := _witch_bay_local_point(xf, Vector2(floor_rect.position.x, floor_rect.end.y))
		var floor_outline := PackedVector2Array([floor_local_a, floor_local_b, floor_local_c, floor_local_d])
		var floor_bounds := Poly.bounding_rect(floor_outline)
		var floor_cross_lo := floor_bounds.position.x if axis == 0 else floor_bounds.position.y
		var floor_cross_hi := floor_bounds.end.x if axis == 0 else floor_bounds.end.y
		var floor_along_lo := floor_bounds.position.y if axis == 0 else floor_bounds.position.x
		var floor_along_hi := floor_bounds.end.y if axis == 0 else floor_bounds.end.x
		# The occupied room stops at its partition, but the shed joins the high
		# core farther in. Continue the interior roof liner from the actual inner
		# wall face to that measured join so the strip above the partition is closed.
		var ceiling_outer := floor_cross_lo if absf(floor_cross_lo - outer_coord) <= absf(floor_cross_hi - outer_coord) else floor_cross_hi
		var ceiling_inner := join_coord
		var ceiling_cross_lo := minf(ceiling_outer, ceiling_inner)
		var ceiling_cross_hi := maxf(ceiling_outer, ceiling_inner)
		var ceiling_outline := PackedVector2Array()
		if axis == 0:
			ceiling_outline = PackedVector2Array([Vector2(ceiling_cross_lo, floor_along_lo),
				Vector2(ceiling_cross_hi, floor_along_lo), Vector2(ceiling_cross_hi, floor_along_hi),
				Vector2(ceiling_cross_lo, floor_along_hi)])
		else:
			ceiling_outline = PackedVector2Array([Vector2(floor_along_lo, ceiling_cross_lo),
				Vector2(floor_along_hi, ceiling_cross_lo), Vector2(floor_along_hi, ceiling_cross_hi),
				Vector2(floor_along_lo, ceiling_cross_hi)])
		var ceiling_bounds := Poly.bounding_rect(ceiling_outline)
		var join_y := minf(rise * 0.55, host_height - 0.05) if join_found and is_finite(host_height) else -1.0
		var minimum_clearance := s.height + minf(eave_y, join_y) - RoofShape.DEPTH * 0.5 - 0.015 - FLOOR_T
		if join_found and is_finite(join_y) and join_y >= eave_y + 0.45 and absf(inner_coord - outer_coord) >= 2.45 and minimum_clearance >= 2.30:
			var cut_poly := PackedVector2Array()
			if axis == 0:
				cut_poly = PackedVector2Array([Vector2(outer_coord, along_lo), Vector2(outer_coord, along_hi), Vector2(inner_coord, along_hi), Vector2(inner_coord, along_lo)])
			else:
				cut_poly = PackedVector2Array([Vector2(along_lo, outer_coord), Vector2(along_hi, outer_coord), Vector2(along_hi, inner_coord), Vector2(along_lo, inner_coord)])
			var wall_end_a := _witch_bay_local_point(xf, outer_a)
			var wall_end_b := _witch_bay_local_point(xf, outer_b)
			var ceiling_lo := ceiling_bounds.position.y if axis == 0 else ceiling_bounds.position.x
			var ceiling_hi := ceiling_bounds.end.y if axis == 0 else ceiling_bounds.end.x
			layout["witch_bay"] = {"room": int(witch_bay.room), "outline": cut_poly,
				"ceiling_outline": ceiling_outline, "normal": normal, "axis": axis,
				"wing_rect": floor_rect, "wing_rooms": witch_bay.get("wing_rooms", [int(witch_bay.room)]),
				"service_lo": witch_bay.get("service_lo", witch_bay.lo),
				"service_hi": witch_bay.get("service_hi", witch_bay.hi),
				"along_world_lo": witch_bay.lo, "along_world_hi": witch_bay.hi,
				# The high-core wall now lies at the service roof's join edge.
				# Clip that wall to the low roof plane, not the distant site facade.
				"wall_outer": wall_outer_coord,
				"wall_along_lo": wall_end_a.y if axis == 0 else wall_end_a.x,
				"wall_along_hi": wall_end_b.y if axis == 0 else wall_end_b.x,
				"minimum_clearance": minimum_clearance,
				"return_at_lo": not source_lo_external, "return_at_hi": not source_hi_external,
				"partition_head_y": 0.0,
				"outer": outer_coord, "inner": inner_coord, "along_lo": along_lo, "along_hi": along_hi,
				"ceiling_outer": ceiling_outer, "ceiling_inner": ceiling_inner,
				"ceiling_along_lo": ceiling_lo, "ceiling_along_hi": ceiling_hi,
				"eave_y": eave_y, "join_y": join_y, "host_y": host_height,
				"host_y_lo": host_a, "host_y_hi": host_b, "transform": xf}
		else:
			layout["witch_bay_rejection"] = "workshop roof has no supported half-hip seam with 0.45 m fall, 2.45 m clear span, and 2.30 m headroom"
			layout["witch_bay_rejection_detail"] = {"join_found": join_found, "required_host_y": required_host_height,
				"join_host_y": join_host, "eave_y": eave_y, "join_y": join_y,
				"join_backset": absf(join_coord - wall_outer_coord), "minimum_clearance": minimum_clearance}
	# A candidate that is turned away says WHY. A fitter that silently drops
	# dormers is indistinguishable from one that never tried, and the count
	# nobody can explain is the count nobody notices going wrong.
	var rejections: Array[Dictionary] = []
	layout["rejections"] = rejections
	if plan.has_court():
		rejections.append(_dormer_reject("", 0.0, &"court", "a court is sky; its ranges are roofed separately"))
		return layout
	if roof.is_empty():
		rejections.append(_dormer_reject("", 0.0, &"no_roof", "the roof descriptor produced no faces"))
		return layout
	if not s.dormers or s.dormer_count <= 0:
		return layout
	layout["requested"] = mini(s.dormer_count, 3)
	var half := span * 0.5 + span_out
	var dw := 0.95
	# Where a dormer can sit on a slope is RoofShape's question, not this
	# file's: the hotel asks it too, and asking it twice is how one of them
	# ends up with dormers a metre above their own roof (ROOF-AUDIT-001).
	var seat := RoofShape.dormer_seat(half, rise, -span * 0.5 * 0.62, dw)
	if not bool(seat["fits"]):
		rejections.append(_dormer_reject("", 0.0, &"no_seat",
			"pitch %.3f over half-span %.2f leaves no usable dormer face" % [rise / half, half]))
		return layout
	var front: float = seat["front"]
	var base: float = seat["base"]
	var eave: float = seat["eave"]
	var rh: float = seat["roof_half"]
	var peak_x: float = seat["peak_x"]
	var side_x: float = seat["side_x"]
	var cheek_x: float = seat["cheek_x"]
	var spacing := maxf(dw + 0.5, minf(along * 0.22, 2.4))
	var host := RoofShape.footprint(roof[0])
	var chimney := chimney_center(plan)
	var stack_size := chimney_size(s) + CHIMNEY_BASE_EXTRA
	var stack := Rect2(chimney - Vector2.ONE * (stack_size * 0.5 + 0.15),
		Vector2.ONE * (stack_size + 0.3))
	for count in range(mini(s.dormer_count, 3), 0, -1):
		var fitted: Array[Dictionary] = []
		# Rejections belong to the attempt that produced the accepted set. A
		# candidate turned away while trying three dormers is not a defect if
		# two then fit; the surviving attempt is the one worth explaining.
		var attempt_rejections: Array[Dictionary] = []
		for i in range(count):
			var z := (float(i) - float(count - 1) * 0.5) * spacing
			var cover := PackedVector2Array([Vector2(front - 0.12, z - rh),
				Vector2(side_x, z - rh), Vector2(peak_x, z),
				Vector2(side_x, z + rh), Vector2(front - 0.12, z + rh)])
			var id := "dormer_%d" % i
			var reason := &""
			var detail := ""
			var world_cover := PackedVector2Array()
			for p in cover:
				if reason == &"" and not Poly.contains_point(host, p):
					reason = &"off_face"
					detail = "corner (%.2f, %.2f) is not on the host face" % [p.x, p.y]
				for j in range(host.size()):
					var edge := host[(j + 1) % host.size()] - host[j]
					var gap: float = absf(edge.cross(p - host[j])) / edge.length()
					if gap < 0.12 and reason in [&"", &"off_face"]:
						reason = &"near_edge"
						detail = "corner (%.2f, %.2f) is %.3fm from a hip, ridge or verge" % [p.x, p.y, gap]
				var wp: Vector3 = xf * Vector3(p.x, 0, p.y)
				world_cover.append(Vector2(wp.x, wp.z))
			if s.chimney and Poly.bounding_rect(world_cover).intersects(stack):
				reason = &"chimney"
				detail = "footprint meets the chimney stack at %s" % str(stack)
			if reason != &"":
				attempt_rejections.append(_dormer_reject(id, z, reason, detail))
				continue
			var opening := PackedVector2Array([Vector2(front, z - dw * 0.5),
				Vector2(cheek_x, z - dw * 0.5), Vector2(peak_x, z),
				Vector2(cheek_x, z + dw * 0.5), Vector2(front, z + dw * 0.5)])
			fitted.append({"id": "dormer_%d" % i, "face": 0, "storey": s.storeys - 1,
				"kind": &"dormer", "opening": opening, "front": front, "z": z,
				"base": base, "eave": eave, "width": dw, "roof_half": rh,
				"peak_x": peak_x, "side_x": side_x, "cheek_x": cheek_x})
		if not fitted.is_empty():
			layout["dormers"] = fitted
			rejections.append_array(attempt_rejections)
			return layout
		if count == 1:
			rejections.append_array(attempt_rejections)
	return layout


## Top surface height at a world-space XZ point. The Witch chimney exits where
## its flue actually crosses the roof, which may be the low service plane.
static func roof_top_surface_at_plan(plan: HousePlan, world_xz: Vector2) -> float:
	if plan == null:
		return NAN
	return _roof_top_surface_in_layout(plan, roof_layout(plan), world_xz)


static func _roof_top_surface_in_layout(plan: HousePlan, layout: Dictionary,
		world_xz: Vector2) -> float:
	var xf: Transform3D = layout["transform"]
	var local := xf.affine_inverse() * Vector3(world_xz.x, xf.origin.y, world_xz.y)
	var bay: Dictionary = layout.get("witch_bay", {})
	var plane := NAN
	if not bay.is_empty():
		var axis := int(bay["axis"])
		var cross := local.x if axis == 0 else local.z
		var along := local.z if axis == 0 else local.x
		var outer := float(bay["outer"])
		var inner := float(bay["inner"])
		var along_lo := float(bay["along_lo"])
		var along_hi := float(bay["along_hi"])
		if cross >= minf(outer, inner) - 0.01 and cross <= maxf(outer, inner) + 0.01 \
				and along >= along_lo - 0.01 and along <= along_hi + 0.01:
			plane = lerpf(float(bay["eave_y"]), float(bay["join_y"]),
				clampf((cross - outer) / (inner - outer), 0.0, 1.0))
	if not is_finite(plane):
		var faces: Array[PackedVector3Array] = layout["faces"]
		plane = RoofShape.height_at(faces, Vector2(local.x, local.z))
	if not is_finite(plane):
		return NAN
	# This point is on the roof skin. Ridge caps and thatch bundles are separate
	# components, not a uniform vertical addition to every point on the roof.
	return xf.origin.y + plane + RoofShape.DEPTH * 0.5


## Highest roof surface sampled across a flue's physical footprint. A stack on
## an exterior wall can straddle the eave, so its centre alone is not a safe
## measure of where the roof pierces the masonry.
static func roof_top_surface_in_footprint(plan: HousePlan, centre: Vector2,
		footprint: Vector2) -> float:
	if plan == null or footprint.x <= 0.0 or footprint.y <= 0.0:
		return NAN
	var layout := roof_layout(plan)
	var highest := -INF
	for fx in [-0.5, 0.0, 0.5]:
		for fy in [-0.5, 0.0, 0.5]:
			var sample := centre + Vector2(float(fx) * footprint.x, float(fy) * footprint.y)
			var y := _roof_top_surface_in_layout(plan, layout, sample)
			if is_finite(y):
				highest = maxf(highest, y)
	return highest if is_finite(highest) else NAN


static func _dormer_reject(id: String, z: float, reason: StringName,
		detail: String) -> Dictionary:
	return {"id": id, "z": z, "reason": reason, "detail": detail}


## Every hole in the roof, in ONE shape, for every consumer: the dormer
## openings fitted by roof_layout plus whatever the plan authored (INT-018).
##
## Derived, never cached -- see HousePlan.roof_openings for why. Polygons are
## in the roof's own local XZ frame; transform them with roof_layout's
## `transform` to get world coordinates.
static func roof_openings(plan: HousePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(plan.roof_openings.size()):
		var authored := _normalise_roof_opening(plan.roof_openings[i], i, plan)
		if not authored.is_empty():
			out.append(authored)
	for d in roof_layout(plan)["dormers"]:
		out.append({"id": String(d["id"]), "kind": &"dormer",
			"storey": int(d["storey"]), "face": int(d["face"]),
			"polygon": d["opening"], "room": -1})
	return out


## Convert the authored shorthand (rect for a compluvium/open court, bounding
## rect for an oculus) into the one polygon representation consumed by the
## roof emitter and its checks.  The source plan remains untouched: callers
## often reuse it for a second roof shape, so this is deliberately derived.
static func _normalise_roof_opening(raw: Dictionary, index: int,
		plan: HousePlan) -> Dictionary:
	var kind: StringName = StringName(raw.get("kind", &"open"))
	if not kind in [&"compluvium", &"oculus", &"open"]:
		return {}
	var poly := PackedVector2Array()
	if raw.has("polygon"):
		for p in raw["polygon"]:
			poly.append(Vector2(p))
	elif raw.has("rect"):
		var rect := Rect2(raw["rect"])
		if rect.size.x <= 0.01 or rect.size.y <= 0.01:
			return {}
		if kind == &"oculus":
			var centre := rect.get_center()
			var radius := minf(rect.size.x, rect.size.y) * 0.5
			for n in range(24):
				var ang := TAU * float(n) / 24.0
				poly.append(centre + Vector2(cos(ang), sin(ang)) * radius)
		else:
			poly = Poly.from_rect(rect)
	else:
		return {}
	if poly.size() < 3 or Poly.area(poly) <= 0.0001:
		return {}
	var out: Dictionary = raw.duplicate(true)
	out["id"] = String(raw.get("id", "%s_%d" % [String(kind), index]))
	out["kind"] = kind
	out["storey"] = int(raw.get("storey", maxi(int(plan.spec.storeys) - 1, 0)))
	out["face"] = int(raw.get("face", -1))
	out["room"] = int(raw.get("room", -1))
	out["polygon"] = poly
	return out


## Why a candidate roof opening was not cut. Same derivation as above.
static func roof_opening_rejections(plan: HousePlan) -> Array[Dictionary]:
	return roof_layout(plan)["rejections"]


## Actual hearth-wall position shared by the chimney and roof attachments.
const BREAST_DEPTH := 0.5
const DOMESTIC_FIREPLACE_BREAST_WIDTH := 1.08

## A structural surround authored alongside the actual hearth placement.
## Its outline keeps diagonal walls honest; rect is only the broad-phase bound.
static func breast_for_hearth(plan: HousePlan, room: int, item: Dictionary, wall: int) -> Dictionary:
	var host: Dictionary = room_walls(plan, room)[wall]
	var normal: Vector2 = host["normal"]
	var along: Vector2 = (Vector2(host["to"]) - Vector2(host["from"])).normalized()
	var foot := PropCatalog.footprint(String(item["key"])) * float(item.get("scale", 1.0))
	var centre: Vector2 = Rect2(item["rect"]).get_center() - normal * (foot.y * 0.5 + BREAST_DEPTH * 0.5)
	var width := foot.x + 0.4
	var outline := PackedVector2Array([centre - along * width * 0.5 - normal * BREAST_DEPTH * 0.5,
		centre + along * width * 0.5 - normal * BREAST_DEPTH * 0.5,
		centre + along * width * 0.5 + normal * BREAST_DEPTH * 0.5,
		centre - along * width * 0.5 + normal * BREAST_DEPTH * 0.5])
	return {"room": room, "storey": plan.storey_of_room(room), "wall": wall,
		"centre": centre, "normal": normal, "width": width, "depth": BREAST_DEPTH,
		"outline": outline, "rect": Poly.bounding_rect(outline), "yaw": float(item["yaw"])}


## Native ordinary-house fireplace host. Width is structural, not borrowed from a prop.
## The opening is derived from this width by HouseBuilder, so planning and emitted
## masonry share one measured envelope.
static func breast_for_domestic_fireplace(plan: HousePlan, room: int, wall: int) -> Dictionary:
	var width: float = DOMESTIC_FIREPLACE_BREAST_WIDTH
	var walls: Array[Dictionary] = room_walls(plan, room)
	if wall < 0 or wall >= walls.size() or width <= 0.0:
		return {}
	var host: Dictionary = walls[wall]
	var normal: Vector2 = host["normal"]
	var along: Vector2 = (Vector2(host["to"]) - Vector2(host["from"])).normalized()
	var span: Vector2 = HousePlanFeatures.clear_wall_span(plan, room, wall)
	if span.y - span.x < width + 0.10:
		return {}
	var along_coordinate := (span.x + span.y) * 0.5
	var start: Vector2 = host["from"]
	var finish: Vector2 = host["to"]
	var axis_delta := finish.x - start.x if absf(normal.y) > 0.5 else finish.y - start.y
	if absf(axis_delta) < 0.001:
		return {}
	var axis_start := start.x if absf(normal.y) > 0.5 else start.y
	var wall_point := start.lerp(finish, (along_coordinate - axis_start) / axis_delta)
	var centre: Vector2 = wall_point + normal * (BREAST_DEPTH * 0.5)
	var outline := PackedVector2Array([centre - along * width * 0.5 - normal * BREAST_DEPTH * 0.5,
		centre + along * width * 0.5 - normal * BREAST_DEPTH * 0.5,
		centre + along * width * 0.5 + normal * BREAST_DEPTH * 0.5,
		centre - along * width * 0.5 + normal * BREAST_DEPTH * 0.5])
	return {"room": room, "storey": plan.storey_of_room(room), "wall": wall,
		"centre": centre, "normal": normal, "width": width, "depth": BREAST_DEPTH,
		"outline": outline, "rect": Poly.bounding_rect(outline),
		"yaw": HouseFurnishGeometry.yaw_facing(normal)}


static func hearth_breast(plan: HousePlan) -> Dictionary:
	return plan.hearth.get("breast", {})


static func chimney_center(plan: HousePlan) -> Vector2:
	var s := chimney_size(plan.spec)
	var r := site_rect(plan.spec)
	var c := Vector2(r.end.x + s / 2.0 - 0.15, 0.0)
	var host := plan.hearth_room()
	if host < 0:
		return c
	var wall := plan.hearth_wall()
	var run := HousePlanFeatures.clear_wall_span(plan, host, wall)
	var along := (run.x + run.y) * 0.5
	if plan.focus_room() == host and plan.focus_cat() == "hearth" and plan.focus_pos().is_finite():
		along = plan.focus_pos().x if wall <= 1 else plan.focus_pos().y
	# When a Witch workshop gets its own lower roof, the high-core roof ends at
	# the site eave. Keep its flue axis on the actual exterior wall line so the
	# emitted stack crosses that roof; the old half-stack exterior offset put
	# the narrow flue 0.375 m outside the high-core roof. Other house grammars
	# retain the established external-stack setback.
	var split_witch_roof := not witch_workshop_bay(plan).is_empty()
	match wall:
		0: c = Vector2(along, r.position.y if split_witch_roof else r.position.y - s / 2.0 + 0.15)
		1: c = Vector2(along, r.end.y if split_witch_roof else r.end.y + s / 2.0 - 0.15)
		2: c = Vector2(r.position.x if split_witch_roof else r.position.x - s / 2.0 + 0.15, along)
		_: c = Vector2(r.end.x if split_witch_roof else r.end.x + s / 2.0 - 0.15, along)
	return c


## ---------------------------------------------------------- exterior bounds
##
## What the house actually occupies, as opposed to what its walls do. Every
## number below is the SAME number the builder emits with, named here once:
## a bound derived from a different constant than the emitter uses is a bound
## that drifts the first time either changes.
##
## Heights are measured from the wall head, which is where the roof's frame
## sits. A feature that does not apply contributes nothing.

## The roof slab is centred on its mid-plane, so the ridge's top surface is
## half a slab above the rise. RoofShape.DEPTH owns the thickness.
const RIDGE_SLAB_TOP := RoofShape.DEPTH * 0.5
## HouseBuilder._build_roof caps the ridge with a 0.16 m box centred 0.14 m
## above the rise.
const RIDGE_CAP_TOP := 0.14 + 0.16 * 0.5
## A finial stands on the ridge cap: 0.55 m tall, centred on rise + 0.22. Only
## a FULL gable has one -- a half hip has no apex to stand it on.
const FINIAL_TOP := 0.22 + 0.55 * 0.5
## HouseBuilder.CHIMNEY_CLEAR + the crown slab + a flue pot. The chimney is the
## tallest thing on an ordinary house and the old bound missed all of it.
const CHIMNEY_TOP := 0.6 + 0.18 + CHIMNEY_POT_H
## The verge: how far past the roof's own end the boards, pendants and finial
## stand, and how far the board's foot kicks out past the eave. These are the
## numbers HouseBuilder._build_bargeboards emits with -- it reads them from
## here, so a bound cannot disagree with the thing it bounds.
const VERGE_END_OUT := 0.28
const VERGE_KICK := 0.10
const FINIAL_D := 0.12
const VERGE_PENDANT_D := 0.09
## How far the roof oversails its walls: RoofShape is built at span + 0.7
## across and along + 0.5 with the ridge.
const ROOF_SPAN_OUT := 0.35
const ROOF_ALONG_OUT := 0.25
## Stone quoins are 0.56 m deep at their widest course, centred on the corner,
## so they reach this far past the wall line on BOTH axes.
const QUOIN_OUT := 0.28

# ---- rich-house ornament (HOUSE-RICH) ----
## The crown at the wall head, in three steps: the corona is the one that
## oversails, and CORNICE_OUT is how far past the wall face it reaches.
## HouseBuilder._build_rich_cornice emits with these numbers and the bound
## below grows by the same one, so a bound cannot disagree with the thing it
## bounds -- the failure house_bounds_suite exists to catch.
const CORNICE_H := 0.36
const CORNICE_BED_OUT := 0.12
const CORNICE_OUT := 0.30
const CORNICE_CROWN_OUT := 0.20
## The band at a storey line. Shallower than the crown, which is why a bound
## grown by CORNICE_OUT already contains every band on every storey below it.
const BAND_H := 0.18
const BAND_OUT := 0.13
## A pediment over an upper window: its base runs PEDIMENT_MARGIN either side
## of the opening, its apex stands PEDIMENT_RISE above that. Both are CAPS --
## the emitter shrinks the rise to whatever the storey has under its own head.
const PEDIMENT_MARGIN := 0.34
const PEDIMENT_RISE := 0.42
const PEDIMENT_OUT := 0.22
const PEDIMENT_MIN_RISE := 0.18
## The ridge crown: a plinth and an obelisk standing on the ridge cap, which is
## 0.22 m wide (HouseBuilder._emit_ridge_cap_segments). The plinth overhangs it
## by 40 mm and the obelisk is narrower than the plinth, so nothing is left
## hanging over the slope with air under it.
## roof_top_above_walls() adds CROWN_BASE_H + CROWN_H to the rise, and
## HouseBuilder._build_ridge_crown emits from the same pair: the silhouette the
## bound promises and the mesh it must contain agree by construction.
const CROWN_BASE_W := 0.30
const CROWN_BASE_H := 0.14
const CROWN_W := 0.18
const CROWN_H := 1.15

# ---- vernacular exterior culture (HOUSE-CULTURE) ----
## The roof's two oversails, in metres, resolved from the spec. A negative
## `roof_span_out` is the ordinary 0.35 m eave; a style row may ask instead for
## the deep eave of a stilted house or the wide skirt of a thatched cone. The
## emitter and the bound BOTH read this, so a deep-eaved house can never be
## looser than the eave it actually built.
##
## TWO functions, not one returning a Vector2, and that is not tidiness. A
## `Vector2`'s components are 32-bit, so returning `Vector2(ROOF_SPAN_OUT, ...)`
## and reading `.x` back gave 0.34999999403953552 instead of 0.35 -- six
## nanometres of error in every roof the builder laid, which is invisible in a
## picture and moves a vertex hash. GDScript's `float` is 64-bit; the emitter's
## arithmetic has to stay in it.
static func roof_span_out(spec: HouseSpec) -> float:
	return ROOF_SPAN_OUT if spec.roof_span_out < 0.0 else spec.roof_span_out


static func roof_along_out(spec: HouseSpec) -> float:
	return ROOF_ALONG_OUT if spec.roof_along_out < 0.0 else spec.roof_along_out


## The same two numbers as a Vector2, for the BOUND only. Every consumer of
## this one compares an AABB, and `verge_overhang` has always returned 32-bit
## components; see roof_span_out for why the emitters do not use it.
static func roof_oversail(spec: HouseSpec) -> Vector2:
	return Vector2(roof_span_out(spec), roof_along_out(spec))


## How far the rafter tails stand out from the wall face on an ordinary eave.
## `HouseBuilder._build_eaves_tails` adds this to half the wall's span, and adds
## the eave's own EXTRA oversail on top of it -- so a house with the ordinary
## 0.35 m eave gets exactly the number it always got, and a deep-eaved one gets
## its tails at the eave it actually built.
const EAVE_TAIL_OUT := 0.15


## An eaves parapet: a rendered wall standing on the roof's own edge, with its
## outer face ON the eave rather than past it, so it costs the plan bound
## nothing. It is the cheapest honest way to say "this is not a house with a
## roof on it, it is a house with a terrace", and it only reads because the
## roof behind it is shallow.
const PARAPET_T := 0.30
const PARAPET_H := 0.62
## The slab's own top face at the eave, which is where the parapet starts.
const PARAPET_BASE := RoofShape.DEPTH * 0.5


## A veranda: a platform on the ground, posts, a head beam and a shed rooflet
## over all three. HouseBuilder._build_veranda emits every piece from these
## numbers, and veranda_rect() is the footprint the bound merges.
const VERANDA_DECK_T := 0.16
const VERANDA_POST_W := 0.16
const VERANDA_POSTS := 4
const VERANDA_BEAM_W := 0.18
const VERANDA_BEAM_H := 0.22
const VERANDA_ROOF_T := 0.16
const VERANDA_ROOF_FALL := 0.55   # the rooflet drops this much to its outer edge
const VERANDA_EAVE_OUT := 0.30     # and oversails the posts by this much
## Head height of the veranda roof against the wall. Capped below the storey it
## serves, because a veranda taller than its own floor is a canopy.
const VERANDA_HEAD_MAX := 2.35
const VERANDA_HEAD_CLEAR := 0.4


## The eave sweep: a fin at each of the four roof corners standing SWEEP_UP
## above the eave and reaching SWEEP_RUN back along it. It is set INBOARD of
## the eave and stops there, so like the parapet it costs the plan bound
## nothing -- it is the roof's own oversail that reaches past it.
const SWEEP_UP := 0.55
const SWEEP_RUN := 0.95
const SWEEP_T := 0.14


## The thatch roll. Reeds are combed and bundled at the ridge at intervals, not
## run as one continuous capping, so the roll is a short fin every ROLL_PITCH
## along the ridge; the eave is one thick rolled bundle capping both eaves.
## Only the ridge roll adds height, because only it stands above the slab.
const ROLL_PITCH := 0.55
const ROLL_W := 0.44
const ROLL_H := 0.3
const ROLL_T := 0.5
const THATCH_EAVE_W := 0.45
const THATCH_EAVE_H := 0.34
## What a thatch roll puts above the slab's own top face, which is the number
## roof_top_above_walls() has to promise once a house carries one.
const THATCH_ROLL_TOP := ROLL_H


## How far above the slab's own mid-plane the tallest thing the ROOF puts up
## stands. The ridge cap and a thatch roll compete for this one number, and
## both the emitter that measures the shell's height and the bound that
## promises it read it here, so the two cannot disagree about a thatched roof.
static func has_witch_roofcraft(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return spec != null and uses_witch_asymmetric_roof(spec, world_family) \
		and spec.roof_material == &"thatch"


## The clipped end planes are part of the same exact built-in Witch path as
## its bundled roof. A Witch trade or world-family roof keeps its source shape.
static func uses_witch_half_hip_roof(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return has_witch_roofcraft(spec, world_family) and spec.roof_type == &"half_hipped"


static func roof_has_thatch_roll(spec: HouseSpec, world_family: StringName = &"") -> bool:
	if spec == null:
		return false
	return spec.thatch_roll or has_witch_roofcraft(spec, world_family)


static func roof_slab_top(spec: HouseSpec, world_family: StringName = &"") -> float:
	# A cone has no ridge, so there is nothing to cap and no reeds to bundle
	# along one. Promising a cap's height here anyway would leave the bound
	# reaching for a piece that was never emitted, and a bound loose by more
	# than BOUNDS_TOL is as much a failure as one that is too tight.
	if ridge_half(spec, world_family) <= 0.05:
		return RIDGE_SLAB_TOP
	return maxf(RIDGE_CAP_TOP, THATCH_ROLL_TOP if roof_has_thatch_roll(spec, world_family) else 0.0)


## Rounded mud corners: a regular octagon standing on each corner of each
## storey, PIER_R in radius, so it reaches that far past the wall line. Every
## style that carries one also carries a roof oversail wider than PIER_R, so
## the eave already reaches past the piers and the plan bound is unchanged.
const PIER_R := 0.3
const PIER_SIDES := 8


## Head height of a veranda's roof where it meets the wall.
static func veranda_head(spec: HouseSpec) -> float:
	return minf(VERANDA_HEAD_MAX, maxf(2.0, spec.height - VERANDA_HEAD_CLEAR))


## The veranda's own footprint: the platform, its posts, and the rooflet that
## oversails them, on the wall the entrance is actually on. Merged into
## exterior_bounds() for the same reason the porch is -- it is emitted in the
## shell mesh, and a bound that promises to contain every emitted vertex has
## to contain this one too.
static func veranda_rect(plan: HousePlan) -> Rect2:
	var spec := plan.spec
	var d: int = plan.entrance()
	if not spec.veranda or d < 0:
		return Rect2()
	var door: Dictionary = plan.doors[d]
	var normal: Vector2 = door["normal"]
	var face: float = wall_thickness(spec) * 0.5
	var reach: float = face + spec.veranda_depth + VERANDA_EAVE_OUT
	var w: float = float(door["width"]) * 2.0 + VERANDA_POST_W * float(VERANDA_POSTS)
	var out_p: Vector2 = door["pos"] + normal * reach
	var in_p: Vector2 = door["pos"] - normal * (face + 0.05)
	var across: Vector2 = Vector2(normal.y, -normal.x) * (w * 0.5)
	var r := Rect2(out_p + across, Vector2.ZERO)
	for p in [out_p - across, in_p + across, in_p - across]:
		r = r.expand(p)
	return r


## How far the furthest piece a style row can add stands above the wall head.
## The bound reads this, and so does nothing else, so a house whose parapet or
## thatch roll grew past its own roof would be caught rather than tolerated.
static func parapet_top(spec: HouseSpec) -> float:
	return PARAPET_BASE + PARAPET_H if spec.parapet else 0.0



## Half the length of the ridge cap this roof carries, or zero when it has no
## ridge to cap. HouseBuilder._build_roof emits the cap and the ridge crown
## from this one number, so the two can never disagree about whether there is
## a ridge for a crown to stand on.
##
## `ridge_half_for` takes the span and along the roof was actually built from,
## so a plan whose top storey is shaped or opens onto a court is measured on
## the geometry that exists rather than on the rectangle its spec would give.
static func ridge_half_for(spec: HouseSpec, span: float, along: float,
		world_family: StringName = &"") -> float:
	# A cone has an apex, and a flat roof has no ridge, so neither can carry a
	# cap or a finial. One return keeps all ridge consumers in agreement.
	if spec.roof_type in [&"conical", &"flat"]:
		return 0.0
	var half: float = along * 0.5 + roof_along_out(spec)
	if uses_witch_half_hip_roof(spec, world_family):
		half = maxf(half - (span * 0.5 + roof_span_out(spec)) * (1.0 - RoofShape.HALF_HIP), 0.0)
	elif spec.roof_type != &"gable":
		# Preserve the established generic hip and half-hip arithmetic exactly.
		# In particular, a full hipped roof subtracts its entire half-span.
		var cut := RoofShape.HALF_HIP if spec.roof_type == &"half_hipped" else 0.0
		half = maxf(half - (span * 0.5 + roof_span_out(spec)) * (1.0 - cut), 0.0)
	return half


## The same ridge for a spec alone, which is all the exterior bound knows.
static func ridge_half(spec: HouseSpec, world_family: StringName = &"") -> float:
	var top := site_rect(spec, maxi(spec.storeys - 1, 0))
	return ridge_half_for(spec, minf(top.size.x, top.size.y), maxf(top.size.x, top.size.y), world_family)


## Bounds are promised to CONTAIN every shell vertex exactly, and to be no
## looser than this. Tested both ways.
const BOUNDS_TOL := 0.16


## Does this house have quoined corners instead of a timber ground floor?
## HouseBuilder._build_timber_frame_level swaps one for the other.
static func has_quoins(spec: HouseSpec) -> bool:
	return spec.material != &"stone" and spec.timber_frame and spec.stone_ground_floor


## How far the jetty reaches past the front wall.
##
## Not jetty_depth: the bressummer is set back half of it, the joist ends
## project past that, and the knee brackets are TILTED, so how far they swing
## depends on the bracket's own run and lift. HouseBuilder._build_jetty emits
## all three from these same numbers.
static func jetty_front_reach(spec: HouseSpec) -> float:
	if not spec.jetty or maxi(spec.storeys, 1) <= 1:
		return 0.0
	var j: float = spec.jetty_depth
	var joists: float = j + 0.05
	var bressummer: float = j * 0.5 + 0.10
	var run: float = minf(j * 1.2, 0.35)
	var lift: float = run * 1.4
	var tilt: float = atan2(lift, run)
	var length: float = sqrt(run * run + lift * lift)
	var brackets: float = j * 0.5 + length * 0.5 * sin(tilt) + 0.12 * 0.5 * cos(tilt)
	return maxf(maxf(joists, bressummer), brackets)


## How far above the wall head the roof and its attachments reach. Independent
## of which wall anything stands on, so it is exact from the spec alone.
static func roof_top_above_walls(spec: HouseSpec, world_family: StringName = &"") -> float:
	var rise: float = roof_rise(spec)
	var witch_roll: bool = has_witch_roofcraft(spec, world_family)
	var top: float = rise + roof_slab_top(spec, world_family)
	if spec.bargeboards and spec.roof_type == &"gable" and not has_witch_roofcraft(spec, world_family):
		top = maxf(top, rise + FINIAL_TOP)
	if spec.chimney:
		top = maxf(top, rise + CHIMNEY_TOP + (THATCH_ROLL_TOP if witch_roll else 0.0))
	if spec.ridge_finial and ridge_half(spec, world_family) > 0.05:
		top = maxf(top, rise + RIDGE_CAP_TOP + CROWN_BASE_H + CROWN_H)
	if spec.parapet:
		top = maxf(top, parapet_top(spec))
	if spec.eave_sweep:
		top = maxf(top, SWEEP_UP)
	return top


## Height of the roof's ridge line above the ground: the top storey's wall head
## plus the rise. The roof faces in roof_layout() are built from these two
## numbers, so the blueprint's elevation can be compared with them.
static func ridge_height(spec: HouseSpec) -> float:
	return spec.height * float(maxi(spec.storeys, 1)) + roof_rise(spec)


## The roof the builder lays on this plan, from the family that owns it: the
## faces in the roof's own frame, the transform to world, and the rise. A
## house, a shop and a long hall share roof_layout(); a hotel has its mansard.
static func roof_of(plan: HousePlan) -> Dictionary:
	if plan.spec is HotelSpec:
		return HotelGeometry.roof_layout(plan.spec as HotelSpec)
	return roof_layout(plan)


## The ridge line's height above ground for any house-family spec.
static func ridge_of(spec: HouseSpec) -> float:
	if spec is HotelSpec:
		return HotelGeometry.wall_top(spec as HotelSpec) + (spec as HotelSpec).roof_rise
	return ridge_height(spec)


## The top of the finished shell, from the family that owns it: a hotel's
## cupolas stand above its roof.
static func shell_top(spec: HouseSpec) -> float:
	if spec is HotelSpec:
		return HotelGeometry.total_height(spec as HotelSpec)
	return total_height(spec)


## Exact top of the emitted shell, in world space.
static func total_height(spec: HouseSpec, world_family: StringName = &"") -> float:
	var raw_storeys = spec.get("storeys")
	var storeys: int = maxi(1, int(raw_storeys)) if raw_storeys != null else 1
	var wall_top: float = spec.height * storeys
	var top: float = wall_top + roof_top_above_walls(spec, world_family)
	if spec.porch:
		# A porch is short, but a single-storey cottage with a shallow roof is
		# shorter than you would think.
		top = maxf(top, DOOR_H + 0.35 + 0.42 + RoofShape.DEPTH * 0.5)
	return top


## How far the roof and its verge oversail the walls, as a half-extent on the
## roof's own two axes: x across the span, y along the ridge.
##
## Bargeboards reach past the roof on BOTH axes. Along the ridge they carry the
## finial, which is the deepest piece. Across the span the board's foot kicks
## out past the eave and the board itself is tilted to the pitch, so how far it
## reaches depends on the pitch -- which is why a constant was 0.128 m short on
## every bargeboarded house.
static func verge_overhang(spec: HouseSpec, world_family: StringName = &"",
		conservative_unknown_scope := false) -> Vector2:
	var span_out := roof_span_out(spec)
	var along_out := roof_along_out(spec)
	if not spec.bargeboards or (not conservative_unknown_scope \
			and has_witch_roofcraft(spec, world_family)) \
			or spec.roof_type in [&"hipped", &"conical"]:
		return Vector2(span_out, along_out)
	var top := site_rect(spec, maxi(spec.storeys - 1, 0))
	var span: float = minf(top.size.x, top.size.y)
	var half: float = (span + span_out * 2.0) * 0.5
	var ang: float = atan2(roof_rise(spec), half)
	# The board's foot, plus half its width swung out by the tilt. The drop
	# pendant hangs at the eave itself and is shallower than that.
	var across: float = maxf(VERGE_KICK * cos(ang) + BARGEBOARD_W * 0.5 * sin(ang),
		VERGE_PENDANT_D * 0.5)
	var along: float = VERGE_END_OUT + (FINIAL_D * 0.5 if spec.roof_type == &"gable"
		else VERGE_PENDANT_D * 0.5)
	return Vector2(span_out + across, along)


## verge_overhang mapped onto the WORLD axes. The roof turns to follow the
## longer footprint dimension, so the span overhang lands on the shorter axis.
static func roof_overhang(spec: HouseSpec, world_family: StringName = &"",
		conservative_unknown_scope := false) -> Vector2:
	var v := verge_overhang(spec, world_family, conservative_unknown_scope)
	var top := site_rect(spec, maxi(spec.storeys - 1, 0))
	return Vector2(v.x, v.y) if top.size.x <= top.size.y else Vector2(v.y, v.x)


## The chimney's own footprint, centred where the hearth actually put it.
static func chimney_rect(plan: HousePlan) -> Rect2:
	var spec := plan.spec
	if not spec.chimney:
		return Rect2()
	var c := chimney_center(plan)
	# The widest course: a stepped base, or the crown that caps either style.
	var s: float = chimney_size(spec) + 0.22
	if spec.chimney_style == &"stepped":
		s = maxf(s, chimney_size(spec) + CHIMNEY_BASE_EXTRA)
	return Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s)


## An exterior door's clear opening in plan: its leaf width, out through the
## wall and half a metre past it. The chimney stack must stay out of it
## (EVAL-C12).
static func door_opening_rect(spec: HouseSpec, d: Dictionary) -> Rect2:
	var n: Vector2 = d["normal"]
	var pos: Vector2 = d["pos"]
	var half: float = float(d["width"]) * 0.5
	var reach: float = wall_thickness(spec) + 0.5
	if absf(n.y) > 0.5:
		var z1: float = pos.y + n.y * reach
		return Rect2(Vector2(pos.x - half, minf(pos.y, z1)), Vector2(half * 2.0, absf(z1 - pos.y)))
	var x1: float = pos.x + n.x * reach
	return Rect2(Vector2(minf(pos.x, x1), pos.y - half), Vector2(absf(x1 - pos.x), half * 2.0))


## The porch's own footprint, on the wall the entrance is actually on.
static func porch_rect(plan: HousePlan) -> Rect2:
	var spec := plan.spec
	var d: int = plan.entrance()
	if not spec.porch or d < 0:
		return Rect2()
	var door: Dictionary = plan.doors[d]
	var depth: float = porch_depth(spec)
	var w: float = float(door["width"]) + 1.1
	var normal: Vector2 = door["normal"]
	# The step runs from the door OUT by depth + 0.1 and back INTO the wall it
	# is fixed to; only the outward half can leave the footprint. Centring a
	# rect of the step's full length on the porch instead pushed the bound half
	# a wall thickness too far out.
	var centre := porch_center(plan)
	var out_p: Vector2 = centre + normal * (depth + 0.1)
	var in_p: Vector2 = centre - normal * (0.1 + wall_thickness(spec))
	var across: Vector2 = Vector2(normal.y, -normal.x) * (w * 0.5)
	var r := Rect2(out_p + across, Vector2.ZERO)
	for p in [out_p - across, in_p + across, in_p - across]:
		r = r.expand(p)
	return r


## EXACT planned exterior bounds of the shell, for a house that has a plan.
## Contains every emitted vertex and is no looser than BOUNDS_TOL.
##
## This is the bound a camera, a placement or a lot check should ask for. The
## spec-only pair below cannot know which wall the hearth or the entrance
## chose, so they are deliberately conservative instead.
static func exterior_bounds(plan: HousePlan) -> AABB:
	var spec := plan.spec
	var over := roof_overhang(spec, plan.world_family)
	# The roof grows from the real top-storey envelope; ground attachments
	# are merged separately, never added twice to the upper-storey overhang.
	var neg := over
	var pos := over
	if has_quoins(spec):
		neg = neg.max(Vector2.ONE * QUOIN_OUT)
		pos = pos.max(Vector2.ONE * QUOIN_OUT)
	if spec.cornice:
		# The crown at the wall head reaches past the face of the wall it
		# stands on, so it is planned exterior and not leakage.
		neg = neg.max(Vector2.ONE * CORNICE_OUT)
		pos = pos.max(Vector2.ONE * CORNICE_OUT)
	var r: Rect2 = site_rect(spec, maxi(spec.storeys - 1, 0)).grow_individual(neg.x, neg.y, pos.x, pos.y)
	r = r.merge(site_rect(spec).grow_individual(0, jetty_front_reach(spec), 0, 0))
	for extra in [chimney_rect(plan), porch_rect(plan), veranda_rect(plan)]:
		if extra.size.x > 0.0:
			r = r.merge(extra)
	# The yard's BUILT pieces are emitted in the shell mesh, so the bound that
	# promises to contain every emitted vertex contains them. The yard's props
	# are separate models (BrickWild.placement merges them), and the APRON itself
	# is permission, not content: it is exposed as `yard_rect`, never added here.
	if spec.exterior_props:
		for piece in plan.yard_pieces:
			r = r.merge(piece["rect"])
	var top: float = total_height(spec, plan.world_family)
	# A landmark declares the storybook elevation it stands in front of its
	# walls (balconies, entrance canopy, cornices, cupolas), so those parts
	# are planned exterior rather than leakage.
	if spec.has_method("landmark_footprint"):
		r = r.merge(spec.landmark_footprint())
		top = maxf(top, spec.landmark_height())
	return AABB(Vector3(r.position.x, 0.0, r.position.y),
		Vector3(r.size.x, top, r.size.y))


## The YARD ENVELOPE: the shell footprint with its porch and chimney stack,
## grown by the apron (2 to 3 m, by style). Everything the house plans outside
## its walls stays inside this; the lot owns the rest. A declared permission, not
## a measured extent -- so it is not part of exterior_bounds().
static func yard_rect(plan: HousePlan) -> Rect2:
	var r := site_rect(plan.spec)
	# The veranda is shell, not yard, but it stands on the same ground and the
	# yard's walk and its props both have to know where it is -- exactly as they
	# do for the porch.
	for extra in [chimney_rect(plan), porch_rect(plan), veranda_rect(plan)]:
		if extra.size.x > 0.0:
			r = r.merge(extra)
	return r.grow(HouseYard.apron(plan.spec))


## CONSERVATIVE spec-only bounds, for callers with no plan. The hearth and the
## entrance may be on any wall, so every wall is grown by what either could
## add. A superset of exterior_bounds(), never a subset -- and never presented
## as exact.
static func spec_bounds(spec: HouseSpec) -> AABB:
	# There is no plan here to establish an empty world family. Keep the legacy
	# bargeboard allowance while also retaining the physical-thatch height from
	# the built-in Witch path below; this is a superset of either context.
	var over := roof_overhang(spec, &"", true)
	if has_quoins(spec):
		over = over.max(Vector2.ONE * QUOIN_OUT)
	if spec.cornice:
		over = over.max(Vector2.ONE * CORNICE_OUT)
	# The front is known, but a spec alone cannot say which wall is the front
	# once the entrance moves, so the jetty reach is applied all round.
	var all_round: float = maxf(maxf(over.x, over.y), jetty_front_reach(spec))
	var r: Rect2 = site_rect(spec, maxi(spec.storeys - 1, 0)).grow(all_round)
	var pad := 0.0
	if spec.chimney:
		pad = maxf(pad, chimney_size(spec) + maxf(CHIMNEY_BASE_EXTRA, 0.22))
	if spec.porch:
		pad = maxf(pad, porch_depth(spec) + 0.2 + wall_thickness(spec))
	if spec.veranda:
		pad = maxf(pad, wall_thickness(spec) * 0.5
			+ HouseGenerator.VERANDA_DEPTH_RANGE[1] + VERANDA_EAVE_OUT)
	# The yard's built pieces are in the mesh and lie inside the envelope: the
	# apron beyond the shell, its porch and chimney stack.
	if spec.exterior_props and not spec.has_method("room_program"):
		pad += HouseYard.apron(spec)
	r = r.grow(pad)
	var top: float = maxf(total_height(spec), total_height(spec, &"__unknown_world_scope__"))
	return AABB(Vector3(r.position.x, 0.0, r.position.y),
		Vector3(r.size.x, top, r.size.y))


## Everything the house covers in plan, porch and chimney included.
## CONSERVATIVE spec-only footprint. Prefer exterior_bounds(plan) when a plan
## exists: this one does not know which wall the chimney or the porch is on,
## so it grows every wall by what either could add.
static func plan_extent(spec: HouseSpec) -> Rect2:
	var b := spec_bounds(spec)
	return Rect2(Vector2(b.position.x, b.position.z),
		Vector2(b.size.x, b.size.z))


static func porch_depth(spec: HouseSpec) -> float:
	return 1.8 if spec.style == &"witch_hut" else 1.35


## The witch canopy shelters the same door but sits slightly off-centre. The
## small offset gives the entry an accreted character without moving the door
## or its approach and is shared by emission and bounds.
static func porch_center(plan: HousePlan) -> Vector2:
	var d := plan.entrance()
	if d < 0:
		return Vector2.ZERO
	var door: Dictionary = plan.doors[d]
	var centre: Vector2 = door["pos"]
	if plan.spec.style == &"witch_hut":
		var normal: Vector2 = door["normal"]
		centre += Vector2(normal.y, -normal.x) * 0.24
	return centre


static func chimney_size(spec: HouseSpec) -> float:
	return 1.05


## A narrower upper flue is a Witch roofcraft detail. Its bearing breast and
## stepped lower stack retain the existing chimney_size footprint.
static func chimney_flue_size(spec: HouseSpec, world_family: StringName = &"") -> float:
	return 0.76 if uses_witch_asymmetric_roof(spec, world_family) else chimney_size(spec)
