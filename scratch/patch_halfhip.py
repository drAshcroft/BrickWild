import io

# ---- 1. a gable may be a trapezoid, because a hip cuts its apex off
p = 'core/mesh_kit.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## gable_end() in the local space of `xf`, whose origin is the wall top.
func gable_end_at(xf: Transform3D, half_span: float, rise: float,
		z_back: float, z_front: float, surf: int) -> void:
	var lo: float = minf(z_back, z_front)
	var hi: float = maxf(z_back, z_front)
	var xy := [
		Vector2(-half_span, 0.0),
		Vector2(half_span, 0.0),
		Vector2(0.0, rise),
	]
	var at_lo: Array = []
	var at_hi: Array = []
	for p in xy:
		at_lo.append(xf * Vector3(p.x, p.y, lo))
		at_hi.append(xf * Vector3(p.x, p.y, hi))
	var st: SurfaceTool = _sts[surf]
	_tri(st, at_lo[0], at_lo[1], at_lo[2])      # faces -Z
	_tri(st, at_hi[0], at_hi[2], at_hi[1])      # faces +Z
	for i in range(3):
		var j: int = (i + 1) % 3
		_quad(st, at_lo[i], at_hi[i], at_hi[j], at_lo[j])'''
new = '''## gable_end() in the local space of `xf`, whose origin is the wall top.
##
## `cut` truncates the apex at that height, which turns the triangle into a
## TRAPEZOID: a half hip takes the top off the gable, and the wall has to stop
## where the hip starts. Left full height, the wall carries on up behind the
## hip and the hip reads as a stray plane lying across the roof rather than as
## the end of it.
func gable_end_at(xf: Transform3D, half_span: float, rise: float,
		z_back: float, z_front: float, surf: int, cut := 0.0) -> void:
	var lo: float = minf(z_back, z_front)
	var hi: float = maxf(z_back, z_front)
	var xy: Array[Vector2] = [Vector2(-half_span, 0.0), Vector2(half_span, 0.0)]
	if cut > 0.0 and cut < rise:
		var w: float = half_span * (1.0 - cut / rise)
		xy.append(Vector2(w, cut))
		xy.append(Vector2(-w, cut))
	else:
		xy.append(Vector2(0.0, rise))
	var n: int = xy.size()
	var at_lo: Array = []
	var at_hi: Array = []
	for p in xy:
		at_lo.append(xf * Vector3(p.x, p.y, lo))
		at_hi.append(xf * Vector3(p.x, p.y, hi))
	var st: SurfaceTool = _sts[surf]
	# fanned from corner 0, which is safe: the outline is convex either way
	for i in range(1, n - 1):
		_tri(st, at_lo[0], at_lo[i], at_lo[i + 1])      # faces -Z
		_tri(st, at_hi[0], at_hi[i + 1], at_hi[i])      # faces +Z
	for i2 in range(n):
		var j: int = (i2 + 1) % n
		_quad(st, at_lo[i2], at_hi[i2], at_hi[j], at_lo[j])'''
assert old in s, 'gable_end_at'
s = s.replace(old, new)

old = '''func ridge_roof(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int, end_surf := -1, end_span := 0.0, end_along := 0.0,
		end_thick := 0.3) -> void:'''
new = '''func ridge_roof(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int, end_surf := -1, end_span := 0.0, end_along := 0.0,
		end_thick := 0.3, end_cut := 0.0) -> void:'''
assert old in s, 'ridge_roof sig'
s = s.replace(old, new)

old = '''		gable_end_at(xf, ex, apex, zf - end_v * end_thick, zf, end_surf)'''
new = '''		gable_end_at(xf, ex, apex, zf - end_v * end_thick, zf, end_surf, end_cut)'''
assert old in s, 'ridge_roof call'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('mesh_kit ok')

# ---- 2. the house says where its gable stops, and everything obeys it
p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	if spec.roof_type == &"hipped":
		_kit.hip_roof_at(xf, span + 0.7, along + 0.5, rise, SURF_ROOF)
	elif spec.roof_type == &"half_hipped":
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)
		# A half hip hangs from the ridge DOWN to the gable, so its low edge
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
			_kit.oriented_box(Vector3(hip_span, 0.24, hip_slope), ht, SURF_ROOF)
	else:
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)'''
new = '''	# Where the gable stops. A plain gable runs to its apex; a half hip takes
	# the top off, and then the WALL, the TRUSS and the BARGEBOARDS all have to
	# stop at the same line the hip starts on. They did not, which is why a
	# half-hipped house had a full-height gable standing up behind its own hip
	# with two bargeboards crossing over an apex that was not there any more.
	var gable_top: float = rise
	if spec.roof_type == &"half_hipped":
		gable_top = rise * 0.82 - rise * 0.35 / 2.0
	if spec.roof_type == &"hipped":
		_kit.hip_roof_at(xf, span + 0.7, along + 0.5, rise, SURF_ROOF)
	elif spec.roof_type == &"half_hipped":
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL,
			span, along, 0.3, gable_top)
		# A half hip hangs from the ridge DOWN to the gable, so its low edge
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
			_kit.oriented_box(Vector3(hip_span, 0.24, hip_slope), ht, SURF_ROOF)
	else:
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)'''
assert old in s, 'roof branch'
s = s.replace(old, new)

old = '''	if spec.timber_frame and spec.roof_type != &"hipped":
		_gable_frame(xf, span, along, rise)
	if spec.roof_type != &"hipped":
		_build_bargeboards(xf, span, along, rise)'''
new = '''	if spec.timber_frame and spec.roof_type != &"hipped":
		_gable_frame(xf, span, along, rise, gable_top)
	if spec.roof_type != &"hipped":
		_build_bargeboards(xf, span, along, rise, gable_top)'''
assert old in s, 'roof calls'
s = s.replace(old, new)

old = '''func _build_bargeboards(xf: Transform3D, span: float, along: float, rise: float) -> void:
	if not spec.bargeboards:
		return
	tag("bargeboards")
	var half := span / 2.0
	var slope_len := sqrt(half * half + rise * rise) + 0.35
	var ang := atan2(rise, half)
	var bb_w: float = HouseGeometry.BARGEBOARD_W
	var bb_thick := 0.05
	for end_v in [-1.0, 1.0]:
		var z: float = float(end_v) * (along / 2.0 + 0.28)
		for side in [-1.0, 1.0]:
			var bx: float = float(side) * half / 2.0
			var by: float = rise / 2.0
			var t := xf * Transform3D(Basis(Vector3(0, 0, 1), -float(side) * ang), Vector3(bx, by, z))
			_kit.oriented_box(Vector3(slope_len, bb_w, bb_thick), t, SURF_TRIM)
		# Carved apex finial at the ridge
		_kit.oriented_box(Vector3(0.12, 0.55, 0.12),
			xf * Transform3D(Basis(), Vector3(0.0, rise + 0.22, z)), SURF_TRIM)
		# Drop pendants at the eaves
		for side in [-1.0, 1.0]:
			_kit.oriented_box(Vector3(0.09, 0.24, 0.09),
				xf * Transform3D(Basis(), Vector3(float(side) * (half + 0.15), -0.05, z)), SURF_TRIM)'''
new = '''## The boards along the verge, and the finial where they meet.
##
## `top` is where the gable stops: the apex on a plain gable, the hip line on a
## half hip. Each board runs from the eaves UP TO THAT POINT and no further,
## with its kick left at the eaves end where a bargeboard kick belongs. Run to
## a fixed slope length centred on the slope, as they were, they over-ran the
## apex by 0.18 m and crossed each other above the ridge -- and on a half hip
## they climbed to an apex the roof no longer had.
func _build_bargeboards(xf: Transform3D, span: float, along: float, rise: float,
		top: float) -> void:
	if not spec.bargeboards:
		return
	tag("bargeboards")
	var half := span / 2.0
	var ang := atan2(rise, half)
	var bb_w: float = HouseGeometry.BARGEBOARD_W
	var bb_thick := 0.05
	var kick := 0.35
	# where the board finishes: the apex, or the hip line on a half hip
	var up := Vector2(half * (1.0 - top / rise), top)
	for end_v in [-1.0, 1.0]:
		var z: float = float(end_v) * (along / 2.0 + 0.28)
		for side in [-1.0, 1.0]:
			var a := Vector2(float(side) * half, 0.0)
			var b := Vector2(float(side) * up.x, up.y)
			var dir: Vector2 = (a - b).normalized()
			var foot: Vector2 = a + dir * kick
			var mid: Vector2 = (foot + b) / 2.0
			var t := xf * Transform3D(Basis(Vector3(0, 0, 1), -float(side) * ang),
				Vector3(mid.x, mid.y, z))
			_kit.oriented_box(Vector3((foot - b).length(), bb_w, bb_thick), t, SURF_TRIM)
		# A finial stands on an apex. A half hip has none, so it gets none.
		if is_equal_approx(top, rise):
			_kit.oriented_box(Vector3(0.12, 0.55, 0.12),
				xf * Transform3D(Basis(), Vector3(0.0, rise + 0.22, z)), SURF_TRIM)
		# Drop pendants at the eaves
		for side2 in [-1.0, 1.0]:
			_kit.oriented_box(Vector3(0.09, 0.24, 0.09),
				xf * Transform3D(Basis(), Vector3(float(side2) * (half + 0.15), -0.05, z)),
				SURF_TRIM)'''
assert old in s, 'bargeboards'
s = s.replace(old, new)

old = '''func _gable_frame(xf: Transform3D, span: float, along: float, rise: float) -> void:
	var half: float = span / 2.0
	# The slabs overhang the wall, so the rafter over the wall face is a little
	# higher than the wall head: this is the roof's half span, not the wall's.
	var roof_half: float = (span + 0.7) / 2.0'''
new = '''func _gable_frame(xf: Transform3D, span: float, along: float, rise: float,
		top: float) -> void:
	var half: float = span / 2.0
	# The slabs overhang the wall, so the rafter over the wall face is a little
	# higher than the wall head: this is the roof's half span, not the wall's.
	var roof_half: float = (span + 0.7) / 2.0
	_frame_top = top'''
assert old in s, 'gable_frame sig'
s = s.replace(old, new)

old = '''static func _under_rafter(x: float, roof_half: float, rise: float) -> float:
	return maxf(rise * (1.0 - absf(x) / roof_half) - HouseGeometry.BEAM_W, 0.0)'''
new = '''func _under_rafter(x: float, roof_half: float, rise: float) -> float:
	return clampf(rise * (1.0 - absf(x) / roof_half) - HouseGeometry.BEAM_W,
		0.0, maxf(_frame_top - HouseGeometry.BEAM_W, 0.0))


## Where the gable the frame stands in stops, set by _gable_frame before it
## places anything. A truss inside a half-hipped gable may not climb past the
## hip any more than the wall may.
var _frame_top := INF'''
assert old in s, 'under_rafter'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('house_builder ok')
