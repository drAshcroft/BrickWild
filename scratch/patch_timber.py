import io

p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

# ---- 1. the flue clears the ridge it comes out of
old = '''	var wall_top: float = spec.height * _storeys()
	var top: float = wall_top + minf(HouseGeometry.roof_rise(spec), 2.0) + 0.9'''
new = '''	var wall_top: float = spec.height * _storeys()
	# Above the RIDGE, not above an assumed two-metre roof. The old
	# minf(roof_rise, 2.0) sized every stack as though no roof rose higher than
	# that, so a longhall with a 5.4 m rise got a flue that stopped two and a
	# half metres short of its own ridge -- a chimney you could see the roof
	# over, which both looks wrong and would smoke back down itself.
	var top: float = wall_top + HouseGeometry.roof_rise(spec) + CHIMNEY_CLEAR'''
assert old in s, 'chimney'
s = s.replace(old, new)

old = '''func _build_chimney() -> void:'''
new = '''## How far a flue finishes above the ridge it comes out of.
const CHIMNEY_CLEAR := 0.6


func _build_chimney() -> void:'''
assert old in s, 'chimney const'
s = s.replace(old, new)

# ---- 2. the gable frame stays under the rafters
start = s.index('func _gable_frame(xf: Transform3D, span: float, along: float, rise: float) -> void:')
end = s.index('func _build_porch() -> void:')
old_block = s[start:end]
new_block = '''## The frame in the gable -- and every member of it stays UNDER THE RAFTERS.
##
## Each strut used to be stated as a run, a lift and a tilt that all had to
## agree with a roof pitch stated somewhere else, and they did not. A
## queen-post strut ran up-and-OUT from its post while the rafter it braces
## runs down-and-out, so the strut left the roof and finished three and a half
## metres out in the open air, reading as a stray roof plane crossing the real
## ones. Members are stated by their two ENDS now, and the outer end is put ON
## the rafter line rather than guessed at, so a member cannot escape the roof
## whatever the pitch turns out to be.
func _gable_frame(xf: Transform3D, span: float, along: float, rise: float) -> void:
	var half: float = span / 2.0
	# The slabs overhang the wall, so the rafter over the wall face is a little
	# higher than the wall head: this is the roof's half span, not the wall's.
	var roof_half: float = (span + 0.7) / 2.0
	for end_v in [-1.0, 1.0]:
		var z: float = end_v * (along / 2.0 + HouseGeometry.BEAM_D / 2.0 - 0.01)
		# Tie beam across the base of the gable
		_kit.oriented_box(Vector3(span, HouseGeometry.PLATE_H, HouseGeometry.BEAM_D),
			xf * Transform3D(Basis(), Vector3(0.0, HouseGeometry.PLATE_H / 2.0, z)),
			SURF_TRIM)

		match spec.gable_truss:
			&"queen_post":
				var qx: float = half * 0.42
				var collar_h: float = minf(rise * 0.52, _under_rafter(qx, roof_half, rise))
				for qs in [-1.0, 1.0]:
					_member(xf, Vector2(qs * qx, 0.0), Vector2(qs * qx, collar_h),
						z, HouseGeometry.BEAM_W)
				_member(xf, Vector2(-qx, collar_h), Vector2(qx, collar_h), z,
					HouseGeometry.BEAM_W * 0.9)
				# and the strut down from the collar onto the rafter, which is
				# the direction a rafter actually goes
				for qs2 in [-1.0, 1.0]:
					var foot: float = qx + half * 0.45
					_member(xf, Vector2(qs2 * qx, collar_h),
						Vector2(qs2 * foot, _under_rafter(foot, roof_half, rise)),
						z, HouseGeometry.BEAM_W * 0.8)
			&"collar_strut":
				var ch: float = minf(rise * 0.45,
					_under_rafter(span * 0.275, roof_half, rise))
				_member(xf, Vector2(-span * 0.275, ch), Vector2(span * 0.275, ch), z,
					HouseGeometry.BEAM_W * 0.9)
				_member(xf, Vector2(0.0, ch),
					Vector2(0.0, _under_rafter(0.0, roof_half, rise)), z,
					HouseGeometry.BEAM_W)
				for side in [-1.0, 1.0]:
					var run: float = half * 0.35
					_member(xf, Vector2(0.0, 0.0),
						Vector2(side * run,
							minf(ch * 0.9, _under_rafter(run, roof_half, rise))),
						z, HouseGeometry.BEAM_W * 0.8)
			_: # &"king_post"
				_member(xf, Vector2(0.0, 0.0),
					Vector2(0.0, _under_rafter(0.0, roof_half, rise)), z,
					HouseGeometry.BEAM_W)
				for side2 in [-1.0, 1.0]:
					var run2: float = half * 0.55
					_member(xf, Vector2(0.0, 0.0),
						Vector2(side2 * run2, _under_rafter(run2, roof_half, rise)),
						z, HouseGeometry.BEAM_W * 0.85)


## The underside of the rafter over `x`, in the gable's own space, with the
## member's own depth already taken off -- a beam whose centre line lands here
## does not poke through the slates.
static func _under_rafter(x: float, roof_half: float, rise: float) -> float:
	return maxf(rise * (1.0 - absf(x) / roof_half) - HouseGeometry.BEAM_W, 0.0)


## One member of a gable frame, between two points in the gable's own plane.
##
## Stating a beam by its ends rather than by a run, a lift and a tilt is the
## whole point: the three could disagree, and did.
func _member(xf: Transform3D, a: Vector2, b: Vector2, z: float,
		width: float) -> void:
	var d: Vector2 = b - a
	var run: float = d.length()
	if run < 0.05:
		return
	var mid: Vector2 = (a + b) / 2.0
	_kit.oriented_box(Vector3(run, width, HouseGeometry.BEAM_D),
		xf * Transform3D(Basis(Vector3(0, 0, 1), atan2(d.y, d.x)),
			Vector3(mid.x, mid.y, z)), SURF_TRIM)


'''
s = s[:start] + new_block + s[end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
