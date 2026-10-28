class_name HouseNewel
extends RefCounted
## A newel (spiral) stair as the plan records it (CASTLE-NEWEL-STAIR).
##
## A straight flight needs a run of storey height over tan 42 degrees: 4.0 m for
## a 3.6 m storey. A mural tower 4.7 m across, or a 3.8 m bergfried keep, has no
## such run, and its straight flight stood at 56 to 70 degrees. Real towers use
## a newel: wedge treads wound round a central post. The record keeps the usual
## stair fields (`rect` is the square well, `foot_landing` / `head_landing` the
## floor at either end, `climb` which way) so every rect-based consumer still
## works, and adds
##
##   kind    &"newel"
##   centre  Vector2, the post
##   radius  float, centre to outer edge of the treads (the well is 2 * radius)
##   hub     float, radius of the post
##   sweep   degrees turned from the first tread to the last: a whole number of
##           turns (the walker leaves on the side he entered) or a half more
##           (he leaves on the far side). The shortest sweep that is no steeper
##           than 41 degrees and keeps 2 * riser + going inside the stride.
##   spin    +1 clockwise seen from above, -1 anticlockwise
##   steps   risers in the storey
##
## The walker climbs along the walking line, two thirds of the way out along the
## tread, and that is where pitch is measured.

const KIND := &"newel"
const HUB := 0.12
const SWEEP := 360.0
## The sweeps a plan may choose, shortest first: a turn, a turn and a half, two
## turns, two and a half (a 6.75 m keep storey needs two).
const SWEEPS: Array[float] = [360.0, 540.0, 720.0, 900.0]
const RADII: Array[float] = [1.1, 1.0, 0.95, 0.9, 0.85]
## The narrowest tread (outer edge to the post) a person can climb.
const TREAD_MIN := 0.6
const TREAD_THICK := 0.16
const FOOT_DEPTH := 0.7
const HEAD_DEPTH := 0.7
## Mirrors of CastleKeepPlan.PITCH_TARGET and HouseStairCheck's GOING_MIN / STRIDE_MAX
## (named here to keep the three classes from referring to each other).
const PITCH_TARGET := 41.0
const GOING_MIN := 0.22
const STRIDE_MAX := 0.70


static func is_newel(st: Dictionary) -> bool:
	return st.get("kind", &"") == KIND


## Radius of the walking line.
static func line_radius(st: Dictionary) -> float:
	var hub := float(st.get("hub", HUB))
	return hub + (float(st["radius"]) - hub) * 2.0 / 3.0


## Length of the walking line from the first tread to the last.
static func line_length(st: Dictionary) -> float:
	return line_radius(st) * deg_to_rad(float(st.get("sweep", SWEEP)))


## Angle (radians) of the entry side: the foot landing lies north (-z) of a
## climb of +1 and south of a climb of -1. Position = centre + r * (cos, sin).
static func entry_angle(st: Dictionary) -> float:
	return -PI * 0.5 if float(st.get("climb", 1.0)) >= 0.0 else PI * 0.5


## Angle at the start of step `s`, radians.
static func step_angle(st: Dictionary, s: int) -> float:
	var steps := maxi(1, int(st.get("steps", 18)))
	return entry_angle(st) + float(st.get("spin", 1.0)) \
		* deg_to_rad(float(st.get("sweep", SWEEP))) * float(s) / float(steps)


## The wedge of step `s` as a plan polygon (inner, inner, outer, outer).
static func step_polygon(st: Dictionary, s: int) -> PackedVector2Array:
	var c: Vector2 = st["centre"]
	var a0 := step_angle(st, s)
	var a1 := step_angle(st, s + 1)
	var hub := float(st.get("hub", HUB))
	var r := float(st["radius"])
	return PackedVector2Array([
		c + Vector2(cos(a0), sin(a0)) * hub, c + Vector2(cos(a0), sin(a0)) * r,
		c + Vector2(cos(a1), sin(a1)) * r, c + Vector2(cos(a1), sin(a1)) * hub])


## Which steps of the stair lie over plan point `p`, lowest first.
static func steps_over(st: Dictionary, p: Vector2) -> Array[int]:
	var out: Array[int] = []
	var c: Vector2 = st["centre"]
	var d := p - c
	if d.length() < float(st.get("hub", HUB)) or d.length() > float(st["radius"]) * 1.5:
		return out
	var steps := maxi(1, int(st.get("steps", 18)))
	var spin := float(st.get("spin", 1.0))
	var turned := fposmod((d.angle() - entry_angle(st)) * spin, TAU)
	var sweep := deg_to_rad(float(st.get("sweep", SWEEP)))
	var s0 := int(turned / sweep * float(steps))
	var per_turn := float(steps) * TAU / sweep
	var k := 0
	while true:
		var s := s0 + int(round(float(k) * per_turn))
		if s >= steps:
			break
		out.append(s)
		k += 1
	return out


## Pitch of the walking line in degrees.
static func pitch(height: float, st: Dictionary) -> float:
	return rad_to_deg(atan2(height, line_length(st)))


## Can radius `radius` wound through `sweep` degrees climb `height` in `steps`
## risers: a walking line no steeper than the castle's target, and a going that
## keeps 2 * riser + going inside the stride and the tread no shorter than a foot?
static func climbable(height: float, steps: int, radius: float, sweep: float) -> bool:
	var probe := {"radius": radius, "hub": HUB, "sweep": sweep}
	var riser := height / float(steps)
	var going := line_length(probe) / float(steps)
	return pitch(height, probe) <= PITCH_TARGET and going >= GOING_MIN and 2.0 * riser + going <= STRIDE_MAX
