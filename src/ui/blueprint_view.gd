class_name BlueprintView
extends Control
## Draws a 2D blueprint sheet for a ChurchSpec: floor plan (top) + south
## elevation (bottom), with dimension lines. Blueprint-blue on white.
##
## Every position here comes from ChurchGeometry -- the same module the mesh
## builder uses. This file must not derive massing of its own: when it did, the
## drawing silently drifted from the model it claimed to depict.

var spec: ChurchSpec

func setup(p_spec: ChurchSpec) -> void:
	spec = p_spec
	queue_redraw()

func _draw() -> void:
	if spec == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("f4f7fa"), true)
	var ink := Color("27476e")
	var light := Color(0.15, 0.28, 0.43, 0.35)

	# title block
	draw_string(ThemeDB.fallback_font, Vector2(12, 22),
		"%s  —  %s" % [spec.variant_name, ChurchSpec.STYLES[spec.style]["label"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(ThemeDB.fallback_font, Vector2(12, 40),
		"Nave %.1fm × %.1fm   Eaves %.1fm" % [spec.width, spec.length, spec.height],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, light)

	var mid_y := size.y * 0.52
	_draw_plan(Rect2(Vector2(0, 46), Vector2(size.x, mid_y - 56)), ink, light)
	_draw_elevation(Rect2(Vector2(0, mid_y - 10), Vector2(size.x, size.y - mid_y + 4)), ink, light)

func _draw_plan(r: Rect2, ink: Color, light: Color) -> void:
	if r.size.x < 40 or r.size.y < 30:
		return
	var zext: Vector2 = ChurchGeometry.length_extent(spec)
	var span_x: float = zext.y - zext.x
	var span_z: float = ChurchGeometry.width_extent(spec)
	var scale: float = minf((r.size.x - 40) / span_x, (r.size.y - 34) / span_z)
	if scale <= 0:
		return

	# centre the drawing on the model's true Z midpoint, not on z=0
	var zmid: float = (zext.x + zext.y) / 2.0
	var cx: float = r.position.x + r.size.x / 2.0
	var cy: float = r.position.y + r.size.y / 2.0 + 8

	# model (x,z) -> paper. Model +Z = altar (right of the sheet).
	var to_paper := func(p: Vector2) -> Vector2:
		return Vector2(cx + (p.y - zmid) * scale, cy + p.x * scale)
	# an AABB's plan footprint as a paper-space Rect2
	var plan_rect := func(a: AABB) -> Rect2:
		var tl: Vector2 = to_paper.call(Vector2(a.position.x, a.position.z))
		var br: Vector2 = to_paper.call(Vector2(a.position.x + a.size.x,
			a.position.z + a.size.z))
		return Rect2(tl, br - tl)

	# aisles
	if spec.aisles > 0:
		for side in [-1.0, 1.0]:
			var ar: Rect2 = plan_rect.call(ChurchGeometry.aisle_aabb(spec, side))
			draw_rect(ar, Color(0.15, 0.28, 0.43, 0.06), true)
			draw_rect(ar, light, false, 1.0)

	# transept
	if spec.transept:
		draw_rect(plan_rect.call(ChurchGeometry.transept_aabb(spec)), light, false, 1.2)

	# nave outline
	draw_rect(plan_rect.call(ChurchGeometry.nave_aabb(spec)), ink, false, 2.0)

	# apse: semicircle springing from the east wall, bulging east
	if spec.apse:
		var ac: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.apse_springing_z(spec)))
		draw_arc(ac, spec.apse_radius * scale, -PI / 2.0, PI / 2.0, 16, ink, 2.0)

	# tower
	if spec.tower:
		var tr: Rect2 = plan_rect.call(ChurchGeometry.tower_aabb(spec))
		draw_rect(tr, ink, false, 2.0)
		# diagonals: conventional mark for walls continuing above
		draw_line(tr.position, tr.position + tr.size, light, 1.0)
		draw_line(Vector2(tr.position.x + tr.size.x, tr.position.y),
			Vector2(tr.position.x, tr.position.y + tr.size.y), light, 1.0)

	# door on the west face of whatever stands westmost
	var dz: float = zext.x
	var d0: Vector2 = to_paper.call(Vector2(-0.8, dz))
	var d1: Vector2 = to_paper.call(Vector2(0.8, dz))
	draw_line(d0, d1, ink, 3.0)
	draw_arc(d0, absf(d1.x - d0.x), -PI / 2.0, 0.0, 8, light, 1.0)

	# dimension line: nave length under the plan
	var dim_y: float = cy + span_z / 2.0 * scale + 14
	var nz0: Vector2 = to_paper.call(Vector2(0, -spec.length / 2.0))
	var nz1: Vector2 = to_paper.call(Vector2(0, spec.length / 2.0))
	_dim_line(Vector2(nz0.x, dim_y), Vector2(nz1.x, dim_y),
		"%.1f m" % spec.length, ink, light)
	# nave width at left
	var dim_x: float = cx - span_z / 2.0 * scale - 14
	_dim_line_v(Vector2(dim_x, cy - spec.width / 2.0 * scale),
		Vector2(dim_x, cy + spec.width / 2.0 * scale),
		"%.1f m" % spec.width, ink, light)

func _draw_elevation(r: Rect2, ink: Color, light: Color) -> void:
	if r.size.x < 40 or r.size.y < 30:
		return
	var total_h: float = ChurchGeometry.total_height(spec)
	var zext: Vector2 = ChurchGeometry.length_extent(spec)
	var ground_span: float = zext.y - zext.x
	var scale: float = minf((r.size.x - 50) / ground_span, (r.size.y - 40) / total_h)
	if scale <= 0:
		return
	var zmid: float = (zext.x + zext.y) / 2.0
	var gy: float = r.position.y + r.size.y - 18     # ground line
	var cx: float = r.position.x + r.size.x / 2.0

	draw_line(Vector2(cx - ground_span / 2.0 * scale - 10, gy),
		Vector2(cx + ground_span / 2.0 * scale + 10, gy), ink, 2.0)

	# model -> paper: we look along X, so the sheet's horizontal axis is Z.
	var up := func(hm: float) -> float:
		return gy - hm * scale
	var zx := func(zm: float) -> float:
		return cx + (zm - zmid) * scale

	var h: float = spec.height
	var z_left: float = zx.call(-spec.length / 2.0)
	var z_right: float = zx.call(spec.length / 2.0)

	# tower at the west end
	if spec.tower:
		var ta: AABB = ChurchGeometry.tower_aabb(spec)
		var th: float = spec.tower_height
		var t_l: float = zx.call(ta.position.z)
		var t_r: float = zx.call(ta.position.z + ta.size.z)
		draw_rect(Rect2(Vector2(t_l, up.call(th)), Vector2(t_r - t_l, th * scale)), ink, false, 1.6)
		var rise: float = ChurchGeometry.tower_roof_rise(spec)
		if rise > 0.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(t_l, up.call(th)), Vector2(t_r, up.call(th)),
				Vector2((t_l + t_r) / 2.0, up.call(th + rise))]), light)
			draw_polyline(PackedVector2Array([
				Vector2(t_l, up.call(th)), Vector2((t_l + t_r) / 2.0, up.call(th + rise)),
				Vector2(t_r, up.call(th)), Vector2(t_l, up.call(th))]), ink, 1.6)
		elif spec.tower_roof == &"flat":
			draw_line(Vector2(t_l - 2, up.call(th)), Vector2(t_r + 2, up.call(th)), ink, 2.0)
		# door in the tower base
		var dh: float = ChurchGeometry.door_height(spec)
		var dw: float = 1.4 * scale
		draw_arc(Vector2((t_l + t_r) / 2.0, up.call(dh)), dw / 2.0, PI, TAU, 8, ink, 1.5)
		draw_rect(Rect2(Vector2((t_l + t_r) / 2.0 - dw / 2.0, up.call(dh)),
			Vector2(dw, dh * scale)), ink, false, 1.5)

	# nave body
	draw_rect(Rect2(Vector2(z_left, up.call(h)), Vector2(z_right - z_left, h * scale)),
		ink, false, 2.0)

	# eaves line, and the east gable seen end-on
	var roof_rise: float = spec.width * spec.roof_pitch
	draw_line(Vector2(z_left - 4, up.call(h)), Vector2(z_right + 4, up.call(h)), light, 1.2)
	draw_polyline(PackedVector2Array([
		Vector2(z_left, up.call(h)),
		Vector2((z_left + z_right) / 2.0, up.call(h + roof_rise)),
		Vector2(z_right, up.call(h))]), ink, 1.4)

	# apse: springs from the east wall, projecting one radius east
	if spec.apse:
		var aa: AABB = ChurchGeometry.apse_aabb(spec)
		var a_z0: float = zx.call(aa.position.z)
		var a_z1: float = zx.call(aa.position.z + aa.size.z)
		var a_top: float = up.call(aa.size.y)
		draw_line(Vector2(a_z0, a_top), Vector2(a_z1, a_top), ink, 1.2)
		draw_arc(Vector2(a_z0, a_top), a_z1 - a_z0, -PI / 2.0, 0.0, 12, ink, 1.6)
		draw_line(Vector2(a_z1, a_top), Vector2(a_z1, gy), ink, 1.2)

	# nave side windows -- drawn only when there is no aisle in front of them,
	# matching ChurchBuilder, which skips them when aisles are present.
	if spec.aisles == 0:
		var nw: int = ChurchGeometry.nave_window_count(spec)
		for i in range(nw):
			var wz: float = -spec.length / 2.0 + spec.length / float(nw + 1) * (i + 1)
			var wx: float = zx.call(wz)
			var ww: float = spec.window_w * scale
			var wh: float = spec.window_h * scale
			var wy: float = up.call(h * 0.58) - wh / 2.0
			_draw_window(Vector2(wx, wy), ww, wh, ink)

	_dim_line_v(Vector2(cx + ground_span / 2.0 * scale + 20, up.call(total_h)),
		Vector2(cx + ground_span / 2.0 * scale + 20, gy),
		"%.1f m" % total_h, ink, light)


func _draw_window(tl: Vector2, ww: float, wh: float, ink: Color) -> void:
	match spec.window_style:
		&"pointed":
			draw_polyline(PackedVector2Array([
				Vector2(tl.x - ww / 2.0, tl.y + wh),
				Vector2(tl.x - ww / 2.0, tl.y + wh * 0.3),
				Vector2(tl.x, tl.y),
				Vector2(tl.x + ww / 2.0, tl.y + wh * 0.3),
				Vector2(tl.x + ww / 2.0, tl.y + wh)]), ink, 1.2)
		&"round":
			draw_arc(Vector2(tl.x, tl.y + wh / 2.0), ww / 2.0, PI, TAU, 8, ink, 1.2)
			draw_line(Vector2(tl.x - ww / 2.0, tl.y + wh / 2.0),
				Vector2(tl.x - ww / 2.0, tl.y + wh), ink, 1.2)
			draw_line(Vector2(tl.x + ww / 2.0, tl.y + wh / 2.0),
				Vector2(tl.x + ww / 2.0, tl.y + wh), ink, 1.2)
		_:
			draw_rect(Rect2(Vector2(tl.x - ww / 2.0, tl.y), Vector2(ww, wh)), ink, false, 1.2)


func _dim_line(a: Vector2, b: Vector2, label: String, ink: Color, light: Color) -> void:
	draw_line(a, b, light, 1.0)
	for p in [a, b]:
		draw_line(p + Vector2(0, -4), p + Vector2(0, 4), light, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2((a.x + b.x) / 2.0 - 20, a.y - 4), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)

func _dim_line_v(a: Vector2, b: Vector2, label: String, ink: Color, light: Color) -> void:
	draw_line(a, b, light, 1.0)
	for p in [a, b]:
		draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), light, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, b + Vector2(6, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
