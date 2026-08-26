class_name CastleGeometry
extends RefCounted
## Single source of truth for a fortification's massing: where every structural
## volume sits, and the shared constants that decide it.
##
## Same contract as ChurchGeometry -- pure functions of an explicit spec, so the
## builder that emits the mesh and the checks that measure it can never derive
## different answers. Model axes:
##   +X = east, +Y = up, +Z = north (the back). The gate is always at -Z.
##
## The site rectangle (spec.width x spec.length) is the OUTER face of the outer
## enceinte AT WALL-TOP level. Two things deliberately reach beyond it:
##   * the batter (talus) at the wall foot, which spreads outward as it descends
##   * mural towers, which project outward from the wall they stud
## Both are what a castle looks like from outside, so plan_extent() reports them
## rather than the builder quietly clipping them.

# ---- joints, in metres ----
const RANGE_LAP := 0.4       # interior range lapping the wall it stands against
const WING_LAP := 0.4        # manor wing lapping the range it meets
const GATE_LAP := 0.3        # barbican lapping the gatehouse

# ---- proportions ----
const INNER_HEIGHT_RATIO := 1.3   # inner curtain height, x outer curtain height
const INNER_THICK_RATIO := 0.85   # inner curtain thickness, x outer thickness
const TOWER_CAP_RATIO := 0.9      # cone/pyramid rise, x tower diameter
const TOWER_BATTER_CAP := 0.35    # most a tower's foot may spread, x its half-size
const TENSHU_PLINTH := 0.42       # stone base of a tiered keep, x its height
const TENSHU_TIERS := 5           # storeys the timber tower steps down through
const MERLON_W := 0.65            # merlon width along the parapet
const MERLON_GAP := 0.55          # crenel (the gap) width
const PARAPET_RISE := 0.25        # wall-walk coping under the merlons
const GATE_DEPTH_MIN := 3.0
const MIN_WALL_RUN := 1.5         # shorter than this and a wall run is dropped
const BAILEY_CLEAR := 1.5         # air kept between interior ranges
const OPENING_EPS := 0.02         # surface offset so openings do not z-fight

# ---- tiers ----
const HOUSE_ANNEXE_W := 0.5       # annexe width, x house width
const HOUSE_ANNEXE_L := 0.35      # annexe length, x house length
const MANOR_RANGE_DEPTH := 0.32   # main range depth along Z, x site length
const MANOR_WING_W := 0.25        # cross wing width, x site width
const CHIMNEY_W := 1.1
const CHIMNEY_RISE := 1.6         # stack standing proud of the ridge
const PORCH_DEPTH := 1.6


# ------------------------------------------------------------------- tiers

static func is_enclosed(spec: CastleSpec) -> bool:
	return spec.tier == &"castle" or spec.tier == &"fortress"


## Index of the innermost enceinte: 1 when there is an inner ward, else 0.
static func inner_ring(spec: CastleSpec) -> int:
	return 1 if spec.inner_ward else 0


## Every enceinte ring the design has, outermost first.
static func rings(spec: CastleSpec) -> Array[int]:
	var out: Array[int] = []
	if not is_enclosed(spec):
		return out
	out.append(0)
	if spec.inner_ward:
		out.append(1)
	return out


# ------------------------------------------------------------------- walls

## Plan rectangle of ring `r`, at wall-top level: position = (x0, z0).
static func enceinte_rect(spec: CastleSpec, r: int) -> Rect2:
	var site := Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))
	if r <= 0:
		return site
	return site.grow(-spec.ward_gap)


static func wall_height(spec: CastleSpec, r: int) -> float:
	return spec.height * (INNER_HEIGHT_RATIO if r > 0 else 1.0)


static func wall_thickness(spec: CastleSpec, r: int) -> float:
	return spec.wall_thickness * (INNER_THICK_RATIO if r > 0 else 1.0)


## How far the talus spreads outward at the foot of a mass `h` tall.
static func batter_spread(spec: CastleSpec, h: float) -> float:
	return h * spec.batter


## Thickness of a wall at its foot, batter included. The inner face is vertical
## at every height, so nothing inside the bailey has to know about the talus.
static func wall_base_thickness(spec: CastleSpec, r: int) -> float:
	return wall_thickness(spec, r) + batter_spread(spec, wall_height(spec, r))


## The gap the gatehouse occupies in the front wall of ring `r`.
static func gate_width(spec: CastleSpec, r: int) -> float:
	if not spec.gatehouse:
		return 0.0
	var gw: float = spec.gate_width
	if r > 0:
		gw *= 0.8
	return minf(gw, max_gate_width(spec, r))


## Widest gate this ring can carry and still leave a run of wall either side of
## it, clear of the corner towers.
static func max_gate_width(spec: CastleSpec, r: int) -> float:
	var rect: Rect2 = enceinte_rect(spec, r)
	var corner: float = 2.0 * tower_base_half(spec, r) + MIN_WALL_RUN
	return maxf(rect.size.x - 2.0 * corner, 2.0)


static func gate_depth(spec: CastleSpec, r: int) -> float:
	return maxf(spec.gate_depth, wall_thickness(spec, r) + GATE_DEPTH_MIN)


## A wall run as its BASE footprint -- the widest it ever is.
##   which: &"front_left", &"front_right", &"front", &"back", &"left", &"right"
## Front and back run the full width; the sides run between them, so abutting
## runs touch at their faces instead of interpenetrating at the corners.
static func wall_aabb(spec: CastleSpec, r: int, which: StringName) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var tb: float = wall_base_thickness(spec, r)
	var h: float = wall_height(spec, r)
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var z0: float = rect.position.y
	var z1: float = rect.end.y
	var gw: float = gate_width(spec, r)
	match which:
		&"front":
			return AABB(Vector3(x0, 0.0, z0 + t - tb), Vector3(rect.size.x, h, tb))
		&"front_left":
			return AABB(Vector3(x0, 0.0, z0 + t - tb),
				Vector3((x1 - x0 - gw) / 2.0, h, tb))
		&"front_right":
			return AABB(Vector3(x0 + (x1 - x0 + gw) / 2.0, 0.0, z0 + t - tb),
				Vector3((x1 - x0 - gw) / 2.0, h, tb))
		&"back":
			return AABB(Vector3(x0, 0.0, z1 - t), Vector3(rect.size.x, h, tb))
		&"left":
			return AABB(Vector3(x0 + t - tb, 0.0, z0 + t),
				Vector3(tb, h, rect.size.y - 2.0 * t))
		&"right":
			return AABB(Vector3(x1 - t, 0.0, z0 + t),
				Vector3(tb, h, rect.size.y - 2.0 * t))
	return AABB()


## Which wall runs ring `r` actually has: the front is split in two by a gate.
static func wall_names(spec: CastleSpec, r: int) -> Array[StringName]:
	var out: Array[StringName] = [&"back", &"left", &"right"]
	if gate_width(spec, r) > 0.0:
		out.append(&"front_left")
		out.append(&"front_right")
	else:
		out.append(&"front")
	return out


# ------------------------------------------------------------------ towers

## Half-plan-size of a tower at its top: the radius of a drum, half the side of
## a square one.
static func tower_half(spec: CastleSpec, r: int) -> float:
	return spec.tower_size * (0.85 if r > 0 else 1.0)


static func tower_height(spec: CastleSpec, r: int) -> float:
	return spec.tower_height * (INNER_HEIGHT_RATIO if r > 0 else 1.0)


## Half-plan-size at the foot. The tower's inner face is pinned to the wall's
## inner face at the BASE, so the talus spreads outward into the open air and
## never intrudes on the bailey behind it.
##
## The spread is capped at a third of the tower: a wall is short and long, so
## the same batter that gives it a convincing talus turned a tall tower into a
## cooling tower, splayed twice as wide at the foot as at the parapet.
static func tower_base_half(spec: CastleSpec, r: int) -> float:
	var half: float = tower_half(spec, r)
	return half + minf(batter_spread(spec, tower_height(spec, r)), half * TOWER_BATTER_CAP)


## Number of sides the tower shell is revolved with. A square tower is a
## 4-segment revolve and a polygonal one an 8; keeping all three shapes on one
## primitive is why they cannot drift apart.
static func tower_sides(spec: CastleSpec) -> int:
	match spec.tower_shape:
		&"square":
			return 4
		&"polygonal":
			return 8
	return 12


## Rotation that puts a flat face outward rather than a corner.
static func tower_rotation(spec: CastleSpec) -> float:
	return PI / float(tower_sides(spec))


## Circumradius for a tower whose half-plan-size (apothem) is `half`.
static func tower_radius_for(spec: CastleSpec, half: float) -> float:
	return half / cos(PI / float(tower_sides(spec)))


## Corner towers of ring `r`, base centres, in the order SW, SE, NW, NE.
static func corner_tower_centers(spec: CastleSpec, r: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not spec.corner_towers:
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = (rect.end.x - t + s) if sx > 0.0 else (rect.position.x + t - s)
			var z: float = (rect.end.y - t + s) if sz > 0.0 else (rect.position.y + t - s)
			out.append(Vector3(x, 0.0, z))
	return out


## Mural towers studding the long walls between the corners, as
## {"pos": Vector3, "facing": Vector3}. Only the +/-X walls carry them: the back
## wall is where the keep stands and the front wall is where the gate is.
static func side_tower_slots(spec: CastleSpec, r: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if spec.side_towers <= 0:
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	# keep clear of the corner towers at both ends of the run
	var margin: float = 2.0 * s + MIN_WALL_RUN
	var z0: float = rect.position.y + margin
	var z1: float = rect.end.y - margin
	if z1 - z0 < 2.0 * s:
		return out
	# Only as many as the run can actually carry. Spacing the requested count
	# evenly regardless is how six towers ended up sharing four towers' worth of
	# wall, each one buried in its neighbour.
	var pitch: float = 2.0 * s + MIN_WALL_RUN
	var n: int = mini(spec.side_towers, int((z1 - z0) / pitch) + 1)
	if n <= 0:
		return out
	for i in range(n):
		var f: float = 0.5 if n == 1 else float(i) / float(n - 1)
		var z: float = lerpf(z0, z1, f)
		for sx in [-1.0, 1.0]:
			var x: float = (rect.end.x - t + s) if sx > 0.0 else (rect.position.x + t - s)
			out.append({"pos": Vector3(x, 0.0, z), "facing": Vector3(sx, 0.0, 0.0)})
	return out


## Clear ground a second enceinte needs between it and the first: enough that
## the inner ring's towers, which project outward from their own wall, stop
## short of the outer ring's.
static func min_ward_gap(spec: CastleSpec) -> float:
	return 2.0 * tower_base_half(spec, 1) + wall_thickness(spec, 1) \
		- wall_thickness(spec, 0) + MIN_WALL_RUN


## Base footprint of a tower centred at `c`.
static func tower_aabb(spec: CastleSpec, r: int, c: Vector3) -> AABB:
	var s: float = tower_base_half(spec, r)
	return AABB(Vector3(c.x - s, 0.0, c.z - s),
		Vector3(s * 2.0, tower_height(spec, r), s * 2.0))


## Rise of whatever caps a tower, above its parapet.
static func tower_roof_rise(spec: CastleSpec, r: int) -> float:
	var d: float = tower_half(spec, r) * 2.0
	match spec.tower_roof:
		&"cone":
			return d * TOWER_CAP_RATIO * 1.4
		&"pyramid":
			return d * TOWER_CAP_RATIO * 0.8
		&"tiered":
			return d * TOWER_CAP_RATIO
	return PARAPET_RISE


# -------------------------------------------------------------------- gate

## The gatehouse block of ring `r`: it fills the gap in the front wall and
## reaches back into the ward, so the passage runs through solid building.
static func gatehouse_aabb(spec: CastleSpec, r: int) -> AABB:
	var gw: float = gate_width(spec, r)
	if gw <= 0.0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, r)
	var d: float = gate_depth(spec, r)
	return AABB(Vector3(-gw / 2.0, 0.0, rect.position.y),
		Vector3(gw, gate_height(spec, r), d))


static func gate_height(spec: CastleSpec, r: int) -> float:
	return wall_height(spec, r) * 1.25


## The twin drums flanking the passage, base centres.
static func gate_tower_centers(spec: CastleSpec, r: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not spec.gate_towers or gate_width(spec, r) <= 0.0:
		return out
	var rect: Rect2 = enceinte_rect(spec, r)
	var t: float = wall_thickness(spec, r)
	var s: float = tower_base_half(spec, r)
	var gw: float = gate_width(spec, r)
	for sx in [-1.0, 1.0]:
		out.append(Vector3(sx * (gw / 2.0 + s * 0.7), 0.0, rect.position.y + t - s))
	return out


## Outwork in front of the gate, lapping it so the two read as one defence.
static func barbican_aabb(spec: CastleSpec) -> AABB:
	if not spec.barbican or gate_width(spec, 0) <= 0.0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var gw: float = gate_width(spec, 0)
	var d: float = clampf(spec.length * 0.1, 4.0, 14.0)
	return AABB(Vector3(-gw * 0.42, 0.0, rect.position.y - d),
		Vector3(gw * 0.84, spec.height * 0.6, d + GATE_LAP))


## The walled causeway between the outer and inner gatehouses. Without it the
## inner ward would be a ring of masonry standing free inside another one --
## which is exactly what the no-gaps check is for.
static func gate_link_aabb(spec: CastleSpec, side: float) -> AABB:
	if not spec.inner_ward or gate_width(spec, 1) <= 0.0:
		return AABB()
	var z0: float = enceinte_rect(spec, 0).position.y + gate_depth(spec, 0)
	var z1: float = enceinte_rect(spec, 1).position.y
	if z1 - z0 < 0.5:
		return AABB()
	var gw: float = gate_width(spec, 1)
	# The two walls flank the passage, so each may be at most a third of it:
	# sized off the curtain alone they met in the middle and sealed the way in.
	var th: float = clampf(spec.wall_thickness * 0.7, 0.4, gw * 0.3)
	var x: float = side * (gw / 2.0 - th / 2.0)
	return AABB(Vector3(x - th / 2.0, 0.0, z0), Vector3(th, spec.height * 0.7, z1 - z0))


# ---------------------------------------------------------- ground inside

## The open ground inside the innermost enceinte: everything a bailey holds is
## placed relative to this. For an unenclosed tier it is the site itself.
static func bailey_rect(spec: CastleSpec) -> Rect2:
	if not is_enclosed(spec):
		return enceinte_rect(spec, 0)
	var r: int = inner_ring(spec)
	return enceinte_rect(spec, r).grow(-wall_thickness(spec, r))


# -------------------------------------------------------------------- keep

## The keep stands against the back wall of the bailey, lapping it.
static func keep_aabb(spec: CastleSpec) -> AABB:
	if not spec.keep:
		return AABB()
	var b: Rect2 = bailey_rect(spec)
	var z1: float = b.end.y + RANGE_LAP
	return AABB(Vector3(-spec.keep_w / 2.0, 0.0, z1 - spec.keep_l),
		Vector3(spec.keep_w, spec.keep_height, spec.keep_l))


## Largest keep footprint the bailey can hold and still leave a courtyard.
static func max_keep_size(spec: CastleSpec) -> Vector2:
	var b: Rect2 = bailey_rect(spec)
	return Vector2(maxf(b.size.x - 2.0 * BAILEY_CLEAR, 2.0),
		maxf(b.size.y * 0.45, 2.0))


## The great hall range: against the west wall, running back to meet the keep,
## so every interior building is tied into the assembly.
static func hall_aabb(spec: CastleSpec) -> AABB:
	if not spec.hall:
		return AABB()
	if not is_enclosed(spec):
		return house_range_aabb(spec)
	var b: Rect2 = bailey_rect(spec)
	var x0: float = b.position.x - RANGE_LAP
	var z1: float = interior_back_z(spec)
	return AABB(Vector3(x0, 0.0, z1 - spec.hall_l),
		Vector3(spec.hall_w, spec.hall_height, spec.hall_l))


## Mirror of the hall on the east side, half its length: the chapel range.
static func chapel_aabb(spec: CastleSpec) -> AABB:
	if not spec.chapel or not is_enclosed(spec):
		return AABB()
	var b: Rect2 = bailey_rect(spec)
	var l: float = maxf(spec.hall_l * 0.55, 3.0)
	var z1: float = interior_back_z(spec)
	return AABB(Vector3(b.end.x + RANGE_LAP - spec.hall_w, 0.0, z1 - l),
		Vector3(spec.hall_w, spec.hall_height * 0.85, l))


## The plane interior ranges start from: the keep's front face when there is a
## keep, otherwise the back of the bailey.
static func interior_back_z(spec: CastleSpec) -> float:
	var b: Rect2 = bailey_rect(spec)
	if spec.keep:
		return keep_aabb(spec).position.z
	return b.end.y + RANGE_LAP


## Longest interior range the bailey can hold in front of the keep.
static func max_range_length(spec: CastleSpec) -> float:
	var b: Rect2 = bailey_rect(spec)
	var back: float = interior_back_z(spec)
	return maxf(back - b.position.y - BAILEY_CLEAR, 2.0)


# ---------------------------------------------------------- house and manor

## The single block a house is, or the main range across the back of a manor.
static func house_range_aabb(spec: CastleSpec) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, 0)
	if spec.tier == &"house":
		return AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, spec.height, rect.size.y))
	var d: float = manor_range_depth(spec)
	return AABB(Vector3(rect.position.x, 0.0, rect.end.y - d),
		Vector3(rect.size.x, spec.height, d))


static func manor_range_depth(spec: CastleSpec) -> float:
	return clampf(spec.length * MANOR_RANGE_DEPTH, 5.0, spec.length * 0.5)


static func manor_wing_width(spec: CastleSpec) -> float:
	return clampf(spec.width * MANOR_WING_W, 4.0, spec.width * 0.35)


## A cross wing running forward from the main range down one side of the court.
static func manor_wing_aabb(spec: CastleSpec, side: float) -> AABB:
	var rect: Rect2 = enceinte_rect(spec, 0)
	var ww: float = manor_wing_width(spec)
	var z1: float = rect.end.y - manor_range_depth(spec) + WING_LAP
	var x: float = (rect.end.x - ww) if side > 0.0 else rect.position.x
	return AABB(Vector3(x, 0.0, rect.position.y),
		Vector3(ww, spec.height, z1 - rect.position.y))


## The lower front range that closes a courtyard manor's fourth side.
static func manor_front_range_aabb(spec: CastleSpec) -> AABB:
	if not spec.courtyard:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var ww: float = manor_wing_width(spec) if spec.wings > 0 else 0.0
	var d: float = clampf(spec.length * 0.16, 4.0, 12.0)
	return AABB(Vector3(rect.position.x + ww - WING_LAP, 0.0, rect.position.y),
		Vector3(rect.size.x - 2.0 * (ww - WING_LAP), spec.height * 0.75, d))


## Entrance block. A courtyard manor puts it through the front range; an open
## court puts a porch on the main range, facing the court.
static func porch_aabb(spec: CastleSpec) -> AABB:
	if is_enclosed(spec):
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var pw: float = clampf(spec.width * 0.18, 2.0, 6.0)
	if spec.tier == &"house":
		return AABB(Vector3(-pw / 2.0, 0.0, rect.position.y - PORCH_DEPTH),
			Vector3(pw, spec.height * 0.55, PORCH_DEPTH + WING_LAP))
	if spec.courtyard:
		var fr: AABB = manor_front_range_aabb(spec)
		return AABB(Vector3(-pw / 2.0, 0.0, fr.position.z - PORCH_DEPTH),
			Vector3(pw, spec.height * 0.9, PORCH_DEPTH + fr.size.z))
	var mr: AABB = house_range_aabb(spec)
	return AABB(Vector3(-pw / 2.0, 0.0, mr.position.z - PORCH_DEPTH),
		Vector3(pw, spec.height * 0.8, PORCH_DEPTH + WING_LAP))


## A service annexe off the front corner of a house. It sits at the front
## because the chimney stacks run up the back wall, and two masses fighting for
## the same corner is how a generator produces a house with a flue inside its
## pantry.
static func annexe_aabb(spec: CastleSpec) -> AABB:
	if spec.tier != &"house" or spec.wings <= 0:
		return AABB()
	var rect: Rect2 = enceinte_rect(spec, 0)
	var aw: float = rect.size.x * HOUSE_ANNEXE_W
	var al: float = rect.size.y * HOUSE_ANNEXE_L
	return AABB(Vector3(rect.end.x - WING_LAP, 0.0, rect.position.y),
		Vector3(aw, spec.height * 0.7, al))


## Which sides a manor's cross wings stand on: one wing takes the west side.
static func wing_sides(spec: CastleSpec) -> Array[float]:
	var out: Array[float] = []
	if spec.wings <= 0:
		return out
	out.append(-1.0)
	if spec.wings >= 2:
		out.append(1.0)
	return out


## Towers at the front ends of a manor's cross wings -- the "castle" half of a
## fortified manor house like Stokesay.
static func manor_tower_centers(spec: CastleSpec) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if is_enclosed(spec) or not spec.corner_towers or spec.wings <= 0:
		return out
	var s: float = tower_base_half(spec, 0)
	for side in wing_sides(spec):
		var wing: AABB = manor_wing_aabb(spec, side)
		out.append(Vector3(wing.position.x + wing.size.x / 2.0, 0.0,
			wing.position.z + s * 0.6))
	return out


## How many stacks the back wall can carry without them touching. A stack is
## CHIMNEY_W across and wants that much air either side of it.
static func max_chimneys(spec: CastleSpec) -> int:
	var host: AABB = house_range_aabb(spec)
	var usable: float = host.size.x - 2.0 * CHIMNEY_W
	return maxi(int(usable / (CHIMNEY_W * 2.0)), 1)


## External chimney stacks. They run from the ground up the outer face of the
## block they serve, which is both what a stone stack does and what keeps every
## mass standing on the ground.
static func chimney_aabb(spec: CastleSpec, i: int) -> AABB:
	var host: AABB = house_range_aabb(spec)
	var n: int = maxi(spec.chimneys, 1)
	var f: float = (float(i) + 1.0) / (float(n) + 1.0)
	var x: float = lerpf(host.position.x + CHIMNEY_W,
		host.position.x + host.size.x - CHIMNEY_W, f)
	var top: float = host.size.y + roof_rise(spec, host) + CHIMNEY_RISE
	return AABB(Vector3(x - CHIMNEY_W / 2.0, 0.0,
		host.position.z + host.size.z - WING_LAP), Vector3(CHIMNEY_W, top, CHIMNEY_W))


## Ridge rise of the roof over a block, measured over its SHORT axis: a roof
## spans the short way, which is what makes a long range read as a range.
static func roof_rise(spec: CastleSpec, a: AABB) -> float:
	return minf(a.size.x, a.size.z) * spec.roof_pitch * 0.5


## True when the block's ridge runs along X rather than Z.
static func ridge_along_x(a: AABB) -> bool:
	return a.size.x > a.size.z


# ----------------------------------------------------------------- envelope

## Tallest point of the whole design.
static func total_height(spec: CastleSpec) -> float:
	var top: float = spec.height
	if is_enclosed(spec):
		for r in rings(spec):
			top = maxf(top, wall_height(spec, r) + PARAPET_RISE + spec.merlon_h)
			top = maxf(top, tower_height(spec, r) + tower_roof_rise(spec, r))
			if gate_width(spec, r) > 0.0:
				top = maxf(top, gate_height(spec, r) + PARAPET_RISE + spec.merlon_h)
	if spec.keep:
		top = maxf(top, spec.keep_height + roof_rise(spec, keep_aabb(spec)))
	for a in [house_range_aabb(spec), hall_aabb(spec), chapel_aabb(spec)]:
		if a.size.y > 0.0:
			top = maxf(top, a.size.y + roof_rise(spec, a))
	if spec.chimneys > 0 and not is_enclosed(spec):
		top = maxf(top, chimney_aabb(spec, 0).size.y)
	if not manor_tower_centers(spec).is_empty():
		top = maxf(top, tower_height(spec, 0) + tower_roof_rise(spec, 0))
	return top


## Everything the design covers in plan, batter and towers included.
static func plan_extent(spec: CastleSpec) -> Rect2:
	var e: Rect2 = enceinte_rect(spec, 0)
	if is_enclosed(spec):
		e = e.grow(batter_spread(spec, wall_height(spec, 0)))
		var s: float = tower_base_half(spec, 0)
		var spots: Array[Vector3] = corner_tower_centers(spec, 0)
		spots.append_array(gate_tower_centers(spec, 0))
		for slot in side_tower_slots(spec, 0):
			spots.append(slot["pos"])
		for c in spots:
			e = e.expand(Vector2(c.x - s, c.z - s))
			e = e.expand(Vector2(c.x + s, c.z + s))
	var ms: float = tower_base_half(spec, 0)
	for c in manor_tower_centers(spec):
		e = e.expand(Vector2(c.x - ms, c.z - ms))
		e = e.expand(Vector2(c.x + ms, c.z + ms))
	for a in [barbican_aabb(spec), porch_aabb(spec), annexe_aabb(spec)]:
		if a.size.x <= 0.0:
			continue
		e = e.expand(Vector2(a.position.x, a.position.z))
		e = e.expand(Vector2(a.position.x + a.size.x, a.position.z + a.size.z))
	if spec.chimneys > 0 and not is_enclosed(spec):
		var ch: AABB = chimney_aabb(spec, 0)
		e = e.expand(Vector2(ch.position.x, ch.position.z + ch.size.z))
	return e
