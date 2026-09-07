import io

# ---- 1. replace plate() with a general planar slab
p = 'core/mesh_kit.gd'
s = io.open(p, encoding='utf-8').read()

start = s.index('## A four-cornered plate of `thickness`, given its corners in order round the')
end = s.index('## Hipped roof: side slabs plus sloped ends, so all four sides fall away.')
new = '''## A flat slab of `thickness` through any planar polygon, given its corners in
## order round the face.
##
## Roof slabs are oriented boxes everywhere else, and a box is a rectangle: it
## cannot be cut back on the diagonal. That is exactly what a hip needs -- the
## slope beside it has a triangle taken out of its top corner, and the hip
## fills that triangle. Built from rectangles instead, the two either leave a
## hole or lie across each other, and both were happening.
##
## The polygon must be planar and convex, which every roof face here is.
func slab_poly(points: PackedVector3Array, thickness: float, surf: int) -> void:
	var n: int = points.size()
	if n < 3:
		return
	var nrm: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if nrm.length_squared() < 1e-12:
		return
	# wind so the outer face is the upper one
	var pts: PackedVector3Array = points
	if nrm.y < 0.0:
		pts = PackedVector3Array()
		for i in range(n - 1, -1, -1):
			pts.append(points[i])
		nrm = -nrm
	var off: Vector3 = nrm.normalized() * (thickness / 2.0)
	var lo: Array = []
	var hi: Array = []
	for p in pts:
		lo.append(p - off)
		hi.append(p + off)
	var st: SurfaceTool = _sts[surf]
	for i2 in range(1, n - 1):
		_tri(st, lo[0], lo[i2], lo[i2 + 1])
		_tri(st, hi[0], hi[i2 + 1], hi[i2])
	for i3 in range(n):
		var j: int = (i3 + 1) % n
		_quad(st, lo[i3], hi[i3], hi[j], lo[j])


'''
s = s[:start] + new + s[end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('mesh_kit ok')

# ---- 2. a jerkinhead built from faces that meet
p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

start = s.index('\t# Where the gable stops. A plain gable runs to its apex; a half hip -- a')
end = s.index('\tvar overhang_x := 0.25 if along_x else 0.35')
new_block = '''	# Where the gable stops. A plain gable runs to its apex; a half hip -- a
	# jerkinhead -- takes the top off, and then the WALL, the TRUSS and the
	# BARGEBOARDS all have to stop on the line the hip starts on.
	var gable_top: float = rise
	if spec.roof_type == &"half_hipped":
		gable_top = rise * HIP_CUT

	if spec.roof_type == &"hipped":
		_kit.hip_roof_at(xf, span + 0.7, along + 0.5, rise, SURF_ROOF)
	elif spec.roof_type == &"half_hipped":
		_half_hipped(xf, span + 0.7, along + 0.5, rise, gable_top)
		_half_hip_gables(xf, span, along, rise, gable_top)
	else:
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL, span, along)

'''
s = s[:start] + new_block + s[end:]

# ---- 3. the emitters
start = s.index('## The two hip faces of a jerkinhead: from the shortened ridge down and out to')
end = s.index('func _build_bargeboards(')
new_block = '''## A jerkinhead: two long slopes with their top corners cut away, and a hip
## filling each cut.
##
## The cut is what makes it work. A hip is a triangle standing on the top of
## the gable and reaching the END OF THE RIDGE, so the slope beside it has to
## give up exactly that triangle -- which a rectangular slab cannot do, and
## which is why the roof used to have either a hole at the end or an extra
## plane lying across it. Both faces are stated as polygons and share an edge,
## so they meet by construction rather than by two sets of numbers agreeing.
func _half_hipped(xf: Transform3D, span: float, along: float, rise: float,
		cut: float) -> void:
	var half: float = span / 2.0
	var far: float = along / 2.0
	# The hip takes the same pitch as the slopes, so its run in plan is the
	# same as the width it has at the wall head.
	var w: float = half * (1.0 - cut / rise)
	var z_ridge: float = far - w
	if w <= 0.05 or z_ridge <= 0.0:
		_kit.ridge_roof(xf, span, along, rise, SURF_ROOF)
		return
	for side in [-1.0, 1.0]:
		_kit.slab_poly(PackedVector3Array([
			xf * Vector3(side * half, 0.0, -far),
			xf * Vector3(side * half, 0.0, far),
			xf * Vector3(side * w, cut, far),
			xf * Vector3(0.0, rise, z_ridge),
			xf * Vector3(0.0, rise, -z_ridge),
			xf * Vector3(side * w, cut, -far),
		]), 0.24, SURF_ROOF)
	for end_v in [-1.0, 1.0]:
		_kit.slab_poly(PackedVector3Array([
			xf * Vector3(-w, cut, end_v * far),
			xf * Vector3(w, cut, end_v * far),
			xf * Vector3(0.0, rise, end_v * z_ridge),
		]), 0.24, SURF_ROOF)
	_kit.oriented_box(Vector3(0.35, 0.25, z_ridge * 2.0),
		xf * Transform3D(Basis(), Vector3(0.0, rise + 0.1, 0.0)), SURF_ROOF)


## The gable under a half hip: a trapezoid, stopping where the hip starts.
func _half_hip_gables(xf: Transform3D, span: float, along: float, rise: float,
		cut: float) -> void:
	var ex: float = span / 2.0
	var apex: float = rise * (ex / ((span + 0.7) / 2.0))
	for end_v in [-1.0, 1.0]:
		var zf: float = end_v * along / 2.0
		_kit.gable_end_at(xf, ex, apex, zf - end_v * 0.3, zf, SURF_WALL,
			minf(cut, apex - 0.05))


'''
s = s[:start] + new_block + s[end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('house_builder ok')
