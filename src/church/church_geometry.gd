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
const OCTAGONAL_RADIUS_FACTOR := 1.06  # shared circumradius of drum and shell rim
const PENDENTIVE_H := 0.5        # square-to-round transition under the drum
const LANTERN_CAP_RATIO := 0.22  # the little roof capping a lantern, x radius
const LANTERN_RATIO := 0.28      # lantern height, x dome radius
const NARTHEX_DEPTH := 0.35      # narthex depth along Z, x nave width

# ---- hero landmarks (spec.hero) ----
const OCT_EMBED := 1.5           # Florence: the octagon laps the nave's east end
const OCT_BLOCK_FACTOR := 1.12   # Florence: block circumradius, x dome radius; the drum sits back
const FLORENCE_DOME_RATIO := 0.14   # dome radius, x overall length (45 m of 153)
const FLORENCE_BAY := 1.45       # bay pitch, x nave width: four huge bays
const TRIBUNE_HEIGHT_RATIO := 0.5
const TENT_RISE_RATIO := 2.3     # St Basil: tent rise, x core radius
const TENT_CAP_RATIO := 0.95     # the little drum and onion on the tent's tip
const PODIUM_RATIO := 0.045      # St Basil: podium height, x core height
const PODIUM_MARGIN := 2.4       # podium reach beyond the outermost chapel
const FLOOR_T := 0.05            # paved floor slab, under the rooms a person walks
const FLOOR_LIFT := 0.001        # its top, just proud of a village's ground at y=0
const BASIL_PATTERN := [0.34, 0.46, 0.38, 0.52, 0.42, 0.48, 0.36, 0.54]
const BASIL_DRUM_PATTERN := [0.9, 1.25, 1.0, 1.35, 1.1, 0.85, 1.3, 1.05]
const HAGIA_BEARING_RATIO := 0.74   # bearing block height, x dome radius
const HAGIA_PIER_RATIO := 0.30      # corner pier plan size, x dome radius


# ------------------------------------------------------------------ nave

static func nave_aabb(spec: ChurchSpec) -> AABB:
	return AABB(Vector3(-spec.width / 2.0, 0.0, -spec.length / 2.0),
		Vector3(spec.width, spec.height, spec.length))


static func nave_window_count(spec: ChurchSpec) -> int:
	return int(spec.length / NAVE_WINDOW_BAY)


static func door_height(spec: ChurchSpec) -> float:
	return minf(spec.height * DOOR_H_RATIO, DOOR_H_CAP)


## The west doorways across the facade: {x, width, style} per leaf. The
## builder cuts them and the furnisher keeps their way clear; one table so the
## two cannot disagree.
static func west_door_layout(spec: ChurchSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match spec.door_style:
		&"twin":
			for x in [-0.8, 0.8]:
				out.append({"x": x, "width": 0.85, "style": &"round"})
		&"portal":
			out.append({"x": 0.0, "width": spec.width * 0.34, "style": &"pointed"})
		_:
			out.append({"x": 0.0, "width": 1.4, "style": &"round"})
	return out


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
	elif octagon_crossing(spec):
		z1 = octagon_aisle_end_z(spec)
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


static func has_clerestory(spec: ChurchSpec) -> bool:
	return spec.aisles > 0 and (spec.clerestory or spec.flying_buttresses)


## Keep the upper nave wall available for glazing. This same spring line is
## consumed by the roof emitter and by the window course.
static func aisle_roof_high(spec: ChurchSpec, ring := 0) -> float:
	var high: float = aisle_height(spec, ring) + spec.aisle_width * 0.8
	if ring > 0:
		return minf(high, aisle_height(spec, ring - 1) - RoofShape.DEPTH)
	var limit: float = spec.height * 0.72 if has_clerestory(spec) else spec.height - RoofShape.DEPTH
	return minf(high, limit)


## One opening in each structural bay, BETWEEN flyers rather than under an
## arch landing. Rectangle height excludes the pointed/round head.
static func clerestory_windows(spec: ChurchSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_clerestory(spec):
		return out
	if hero_bays(spec):
		return _hero_clerestory(spec)
	var centers: Array[float] = []
	var span: Vector2 = aisle_z_range(spec)
	var pitch: float
	if spec.flying_buttresses and flyer_count(spec) >= 2:
		pitch = flyer_z(spec, 1) - flyer_z(spec, 0)
		for i in range(flyer_count(spec) - 1):
			centers.append((flyer_z(spec, i) + flyer_z(spec, i + 1)) * 0.5)
	else:
		var count := maxi(1, int((span.y - span.x) / 3.5))
		pitch = (span.y - span.x) / float(count + 1)
		for i in range(count):
			centers.append(span.x + pitch * float(i + 1))
	var sill: float = aisle_roof_high(spec) + RoofShape.DEPTH + 0.18
	var head: float = spec.height - 0.22
	var band: float = head - sill
	var width: float = minf(pitch * 0.48, band * 0.7)
	var crown: float = width * (0.35 if spec.window_style == &"pointed" else 0.25)
	var height: float = band - crown
	if width < 0.2 or height < 0.25:
		return out
	for z in centers:
		for side in [-1.0, 1.0]:
			out.append({"pos": Vector3(side * (spec.width / 2.0 + OPENING_EPS),
				sill + height / 2.0, z), "face": side * PI / 2.0,
				"width": width, "height": height, "sill": sill, "head": head})
	return out


static func aisle_aabb(spec: ChurchSpec, side: float, ring := 0) -> AABB:
	var zr: Vector2 = aisle_z_range(spec)
	var aw: float = spec.aisle_width
	return AABB(Vector3(aisle_center_x(spec, side, ring) - aw / 2.0, 0.0, zr.x),
		Vector3(aw, aisle_height(spec, ring), zr.y - zr.x))


# ------------------------------------------------- crossing tower and dome

## The crossing: where nave and transept meet, and what a dome or lantern
## tower is centred on. Without a transept it falls at the nave centre.
static func crossing_center_z(spec: ChurchSpec) -> float:
	if octagon_crossing(spec):
		return octagon_center_z(spec)
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


## A hero Byzantine dome needs enough vertical bearing depth for the
## square-to-round curve to read at building scale. Other dome families keep
## the compact course, including Florence's deliberate octagonal support.
static func pendentive_height(spec: ChurchSpec) -> float:
	if octagon_crossing(spec):
		return spec.dome_radius * 0.06      # the chamfered ledge between block and drum
	if hagia_bearing(spec):
		return spec.dome_radius * HAGIA_BEARING_RATIO
	if spec.style == &"byzantine" and spec.dome_shape == &"hemisphere":
		return maxf(PENDENTIVE_H, spec.dome_radius * 0.18)
	return PENDENTIVE_H


## The pendentive course: the square-to-round transition that carries the drum
## on the walls below. It is a real structural member, so it is a mass of its
## own -- without it the drum reads as hovering half a metre above the nave.
static func pendentive_aabb(spec: ChurchSpec) -> AABB:
	if octagon_crossing(spec):
		var a: float = octagon_apothem(spec)
		return AABB(Vector3(-a, dome_base_height(spec), crossing_center_z(spec) - a),
			Vector3(a * 2.0, pendentive_height(spec), a * 2.0))
	var r: float = spec.dome_radius + 0.3
	return AABB(Vector3(-r, dome_base_height(spec), crossing_center_z(spec) - r),
		Vector3(r * 2.0, pendentive_height(spec), r * 2.0))


static func dome_drum_aabb(spec: ChurchSpec) -> AABB:
	var r: float = spec.dome_radius
	return AABB(Vector3(-r, dome_base_height(spec) + pendentive_height(spec),
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
	var without_drum: float = dome_base_height(spec) + pendentive_height(spec) + dome_shell_rise(spec)
	return maxf(clearance - without_drum, spec.dome_radius * 0.25)


## Rise of the dome shell above the top of its drum.
static func dome_shell_rise(spec: ChurchSpec) -> float:
	if basil_core(spec):
		return tent_rise(spec)
	match spec.dome_shape:
		&"onion":
			return spec.dome_radius * 1.55
		&"octagonal":
			return spec.dome_radius * 1.05
	return spec.dome_radius            # hemisphere


static func dome_apex_height(spec: ChurchSpec) -> float:
	var top: float = dome_base_height(spec) + pendentive_height(spec) + spec.dome_drum_height \
		+ dome_shell_rise(spec)
	if spec.dome_lantern:
		top += lantern_height(spec) + lantern_cap_height(spec)
	if basil_core(spec):
		top += tent_cap_height(spec)
	return top


## The lantern is part of the silhouette, so it is sized by what it has to
## stand against: a slender 9 m lantern disappears on Florence's 45 m dome.
static func lantern_height(spec: ChurchSpec) -> float:
	return spec.dome_radius * (0.42 if octagon_crossing(spec) else LANTERN_RATIO)


static func lantern_cap_height(spec: ChurchSpec) -> float:
	return spec.dome_radius * (0.28 if octagon_crossing(spec) else LANTERN_CAP_RATIO)


static func lantern_radius(spec: ChurchSpec) -> float:
	return spec.dome_radius * (0.22 if octagon_crossing(spec) else 0.16)


## Width of the little roof that caps the lantern.
static func lantern_cap_width(spec: ChurchSpec) -> float:
	return spec.dome_radius * (0.46 if octagon_crossing(spec) else 0.34)


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
		Vector3(hi.x - lo.x, chapel_tower_height(spec, i), hi.y - lo.y))


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
	return clampf(spec.height * 0.065, 0.45, 2.6)


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


## Z centre of a nave buttress. Shared by the shell and blueprint so the
## elevation marks the same bays that carry the emitted supports.
## Where the nave's side windows stand along Z, both walls alike. With
## buttresses each sits in the middle of a bay between two of them, where a
## mason would put it; spaced on their own rhythm down the whole length, the
## windows met the buttresses and showed slivers of glass either side of one
## (walk-QA, Abbey Ivo pin 1). A bay too short for a window keeps none.
static func nave_window_zs(spec: ChurchSpec) -> Array[float]:
	var out: Array[float] = []
	if not spec.buttresses or spec.buttress_count_per_side < 2:
		var count: int = int(spec.length / NAVE_WINDOW_BAY)
		for i in range(count):
			out.append(-spec.length * 0.5 + spec.length / float(count + 1) * (i + 1))
		return out
	var n: int = spec.buttress_count_per_side
	# a buttress is BUTTRESS_FACE wide along the wall; leave a hand either side
	var need: float = spec.window_w + BUTTRESS_FACE + 0.4
	for i in range(n - 1):
		var a: float = nave_buttress_z(spec, i, n)
		var b: float = nave_buttress_z(spec, i + 1, n)
		if b - a >= need:
			out.append((a + b) * 0.5)
	return out


## A nave buttress's width along the wall (ChurchBuilder emits it at this).
const BUTTRESS_FACE := 0.5


static func nave_buttress_z(spec: ChurchSpec, i: int, count := -1) -> float:
	var n: int = count if count > 0 else spec.buttress_count_per_side
	var z0: float = -spec.length / 2.0 + 0.8
	if spec.tower:
		z0 = -spec.length / 2.0 + TOWER_EMBED + spec.tower_width + 0.4
	var z1: float = spec.length / 2.0 - 0.8
	if spec.transept:
		z1 = transept_front_z(spec) - 0.6
	elif octagon_crossing(spec):
		z1 = octagon_west_z(spec) - 0.8
	var span: float = maxf(z1 - z0, 2.0)
	return z0 + span / float(maxi(n - 1, 1)) * i



# ------------------------------------------------------- hero landmarks
#
# Everything below is gated on `spec.hero`, which only
# ChurchGenerator.apply_landmark() sets, so no randomly generated church
# changes. Builder, blueprint and the QA suites all read these functions.

## Florence: the dome sits over an octagonal crossing as wide as the dome
## itself, with three tribunes round it and the nave running in from the west.
static func octagon_crossing(spec: ChurchSpec) -> bool:
	return spec.hero == &"florence" and spec.dome and spec.dome_shape == &"octagonal"


## The block is wider than the drum it carries (1.12 against 1.06 of the dome
## radius), so the drum stands back from it on a chamfered ledge.
static func octagon_circumradius(spec: ChurchSpec) -> float:
	return spec.dome_radius * OCT_BLOCK_FACTOR


## Flat faces look along the axes; the drum and shell share this phase.
static func octagon_apothem(spec: ChurchSpec) -> float:
	return octagon_circumradius(spec) * cos(PI / 8.0)


## West face of the octagon, lapping the nave's east end by OCT_EMBED.
static func octagon_west_z(spec: ChurchSpec) -> float:
	return spec.length / 2.0 - OCT_EMBED


static func octagon_center_z(spec: ChurchSpec) -> float:
	return octagon_west_z(spec) + octagon_apothem(spec)


## The octagonal block carries the walls up to the drum; the pendentive course
## is the cornice ring on top of it.
static func octagon_aabb(spec: ChurchSpec) -> AABB:
	var a: float = octagon_apothem(spec)
	return AABB(Vector3(-a, 0.0, octagon_center_z(spec) - a),
		Vector3(a * 2.0, dome_base_height(spec), a * 2.0))


## Where an aisle must stop to meet the octagon's south-west (or north-west)
## face. That face runs at 45 degrees, so the further out the aisle's outer
## wall, the further east it can run before it reaches the masonry.
static func octagon_aisle_end_z(spec: ChurchSpec) -> float:
	var half_face: float = octagon_apothem(spec) * tan(PI / 8.0)
	var outer: float = aisle_outer_x(spec)
	return octagon_west_z(spec) + maxf(outer - half_face, 0.0) + 0.3


static func tribune_count(spec: ChurchSpec) -> int:
	return 3 if octagon_crossing(spec) else 0


## Each tribune is a half-drum as wide as an octagon face.
static func tribune_radius(spec: ChurchSpec) -> float:
	return octagon_apothem(spec) * tan(PI / 8.0)


static func tribune_height(spec: ChurchSpec) -> float:
	return spec.height * TRIBUNE_HEIGHT_RATIO


## Model bearing of tribune `i` from +Z (east) toward +X: the east apse, then
## the south and north arms.
static func tribune_angle(_spec: ChurchSpec, i: int) -> float:
	return [0.0, PI / 2.0, -PI / 2.0][i]


static func tribune_center(spec: ChurchSpec, i: int) -> Vector3:
	var a: float = tribune_angle(spec, i)
	var reach: float = octagon_apothem(spec) - CHAPEL_LAP
	return Vector3(sin(a) * reach, 0.0, octagon_center_z(spec) + cos(a) * reach)


static func tribune_arc_start(spec: ChurchSpec, i: int) -> float:
	return -tribune_angle(spec, i)


static func tribune_aabb(spec: ChurchSpec, i: int) -> AABB:
	return half_drum_aabb(tribune_center(spec, i), tribune_radius(spec),
		tribune_arc_start(spec, i), tribune_height(spec))


## True AABB of a half-drum alcove, sampled around its arc.
static func half_drum_aabb(c: Vector3, r: float, start: float, height: float) -> AABB:
	var lo := Vector2(c.x, c.z)
	var hi := Vector2(c.x, c.z)
	for k in range(13):
		var th: float = start + PI * float(k) / 12.0
		var px: float = c.x + cos(th) * r
		var pz: float = c.z + sin(th) * r
		lo.x = minf(lo.x, px); lo.y = minf(lo.y, pz)
		hi.x = maxf(hi.x, px); hi.y = maxf(hi.y, pz)
	return AABB(Vector3(lo.x, 0.0, lo.y), Vector3(hi.x - lo.x, height, hi.y - lo.y))


## Florence and Hagia Sophia are laid out in bays, not as a picket line: the
## nave wall is divided at its pilasters, and each bay carries its own aisle
## window and clerestory light(s).
static func hero_bays(spec: ChurchSpec) -> bool:
	return octagon_crossing(spec) or (spec.hero == &"hagia" and spec.dome)


## Four huge bays at Florence; about a third of a nave width each at Hagia.
static func hero_bay_count(spec: ChurchSpec) -> int:
	if octagon_crossing(spec):
		var z0: float = -spec.length / 2.0 + 0.8
		var z1: float = octagon_west_z(spec) - 0.8
		return maxi(2, roundi((z1 - z0) / (spec.width * FLORENCE_BAY)))
	return maxi(3, roundi((spec.length - 1.6) / (spec.width * 0.30)))


## Bay edges along the nave: pilasters stand on them.
static func hero_bay_edges(spec: ChurchSpec) -> Array[float]:
	var n: int = hero_bay_count(spec) + 1
	var edges: Array[float] = []
	for i in range(n):
		edges.append(nave_buttress_z(spec, i, n))
	return edges


## Aisle windows: one tall light in the middle of each bay.
static func hero_aisle_windows(spec: ChurchSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if spec.aisles <= 0:
		return out
	var ring: int = spec.aisles - 1
	var ah: float = aisle_height(spec, ring)
	var edges: Array[float] = hero_bay_edges(spec)
	var florence: bool = octagon_crossing(spec)
	for i in range(edges.size() - 1):
		var pitch: float = edges[i + 1] - edges[i]
		out.append({"z": (edges[i] + edges[i + 1]) * 0.5,
			"width": minf(pitch * (0.11 if florence else 0.26), 2.6 if florence else 3.2),
			"height": ah * (0.46 if florence else 0.55), "y": ah * 0.5})
	return out


## The clerestory in bays. Florence gets a pair of modest round-headed lights in
## each; Hagia Sophia one tall arched light.
static func _hero_clerestory(spec: ChurchSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sill: float = aisle_roof_high(spec) + RoofShape.DEPTH + 0.18
	var head: float = spec.height - 0.22
	var band: float = head - sill
	var edges: Array[float] = hero_bay_edges(spec)
	var florence: bool = octagon_crossing(spec)
	var offsets: Array = [-0.2, 0.2] if florence else [0.0]
	for i in range(edges.size() - 1):
		var pitch: float = edges[i + 1] - edges[i]
		var width: float = minf(pitch * (0.14 if florence else 0.34),
			band * (0.42 if florence else 0.5))
		var crown: float = width * 0.25
		var height: float = minf(width * 1.25 if florence else band * 0.7,
			band * 0.62 - crown if florence else band - crown - 0.4)
		if width < 0.2 or height < 0.25:
			return []
		var mid: float = sill + band * 0.5
		for dz in offsets:
			for side in [-1.0, 1.0]:
				out.append({"pos": Vector3(side * (spec.width / 2.0 + OPENING_EPS), mid,
					(edges[i] + edges[i + 1]) * 0.5 + float(dz) * pitch),
					"face": side * PI / 2.0, "width": width, "height": height,
					"sill": mid - height / 2.0, "head": head})
	return out


## St Basil: a tented core ringed by onion-domed chapels on a podium.
static func basil_core(spec: ChurchSpec) -> bool:
	return spec.hero == &"basil" and spec.dome


static func tent_rise(spec: ChurchSpec) -> float:
	return spec.dome_radius * TENT_RISE_RATIO


static func tent_cap_height(spec: ChurchSpec) -> float:
	return spec.dome_radius * TENT_CAP_RATIO


static func podium_height(spec: ChurchSpec) -> float:
	return maxf(spec.height * PODIUM_RATIO, 0.6) if basil_core(spec) else 0.0


## The paved floor of the rooms a person walks: nave, aisles, transept, the
## west towers' ground storeys and the narthex, as DISJOINT plates (the rooms
## overlap where they lap each other; overlapping coplanar tops would fight).
##
## Every one of those masses is a closed shell whose bottom faces DOWN at y=0,
## so from inside there was no floor at all: the eye saw the ground through
## it, and one-sided trimesh collision let the walker's capsule, standing on
## the ground 2 cm lower, poke its foot through those undersides and jam on
## their edge in the doorway (WALK-QA, 6 Oct, Abbey Ivo pin 2 "stuck in
## door"). A podium church stands on its podium and needs none.
static func floor_rects(spec: ChurchSpec) -> Array[Rect2]:
	if podium_height(spec) > 0.0:
		return []
	var rooms: Array[Rect2] = [_plan_rect(nave_aabb(spec))]
	for ring in range(spec.aisles):
		for side in [-1.0, 1.0]:
			rooms.append(_plan_rect(aisle_aabb(spec, side, ring)))
	if spec.transept:
		rooms.append(_plan_rect(transept_aabb(spec)))
	for side in west_tower_sides(spec):
		rooms.append(_plan_rect(tower_aabb(spec, side)))
	if spec.narthex:
		rooms.append(_plan_rect(narthex_aabb(spec)))
	return disjoint_rects(rooms)


static func _plan_rect(a: AABB) -> Rect2:
	return Rect2(a.position.x, a.position.z, a.size.x, a.size.z)


## The union of `rects` as non-overlapping rectangles: cut the plane on every
## rect edge, keep the covered cells, and merge each z strip's runs in x.
static func disjoint_rects(rects: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for r in rects:
		if r.size.x <= 0.01 or r.size.y <= 0.01:
			continue
		for v in [r.position.x, r.end.x]:
			if not xs.any(func(o: float) -> bool: return absf(o - v) < 0.001):
				xs.append(v)
		for v in [r.position.y, r.end.y]:
			if not zs.any(func(o: float) -> bool: return absf(o - v) < 0.001):
				zs.append(v)
	xs.sort()
	zs.sort()
	var out: Array[Rect2] = []
	for j in range(zs.size() - 1):
		var run_x0 := INF
		for i in range(xs.size()):
			var covered := false
			if i < xs.size() - 1:
				var c := Vector2((xs[i] + xs[i + 1]) / 2.0, (zs[j] + zs[j + 1]) / 2.0)
				for r in rects:
					if r.has_point(c):
						covered = true
						break
			if covered and run_x0 == INF:
				run_x0 = xs[i]
			elif not covered and run_x0 != INF:
				out.append(Rect2(run_x0, zs[j], xs[i] - run_x0, zs[j + 1] - zs[j]))
				run_x0 = INF
	return out


## The podium reaches PODIUM_MARGIN beyond everything that stands on it.
static func podium_aabb(spec: ChurchSpec) -> AABB:
	var lo := Vector2(-spec.width / 2.0, -spec.length / 2.0)
	var hi := Vector2(spec.width / 2.0, spec.length / 2.0)
	if spec.narthex:
		var n: AABB = narthex_aabb(spec)
		lo.y = minf(lo.y, n.position.z)
	for i in range(spec.radiating_chapels):
		var c: AABB = chapel_aabb(spec, i)
		lo = lo.min(Vector2(c.position.x, c.position.z))
		hi = hi.max(Vector2(c.end.x, c.end.z))
	var m: float = PODIUM_MARGIN
	return AABB(Vector3(lo.x - m, 0.0, lo.y - m),
		Vector3(hi.x - lo.x + m * 2.0, podium_height(spec), hi.y - lo.y + m * 2.0))


## Body of chapel `i` below its drum. Heights are staggered so no two
## neighbours read as a pair.
static func chapel_body_height(spec: ChurchSpec, i: int) -> float:
	if spec.hero == &"basil":
		return spec.height * float(BASIL_PATTERN[i % BASIL_PATTERN.size()])
	return spec.height * 0.42


static func chapel_drum_radius(spec: ChurchSpec) -> float:
	return spec.chapel_radius * 0.78


static func chapel_drum_height(spec: ChurchSpec, i: int) -> float:
	return spec.chapel_radius * 0.9 * float(BASIL_DRUM_PATTERN[(i * 3) % BASIL_DRUM_PATTERN.size()])


static func chapel_onion_rise(spec: ChurchSpec) -> float:
	return chapel_drum_radius(spec) * 1.7


static func chapel_spike_height(spec: ChurchSpec) -> float:
	return spec.chapel_radius * 0.45


## The drum stands a little out from the chapel's flat face, so it sits wholly
## over the half-drum below it.
static func chapel_drum_center(spec: ChurchSpec, i: int) -> Vector3:
	var a: float = chapel_angle(spec, i)
	return chapel_center(spec, i) + Vector3(sin(a), 0.0, cos(a)) * (spec.chapel_radius * 0.10)


## Ground to the tip of the cross: what the elevation draws.
static func chapel_tower_height(spec: ChurchSpec, i: int) -> float:
	if spec.hero != &"basil":
		return spec.height * 0.42
	return chapel_body_height(spec, i) + chapel_drum_height(spec, i) \
		+ chapel_onion_rise(spec) + chapel_spike_height(spec)


## Hagia Sophia: the drum stands on a square masonry bearing whose four faces
## are the great arches. Half-domes spring from its east and west faces.
static func hagia_bearing(spec: ChurchSpec) -> bool:
	return spec.hero == &"hagia" and spec.dome and spec.dome_shape == &"hemisphere"


## Half the bearing's side: the crossing square the dome circle is inscribed in.
static func hagia_bearing_half(spec: ChurchSpec) -> float:
	return spec.dome_radius + 0.3


static func hagia_pier_size(spec: ChurchSpec) -> float:
	return spec.dome_radius * HAGIA_PIER_RATIO


## Centre of the corner pier at (sx, sz) in {-1, 1}.
static func hagia_pier_center(spec: ChurchSpec, sx: float, sz: float) -> Vector3:
	var off: float = hagia_bearing_half(spec) - hagia_pier_size(spec) * 0.5
	return Vector3(sx * off, 0.0, crossing_center_z(spec) + sz * off)


## Piers climb past the bearing to about half-way up the drum.
static func hagia_pier_top(spec: ChurchSpec) -> float:
	return dome_base_height(spec) + pendentive_height(spec) + spec.dome_drum_height * 0.5


## Rise of a half-dome. At Hagia the crown meets the top of the bearing, so
## the great arches and the domes close at one level.
static func half_dome_rise(spec: ChurchSpec) -> float:
	if hagia_bearing(spec):
		return pendentive_height(spec)
	return half_dome_radius(spec) * 0.85


## Z of the plane a half-dome springs from: the bearing's east and west faces.
static func half_dome_face_z(spec: ChurchSpec, dir: float) -> float:
	if hagia_bearing(spec):
		return crossing_center_z(spec) + dir * hagia_bearing_half(spec)
	return crossing_center_z(spec)


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
		var half_reach: float = half_dome_radius(spec) \
			+ (hagia_bearing_half(spec) if hagia_bearing(spec) else 0.0)
		z1 = maxf(z1, crossing_center_z(spec) + half_reach)
		z0 = minf(z0, crossing_center_z(spec) - half_reach)
	for i in range(tribune_count(spec)):
		var tb: AABB = tribune_aabb(spec, i)
		z1 = maxf(z1, tb.end.z)
		z0 = minf(z0, tb.position.z)
	if octagon_crossing(spec):
		var oct: AABB = octagon_aabb(spec)
		z1 = maxf(z1, oct.end.z)
		z0 = minf(z0, oct.position.z)
	if podium_height(spec) > 0.0:
		var pod: AABB = podium_aabb(spec)
		z1 = maxf(z1, pod.end.z)
		z0 = minf(z0, pod.position.z)
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
	for i in range(tribune_count(spec)):
		var tb: AABB = tribune_aabb(spec, i)
		w = maxf(w, absf(tb.position.x) * 2.0)
		w = maxf(w, absf(tb.end.x) * 2.0)
	if podium_height(spec) > 0.0:
		w = maxf(w, podium_aabb(spec).size.x)
	return w
