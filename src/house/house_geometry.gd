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

# ---- furnishing ----
const WALL_GAP := 0.06        # how close a wall-hugging piece sits to the wall
const FURNITURE_DENSITY_MAX := 0.42   # of a room's floor, before it reads as a junk shop
const SHELF_HEIGHT := 1.55    # mounting height of a wall shelf or rack
const SCONCE_HEIGHT := 1.85
const BED_HEAD_TOL := 0.35    # how far a headboard may sit off its wall

# ---- rooms ----
const MIN_ROOM_SIDE := 2.1
const ROOM_ASPECT_MAX := 3.4

## Floor area a room of each kind needs to be worth calling that.
const MIN_AREA := {
	&"hall": 9.0, &"kitchen": 6.0, &"bedroom": 11.0, &"workshop": 8.0,
	&"store": 2.4, &"parlour": 8.0,
}

## And the narrowest it may be. Area alone is not enough: a bed is 1.9 x 2.4 m
## and wants three quarters of a metre down one side, so a 2 x 6 m room has the
## floor area of a bedroom and cannot hold a bed. A house that fails this test
## does not get a smaller bedroom -- it gets no bedroom, and the bed goes in the
## hall, which is what a one-room cottage has always done.
const MIN_SIDE := {
	&"hall": 2.6, &"kitchen": 2.2, &"bedroom": 3.3, &"workshop": 2.6,
	&"store": 1.6, &"parlour": 2.6,
}


## Can room `i` be called `kind` -- big enough, and not a corridor?
static func room_suits(plan: HousePlan, i: int, kind: StringName) -> bool:
	var f: Rect2 = room_floor_rect(plan, i)
	if f.size.x * f.size.y < float(MIN_AREA.get(kind, 4.0)):
		return false
	return minf(f.size.x, f.size.y) >= float(MIN_SIDE.get(kind, 1.6))

## Rooms people live in. A store room needs neither a window nor a chair.
const HABITABLE := [&"hall", &"kitchen", &"bedroom", &"workshop", &"parlour"]


# ------------------------------------------------------------------- shell

## Outer footprint of the house at wall-top level.
static func site_rect(spec: HouseSpec) -> Rect2:
	return Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))


## The ground the rooms partition: inside the exterior walls.
static func interior_rect(spec: HouseSpec) -> Rect2:
	return site_rect(spec).grow(-WALL_T)


## The four exterior wall runs, each as
## {"from": Vector2, "to": Vector2, "normal": Vector2, "side": StringName}.
## `from`/`to` run along the wall's CENTRE LINE, and `normal` points outdoors.
static func exterior_runs(spec: HouseSpec) -> Array[Dictionary]:
	var r: Rect2 = site_rect(spec).grow(-WALL_T / 2.0)
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
static func room_floor_rect(plan: HousePlan, i: int) -> Rect2:
	var rect: Rect2 = plan.rooms[i]["rect"]
	var inner: Rect2 = interior_rect(plan.spec)
	var half: float = INNER_WALL_T / 2.0
	var x0: float = rect.position.x + (0.0 if absf(rect.position.x - inner.position.x) < 0.01 else half)
	var x1: float = rect.end.x - (0.0 if absf(rect.end.x - inner.end.x) < 0.01 else half)
	var z0: float = rect.position.y + (0.0 if absf(rect.position.y - inner.position.y) < 0.01 else half)
	var z1: float = rect.end.y - (0.0 if absf(rect.end.y - inner.end.y) < 0.01 else half)
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))


static func room_area(plan: HousePlan, i: int) -> float:
	var f: Rect2 = room_floor_rect(plan, i)
	return f.size.x * f.size.y


static func room_aspect(plan: HousePlan, i: int) -> float:
	var f: Rect2 = room_floor_rect(plan, i)
	var lo: float = minf(f.size.x, f.size.y)
	var hi: float = maxf(f.size.x, f.size.y)
	return hi / maxf(lo, 0.01)


static func is_habitable(kind: StringName) -> bool:
	return kind in HABITABLE


## The four walls of a room's clear floor, as
## {"from": Vector2, "to": Vector2, "normal": Vector2} with `normal` pointing
## INTO the room. This is what a piece of furniture puts its back against.
static func room_walls(plan: HousePlan, i: int) -> Array[Dictionary]:
	var f: Rect2 = room_floor_rect(plan, i)
	return [
		{"from": f.position, "to": Vector2(f.end.x, f.position.y), "normal": Vector2(0, 1)},
		{"from": Vector2(f.position.x, f.end.y), "to": f.end, "normal": Vector2(0, -1)},
		{"from": f.position, "to": Vector2(f.position.x, f.end.y), "normal": Vector2(1, 0)},
		{"from": Vector2(f.end.x, f.position.y), "to": f.end, "normal": Vector2(-1, 0)},
	]


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
	var along := Vector2(n.y, -n.x).abs()
	var half: Vector2 = along * (float(win["width"]) / 2.0)
	var a: Vector2 = c - half
	var b: Vector2 = c + half + n * 0.35
	return Rect2(a.min(b), (b - a).abs())


static func window_area(win: Dictionary) -> float:
	return float(win["width"]) * float(win["head"] - win["sill"])


# ---------------------------------------------------------------- envelope

static func roof_rise(spec: HouseSpec) -> float:
	return minf(spec.width, spec.length) * spec.roof_pitch * 0.5


static func total_height(spec: HouseSpec) -> float:
	var raw_storeys = spec.get("storeys")
	var storeys: int = maxi(1, int(raw_storeys)) if raw_storeys != null else 1
	var wall_top: float = spec.height * storeys
	var top: float = wall_top + roof_rise(spec)
	if spec.chimney:
		top = maxf(top, wall_top + minf(roof_rise(spec), 2.0) + 1.06)
	return top


## Everything the house covers in plan, porch and chimney included.
static func plan_extent(spec: HouseSpec) -> Rect2:
	var e: Rect2 = site_rect(spec)
	if spec.porch:
		e = e.expand(Vector2(0.0, e.position.y - porch_depth(spec)))
	if spec.chimney:
		e = e.expand(Vector2(e.end.x + chimney_size(spec), 0.0))
	return e


static func porch_depth(spec: HouseSpec) -> float:
	return 1.35


static func chimney_size(spec: HouseSpec) -> float:
	return 1.05
