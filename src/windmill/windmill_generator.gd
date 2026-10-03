class_name WindmillGenerator
extends RefCounted
## A seed and a type: one windmill, exactly, every time.
##
## Everything derived from the seed is written HERE, once, and `WindmillBuilder`
## reads it without drawing a single die. That is the family contract: the spec
## is the whole truth, and a mill built twice from one spec is the same mill
## down to the vertex.
##
## The order matters. A mill is not free to be any size at all: its rotor has to
## clear the ground it turns over, its sail plane has to stand in front of its
## own cap, and its ladder has to stand outside its own sails. Each of those is
## a real machine constraint, not a style rule, and each one here is enforced by
## solving it rather than by hoping the caller's numbers happened to satisfy it.

## Windmills are named after their place, the way mills are.
const NAME_FIRST := ["Ash", "Blackthorn", "Combe", "Elm", "Fenner", "Hollow",
	"Rook", "Thistle", "Warren", "Wether", "Kiln", "Comfrey", "Nether", "Sallow"]
const NAME_SECOND := ["", "", "", " Cross", " Green", " End", " Bridge", " Reach"]


static func generate(spec: WindmillSpec, p_seed: int) -> void:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var rng: RandomNumberGenerator = spec.rng
	var row: Dictionary = spec.type_row()

	# 1. What this type will accept. A windpump asked for a twenty-metre sail
	#    span is answered with a fan it can actually turn, and the answer is
	#    the type's own doing rather than the generator's taste.
	var ok: Dictionary = WindmillGeometry.legal(spec)
	spec.sail_span = float(ok["sail_span"])
	spec.body = float(ok["body"])
	spec.height = float(ok["height"])
	spec.base_r = float(ok["base_r"])

	# 2. The rotor, which every type shares and every type means differently.
	spec.sail_r = spec.sail_span * 0.5
	spec.sail_width = clampf(spec.sail_r * 0.16, 0.45, 1.6)
	spec.whorl_r = clampf(spec.sail_r * 0.085, 0.28, 0.72)
	spec.sail_angle = rng.randf_range(0.42, 1.15)
	spec.sails = _blade_count(rng, row["sails"])
	spec.wall_t = WindmillGeometry.wall_thickness(spec)
	spec.doors(0) if false else null

	spec.door_h = WindmillGeometry.DOOR_H
	spec.windows = rng.randi_range(1, 4)

	match spec.mill_type:
		&"tower":
			_tower(spec, rng, row)
		&"post":
			_post(spec, rng, row)
		&"smock":
			_smock(spec, rng, row)
		&"windpump":
			_windpump(spec, rng, row)
		&"paddle":
			_paddle(spec, rng, row)

	spec.variant_name = _name(rng)
	_palette(spec, rng, row)


## How many sails, and a windpump's blades want a multiple of four because that
## is what came off a punch. An ODD count is a wreck: a five-sailed mill turns
## unevenly and always has done.
static func _blade_count(rng: RandomNumberGenerator, band: Array) -> int:
	var lo: int = int(band[0])
	var hi: int = int(band[1])
	var raw: float = rng.randf_range(float(lo), float(hi))
	var step: int = 4 if hi >= 12 else 2
	return clampi(int(round(raw / float(step))) * step, lo, hi)


# ------------------------------------------------------------------ the tower

## A battered brick drum, a cap that turns on a curb, a stage on the front.
static func _tower(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	spec.curb_r = spec.base_r * rng.randf_range(float(row["batter"][0]), float(row["batter"][1]))
	spec.cap = GeneratorRandom.pick(rng, row["cap"])
	spec.cap_r = WindmillGeometry.cap_radius_for(spec.curb_r)
	spec.cap_h = WindmillGeometry.cap_height_for(spec.cap, spec.curb_r)
	spec.cap_yaw = rng.randf_range(-0.18, 0.18)
	spec.gallery = spec.curb_r >= 1.3
	spec.burr_y = 0.0
	# the tower grows until its rotor clears the grass: the one equation that
	# decides a tower mill's height
	spec.height = maxf(spec.height, WindmillGeometry.required_floor_y(spec))
	spec.curb_y = spec.height
	_stage_and_stock(spec, rng, row, spec.cap_r)
	_tail(spec, rng, row)
	spec.fantail = bool(row["fantail"])
	spec.fantail_r = clampf(spec.cap_r * 0.55, 0.4, 1.2)


# ------------------------------------------------------------------- the post

## A timber burr on one post, on a mound, with a ladder up to a door the ladder
## is standing beside rather than under.
static func _post(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	spec.curb_r = spec.base_r        # a square burr has no batter
	spec.cap = &"none"
	spec.cap_r = 0.0
	spec.cap_h = 0.0
	spec.gallery = false
	spec.trestle = GeneratorRandom.chance(rng, 0.4)
	# The mound or the trestle is what makes it a post mill rather than a box on
	# a stick, and it is also the ground the sails have to clear.
	spec.mound_h = 0.0 if spec.trestle else rng.randf_range(0.7, WindmillGeometry.MOUND_MAX)
	_stage_and_stock(spec, rng, row, spec.base_r)
	# now that the mound's height is known, the post can be made long enough
	spec.burr_y = maxf(spec.mound_h + WindmillGeometry.POST_MIN,
		WindmillGeometry.required_floor_y(spec))
	spec.height = maxf(spec.height, 2.6)
	spec.curb_y = spec.burr_y + spec.height
	spec.stage_y = spec.burr_y + 0.5
	spec.stage_arc = TAU * 0.78
	# the burr is stood off the wind, so its ladder, its door and its tailpole
	# all sit wherever the miller last turned it
	spec.body_yaw = rng.randf_range(-0.55, 0.55) * (1.0 if GeneratorRandom.chance(rng, 0.5) else -1.0)
	# The door is in the burr's front WALL, a quarter of the way to one side --
	# which side is whichever the burr was last turned. It cannot stand further
	# out than that: the ladder's FOOT is what clears the sails, not its top.
	spec.door_offset_x = spec.base_r * 0.25 * (1.0 if spec.body_yaw >= 0.0 else -1.0)
	spec.ladder = true
	spec.ladder_w = rng.randf_range(0.62, 0.85)
	spec.ladder_offset = WindmillGeometry.ladder_offset_for(spec)
	spec.ladder_run = rng.randf_range(1.6, 2.8)
	spec.mound_r = maxf(spec.base_r * 2.4,
		WindmillGeometry.ladder_foot_radius(spec) + 0.7)
	spec.tail = spec.base_r * rng.randf_range(float(row["tail"][0]), float(row["tail"][1]))
	spec.tail_drop = rng.randf_range(0.14, 0.26)
	spec.tailwheel_r = clampf(spec.base_r * 0.22, 0.34, 0.7)
	spec.fantail = false


# ------------------------------------------------------------------ the smock

## A weatherboarded frame on a low brick stump, turning an ogee cap.
static func _smock(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	spec.stump_h = rng.randf_range(1.4, 3.2)
	spec.burr_y = spec.stump_h
	spec.curb_r = spec.base_r * rng.randf_range(float(row["batter"][0]), float(row["batter"][1]))
	spec.cap = GeneratorRandom.pick(rng, row["cap"])
	spec.cap_r = WindmillGeometry.cap_radius_for(spec.curb_r)
	spec.cap_h = WindmillGeometry.cap_height_for(spec.cap, spec.curb_r)
	spec.cap_yaw = rng.randf_range(-0.14, 0.14)
	spec.gallery = spec.curb_r >= 1.2
	spec.height = maxf(spec.height, WindmillGeometry.required_floor_y(spec) - spec.stump_h)
	spec.curb_y = spec.stump_h + spec.height
	_stage_and_stock(spec, rng, row, spec.cap_r)
	_tail(spec, rng, row)
	spec.fantail = bool(row["fantail"])
	spec.fantail_r = clampf(spec.cap_r * 0.5, 0.35, 1.0)


# -------------------------------------------------------------- the windpump

## Not a mill at all: a bladed fan on a lattice tower, geared down to a water
## pump. The head turns, so there is no cap, no stage and no tailpole -- and
## instead there is a fan vane, a star wheel and a rod down to the pump.
static func _windpump(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	spec.curb_r = spec.base_r * rng.randf_range(float(row["batter"][0]), float(row["batter"][1]))
	spec.head_r = clampf(spec.base_r * 0.45, 0.45, 0.95)
	spec.tilt = rng.randf_range(WindmillGeometry.FAN_TILT[0], WindmillGeometry.FAN_TILT[1])
	spec.braces = clampi(int(round(maxf(spec.height, 6.0) / 1.85)), 4, 9)
	spec.cap = &"flat"
	spec.cap_r = spec.head_r * 1.45
	spec.cap_h = WindmillGeometry.cap_height_for(&"flat", spec.head_r)
	spec.gallery = false
	spec.burr_y = 0.0
	# the lattice grows until the fan clears the ground it turns over
	spec.height = maxf(spec.height, WindmillGeometry.required_floor_y(spec))
	spec.curb_y = spec.height
	spec.stage_r = 0.0
	spec.stage_y = 0.0
	spec.stage_arc = 0.0
	spec.tail = spec.sail_r * rng.randf_range(1.5, 2.05)
	spec.tail_drop = 0.0
	spec.tailwheel_r = 0.0
	spec.fantail = false
	spec.vanes = true
	spec.star_teeth = rng.randi_range(8, 16) * 2
	spec.cranked = true
	spec.pump_h = rng.randf_range(1.8, 2.6)
	spec.discharge_h = rng.randf_range(2.6, 4.2)
	spec.windows = 0


# ----------------------------------------------------------------- the paddle

## The Dutch one: a tower over a scoop wheel, standing in its own race. There
## are no sails on it at all, which is exactly what makes it a windmill.
static func _paddle(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	spec.curb_r = spec.base_r * rng.randf_range(float(row["batter"][0]), float(row["batter"][1]))
	spec.wheel_r = spec.base_r * rng.randf_range(0.92, 1.3)
	spec.wheel_buckets = clampi(int(spec.wheel_r * 2.4), 8, 14)
	spec.wheel_width = clampf(spec.wheel_r * 0.16, 0.6, 1.2)
	spec.race_w = spec.wheel_r * 1.45
	spec.race_len = spec.wheel_r * 2.7
	spec.race_depth = clampf(spec.wheel_r * 0.26, 0.7, 1.6)
	spec.cap = GeneratorRandom.pick(rng, row["cap"])
	spec.cap_r = WindmillGeometry.cap_radius_for(spec.curb_r)
	spec.cap_h = WindmillGeometry.cap_height_for(spec.cap, spec.curb_r)
	spec.cap_yaw = 0.0
	spec.gallery = spec.curb_r >= 1.2
	spec.burr_y = 0.0
	# a mill house stands clear of its own wheel, or the water lands on the roof
	spec.height = maxf(spec.height, spec.wheel_r * 1.75)
	spec.curb_y = spec.height
	spec.stage_r = 0.0
	spec.stage_y = 0.0
	spec.stage_arc = 0.0
	spec.tail = 0.0
	spec.fantail = false
	spec.sails = spec.wheel_buckets
	spec.windows = 2


# ---------------------------------------------------------------- shared parts

## The stage, and with it the sail plane. The stock stands off the mill's own
## face far enough that the sail circle passes in front of the cap rather than
## through it -- the clearance is the reason the stage exists at all.
static func _stage_and_stock(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary,
		face_r: float) -> void:
	var band: Array = row["stage"]
	if band[1] <= 0.0:
		spec.stage_r = 0.0
		spec.stage_y = 0.0
		spec.stage_arc = 0.0
		return
	var stand: float = rng.randf_range(float(band[0]), float(band[1]))
	spec.stage_r = face_r + maxf(stand, WindmillGeometry.CAP_CLEAR)
	# the deck sits a step under the shaft, which is where a miller works
	var shaft_above: float = WindmillGeometry.cap_height_for(spec.cap, spec.curb_r) * 0.28
	spec.stage_y = spec.curb_y + shaft_above - 0.95
	spec.stage_arc = TAU * 0.62


## The tailpole, measured in body radii: a cap mill's is a beam and a post
## mill's is a lever long enough to walk a body the size of a room.
static func _tail(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	var band: Array = row["tail"]
	spec.tail = spec.base_r * rng.randf_range(float(band[0]), float(band[1]))
	spec.tail_drop = rng.randf_range(0.13, 0.26)
	spec.tailwheel_r = clampf(spec.base_r * 0.2, 0.3, 0.7)


static func _name(rng: RandomNumberGenerator) -> String:
	return "%s%s Mill" % [GeneratorRandom.pick(rng, NAME_FIRST),
		GeneratorRandom.pick(rng, NAME_SECOND)]


## The colours, and they are the mill's period as much as its stone is: a
## smock mill is tarred black or lime-washed white, a Dutch tower is dark red
## brick, an American windpump is galvanised grey. Ironwork is ironwork.
static func _palette(spec: WindmillSpec, rng: RandomNumberGenerator, row: Dictionary) -> void:
	var walls: Array = row.get("walls", ["6d6255", "59503f"])
	spec.wall_color = Color(String(GeneratorRandom.pick(rng, walls)))
	spec.trim_color = Color(String(row.get("trim", "2b2622")))
	spec.sail_color = Color(String(row.get("sail", "e6dfcb")))
	spec.dark_color = Color(String(row.get("dark", "12100e")))
	spec.water_color = Color(String(row.get("water", "2c4148")))