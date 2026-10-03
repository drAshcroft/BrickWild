class_name WindmillSpec
extends RefCounted
## One windmill: a rotor, a body to hold it, and whatever turns it into the
## wind.
##
## A windmill is not one building. It is at least five, and what separates them
## is not size or ornament -- it is WHICH PART TURNS:
##
##   post      the whole body turns, on one post
##   smock     a fixed timber frame; only the cap turns
##   tower     a fixed masonry tower; only the cap turns
##   windpump  the whole head turns on a lattice tower, and drives a pump
##   paddle    nothing turns in the wind at all; water turns an undershot wheel
##
## That is why this is one family and not five. All five answer to the same
## three numbers -- the ROTOR's span, the BODY's own width, and how TALL it
## stands -- and all five are the same machine seen from a different century.
##
## The three numbers are the request's own `width`, `length` and `height`, and
## the library says what they mean: a sail span, a body, a height. Nothing here
## re-derives them; the generator clamps them against WindmillGeometry and
## writes down what the mill actually became, so `WindmillBuilder.build()` is a
## pure function of this spec.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized) ----
## Which of the five. See TYPES.
var mill_type: StringName = &"tower"
## The rotor's diameter, tip to tip, in metres. The request's `width`. A sail
## span on a tower mill, a fan diameter on a windpump, the wheel across a
## paddle mill -- each family keeps the same three numbers and means something
## native by them.
var sail_span: float = 12.0
## The body's own width, outside face to outside face. The request's `length`.
## A tower mill's base diameter, a post mill's burr, a windpump's leg spread.
var body: float = 6.0
## How tall the mill stands, ground to curb. The request's `height`.
var height: float = 12.0
var material: StringName = &"stone"
var orientation: float = 0.0
var period: int = 1200

# ---- derived from seed + type + the three numbers above ----
var variant_name: String

## Body geometry. `base_r` is the body's half-width at the ground; `curb_r` is
## its radius where the cap turns. A post mill's burr is square, so its `base_r`
## is half its side and it has no curb at all.
var base_r: float = 3.0
var curb_r: float = 1.8
## The body's floor height. Zero on a mill standing on the ground, a stump's
## height on a smock mill, and the top of the mound and post on a post mill.
## `WindmillGeometry.floor_y()` is this field; every rule about where a post
## mill's own floor stands is really a rule about this number.
var burr_y: float = 0.0
## Which way round the body faces. A post mill turns its whole burr into the
## wind, so this is off the axis: the tail goes wherever the wind is not.
var body_yaw: float = 0.0
## Where the door sits across the front wall. Zero for a mill whose front wall
## is symmetric; off the axis for a post mill, whose ladder has to stand
## clear of its own sails.
var door_offset_x: float = 0.0
var curb_y: float = 12.0
var wall_t: float = 0.5
var stump_h: float = 0.0     ## a smock mill's brick base, under its frame

## The cap: what turns, and what the weather falls on.
var cap: StringName = &"dome"  # &"dome", &"ogee", &"crown", &"flat", &"none"
var cap_r: float = 2.2
var cap_h: float = 2.6
var cap_yaw: float = 0.0      # a cap is set a few degrees off the body
var gallery: bool = false     # a walk round the curb
var fantail: bool = false     # the self-turning tail
var fantail_r: float = 1.0

## The rotor.
var sails: int = 4            # &"sails" on a mill, &"blades" on a windpump
var sail_r: float = 6.0
var sail_width: float = 1.1   # the cloth's breadth
var sail_angle: float = 0.5   # where the rotor happens to have stopped
var tilt: float = 0.0         # a windpump's axle tips up into the wind
var stock_r: float = 0.9      # how far the stock's outer end stands off the mill
var whorl_r: float = 0.55     # the disc at the sail's root
var axle: Vector3 = Vector3.ZERO

## The stage: the walk the miller stands on to reef a sail.
var stage_r: float = 1.2
var stage_y: float = 8.0
var stage_arc: float = 3.8

## The tail: what a mill is turned by, and the only reason it is not a statue.
var tail: float = 3.0
var tail_drop: float = 0.0    # radians below horizontal
var tailwheel_r: float = 0.6

## A post mill stands on a mound, because a post mill's post is short and a
## miller cannot climb six metres of ladder twice a day.
var mound_r: float = 0.0
var mound_h: float = 0.0
var trestle: bool = false     ## a timber trestle instead of a mound

## The way up. A stock ladder is offset sideways so the sails pass it.
var ladder: bool = false
var ladder_w: float = 0.7
var ladder_offset: float = 1.2
var ladder_run: float = 3.0

## A windpump's tower: bays of X-braced lattice.
var braces: int = 6
var leg_r: float = 0.5
var head_r: float = 0.7
var vanes: bool = false       # the fan vane that weathercocks the head
var star_teeth: int = 12      # the gear between the fan shaft and the pump
var cranked: bool = false     ## the pump gear a windpump carries
var pump_h: float = 2.0
var discharge_h: float = 3.0

## A paddle mill's wheel and the race it stands in.
var wheel_r: float = 4.0
var wheel_buckets: int = 10
var wheel_width: float = 0.9
var race_w: float = 3.0
var race_len: float = 12.0
var race_depth: float = 1.1

## Openings.
var door_w: float = 1.0
var door_h: float = 2.1
var windows: int = 3

var wall_color: Color
var trim_color: Color
var sail_color: Color
var dark_color: Color
## Race water. Only a polder mill has a fifth surface to fill, but the colour
## lives here with the rest so `colours()` never has to know which mills do.
var water_color: Color

## The five, in the order a menu should offer them: the three that ground a
## European village, and the two that did not.
##
## Every entry carries what that mill IS -- which part turns, what it stands
## on, what carries the rotor -- and the bands its own three numbers are held
## to. The generator picks within these; `WindmillGeometry` is what both read.
const TYPES := {
	&"tower": {
		"label": "Tower mill",
		# A battered brick drum with a cap that turns on a curb, a stage on
		# the front and a short tailpole behind it. England, Flanders, and
		# every windmill drawn on a bank note.
		"turns": &"cap", "on": &"ground",
		"body_r": [2.8, 4.0], "height": [9.0, 22.0], "batter": [0.52, 0.64],
		"stage": [1.0, 1.6], "cap": [&"dome", &"ogee", &"crown", &"flat"],
		"sails": [4, 4], "tail": [1.3, 2.1], "fantail": true,
		"span": [0.95, 1.65], "detail": "Tall and taper-footed, so the taper carries the eye",
		# flint, ragstone, and the red brick a miller could afford
		"walls": ["6b6355", "7a6a52", "8c4a37", "4f4a42"],
		"trim": "2f2a25", "sail": "e8e1cd", "dark": "15120f",
	},
	&"post": {
		"label": "Post mill",
		# A timber burr on one post, on a mound, with a ladder up to the door
		# and a long tailpole to turn it. The whole body leans into the wind.
		"turns": &"body", "on": &"mound",
		"body_r": [1.9, 3.0], "height": [2.6, 4.2], "batter": [1.0, 1.0],
		"stage": [0.55, 0.95], "cap": [&"none"],
		"sails": [4, 6], "tail": [1.6, 2.6], "fantail": false,
		"span": [0.85, 1.25], "detail": "Low, square and perched, with the ladder to one side",
		# tarred weatherboarding, which is what a burr was, always
		"walls": ["2b2723", "3a332b", "57493a"],
		"trim": "1f1b17", "sail": "e4dcc6", "dark": "0d0b09",
	},
	&"smock": {
		"label": "Smock mill",
		# A weatherboarded octagonal frame on a low brick stump, with an ogee
		# cap. The timber answer to the tower mill, and much cheaper to raise.
		"turns": &"cap", "on": &"stump",
		"body_r": [2.6, 3.8], "height": [9.0, 16.0], "batter": [0.52, 0.66],
		"stage": [0.7, 1.15], "cap": [&"ogee", &"crown", &"dome"],
		"sails": [4, 4], "tail": [1.8, 2.6], "fantail": true,
		"span": [0.9, 1.4], "detail": "Boarded all over, tapering hard to a little ogee cap",
		# tarred black or lime-washed white, and the white ones are why you
		# can pick a smock mill out of an English skyline at a mile
		"walls": ["d9d3c4", "cfc7b6", "2e2925", "3d372f"],
		"trim": "241f1b", "sail": "efe8d4", "dark": "100e0c",
	},
	&"windpump": {
		"label": "Farm windpump",
		# Not a mill at all: a many-bladed fan on a lattice tower, geared down
		# to a water pump. Great Plains and Australian stations.
		"turns": &"head", "on": &"lattice",
		"body_r": [1.1, 2.0], "height": [7.0, 15.0], "batter": [0.45, 0.62],
		"stage": [0.0, 0.0], "cap": [&"flat"],
		"sails": [16, 24], "tail": [0.0, 0.0], "fantail": false,
		"span": [0.9, 1.6], "detail": "Lattice steel, a bladed fan, a vane behind it and a pump below",
		# galvanised, and after a few seasons rusted to the colour of a dodo
		"walls": ["8d9095", "9aa0a4", "a2765a"],
		"trim": "3b3d40", "sail": "cfc9bb", "dark": "131618",
	},
	&"paddle": {
		"label": "Polder mill",
		# The Dutch: a masonry tower with an undershot wheel in the race at
		# its foot. No sails, no wind -- which is exactly what makes it one.
		"turns": &"water", "on": &"ground",
		"body_r": [2.8, 4.2], "height": [8.0, 15.0], "batter": [0.66, 0.80],
		"stage": [0.0, 0.0], "cap": [&"dome", &"flat"],
		"sails": [8, 12], "tail": [0.0, 0.0], "fantail": false,
		"span": [1.2, 1.9], "wheel": true,
		"detail": "A tower over a scoop wheel, standing in its own race",
		# dark red brick, and a thatch cap because thatch was what got wet
		"walls": ["7d3b2c", "8a4a35", "6a6257"],
		"trim": "2a2523", "sail": "cbb183", "dark": "121312",
	},
}


func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed


## This mill's own row of TYPES, or an empty dictionary for a type it does not
## have. Callers that are handed a spec by a caller rather than by the
## generator go through here first.
func type_row() -> Dictionary:
	return TYPES.get(mill_type, TYPES[&"tower"])