import io

# ---------------------------------------------------------------- hipped
p = 'core/mesh_kit.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## hip_roof() placed by an arbitrary transform; local origin is the wall top.
func hip_roof_at(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int) -> void:
	var half: float = span_x / 2.0
	var slope_len_x: float = sqrt(half * half + rise * rise)
	var ang_x: float = atan2(rise, half)
	for side in [-1.0, 1.0]:
		var t: Transform3D = xf * Transform3D(Basis(Vector3(0, 0, 1), -side * ang_x),
			Vector3(side * half / 2.0, rise / 2.0, 0.0))
		oriented_box(Vector3(slope_len_x, 0.24, along_z * 0.72), t, surf)
	var half_along: float = along_z / 2.0
	var slope_len: float = sqrt(half_along * half_along + rise * rise)
	var ang: float = atan2(rise, half_along)
	for end_v in [-1.0, 1.0]:
		var t2: Transform3D = xf * Transform3D(Basis(Vector3(1, 0, 0), end_v * ang),
			Vector3(0.0, rise / 2.0, end_v * half_along / 2.0))
		oriented_box(Vector3(span_x * 0.72, 0.24, slope_len), t2, surf)
	oriented_box(Vector3(0.35, 0.25, along_z * 0.4),
		xf * Transform3D(Basis(), Vector3(0.0, rise + 0.1, 0.0)), surf)'''
new = '''## hip_roof() placed by an arbitrary transform; local origin is the wall top.
##
## Four slabs: two long slopes covering the ridge, and two hips falling to the
## end walls. The HIPS RUN THE FULL WIDTH, and that is the whole trick -- the
## slopes have to stop short of the ends or the hips would never show, so
## whatever the slopes do not reach has to be reached by something. Cutting
## both pairs back by the same fraction, which is what this did, left the four
## corners covered by neither: a hole in the roof you could see the floor
## through, and 4.5% of a farmhouse open to the sky.
func hip_roof_at(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int) -> void:
	var half_x: float = span_x / 2.0
	var half_z: float = along_z / 2.0
	# A hip falls back from each end by as much as the roof is wide, so a
	# square plan comes almost to a point and a long one keeps a ridge.
	var ridge: float = maxf(along_z - span_x, along_z * 0.2)
	var slope_len_x: float = sqrt(half_x * half_x + rise * rise)
	var ang_x: float = atan2(rise, half_x)
	for side in [-1.0, 1.0]:
		var t: Transform3D = xf * Transform3D(Basis(Vector3(0, 0, 1), -side * ang_x),
			Vector3(side * half_x / 2.0, rise / 2.0, 0.0))
		oriented_box(Vector3(slope_len_x, 0.24, ridge), t, surf)
	var slope_len_z: float = sqrt(half_z * half_z + rise * rise)
	var ang_z: float = atan2(rise, half_z)
	for end_v in [-1.0, 1.0]:
		var t2: Transform3D = xf * Transform3D(Basis(Vector3(1, 0, 0), end_v * ang_z),
			Vector3(0.0, rise / 2.0, end_v * half_z / 2.0))
		oriented_box(Vector3(span_x, 0.24, slope_len_z), t2, surf)
	oriented_box(Vector3(0.35, 0.25, ridge),
		xf * Transform3D(Basis(), Vector3(0.0, rise + 0.1, 0.0)), surf)'''
assert old in s, 'hip_roof_at'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('mesh_kit ok')

# ------------------------------------------------------------ half hipped
p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		var hip_span := span * 0.55
		var hip_rise := rise * 0.35
		var hip_slope := sqrt(hip_rise * hip_rise + (span * 0.28) * (span * 0.28))
		var hip_ang := atan2(hip_rise, span * 0.28)
		for end_v in [-1.0, 1.0]:
			var ht := xf * Transform3D(Basis(Vector3(1, 0, 0), end_v * hip_ang),
				Vector3(0.0, rise * 0.82, end_v * (along / 2.0 - 0.05)))
			_kit.oriented_box(Vector3(hip_span, 0.24, hip_slope), ht, SURF_ROOF)'''
new = '''		# A half hip hangs from the ridge DOWN to the gable, so its low edge
		# lands on the verge and its high edge meets the ridge. Centring the
		# slab ON the gable plane -- which is what this did -- put half of it,
		# 1.76 m of roof, out in the air beyond the end wall.
		var hip_span := span * 0.55
		var hip_rise := rise * 0.35
		var hip_run := span * 0.28
		var hip_slope := sqrt(hip_rise * hip_rise + hip_run * hip_run)
		var hip_ang := atan2(hip_rise, hip_run)
		var hip_z: float = along / 2.0 + VERGE - hip_run / 2.0
		for end_v in [-1.0, 1.0]:
			var ht := xf * Transform3D(Basis(Vector3(1, 0, 0), end_v * hip_ang),
				Vector3(0.0, rise * 0.82, end_v * hip_z))
			_kit.oriented_box(Vector3(hip_span, 0.24, hip_slope), ht, SURF_ROOF)'''
assert old in s, 'half hip'
s = s.replace(old, new)

old = '''func _build_roof() -> void:
	tag("roof")'''
new = '''## How far the roof runs past the end wall at the gable: the verge.
const VERGE := 0.25


func _build_roof() -> void:
	tag("roof")'''
assert old in s, 'verge const'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('house_builder ok')
