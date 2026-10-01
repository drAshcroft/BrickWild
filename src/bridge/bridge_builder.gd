class_name BridgeBuilder
extends RefCounted
## Emits a bridge's mesh from a BridgeSpec. Four kinds, one builder.
##
## Same contract as the rest: everything it needs is on the spec, and it draws
## no dice. `spec.members` is a list of `{role, a, b, surf, carries}` and this
## file is mostly a dispatch on `role` -- because a bridge is not a solid, it is
## a set of MEMBERS, and the difference between a good one and a bad one is
## entirely in how each member is drawn. An arch ring drawn as a smooth band is
## a tunnel roof; the same ring drawn as VOUSSOIRS is an arch.
##
## Four roles carry most of the character:
##
##   arch_ring    a semicircular ring cut into wedge blocks with a mortar joint
##                between each. The joint is the whole point.
##   main_cable   a tube swept along the sampled parabola, so it CURVES.
##   post         a tapered square post with a chamfered head.
##   parapet      a pierced wall with a coping course that overhangs both faces.
##
## Everything else falls back to a beam, which is right for the members that
## already are beams: a side beam, a hand rail, a lift rope, a drawbridge leaf.
##
## Drawn through `MeshKit.oriented_box` for every member, because a member is
## a length with a section and that is exactly what an oriented box is. One
## primitive, every role, no second opinion about winding anywhere.

var kit: MeshKit
## The deck, one row per laid slab: {"a": Vector3, "b": Vector3, "carries"}.
## The check walks the road the same way the builder laid it.
var deck_log: Array[Dictionary] = []
## Every support: {"x", "w", "top", "bottom", "kind"}.
var pier_log: Array[Dictionary] = []

## How many wedge blocks an arch ring is cut into. Thirteen reads as masonry and
## is still an arch and not a staircase.
const VOUSSOIRS := 13
## The mortar joint between two voussoirs, as a fraction of the block's sweep.
const JOINT := 0.055
## How deep a cutwater stands proud of a pier.
const CUTWATER := 1.5


func build(spec: BridgeSpec) -> ArrayMesh:
	kit = MeshKit.new(BridgeSpec.SURFACE_COUNT)
	deck_log = []
	pier_log = []
	_piers(spec)
	_deck(spec)
	for m in spec.members:
		_member(spec, m)
	# commit_named: a bridge with no timber would otherwise hand its deck the
	# timber material, one surface along
	return BridgeGeometry.fit_mesh(kit.commit_named(), spec)


# ------------------------------------------------------------------ members

## One member, drawn according to what it IS.
func _member(spec: BridgeSpec, m: Dictionary) -> void:
	var role: StringName = m["role"]
	var a: Vector3 = m["a"]
	var b: Vector3 = m["b"]
	var surf: int = int(m["surf"])
	match role:
		&"arch_ring":
			_arch_ring(spec, a, b, surf)
		&"main_cable":
			_beam(a, b, _r(role, spec) * 2.0, _r(role, spec) * 2.0, surf, 6)
		&"hanger", &"backstay", &"lift_rope", &"ridge", &"side_beam", &"cross_beam", &"rafter", &"pivot", &"lift_beam":
			var r: float = _r(role, spec)
			_beam(a, b, r * 2.0, r * 2.0, surf, 6 if role == &"pivot" else 4)
		&"post":
			_beam(a, b, 0.38, 0.38, surf, 4)
			# A chamfered head, so the post meets the beam it carries instead of
			# stopping at it.
			_beam(a.lerp(b, 0.94), b, 0.50, 0.50, surf, 4)
		&"parapet":
			_parapet(spec, a, b, surf)
		&"string_course":
			# A band that PROJECTS past the wall face. It is the only reason a
			# long stone elevation reads as masonry and not as a ribbon of colour.
			_beam(a, b, 0.34, 0.34, surf, 4, Vector3(0.0, 0.0, 1.0),
				spec.width * 0.08)
		&"roof":
			# A SLOPING PLANE: the member runs from the eave up to the ridge, so
			# its "width" is the slope's own length in plan and its depth is the
			# board thickness measured perpendicular to it.
			var run: float = absf(b.z - a.z)
			var climb: float = absf(b.y - a.y)
			_beam(a, b, 0.18, 0.18, surf, 4, Vector3(0.0, 1.0, 0.0),
				sqrt(run * run + climb * climb))
		&"wall_panel":
			_beam(a, b, 1.05, 0.14, surf, 4, Vector3(0.0, 0.0, 1.0), 0.07)
		&"hand_rail":
			_beam(a, b, 0.11, 0.11, surf, 4)
		&"leaf":
			# A drawbridge leaf is a DECK, not a beam: wide, thin, and with
			# something along its edges.
			_beam(a, b, spec.deck_thickness, 0.18, surf, 4, Vector3(0.0, 0.0, 1.0),
				spec.width * 0.5)
		&"spandrel":
			_beam(a, b, 0.16, spec.width * 0.5, surf, 4, Vector3(1.0, 0.0, 0.0),
				absf(b.x - a.x) * 0.5)
		&"gable_end":
			_beam(a, b, 0.2, 0.2, surf, 4, Vector3(0.0, 0.0, 1.0), spec.width * 0.5)
		&"swing_boom", &"float":
			_beam(a, b, 0.2, 0.2, surf, 4, Vector3(0.0, 0.0, 1.0),
				spec.width * 0.42 if role == &"swing_boom" else 0.5)
		_:
			_beam(a, b, 0.2, 0.2, surf, 4)


## An arch ring as VOUSSOIRS. The joints between the wedge blocks are the whole
## difference: a smooth band along the same semicircle is a tunnel roof, and a
## semicircle cut into thirteen wedges with a mortar line between each is an
## arch, because that is what an arch IS. Each block is also a little wider on
## the extrados than on the intrados, which is why a real ring thickens towards
## the crown and a stack of identical slabs does not.
func _arch_ring(spec: BridgeSpec, a: Vector3, b: Vector3, surf: int) -> void:
	var axis: Vector3 = b - a
	var len: float = axis.length()
	if len < 1e-4:
		return
	var across := Vector3(0.0, 0.0, 1.0)
	var n: Vector3 = axis.normalized()
	var p := n.cross(across).normalized()
	if p.length() < 0.1:
		p = n.cross(Vector3(1.0, 0.0, 0.0)).normalized()
	var k: int = maxi(4, mini(VOUSSOIRS, int(round(len / maxf(spec.span * 0.012, 0.3)))))
	# The radial at the block's centre: the tangent turned ninety degrees in the
	# plane the arch is drawn in, and nothing to do with the channel's width.
	var radial := Vector3(-n.y, n.x, 0.0)
	if radial.length() < 0.1:
		radial = across
	# The ring's depth, into the spandrel. A third of the arch's rise is the
	# usual proportion and the opening closes up below about a fifth.
	var rise: float = maxf(len * 0.5, 0.4)
	var deep: float = maxf(rise * 0.42, 0.3)
	for i in range(k):
		var t0: float = float(i) / float(k) + JOINT * 0.5
		var t1: float = float(i + 1) / float(k) - JOINT * 0.5
		if t1 <= t0:
			continue
		# The block's centre, and its depth at the crown versus at the springing.
		var tc: float = (t0 + t1) * 0.5
		var h: float = sin(PI * clampf(tc, 0.0, 1.0))
		var mid: Vector3 = a + axis * tc + p * (deep * 0.5 * (0.55 + 0.75 * h))
		# The block's DEPTH is RADIAL -- along the arch's own normal, pointing at
		# the centre of the ring -- and its width runs across the channel.
		# Measuring the depth across the channel instead lays every voussoir
		# flat like a louvre blade, and a fan of flat plates is not an arch.
		_beam(a + axis * t0, a + axis * t1, deep * (0.55 + 0.75 * h), 0.34, surf, 4,
			radial, spec.width * 0.92, mid, axis)


## A beam from a to b. `up` is the direction its WIDTH is measured along, and
## `mid` an optional override for where the block's centre sits -- which is what
## lets a voussoir be a wedge on one axis and radial on the other.
func _beam(a: Vector3, b: Vector3, thick: float, wide: float, surf: int,
		sides := 4, up := Vector3.ZERO, wide_scale := 0.0,
		mid := Vector3.INF, along := Vector3.INF) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 1e-4:
		return
	var local_x: Vector3 = along if along != Vector3.INF else d.normalized()
	var local_y: Vector3 = Vector3.UP
	if up != Vector3.ZERO:
		local_y = up
	if absf(local_y.dot(local_x)) > 0.98:
		local_y = Vector3.FORWARD if absf(local_x.dot(Vector3.FORWARD)) < 0.9 \
			else Vector3.RIGHT
	var local_z: Vector3 = local_x.cross(local_y).normalized()
	local_y = local_z.cross(local_x).normalized()
	var basis := Basis(local_x, local_y, local_z)
	var centre: Vector3 = mid if mid != Vector3.INF else (a + b) * 0.5
	kit.oriented_box(Vector3(length + 0.03, thick, wide_scale if wide_scale > 0.0 else wide),
		Transform3D(basis, centre), surf)


## A pier or an abutment. The footing goes DOWN into the bank, because the one
## thing a bridge must never do is hover over the ground it is drawn against.
func _piers(spec: BridgeSpec) -> void:
	var half: float = spec.span * 0.5
	var hz: float = spec.width * 0.5
	for p in spec.piers:
		var x: float = float(p["x"])
		var w: float = float(p["w"])
		var top: float = float(p["top"])
		var kind: StringName = p["kind"]
		var bottom: float = spec.water_level - 0.7
		if kind != &"pier" and kind != &"pontoon":
			bottom = minf(BridgeGeometry.bank_height_at(spec, x)
				- BridgeGeometry.FOOTING, spec.water_level)
		pier_log.append({"x": x, "w": w, "top": top, "bottom": bottom,
			"kind": kind})
		match kind:
			&"tower":
				_tower(spec, x, w, bottom, top, hz)
			&"pontoon":
				kit.oriented_box(
					Vector3(w, spec.pontoon_draft, hz * 1.7),
					Transform3D(Basis(), Vector3(x,
						spec.water_level - spec.pontoon_draft * 0.5, 0.0)),
					BridgeSpec.SURF_TIMBER)
			_:
				_battered(spec, x, w, bottom, top, hz, kind == &"pier")
	if spec.kind == &"stone" or spec.kind == &"rope":
		_abutments(spec, half, hz)


## A masonry pier or abutment wall, BATTERED. The batter is not decoration: it
## is why the thing stands up, and a masonry pier with vertical sides reads as
## a box standing in a river. Two battered walls either side of the roadway,
## with a road slab between them.
func _battered(spec: BridgeSpec, x: float, w: float, bottom: float, top: float,
		hz: float, cutwater: bool) -> void:
	var foot: float = w * (1.0 + BridgeGeometry.ABUT_SPREAD * 0.35)
	for sz in [-1.0, 1.0]:
		kit.cone(0.0, 0.0, Vector3.ZERO, 0, 0)   # no-op guard for empty kits
		_taper(spec, Vector3(x, bottom, hz * 0.86 * sz),
			Vector3(x, top, hz * 0.5 * sz), foot, w, BridgeSpec.SURF_STONE)
	kit.oriented_box(Vector3(w, 0.34, hz * 1.06),
		Transform3D(Basis(), Vector3(x, top - 0.17, 0.0)), BridgeSpec.SURF_STONE)
	# A coping course that overhangs, so the top of the pier catches a shadow.
	kit.oriented_box(Vector3(w * 1.15, 0.16, hz * 1.14),
		Transform3D(Basis(), Vector3(x, top + 0.08, 0.0)), BridgeSpec.SURF_STONE)
	if cutwater:
		# A triangular cutwater on the upstream face. Two wedges and a nose:
		# it is the detail that stops a masonry pier looking extruded, and it
		# is the only asymmetry a pier has.
		var cw: float = w * CUTWATER
		var nose := Vector3(x, 0.0, -hz * 0.86 - cw * 0.5)
		_taper(spec, Vector3(x, bottom, -hz * 0.86), nose + Vector3(0, 0, cw * 0.5),
			w * 0.9, w * 0.55, BridgeSpec.SURF_STONE)
		_taper(spec, Vector3(x, top, -hz * 0.86),
			nose + Vector3(0, 0, cw * 0.5), w * 0.8, w * 0.45, BridgeSpec.SURF_STONE)


## A suspension tower: a pair of legs leaning IN, because a tower that leans
## out is a pylon and a tower that stands dead straight is a mast. The lean is
## what says "it holds something up".
func _tower(spec: BridgeSpec, x: float, w: float, bottom: float, top: float,
		hz: float) -> void:
	var lean: float = spec.tower_tilt * spec.width * signf(x)
	for sz in [-1.0, 1.0]:
		_taper(spec, Vector3(x, bottom, hz * 0.80 * sz),
			Vector3(x - lean, top, hz * 0.56 * sz), w * 0.7, w * 0.5,
			BridgeSpec.SURF_STONE)
	# The crossbeam, and a cap over each leg. A tower with a crossbeam is a
	# frame; a tower with two posts is a goalpost.
	kit.oriented_box(Vector3(w * 0.8, w * 0.5, hz * 1.35),
		Transform3D(Basis(), Vector3(x - lean, top - w * 0.4, 0.0)),
		BridgeSpec.SURF_STONE)
	for sz in [-1.0, 1.0]:
		kit.oriented_box(Vector3(w * 0.9, 0.18, w * 0.9),
			Transform3D(Basis(), Vector3(x - lean, top + 0.09, hz * 0.56 * sz)),
			BridgeSpec.SURF_STONE)


## The two abutments get WING walls splayed back into the bank. Without them a
## bridge ends in a cliff, and with them it ends in a road.
func _abutments(spec: BridgeSpec, half: float, hz: float) -> void:
	for p in spec.piers:
		if p["kind"] != &"abutment":
			continue
		var x: float = float(p["x"])
		var out: float = signf(x) * (half + spec.bank_run * 0.5)
		var g1: float = BridgeGeometry.bank_height_at(spec, out) - 0.5
		var g0: float = BridgeGeometry.bank_height_at(spec, x) - 0.5
		for sz in [-1.0, 1.0]:
			_taper(spec, Vector3(x, g0 - BridgeGeometry.FOOTING * 0.6, hz * 0.5 * sz),
				Vector3(out, g1, hz * 0.66 * sz), spec.pier_width,
				spec.pier_width * 0.45, BridgeSpec.SURF_STONE)


## A wall that is wider at the bottom than the top.
func _taper(spec: BridgeSpec, a: Vector3, b: Vector3, wa: float, wb: float,
		surf: int) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 1e-4:
		return
	var axis: Vector3 = d.normalized()
	var up := Vector3.UP
	if absf(axis.dot(up)) > 0.97:
		up = Vector3.FORWARD
	var side := axis.cross(up).normalized()
	up = side.cross(axis).normalized()
	var centre: Vector3 = (a + b) * 0.5
	# One box, scaled by putting the wider half below: a batter is a taper and
	# MeshKit has no taper, so it is a box plus a narrower box above it.
	kit.oriented_box(Vector3(wa, length * 0.5, wa),
		Transform3D(Basis(axis, up, side), a.lerp(b, 0.25)), surf)
	kit.oriented_box(Vector3(wb, length * 0.5, wb),
		Transform3D(Basis(axis, up, side), a.lerp(b, 0.75)), surf)


# --------------------------------------------------------------------- deck

## The walking surface, laid station by station so it follows the camber. A
## stone bridge's road rises over its crown; the other three are flat, and the
## whole difference is one line in `BridgeGeometry.deck_height_at`.
func _deck(spec: BridgeSpec) -> void:
	var hw: float = spec.width * 0.5
	var t: float = spec.deck_thickness
	var pts: Array = spec.deck
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid: Vector3 = Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5 - t * 0.5, 0.0)
		kit.oriented_box(Vector3(absf(b.x - a.x) + 0.02, t, hw * 2.0),
			Transform3D(Basis(), mid), BridgeSpec.SURF_DECK)
		deck_log.append({"a": Vector3(a.x, a.y, 0.0), "b": Vector3(b.x, b.y, 0.0),
			"carries": PackedFloat32Array([minf(a.x, b.x), maxf(a.x, b.x)])})
	# Transverse deck timbers along the fascia. Cheap, and they are what a
	# timber deck is actually made of.
	var n: int = clampi(int(spec.span / 0.42), 4, 220)
	for i in range(n + 1):
		var x: float = -spec.span * 0.5 + spec.span * float(i) / float(n)
		kit.oriented_box(Vector3(0.15, t * 1.06, hw * 2.08),
			Transform3D(Basis(), Vector3(x,
				BridgeGeometry.deck_height_at(spec, x) - t * 0.5, 0.0)),
			BridgeSpec.SURF_TIMBER)


## A parapet: a pierced wall with a coping course. The piercings are not
## decoration -- a blank parapet is a wall, and a pierced one is a parapet, and
## the light coming through it is half of why a stone bridge looks the way it
## does from a distance.
func _parapet(spec: BridgeSpec, a: Vector3, b: Vector3, surf: int) -> void:
	var h: float = spec.parapet_height
	var w: float = spec.parapet_width
	var len: float = absf(b.x - a.x) + 0.06
	var z: float = a.z
	var y: float = a.y
	var slots: int = clampi(int(len / 1.4), 0, 64)
	if slots == 0:
		kit.oriented_box(Vector3(len, h, w), Transform3D(Basis(),
			Vector3((a.x + b.x) * 0.5, y + h * 0.5, z)), surf)
	else:
		var pitch: float = len / float(slots)
		for i in range(slots):
			var cx: float = a.x + pitch * (float(i) + 0.5)
			# Two piers either side of each opening: a short one and a long one,
			# alternating, which is the rhythm a real parapet has.
			kit.oriented_box(Vector3(pitch * 0.34, h, w),
				Transform3D(Basis(), Vector3(cx - pitch * 0.33, y + h * 0.5, z)), surf)
			kit.oriented_box(Vector3(pitch * 0.22, h, w),
				Transform3D(Basis(), Vector3(cx + pitch * 0.39, y + h * 0.5, z)), surf)
		# A sill under the openings, and a lintel over: a parapet is a wall with
		# windows in it, and a wall with slots is a fence.
		kit.oriented_box(Vector3(len, 0.22, w * 1.06),
			Transform3D(Basis(), Vector3((a.x + b.x) * 0.5, y + 0.11, z)), surf)
		kit.oriented_box(Vector3(len, 0.18, w * 1.12),
			Transform3D(Basis(), Vector3((a.x + b.x) * 0.5, y + h - 0.09, z)), surf)
	# The coping, overhanging both faces -- the only part of a parapet that
	# catches a shadow and the only part that reads from above.
	kit.oriented_box(Vector3(len, 0.17, w * 1.6),
		Transform3D(Basis(), Vector3((a.x + b.x) * 0.5, y + h + 0.09, z)), surf)


static func _r(role: StringName, spec: BridgeSpec) -> float:
	match role:
		&"main_cable":
			return maxf(spec.width * 0.023, 0.055)
		&"hanger", &"backstay", &"lift_rope":
			return maxf(spec.width * 0.011, 0.03)
		&"ridge", &"lift_beam":
			return maxf(spec.width * 0.05, 0.10)
		&"side_beam", &"cross_beam", &"rafter":
			return maxf(spec.width * 0.055, 0.11)
		&"pivot":
			return maxf(spec.width * 0.10, 0.18)
	return 0.08
