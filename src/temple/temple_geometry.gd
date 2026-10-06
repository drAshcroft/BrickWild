class_name TempleGeometry
extends RefCounted
## Single source of truth for a temple's massing.
##
## Same contract as the other three: pure functions of an explicit spec, so the
## builder that emits the mesh and the checks that judge the rite read the same
## numbers. Model axes: +X right, +Y up, +Z deep. The way in is at -Z and the
## god is at +Z, and the line x = 0 between them is THE AXIS -- almost every
## rule in qa/temple_rite_check.gd is a statement about it.
##
## The four forms are variations on one skeleton:
##
##   way in ─▶ approach ─▶ the great hall ─▶ dais ─▶ altar ─▶ idol
##
## What changes between them is the envelope (a hall, a walled court, a stepped
## mountain, a drum), where the columns stand (two rows, a grid, a ring) and
## what is overhead. What does not change is the axis, and that is deliberate:
## a temple whose god is off to one side is not a temple, it is a warehouse.

# ---- shell ----
const WALL_MIN := 0.8
const WALL_MAX := 2.4
const FLOOR_T := 0.3
const GATE_W := 3.2           # the doorway on the axis
const GATE_H := 5.5

# ---- the rite ----
const AISLE_MIN := 1.8        # a procession is not a corridor
const PROCESSION_MIN := 2.4   # clear width the whole way from door to altar
const ALTAR_CLEAR := 1.2      # floor kept clear round the altar for the rite
const DAIS_TREAD := 0.55      # depth of one step of the dais
const DAIS_RISE := 0.22
const IDOL_GAP := 1.4         # between the back of the altar and the idol
const PIT_RIM := 0.45         # the raised lip round a pit
const BRIDGE_MIN := 1.6
const CELL_DEPTH := 2.6
const CELL_W := 2.2
const LIGHT_REACH := 7.0      # how far one brazier lights the way

# ---- ornament ----
const OBELISK_H := 0.55       # x temple height
const SPIRE_BASE := 0.28      # x hall width
const COLUMN_CAP := 0.45      # the capital, x column radius
## A basilica's ridge rise, x its span. It was 0.32 -- a barn's pitch, and the
## first thing a walker said of the building was "looks like a barn". A
## temple front is a low pediment; Roman basilicas ran near 20 degrees.
const RIDGE_PITCH := 0.18
## The classical order a basilica dresses its walls in (`TempleBuilder.
## _build_order`): a stepped podium, pilasters on the bay rhythm, clerestory
## lights between them, an entablature at the eaves, raking cornices that make
## each gable a pediment, and an aedicule round the gate. Nothing in it stands
## further out from a wall than ORDER_REACH -- inside the roof's own overhang
## -- so a lot planned to the footprint still holds the building.
const ORDER_REACH := 0.6
const PODIUM_STEPS := 3
const PODIUM_RISE := 0.22
const ORDER_BAY := 4.6        # target pilaster spacing, metres

## Person radius for the walking checks: a robed celebrant, not a burglar.
const PERSON_RADIUS := 0.28
const NAV_CELL := 0.16


# ------------------------------------------------------------------ shell

static func site_rect(spec: TempleSpec) -> Rect2:
	return Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))


## Everything inside the outer walls: the ground the rite happens on.
##
## A ziggurat has no walls of its own -- its lowest terrace IS the wall, and
## the chamber is hollowed out of it -- so its interior is set in by a terrace
## rather than by a wall thickness.
static func interior_rect(spec: TempleSpec) -> Rect2:
	if spec.form == &"ziggurat":
		return site_rect(spec).grow(-terrace_inset(spec))
	return site_rect(spec).grow(-spec.wall_t)


## Where a person coming in stands, on the axis, one stride inside the gate.
static func entry_point(spec: TempleSpec) -> Vector2:
	return Vector2(0.0, interior_rect(spec).position.y + 0.9)


## Where you stand to look at the god.
##
## For three of the forms that is the doorway. For a ziggurat it is the foot of
## the great stair, out in the open: the whole point of a mountain is that the
## god is on top of it and you see him from outside, and asking whether he is
## visible from inside the chamber at its base is asking the wrong question.
static func sight_point(spec: TempleSpec) -> Vector2:
	if spec.form == &"ziggurat":
		return Vector2(0.0, stair_rect(spec).position.y - 1.0)
	return entry_point(spec)


## The open court a pylon temple puts between its gate and its hall. Empty for
## every other form.
static func court_depth(spec: TempleSpec) -> float:
	if spec.form != &"pylon":
		return 0.0
	return interior_rect(spec).size.y * 0.3


## The great hall: the roofed room the congregation stands in. For a pylon
## temple it starts beyond the court; for a rotunda it is the drum.
static func hall_rect(spec: TempleSpec) -> Rect2:
	var r: Rect2 = interior_rect(spec)
	var court: float = court_depth(spec)
	return Rect2(Vector2(r.position.x, r.position.y + court),
		Vector2(r.size.x, r.size.y - court))


## The sanctum: the far end, where the dais, the altar and the idol are. It is
## part of the hall, not a separate room -- what makes it the sanctum is that
## it is raised and that everything points at it.
## Deep enough to hold what has to stand in it: the dais with the altar on it,
## the gap a person needs between the altar and the god, and the god.
##
## Sizing the sanctum by proportion alone is what drove the idol back through
## the wall of every large temple -- there was simply nowhere else for it to
## go, and the geometry obliged.
static func sanctum_depth(spec: TempleSpec) -> float:
	var needs: float = spec.altar_l + ALTAR_CLEAR * 2.0 + IDOL_GAP \
		+ spec.idol_width + 1.2
	var hall: Rect2 = hall_rect(spec)
	return clampf(maxf(hall.size.y * 0.28, needs), 4.0, hall.size.y * 0.6)


static func sanctum_rect(spec: TempleSpec) -> Rect2:
	var h: Rect2 = hall_rect(spec)
	var d: float = sanctum_depth(spec)
	if spec.form == &"ziggurat":
		# The summit god and the chamber altar share one axis. Anchor the
		# chamber's dais below that real summit, not at the base's rear wall.
		var summit := terrace_rect(spec, maxi(spec.terraces - 1, 0))
		var end := summit.end.y - 0.5
		d = minf(d, end - h.position.y)
		return Rect2(Vector2(h.position.x, end - d), Vector2(h.size.x, d))
	return Rect2(Vector2(h.position.x, h.end.y - d), Vector2(h.size.x, d))


# ------------------------------------------------------------------- dais

## The platform the altar stands on, stepped up from the hall floor.
static func dais_rect(spec: TempleSpec) -> Rect2:
	var s: Rect2 = sanctum_rect(spec)
	var w: float = clampf(s.size.x * 0.55, spec.altar_w + ALTAR_CLEAR * 2.0, s.size.x - 1.0)
	var d: float = clampf(s.size.y * 0.6, spec.altar_l + ALTAR_CLEAR * 2.0, s.size.y - 0.6)
	return Rect2(Vector2(-w / 2.0, s.end.y - d), Vector2(w, d))


## Is the sanctum deep enough for the altar to stand its distance from the god?
## The generator asks this and grows the room until the answer is yes.
static func sanctum_fits(spec: TempleSpec) -> bool:
	var a: Vector3 = altar_center(spec)
	var d: Rect2 = dais_rect(spec)
	return a.z - spec.altar_l / 2.0 >= d.position.y - 0.05


static func dais_top(spec: TempleSpec) -> float:
	return spec.dais_height


## The ground the dais actually covers, steps included.
##
## dais_rect() is its TOP; each step below that grows it by a tread on the
## three sides you can climb from, so the thing on the floor is half a metre
## bigger all round than the platform on top of it. Reading the top rect where
## the footprint was meant is what put a column through the bottom step.
static func dais_footprint(spec: TempleSpec) -> Rect2:
	var d: Rect2 = dais_rect(spec)
	var grow: float = float(maxi(spec.dais_steps, 1) - 1) * DAIS_TREAD
	return Rect2(d.position - Vector2(grow, grow),
		d.size + Vector2(grow * 2.0, grow))


# ------------------------------------------------------------------ altar

## The altar, on the axis, at the front of the dais so the congregation can see
## what happens on it.
## The altar, on the axis, at the front of the dais so the congregation can see
## what happens on it -- and never closer to the god than a person can stand.
static func altar_center(spec: TempleSpec) -> Vector3:
	var d: Rect2 = dais_rect(spec)
	var z: float = d.position.y + spec.altar_l / 2.0 + ALTAR_CLEAR * 0.8
	var idol: Vector3 = idol_center(spec)
	var limit: float = idol.z - spec.idol_width / 2.0 - IDOL_GAP - spec.altar_l / 2.0
	return Vector3(0.0, dais_top(spec), minf(z, limit))


static func altar_rect(spec: TempleSpec) -> Rect2:
	var c: Vector3 = altar_center(spec)
	return Rect2(Vector2(c.x - spec.altar_w / 2.0, c.z - spec.altar_l / 2.0),
		Vector2(spec.altar_w, spec.altar_l))


## The floor the celebrant and the acolytes need round the altar.
static func altar_approach(spec: TempleSpec) -> Rect2:
	return altar_rect(spec).grow(ALTAR_CLEAR)


# ------------------------------------------------------------------- idol

## The idol stands behind the altar, on the axis, against the far wall. It is
## the thing you see from the door, and it is meant to be the biggest thing in
## the building.
static func idol_center(spec: TempleSpec) -> Vector3:
	var s: Rect2 = sanctum_rect(spec)
	# against the back wall, and never through it
	var z: float = s.end.y - spec.idol_width / 2.0 - 0.5
	if spec.form == &"ziggurat":
		# The coil/plinth is wider than the nominal idol rectangle. Its full
		# base remains on the highest terrace, with a half-metre rear margin.
		z = s.end.y - spec.idol_width * 0.7
	return Vector3(0.0, _idol_base_height(spec), z)


static func idol_rect(spec: TempleSpec) -> Rect2:
	var c: Vector3 = idol_center(spec)
	var w: float = spec.idol_width
	return Rect2(Vector2(c.x - w / 2.0, c.z - w / 2.0), Vector2(w, w))


## A ziggurat's god stands on the summit; everyone else's stands on the dais.
static func _idol_base_height(spec: TempleSpec) -> float:
	if spec.form == &"ziggurat":
		return terrace_top(spec)
	return dais_top(spec)


static func idol_apex(spec: TempleSpec) -> float:
	return _idol_base_height(spec) + spec.idol_height


# -------------------------------------------------------------------- pit

## The hole. A rotunda is built round one; the other forms cut theirs into the
## floor in front of the dais, so the procession has to cross it.
static func pit_rect(spec: TempleSpec) -> Rect2:
	if not spec.pit:
		return Rect2()
	var r: float = spec.pit_radius
	if spec.form == &"rotunda":
		return Rect2(Vector2(-r, -r), Vector2(r * 2.0, r * 2.0))
	var d: Rect2 = dais_rect(spec)
	var z: float = d.position.y - r - 1.2
	return Rect2(Vector2(-r, z - r), Vector2(r * 2.0, r * 2.0))


## The way across it, on the axis. Without this the pit is not a feature of the
## rite, it is a wall with a hole in it.
static func bridge_rect(spec: TempleSpec) -> Rect2:
	var p: Rect2 = pit_rect(spec)
	if p.size.x <= 0.0:
		return Rect2()
	var w: float = spec.bridge_width
	return Rect2(Vector2(-w / 2.0, p.position.y - PIT_RIM),
		Vector2(w, p.size.y + PIT_RIM * 2.0))


# ---------------------------------------------------------------- columns

## Where the columns stand, and how thick. The arrangement is the form's
## signature: two rows down a basilica, a grid in a hypostyle hall, a ring in a
## rotunda -- and in every one of them the axis itself is left clear, because a
## column in the middle of the processional way is a column in front of the god.
## The generated positions are retained as a compatibility helper for callers
## that only need points. Once TempleGenerator has authored `spec.columns`,
## this returns those plan records rather than deriving a second arrangement.
static func column_positions(spec: TempleSpec) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not spec.columns.is_empty():
		for column in spec.columns:
			out.append(column["pos"])
		return out
	return _generated_column_positions(spec)


static func column_records(spec: TempleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var positions := _generated_column_positions(spec)
	var radius := spec.column_r
	var height := column_height(spec)
	for i in range(positions.size()):
		var c: Vector3 = positions[i]
		var ring := 0
		if spec.form == &"rotunda":
			ring = i
		else:
			ring = int(floor((absf(c.x) - (axis_half_width(spec) + radius)) \
			/ maxf(spec.aisle_width + radius * 2.0, 0.01) + 0.5))
		out.append({"pos": c, "radius": radius, "height": height, "ring": ring})
	return out


static func _generated_column_positions(spec: TempleSpec) -> Array[Vector3]:
	var out: Array[Vector3] = []
	match spec.form:
		&"rotunda":
			var ring: float = ring_radius(spec)
			var n: int = ring_columns(spec)
			for i in range(n):
				var a: float = TAU * float(i) / float(n) + PI / float(n)
				out.append(Vector3(sin(a) * ring, 0.0, cos(a) * ring))
		_:
			var h: Rect2 = hall_rect(spec)
			var z0: float = h.position.y + 1.6
			var z1: float = sanctum_rect(spec).position.y - 1.0
			var bays: int = spec.column_bays
			if bays <= 0 or z1 - z0 < 2.0:
				return out
			# The first row stands clear of the processional way AND of the
			# hole in it: pushing the rows out is better than deleting the
			# ones that clash, which left a colonnade with gaps in it.
			var inner_x: float = axis_half_width(spec) + spec.column_r
			var pit: Rect2 = pit_rect(spec)
			if pit.size.x > 0.0:
				inner_x = maxf(inner_x, pit.size.x / 2.0 + PIT_RIM + spec.column_r + 0.4)
			for row in range(spec.column_rows):
				var x: float = inner_x \
					+ float(row) * (spec.aisle_width + spec.column_r * 2.0)
				if x + spec.column_r > h.size.x / 2.0 - 0.4:
					continue
				for i in range(bays):
					var t: float = float(i) / float(maxi(bays - 1, 1))
					var z: float = lerpf(z0, z1, t) if bays > 1 else (z0 + z1) / 2.0
					out.append(Vector3(-x, 0.0, z))
					out.append(Vector3(x, 0.0, z))
	return _clear_of_voids(spec, out)


## Drop any column that would stand over the pit, in the mouth of a cell, or in
## the processional way.
##
## The first two are holes in what the column would otherwise stand on -- one
## in the floor, one in the wall. The third is the whole point of the building:
## a ring of columns round a rotunda closes across the axis unless somebody
## says not to, and then the god is behind a pillar.
static func _clear_of_voids(spec: TempleSpec, cols: Array[Vector3]) -> Array[Vector3]:
	var pit: Rect2 = pit_rect(spec)
	var cells: Array[Rect2] = cell_rects(spec)
	var lane: Rect2 = processional_lane(spec)
	var holy: Array[Rect2] = [dais_footprint(spec).grow(0.3),
		idol_rect(spec).grow(0.3), altar_rect(spec).grow(0.3)]
	var r: float = spec.column_r
	var kept: Array[Vector3] = []
	for c in cols:
		var foot := Rect2(Vector2(c.x - r, c.z - r), Vector2(r * 2.0, r * 2.0))
		var clash: bool = lane.intersects(foot)
		if not clash and pit.size.x > 0.0:
			clash = pit.grow(PIT_RIM).intersects(foot)
		if not clash:
			for cell in cells:
				if cell.grow(0.15).intersects(foot):
					clash = true
					break
		if not clash:
			for h in holy:
				if h.intersects(foot):
					clash = true
					break
		if not clash:
			kept.append(c)
	return _symmetrical(kept)


## Keep only the columns whose twin across the axis also survived.
##
## Every rule above is symmetrical, but they are applied to rectangles, and a
## column that clears a cell by a millimetre on one side may not on the other.
## One missing column out of forty is exactly the kind of thing nobody notices
## in a render and the symmetry rule notices immediately -- so rather than
## loosen that rule, the pair goes together.
static func _symmetrical(cols: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c in cols:
		if absf(c.x) < 0.01:
			out.append(c)
			continue
		var twinned := false
		for d in cols:
			if absf(d.x + c.x) < 0.05 and absf(d.z - c.z) < 0.05 \
					and absf(d.y - c.y) < 0.05:
				twinned = true
				break
		if twinned:
			out.append(c)
	return out


## The lane down the middle that nothing may stand in: from the gate to the
## back of the sanctum, as wide as a procession.
static func processional_lane(spec: TempleSpec) -> Rect2:
	var half: float = axis_half_width(spec)
	var z0: float = site_rect(spec).position.y
	var z1: float = interior_rect(spec).end.y
	return Rect2(Vector2(-half, z0), Vector2(half * 2.0, z1 - z0))


## Half the width of the processional way: the clear lane down the axis that
## nothing may stand in.
static func axis_half_width(spec: TempleSpec) -> float:
	return maxf(PROCESSION_MIN, spec.bridge_width) / 2.0 + 0.3


static func ring_radius(spec: TempleSpec) -> float:
	var h: Rect2 = hall_rect(spec)
	return minf(h.size.x, h.size.y) * 0.5 - spec.column_r - 1.4


static func ring_columns(spec: TempleSpec) -> int:
	var circumference: float = TAU * ring_radius(spec)
	return clampi(int(circumference / (spec.column_r * 6.0)), 8, 24)


static func column_height(spec: TempleSpec) -> float:
	if spec.form == &"ziggurat":
		# Only the lowest terrace is occupied. Its supporting capitals meet
		# the stone ceiling, not the summit of the whole stepped mountain.
		return terrace_height(spec) - COLUMN_CAP * spec.column_r
	return spec.height - COLUMN_CAP * spec.column_r - 0.2


# ------------------------------------------------------------------ cells

## The holding cells: alcoves off the side walls, where whatever the rite needs
## is kept until it is needed. Never on the axis -- they are the part of the
## building the congregation is not meant to look at.
static func cell_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if spec.cells <= 0 or spec.form == &"rotunda":
		return out
	var h: Rect2 = hall_rect(spec)
	var z0: float = h.position.y + 1.5
	var z1: float = sanctum_rect(spec).position.y - CELL_W - 1.0
	if z1 <= z0:
		return out
	var per_side: int = maxi(spec.cells / 2, 1)
	for i in range(per_side):
		var t: float = (float(i) + 0.5) / float(per_side)
		var z: float = lerpf(z0, z1, t)
		for side in [-1.0, 1.0]:
			var x: float = (h.end.x if side > 0.0 else h.position.x) - side * CELL_DEPTH
			out.append(Rect2(Vector2(minf(x, x + side * CELL_DEPTH), z - CELL_W / 2.0),
				Vector2(CELL_DEPTH, CELL_W)))
	return out


# ------------------------------------------------------------- ziggurat

## The stepped terraces of a ziggurat, outermost first.
static func terrace_rect(spec: TempleSpec, level: int) -> Rect2:
	var r: Rect2 = site_rect(spec)
	var inset: float = float(level) * terrace_inset(spec)
	return r.grow(-inset)


static func terrace_inset(spec: TempleSpec) -> float:
	return minf(spec.width, spec.length) * 0.5 / float(maxi(spec.terraces, 1) + 1)


static func terrace_height(spec: TempleSpec) -> float:
	return spec.height / float(maxi(spec.terraces, 1)) * 0.85


static func terrace_top(spec: TempleSpec) -> float:
	if spec.form != &"ziggurat":
		return dais_top(spec)
	return terrace_height(spec) * float(spec.terraces)


## The great stairs up the front of a ziggurat: TWO flights, one either side of
## the doorway, climbing the outside of the mountain to the summit shrine.
##
## One flight on the axis is the obvious arrangement and it is wrong twice
## over: it buries the doorway to the chamber underneath itself, and it stands
## in the line between the ground and the god. A pair flanking the door leaves
## both clear -- which is how Ur was built, and for the same reason.
static func stair_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if spec.form != &"ziggurat":
		return out
	var r: Rect2 = site_rect(spec)
	var w: float = clampf(spec.width * 0.18, 2.0, 6.0)
	var run: float = terrace_top(spec) * 1.25 + 1.0
	# Keep the existing physical toe while centring each tread correctly.
	# The uphill end overlaps the summit by half a metre: ending at the base's
	# front wall left a high, disconnected flight several metres from it.
	var old_steps := maxi(int(terrace_top(spec) / 0.35), 4)
	var front := r.position.y - run - (run + 0.3) / (2.0 * old_steps)
	var back := terrace_rect(spec, maxi(spec.terraces - 1, 0)).position.y + 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * (GATE_W / 2.0 + 1.0 + w / 2.0)
		out.append(Rect2(Vector2(x - w / 2.0, front), Vector2(w, back - front)))
	return out


## The whole stair footprint, for sizing the paving in front of it.
static func stair_rect(spec: TempleSpec) -> Rect2:
	var rects: Array[Rect2] = stair_rects(spec)
	if rects.is_empty():
		return Rect2()
	var out: Rect2 = rects[0]
	for i in range(1, rects.size()):
		out = out.merge(rects[i])
	return out


## The paved approach in front of the gate. Somewhere for a procession to form
## up, and -- less romantically -- something for the obelisks to stand on: they
## were floating in the grass with nothing to touch until this existed.
static func forecourt_rect(spec: TempleSpec) -> Rect2:
	var r: Rect2 = site_rect(spec)
	var depth: float = 0.0
	if spec.obelisks:
		depth = maxf(depth, obelisk_height(spec) * 0.14 + 2.4)
	if spec.form == &"ziggurat":
		# Only the part in front of the base needs paving. Extending the
		# summit landing must not grow the building's outer placement bounds.
		depth = maxf(depth, terrace_top(spec) * 1.25 + 2.3)
	if depth <= 0.0:
		return Rect2()
	var w: float = minf(r.size.x, GATE_W + 8.0)
	return Rect2(Vector2(-w / 2.0, r.position.y - depth), Vector2(w, depth + 0.4))


static func obelisk_height(spec: TempleSpec) -> float:
	return spec.height * OBELISK_H * 2.0


## Where the obelisks stand: clear of the pylons behind them, on the paving.
static func obelisk_center(spec: TempleSpec, side: float) -> Vector2:
	var r: Rect2 = site_rect(spec)
	var oh: float = obelisk_height(spec)
	return Vector2(side * (GATE_W / 2.0 + 1.6),
		r.position.y - maxf(1.2, oh * 0.07 + 0.7))


# -------------------------------------------------------------- the floor

## The floor a person can actually walk on, as rectangles: the interior, with
## the pit taken out of it and the bridge put back over it, plus the cells.
##
## The builder emits these as slabs and the rite check walks them, so the hole
## in the floor is the same hole in both. Deriving it twice is how a bridge
## ends up somewhere the mesh has none.
static func floor_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var base: Rect2 = interior_rect(spec)
	var hole: Rect2 = pit_rect(spec)
	if hole.size.x <= 0.0:
		out.append(base)
	else:
		# four plates round the hole, any of which may come out empty
		out.append(Rect2(base.position, Vector2(base.size.x, hole.position.y - base.position.y)))
		out.append(Rect2(Vector2(base.position.x, hole.end.y),
			Vector2(base.size.x, base.end.y - hole.end.y)))
		out.append(Rect2(Vector2(base.position.x, hole.position.y),
			Vector2(hole.position.x - base.position.x, hole.size.y)))
		out.append(Rect2(Vector2(hole.end.x, hole.position.y),
			Vector2(base.end.x - hole.end.x, hole.size.y)))
		var b: Rect2 = bridge_rect(spec)
		if b.size.x > 0.0:
			out.append(b)
	for cell in cell_rects(spec):
		out.append(cell)
	var court: Rect2 = forecourt_rect(spec)
	if court.size.x > 0.0:
		out.append(court)
	var kept: Array[Rect2] = []
	for r in out:
		if r.size.x > 0.05 and r.size.y > 0.05:
			kept.append(r)
	return kept


## What stands on that floor and gets in the way: the columns, the altar, the
## idol. The dais is not here -- you walk up onto a dais, which is the whole
## point of one.
static func obstacle_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var columns: Array[Dictionary] = spec.columns if not spec.columns.is_empty() else column_records(spec)
	for column in columns:
		var c: Vector3 = column["pos"]
		var r: float = float(column["radius"])
		out.append(Rect2(Vector2(c.x - r, c.z - r), Vector2(r * 2.0, r * 2.0)))
	out.append(altar_rect(spec))
	out.append(idol_rect(spec))
	return out


# ---------------------------------------------------------------- envelope

## The dome and its surrounding deck share this exact polygonal rim.
const DOME_SEGMENTS := 20

static func dome_radius(spec: TempleSpec) -> float:
	return ring_radius(spec) + spec.column_r * 2.0


static func roof_height(spec: TempleSpec) -> float:
	match spec.form:
		&"ziggurat":
			return terrace_top(spec)
		&"rotunda":
			return spec.height + dome_radius(spec) * 0.55 + RoofShape.DEPTH * 0.5
		&"pylon":
			return spec.height + 0.5
	return spec.height + minf(spec.width, spec.length) * RIDGE_PITCH + RoofShape.DEPTH * 0.5


static func total_height(spec: TempleSpec) -> float:
	var top: float = roof_height(spec)
	if spec.spire:
		top = maxf(top, roof_height(spec) + spec.spire_height)
	top = maxf(top, idol_apex(spec))
	if spec.obelisks:
		top = maxf(top, spec.height * OBELISK_H * 2.0)
	return top


## The pylon towers either side of the gate: the wall a pylon temple shows the
## world.
static func pylon_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if spec.form != &"pylon":
		return out
	var r: Rect2 = site_rect(spec)
	var d: float = spec.wall_t * 2.6
	var w: float = (r.size.x - GATE_W) / 2.0
	for side in [-1.0, 1.0]:
		var x: float = r.position.x if side < 0.0 else GATE_W / 2.0
		out.append(Rect2(Vector2(x, r.position.y), Vector2(w, d)))
	return out


## Everything the temple covers in plan, its outworks included.
static func plan_extent(spec: TempleSpec) -> Rect2:
	var e: Rect2 = site_rect(spec)
	if spec.form == &"ziggurat":
		e = e.merge(stair_rect(spec))
	if spec.obelisks:
		e = e.grow(1.5)
	return e
