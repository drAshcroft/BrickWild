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


static func tower_aabb(spec: ChurchSpec) -> AABB:
	var tw: float = spec.tower_width
	return AABB(Vector3(-tw / 2.0, 0.0, tower_center_z(spec) - tw / 2.0),
		Vector3(tw, spec.tower_height, tw))


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


static func aisle_center_x(spec: ChurchSpec, side: float) -> float:
	return side * (spec.width / 2.0 + spec.aisle_width / 2.0 - AISLE_LAP)


static func aisle_aabb(spec: ChurchSpec, side: float) -> AABB:
	var zr: Vector2 = aisle_z_range(spec)
	var aw: float = spec.aisle_width
	return AABB(Vector3(aisle_center_x(spec, side) - aw / 2.0, 0.0, zr.x),
		Vector3(aw, spec.height * AISLE_HEIGHT_RATIO, zr.y - zr.x))


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
		z0 = minf(z0, tower_aabb(spec).position.z)
	if spec.apse:
		var a: AABB = apse_aabb(spec)
		z1 = maxf(z1, a.position.z + a.size.z)
	return Vector2(z0, z1)


## Full drawn extent along Z, including bracing that projects past the masses.
## This is what the sheet must be scaled to so nothing is clipped.
static func length_extent(spec: ChurchSpec) -> Vector2:
	var e: Vector2 = mass_length_extent(spec)
	if spec.tower:
		e.x -= buttress_projection(spec)
	return e


## Full extent across X, including aisles, transept arms and buttresses.
static func width_extent(spec: ChurchSpec) -> float:
	var w: float = spec.width
	var bp: float = buttress_projection(spec)
	if spec.aisles > 0:
		w = maxf(w, absf(aisle_center_x(spec, 1.0)) * 2.0 + spec.aisle_width)
	if spec.transept:
		w = maxf(w, spec.transept_len)
	if spec.tower:
		w = maxf(w, spec.tower_width + bp * 2.0)
	if spec.buttresses:
		w = maxf(w, spec.width + bp * 2.0)
	return w
