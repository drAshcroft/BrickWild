import io

# ---- 1. a four-cornered plate, so a roof face can taper
p = 'core/mesh_kit.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## Hipped roof: side slabs plus sloped ends, so all four sides fall away.'''
new = '''## A four-cornered plate of `thickness`, given its corners in order round the
## face: a-b along one edge, c-d back along the other. The corners do NOT have
## to form a rectangle, which is the point -- a hip face is a trapezoid, wide
## where it meets the wall and narrow where it meets the ridge, and a rectangle
## laid over the roof instead of it matches nothing at either end.
func plate(a: Vector3, b: Vector3, c: Vector3, d: Vector3, thickness: float,
		surf: int) -> void:
	var n: Vector3 = (b - a).cross(d - a)
	if n.length_squared() < 1e-12:
		return
	var off: Vector3 = n.normalized() * (thickness / 2.0)
	# the corner order _emit_box triangulates: see _corners()
	_emit_box([a - off, b - off, b + off, a + off,
		c - off, d - off, d + off, c + off], surf)


## Hipped roof: side slabs plus sloped ends, so all four sides fall away.'''
assert old in s, 'plate'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('mesh_kit ok')

# ---- 2. a real jerkinhead: the ridge stops short and a hip closes the end
p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

start = s.index('\tvar gable_top: float = rise\n')
end = s.index('\tvar overhang_x := 0.25 if along_x else 0.35')
old_block = s[start:end]
new_block = '''	# Where the gable stops. A plain gable runs to its apex; a half hip -- a
	# jerkinhead -- takes the top off, and then the WALL, the TRUSS and the
	# BARGEBOARDS all have to stop on the line the hip starts on.
	var gable_top: float = rise
	# and how far in from the end the ridge stops, so the hip has somewhere to
	# be. The hip takes the same pitch as the main slopes, which is what makes
	# its edges land on the slope edges instead of crossing them.
	var hip_run: float = 0.0
	if spec.roof_type == &"half_hipped":
		gable_top = rise * HIP_CUT
		hip_run = (span / 2.0 + 0.35) * (1.0 - HIP_CUT)

	if spec.roof_type == &"hipped":
		_kit.hip_roof_at(xf, span + 0.7, along + 0.5, rise, SURF_ROOF)
	elif spec.roof_type == &"half_hipped":
		# The slopes stop short of each end. Run full length, as they were,
		# the roof is already closed there and the hip becomes an extra plane
		# lying on top of it, matching nothing at either edge.
		_kit.ridge_roof(xf, span + 0.7, along + 0.5 - hip_run * 2.0, rise, SURF_ROOF)
		_hip_faces(xf, span, along, rise, gable_top, hip_run)
		_half_hip_gables(xf, span, along, rise, gable_top)
	else:
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)

'''
s = s[:start] + new_block + s[end:]

old = '''## How far the roof runs past the end wall at the gable: the verge.
const VERGE := 0.25'''
new = '''## How far the roof runs past the end wall at the gable: the verge.
const VERGE := 0.25
## How much of a half-hipped roof is still gable, measured up from the wall
## head. The rest is hipped off.
const HIP_CUT := 0.62


## The two hip faces of a jerkinhead: from the shortened ridge down and out to
## the top of the gable, tapering as they go, so the sloping edge of each hip
## lands exactly on the sloping edge of the slope beside it.
func _hip_faces(xf: Transform3D, span: float, along: float, rise: float,
		cut: float, hip_run: float) -> void:
	var half: float = span / 2.0 + 0.35             # the slabs overhang
	var wide: float = half * (1.0 - cut / rise)     # half width at the gable
	var narrow := 0.175                             # half width at the ridge
	var z_gable: float = along / 2.0 + VERGE
	var z_ridge: float = z_gable - hip_run
	for end_v in [-1.0, 1.0]:
		var zg: float = end_v * z_gable
		var zr: float = end_v * z_ridge
		_kit.plate(
			xf * Vector3(-narrow * end_v, rise, zr),
			xf * Vector3(narrow * end_v, rise, zr),
			xf * Vector3(wide * end_v, cut, zg),
			xf * Vector3(-wide * end_v, cut, zg),
			0.24, SURF_ROOF)


## The gable under a half hip: a trapezoid, stopping where the hip starts.
func _half_hip_gables(xf: Transform3D, span: float, along: float, rise: float,
		cut: float) -> void:
	var ex: float = span / 2.0
	var apex: float = rise * (ex / (span / 2.0 + 0.35))
	for end_v in [-1.0, 1.0]:
		var zf: float = end_v * along / 2.0
		_kit.gable_end_at(xf, ex, apex, zf - end_v * 0.3, zf, SURF_WALL,
			minf(cut, apex - 0.05))'''
assert old in s, 'verge const'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('house_builder ok')
