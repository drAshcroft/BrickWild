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
	&"lords_chamber": 10.0, &"nave": 12.0,
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
	&"lords_chamber": 2.8, &"nave": 2.8,
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
	&"lords_chamber", &"nave", &"reading_room", &"stacks", &"scriptorium",
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
	return minf(spec.width, spec.length) * spec.roof_pitch * 0.5


## Art direction, not a structural limit. Broad houses gain roof rise more
## slowly than width; witch huts deliberately keep their extravagant pitch.
## Applied only to generated pitch, never to an explicit emitter fixture.
static func art_pitch_scale(spec: HouseSpec) -> float:
	var reference := float({&"cottage": 7.0, &"farmhouse": 9.0,
		&"townhouse": 8.0, &"longhall": 8.0, &"witch_hut": 8.0}.get(spec.style, 8.0))
	var span := minf(spec.width, spec.length)
	if span <= reference:
		return 1.0
	return pow(reference / span, 0.2 if spec.style == &"witch_hut" else 0.5)


## Pure plan-space roof layout. Attachments and the emitter read the same
## face coordinates; rebuilding a mutable spec never leaves cached holes on
## a former roof. The transform's origin is the top storey's wall head.
static func roof_layout(plan: HousePlan) -> Dictionary:
	var s := plan.spec
	var top := storey_rect(plan, maxi(s.storeys - 1, 0))
	var span := minf(top.size.x, top.size.y)
	var along := maxf(top.size.x, top.size.y)
	var rise := roof_rise(s)
	var xf := Transform3D(Basis(Vector3.UP, PI / 2.0 if top.size.x > top.size.y else 0.0),
		Vector3(top.get_center().x, s.height * maxi(s.storeys, 1), top.get_center().y))
	var roof := RoofShape.faces(span + 0.7, along + 0.5, rise, s.roof_type)
	var layout := {"transform": xf, "span": span, "along": along, "rise": rise,
		"faces": roof, "dormers": [], "rejections": [], "requested": 0}
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
	var half := (span + 0.7) * 0.5
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
	match wall:
		0: c = Vector2(along, r.position.y - s / 2.0 + 0.15)
		1: c = Vector2(along, r.end.y + s / 2.0 - 0.15)
		2: c = Vector2(r.position.x - s / 2.0 + 0.15, along)
		_: c = Vector2(r.end.x + s / 2.0 - 0.15, along)
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
static func roof_top_above_walls(spec: HouseSpec) -> float:
	var rise: float = roof_rise(spec)
	var top: float = rise + maxf(RIDGE_SLAB_TOP, RIDGE_CAP_TOP)
	if spec.bargeboards and spec.roof_type == &"gable":
		top = maxf(top, rise + FINIAL_TOP)
	if spec.chimney:
		top = maxf(top, rise + CHIMNEY_TOP)
	return top


## Exact top of the emitted shell, in world space.
static func total_height(spec: HouseSpec) -> float:
	var raw_storeys = spec.get("storeys")
	var storeys: int = maxi(1, int(raw_storeys)) if raw_storeys != null else 1
	var wall_top: float = spec.height * storeys
	var top: float = wall_top + roof_top_above_walls(spec)
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
static func verge_overhang(spec: HouseSpec) -> Vector2:
	if not spec.bargeboards or spec.roof_type == &"hipped":
		return Vector2(ROOF_SPAN_OUT, ROOF_ALONG_OUT)
	var top := site_rect(spec, maxi(spec.storeys - 1, 0))
	var span: float = minf(top.size.x, top.size.y)
	var half: float = (span + 0.7) * 0.5
	var ang: float = atan2(roof_rise(spec), half)
	# The board's foot, plus half its width swung out by the tilt. The drop
	# pendant hangs at the eave itself and is shallower than that.
	var across: float = maxf(VERGE_KICK * cos(ang) + BARGEBOARD_W * 0.5 * sin(ang),
		VERGE_PENDANT_D * 0.5)
	var along: float = VERGE_END_OUT + (FINIAL_D * 0.5 if spec.roof_type == &"gable"
		else VERGE_PENDANT_D * 0.5)
	return Vector2(ROOF_SPAN_OUT + across, along)


## verge_overhang mapped onto the WORLD axes. The roof turns to follow the
## longer footprint dimension, so the span overhang lands on the shorter axis.
static func roof_overhang(spec: HouseSpec) -> Vector2:
	var v := verge_overhang(spec)
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
	var out_p: Vector2 = door["pos"] + normal * (depth + 0.1)
	var in_p: Vector2 = door["pos"] - normal * (0.1 + wall_thickness(spec))
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
	var over := roof_overhang(spec)
	# The roof grows from the real top-storey envelope; ground attachments
	# are merged separately, never added twice to the upper-storey overhang.
	var neg := over
	var pos := over
	if has_quoins(spec):
		neg = neg.max(Vector2.ONE * QUOIN_OUT)
		pos = pos.max(Vector2.ONE * QUOIN_OUT)
	var r: Rect2 = site_rect(spec, maxi(spec.storeys - 1, 0)).grow_individual(neg.x, neg.y, pos.x, pos.y)
	r = r.merge(site_rect(spec).grow_individual(0, jetty_front_reach(spec), 0, 0))
	for extra in [chimney_rect(plan), porch_rect(plan)]:
		if extra.size.x > 0.0:
			r = r.merge(extra)
	# The yard's BUILT pieces are emitted in the shell mesh, so the bound that
	# promises to contain every emitted vertex contains them. The yard's props
	# are separate models (BigGlade.placement merges them), and the APRON itself
	# is permission, not content: it is exposed as `yard_rect`, never added here.
	if spec.exterior_props:
		for piece in plan.yard_pieces:
			r = r.merge(piece["rect"])
	var top: float = total_height(spec)
	return AABB(Vector3(r.position.x, 0.0, r.position.y),
		Vector3(r.size.x, top, r.size.y))


## The YARD ENVELOPE: the shell footprint with its porch and chimney stack,
## grown by the apron (2 to 3 m, by style). Everything the house plans outside
## its walls stays inside this; the lot owns the rest. A declared permission, not
## a measured extent -- so it is not part of exterior_bounds().
static func yard_rect(plan: HousePlan) -> Rect2:
	var r := site_rect(plan.spec)
	for extra in [chimney_rect(plan), porch_rect(plan)]:
		if extra.size.x > 0.0:
			r = r.merge(extra)
	return r.grow(HouseYard.apron(plan.spec))


## CONSERVATIVE spec-only bounds, for callers with no plan. The hearth and the
## entrance may be on any wall, so every wall is grown by what either could
## add. A superset of exterior_bounds(), never a subset -- and never presented
## as exact.
static func spec_bounds(spec: HouseSpec) -> AABB:
	var over := roof_overhang(spec)
	if has_quoins(spec):
		over = over.max(Vector2.ONE * QUOIN_OUT)
	# The front is known, but a spec alone cannot say which wall is the front
	# once the entrance moves, so the jetty reach is applied all round.
	var all_round: float = maxf(maxf(over.x, over.y), jetty_front_reach(spec))
	var r: Rect2 = site_rect(spec, maxi(spec.storeys - 1, 0)).grow(all_round)
	var pad := 0.0
	if spec.chimney:
		pad = maxf(pad, chimney_size(spec) + maxf(CHIMNEY_BASE_EXTRA, 0.22))
	if spec.porch:
		pad = maxf(pad, porch_depth(spec) + 0.2 + wall_thickness(spec))
	# The yard's built pieces are in the mesh and lie inside the envelope: the
	# apron beyond the shell, its porch and chimney stack.
	if spec.exterior_props and not spec.has_method("room_program"):
		pad += HouseYard.apron(spec)
	r = r.grow(pad)
	var top: float = total_height(spec)
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
	return 1.35


static func chimney_size(spec: HouseSpec) -> float:
	return 1.05
