class_name WindmillBuilder
extends MassBuilder
## WindmillSpec -> ArrayMesh, and the three logs the QA harness measures.
##
## Five buildings in one emitter, and the split is not decoration: each one is
## a different machine, so each is drawn the way that machine is built.
##
##   tower / smock   a drum with a batter, a cap that turns on a curb, a stage
##                   on the front, and a windshaft out through the cap
##   post            a box on a stick, a mound under the stick, a ladder up to
##                   a door that stands clear of the sails
##   windpump        a lattice tower, a fan of blades, a vane, and a rod from
##                   the star wheel down to a pump
##   paddle          a tower, a scoop wheel in a race, and no sails at all
##
## Everything is drawn through `component_box` / `component_slab` where the kit
## has a shape for it, and `component_note` where it does not -- so every
## quarter of this file is checkable by `qa/component_check.gd`, which re-emits
## the log and demands the mesh contain exactly those triangles.

## The five surfaces, in the order `BuildingFamilyAdapter.colours()` names them.
## Water is LAST on purpose: a mill with no race has an empty trailing surface,
## which moves nothing, where a hole in the middle would shift every later
## slot and break the component log's surface indices against the mesh.
const SURF_WALL := 0   ## masonry, weatherboarding, lattice, the body itself
const SURF_TRIM := 1   ## iron: gearing, wheels, the frame of every sail
const SURF_SAIL := 2   ## cloth, thatch, and any painted panel that catches wind
const SURF_DARK := 3   ## doorways, window slits, the dark inside
const SURF_WATER := 4  ## the race a paddle mill turns in

## How many bars a sail carries between its stock and its tip.
const SAIL_BARS := 5
## A mill's door and window frames are set proud of the wall by this much, so
## the opening never fights the masonry it is cut into.
const OPENING_LIFT := 0.012
const CLOTH_T := 0.045
const RAIL_T := 0.07
## A tower mill's slit window.
const WINDOW_W := 0.26
const WINDOW_H := 0.72

var spec: WindmillSpec


func build(p_spec: WindmillSpec) -> ArrayMesh:
	spec = p_spec
	begin(WindmillGeometry.SURFACE_COUNT)
	_ground()
	match spec.mill_type:
		&"tower", &"paddle":
			_drum_body()
		&"smock":
			_smock_body()
		&"post":
			_post_body()
		&"windpump":
			_lattice_body()
	_openings()
	_cap_or_head()
	if WindmillGeometry.has_stage(spec):
		_stage()
	if WindmillGeometry.has_gallery(spec):
		_gallery()
	_rotor()
	_tail()
	if spec.cranked:
		_windpump_gear()
	if spec.ladder:
		_stock_ladder()
	total_height = WindmillGeometry.envelope(spec).end.y
	return commit_named()


# ----------------------------------------------------------------- the ground

## What the mill stands on. A post mill stands on a mound because a post mill's
## post is short and a miller cannot climb six metres of ladder twice a day; a
## paddle mill stands in a race because that is where its work is.
func _ground() -> void:
	if spec.mill_type == &"paddle":
		_race()
		return
	if spec.mill_type != &"post":
		return
	tag("ground")
	if spec.trestle:
		_trestle()
		return
	host("ground")
	var mound := PackedVector2Array([Vector2(spec.mound_r, 0.0),
		Vector2(spec.mound_r * 0.72, spec.mound_h * 0.62),
		Vector2(spec.mound_r * 0.45, spec.mound_h)])
	_kit.revolve(mound, Vector3.ZERO, SURF_WALL, 14)
	component_note("mound", "revolve", SURF_WALL, {"profile": mound,
		"center": Vector3.ZERO, "segments": 14,
		"aabb": AABB(Vector3(-spec.mound_r, 0.0, -spec.mound_r),
			Vector3(spec.mound_r * 2.0, spec.mound_h, spec.mound_r * 2.0))})
	# a kerb round the top, because a mound of loose rubble wears a course of
	# stone round its edge and that course is what holds it up
	_kit.balcony_ring(spec.mound_r * 0.62, spec.mound_r * 0.5, spec.mound_h, TAU,
		SURF_WALL, Vector2.ZERO, 0.0, 0.22, 14)
	_log_mass("mound", AABB(Vector3(-spec.mound_r, 0.0, -spec.mound_r),
		Vector3(spec.mound_r * 2.0, spec.mound_h, spec.mound_r * 2.0)))


## A post mill's alternative foundation: four splayed legs and a cross of
## braces, which is what a mill on flat ground got.
func _trestle() -> void:
	host("ground")
	var top: float = WindmillGeometry.floor_y(spec) - spec.mound_h
	var spread: float = spec.base_r * 1.5
	var legs := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for i in range(4):
		var a: Vector3 = Vector3(legs[i].x * spread, 0.0, legs[i].z * spread)
		var b: Vector3 = Vector3(legs[i].x * spec.base_r * 0.9, top,
			legs[i].z * spec.base_r * 0.9)
		_beam(a, b, 0.34, 0.34, SURF_WALL, "trestle_leg")
	for i2 in range(4):
		var p: Vector3 = legs[i2]
		var q: Vector3 = legs[(i2 + 1) % 4]
		var lo := Vector3(p.x * spec.base_r * 0.9, top * 0.35, p.z * spec.base_r * 0.9)
		var hi := Vector3(q.x * spec.base_r * 0.9, top, q.z * spec.base_r * 0.9)
		_beam(lo, hi, 0.2, 0.2, SURF_WALL, "trestle_brace")
	_log_mass("trestle", AABB(Vector3(-spread, 0.0, -spread),
		Vector3(spread * 2.0, top, spread * 2.0)))


## A paddle mill's race: a stone channel cut in front of it, with the water in
## it. The wheel is an UNDERSHOT wheel, so the current has to arrive along the
## floor of the channel and push its buckets round from below.
func _race() -> void:
	tag("race")
	host("race")
	var r: Rect2 = WindmillGeometry.race_rect(spec)
	var near: float = r.end.y
	var far: float = r.position.y
	var depth: float = spec.race_depth
	var bed := Vector3(spec.race_w, 0.3, near - far)
	component_box("race_bed", bed,
		Transform3D(Basis(), Vector3(0.0, -depth - 0.15, (near + far) * 0.5)), SURF_WALL)
	for side in [-1.0, 1.0]:
		var kerb := Vector3(0.4, depth + 0.45, near - far)
		component_box("race_kerb", kerb, Transform3D(Basis(),
			Vector3(side * (spec.race_w * 0.5 + 0.2), -depth * 0.5 + 0.225,
				(near + far) * 0.5)), SURF_WALL)
	# the undershot lip the current comes over
	component_box("race_sill", Vector3(spec.race_w, 0.34, 0.5), Transform3D(Basis(),
		Vector3(0.0, -depth + 0.17, near - 0.3)), SURF_WALL)
	# the sluice that lets the water in, at the far end
	for side2 in [-1.0, 1.0]:
		component_box("sluice_post", Vector3(0.32, depth + 1.5, 0.32),
			Transform3D(Basis(), Vector3(side2 * spec.race_w * 0.5, 0.4, far + 0.2)),
			SURF_WALL)
	component_box("sluice_beam", Vector3(spec.race_w + 0.6, 0.3, 0.36),
		Transform3D(Basis(), Vector3(0.0, 1.28, far + 0.2)), SURF_WALL)
	# and the water itself
	var level: float = WindmillGeometry.water_level(spec)
	var water := PackedVector3Array([
		Vector3(-spec.race_w * 0.5, level, near), Vector3(spec.race_w * 0.5, level, near),
		Vector3(spec.race_w * 0.5, level, far), Vector3(-spec.race_w * 0.5, level, far)])
	component_slab("race_water", water, 0.02, SURF_WATER, false)
	_log_mass("race", AABB(Vector3(-spec.race_w * 0.7, -depth, far),
		Vector3(spec.race_w * 1.4, depth + 0.5, near - far)))


# ----------------------------------------------------------------- the bodies

## A masonry drum with a batter, which is a tower mill and a polder mill alike.
func _drum_body() -> void:
	tag("body")
	host("body")
	var t: float = spec.wall_t
	var box := _tapered_drum(0.0, spec.base_r, spec.curb_r, spec.curb_y, t,
		SURF_WALL, WindmillGeometry.sides(spec))
	_log_mass("tower", box)
	# the curb the cap turns on: a ring of iron, proud of the wall
	_kit.balcony_ring(spec.curb_r + 0.12, 0.24, spec.curb_y, TAU, SURF_TRIM,
		Vector2.ZERO, WindmillGeometry.drum_start(WindmillGeometry.sides(spec)), 0.26,
		WindmillGeometry.sides(spec))
	component_note("curb", "ring", SURF_TRIM,
		{"aabb": AABB(Vector3(-spec.curb_r, spec.curb_y - 0.05, -spec.curb_r),
			Vector3(spec.curb_r * 2.0, 0.3, spec.curb_r * 2.0))})


## A smock mill's body: a low brick stump, then a weatherboarded frame over it.
func _smock_body() -> void:
	tag("body")
	host("body")
	var stump := _tapered_drum(0.0, spec.base_r, spec.base_r * 0.96, spec.stump_h,
		spec.wall_t, SURF_WALL, WindmillGeometry.SIDES_ROUND)
	_log_mass("stump", stump)
	host("frame")
	var frame := _tapered_drum(spec.stump_h, spec.base_r * 0.96, spec.curb_r,
		spec.height, spec.wall_t, SURF_WALL, WindmillGeometry.SIDES_SMOCK)
	_log_mass("smock_frame", frame)
	# the frame's corner posts and its mid rail, standing proud of the boards.
	# A smock mill is a timber skeleton with weatherboards nailed to it, and
	# without the skeleton it is a smooth cone.
	var sides: int = WindmillGeometry.SIDES_SMOCK
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides) + PI / float(sides)
		var r0: float = spec.base_r * 0.96
		var r1: float = spec.curb_r
		_beam(Vector3(cos(a) * r0, spec.stump_h, sin(a) * r0),
			Vector3(cos(a) * r1, spec.curb_y, sin(a) * r1), 0.17, 0.17,
			SURF_WALL, "frame_post")
		var mid: float = lerpf(spec.stump_h, spec.curb_y, 0.45)
		_beam(Vector3(cos(a) * lerpf(r0, r1, 0.45) + 0.03, mid,
			sin(a) * lerpf(r0, r1, 0.45) + 0.03),
			Vector3(cos(a) * lerpf(r0, r1, 0.62) + 0.03,
				lerpf(spec.stump_h, spec.curb_y, 0.62),
				sin(a) * lerpf(r0, r1, 0.62) + 0.03), 0.11, 0.11,
			SURF_WALL, "frame_brace")


## A post mill's body: a square burr of boards, and the post under it.
func _post_body() -> void:
	tag("body")
	host("body")
	var floor: float = WindmillGeometry.floor_y(spec)
	# the post, on its own kerb, and the pinion wheel it turns on
	var post_w: float = 0.46
	var kerb: float = post_w * 1.5
	component_box("post_kerb", Vector3(kerb, 0.34, kerb), Transform3D(Basis(),
		Vector3(0.0, floor - 0.17, 0.0)), SURF_WALL)
	component_box("post", Vector3(post_w, floor, post_w), Transform3D(Basis(),
		Vector3(0.0, floor * 0.5, 0.0)), SURF_WALL)
	_toothed_wheel(Vector3(0.0, floor - 0.55, 0.0), Vector3.BACK, 0.5, 14, 0.14,
		SURF_TRIM, "post_pinion")
	_log_mass("post", AABB(Vector3(-post_w * 0.5, 0.0, -post_w * 0.5),
		Vector3(post_w, floor, post_w)))

	# the burr, as four boarded walls and a deck, standing at its own yaw
	var y := Basis(Vector3.UP, spec.body_yaw)
	var h: float = spec.height
	var r: float = spec.base_r
	var courses: int = maxi(int(h / 0.45), 2)
	for face in range(4):
		var dir: Vector3 = y * [Vector3.BACK, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.LEFT][face]
		var face_yaw: float = atan2(dir.x, dir.z)
		var at: Vector3 = Vector3(0.0, floor, 0.0) + dir * (r - spec.wall_t * 0.5)
		component_box("burr_wall", Vector3(r * 2.0, h, spec.wall_t),
			Transform3D(Basis(Vector3.UP, face_yaw), at + Vector3(0.0, h * 0.5, 0.0)),
			SURF_WALL)
		# the boarding lines, which are what make a burr read as boards
		for board in range(1, courses):
			component_box("burr_board", Vector3(r * 2.06, 0.05, spec.wall_t * 1.25),
				Transform3D(Basis(Vector3.UP, face_yaw),
					at + Vector3(0.0, h * float(board) / float(courses), 0.0)),
				SURF_TRIM)
	component_box("burr_deck", Vector3(r * 2.0, 0.22, r * 2.0),
		Transform3D(Basis(), Vector3(0.0, floor + h - 0.11, 0.0)), SURF_WALL)
	_log_mass("burr", AABB(Vector3(-r, floor, -r), Vector3(r * 2.0, h, r * 2.0)))

	# A post mill's roof is a single pitch and it drains towards the tail, so
	# the tailpole is not standing under a gutter.
	var eave: float = floor + h + 0.02
	var roof := PackedVector3Array([
		y * Vector3(-r - 0.14, eave + 0.55, -r - 0.14),
		y * Vector3(r + 0.14, eave + 0.55, -r - 0.14),
		y * Vector3(r + 0.14, eave, r + 0.14),
		y * Vector3(-r - 0.14, eave, r + 0.14)])
	component_slab("burr_roof", roof, 0.18, SURF_SAIL, false)
	_log_mass("burr_roof", AABB(Vector3(-r - 0.2, eave, -r - 0.2),
		Vector3((r + 0.2) * 2.0, 0.6, (r + 0.2) * 2.0)))


## A windpump's body: four legs and `braces` bays of X-bracing. It is the only
## one of the five that is mostly air, and that is the whole point of it.
func _lattice_body() -> void:
	tag("body")
	host("body")
	var legs := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	var top_r: float = spec.curb_r
	var foot: Array[Vector3] = []
	var head: Array[Vector3] = []
	for i in range(4):
		foot.append(Vector3(legs[i].x * spec.base_r, 0.0, legs[i].z * spec.base_r))
		head.append(Vector3(legs[i].x * top_r, spec.height, legs[i].z * top_r))
	for i2 in range(4):
		_beam(foot[i2], head[i2], 0.13, 0.13, SURF_WALL, "tower_leg")
	for bay in range(spec.braces + 1):
		var t: float = float(bay) / float(spec.braces)
		var ring: Array[Vector3] = []
		for i3 in range(4):
			ring.append(foot[i3].lerp(head[i3], t))
		for i4 in range(4):
			if bay > 0:
				_beam(ring[i4], ring[(i4 + 1) % 4], 0.09, 0.09, SURF_TRIM, "tower_ring")
		if bay < spec.braces:
			for i5 in range(4):
				var a: Vector3 = ring[i5]
				var b: Vector3 = ring[(i5 + 1) % 4]
				var an: Vector3 = foot[i5].lerp(head[i5], t + 1.0 / float(spec.braces))
				var bn: Vector3 = foot[(i5 + 1) % 4].lerp(head[(i5 + 1) % 4],
					t + 1.0 / float(spec.braces))
				_beam(a, bn, 0.08, 0.08, SURF_TRIM, "tower_brace")
				_beam(b, an, 0.08, 0.08, SURF_TRIM, "tower_brace")
	# the head platform the whole fan turns on
	component_box("head_platform", Vector3(top_r * 2.2, 0.14, top_r * 2.2),
		Transform3D(Basis(), Vector3(0.0, spec.height - 0.07, 0.0)), SURF_TRIM)
	_log_mass("lattice", AABB(Vector3(-spec.base_r, 0.0, -spec.base_r),
		Vector3(spec.base_r * 2.0, spec.height, spec.base_r * 2.0)))


# ----------------------------------------------------------------- the cap

## A mill that stands still and is turned by its cap, and a windpump that stands
## still and is turned by a whole head, both put their weather on top here.
func _cap_or_head() -> void:
	if spec.mill_type == &"post":
		return
	tag("cap")
	host("cap")
	var sides: int = WindmillGeometry.sides(spec)
	if spec.mill_type == &"windpump":
		_windpump_head()
		return
	# the turntable the cap turns on
	_kit.balcony_ring(spec.cap_r * 0.88, spec.cap_r * 0.8, spec.curb_y + 0.12, TAU,
		SURF_TRIM, Vector2.ZERO, 0.0, 0.18, sides)
	component_note("turntable", "ring", SURF_TRIM, {"aabb": AABB(
		Vector3(-spec.cap_r, spec.curb_y, -spec.cap_r),
		Vector3(spec.cap_r * 2.0, 0.3, spec.cap_r * 2.0))})
	var profile: PackedVector2Array = WindmillGeometry.cap_profile(spec)
	_kit.revolve(profile, Vector3(0.0, spec.curb_y + 0.12, 0.0), SURF_SAIL, sides,
		TAU, spec.cap_yaw)
	component_note("cap", "revolve", SURF_SAIL, {"profile": profile,
		"center": Vector3(0.0, spec.curb_y + 0.12, 0.0), "segments": sides,
		"start": spec.cap_yaw,
		"aabb": AABB(Vector3(-spec.cap_r, spec.curb_y, -spec.cap_r),
			Vector3(spec.cap_r * 2.0, spec.cap_h + 0.3, spec.cap_r * 2.0))})
	_log_mass("cap", AABB(Vector3(-spec.cap_r, spec.curb_y, -spec.cap_r),
		Vector3(spec.cap_r * 2.0, spec.cap_h + 0.3, spec.cap_r * 2.0)))
	# the windshaft, out through the cap's front to the sail plane
	var axle: Vector3 = WindmillGeometry.axle_point(spec)
	_beam(Vector3(0.0, axle.y, spec.curb_r * 0.35), axle, 0.26, 0.26, SURF_TRIM,
		"windshaft")


## A windpump's head: a collar, a tilted axle, and a fan on the front of it --
## all drawn in the head's own tilted frame, because that frame is what the
## wind actually turns.
func _windpump_head() -> void:
	var basis: Basis = WindmillGeometry.head_basis(spec)
	var origin: Vector3 = WindmillGeometry.head_origin(spec)
	# the collar the head turns on
	component_box("head_collar", Vector3(spec.head_r * 1.1, 0.5, spec.head_r * 1.1),
		Transform3D(Basis(), origin + Vector3(0.0, -0.25, 0.0)), SURF_TRIM)
	_beam(origin, WindmillGeometry.axle_point(spec), spec.head_r * 0.9,
		spec.head_r * 0.9, SURF_TRIM, "fan_axle")
	# No hood over the gear. A windpump's star wheel and crank are the most
	# telling thing on its head, and a weather cap parked on the hub hides all
	# of them while telling the reader nothing at all. The gear gets drawn
	# instead, in `_windpump_gear()`.
	component_note("head_collar_plate", "none", SURF_TRIM, {"aabb": AABB(
		Vector3(-spec.head_r, origin.y - 0.4, -spec.head_r),
		Vector3(spec.head_r * 2.0, 0.5, spec.head_r * 2.0))})


# ---------------------------------------------------------------- openings

## The door and the slits. Every mill has one door, low and on the front, and
## tower mills have small windows put in afterwards wherever the stair landed.
##
## Every opening is placed ON the wall the drum really is -- the centre of one
## polygon face, leaning with the batter -- by `WindmillGeometry.wall_face`.
## Placed on the circle the polygon is inscribed in, a slit hung in the air
## beside a face that turned away from it, and a door stood vertical in front
## of a leaning wall with a gap over its head. `WindmillCheck` (`openings`)
## measures every opening against that same surface.
func _openings() -> void:
	tag("openings")
	host("openings")
	var y := Basis(Vector3.UP, spec.body_yaw)
	var floor: float = WindmillGeometry.floor_y(spec)
	var h: float = WindmillGeometry.door_h(spec)
	if spec.mill_type == &"windpump":
		# a lattice has no wall to cut: its door stands flat at the foot
		_door({"point": y * Vector3(spec.door_offset_x, 0.0, -spec.base_r)
				+ Vector3(0.0, floor + h * 0.5, 0.0),
			"normal": y * Vector3.FORWARD, "up": Vector3.UP}, floor)
		return
	var face: Dictionary = WindmillGeometry.wall_face(spec, -PI * 0.5, floor + h * 0.5)
	if WindmillGeometry.is_square(spec):
		# A post mill's door is off the axis, because its ladder is, and a
		# ladder under the sails is a ladder the miller cannot climb.
		face["point"] = (face["point"] as Vector3) + y * Vector3(spec.door_offset_x, 0.0, 0.0)
	_door(face, floor)
	if spec.windows <= 0:
		return
	# The slits go up the front, turned a little either way, because that is
	# where the stair inside the tower actually landed. Each one lands in the
	# middle of the face nearest that bearing.
	for i in range(spec.windows):
		var t: float = (float(i) + 1.2) / (float(spec.windows) + 0.4)
		var wy: float = lerpf(floor + 1.7, spec.curb_y - 1.5, t)
		var swing: float = deg_to_rad(-62.0 if i % 2 == 0 else 62.0)
		var outward: Vector3 = y * Vector3(sin(swing), 0.0, -cos(swing))
		_window(WindmillGeometry.wall_face(spec, atan2(outward.z, outward.x), wy),
			WINDOW_W, WINDOW_H)


## A slit window: the dark opening on the face, and a sill and a head of
## dressed stone proud of it, so it reads as cut INTO the wall.
func _window(face: Dictionary, w: float, h: float) -> void:
	var n: Vector3 = face["normal"]
	var up: Vector3 = face["up"]
	var c: Vector3 = face["point"]
	_quad_opening(c, n, up, w, h, SURF_DARK, "window")
	var along := Basis(up.cross(n).normalized(), up, n)
	for s in [-1.0, 1.0]:
		component_box("window_sill" if s < 0.0 else "window_head",
			Vector3(w + 0.16, 0.08, 0.12),
			Transform3D(along, c + up * s * (h * 0.5 + 0.04) + n * 0.05), SURF_WALL)


## One door, on the wall face it belongs to: a painted board leaf with iron
## strap hinges and a ring, a frame round it, and a step up to it. A dark
## rectangle on a wall read as a hole or a poster; a leaf with boards and
## hinges reads as a door from as far off as anybody walks up to one.
func _door(face: Dictionary, floor: float) -> void:
	var w: float = WindmillGeometry.door_w(spec)
	var h: float = WindmillGeometry.door_h(spec)
	var n: Vector3 = face["normal"]
	var up: Vector3 = face["up"]
	var c: Vector3 = face["point"]
	var side: Vector3 = up.cross(n).normalized()
	var along := Basis(side, up, n)
	# the leaf, painted, lifted off the wall it hangs in
	_quad_opening(c, n, up, w, h, SURF_SAIL, "door")
	# the joints between its boards
	var boards: int = 4
	for b in range(1, boards):
		var x: float = -w * 0.5 + w * float(b) / float(boards)
		component_box("door_board_joint", Vector3(0.03, h - 0.06, 0.012),
			Transform3D(along, c + side * x + n * (OPENING_LIFT + 0.016)), SURF_DARK)
	# two strap hinges and a ring, which is what makes boards a door
	for hy in [-0.3, 0.3]:
		component_box("door_hinge", Vector3(w * 0.72, 0.07, 0.025),
			Transform3D(along, c + side * (-w * 0.13) + up * (h * hy)
				+ n * (OPENING_LIFT + 0.03)), SURF_TRIM)
	component_box("door_ring", Vector3(0.1, 0.1, 0.05),
		Transform3D(along, c + side * (w * 0.36) + n * (OPENING_LIFT + 0.04)), SURF_TRIM)
	# the frame: a lintel and two jambs, proud of the wall and leaning with it
	for s in [-1.0, 1.0]:
		component_box("door_jamb", Vector3(0.16, h, 0.22),
			Transform3D(along, c + side * s * (w * 0.5 + 0.08)), SURF_WALL)
	component_box("door_lintel", Vector3(w + 0.52, 0.2, 0.22),
		Transform3D(along, c + up * (h * 0.5 + 0.1)), SURF_WALL)
	# and the step up to it, level, on the ground in front of the sill
	var flat: Vector3 = Vector3(n.x, 0.0, n.z).normalized()
	var foot: Vector3 = c - up * (h * 0.5)
	component_box("door_step", Vector3(w + 0.5, 0.14, 0.5), Transform3D(
		Basis(Vector3.UP, atan2(flat.x, flat.z)),
		Vector3(foot.x, floor + 0.07, foot.z) + flat * 0.2), SURF_WALL)


# ------------------------------------------------------ the stage and gallery

## The stage: a deck standing off the mill so the miller can reach a sail, and
## a rail round it because a miller on a stage in a gale is a miller in a
## hospital. It is also the reason the sail plane has to stand where it does.
func _stage() -> void:
	tag("stage")
	host("stage")
	var start: float = -PI * 0.5 - spec.stage_arc * 0.5
	var inner: float = WindmillGeometry.stage_inner_r(spec)
	var thickness: float = 0.14
	_kit.balcony_ring(spec.stage_r, WindmillGeometry.STAGE_WIDTH, spec.stage_y,
		spec.stage_arc, SURF_WALL, Vector2.ZERO, start, thickness, 14)
	component_note("stage_deck", "ring", SURF_WALL, {"radius": spec.stage_r,
		"width": WindmillGeometry.STAGE_WIDTH, "y": spec.stage_y,
		"arc": spec.stage_arc, "start": start, "thickness": thickness,
		"aabb": _ring_aabb(spec.stage_r, spec.stage_y, thickness, start, spec.stage_arc)})
	_log_mass("stage", _ring_aabb(spec.stage_r, spec.stage_y, thickness, start,
		spec.stage_arc))
	# the brackets under it, back to the mill: a stage is held up, not floating
	var posts: int = 7
	for i in range(posts):
		var a: float = start + spec.stage_arc * float(i) / float(posts - 1)
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_beam(out * (spec.stage_r - 0.04) + Vector3(0.0, spec.stage_y, 0.0),
			out * maxf(inner - 0.1, 0.2) + Vector3(0.0, spec.stage_y - 0.75, 0.0),
			0.1, 0.1, SURF_TRIM, "stage_bracket")
	_rail(spec.stage_r, spec.stage_y, start, spec.stage_arc, posts, "stage_rail")


## The gallery: a walk right round the curb, which is where a cap mill's miller
## stands to get at the whole cap and the windshaft bearing.
func _gallery() -> void:
	host("gallery")
	var outer: float = spec.curb_r + WindmillGeometry.GALLERY_WIDTH
	_kit.balcony_ring(outer, WindmillGeometry.GALLERY_WIDTH, spec.curb_y, TAU,
		SURF_WALL, Vector2.ZERO, 0.0, 0.16, 18)
	component_note("gallery_deck", "ring", SURF_WALL, {"radius": outer,
		"width": WindmillGeometry.GALLERY_WIDTH, "y": spec.curb_y, "arc": TAU,
		"thickness": 0.16, "aabb": _ring_aabb(outer, spec.curb_y, 0.16, 0.0, TAU)})
	_log_mass("gallery", _ring_aabb(outer, spec.curb_y, 0.16, 0.0, TAU))
	_rail(outer, spec.curb_y, 0.0, TAU, 16, "gallery_rail")
	# and the brackets it hangs on
	for i in range(10):
		var a: float = TAU * float(i) / 10.0
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_beam(out * (outer - 0.06) + Vector3(0.0, spec.curb_y, 0.0),
			out * (spec.curb_r - 0.05) + Vector3(0.0, spec.curb_y - 0.6, 0.0),
			0.08, 0.08, SURF_TRIM, "gallery_bracket")


## Posts and a rail along an arc. `posts` uprights, each carrying the next
## span of rail.
func _rail(radius: float, y: float, start: float, arc: float, posts: int,
		role: String) -> void:
	var top: float = y + WindmillGeometry.RAIL_H
	var prev: Vector3 = Vector3.ZERO
	for i in range(posts):
		var a: float = start + arc * float(i) / float(maxi(posts - 1, 1))
		var p: Vector3 = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		_beam(p + Vector3(0.0, y, 0.0), p + Vector3(0.0, top, 0.0),
			WindmillGeometry.RAIL_POST, WindmillGeometry.RAIL_POST, SURF_TRIM,
			role + "_post")
		if i > 0:
			_beam(prev, p + Vector3(0.0, top, 0.0), RAIL_T, RAIL_T, SURF_TRIM, role)
		prev = p + Vector3(0.0, top, 0.0)


# -------------------------------------------------------------------- rotor

## The rotor, which is the only part of a windmill anybody photographs. Three
## of the five mills turn sails; a windpump turns a fan of blades; a polder
## mill turns a scoop wheel in water, and that is the same machine with the
## wind taken away.
func _rotor() -> void:
	match spec.mill_type:
		&"paddle":
			_scoop_wheel()
		&"windpump":
			_fan()
		_:
			_sails()


## Four sails, or six, on a windshaft: a whorl at the root, a stock, bars across
## it and cloth on top. The stock is iron-dark and the cloth is not, which is
## the only reason you can read a mill's sails at any distance.
func _sails() -> void:
	tag("rotor")
	host("rotor")
	var plane: float = WindmillGeometry.sail_plane(spec)
	var axle: Vector3 = WindmillGeometry.axle_point(spec)
	var centre := Vector3(0.0, axle.y, plane)
	# the whorl every sail hangs off, and the shaft it hangs from
	_disc(centre + Vector3(0.0, 0.0, -spec.whorl_r * 0.2), spec.whorl_r, 0.16,
		Vector3.BACK, SURF_TRIM, "whorl", 14)
	_beam(centre + Vector3(0.0, 0.0, 0.3), centre + Vector3(0.0, 0.0, -0.2), 0.3, 0.3,
		SURF_TRIM, "windshaft_head")
	var angles: Array[float] = WindmillGeometry.sail_angles(spec)
	var tips: Array[Vector3] = []
	for i in range(angles.size()):
		var angle: float = angles[i]
		var dir: Vector3 = WindmillGeometry.sail_direction(angle)
		var across: Vector3 = Vector3(-dir.y, dir.x, 0.0)
		var root: Vector3 = centre + dir * spec.whorl_r
		var tip: Vector3 = centre + dir * spec.sail_r
		tips.append(tip)
		_beam(root, tip, 0.17, 0.24, SURF_TRIM, "sail_stock")
		for bar in range(SAIL_BARS):
			var t: float = (float(bar) + 1.0) / float(SAIL_BARS + 1)
			var at: Vector3 = root.lerp(tip, t)
			_beam(at - across * (spec.sail_width * 0.5),
				at + across * (spec.sail_width * 0.5), 0.07, 0.07, SURF_TRIM,
				"sail_bar")
		# the cloth, a little narrower than the bars and set in front of them
		var w: float = spec.sail_width * 0.88
		var face: float = plane - 0.09
		var cloth := PackedVector3Array([
			Vector3(root.x - across.x * w * 0.5, root.y - across.y * w * 0.5, face),
			Vector3(tip.x - across.x * w * 0.5, tip.y - across.y * w * 0.5, face),
			Vector3(tip.x + across.x * w * 0.5, tip.y + across.y * w * 0.5, face),
			Vector3(root.x + across.x * w * 0.5, root.y + across.y * w * 0.5, face)])
		component_slab("sail_cloth", cloth, CLOTH_T, SURF_SAIL, false)
	_log_mass("sails", _points_aabb(tips).grow(spec.sail_width * 0.6 + 0.4))


## A windpump's fan: a rim, a hub and twenty blades between them, all set at a
## pitch, because a flat disc of blades would push nothing at all.
func _fan() -> void:
	tag("rotor")
	host("rotor")
	var basis: Basis = WindmillGeometry.head_basis(spec)
	var origin: Vector3 = WindmillGeometry.head_origin(spec)
	var axle: Vector3 = WindmillGeometry.axle_point(spec)
	var blades: int = maxi(spec.sails, 8)
	var rim: float = spec.sail_r
	var hub: float = maxf(rim * 0.17, 0.2)
	# The hub faces along the fan's own axis, not the world's: the head is
	# tilted into the wind and a hub that ignored that reads as a loose disc.
	_disc(axle, hub, spec.head_r * 0.8, basis * Vector3.BACK, SURF_TRIM, "fan_hub", 12)
	var tips: Array[Vector3] = []
	for i in range(blades):
		var a: float = TAU * float(i) / float(blades)
		var dir := Vector3(cos(a), sin(a), 0.0)
		var at: Vector3 = axle + basis * (dir * hub)
		var out: Vector3 = axle + basis * (dir * rim)
		tips.append(out)
		# A blade is a paddle, so it is pitched about its OWN RADIAL axis: that
		# is what turns its face into the wind instead of its edge. Pitching it
		# about the fan's normal instead lifts the whole blade out of the disc,
		# and a fan of blades that are not in the disc is not a fan.
		var pitch: Basis = basis * Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.26)
		component_box("fan_blade", Vector3(rim - hub, rim * 0.17, 0.05),
			Transform3D(pitch, (at + out) * 0.5), SURF_TRIM)
	# The rim is a ring of joined segments, so the fan reads as a DISC. Studs at
	# the right radius read as studs, which is what they are.
	var segments: int = maxi(blades / 2, 8)
	for k in range(segments):
		var ar: float = TAU * float(k) / float(segments)
		var ar2: float = TAU * float(k + 1) / float(segments)
		_beam(axle + basis * Vector3(cos(ar) * rim, sin(ar) * rim, 0.0),
			axle + basis * Vector3(cos(ar2) * rim, sin(ar2) * rim, 0.0),
			0.1, 0.1, SURF_TRIM, "fan_rim")
	for i2 in range(maxi(blades / 4, 3)):
		var a2: float = TAU * float(i2) / float(maxi(blades / 4, 3))
		var d2 := Vector3(cos(a2), sin(a2), 0.0)
		_beam(axle + basis * (d2 * hub), axle + basis * (d2 * rim), 0.09, 0.09,
			SURF_TRIM, "fan_spoke")
	_log_mass("fan", _points_aabb(tips).grow(spec.head_r))
	# the fan vane: the thing that weathercocks the head, standing off the back
	if spec.vanes:
		# The tail is a boom, the vane a panel at its end, and the fan vane a
		# small one above it. Without the small one the head cannot find the
		# wind at all: the big vane only tells it which way it is going.
		var boom: float = spec.tail
		component_box("vane_arm", Vector3(0.18, 0.18, boom),
			Transform3D(basis, axle + basis * Vector3(0.0, 0.0, boom * 0.5)), SURF_TRIM)
		component_box("vane_panel", Vector3(boom * 0.5, boom * 0.3, 0.05),
			Transform3D(basis, axle + basis * Vector3(0.0, 0.0, boom * 0.78)),
			SURF_SAIL)
		component_box("fan_vane_arm", Vector3(0.06, 0.06, boom * 0.3),
			Transform3D(basis, axle + basis * Vector3(0.0, boom * 0.22, boom * 0.15)),
			SURF_TRIM)
		component_box("fan_vane", Vector3(boom * 0.16, boom * 0.2, 0.04),
			Transform3D(basis, axle + basis * Vector3(0.0, boom * 0.34, boom * 0.28)),
			SURF_SAIL)
		_log_mass("vane", AABB(axle + basis * Vector3(-boom * 0.4, -boom * 0.4,
			0.0), Vector3(boom * 0.9, boom * 0.8, boom)))


## A polder mill's wheel: two rims, spokes, and buckets between them, standing
## in the race with about half its rim under the water.
func _scoop_wheel() -> void:
	tag("rotor")
	host("rotor")
	var axle: Vector3 = WindmillGeometry.wheel_axle(spec)
	var half: float = spec.wheel_width * 0.5
	var r: float = spec.wheel_r
	var n: int = maxi(spec.wheel_buckets, 6)
	for side in [-1.0, 1.0]:
		var z: float = side * half
		# The rim is a RING, and each segment joins the next. A ring of marks at
		# the right radius is not a waterwheel; it is a handful of studs.
		for i in range(n):
			var a: float = TAU * float(i) / float(n)
			var a2: float = TAU * float(i + 1) / float(n)
			_beam(axle + Vector3(cos(a) * r, sin(a) * r, z),
				axle + Vector3(cos(a2) * r, sin(a2) * r, z), 0.13, 0.13,
				SURF_TRIM, "wheel_rim")
		for i2 in range(maxi(n / 2, 3)):
			var a3: float = TAU * float(i2) / float(maxi(n / 2, 3))
			_beam(axle + Vector3(0.0, 0.0, z),
				axle + Vector3(cos(a3) * r, sin(a3) * r, z), 0.1, 0.1,
				SURF_TRIM, "wheel_spoke")
		_disc(axle + Vector3(0.0, 0.0, z * 1.05), maxf(r * 0.12, 0.18), 0.14,
			Vector3.BACK, SURF_TRIM, "wheel_hub", 10)
	for i3 in range(n):
		var ab: float = TAU * float(i3) / float(n)
		var dir := Vector3(cos(ab), sin(ab), 0.0)
		# A bucket is a board standing in the plane of the wheel, so the current
		# pushes its whole face rather than an edge of it.
		component_box("wheel_bucket", Vector3(0.12, 0.42, spec.wheel_width),
			Transform3D(Basis(Vector3(0, 0, 1), ab) * Basis(Vector3.RIGHT, 0.22),
				axle + dir * r * 0.78), SURF_TRIM)
	_beam(axle + Vector3(0, 0, -half - 0.4), axle + Vector3(0, 0, half + 0.4),
		0.28, 0.28, SURF_TRIM, "wheel_axle")
	_log_mass("wheel", AABB(axle - Vector3(r, r, half + 0.4), Vector3(r * 2.0, r * 2.0,
		(half + 0.4) * 2.0)))


# ---------------------------------------------------------------- the tail

## The tail. This is the part that says the mill turns: a beam or a lever
## behind the body, with a wheel or a fan on its end that a rope or the wind
## itself pushes on.
func _tail() -> void:
	if not WindmillGeometry.has_tail(spec):
		return
	tag("tail")
	host("tail")
	var root: Vector3 = WindmillGeometry.tail_root(spec)
	var tip: Vector3 = WindmillGeometry.tail_tip(spec)
	_beam(root, tip, 0.26, 0.26, SURF_TRIM, "tailpole")
	# the stock it turns on, against the mill's own body
	_beam(root, root + Vector3(0.0, -spec.tail * 0.12, 0.0), 0.34, 0.34,
		SURF_TRIM, "tail_stock")
	if spec.mill_type == &"post":
		# a post mill's tail carries a great wheel, which is what the post's
		# pinion turns
		_toothed_wheel(tip, Basis(Vector3.RIGHT, 0.25) * Vector3.BACK, spec.tailwheel_r,
			12, 0.12, SURF_TRIM, "winding_wheel")
	else:
		_disc(tip, spec.tailwheel_r, 0.1, Vector3.BACK, SURF_TRIM, "tailwheel", 12)
	if spec.fantail:
		# the fantail: eight arms on a short arm, which walks the cap round into
		# the wind all by itself. It is the whole reason a tower mill turns.
		var basis := Basis(Vector3.RIGHT, -spec.tail_drop)
		var hub: Vector3 = root.lerp(tip, 0.82)
		_beam(root, hub, 0.09, 0.09, SURF_TRIM, "fantail_arm")
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			var dir := basis * Vector3(cos(a), sin(a), 0.0)
			component_box("fantail_blade", Vector3(spec.fantail_r, 0.03, 0.26),
				Transform3D(basis * Basis(Vector3.UP, a), hub + dir * (spec.fantail_r * 0.5)),
				SURF_TRIM)
		_disc(hub, 0.2, 0.12, Vector3.BACK, SURF_TRIM, "fantail_hub", 10)
	# the rope or the winding gear somebody uses to turn it
	if not spec.fantail:
		_beam(tip, Vector3(tip.x, 0.3, tip.z + 0.4), 0.05, 0.05, SURF_TRIM, "winding_rope")
	_log_mass("tail", _points_aabb([root, tip]).grow(0.5))


# -------------------------------------------------------- the windpump's gear

## The gear between the fan and the water: a star wheel on the fan shaft, a
## crank pin on its rim, and a rod down the tower to a pump at the foot. A
## windpump is a fan and a pump and nothing else, and the rod is the proof.
func _windpump_gear() -> void:
	tag("gear")
	host("gear")
	var basis: Basis = WindmillGeometry.head_basis(spec)
	var axle: Vector3 = WindmillGeometry.axle_point(spec)
	var star: float = WindmillGeometry.star_radius(spec)
	var hub: Vector3 = axle + basis * Vector3(0.0, 0.0, -(star + spec.head_r * 0.3))
	# the star wheel, teeth and all
	_toothed_wheel(hub, basis * Vector3.BACK, star, spec.star_teeth, 0.1, SURF_TRIM,
		"star_wheel")
	# the pinion it drives, on the pump shaft below it
	var pinion: Vector3 = hub + Vector3(0.0, -star * 1.35, 0.0)
	_toothed_wheel(pinion, Vector3.BACK, maxf(star * 0.34, 0.14),
		maxi(spec.star_teeth / 3, 6), 0.08, SURF_TRIM, "pinion")
	# the crank pin at the star wheel's own radius, and the rod it drives
	var pin: Vector3 = WindmillGeometry.crank_pin(spec)
	_beam(pin + Vector3(0.0, 0.0, -0.22), pin + Vector3(0.0, 0.0, 0.22), 0.12, 0.12,
		SURF_TRIM, "crank_pin")
	var pump: Vector3 = WindmillGeometry.pump_point(spec)
	_beam(pin, pump + Vector3(0.0, spec.pump_h, 0.0), 0.1, 0.1, SURF_TRIM, "pump_rod")
	# the pump itself, and the spout its water leaves by
	host("pump")
	component_box("pump", Vector3(0.7, spec.pump_h, 0.7), Transform3D(Basis(),
		pump + Vector3(0.0, spec.pump_h * 0.5, 0.0)), SURF_WALL)
	component_box("pump_spout", Vector3(0.42, 0.3, 1.5), Transform3D(
		Basis(Vector3.UP, PI * 0.25),
		pump + Vector3(-0.5, spec.discharge_h - 0.6, -0.45)), SURF_TRIM)
	component_box("pump_spout_leg", Vector3(0.2, spec.discharge_h - 0.6, 0.2),
		Transform3D(Basis(), pump + Vector3(-0.05, (spec.discharge_h - 0.6) * 0.5, -0.05)),
		SURF_TRIM)
	_log_mass("gear", _points_aabb([hub, pinion, pin, pump]).grow(0.6))
	_log_mass("pump", AABB(pump - Vector3(0.35, 0.0, 0.35),
		Vector3(0.7, spec.pump_h, 0.7)))


# ------------------------------------------------------------ the stock ladder

## The stock ladder: from the mound up to the door.
##
## Its FOOT stands well to one side, outside the sails, because a miller who
## climbed into them would not come back; its TOP is at the door, in the middle
## of the burr's front wall. So it leans across in plan on its way up -- which
## is exactly what a stock ladder looks like from the far side of a mound, and
## why they are always photographed from behind.
func _stock_ladder() -> void:
	tag("access")
	host("access")
	var foot: float = WindmillGeometry.ladder_foot_y(spec)
	var top: float = WindmillGeometry.floor_y(spec)
	var z_near: float = -spec.base_r
	var z_far: float = -WindmillGeometry.ladder_run_for(spec)
	var half: float = spec.ladder_w * 0.5
	var foot_x: float = spec.ladder_offset
	var head_x: float = spec.door_offset_x + half * 0.6
	for side in [-1.0, 1.0]:
		_beam(Vector3(foot_x + side * half, foot, z_far),
			Vector3(head_x + side * half * 0.6, top + WindmillGeometry.DOOR_H * 0.1,
				z_near + 0.1), 0.12, 0.16, SURF_WALL, "ladder_rail")
	var rungs: int = maxi(int((top - foot) / 0.34), 3)
	for i in range(rungs):
		var t: float = float(i) / float(rungs - 1)
		var y: float = lerpf(foot + 0.12, top - 0.1, t)
		var z: float = lerpf(z_far + 0.2, z_near + 0.15, t)
		var x: float = lerpf(foot_x, head_x, t)
		var wide: float = half * (1.0 - t * 0.4)
		_beam(Vector3(x - wide, y, z), Vector3(x + wide, y, z), 0.07, 0.07,
			SURF_WALL, "ladder_rung")
	# a handrail down the outboard side, climbed in a gale
	_beam(Vector3(foot_x + half, foot + WindmillGeometry.RAIL_H, z_far),
		Vector3(head_x + half * 0.6, top + WindmillGeometry.RAIL_H * 0.6,
			z_near + 0.1), 0.07, 0.07, SURF_TRIM, "ladder_rail_post")
	var lo := Vector3(minf(foot_x, head_x) - half, foot, z_far)
	var hi := Vector3(maxf(foot_x, head_x) + half, top + 0.4, z_near + 0.1)
	_log_mass("ladder", AABB(lo, hi - lo))


# ------------------------------------------------------------------ primitives

## A beam from a to b, in the section given. One oriented box: a length with a
## section is exactly that, and there is no second opinion about winding
## anywhere in this file.
func _beam(a: Vector3, b: Vector3, w: float, d: float, surf: int,
		role: String) -> void:
	var axis: Vector3 = b - a
	var length: float = axis.length()
	if length < 1e-4:
		return
	var up := Vector3.UP
	if absf(axis.normalized().dot(up)) > 0.999:
		up = Vector3.FORWARD
	component_box(role, Vector3(w, d, length * 1.02),
		Transform3D(Basis().looking_at(axis / length, up), (a + b) * 0.5), surf)


## A flat disc facing `axis`, drawn as a polygon slab. Used for every wheel and
## every hub on the mill, because a slab is the one kit primitive that can be
## any circle on any plane.
func _disc(centre: Vector3, radius: float, thickness: float, axis: Vector3,
		surf: int, role: String, sides: int) -> void:
	if radius <= 0.01 or thickness <= 0.01:
		return
	var n: Vector3 = axis.normalized()
	var u: Vector3 = n.cross(Vector3.UP)
	if u.length_squared() < 1e-6:
		u = n.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = n.cross(u).normalized()
	var poly := PackedVector3Array()
	var at: Vector3 = centre - n * (thickness * 0.5)
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides)
		poly.append(at + (u * cos(a) + v * sin(a)) * radius)
	component_slab(role, poly, thickness, surf, false)


## A wheel with teeth on it: a hub disc and a ring of blocks, which is what a
## winding wheel and a star wheel actually are.
func _toothed_wheel(centre: Vector3, axis: Vector3, radius: float, teeth: int,
		thickness: float, surf: int, role: String) -> void:
	if radius <= 0.05:
		return
	_disc(centre, maxf(radius - 0.06, radius * 0.5), thickness * 0.6, axis, surf,
		role + "_web", 12)
	var n: Vector3 = axis.normalized()
	var u: Vector3 = n.cross(Vector3.UP)
	if u.length_squared() < 1e-6:
		u = n.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = n.cross(u).normalized()
	var count: int = maxi(teeth, 6)
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		var dir: Vector3 = u * cos(a) + v * sin(a)
		var tip: Vector3 = centre + dir * (radius + thickness * 0.6)
		_beam(centre + dir * (radius - thickness), tip, thickness * 1.4, thickness * 1.4,
			surf, role + "_tooth")


## A battered wall as three surfaces of revolution: the outside, the inside and
## the ring of wall between them at the top. Returned as the volume it occupies.
##
## The polygon is turned by `WindmillGeometry.drum_start` so a face looks down
## -Z. The openings are placed on exactly this surface by
## `WindmillGeometry.wall_face`, and the two must agree.
func _tapered_drum(base_y: float, base_r: float, top_r: float, height: float,
		thickness: float, surf: int, sides: int) -> AABB:
	var centre := Vector3(0.0, base_y, 0.0)
	var start: float = WindmillGeometry.drum_start(sides)
	var outer := PackedVector2Array([Vector2(base_r, 0.0), Vector2(top_r, height)])
	var inner_r0: float = maxf(base_r - thickness, 0.05)
	var inner_r1: float = maxf(top_r - thickness, 0.05)
	_kit.revolve(outer, centre, surf, sides, TAU, start)
	# the same profile run downwards, which is what turns its normals inward
	_kit.revolve(PackedVector2Array([Vector2(inner_r1, height),
		Vector2(inner_r0, 0.0)]), centre, surf, sides, TAU, start)
	_kit.revolve(PackedVector2Array([Vector2(top_r, height),
		Vector2(inner_r1, height)]), centre, surf, sides, TAU, start)
	_kit.revolve(PackedVector2Array([Vector2(base_r, 0.0),
		Vector2(inner_r0, 0.0)]), centre, surf, sides, TAU, start)
	var r: float = maxf(base_r, top_r)
	var aabb := AABB(Vector3(-r, base_y, -r), Vector3(r * 2.0, height, r * 2.0))
	component_note("wall", "revolve", surf, {"profile": outer, "center": centre,
		"segments": sides, "start": start, "thickness": thickness, "aabb": aabb})
	return aabb


## An opening: a dark quad laid on the wall it is cut in, lifted a millimetre
## or so off the masonry so the two surfaces cannot fight.
func _quad_opening(centre: Vector3, normal: Vector3, up: Vector3, w: float, h: float,
		surf: int, role: String) -> void:
	var n: Vector3 = normal.normalized()
	var u: Vector3 = n.cross(up).normalized()
	var v: Vector3 = n.cross(u).normalized()
	var c: Vector3 = centre + n * OPENING_LIFT
	var poly := PackedVector3Array([
		c - u * (w * 0.5) - v * (h * 0.5), c + u * (w * 0.5) - v * (h * 0.5),
		c + u * (w * 0.5) + v * (h * 0.5), c - u * (w * 0.5) + v * (h * 0.5)])
	component_slab(role, poly, 0.02, surf, false)


static func _points_aabb(points: Array[Vector3]) -> AABB:
	if points.is_empty():
		return AABB()
	var out := AABB(points[0], Vector3.ZERO)
	for p in points:
		out = out.expand(p)
	return out


## The volume a ring of boards occupies, from the arc it sweeps.
static func _ring_aabb(radius: float, y: float, thickness: float, start: float,
		arc: float) -> AABB:
	var out := AABB()
	var steps: int = 10
	for i in range(steps + 1):
		var a: float = start + arc * float(i) / float(steps)
		out = out.expand(Vector3(cos(a) * radius, y - thickness,
			sin(a) * radius))
		out = out.expand(Vector3(cos(a) * radius, y + thickness,
			sin(a) * radius))
	return out.grow(0.05)