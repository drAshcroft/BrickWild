class_name PropKit
extends RefCounted
## The small props a village needs and no art pack ships (VILLAGES §7).
##
## Everything else outdoors comes from the measured catalogue -- barrels,
## carts, benches, trees. But nobody in the Quaternius packs made a well, a
## signpost, a palisade, a haystack or a mill wheel, and a village that has
## no well is not a village. So these ten are BUILT, out of the same
## primitives every building is built from, and the village never depends on
## an asset that is not there.
##
## Deliberately not in MeshKit. MeshKit takes plain sizes and positions and
## does not know what a church is; a well knows it is a well. This is the
## same separation LightKit keeps -- a kit of its own, over the primitives.
##
## Each prop is emitted about `at`, standing on `at.y`, facing local -Z
## turned by `yaw` (the whole project's convention), and returns the world
## AABB of what it emitted.
##
## That AABB is ACCUMULATED from the pieces as they go out, never written
## down alongside them. The village logs it as a mass, the walk grid blocks
## it, and the fire-gap and road-clearance rules measure it -- so a well
## whose roof hangs out of the box it claims is a well people walk through.
## Every emitter below goes through `_box`/`_oriented`/`_round`, each of
## which widens the accumulator with the true turned extent of what it just
## placed. This is the same discipline `MassBuilder` keeps for buildings, and
## `PropKitSuite` reads the mesh back to prove it holds.

var _kit: MeshKit
## Which surface each material is: the masonry of a well head, the timber of
## a post, the thatch or shingle of a little roof, and the iron and shadow of
## a lamp bracket or a mine mouth.
var _stone: int
var _wood: int
var _roof: int
var _dark: int

var _acc := AABB()
var _seen := false


func _init(kit: MeshKit, stone: int, wood: int, roof: int, dark: int) -> void:
	_kit = kit
	_stone = stone
	_wood = wood
	_roof = roof
	_dark = dark


# ------------------------------------------------------------------ the well

## The well on the common: a drum of masonry you can sit on, two posts, a
## windlass between them and a little gabled roof over it. `radius` is the
## outside of the drum, so a person's clearance is measured from it.
func well(at: Vector3, yaw := 0.0, radius := 0.9) -> AABB:
	_begin()
	var wall: float = maxf(radius * 0.18, 0.12)
	var head: float = radius * 1.05          # the parapet, waist high
	_kit.oval_ring(at, radius, radius, wall, head, _stone, 16)
	_round(at, radius, head)
	# the two posts, on the axis across the well mouth
	var post := 0.12
	var post_h: float = radius * 2.1
	for side in [-1.0, 1.0]:
		var p: Vector3 = at + _turn(Vector3(side * (radius - wall / 2.0), 0.0, 0.0), yaw)
		_box(Vector3(post, head + post_h, post),
			p + Vector3(0.0, (head + post_h) / 2.0, 0.0), _wood, yaw)
	# the windlass: a barrel of wood on its side, spanning the posts
	var span: float = (radius - wall / 2.0) * 2.0
	_box(Vector3(span, 0.16, 0.16),
		Vector3(at.x, at.y + head + post_h * 0.72, at.z), _wood, yaw)
	# and the roof over it, ridge across the posts
	var eave: float = at.y + head + post_h
	_ridge(Vector3(at.x, eave, at.z), yaw + PI / 2.0,
		radius * 2.4, radius * 2.0, radius * 0.7)
	return _end()


# -------------------------------------------------------------- the roadside

## A signpost at a gate or a fork: a post and `arms` fingerboards, the first
## pointing down local -Z and the rest turned off it.
func signpost(at: Vector3, yaw := 0.0, arms := 2, height := 2.2) -> AABB:
	_begin()
	_box(Vector3(0.14, height, 0.14), at + Vector3(0.0, height / 2.0, 0.0), _wood, yaw)
	for i in range(arms):
		# arms alternate about the post's own facing and step down it, so two
		# fingerboards never occupy the same band of the post
		var turn: float = yaw + (0.0 if i % 2 == 0 else PI * 0.62)
		var y: float = at.y + height - 0.22 - float(i) * 0.32
		_box(Vector3(0.66, 0.2, 0.06),
			at + _turn(Vector3(0.0, 0.0, -0.42), turn) + Vector3(0.0, y - at.y, 0.0),
			_wood, turn)
	return _end()


## A lamp post: a post, a little bracket and the cap the flame sits under.
## The flame itself is a catalogued prop (`Torch_Metal`) hung at the returned
## AABB's top by the assembler, and lit by LightKit like every other lamp --
## which is why nothing here emits a light.
func lamp_post(at: Vector3, yaw := 0.0, height := 3.0) -> AABB:
	_begin()
	_box(Vector3(0.16, height, 0.16), at + Vector3(0.0, height / 2.0, 0.0), _wood, yaw)
	_box(Vector3(0.5, 0.1, 0.1),
		at + _turn(Vector3(0.0, 0.0, -0.16), yaw) + Vector3(0.0, height - 0.18, 0.0),
		_dark, yaw)
	var cap: Vector3 = at + Vector3(0.0, height, 0.0)
	_kit.cone(0.3, 0.24, cap, _dark, 8)
	_round(cap, 0.3, 0.24)
	return _end()


# ------------------------------------------------------------------- the edge

## A palisade run from `from_p` to `to_p`: sharpened stakes at a pitch, with a
## waling piece behind them at shoulder height. The run is the village's edge
## when `enclosure = palisade`, and the returned AABB is the ribbon of it --
## the walk grid blocks the ribbon, not each stake.
func palisade(from_p: Vector2, to_p: Vector2, y := 0.0, height := 2.4,
		pitch := 0.34) -> AABB:
	var run: Vector2 = to_p - from_p
	var length: float = run.length()
	if length < 0.01:
		return AABB()
	_begin()
	var dir: Vector2 = run / length
	var facing: float = atan2(-dir.x, -dir.y) + PI / 2.0
	var stake: float = minf(pitch * 0.82, 0.26)
	var count: int = maxi(int(length / pitch), 1)
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var p: Vector2 = from_p + dir * (length * t)
		# every third stake stands a little proud, so the run reads as timber
		# rather than as one extruded wall
		var h: float = height * (1.06 if i % 3 == 0 else 1.0)
		_box(Vector3(stake, h - stake, stake),
			Vector3(p.x, y + (h - stake) / 2.0, p.y), _wood, facing)
		# the point on top, which is what makes it a palisade and not a fence
		var tip := Vector3(p.x, y + h - stake, p.y)
		_kit.stepped_taper(tip, stake, stake * 1.6, _wood, 2, stake * 0.15)
		_round(tip, stake * 0.75, stake * 1.6)
	var mid: Vector2 = from_p.lerp(to_p, 0.5)
	_box(Vector3(length, 0.14, 0.1), Vector3(mid.x, y + height * 0.66, mid.y),
		_wood, facing)
	return _end()


## A gate in a fence or a palisade: two heavier posts and the three rails
## between them. Left as a gap in the run it stands in, so a person can walk
## through -- `width` is the clear opening, not the overall.
func fence_gate(at: Vector3, yaw := 0.0, width := 1.6, height := 1.5) -> AABB:
	_begin()
	var post := 0.2
	for side in [-1.0, 1.0]:
		var p: Vector3 = at + _turn(Vector3(side * (width + post) / 2.0, 0.0, 0.0), yaw)
		_box(Vector3(post, height * 1.15, post),
			p + Vector3(0.0, height * 0.575, 0.0), _wood, yaw)
	for i in range(3):
		_box(Vector3(width, 0.1, 0.06),
			Vector3(at.x, at.y + height * (0.25 + 0.3 * float(i)), at.z), _wood, yaw)
	# the brace, which is how you tell a gate from a hole in a fence
	_oriented(Vector3(width * 1.12, 0.08, 0.05),
		Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), 0.5),
			Vector3(at.x, at.y + height * 0.55, at.z)), _wood)
	return _end()


# ------------------------------------------------------------------ the farm

## A haystack: a revolved dome on a low ring of loose straw, with the pole it
## was built round poking out of the top.
func haystack(at: Vector3, radius := 1.4, height := 2.6) -> AABB:
	_begin()
	var profile := PackedVector2Array([
		Vector2(radius * 0.86, 0.0),
		Vector2(radius, height * 0.28),
		Vector2(radius * 0.88, height * 0.55),
		Vector2(radius * 0.55, height * 0.82),
		Vector2(0.0, height),
	])
	_kit.revolve(profile, at, _roof, 14)
	_round(at, radius, height)
	_box(Vector3(0.1, height * 0.28, 0.1),
		at + Vector3(0.0, height + height * 0.1, 0.0), _wood, 0.0)
	return _end()


## A drying rack for fish or nets on the strand: two A-frames and the poles
## between them, hung with cloth.
func drying_rack(at: Vector3, yaw := 0.0, length := 2.8, height := 1.9) -> AABB:
	_begin()
	for side in [-1.0, 1.0]:
		var c: Vector3 = at + _turn(Vector3(0.0, 0.0, side * length / 2.0), yaw)
		for lean in [-1.0, 1.0]:
			_oriented(Vector3(0.09, height * 1.06, 0.09),
				Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), lean * 0.34),
					c + Vector3(0.0, height / 2.0, 0.0)), _wood)
	for i in range(2):
		_box(Vector3(0.07, 0.07, length + 0.2),
			Vector3(at.x, at.y + height * (0.6 + 0.38 * float(i)), at.z), _wood, yaw)
	# the catch, hanging off the top pole
	_box(Vector3(0.03, height * 0.34, length * 0.8),
		Vector3(at.x, at.y + height * 0.81, at.z), _dark, yaw)
	return _end()


# ----------------------------------------------------------------- the water

## The mill wheel, on the wall of the mill and turning in the race: a ring of
## two rims, the spokes between them and the paddles round the outside. `yaw`
## turns the AXLE, so the wheel stands in the plane across it.
func mill_wheel(at: Vector3, yaw := 0.0, radius := 1.8, width := 0.7) -> AABB:
	_begin()
	var basis := Basis(Vector3.UP, yaw)
	var paddles := 12
	for side in [-1.0, 1.0]:
		_ring(at + basis * Vector3(0.0, 0.0, side * width / 2.0),
			radius, radius * 0.86, basis)
	for i in range(paddles):
		var a: float = TAU * float(i) / float(paddles)
		var spin: Basis = basis * Basis(Vector3(0, 0, 1), a)
		var out_v: Vector3 = basis * Vector3(cos(a) * radius * 0.93,
			sin(a) * radius * 0.93, 0.0)
		_oriented(Vector3(radius * 0.26, 0.08, width), Transform3D(spin, at + out_v), _wood)
		# every third spoke, so the wheel reads as built rather than solid
		if i % 3 == 0:
			var spoke: Vector3 = basis * Vector3(cos(a) * radius * 0.45,
				sin(a) * radius * 0.45, 0.0)
			_oriented(Vector3(radius * 0.9, 0.07, 0.07),
				Transform3D(spin, at + spoke), _wood)
	_oriented(Vector3(0.18, 0.18, width * 1.9), Transform3D(basis, at), _dark)
	return _end()


## A boat drawn up on the strand: a hull of tapering strakes, a thwart and a
## pair of oars. Sits on its own keel, so `at.y` is the ground it is on.
func boat(at: Vector3, yaw := 0.0, length := 4.2, beam := 1.3) -> AABB:
	_begin()
	var depth: float = beam * 0.62
	var strakes := 3
	for i in range(strakes):
		var t: float = float(i) / float(strakes - 1)
		# each strake is wider, longer and higher than the one under it, which
		# is a clinker hull to within the accuracy anyone sees it from
		_box(Vector3(lerpf(beam * 0.38, beam, t), depth * 0.4,
				lerpf(length * 0.74, length, t)),
			Vector3(at.x, at.y + depth * (0.16 + 0.34 * t), at.z), _wood, yaw)
	_box(Vector3(beam * 0.94, 0.08, 0.28),
		Vector3(at.x, at.y + depth * 0.68, at.z), _wood, yaw)
	for side in [-1.0, 1.0]:
		_oriented(Vector3(0.07, 0.07, length * 0.82),
			Transform3D(Basis(Vector3.UP, yaw + side * 0.2) * Basis(Vector3(1, 0, 0), 0.12),
				at + _turn(Vector3(side * beam * 0.3, depth * 0.8, 0.0), yaw)), _wood)
	return _end()


# ------------------------------------------------------------------ the mine

## A mine adit in the hillside at the edge: two props, a lintel, the spoil
## either side and the dark of the shaft behind it. The dark face is a real
## box set back from the lintel, so the mouth reads as a hole rather than as
## a doorway painted on a hill.
func adit(at: Vector3, yaw := 0.0, width := 1.8, height := 2.0) -> AABB:
	_begin()
	var prop := 0.22
	for side in [-1.0, 1.0]:
		var p: Vector3 = at + _turn(Vector3(side * (width - prop) / 2.0, 0.0, 0.0), yaw)
		_box(Vector3(prop, height, prop), p + Vector3(0.0, height / 2.0, 0.0), _wood, yaw)
	_box(Vector3(width + prop, prop, prop * 1.2),
		at + Vector3(0.0, height + prop / 2.0, 0.0), _wood, yaw)
	# the shaft, set back behind the frame
	_box(Vector3(width - prop, height - 0.1, 0.3),
		at + _turn(Vector3(0.0, 0.0, 0.34), yaw) + Vector3(0.0, (height - 0.1) / 2.0, 0.0),
		_dark, yaw)
	# the spoil heaped either side of the mouth
	for side2 in [-1.0, 1.0]:
		var s: Vector3 = at + _turn(Vector3(side2 * (width * 0.72), 0.0, -0.4), yaw)
		_kit.cone(width * 0.42, height * 0.45, s, _stone, 8)
		_round(s, width * 0.42, height * 0.45)
	return _end()


# ----------------------------------------------------------------- internals

## Start accumulating a fresh prop.
func _begin() -> void:
	_acc = AABB()
	_seen = false


func _end() -> AABB:
	return _acc if _seen else AABB()


## Widen the accumulator to hold `box`.
func _widen(box: AABB) -> void:
	_acc = box if not _seen else _acc.merge(box)
	_seen = true


## A box turned about Y, emitted and accounted for. The extent of a turned
## box is its ROTATED footprint, not its own size -- a rack at 40 degrees
## logged as its unturned box is a rack that is not there.
func _box(size: Vector3, pos: Vector3, surf: int, yaw: float) -> void:
	_kit.box(size, pos, surf, yaw)
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	var f := Vector2(size.x * c + size.z * s, size.x * s + size.z * c)
	_widen(AABB(Vector3(pos.x - f.x / 2.0, pos.y - size.y / 2.0, pos.z - f.y / 2.0),
		Vector3(f.x, size.y, f.y)))


## A box placed by an arbitrary transform. Its extent is taken from its eight
## corners, because a piece that is tilted AND rolled -- an oar, a gate brace,
## a mill paddle -- has no footprint formula.
func _oriented(size: Vector3, xform: Transform3D, surf: int) -> void:
	_kit.oriented_box(size, xform, surf)
	_oriented_extent(size, xform)


## Account for a solid of revolution about the Y axis through `centre`:
## anything `_kit.revolve`, `cone`, `drum` or `stepped_taper` puts there.
func _round(centre: Vector3, radius: float, height: float) -> void:
	_widen(AABB(centre - Vector3(radius, 0.0, radius),
		Vector3(radius * 2.0, height, radius * 2.0)))


## A gabled roof whose wall top is at `at`, ridge along the local Z of `yaw`.
## MeshKit places the slabs, and this accounts for the whole of what it
## placed: two slabs that reach half a span out and a ridge cap over them.
func _ridge(at: Vector3, yaw: float, span_x: float, along_z: float,
		rise: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), at)
	_kit.ridge_roof(xf, span_x, along_z, rise, _roof)
	var half: float = span_x / 2.0
	var slope_len: float = sqrt(half * half + rise * rise)
	var ang: float = atan2(rise, half)
	for side in [-1.0, 1.0]:
		_oriented_extent(Vector3(slope_len, 0.24, along_z),
			xf * Transform3D(Basis(Vector3(0, 0, 1), -side * ang),
				Vector3(side * half / 2.0, rise / 2.0, 0.0)))
	_oriented_extent(Vector3(0.35, 0.25, along_z + 0.2),
		xf * Transform3D(Basis(), Vector3(0.0, rise + 0.1, 0.0)))


## The extent of a box under a transform, without emitting it -- for pieces
## MeshKit emits on our behalf.
func _oriented_extent(size: Vector3, xform: Transform3D) -> void:
	var h: Vector3 = size / 2.0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p: Vector3 = xform * Vector3(h.x * sx, h.y * sy, h.z * sz)
				lo = lo.min(p)
				hi = hi.max(p)
	_widen(AABB(lo, hi - lo))


## One rim of the mill wheel, in the plane of `basis`'s XY.
func _ring(centre: Vector3, outer: float, inner: float, basis: Basis) -> void:
	var segments := 16
	for s in range(segments):
		var a: float = TAU * (float(s) + 0.5) / float(segments)
		var mid: Vector3 = basis * Vector3(cos(a) * (outer + inner) / 2.0,
			sin(a) * (outer + inner) / 2.0, 0.0)
		_oriented(Vector3(outer - inner, TAU * outer / float(segments) * 1.06, 0.1),
			Transform3D(basis * Basis(Vector3(0, 0, 1), a), centre + mid), _wood)


## Turn a local offset by `yaw` about Y.
static func _turn(v: Vector3, yaw: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * v
