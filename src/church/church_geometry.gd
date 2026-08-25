class_name ChurchGeometry
extends RefCounted
## Single source of truth for a church's massing: where every structural volume
## sits, and the shared constants that decide it.
##
## Both ChurchBuilder (which emits the mesh) and BlueprintView (which draws the
## plan and elevation) read from here. That is the point: when each derived its
## own positions, they drifted -- the drawing stopped being a drawing of the
## model. Anything used by both belongs in this file and nowhere else.
##
## All functions are pure and take an explicit spec. Model axes:
##   +X = south, +Y = up, +Z = east (the altar end).

# ---- joints: how deep abutting masses interpenetrate, in metres ----
const TOWER_EMBED := 0.6    # tower inside the nave's west wall
const APSE_EMBED := 0.3     # apse inside the nave's east wall
const AISLE_LAP := 0.15     # aisle wall lapping the nave wall
const MIN_AISLE_LEN := 3.0  # shorter than this and an aisle is not worth having

# ---- proportions ----
const TRANSEPT_DEPTH_RATIO := 0.55   # transept depth along Z, x nave width
const SPIRE_RISE_FACTOR := 2.2       # spire rise, x tower width x spire pitch
const PYRAMID_RISE_FACTOR := 0.75    # pyramid tower roof rise, x tower width
const BELFRY_RISE_FACTOR := 0.4      # belfry cap rise, x tower width
const FLAT_CAP_RISE := 0.3           # flat tower gets a thin parapet slab
const PINNACLE_RISE := 1.8           # shaft (1.2) + its little pyramid (0.6)
const RIDGE_CAP := 0.25              # ridge timber sitting proud of the slabs
const APSE_CONE_RATIO := 0.9         # apse roof rise, x apse radius
const DOOR_H_RATIO := 0.32           # door height, x nave height
const DOOR_H_CAP := 3.4              # ...capped at this many metres
const NAVE_WINDOW_BAY := 3.2         # metres of nave wall per side window
const AISLE_HEIGHT_RATIO := 0.55     # aisle wall height, x nave height
const APSE_HEIGHT_RATIO := 0.85      # apse drum height, x nave height

# ---- roof overhangs ----
const ROOF_EAVE_X := 0.5
const ROOF_EAVE_Z := 0.4
const APSE_EAVE := 0.35

const OPENING_EPS := 0.02   # surface offset so openings do not z-fight
const BUTTRESS_INSET := 0.05   # buttresses bury this far into the wall they brace

# ---- landmark features ----
const TWIN_TOWER_GAP := 0.6      # clear air between paired west towers
const FLYER_PIER_GAP := 0.9      # gap between aisle wall and flyer pier
const FLYER_PIER_W := 0.9        # minimum flyer pier plan size
const FLYER_TIER_DROP := 0.34    # vertical gap between stacked flyers, x height
const CHAPEL_LAP := 0.25         # chapel mouth buried in the wall it opens off
const AMBULATORY_W := 0.55       # ambulatory width, x apse radius
const DOME_DRUM_RATIO := 0.45    # drum height, x dome radius
const PENDENTIVE_H := 0.5        # square-to-round transition under the drum
const LANTERN_CAP_RATIO := 0.22  # the little roof capping a lantern, x radius
const LANTERN_RATIO := 0.28      # lantern height, x dome radius
const NARTHEX_DEPTH := 0.35      # narthex depth along Z, x nave width


# ------------------------------------------------------------------ nave

static func nave_aabb(spec: ChurchSpec) -> AABB:
	return AABB(Vector3(-spec.width / 2.0, 0.0, -spec.length / 2.0),
		Vector3(spec.width, spec.height, spec.length))


static func nave_window_count(spec: ChurchSpec) -> int:
	return int(spec.length / NAVE_WINDOW_BAY)


static func door_height(spec: ChurchSpec) -> float:
	return minf(spec.height * DOOR_H_RATIO, DOOR_H_CAP)


# ----------------------------------------------------------------- tower

## Centre of the tower along Z. The tower abuts the west wall, penetrating it
## by TOWER_EMBED so the masses read as joined rather than merely touching.
static func tower_center_z(spec: ChurchSpec) -> float:
	return -spec.length / 2.0 + TOWER_EMBED - spec.tower_width / 2.0


## Centre X of a west tower. A single tower sits on the nave axis; twin towers
## flank it, kept inside the nave footprint so they never collide.
static func tower_center_x(spec: ChurchSpec, side: float) -> float:
	if spec.west_towers < 2:
		return 0.0
	return side * (spec.tower_width + TWIN_TOWER_GAP) / 2.0


## Largest tower width that still lets a pair stand side by side on the facade.
static func max_twin_tower_width(spec: ChurchSpec) -> float:
	return maxf((spec.width - TWIN_TOWER_GAP) / 2.0, 1.5)


static func tower_aabb(spec: ChurchSpec, side := 0.0) -> AABB:
	var tw: float = spec.tower_width
	return AABB(Vector3(tower_center_x(spec, side) - tw / 2.0, 0.0,
		tower_center_z(spec) - tw / 2.0), Vector3(tw, spec.tower_height, tw))


## Each west tower in turn, as (side, aabb). Empty when there is no tower.
static func west_tower_sides(spec: ChurchSpec) -> Array[float]:
	if spec.west_towers >= 2:
		return [-1.0, 1.0]
	if spec.west_towers == 1:
		return [0.0]
	return []


## Rise of the tower roof above the tower top, for every roof kind the builder
## emits. A spire also carries a pinnacle, which is part of the silhouette and
## so part of the height the sheet dimensions.
static func tower_roof_rise(spec: ChurchSpec) -> float:
	if not spec.tower:
		return 0.0
	var tw: float = spec.tower_width
	match spec.tower_roof:
		&"spire":
			return tw * spec.spire_pitch * SPIRE_RISE_FACTOR + PINNACLE_RISE
		&"pyramid":
			return tw * PYRAMID_RISE_FACTOR
		&"belfry":
			return tw * BELFRY_RISE_FACTOR
	return FLAT_CAP_RISE


# ------------------------------------------------------------------ apse

## The springing plane: the apse drum's FLAT FACE sits here, embedded
## APSE_EMBED inside the nave, and the drum bulges east to +apse_radius.
## half_cylinder() sweeps a in [0, PI] so sin(a) >= 0; this is the flat face,
## not the centre of a full cylinder.
static func apse_springing_z(spec: ChurchSpec) -> float:
	return spec.length / 2.0 - APSE_EMBED


static func apse_aabb(spec: ChurchSpec) -> AABB:
	var r: float = spec.apse_radius
	return AABB(Vector3(-r, 0.0, apse_springing_z(spec)),
		Vector3(r * 2.0, spec.height * APSE_HEIGHT_RATIO, r))


# -------------------------------------------------------------- transept

static func transept_depth(spec: ChurchSpec) -> float:
	return spec.width * TRANSEPT_DEPTH_RATIO


## The crossing sits at the east end, shifted west by APSE_EMBED when an apse
## is present so the apse still springs from the nave wall rather than from it.
static func transept_center_z(spec: ChurchSpec) -> float:
	var d: float = transept_depth(spec)
	var z: float = spec.length / 2.0 - d / 2.0
	if spec.apse:
		z -= APSE_EMBED
	return z


static func transept_aabb(spec: ChurchSpec) -> AABB:
	var d: float = transept_depth(spec)
	return AABB(Vector3(-spec.transept_len / 2.0, 0.0, transept_center_z(spec) - d / 2.0),
		Vector3(spec.transept_len, spec.height, d))


## West face of the crossing: the plane aisles must stop at.
static func transept_front_z(spec: ChurchSpec) -> float:
	return transept_center_z(spec) - transept_depth(spec) / 2.0


# ---------------------------------------------------------------- aisles

## The Z span available to a side aisle: between the tower's east face and the
## crossing's west face, so it slices through neither.
static func aisle_z_range(spec: ChurchSpec) -> Vector2:
	var z0: float = -spec.length / 2.0
	if spec.tower:
		z0 = -spec.length / 2.0 + TOWER_EMBED + spec.tower_width
	var z1: float = spec.length / 2.0
	if spec.transept:
		z1 = transept_front_z(spec)
	return Vector2(z0, z1)


static func aisle_length(spec: ChurchSpec) -> float:
	var zr: Vector2 = aisle_z_range(spec)
	return zr.y - zr.x


## Is there room for a usable aisle? The generator uses this to decide, so that
## build() never has to mutate the spec it was handed.
static func aisle_fits(spec: ChurchSpec) -> bool:
	return aisle_length(spec) >= MIN_AISLE_LEN


## Centre X of aisle `ring` on `side`. Ring 0 hugs the nave; each further ring
## laps the one inside it, which is how Notre-Dame's double aisles and
## Cologne's five-aisled section are built.
static func aisle_center_x(spec: ChurchSpec, side: float, ring := 0) -> float:
	var x: float = spec.width / 2.0 + spec.aisle_width / 2.0 - AISLE_LAP
	x += ring * (spec.aisle_width - AISLE_LAP)
	return side * x


## Outer face of the outermost aisle on `side`, or the nave wall if there are none.
static func aisle_outer_x(spec: ChurchSpec) -> float:
	if spec.aisles <= 0:
		return spec.width / 2.0
	return absf(aisle_center_x(spec, 1.0, spec.aisles - 1)) + spec.aisle_width / 2.0


## Each ring steps down in height, so the clerestory stays visible above them.
static func aisle_height(spec: ChurchSpec, ring := 0) -> float:
	return spec.height * AISLE_HEIGHT_RATIO * pow(0.82, ring)


static func aisle_aabb(spec: ChurchSpec, side: float, ring := 0) -> AABB:
	var zr: Vector2 = aisle_z_range(spec)
	var aw: float = spec.aisle_width
	return AABB(Vector3(aisle_center_x(spec, side, ring) - aw / 2.0, 0.0, zr.x),
		Vector3(aw, aisle_height(spec, ring), zr.y - zr.x))


# ------------------------------------------------- crossing tower and dome

## The crossing: where nave and transept meet, and what a dome or lantern
## tower is centred on. Without a transept it falls at the nave centre.
static func crossing_center_z(spec: ChurchSpec) -> float:
	return transept_center_z(spec) if spec.transept else 0.0


## The crossing tower stands on the crossing BAY: nave width across, transept
## depth along Z. Making it a width-square instead ran it east past the apse
## springing, so the tower swallowed the apse.
static func crossing_bay_depth(spec: ChurchSpec) -> float:
	return transept_depth(spec) if spec.transept else spec.width


static func crossing_tower_aabb(spec: ChurchSpec) -> AABB:
	var d: float = crossing_bay_depth(spec)
	return AABB(Vector3(-spec.width / 2.0, 0.0, crossing_center_z(spec) - d / 2.0),
		Vector3(spec.width, spec.crossing_tower_height, d))


## Height the dome drum springs from: the top of the walls it rests on.
static func dome_base_height(spec: ChurchSpec) -> float:
	return spec.height


## The pendentive course: the square-to-round transition that carries the drum
## on the walls below. It is a real structural member, so it is a mass of its
## own -- without it the drum reads as hovering half a metre above the nave.
static func pendentive_aabb(spec: ChurchSpec) -> AABB:
	var r: float = spec.dome_radius + 0.3
	return AABB(Vector3(-r, dome_base_height(spec), crossing_center_z(spec) - r),
		Vector3(r * 2.0, PENDENTIVE_H, r * 2.0))


static func dome_drum_aabb(spec: ChurchSpec) -> AABB:
	var r: float = spec.dome_radius
	return AABB(Vector3(-r, dome_base_height(spec) + PENDENTIVE_H,
		crossing_center_z(spec) - r), Vector3(r * 2.0, spec.dome_drum_height, r * 2.0))


## Footprint of the dome MASSES: the pendentive course is the widest of them.
static func dome_mass_radius(spec: ChurchSpec) -> float:
	return spec.dome_radius + 0.3 if spec.dome else 0.0


## Widest the whole dome assembly reaches in plan, shell included. An onion
## bulges past its springing radius, so the drum alone does not bound it. This
## is what the sheet must be scaled to; the masses use dome_mass_radius.
static func dome_plan_radius(spec: ChurchSpec) -> float:
	if not spec.dome:
		return 0.0
	var shell: float = spec.dome_radius * (1.16 if spec.dome_shape == &"onion" else 1.0)
	return maxf(shell, dome_mass_radius(spec))


## Drum height needed for the dome to clear the roofs around it.
##
## A gable over a wide nave can out-rise a dome entirely -- at Hagia Sophia's
## proportions the ridge reached 62 m against a 61 m dome, so the roof swallowed
## it. The dome is the point of these buildings, so the drum grows until the
## dome sits clear.
static func min_drum_height(spec: ChurchSpec) -> float:
	if not spec.dome:
		return 0.0
	var clearance: float = nave_ridge_height(spec) + spec.height * 0.12
	var without_drum: float = dome_base_height(spec) + PENDENTIVE_H + dome_shell_rise(spec)
	return maxf(clearance - without_drum, spec.dome_radius * 0.25)


## Rise of the dome shell above the top of its drum.
static func dome_shell_rise(spec: ChurchSpec) -> float:
	match spec.dome_shape:
		&"onion":
			return spec.dome_radius * 1.55
		&"octagonal":
			return spec.dome_radius * 1.05
	return spec.dome_radius            # hemisphere


static func dome_apex_height(spec: ChurchSpec) -> float:
	var top: float = dome_base_height(spec) + PENDENTIVE_H + spec.dome_drum_height \
		+ dome_shell_rise(spec)
	if spec.dome_lantern:
		top += spec.dome_radius * (LANTERN_RATIO + LANTERN_CAP_RATIO)
	return top


## Buttressing half-domes sit east and west of the main dome, at its springing.
static func half_dome_radius(spec: ChurchSpec) -> float:
	return spec.dome_radius * 0.92


# --------------------------------------------------- alcoves and ambulatory

## The ambulatory wraps the apse; chapels open off it when present.
static func ambulatory_radius(spec: ChurchSpec) -> float:
	return spec.apse_radius * (1.0 + AMBULATORY_W)


static func ambulatory_aabb(spec: ChurchSpec) -> AABB:
	var r: float = ambulatory_radius(spec)
	return AABB(Vector3(-r, 0.0, apse_springing_z(spec)),
		Vector3(r * 2.0, spec.height * AISLE_HEIGHT_RATIO, r))


## Where the ring of chapels is centred.
##   chevet  -- on the apse, so the alcoves fan across its hemicycle
##   cluster -- on the crossing, so they ring the central mass in a star,
##              which is how St Basil's nine chapels are arranged
static func chapel_ring_center_z(spec: ChurchSpec) -> float:
	if spec.chapel_arrangement == &"cluster":
		return crossing_center_z(spec)
	return apse_springing_z(spec)


## Distance from the ring centre to chapel `i`'s flat face.
##
## A chevet ring sits on a circle, so the reach is constant. A cluster hugs the
## nave BLOCK, so the reach has to follow that rectangle's edge along each
## chapel's own bearing. Treating the block as a width-square instead left the
## due-east alcove hanging in space past the nave's east wall.
static func chapel_reach_at(spec: ChurchSpec, i: int) -> float:
	if spec.chapel_arrangement != &"cluster":
		var host: float = ambulatory_radius(spec) if spec.ambulatory else spec.apse_radius
		return host - CHAPEL_LAP
	var a: float = chapel_angle(spec, i)
	var sx: float = sin(a)
	var sz: float = cos(a)
	var cz: float = chapel_ring_center_z(spec)
	var best: float = INF
	if absf(sx) > 0.001:
		best = minf(best, (spec.width / 2.0) / absf(sx))
	if absf(sz) > 0.001:
		var wall: float = (spec.length / 2.0) if sz > 0.0 else -(spec.length / 2.0)
		best = minf(best, (wall - cz) / sz)
	if not is_finite(best) or best <= 0.0:
		best = spec.width / 2.0
	return maxf(best - CHAPEL_LAP, 0.1)


## Nominal reach, used where a single representative value is wanted.
static func chapel_reach(spec: ChurchSpec) -> float:
	if spec.chapel_arrangement == &"cluster":
		# the tightest bearing governs how big an alcove may be
		var tightest: float = INF
		for i in range(maxi(spec.radiating_chapels, 1)):
			tightest = minf(tightest, chapel_reach_at(spec, i))
		return tightest if is_finite(tightest) else spec.width / 2.0
	var host: float = ambulatory_radius(spec) if spec.ambulatory else spec.apse_radius
	return host - CHAPEL_LAP


## Widest angle a chevet chapel can sit at and still clear the nave's east wall.
##
## A chapel at angle `a` reaches back to z = springing + cos(a) * reach - r.
## That must stay east of the nave wall, so cos(a) >= (r + APSE_EMBED) / reach.
## Deriving it rather than hard-coding a fan keeps chapels clear at every size:
## a small church has proportionally less hemicycle to spread them over.
static func chapel_max_angle(spec: ChurchSpec) -> float:
	if spec.chapel_arrangement == &"cluster":
		return PI                       # a cluster rings the whole block
	var reach: float = chapel_reach(spec)
	if reach <= 0.0:
		return 0.0
	var lim: float = (spec.chapel_radius + APSE_EMBED) / reach
	if lim >= 1.0:
		return 0.0                      # no room to fan at all: stack them east
	return clampf(acos(lim), 0.0, 1.22)


## How much of the circle a clustered ring may occupy.
##
## A full ring would run straight through whatever stands on the west front, so
## when there is a tower or a narthex the ring gives way to it and fans across
## the eastern three quarters instead.
static func cluster_span(spec: ChurchSpec) -> float:
	if spec.west_towers > 0 or spec.narthex:
		return PI * 1.5
	return TAU


## Angular step between neighbouring chapels.
static func chapel_step(spec: ChurchSpec, count: int) -> float:
	if count <= 1:
		return PI
	if spec.chapel_arrangement == &"cluster":
		var span: float = cluster_span(spec)
		if span >= TAU - 0.001:
			return TAU / float(count)
		return span / float(count - 1)
	return chapel_max_angle(spec) * 2.0 / float(count - 1)


## Largest chapel radius that leaves adjacent alcoves clear of one another.
## Neighbours sit one angular step apart, so the chord between their centres is
## 2 * reach * sin(step / 2); each needs half of that. Without this the ring
## simply overlaps itself as the count rises.
static func max_chapel_radius(spec: ChurchSpec, count: int) -> float:
	var reach: float = chapel_reach(spec)
	if count <= 1 or reach <= 0.0:
		return reach * 0.42
	var step: float = chapel_step(spec, count)
	return minf(reach * 0.6, reach * sin(step / 2.0) * 0.94)


## Angle of chapel `i`, measured from due east (+Z).
static func chapel_angle(spec: ChurchSpec, i: int) -> float:
	var n: int = maxi(spec.radiating_chapels, 1)
	if spec.chapel_arrangement == &"cluster":
		var span: float = cluster_span(spec)
		if span >= TAU - 0.001:
			return TAU * float(i) / float(n)
		if n == 1:
			return 0.0
		return lerpf(-span / 2.0, span / 2.0, float(i) / float(n - 1))
	if n == 1:
		return 0.0
	var lim: float = chapel_max_angle(spec)
	return lerpf(-lim, lim, float(i) / float(n - 1))


## Flat-face centre of chapel `i`. An alcove is a half-drum whose flat face
## sits ON its host wall, buried CHAPEL_LAP deep so it reads as opening off it
## rather than stuck to it.
static func chapel_center(spec: ChurchSpec, i: int) -> Vector3:
	var a: float = chapel_angle(spec, i)
	var reach: float = chapel_reach_at(spec, i)
	return Vector3(sin(a) * reach, 0.0, chapel_ring_center_z(spec) + cos(a) * reach)


## Sweep of the alcove in revolve() angle space, which measures from +X.
## A chapel facing model angle `a` (from +Z) spans [-a, -a + PI].
static func chapel_arc_start(spec: ChurchSpec, i: int) -> float:
	return -chapel_angle(spec, i)


## True AABB of the half-drum, sampled around its arc. A full 2r box would
## overstate it inward and read as colliding with the mass it opens off.
static func chapel_aabb(spec: ChurchSpec, i: int) -> AABB:
	var c: Vector3 = chapel_center(spec, i)
	var r: float = spec.chapel_radius
	var start: float = chapel_arc_start(spec, i)
	var lo := Vector2(c.x, c.z)
	var hi := Vector2(c.x, c.z)
	var samples: int = 12
	for k in range(samples + 1):
		var th: float = start + PI * float(k) / samples
		var px: float = c.x + cos(th) * r
		var pz: float = c.z + sin(th) * r
		lo.x = minf(lo.x, px); lo.y = minf(lo.y, pz)
		hi.x = maxf(hi.x, px); hi.y = maxf(hi.y, pz)
	return AABB(Vector3(lo.x, 0.0, lo.y),
		Vector3(hi.x - lo.x, spec.height * 0.42, hi.y - lo.y))


static func narthex_depth(spec: ChurchSpec) -> float:
	return spec.width * NARTHEX_DEPTH


## Vestibule across the west front, lapping the nave so it reads as attached.
static func narthex_aabb(spec: ChurchSpec) -> AABB:
	var d: float = narthex_depth(spec)
	var z1: float = -spec.length / 2.0 + TOWER_EMBED
	return AABB(Vector3(-spec.width / 2.0, 0.0, z1 - d),
		Vector3(spec.width, spec.height * 0.6, d))


# ------------------------------------------------------ flying buttresses

## Flying buttresses have to be sized to the building they brace. Fixed
## metre values made them read as fence posts against a 33 m cathedral wall.
static func flyer_pier_width(spec: ChurchSpec) -> float:
	return clampf(spec.width * 0.17, FLYER_PIER_W, 4.5)


static func flyer_arch_thickness(spec: ChurchSpec) -> float:
	return clampf(spec.height * 0.05, 0.35, 2.2)


## Pinnacles, finials and the like scale off the wall height for the same reason.
static func ornament_scale(spec: ChurchSpec) -> float:
	return clampf(spec.height * 0.075, 1.0, 4.5)


## X offset of the flyer pier: clear of the outermost aisle wall.
static func flyer_pier_x(spec: ChurchSpec, side: float) -> float:
	var outer: float = spec.width / 2.0
	if spec.aisles > 0:
		outer = aisle_outer_x(spec)
	return side * (outer + FLYER_PIER_GAP + flyer_pier_width(spec) / 2.0)


static func flyer_pier_height(spec: ChurchSpec) -> float:
	return spec.height * 0.62


## Where a flyer meets the nave wall: high on the clerestory, under the eaves.
static func flyer_spring_height(spec: ChurchSpec) -> float:
	return spec.height * 0.78


## Bay range the flyer PIERS occupy, inset so a pier never overhangs the bay
## it braces and never crowds the apse or ambulatory at the east end.
static func flyer_span(spec: ChurchSpec) -> Vector2:
	var zr: Vector2 = aisle_z_range(spec) if spec.aisles > 0 else Vector2(
		-spec.length / 2.0, spec.length / 2.0)
	if spec.apse:
		var east: float = apse_springing_z(spec)
		if spec.ambulatory:
			east -= ambulatory_radius(spec) - spec.apse_radius
		zr.y = minf(zr.y, east)
	var inset: float = flyer_pier_width(spec) / 2.0 + 0.4
	return Vector2(zr.x + inset, zr.y - inset)


## How many flyers actually fit along that span without their piers touching.
## The pier grew with the building, so a fixed count started colliding.
static func flyer_count(spec: ChurchSpec) -> int:
	var zr: Vector2 = flyer_span(spec)
	var usable: float = maxf(zr.y - zr.x, 0.0)
	var pitch: float = flyer_pier_width(spec) + 0.6
	var fits: int = int(usable / pitch) + 1
	return clampi(mini(spec.buttress_count_per_side, fits), 1, 12)


## Vertical drop to the next tier down.
##
## Stacked flyers must clear one another, and an arch is as deep as its span
## makes it: the bow plus the thickness of the ribbon at both ends. Deriving
## the drop from that is what keeps two-tier buttresses from merging.
static func flyer_tier_drop(spec: ChurchSpec) -> float:
	var reach: float = absf(flyer_pier_x(spec, 1.0)) - spec.width / 2.0
	var arch_h: float = absf(flyer_spring_height(spec) - flyer_pier_height(spec)) \
		+ reach * 0.16 + flyer_arch_thickness(spec) * 2.0
	return maxf(spec.height * FLYER_TIER_DROP, arch_h + 0.6)


static func flyer_z(spec: ChurchSpec, i: int) -> float:
	var n: int = flyer_count(spec)
	var zr: Vector2 = flyer_span(spec)
	if n <= 1:
		return (zr.x + zr.y) / 2.0
	return lerpf(zr.x, zr.y, float(i) / float(n - 1))


# ------------------------------------------------------------- envelope

## Ridge height of the nave roof, which caps the nave walls.
static func nave_ridge_height(spec: ChurchSpec) -> float:
	return spec.height + spec.width * spec.roof_pitch + RIDGE_CAP


## Tallest point of the building: whichever of nave, transept, tower or apse
## reaches highest. This is what the elevation's height dimension reports, so
## it must describe the mesh rather than approximate it.
static func total_height(spec: ChurchSpec) -> float:
	var top: float = nave_ridge_height(spec)
	if spec.transept:
		top = maxf(top, spec.height + spec.width * spec.roof_pitch * 0.9 + RIDGE_CAP)
	if spec.tower:
		top = maxf(top, spec.tower_height + tower_roof_rise(spec))
	if spec.apse:
		top = maxf(top, spec.height * APSE_HEIGHT_RATIO
			+ spec.apse_radius * APSE_CONE_RATIO)
	if spec.crossing_tower:
		top = maxf(top, spec.crossing_tower_height + spec.width * 0.42)
	if spec.dome:
		top = maxf(top, dome_apex_height(spec))
	return top


## How far a buttress projects beyond the face it braces.
static func buttress_projection(spec: ChurchSpec) -> float:
	return spec.buttress_depth - BUTTRESS_INSET if spec.buttresses else 0.0


## Extent along Z of the STRUCTURAL MASSES alone (nave, tower, apse, transept,
## aisles) -- what ChurchBuilder.mass_log should add up to.
static func mass_length_extent(spec: ChurchSpec) -> Vector2:
	var z0: float = -spec.length / 2.0
	var z1: float = spec.length / 2.0
	if spec.tower:
		z0 = minf(z0, tower_aabb(spec, 0.0).position.z)
	if spec.narthex:
		z0 = minf(z0, narthex_aabb(spec).position.z)
	if spec.apse:
		var a: AABB = apse_aabb(spec)
		z1 = maxf(z1, a.position.z + a.size.z)
	if spec.ambulatory:
		var am: AABB = ambulatory_aabb(spec)
		z1 = maxf(z1, am.position.z + am.size.z)
	for i in range(spec.radiating_chapels):
		var c: AABB = chapel_aabb(spec, i)
		z1 = maxf(z1, c.position.z + c.size.z)
		z0 = minf(z0, c.position.z)
	if spec.flying_buttresses:
		var fs: Vector2 = flyer_span(spec)
		var half: float = flyer_pier_width(spec) / 2.0
		z0 = minf(z0, fs.x - half)
		z1 = maxf(z1, fs.y + half)
	if spec.dome:
		var dz: float = crossing_center_z(spec)
		var dr: float = dome_mass_radius(spec)
		z1 = maxf(z1, dz + dr)
		z0 = minf(z0, dz - dr)
	if spec.crossing_tower:
		var ct: AABB = crossing_tower_aabb(spec)
		z1 = maxf(z1, ct.position.z + ct.size.z)
		z0 = minf(z0, ct.position.z)
	if spec.dome and spec.half_domes:
		z1 = maxf(z1, crossing_center_z(spec) + half_dome_radius(spec))
		z0 = minf(z0, crossing_center_z(spec) - half_dome_radius(spec))
	return Vector2(z0, z1)


## Full drawn extent along Z, including bracing that projects past the masses.
## This is what the sheet must be scaled to so nothing is clipped.
static func length_extent(spec: ChurchSpec) -> Vector2:
	var e: Vector2 = mass_length_extent(spec)
	if spec.tower:
		e.x -= buttress_projection(spec)
	if spec.dome:
		var dz: float = crossing_center_z(spec)
		var dr: float = dome_plan_radius(spec)
		e.x = minf(e.x, dz - dr)
		e.y = maxf(e.y, dz + dr)
	return e


## Full extent across X, including aisles, transept arms and buttresses.
static func width_extent(spec: ChurchSpec) -> float:
	var w: float = spec.width
	var bp: float = buttress_projection(spec)
	if spec.aisles > 0:
		w = maxf(w, aisle_outer_x(spec) * 2.0)
	if spec.transept:
		w = maxf(w, spec.transept_len)
	if spec.tower:
		var tx: float = absf(tower_center_x(spec, 1.0)) + spec.tower_width / 2.0
		w = maxf(w, tx * 2.0 + bp * 2.0)
	if spec.buttresses:
		w = maxf(w, spec.width + bp * 2.0)
	if spec.flying_buttresses:
		w = maxf(w, (absf(flyer_pier_x(spec, 1.0)) + flyer_pier_width(spec) / 2.0) * 2.0)
	if spec.ambulatory:
		w = maxf(w, ambulatory_radius(spec) * 2.0)
	for i in range(spec.radiating_chapels):
		var c: AABB = chapel_aabb(spec, i)
		w = maxf(w, absf(c.position.x) * 2.0)
		w = maxf(w, absf(c.position.x + c.size.x) * 2.0)
	if spec.dome:
		w = maxf(w, dome_plan_radius(spec) * 2.0)
	return w
