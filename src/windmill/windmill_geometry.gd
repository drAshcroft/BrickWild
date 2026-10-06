class_name WindmillGeometry
extends RefCounted
## Every dimension a windmill has, as pure functions of its spec.
##
## This is the single source of truth, the same job `CastleGeometry` and
## `ChurchGeometry` do. `WindmillGenerator` clamps against it and writes the
## result onto the spec; `WindmillBuilder` draws it; `WindmillCheck` measures
## the drawn mesh against it. If two places computed the same dimension, that
## is the bug -- so they do not.
##
## The frame every mill here shares: local -Z is the front and the way the
## wind comes from, local +Z is where the tail is, Y is up. The rotor's plane
## is the XY plane in front of the mill, so a mill that has turned into the
## wind has turned its tail away from you.

## Five surfaces, and deliberately one more than the usual four. A windmill
## has iron in it -- gearing, a winding wheel, a scoop wheel, the frame of
## every sail -- and iron is not the same colour as anything else on the
## building. Folding it into "trim" left the machinery the colour of the
## thatch. See `BuildingFamilyAdapter.colours()`.
const SURFACE_COUNT := 5
## A post mill's roof is a single pitch, and it is the only roof in the family
## that is not a cap -- so it is the one whose highest point the cap's height
## does not describe.
const POST_ROOF_RISE := 0.75

# ------------------------------------------------------------- fixed dimensions

## Masonry thickness. Enough to read as a wall at any mill this size.
const WALL_T := 0.45
## A stage is a walkway: how far it reaches in from the sail plane towards the
## mill, and how high its rail stands.
const STAGE_WIDTH := 0.6
const DOOR_W := 1.05
const DOOR_H := 2.15
const GALLERY_WIDTH := 0.5
const RAIL_H := 0.95
const RAIL_POST := 0.09

## The rotor's circle must clear the ground by this much. A mill whose sails
## drag in the grass is a broken mill, and this is the rule that catches it --
## and it is the rule that decides how tall a post mill's post has to be.
const TIP_CLEAR := 0.6
## How far the sail plane stands in front of the cap's widest point. A windshaft
## emerges from the cap's front wall and the stocks go on from there, so this
## is a real clearance and not a fudge factor.
const CAP_CLEAR := 0.35
## A stock ladder runs up beside the mill, so the sails pass it. This is how far
## outside the sail's own breadth it has to stand.
const LADDER_CLEAR := 0.3

## A cap mill's sail span against the height of the tower carrying it. The
## generator holds a tower or smock mill's span to at least SPAN_PER_HEIGHT of
## its height (and allows up to SPAN_PER_HEIGHT_MAX); `WindmillCheck` fails a
## drawn rotor under SPAN_PER_HEIGHT_MIN. A real tower mill's sails span about
## the tower's height or more; a span of half the height reads as toy vanes.
const SPAN_PER_HEIGHT := 0.9
const SPAN_PER_HEIGHT_MAX := 1.5
const SPAN_PER_HEIGHT_MIN := 0.8
## A smock mill's brick stump, under its timber frame.
const STUMP_H := [1.4, 3.2]

## A post mill's post cannot be so short that a miller would not climb it.
const POST_MIN := 1.9
const TRESTLE_MIN := 2.4
const MOUND_MAX := 2.2

## How the five bodies are drawn in plan: a round drum, an eight-sided frame, a
## square burr, a lattice of four legs, or a drum with a wheel in front of it.
const SIDES_ROUND := 16
const SIDES_SMOCK := 8
const SIDES_BURR := 4

## A windpump's axle tips back into the wind, so the fan takes the full push of
## it instead of edge-on. Nine to sixteen degrees, which is what they did.
const FAN_TILT := [0.16, 0.28]
## ... and how far down the tilted shaft its fan sits from the pivot.
const HEAD_REACH := 0.55


static func row(spec: WindmillSpec) -> Dictionary:
	return spec.type_row()


static func label(spec: WindmillSpec) -> String:
	return String(row(spec).get("label", "Windmill"))


static func turns(spec: WindmillSpec) -> StringName:
	return row(spec).get("turns", &"cap")


## Which part turns. The whole distinction between these five buildings.
static func is_round(spec: WindmillSpec) -> bool:
	return spec.mill_type in [&"tower", &"smock", &"paddle"]

static func has_gallery(spec: WindmillSpec) -> bool:
	return spec.gallery


static func is_square(spec: WindmillSpec) -> bool:
	return spec.mill_type == &"post"


static func has_stage(spec: WindmillSpec) -> bool:
	return spec.stage_r > 0.0


static func has_tail(spec: WindmillSpec) -> bool:
	return spec.tail > 0.0


static func has_galaxy_gallery(spec: WindmillSpec) -> bool:
	return spec.gallery


## The fixed structure's top: a tower's curb, a smock's curb, a lattice tower's
## head platform, a post mill's burr roof.
static func top_y(spec: WindmillSpec) -> float:
	return spec.curb_y


## The body's floor. Zero on a mill that stands on the ground, a stump's height
## on a smock mill, and the top of the mound and post on a post mill -- which is
## the number every other rule about a post mill is really about.
static func floor_y(spec: WindmillSpec) -> float:
	return spec.burr_y


## The ground the rotor actually sweeps over: the top of the mound under a post
## mill, and nothing anywhere else. A mill on a mound cannot have its sails
## dragging on the mound, so this is what `TIP_CLEAR` is measured from.
static func ground_under(spec: WindmillSpec) -> float:
	if spec.mill_type == &"paddle":
		return -spec.race_depth     # the bed of its own race, not the ground
	return spec.mound_h


## The lowest ground the mill stands on. Zero everywhere except a polder mill,
## whose race is a channel CUT INTO it -- so its mill is not dug in, it dug.
static func footing_y(spec: WindmillSpec) -> float:
	return -spec.race_depth if spec.mill_type == &"paddle" else 0.0

## How far out from the mill's axis the ladder's foot stands. The mound has to
## be wide enough to carry it, so the generator asks this before it chooses one.
static func ladder_foot_radius(spec: WindmillSpec) -> float:
	return Vector2(spec.ladder_offset, spec.base_r + spec.ladder_run).length()


## The body's radius at a height: a straight batter from the ground's radius to
## the curb's. A post mill has no batter at all, which is why its own row says
## so.
static func radius_at(spec: WindmillSpec, y: float) -> float:
	var top: float = maxf(top_y(spec) - floor_y(spec), 0.001)
	var t: float = clampf((y - floor_y(spec)) / top, 0.0, 1.0)
	return lerpf(spec.base_r, spec.curb_r, t)


static func sides(spec: WindmillSpec) -> int:
	if is_square(spec):
		return SIDES_BURR
	if spec.mill_type == &"smock":
		return SIDES_SMOCK
	return SIDES_ROUND


## The walls, drawn thick enough to read and thin enough not to eat the inside
## of a small burr.
static func wall_thickness(spec: WindmillSpec) -> float:
	return minf(WALL_T, maxf(spec.base_r * 0.22, 0.18))


## A round drum's door must fit ONE face of the polygon it is drawn as, or its
## edges hang in the air where the next face turns away. Measured at the
## door head, where a battered face is narrowest.
static func door_w(spec: WindmillSpec) -> float:
	var w: float = minf(spec.door_w, maxf(spec.base_r * 1.15, 0.7))
	if not is_square(spec) and spec.mill_type != &"windpump":
		var head: float = floor_y(spec) + minf(spec.door_h, maxf(spec.height * 0.78, 1.4))
		w = minf(w, face_width(spec, head) * 0.92)
	return w


# ------------------------------------------------------------ the wall surface
#
# A drum is drawn as a POLYGON of `sides` faces, battered from its base radius
# to its curb radius, and an opening put on the circle that polygon is
# inscribed in -- or on the drum's bounding box -- hangs in the air beside the
# wall wherever a face turns away from it, and stands vertical where the wall
# leans. These are the one description of that surface: the builder draws the
# drum from them and places every opening on them, and `WindmillCheck` measures
# every opening against them.

## The drum is turned half a segment so a FACE, not a corner, looks down -Z,
## which is where the door is. With a corner there, the door stood across a
## ridge and both of its jambs stood off the wall.
static func drum_start(sides_n: int) -> float:
	return PI / float(maxi(sides_n, 3))


## The battered band of drum at height `y`: its foot and head, the radii there
## (to the polygon's corners) and its number of faces. A smock mill has two --
## a round brick stump and an eight-sided frame on it.
static func drum_band(spec: WindmillSpec, y: float) -> Dictionary:
	if spec.mill_type == &"smock":
		if y < spec.stump_h:
			return {"y0": 0.0, "y1": spec.stump_h, "r0": spec.base_r,
				"r1": spec.base_r * 0.96, "sides": SIDES_ROUND}
		return {"y0": spec.stump_h, "y1": spec.curb_y, "r0": spec.base_r * 0.96,
			"r1": spec.curb_r, "sides": SIDES_SMOCK}
	return {"y0": floor_y(spec), "y1": spec.curb_y, "r0": spec.base_r,
		"r1": spec.curb_r, "sides": sides(spec)}


## How far a post mill's boarding stands proud of its burr wall. The boards are
## the face an opening is fixed to.
static func board_proud(spec: WindmillSpec) -> float:
	return spec.wall_t * 0.125


## One face's width at height `y`.
static func face_width(spec: WindmillSpec, y: float) -> float:
	if is_square(spec):
		return spec.base_r * 2.0
	var band: Dictionary = drum_band(spec, y)
	var t: float = clampf((y - float(band["y0"])) / maxf(float(band["y1"]) - float(band["y0"]), 0.001), 0.0, 1.0)
	var r: float = lerpf(float(band["r0"]), float(band["r1"]), t)
	return 2.0 * r * sin(PI / float(band["sides"]))


## The wall face an opening at plan angle `angle` (atan2(z, x), the angle
## `MeshKit.revolve` uses) and height `y` belongs on: the centre of the
## nearest face, ON its plane, with that face's outward normal -- tipped up by
## the batter -- and the direction up the face. A square burr's faces are flat
## and vertical, at its own yaw.
static func wall_face(spec: WindmillSpec, angle: float, y: float) -> Dictionary:
	if is_square(spec):
		var yaw := Basis(Vector3.UP, spec.body_yaw)
		var local: Vector3 = yaw.inverse() * Vector3(cos(angle), 0.0, sin(angle))
		var axis := Vector3(signf(local.x), 0.0, 0.0) if absf(local.x) > absf(local.z) \
			else Vector3(0.0, 0.0, signf(local.z) if local.z != 0.0 else -1.0)
		var n: Vector3 = yaw * axis
		var out_r: float = spec.base_r + board_proud(spec)
		return {"angle": atan2(n.z, n.x), "point": n * out_r + Vector3(0.0, y, 0.0),
			"normal": n, "up": Vector3.UP, "width": spec.base_r * 2.0}
	var band: Dictionary = drum_band(spec, y)
	var n_sides: int = int(band["sides"])
	var step: float = TAU / float(n_sides)
	var start: float = drum_start(n_sides)
	var k: float = round((angle - start) / step - 0.5)
	var a: float = start + step * (k + 0.5)
	var half: float = PI / float(n_sides)
	var y0: float = float(band["y0"])
	var y1: float = float(band["y1"])
	var t: float = clampf((y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
	var r: float = lerpf(float(band["r0"]), float(band["r1"]), t)
	# the apothem's change per metre up the drum: negative on a battered wall
	var slope: float = (float(band["r1"]) - float(band["r0"])) / maxf(y1 - y0, 0.001) * cos(half)
	var out := Vector3(cos(a), 0.0, sin(a))
	return {"angle": a, "point": out * (r * cos(half)) + Vector3(0.0, y, 0.0),
		"normal": (out - Vector3.UP * slope).normalized(),
		"up": (out * slope + Vector3.UP).normalized(),
		"width": 2.0 * r * sin(half)}


## How far `p` stands OUTSIDE the drawn wall (negative: inside it). Measured
## along the plan ray through `p`, against the polygon the drum really is.
static func wall_distance(spec: WindmillSpec, p: Vector3) -> float:
	if is_square(spec):
		var local: Vector3 = Basis(Vector3.UP, spec.body_yaw).inverse() * p
		return maxf(absf(local.x), absf(local.z)) - (spec.base_r + board_proud(spec))
	var band: Dictionary = drum_band(spec, p.y)
	var n_sides: int = int(band["sides"])
	var step: float = TAU / float(n_sides)
	var start: float = drum_start(n_sides)
	var angle: float = atan2(p.z, p.x)
	var k: float = floor((angle - start) / step)
	var centre: float = start + step * (k + 0.5)
	var t: float = clampf((p.y - float(band["y0"])) / maxf(float(band["y1"]) - float(band["y0"]), 0.001), 0.0, 1.0)
	var r: float = lerpf(float(band["r0"]), float(band["r1"]), t)
	var half: float = PI / float(n_sides)
	var radius_here: float = r * cos(half) / maxf(cos(angle - centre), 0.01)
	return Vector2(p.x, p.z).length() - radius_here


static func door_h(spec: WindmillSpec) -> float:
	return minf(spec.door_h, maxf(spec.height * 0.78, 1.4))


# ------------------------------------------------------------------- the cap

## A cap is a little wider than the curb it turns on -- it has to overhang it
## or the weather gets in at the joint.
static func cap_radius_for(curb_r: float) -> float:
	return curb_r + 0.45


static func cap_height_for(cap: StringName, curb_r: float) -> float:
	match cap:
		&"dome":
			return curb_r * 0.95
		&"ogee":
			return curb_r * 1.25
		&"crown":
			return curb_r * 0.70
		&"flat":
			return curb_r * 0.22
	return 0.0


## The cap's silhouette as (radius, height) pairs, base to crown, which is what
## `MeshKit.revolve` wants. This is where a dome stops being a cone: the
## quarter-circle, the S of an ogee and the bell of a crown are four different
## curves and the difference is the whole difference between three mills.
static func cap_profile(spec: WindmillSpec) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r: float = maxf(spec.cap_r, 0.05)
	var h: float = maxf(spec.cap_h, 0.02)
	match spec.cap:
		&"dome":
			out.append(Vector2(r, 0.0))
			for i in range(1, 7):
				var a: float = (PI * 0.5) * float(i) / 6.0
				out.append(Vector2(r * cos(a), h * sin(a)))
		&"ogee":
			# the lower half swells out before the upper half turns in
			out.append(Vector2(r, 0.0))
			for i in range(1, 4):
				var a2: float = (PI * 0.5) * float(i) / 4.0
				out.append(Vector2(r * (1.0 - 0.12 * sin(a2)), h * 0.42 * sin(a2)))
			for i2 in range(1, 5):
				var a3: float = (PI * 0.5) * float(i2) / 5.0
				out.append(Vector2(r * 0.88 * cos(a3), h * (0.42 + 0.58 * sin(a3))))
		&"crown":
			# a bell: it springs out faster than a dome and turns in early
			out.append(Vector2(r, 0.0))
			for i3 in range(1, 5):
				var a4: float = (PI * 0.5) * float(i3) / 5.0
				out.append(Vector2(r * (1.0 - 0.35 * sin(a4)), h * sin(a4)))
		_:
			out.append(Vector2(r, 0.0))
			out.append(Vector2(r * 0.92, h))
			out.append(Vector2(0.0, h))
	return out


# --------------------------------------------------------------------- the rotor

## The windshaft's centre. Everything about the rotor hangs off this one point:
## the sail plane's distance from it, the tip circle, the tail behind it and the
## stage under it.
static func axle_point(spec: WindmillSpec) -> Vector3:
	match spec.mill_type:
		&"post":
			# through the burr's front wall, a little above its own floor
			return Vector3(0.0, floor_y(spec) + spec.height * 0.62, -spec.stage_r)
		&"windpump":
			return head_basis(spec) * Vector3(0.0, spec.head_r * HEAD_REACH, 0.0) \
				+ Vector3(0.0, top_y(spec), 0.0)
		&"paddle":
			return wheel_axle(spec)
	# a mill that stands and is turned by its cap: the shaft emerges from the
	# cap's front, a little below its crown
	return Vector3(0.0, top_y(spec) + spec.cap_h * 0.28, -spec.stage_r)


## A windpump's head turns about a collar on top of the lattice, and its axle
## is tipped back into the wind by `tilt`. Everything on the head -- fan, star
## wheel, vane -- is drawn in this frame and nowhere else.
static func head_basis(spec: WindmillSpec) -> Basis:
	return Basis(Vector3.RIGHT, -spec.tilt)


static func head_origin(spec: WindmillSpec) -> Vector3:
	return Vector3(0.0, top_y(spec), 0.0)


## The plane the sails sweep in, as a Z. The stock's outer face.
static func sail_plane(spec: WindmillSpec) -> float:
	return -spec.stage_r


## One sail's direction from the shaft, as an angle from straight up. The rotor
## is a flat wheel in the XY plane; a windpump's fan is the same wheel.
static func sail_direction(angle: float) -> Vector3:
	return Vector3(sin(angle), cos(angle), 0.0)


## Where each sail points. A mill that has stopped with a sail straight down
## reads as broken, so the generator picks the resting angle and every rule
## below is measured against the true worst of these.
static func sail_angles(spec: WindmillSpec) -> Array[float]:
	var out: Array[float] = []
	var n: int = maxi(spec.sails, 3)
	for i in range(n):
		out.append(spec.sail_angle + TAU * float(i) / float(n))
	return out


## One sail's tip, in world space.
static func tip_point(spec: WindmillSpec, angle: float) -> Vector3:
	return axle_point(spec) + sail_direction(angle) * spec.sail_r


## The lowest point the rotor actually reaches. A four-sailed mill stopped at
## an angle has one sail lower than the circle's bottom, and a mill stopped with
## a sail vertical has one exactly at it -- so this samples the real sails
## rather than assuming the worst case is always reached.
static func lowest_tip(spec: WindmillSpec) -> float:
	var axle: Vector3 = axle_point(spec)
	if spec.mill_type == &"windpump":
		return axle.y - spec.sail_r      # a fan is a disc, not a cross
	if spec.mill_type == &"paddle":
		return axle.y - spec.wheel_r      # a scoop wheel in the race
	var worst: float = axle.y - spec.sail_r
	for a in sail_angles(spec):
		worst = minf(worst, axle.y + cos(a) * spec.sail_r)
	return worst


## How far the lowest sail point clears the ground it passes over. Negative
## means the mill would drag.
static func tip_clearance(spec: WindmillSpec) -> float:
	return lowest_tip(spec) - ground_under(spec)


## How far the sail plane stands in front of the cap's widest point. A tower or
## smock mill with its rotor inside its own cap is a mill whose sails cannot
## turn, so this is the rule that fixes the stage.
static func cap_clearance(spec: WindmillSpec) -> float:
	if spec.mill_type in [&"post", &"windpump", &"paddle"]:
		return INF
	return spec.stage_r - spec.cap_r


## How far the stock stands off the mill's own face to reach the sail plane.
## This is what decides where the sail plane is, and it is the single number a
## miller would recognise from the ground.
static func stock_stand_off(spec: WindmillSpec) -> float:
	if is_square(spec):
		return spec.stage_r - spec.base_r
	return spec.stage_r - spec.curb_r

## The stage's own height: the deck the miller stands on to reef a sail, which
## is a step or two below the shaft and inside the sail circle.
static func stage_y(spec: WindmillSpec) -> float:
	if not has_stage(spec):
		return 0.0
	return spec.stage_y


## Where the stage's deck ends, towards the mill.
static func stage_inner_r(spec: WindmillSpec) -> float:
	return spec.stage_r - STAGE_WIDTH


## A stock ladder stands beside the mill so the sails pass it. This is how far
## off the axis it has to be, and it is not a free choice: a ladder inside the
## sail's own circle is a ladder the sails hit.
static func ladder_offset_for(spec: WindmillSpec) -> float:
	return maxf(spec.stage_r + spec.sail_width * 0.5 + LADDER_CLEAR,
		spec.base_r + spec.ladder_w * 0.5 + LADDER_CLEAR)


# ------------------------------------------------------------- openings and access

## Where the door is: on the front wall, at the height the floor stands at.
## A post mill's door is off the axis, because its ladder is, and the ladder has
## to be off the axis so the sails clear it.
static func door_point(spec: WindmillSpec) -> Vector3:
	# A post mill's whole burr turns into the wind, so its door is on a wall
	# that is no longer square to anything. This is where that door actually
	# ends up -- and it is the only place a caller wanting to walk up to it can
	# be sent. The rotation is about Y alone, which is what the builder does.
	var here: Vector3 = Basis(Vector3.UP, spec.body_yaw) \
		* Vector3(spec.door_offset_x, 0.0, -spec.base_r)
	return here + Vector3(0.0, floor_y(spec) + door_h(spec) * 0.5, 0.0)


## The stock ladder, in plan: its own width, standing beside the mill.
static func ladder_rect(spec: WindmillSpec) -> Rect2:
	var half: float = spec.ladder_w * 0.5
	return Rect2(Vector2(spec.ladder_offset - half, -spec.base_r - spec.ladder_run),
		Vector2(spec.ladder_w, spec.ladder_run))


## How far out in front of the mill's own face the ladder's foot stands. A
## stock ladder is steep -- a miller climbs it twice a day -- and this is what
## keeps it steep instead of letting it lie down on the mound.
static func ladder_run_for(spec: WindmillSpec) -> float:
	return spec.base_r + spec.ladder_run




# ------------------------------------------------------------------ the tail

## The tail is what turns the mill, and the only reason it is not a statue. It
## reaches behind the body far enough that a hand on it can turn the thing --
## which on a post mill means the whole body, and on a cap mill means the cap's
## own weight.
static func tail_root(spec: WindmillSpec) -> Vector3:
	var axle: Vector3 = axle_point(spec)
	if spec.mill_type == &"post":
		# a post mill's tailpole leaves the burr's back wall at its own floor
		return Vector3(0.0, floor_y(spec) + spec.height * 0.55, spec.base_r)
	return Vector3(0.0, axle.y - spec.cap_h * 0.16, -spec.cap_r * 0.45)


static func tail_tip(spec: WindmillSpec) -> Vector3:
	return tail_root(spec) + Vector3(0.0, -sin(spec.tail_drop), cos(spec.tail_drop)) * spec.tail


## A cap mill that carries a fantail turns itself; one that does not, a rope
## from the cap to a winch on the ground turns it. Either way the tail has to
## reach past the mill's own body to be the thing doing the turning.
static func tail_reach_ratio(spec: WindmillSpec) -> float:
	return spec.tail / maxf(spec.base_r, 0.01)


# ------------------------------------------------------------- the polder wheel

## A paddle mill's wheel is a rotor turned by water instead of wind, and it
## lives at the mill's foot on the front side, standing in its own race.
## The wheel stands clear of the bed and dips its buckets into the flow. An
## undershot wheel works because the current pushes them round, and one that
## stood on the bed would be a waterwheel nobody bothered to build.
static func wheel_axle(spec: WindmillSpec) -> Vector3:
	return Vector3(0.0, spec.wheel_r - spec.race_depth * 0.75,
		-spec.base_r - spec.wheel_width * 0.5 - 0.35)


## How much of the wheel stands under water. An undershot wheel works because
## the current pushes its buckets round, so it has to stand in the water and
## not on the bed of it.
static func water_level(spec: WindmillSpec) -> float:
	return -spec.race_depth * 0.30


## The channel the wheel turns in, in plan: the near end is at the wheel.
static func race_rect(spec: WindmillSpec) -> Rect2:
	var half: float = spec.race_w * 0.5
	return Rect2(Vector2(-half, wheel_axle(spec).z - spec.race_len),
		Vector2(spec.race_w, spec.race_len))


## The wheel's own width, across the race.
static func race_z(spec: WindmillSpec) -> Vector2:
	var r: Rect2 = race_rect(spec)
	return Vector2(r.position.y, r.end.y)


static func wheel_z_front(spec: WindmillSpec) -> float:
	return wheel_axle(spec).z - spec.wheel_width * 0.5


# ----------------------------------------------------------- the windpump's gear

## The star wheel's teeth, and therefore its radius. A real windpump's fan turns
## fast and its pump turns slowly, and this gear is the reason.
static func star_radius(spec: WindmillSpec) -> float:
	return maxf(spec.sail_r * 0.17, 0.3)


## Where the crank pin stands, at the star wheel's own radius. The rod hangs
## from here down the tower to the pump.
static func crank_pin(spec: WindmillSpec) -> Vector3:
	var basis := head_basis(spec)
	var axle: Vector3 = axle_point(spec)
	return axle + basis * Vector3(0.0, -star_radius(spec),
		-(star_radius(spec) + spec.head_r * 0.3))


## The pump a windpump exists to drive, and the spout its water leaves by.
static func pump_point(spec: WindmillSpec) -> Vector3:
	return Vector3(spec.base_r * 0.9, 0.0, -spec.base_r * 0.9)


# ----------------------------------------------------------------- the envelope

## What the drawn mill is allowed to occupy, plus the tolerance a beam's own
## section needs at its ends. Deliberately exact at the rotor -- which is the
## part a caller sized -- and generous everywhere else, because a mill with a
## tailpole is a long thin thing and its corners are not interesting.
static func envelope(spec: WindmillSpec) -> AABB:
	# Every member is a beam, and a beam is a little longer than the gap it
	# spans, so the envelope carries a half-metre of tolerance for its ends.
	var half_x: float = spec.sail_r + spec.sail_width * 0.5 + 0.2
	half_x = maxf(half_x, absf(spec.ladder_offset) + spec.ladder_w + 0.2)
	half_x = maxf(half_x, spec.cap_r + 0.2)
	half_x = maxf(half_x, spec.base_r + GALLERY_WIDTH + 0.3)
	half_x = maxf(half_x, spec.mound_r + 0.2)
	if spec.mill_type == &"paddle":
		half_x = maxf(maxf(half_x, spec.wheel_r), spec.race_w) + 0.2
	if spec.mill_type == &"windpump":
		half_x = maxf(half_x, spec.tail * 0.35)

	var axle: Vector3 = axle_point(spec)
	var top: float = maxf(body_top(spec) + 0.3, floor_y(spec) + spec.height)
	top = maxf(top, axle.y + spec.sail_r + 0.2)
	if has_gallery(spec):
		# a gallery carries a rail, and the rail is the highest thing on the mill
		# short of its own sails
		top = maxf(top, spec.curb_y + RAIL_H + 0.15)
	var back: float = spec.base_r + 0.4
	# the mound is wider than the mill standing on it, and it is at the front
	var front: float = minf(sail_plane(spec) - 0.45, -spec.mound_r - 0.2)
	if has_tail(spec):
		top = maxf(top, tail_root(spec).y + 0.4)
		back = maxf(back, tail_tip(spec).z + 0.5)
	if spec.mill_type == &"windpump":
		# the head turns, so it has no tailpole; what it has instead is a boom
		# behind the fan and a pump and spout at the foot in front of it
		front = minf(front, pump_point(spec).z - spec.base_r - 0.7)
		back = maxf(back, axle.z + spec.tail + 0.5)
	var bottom: float = -0.3
	if spec.mill_type == &"paddle":
		front = minf(front, race_rect(spec).position.y - 0.4)
		bottom = minf(bottom, -spec.race_depth - 0.35)
	return AABB(Vector3(-half_x, bottom, front),
		Vector3(half_x * 2.0, top - bottom, back - front))


## The highest fixed point of the body: a cap's crown, or a post mill's lean-to
## roof. This is what the envelope's ceiling is measured from.
static func body_top(spec: WindmillSpec) -> float:
	if spec.mill_type == &"post":
		return spec.curb_y + POST_ROOF_RISE
	return spec.curb_y + spec.cap_h


## A post mill's mound is a truncated cone, so what the ladder's foot stands on
## depends on how far out it is. This is that slope.
static func mound_height_at(spec: WindmillSpec, radius: float) -> float:
	if spec.mound_h <= 0.0:
		return 0.0
	if radius <= spec.mound_r * 0.45:
		return spec.mound_h
	var t: float = clampf((radius / maxf(spec.mound_r, 0.01) - 0.45) / 0.55, 0.0, 1.0)
	return spec.mound_h * (1.0 - t)


## Where the ladder's foot stands: on the mound it climbs, or on the ground.
static func ladder_foot_y(spec: WindmillSpec) -> float:
	if not spec.ladder:
		return 0.0
	return mound_height_at(spec, ladder_foot_radius(spec))


## The plan a lot planner must keep: the mill's own body.
##
## A polder mill's RACE is not in here. It is a channel cut into the ground in
## front of the door, so folding it in would drag this rectangle's -Z edge away
## from the door it is supposed to be the front of -- and the door contract is
## worth more than the convenience. `race_site()` is published beside the
## placement instead, which is where a lot finds out about it.
static func site_rect(spec: WindmillSpec) -> Rect2:
	if is_square(spec):
		# a post mill's burr is square and stands at its own yaw, so its plan is
		# the four TURNED corners. The accumulator cannot use `size ==
		# Vector2.ZERO` to mean "nothing yet": a rectangle holding one point also
		# has zero size, so that test throws the first corner away every time.
		# Same trap as `AABB.merge`, different shape -- a flag is the fix.
		var body := Basis(Vector3.UP, spec.body_yaw)
		var out := Rect2()
		var started := false
		for corner in [body * Vector3(-spec.base_r, 0.0, -spec.base_r),
				body * Vector3(spec.base_r, 0.0, -spec.base_r),
				body * Vector3(spec.base_r, 0.0, spec.base_r),
				body * Vector3(-spec.base_r, 0.0, spec.base_r)]:
			var p := Vector2(corner.x, corner.z)
			out = Rect2(p, Vector2.ZERO) if not started else out.expand(p)
			started = true
		return out
	return Rect2(Vector2(-spec.base_r, -spec.base_r),
		Vector2(spec.base_r * 2.0, spec.base_r * 2.0))


## The ground a polder mill needs and does not own: its race. Empty for every
## other mill, which is why it is placement metadata rather than part of the
## footprint.
static func race_site(spec: WindmillSpec) -> Rect2:
	if spec.mill_type != &"paddle":
		return Rect2()
	var race: Rect2 = race_rect(spec)
	return Rect2(Vector2(race.position.x, race.position.y - 0.5),
		Vector2(spec.race_w, race.size.y + 0.5))


# --------------------------------------------------------- the generator's clamp

## What this type will actually accept, from the three numbers a caller gave
## it, before anything else is decided. A windpump asked for a 20 m sail span
## is answered with a fan it can really turn -- and the clamp is done here, on
## the type's own row, rather than in the generator where it would be a rule
## only this file could see.
static func legal(spec: WindmillSpec) -> Dictionary:
	var r: Dictionary = row(spec)
	var band: Array = r.get("span", [0.85, 1.6])
	var body_r: float = clampf(maxf(spec.body, 1.0) * 0.5,
		float(r["body_r"][0]), float(r["body_r"][1]))
	var height: float = clampf(spec.height, float(r["height"][0]), float(r["height"][1]))
	var lo: float = body_r * float(band[0]) * 2.0
	var hi: float = body_r * float(band[1]) * 2.0
	if spec.mill_type in [&"tower", &"smock"]:
		# A cap mill's sails are sized to its TOWER, not to its foot: a real
		# tower mill's sails span roughly the tower's height or more, and a
		# rotor held to a multiple of the base radius read as a toy on a tall
		# drum. The smock's brick stump is under its frame, so it counts.
		var tall: float = height + (STUMP_H[1] if spec.mill_type == &"smock" else 0.0)
		lo = maxf(lo, tall * SPAN_PER_HEIGHT)
		hi = maxf(hi, tall * SPAN_PER_HEIGHT_MAX)
	var span: float = clampf(maxf(spec.sail_span, 2.0), lo, hi)
	return {"sail_span": span, "body": body_r * 2.0, "height": height,
		"base_r": body_r}


## How high the body's floor has to stand for this rotor to clear the ground.
## For a post mill this is the height of the post; for a tower mill it is the
## height of the tower above its own cap. It is the one equation a miller
## actually solved, and getting it wrong is why a mill's sails dragged in the
## grass and got taken down.
static func required_floor_y(spec: WindmillSpec) -> float:
	var axle_above: float = spec.height * 0.62 if spec.mill_type == &"post" \
		else spec.head_r * HEAD_REACH
	var cap_above: float = cap_height_for(spec.cap, spec.curb_r) * 0.28 \
		if spec.mill_type not in [&"post", &"windpump"] else 0.0
	return spec.sail_r + ground_under(spec) + TIP_CLEAR - cap_above - axle_above