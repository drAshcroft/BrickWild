import io

p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()
assert '\nfunc _build_roof(' not in s, 'already present'

anchor = '''## A jerkinhead: two long slopes with their top corners cut away, and a hip
## filling each cut.'''
assert anchor in s

body = '''func _build_roof() -> void:
	tag("roof")
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var rise: float = HouseGeometry.roof_rise(spec)
	var along_x: bool = r.size.x > r.size.y
	var yaw: float = PI / 2.0 if along_x else 0.0
	var span: float = r.size.y if along_x else r.size.x
	var along: float = r.size.x if along_x else r.size.y
	var wall_top := spec.height * _storeys()
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, wall_top, 0.0))

	# Where the gable stops. A plain gable runs to its apex; a half hip -- a
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
		_kit.ridge_roof(xf, span + 0.7, along + 0.5, rise, SURF_ROOF, SURF_WALL,
			span, along)

	var overhang_x := 0.25 if along_x else 0.35
	var overhang_z := 0.35 if along_x else 0.25
	_log_mass("roof" if _storeys() == 1 else "roof_%d" % (_storeys() - 1),
		AABB(Vector3(r.position.x - overhang_x, wall_top, r.position.y - overhang_z),
			Vector3(r.size.x + overhang_x * 2.0, rise + 0.25,
				r.size.y + overhang_z * 2.0)))
	total_height = maxf(total_height, wall_top + rise)

	if spec.timber_frame and spec.roof_type != &"hipped":
		_gable_frame(xf, span, along, rise, gable_top)
	if spec.roof_type != &"hipped":
		_build_bargeboards(xf, span, along, rise, gable_top)
	_build_eaves_tails(xf, span, along, rise)
	if spec.dormers:
		_build_dormers(xf, span, along, rise)


'''
s = s.replace(anchor, body + anchor)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('restored')
