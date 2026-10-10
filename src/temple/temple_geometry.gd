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
const ROTUNDA_FLOOR_BAND := 0.45
const ROTUNDA_WALL_PANEL_MAX_CHORD := 1.35
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
## Basilica plan and vertical hierarchy. The central nave carries the high
## ridge; the two aisles meet it at the raised side walls.
const BASILICA_NAVE_FRACTION := 0.62
const BASILICA_NAVE_RISE_FRACTION := 0.16
const BASILICA_PORTICO_WIDTH_FRACTION := 0.68
const BASILICA_PORTICO_DEPTH_FRACTION := 0.18
const BASILICA_PORTICO_MIN_DEPTH := 2.6
const BASILICA_PORTICO_MAX_DEPTH := 4.2
const BASILICA_PORTICO_APPROACH_APRON := 0.6
const BASILICA_PORTICO_ROOF_PITCH := 0.08
const BASILICA_PORTICO_MIN_COLUMNS := 4
const BASILICA_PORTICO_MAX_COLUMNS := 8

## Person radius for the walking checks: a robed celebrant, not a burglar.
const PERSON_RADIUS := 0.28
const NAV_CELL := 0.16
## The lowest ziggurat terrace is an occupied chamber. Its ceiling and the
## underside of its column entablature must both clear the human route.
const RITUAL_HEADROOM_MIN := 2.0


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
	if spec.form == &"rotunda":
		var inner_radius: float = rotunda_inner_radius(spec)
		return Rect2(Vector2(-inner_radius, -inner_radius),
			Vector2(inner_radius * 2.0, inner_radius * 2.0))
	return site_rect(spec).grow(-spec.wall_t)


## The Rotunda uses a true circular drum inscribed in its published plan bounds.
## Its wall depth is radial, so both interior and roof support share one datum.
static func rotunda_lower_drum_height(spec: TempleSpec) -> float:
	# Keep a broad continuous base and reserve the upper third for open bays.
	return spec.height * 0.69


static func rotunda_outer_radius(spec: TempleSpec) -> float:
	return minf(spec.width, spec.length) * 0.5


static func rotunda_inner_radius(spec: TempleSpec) -> float:
	return maxf(0.5, rotunda_outer_radius(spec) - spec.wall_t)


static func rotunda_wall_panel_count(spec: TempleSpec) -> int:
	var circumference: float = TAU * (rotunda_outer_radius(spec) - spec.wall_t * 0.5)
	var count: int = clampi(int(ceil(circumference / ROTUNDA_WALL_PANEL_MAX_CHORD)), 24, 96)
	return count if count % 2 == 0 else mini(count + 1, 96)


## Separating-axis test for two exact oriented component boxes.
## Returns the shallowest penetration in metres, or zero when disjoint.
static func obb_overlap_depth(a: Dictionary, b: Dictionary) -> float:
	var a_xf: Transform3D = a["xf"]
	var b_xf: Transform3D = b["xf"]
	var a_axes: Array[Vector3] = [a_xf.basis.x.normalized(), a_xf.basis.y.normalized(),
		a_xf.basis.z.normalized()]
	var b_axes: Array[Vector3] = [b_xf.basis.x.normalized(), b_xf.basis.y.normalized(),
		b_xf.basis.z.normalized()]
	var a_half: Vector3 = (a["size"] as Vector3) * 0.5
	var b_half: Vector3 = (b["size"] as Vector3) * 0.5
	var axes: Array[Vector3] = []
	axes.append_array(a_axes)
	axes.append_array(b_axes)
	for a_axis in a_axes:
		for b_axis in b_axes:
			axes.append(a_axis.cross(b_axis))
	var delta: Vector3 = b_xf.origin - a_xf.origin
	var shallowest := INF
	for candidate in axes:
		if candidate.length_squared() < 1e-10:
			continue
		var axis: Vector3 = candidate.normalized()
		var a_radius := 0.0
		var b_radius := 0.0
		for index in range(3):
			a_radius += a_half[index] * absf(a_axes[index].dot(axis))
			b_radius += b_half[index] * absf(b_axes[index].dot(axis))
		var overlap: float = a_radius + b_radius - absf(delta.dot(axis))
		if overlap <= 0.0:
			return 0.0
		shallowest = minf(shallowest, overlap)
	return 0.0 if is_inf(shallowest) else shallowest


## Omit tangent panels far enough from the portal that their actual inner-face
## corners clear both jambs. The wall thickness and panel chord matter here;
## an angle derived from gate width alone leaves a wedge over the clear opening.
static func rotunda_gate_panel_half_angle(spec: TempleSpec) -> float:
	var outer: float = rotunda_outer_radius(spec)
	var mid: float = outer - spec.wall_t * 0.5
	var inner: float = rotunda_inner_radius(spec)
	var step: float = TAU / float(rotunda_wall_panel_count(spec))
	var panel_half: float = mid * tan(step * 0.5) + 0.0125
	var required_x: float = GATE_W * 0.5 + 0.03
	var low := 0.0
	var high := PI * 0.49
	for _iteration in range(24):
		var angle: float = (low + high) * 0.5
		var inner_corner_x: float = inner * sin(angle) - panel_half * cos(angle)
		if inner_corner_x < required_x:
			low = angle
		else:
			high = angle
	return high


static func basilica_nave_half_width(spec: TempleSpec) -> float:
	if not basilica_has_nave_bearings(spec):
		# A single nave roof lands on the outer shell walls when the generated
		# sanctum has no interior bearing row. This span includes the real eaves.
		return spec.width * 0.5 + 0.6 - spec.wall_t * 0.5
	return basilica_nave_bearing_x(spec) + basilica_nave_wall_thickness(spec) * 0.5


static func basilica_has_nave_bearings(spec: TempleSpec) -> bool:
	if spec.columns.is_empty():
		return false
	var bearing_x := INF
	for column in spec.columns:
		var p: Vector3 = column["pos"]
		bearing_x = minf(bearing_x, absf(p.x))
	var negative_z: Array[float] = []
	var positive_z: Array[float] = []
	for column in spec.columns:
		var p: Vector3 = column["pos"]
		if absf(absf(p.x) - bearing_x) > 0.01:
			continue
		var stations: Array[float] = negative_z if p.x < 0.0 else positive_z
		var duplicate := false
		for z in stations:
			if absf(z - p.z) < 0.01:
				duplicate = true
				break
		if not duplicate:
			stations.append(p.z)
	return negative_z.size() >= 2 and positive_z.size() >= 2


## The nave walls sit over the innermost final generated colonnade. Do not
## derive a second bay layout: TempleGenerator's records are the bearings.
static func basilica_nave_bearing_x(spec: TempleSpec) -> float:
	var columns: Array[Dictionary] = spec.columns if not spec.columns.is_empty() \
		else column_records(spec)
	var nearest := INF
	for column in columns:
		var p: Vector3 = column["pos"]
		nearest = minf(nearest, absf(p.x))
	if nearest == INF:
		return minf(spec.width * BASILICA_NAVE_FRACTION * 0.5,
			spec.width * 0.5 - spec.wall_t)
	return nearest


static func basilica_nave_wall_thickness(spec: TempleSpec) -> float:
	return maxf(spec.column_r * 2.0, spec.wall_t * 0.7)


## Underside heights of the no-bearing fallback ridge at its actual shell-wall
## faces. This profile gives the emitted bearing head its true roof contact.
static func basilica_fallback_roof_wall_profile(spec: TempleSpec) -> Vector2:
	var span: float = minf(spec.width, spec.length)
	var roof_half: float = (span + 1.2) * 0.5
	var rise: float = span * RIDGE_PITCH
	var outer: float = span * 0.5
	var inner: float = maxf(0.0, outer - spec.wall_t)
	var outer_y: float = spec.height + rise * (1.0 - outer / roof_half) \
		- RoofShape.DEPTH * 0.5
	var inner_y: float = spec.height + rise * (1.0 - inner / roof_half) \
		- RoofShape.DEPTH * 0.5
	return Vector2(outer_y, inner_y)


static func basilica_fallback_roof_wall_center_y(spec: TempleSpec) -> float:
	var profile: Vector2 = basilica_fallback_roof_wall_profile(spec)
	return (profile.x + profile.y) * 0.5


static func basilica_nave_eave_height(spec: TempleSpec) -> float:
	if not basilica_has_nave_bearings(spec):
		return spec.height
	return spec.height + clampf(spec.height * BASILICA_NAVE_RISE_FRACTION, 1.6, 3.2)


## The lower clerestory opening is measured from the final column-capital
## record and the same architrave height used by the builder.
static func basilica_clerestory_opening_bottom(spec: TempleSpec) -> float:
	var wall_base: float = spec.height
	if basilica_has_nave_bearings(spec):
		var bearing_x := INF
		var bearing: Dictionary = {}
		for column in spec.columns:
			var p: Vector3 = column["pos"]
			if absf(p.x) < bearing_x:
				bearing_x = absf(p.x)
				bearing = column
		if not bearing.is_empty():
			var beam_h: float = clampf(spec.column_r * 0.34, 0.18, 0.38)
			wall_base = column_cap_top(bearing) + beam_h
	var opening_bottom: float = maxf(wall_base + 0.62, spec.height + 0.62)
	var opening_top: float = basilica_nave_eave_height(spec) - 0.30
	if opening_top <= opening_bottom + 0.35:
		opening_bottom = maxf(wall_base + 0.08, minf(opening_bottom, opening_top - 0.35))
	return opening_bottom


static func basilica_portico_eave_height(spec: TempleSpec) -> float:
	return spec.height + 0.15


static func basilica_portico_rise(spec: TempleSpec) -> float:
	return basilica_portico_half_width(spec) * BASILICA_PORTICO_ROOF_PITCH


static func basilica_portico_shaft_diameter(spec: TempleSpec) -> float:
	return clampf(basilica_portico_eave_height(spec) * 0.08, 0.70, 1.55)


static func basilica_portico_depth(spec: TempleSpec) -> float:
	return clampf(spec.width * BASILICA_PORTICO_DEPTH_FRACTION,
		BASILICA_PORTICO_MIN_DEPTH, BASILICA_PORTICO_MAX_DEPTH)


static func basilica_portico_half_width(spec: TempleSpec) -> float:
	return minf(spec.width * BASILICA_PORTICO_WIDTH_FRACTION * 0.5,
		spec.width * 0.5 - spec.wall_t - 0.4)


static func basilica_portico_column_positions(spec: TempleSpec) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not basilica_has_nave_bearings(spec):
		return out
	var half := basilica_portico_half_width(spec)
	var shaft_r: float = basilica_portico_shaft_diameter(spec) * 0.5
	var bearing_half: float = maxf(half - shaft_r, 0.5)
	var z: float = site_rect(spec).position.y - basilica_portico_depth(spec) + 0.5
	var count: int = clampi(int(round(bearing_half * 2.0 / ORDER_BAY)) + 1,
		BASILICA_PORTICO_MIN_COLUMNS, BASILICA_PORTICO_MAX_COLUMNS)
	if count % 2 != 0:
		count = count - 1 if count > BASILICA_PORTICO_MIN_COLUMNS \
			else mini(count + 1, BASILICA_PORTICO_MAX_COLUMNS)
	for i in range(count):
		var t := float(i) / float(count - 1)
		out.append(Vector2(lerpf(-bearing_half, bearing_half, t), z))
	return out


## Exterior forehall paving ends at the gate's outer wall face. A short 0.6m
## uncovered apron extends beyond the portico roof as a real approach surface.
static func basilica_portico_floor_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"basilica" or not basilica_has_nave_bearings(spec):
		return Rect2()
	var r := site_rect(spec)
	var half := basilica_portico_half_width(spec)
	var depth: float = basilica_portico_depth(spec)
	var apron: float = BASILICA_PORTICO_APPROACH_APRON
	return Rect2(Vector2(-half, r.position.y - depth - apron),
		Vector2(half * 2.0, depth + apron))


## The body-clear passage beneath the real pronaos floor, from its outside
## edge to the gate threshold. This is placement approach metadata, not a
## substitute door position.
static func basilica_approach_rect(spec: TempleSpec) -> Rect2:
	var floor: Rect2 = basilica_portico_floor_rect(spec)
	if floor.size.x <= 0.0:
		return Rect2()
	var gate_z: float = site_rect(spec).position.y
	var width: float = minf(TempleGeometry.PROCESSION_MIN,
		TempleGeometry.GATE_W - TempleGeometry.PERSON_RADIUS * 2.0)
	return Rect2(Vector2(-width * 0.5, floor.position.y),
		Vector2(width, gate_z - floor.position.y))


## A threshold floor joins the forehall slab to the interior floor through the
## actual gate opening, without paving under the solid front-wall returns.
static func basilica_threshold_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"basilica":
		return Rect2()
	var r := site_rect(spec)
	return Rect2(Vector2(-GATE_W * 0.5, r.position.y),
		Vector2(GATE_W, spec.wall_t))


static func basilica_portico_rect(spec: TempleSpec) -> Rect2:
	var floor: Rect2 = basilica_portico_floor_rect(spec)
	if floor.size.x <= 0.0:
		return Rect2()
	return floor


static func basilica_aisle_roof_run(spec: TempleSpec) -> float:
	return site_rect(spec).size.y + 0.8


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
	var interior: Rect2 = interior_rect(spec)
	var desired: float = maxf(4.0, interior.size.y * 0.4)
	# Preserve a useful hypostyle bay and the complete shrine behind the court.
	# Compute the shrine's authored minimum directly: sanctum_depth() depends on
	# hall_rect(), which depends on this court depth.
	var shrine_need: float = spec.altar_l + ALTAR_CLEAR * 2.0 + IDOL_GAP \
		+ spec.idol_width + 1.2
	var maximum: float = maxf(0.0, interior.size.y - maxf(4.0, shrine_need) - 4.0)
	return minf(desired, maximum)


## Keep the first supported column row inside the hall so the open court reads
## as a space of its own rather than a threshold directly under the colonnade.
static func pylon_hypostyle_setback(spec: TempleSpec) -> float:
	return 1.4 if spec.form == &"pylon" else 0.0


## The great hall: the roofed room the congregation stands in. For a pylon
## temple it starts beyond the court; for a rotunda it is the drum.
static func hall_rect(spec: TempleSpec) -> Rect2:
	var r: Rect2 = interior_rect(spec)
	var court: float = court_depth(spec)
	return Rect2(Vector2(r.position.x, r.position.y + court),
		Vector2(r.size.x, r.size.y - court))


## The Pylon's roof covers the hypostyle hall, not the open arrival court.
## The first authored cross-architrave is its front bearing line.
static func pylon_roof_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"pylon":
		return Rect2()
	var site: Rect2 = site_rect(spec)
	var hall: Rect2 = hall_rect(spec)
	var front: float = hall.position.y + pylon_hypostyle_setback(spec)
	if not spec.columns.is_empty():
		front = INF
		for column in spec.columns:
			var pos: Vector3 = column["pos"]
			front = minf(front, pos.z)
		front -= 0.12
	return Rect2(Vector2(site.position.x - 0.4, front),
		Vector2(site.size.x + 0.8, site.end.y + 0.4 - front))


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
	var x: float = h.position.x
	var width: float = h.size.x
	if spec.form == &"pylon":
		# The shrine is narrower than the public hall, with room for the authored altar.
		width = minf(h.size.x, maxf(spec.altar_w + 2.4, h.size.x * 0.62))
		# The lowest dais tread grows sideways from the top platform. Reserve that
		# full growth plus both return-wall thicknesses inside the shrine width.
		var tread_growth: float = float(maxi(spec.dais_steps, 1) - 1) * DAIS_TREAD
		var dais_min_width: float = spec.altar_w + ALTAR_CLEAR * 2.0
		var dais_required_width: float = dais_min_width + spec.wall_t * 2.0 \
			+ tread_growth * 2.0 + 0.1
		width = minf(h.size.x, maxf(width, dais_required_width))
		x = -width * 0.5
	return Rect2(Vector2(x, h.end.y - d), Vector2(width, d))


static func pylon_gate_width(spec: TempleSpec) -> float:
	return clampf(spec.width * 0.19, 3.8, 7.0)


static func pylon_sanctum_doorway_width(spec: TempleSpec) -> float:
	if spec.form != &"pylon":
		return 0.0
	return minf(GATE_W, sanctum_rect(spec).size.x - spec.wall_t * 2.0)


static func pylon_sanctum_portal_height(spec: TempleSpec) -> float:
	if spec.form != &"pylon":
		return 0.0
	# The portal head sits above the existing rite eye ray at the actual screen
	# plane. The short lintel begins at this opening top, not across the ray.
	var eye: Vector2 = sight_point(spec)
	var idol: Vector3 = idol_center(spec)
	var target_z: float = idol.z - spec.idol_width * 0.5 - 0.05
	var gate_z: float = sanctum_rect(spec).position.y + spec.wall_t * 0.5
	var t: float = clampf((gate_z - eye.y) / maxf(target_z - eye.y, 0.001), 0.0, 1.0)
	var line_y: float = lerpf(1.65, idol.y + spec.idol_height * 0.7, t)
	var lintel_h: float = clampf(spec.wall_t * 0.55, 0.45, 0.8)
	return maxf(1.9, minf(spec.height - lintel_h - 0.6, line_y + 0.18))


static func pylon_sanctum_wall_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if spec.form != &"pylon":
		return out
	var shrine: Rect2 = sanctum_rect(spec)
	var t: float = spec.wall_t
	var opening: float = pylon_sanctum_doorway_width(spec)
	var pier_width: float = (shrine.size.x - opening) * 0.5
	out.append(Rect2(shrine.position, Vector2(pier_width, t)))
	out.append(Rect2(Vector2(shrine.end.x - pier_width, shrine.position.y),
		Vector2(pier_width, t)))
	var return_front: float = shrine.position.y + t
	var return_depth: float = maxf(shrine.size.y - t, 0.0)
	out.append(Rect2(Vector2(shrine.position.x, return_front),
		Vector2(t, return_depth)))
	out.append(Rect2(Vector2(shrine.end.x - t, return_front),
		Vector2(t, return_depth)))
	return out


# ------------------------------------------------------------------- dais

## The platform the altar stands on, stepped up from the hall floor.
static func dais_rect(spec: TempleSpec) -> Rect2:
	var s: Rect2 = sanctum_rect(spec)
	var minimum_width: float = spec.altar_w + ALTAR_CLEAR * 2.0
	var maximum_width: float = s.size.x - 1.0
	if spec.form == &"pylon":
		var tread_growth: float = float(maxi(spec.dais_steps, 1) - 1) * DAIS_TREAD
		# Keep the full lowest tread inside the clear width between the two return
		# walls. sanctum_rect() reserves this width before placing the shrine.
		maximum_width = s.size.x - spec.wall_t * 2.0 - tread_growth * 2.0 - 0.1
	var w: float = clampf(s.size.x * 0.55, minimum_width, maximum_width)
	var d: float = clampf(s.size.y * 0.6, spec.altar_l + ALTAR_CLEAR * 2.0, s.size.y - 0.6)
	if spec.form == &"rotunda":
		# Keep the complete stepped dais inside the circular room, including the
		# extra tread and side growth emitted by _build_dais().
		var circle: float = rotunda_inner_radius(spec) - 0.15
		var min_width: float = spec.altar_w + ALTAR_CLEAR * 2.0
		w = minf(w, maxf(min_width, s.size.x * 0.35))
		var grow: float = float(maxi(spec.dais_steps, 1) - 1) * DAIS_TREAD
		w = minf(w, maxf((circle - grow) * 2.0, 0.0))
		var outer_half: float = w * 0.5 + grow
		var max_back: float = sqrt(maxf(circle * circle - outer_half * outer_half, 0.0))
		var back: float = minf(s.end.y - 0.1, max_back)
		var minimum_front: float = s.position.y + grow
		var pit: Rect2 = pit_rect(spec)
		if pit.size.x > 0.0:
			# The lowest emitted tread grows toward the congregation only. Keep
			# that true footprint behind the pit so the central witness remains
			# an actual hole beside the bridge, not a rectangle under the dais.
			minimum_front = maxf(minimum_front,
				pit.end.y + grow + 0.15)
		var available: float = maxf(back - minimum_front, 0.0)
		# Fit the full service rectangle on the stepped footprint. The idol gap
		# fixes the altar's rearward limit; the front approach must therefore be
		# reserved from that same center, not inferred from altar depth alone.
		var center_limit: float = _rotunda_altar_center_limit(spec, back)
		var approach_front: float = center_limit - spec.altar_l * 0.5 \
			- ALTAR_CLEAR
		var required: float = maxf(spec.altar_l + ALTAR_CLEAR * 2.0,
			back - (approach_front + grow))
		d = minf(maxf(d, required), available)
		return Rect2(Vector2(-w * 0.5, back - d), Vector2(w, d))
	return Rect2(Vector2(-w / 2.0, s.end.y - d), Vector2(w, d))


## Is the sanctum deep enough for the altar to stand its distance from the god?
## The generator asks this and grows the room until the answer is yes.
static func sanctum_fits(spec: TempleSpec) -> bool:
	var a: Vector3 = altar_center(spec)
	var d: Rect2 = dais_rect(spec)
	if spec.form != &"rotunda":
		return a.z - spec.altar_l / 2.0 >= d.position.y - 0.05
	var approach: Rect2 = altar_approach(spec)
	var foot: Rect2 = dais_footprint(spec)
	var circle: float = rotunda_inner_radius(spec) - 0.15
	if d.size.x + 0.001 < spec.altar_w + ALTAR_CLEAR * 2.0 \
			or d.size.y + 0.001 < spec.altar_l + ALTAR_CLEAR * 2.0:
		return false
	if approach.position.x < foot.position.x - 0.03 \
			or approach.end.x > foot.end.x + 0.03 \
			or approach.position.y < foot.position.y - 0.03 \
			or approach.end.y > foot.end.y + 0.03:
		return false
	for corner in [approach.position, Vector2(approach.end.x, approach.position.y),
			approach.end, Vector2(approach.position.x, approach.end.y)]:
		if corner.length() > circle + 0.03:
			return false
	var idol: Rect2 = idol_rect(spec)
	# altar_center already leaves IDOL_GAP between the altar's rear face and the
	# idol. The service approach extends behind the altar by ALTAR_CLEAR; asking
	# that whole clearance rectangle to preserve IDOL_GAP again double-reserves
	# the same depth and can reject a room whose altar itself fits correctly.
	return approach.end.y <= idol.position.y + 0.03


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
	if spec.form == &"rotunda":
		var foot: Rect2 = dais_footprint(spec)
		var minimum: float = foot.position.y + ALTAR_CLEAR + spec.altar_l / 2.0
		var platform_limit: float = d.end.y - ALTAR_CLEAR - spec.altar_l / 2.0
		limit = minf(limit, platform_limit)
		z = maxf(z, minimum)
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
		var gateward: float = _rotunda_required_pit_gateward(spec, r)
		return Rect2(Vector2(-r, -r - gateward), Vector2(r * 2.0, r * 2.0))
	var d: Rect2 = dais_rect(spec)
	var z: float = d.position.y - r - 1.2
	return Rect2(Vector2(-r, z - r), Vector2(r * 2.0, r * 2.0))


## Shift only as much as the real sanctum needs. The lowest dais tread starts
## behind the pit rim; the altar and its service clearance fit on the
## circle-constrained platform. This uses the same dimensions as dais_rect()
## without calling pit_rect() again, so the shared pit/bridge/floor datum stays
## acyclic and all consumers inherit one physical translation.
static func _rotunda_required_pit_gateward(spec: TempleSpec, radius: float) -> float:
	var sanctum: Rect2 = sanctum_rect(spec)
	var circle: float = rotunda_inner_radius(spec) - 0.15
	var minimum_width: float = spec.altar_w + ALTAR_CLEAR * 2.0
	var width: float = clampf(sanctum.size.x * 0.55,
		minimum_width, sanctum.size.x - 1.0)
	width = minf(width, maxf(minimum_width, sanctum.size.x * 0.35))
	var grow: float = float(maxi(spec.dais_steps, 1) - 1) * DAIS_TREAD
	width = minf(width, maxf((circle - grow) * 2.0, 0.0))
	var half_outer: float = width * 0.5 + grow
	var circular_back: float = sqrt(maxf(circle * circle - half_outer * half_outer, 0.0))
	var back: float = minf(sanctum.end.y - 0.1, circular_back)
	# Match dais_rect(): move the real pit only far enough gateward that the
	# entire approach can occupy the circle-constrained dais footprint.
	var center_limit: float = _rotunda_altar_center_limit(spec, back)
	var approach_front: float = center_limit - spec.altar_l * 0.5 \
		- ALTAR_CLEAR
	var required_depth: float = maxf(spec.altar_l + ALTAR_CLEAR * 2.0,
		back - (approach_front + grow))
	var centered_pit_front: float = radius + grow + 0.15
	var available: float = back - centered_pit_front
	return maxf(required_depth - available, 0.0)


## Latest legal altar center after preserving the actual idol gap and a full
## rear service clearance on the dais. The dais front and pit are derived from
## this same limit, so they cannot reserve different footprints.
static func _rotunda_altar_center_limit(spec: TempleSpec, dais_back: float) -> float:
	var idol: Rect2 = idol_rect(spec)
	var idol_limit: float = idol.position.y - IDOL_GAP - spec.altar_l * 0.5
	var platform_limit: float = dais_back - ALTAR_CLEAR - spec.altar_l * 0.5
	return minf(idol_limit, platform_limit)


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
		for column in column_records(spec):
			out.append(column["pos"])
		return out
	return _generated_column_positions(spec)


static func column_records(spec: TempleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not spec.columns.is_empty():
		if spec.form == &"rotunda":
			return _clear_authored_rotunda_records(spec, spec.columns)
		# Authored non-Rotunda records are the plan. Preserve their individual
		# bearings, heights, ring numbers, and any family metadata unchanged.
		for record in spec.columns:
			out.append(record.duplicate(true))
		return out
	var positions := column_positions(spec)
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


## Filter authored Rotunda members by each record's actual footprint, while
## retaining the complete original record for every surviving column.
static func _clear_authored_rotunda_records(spec: TempleSpec,
		records: Array[Dictionary]) -> Array[Dictionary]:
	var pit: Rect2 = pit_rect(spec)
	var cells: Array[Rect2] = cell_rects(spec)
	var lane: Rect2 = processional_lane(spec)
	var holy: Array[Rect2] = [dais_footprint(spec).grow(0.3),
		idol_rect(spec).grow(0.3), altar_rect(spec).grow(0.3)]
	var candidates: Array[Dictionary] = []
	for record in records:
		if not record.has("pos") or not record.has("radius"):
			continue
		var pos: Vector3 = record["pos"]
		var radius: float = float(record["radius"])
		var foot := Rect2(Vector2(pos.x - radius, pos.z - radius),
			Vector2.ONE * radius * 2.0)
		var clash: bool = lane.intersects(foot)
		if not clash and pit.size.x > 0.0:
			clash = pit.grow(PIT_RIM).intersects(foot)
		if not clash:
			for cell in cells:
				if cell.grow(0.15).intersects(foot):
					clash = true
					break
		if not clash:
			for occupied in holy:
				if occupied.intersects(foot):
					clash = true
					break
		if not clash:
			candidates.append(record.duplicate(true))
	var out: Array[Dictionary] = []
	for record in candidates:
		var pos: Vector3 = record["pos"]
		if absf(pos.x) < 0.01:
			out.append(record)
			continue
		for twin in candidates:
			var twin_pos: Vector3 = twin["pos"]
			if absf(twin_pos.x + pos.x) < 0.05 \
					and absf(twin_pos.z - pos.z) < 0.05 \
					and absf(twin_pos.y - pos.y) < 0.05:
				out.append(record)
				break
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
			var z0: float = h.position.y + (pylon_hypostyle_setback(spec) \
				if spec.form == &"pylon" else 1.6)
			var terminal_clearance: float = 1.0
			if spec.form == &"pylon":
				terminal_clearance = maxf(terminal_clearance, spec.column_r * 1.2 + 0.12)
			var z1: float = sanctum_rect(spec).position.y - terminal_clearance
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


## Underside of the beam course carried by the authored column capitals.
static func column_entablature_height(spec: TempleSpec) -> float:
	return column_height(spec) + COLUMN_CAP * spec.column_r


## The top of the capital actually emitted for one authored column record.
## Beam placement uses this per support, so its soffit rests on the capital.
static func column_cap_top(column: Dictionary) -> float:
	return float(column["height"]) + COLUMN_CAP * float(column["radius"])


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
	if spec.form == &"rotunda":
		var outer_radius: float = rotunda_outer_radius(spec)
		var outer_arrival: float = outer_radius + 0.45
		var w: float = GATE_W + 1.2
		if spec.obelisks:
			var obelisk_x: float = absf(obelisk_center(spec, 1.0).x)
			var obelisk_z: float = obelisk_center(spec, 1.0).y
			var half_obelisk: float = obelisk_height(spec) * 0.07
			w = maxf(w, (obelisk_x + half_obelisk + 0.25) * 2.0)
			outer_arrival = maxf(outer_arrival,
				-obelisk_z + half_obelisk + 0.25)
		w = minf(spec.width, w)
		return Rect2(Vector2(-w * 0.5, -outer_arrival),
			Vector2(w, outer_arrival - outer_radius + 0.4))
	var depth: float = 0.0
	if spec.obelisks:
		var obelisk_apron: float = obelisk_height(spec) * 0.14 + 2.4
		if spec.form == &"pylon":
			obelisk_apron = maxf(4.0, obelisk_apron)
		depth = maxf(depth, obelisk_apron)
	if spec.form == &"ziggurat":
		# Only the part in front of the base needs paving. Extending the
		# summit landing must not grow the building's outer placement bounds.
		depth = maxf(depth, terrace_top(spec) * 1.25 + 2.3)
	if depth <= 0.0:
		return Rect2()
	var apron_gate_width: float = GATE_W
	if spec.form == &"pylon":
		apron_gate_width = pylon_gate_width(spec)
	var w: float = minf(r.size.x, apron_gate_width + 8.0)
	var end_y: float = r.position.y + 0.4
	if spec.form == &"pylon":
		end_y = minf(end_y, interior_rect(spec).position.y)
	if spec.form == &"ziggurat":
		# Join the ground-level approach to the hollow first-terrace doorway.
		# Its inset is several metres on a normal ziggurat; stopping at the
		# outer footprint leaves entry and forecourt as separate islands.
		end_y = interior_rect(spec).position.y + 0.4
	return Rect2(Vector2(-w / 2.0, r.position.y - depth), Vector2(w, end_y - (r.position.y - depth)))


## The gate-width floor that closes only the actual gap between apron and the
## interior slab through the outer wall. No paving is added under wall returns.
static func pylon_threshold_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"pylon":
		return Rect2()
	var apron: Rect2 = forecourt_rect(spec)
	if apron.size.x <= 0.0:
		return Rect2()
	var inside: Rect2 = interior_rect(spec)
	var depth: float = inside.position.y - apron.end.y
	if depth <= 0.05:
		return Rect2()
	var gate_width: float = pylon_gate_width(spec)
	return Rect2(Vector2(-gate_width * 0.5, apron.end.y), Vector2(gate_width, depth))


## Recessed gate approach for public placement: the true door remains on the
## wall plane while the footprint begins at the actual paved apron edge.
static func pylon_approach_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"pylon":
		return Rect2()
	var apron: Rect2 = forecourt_rect(spec)
	if apron.size.x <= 0.0 or apron.size.y <= 0.0:
		return Rect2()
	var gate_z: float = site_rect(spec).position.y
	return Rect2(Vector2(apron.position.x, apron.position.y),
		Vector2(apron.size.x, gate_z - apron.position.y))


## The Rotunda's public approach follows the actual paved apron to the circular
## gate plane. It does not move the gate to the rectangle used as its bounds.
static func rotunda_approach_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"rotunda":
		return Rect2()
	var apron: Rect2 = forecourt_rect(spec)
	var gate_z: float = -rotunda_outer_radius(spec)
	return Rect2(Vector2(apron.position.x, apron.position.y),
		Vector2(apron.size.x, gate_z - apron.position.y))


## The actual paved threshold from the forecourt, through the gate thickness,
## and into the first inscribed floor band. It is deliberately gate-width only:
## the portion outside the circle is supported solely inside the real doorway.
static func rotunda_threshold_rect(spec: TempleSpec) -> Rect2:
	if spec.form != &"rotunda":
		return Rect2()
	var apron: Rect2 = forecourt_rect(spec)
	var start_z: float = apron.end.y - 0.1
	var end_z: float = -rotunda_inner_radius(spec) + ROTUNDA_FLOOR_BAND + 0.1
	return Rect2(Vector2(-GATE_W * 0.5, start_z),
		Vector2(GATE_W, maxf(end_z - start_z, 0.05)))


static func obelisk_height(spec: TempleSpec) -> float:
	var scale: float = 0.45 if spec.form == &"pylon" else 1.0
	return spec.height * OBELISK_H * 2.0 * scale


## Where the obelisks stand: clear of the pylons behind them, on the paving.
static func obelisk_center(spec: TempleSpec, side: float) -> Vector2:
	var r: Rect2 = site_rect(spec)
	var oh: float = obelisk_height(spec)
	var gate_half: float = GATE_W / 2.0
	var lateral_offset: float = 1.6
	if spec.form == &"pylon":
		gate_half = pylon_gate_width(spec) / 2.0
		lateral_offset = 2.2
	return Vector2(side * (gate_half + lateral_offset),
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
	if spec.form == &"rotunda":
		out.append_array(_rotunda_floor_bands(spec))
	else:
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
	var portico_floor := basilica_portico_floor_rect(spec)
	if portico_floor.size.x > 0.0:
		out.append(portico_floor)
	var threshold := basilica_threshold_rect(spec)
	if threshold.size.x > 0.0:
		out.append(threshold)
	var rotunda_threshold := rotunda_threshold_rect(spec)
	if rotunda_threshold.size.x > 0.0:
		out.append(rotunda_threshold)
	var pylon_threshold := pylon_threshold_rect(spec)
	if pylon_threshold.size.x > 0.0:
		out.append(pylon_threshold)
	var court: Rect2 = forecourt_rect(spec)
	if court.size.x > 0.0:
		out.append(court)
	var kept: Array[Rect2] = []
	for r in out:
		if r.size.x > 0.05 and r.size.y > 0.05:
			kept.append(r)
	return kept


## Walk-grid floor rectangles inscribed in the Rotunda's circular inner wall.
## Rectangles are a conservative walk-grid approximation. The emitted mesh
## adds convex perimeter wedges from the same row data, reaching the circular
## inner wall instead of leaving the rectangular approximation exposed.
## The central pit is cut from each row and the actual axial bridge is restored.
static func _rotunda_floor_bands(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _rotunda_floor_rows(spec):
		var z0: float = row["z0"]
		var z1: float = row["z1"]
		var left: float = row["left"]
		var right: float = row["right"]
		if right - left > 0.05:
			out.append(Rect2(Vector2(left, z0), Vector2(right - left, z1 - z0)))
	var bridge: Rect2 = bridge_rect(spec)
	if bridge.size.x > 0.0:
		out.append(bridge)
	return out


## Convex floor strips between each conservative walk rectangle and the exact
## polygonal circle. The builder emits these as real stone slabs. Pit cut lines
## and the zero axis split rows so each strip stays convex.
static func rotunda_floor_wing_polygons(spec: TempleSpec) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var radius: float = rotunda_inner_radius(spec)
	for row in _rotunda_floor_rows(spec):
		var z0: float = row["z0"]
		var z1: float = row["z1"]
		var left: float = row["left"]
		var right: float = row["right"]
		var outer0: float = sqrt(maxf(radius * radius - z0 * z0, 0.0))
		var outer1: float = sqrt(maxf(radius * radius - z1 * z1, 0.0))
		if bool(row["extend_left"]) and (left + outer0 > 0.02 or left + outer1 > 0.02):
			out.append(PackedVector2Array([
				Vector2(-outer0, z0), Vector2(left, z0),
				Vector2(left, z1), Vector2(-outer1, z1)]))
		if bool(row["extend_right"]) and (outer0 - right > 0.02 or outer1 - right > 0.02):
			out.append(PackedVector2Array([
				Vector2(right, z0), Vector2(outer0, z0),
				Vector2(outer1, z1), Vector2(right, z1)]))
	return out


## Shared row data keeps pit boundaries and conservative walk floors aligned
## with the perimeter slabs. The grid deliberately omits the curved wings;
## that approximation can understate free floor, never invent it.
static func _rotunda_floor_rows(spec: TempleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var radius: float = rotunda_inner_radius(spec)
	var hole: Rect2 = pit_rect(spec)
	var z0: float = -radius
	while z0 < radius - 0.001:
		var z1: float = minf(radius, z0 + ROTUNDA_FLOOR_BAND)
		var cuts: Array[float] = [z0, z1]
		if z0 < 0.0 and z1 > 0.0:
			cuts.append(0.0)
		if hole.size.x > 0.0:
			if hole.position.y > z0 and hole.position.y < z1:
				cuts.append(hole.position.y)
			if hole.end.y > z0 and hole.end.y < z1:
				cuts.append(hole.end.y)
		cuts.sort()
		for cut_index in range(cuts.size() - 1):
			var row0: float = cuts[cut_index]
			var row1: float = cuts[cut_index + 1]
			var edge_z: float = maxf(absf(row0), absf(row1))
			var half_width: float = sqrt(maxf(radius * radius - edge_z * edge_z, 0.0))
			var mid_z: float = (row0 + row1) * 0.5
			var cuts_pit: bool = hole.size.x > 0.0 \
				and mid_z > hole.position.y and mid_z < hole.end.y \
				and hole.position.x < half_width and hole.end.x > -half_width
			if cuts_pit:
				var left_end: float = minf(hole.position.x, half_width)
				var right_start: float = maxf(hole.end.x, -half_width)
				if left_end - (-half_width) > 0.05:
					out.append({"z0": row0, "z1": row1, "left": -half_width,
						"right": left_end, "extend_left": true, "extend_right": false})
				if half_width - right_start > 0.05:
					out.append({"z0": row0, "z1": row1, "left": right_start,
						"right": half_width, "extend_left": false, "extend_right": true})
			else:
				out.append({"z0": row0, "z1": row1, "left": -half_width,
					"right": half_width, "extend_left": true, "extend_right": true})
		z0 = z1
	return out


## What stands on that floor and gets in the way: the columns, the altar, the
## idol. The dais is not here -- you walk up onto a dais, which is the whole
## point of one.
static func obstacle_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for wall in pylon_sanctum_wall_rects(spec):
		out.append(wall)
	var columns: Array[Dictionary] = column_records(spec)
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
	if spec.form == &"rotunda":
		# Seat the dome on the circular wall top rather than suspending a small
		# cap inside a larger square roof/deck.
		return rotunda_outer_radius(spec) - spec.wall_t * 0.5
	return ring_radius(spec) + spec.column_r * 2.0


static func rotunda_lantern_radius(spec: TempleSpec) -> float:
	return minf(clampf(spec.column_r * 1.1, 0.42, 0.72), dome_radius(spec) * 0.12)


static func roof_height(spec: TempleSpec) -> float:
	match spec.form:
		&"basilica":
			if not basilica_has_nave_bearings(spec):
				return spec.height + minf(spec.width, spec.length) * RIDGE_PITCH \
					+ RoofShape.DEPTH * 0.5
			var nave_span: float = basilica_nave_half_width(spec) * 2.0
			return basilica_nave_eave_height(spec) + nave_span * RIDGE_PITCH \
				+ RoofShape.DEPTH * 0.5
		&"ziggurat":
			return terrace_top(spec)
		&"rotunda":
			return spec.height + RoofShape.DEPTH * 0.5
		&"pylon":
			return spec.height + 0.5
	return spec.height + minf(spec.width, spec.length) * RIDGE_PITCH + RoofShape.DEPTH * 0.5


static func total_height(spec: TempleSpec) -> float:
	var top: float = roof_height(spec)
	if spec.spire and spec.form != &"rotunda":
		top = maxf(top, roof_height(spec) + spec.spire_height)
	top = maxf(top, idol_apex(spec))
	if spec.obelisks:
		top = maxf(top, obelisk_height(spec))
	return top


## The pylon towers either side of the gate: the wall a pylon temple shows the
## world.
static func pylon_tower_shell_depth(spec: TempleSpec) -> float:
	if spec.form != &"pylon":
		return 0.0
	return minf(0.32, maxf(0.14, spec.wall_t * 0.12))


static func pylon_rects(spec: TempleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if spec.form != &"pylon":
		return out
	var r: Rect2 = site_rect(spec)
	# A deep pair of battered gate towers must read in elevation as volumes, not
	# as thin pilasters laid over the perimeter wall.
	var d: float = clampf(spec.length * 0.22, 4.0, 6.0)
	var gate_width: float = pylon_gate_width(spec)
	var w: float = (r.size.x - gate_width) / 2.0
	for side in [-1.0, 1.0]:
		var x: float = r.position.x if side < 0.0 else gate_width / 2.0
		out.append(Rect2(Vector2(x, r.position.y), Vector2(w, d)))
	return out


## Everything the temple covers in plan, its outworks included.
static func plan_extent(spec: TempleSpec) -> Rect2:
	var e: Rect2 = site_rect(spec)
	if spec.form == &"pylon":
		e = e.merge(pylon_roof_rect(spec))
		var apron: Rect2 = forecourt_rect(spec)
		if apron.size.x > 0.0 and apron.size.y > 0.0:
			e = e.merge(apron)
	if spec.form == &"basilica":
		# Include actual main-roof overhang, side-aisle soffits, and the projecting
		# covered pronaos so public placement reserves the architecture it emits.
		e = e.grow(maxf(maxf(ORDER_REACH, 0.6), maxf(spec.wall_t, 0.5) * 0.5))
		# The covered portico already ends at its real outer floor face. Growing
		# this front edge invents an unbuilt apron and separates the published
		# footprint front from the actual arrival surface.
		e = e.merge(basilica_portico_floor_rect(spec))
	if spec.form == &"ziggurat":
		e = e.merge(stair_rect(spec))
	if spec.form == &"rotunda":
		var extent_radius: float = rotunda_outer_radius(spec) + 0.45
		e = Rect2(Vector2(-extent_radius, -extent_radius),
			Vector2(extent_radius * 2.0, extent_radius * 2.0))
		e = e.merge(forecourt_rect(spec))
	if spec.obelisks:
		e = e.grow(1.5)
	return e
