class_name BlueprintView
extends Control
## Draws a 2D blueprint sheet for a ChurchSpec: floor plan (top) + south
## elevation (bottom), with dimension lines. Blueprint-blue on white.

var spec: ChurchSpec
var mesh_info: Dictionary = {}   # total_height etc.

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
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 0),
		"", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	# scale to fit plan (length along X in the drawing)
	var span_x: float = spec.length + (spec.tower_width * 0.45 if spec.tower else 0.0) \
		+ (spec.apse_radius * 0.6 if spec.apse else 0.0)
	var span_z: float = maxf(spec.transept_len if spec.transept else spec.width, spec.width)
	var scale: float = minf((r.size.x - 40) / span_x, (r.size.y - 34) / span_z)
	if scale <= 0:
		return

	var cx: float = r.position.x + r.size.x / 2.0
	var cy: float = r.position.y + r.size.y / 2.0 + 8

	# helper: model (x,z) -> paper (px,py). Model +Z = altar (right).
	var to_paper := func(p: Vector2) -> Vector2:
		return Vector2(cx + p.y * scale, cy + p.x * scale)

	var w2: float = spec.width / 2.0
	var l2: float = spec.length / 2.0

	# aisles
	if spec.aisles > 0:
		for side in [-1.0, 1.0]:
			var aw: float = spec.aisle_width
			var ax: float = side * (w2 + aw / 2.0 - 0.15)
			var tl: Vector2 = to_paper.call(Vector2(ax - aw / 2.0, -l2))
			var br: Vector2 = to_paper.call(Vector2(ax + aw / 2.0, l2))
			draw_rect(Rect2(tl, br - tl), Color(0, 0, 0, 0), false, 1.0)
			draw_rect(Rect2(tl, br - tl), Color(0.15, 0.28, 0.43, 0.06), true)
			draw_rect(Rect2(tl, br - tl), light, false, 1.0)

	# transept
	if spec.transept:
		var tz_w: float = spec.width * 0.55
		var tz_z: float = l2 - tz_w / 2.0 - (spec.apse_radius * 0.6 if spec.apse else 0.0)
		var t_tl: Vector2 = to_paper.call(Vector2(-spec.transept_len / 2.0, tz_z - tz_w / 2.0))
		var t_br: Vector2 = to_paper.call(Vector2(spec.transept_len / 2.0, tz_z + tz_w / 2.0))
		draw_rect(Rect2(t_tl, t_br - t_tl), light, false, 1.2)

	# nave outline
	var n_tl: Vector2 = to_paper.call(Vector2(-w2, -l2))
	var n_br: Vector2 = to_paper.call(Vector2(w2, l2))
	var nave := Rect2(n_tl, n_br - n_tl)
	draw_rect(nave, ink, false, 2.0)

	# apse
	if spec.apse:
		var ac: Vector2 = to_paper.call(Vector2(0, l2 + spec.apse_radius * 0.6))
		var rr: float = spec.apse_radius * scale
		draw_arc(ac, rr, -PI / 2.0, PI / 2.0, 16, ink, 2.0)

	# tower
	if spec.tower:
		var tw: float = spec.tower_width
		var tz_c: float = -l2 - tw * 0.45 + tw / 2.0
		var t_tl: Vector2 = to_paper.call(Vector2(-tw / 2.0, tz_c - tw / 2.0))
		var t_br: Vector2 = to_paper.call(Vector2(tw / 2.0, tz_c + tw / 2.0))
		draw_rect(Rect2(t_tl, t_br - t_tl), ink, false, 2.0)
		# diagonals (conventional for walls above)
		draw_line(t_tl, t_br, light, 1.0)
		draw_line(Vector2(t_br.x, t_tl.y), Vector2(t_tl.x, t_br.y), light, 1.0)

	# door mark on west wall
	var dz: float = (-l2 - spec.tower_width * 0.45 if spec.tower else -l2)
	var d0: Vector2 = to_paper.call(Vector2(-0.8, dz))
	var d1: Vector2 = to_paper.call(Vector2(0.8, dz))
	draw_line(d0, d1, ink, 3.0)
	# door swing arc
	var arc_r: float = absf(d1.x - d0.x)
	draw_arc(d0, arc_r, -PI / 2.0, 0.0, 8, light, 1.0)

	# dimension line: length under the plan
	var dim_y: float = cy + span_z / 2.0 * scale + 14
	var x0: float = cx - spec.length / 2.0 * scale
	var x1: float = cx + spec.length / 2.0 * scale
	_dim_line(Vector2(x0, dim_y), Vector2(x1, dim_y),
		"%.1f m" % spec.length, ink, light)
	# width at left
	var dim_x: float = cx - span_z / 2.0 * scale - 14
	var y0p: float = cy - spec.width / 2.0 * scale
	var y1p: float = cy + spec.width / 2.0 * scale
	_dim_line_v(Vector2(dim_x, y0p), Vector2(dim_x, y1p),
		"%.1f m" % spec.width, ink, light)

func _draw_elevation(r: Rect2, ink: Color, light: Color) -> void:
	if r.size.x < 40 or r.size.y < 30:
		return
	var total_h: float = maxf(spec.height + spec.width * spec.roof_pitch,
		spec.tower_height + spec.tower_width * spec.spire_pitch * 2.2 if spec.tower and spec.spire else spec.height + spec.width * spec.roof_pitch)
	var ground_span: float = maxf(spec.transept_len if spec.transept else spec.width,
		spec.length + (spec.tower_width * 0.9 if spec.tower else 0.0) + (spec.apse_radius if spec.apse else 0.0))
	var scale: float = minf((r.size.x - 50) / ground_span, (r.size.y - 40) / total_h)
	if scale <= 0:
		return
	var gy: float = r.position.y + r.size.y - 18     # ground line y
	var cx: float = r.position.x + r.size.x / 2.0

	# ground line
	draw_line(Vector2(cx - ground_span / 2.0 * scale - 10, gy),
		Vector2(cx + ground_span / 2.0 * scale + 10, gy), ink, 2.0)

	var up := func(hm: float) -> float:
		return gy - hm * scale

	var w2: float = spec.width / 2.0
	var h: float = spec.height
	var l2: float = spec.length / 2.0

	# elevation drawn from the side? Use SOUTH elevation: we look along X,
	# so horizontal axis is Z (nave length). Nave silhouette: rectangle.
	var z_left: float = cx - l2 * scale
	var z_right: float = cx + l2 * scale

	# tower behind west end
	if spec.tower:
		var tw: float = spec.tower_width
		var th: float = spec.tower_height
		var t_l: float = cx - (l2 + tw * 0.9) * scale
		var t_r: float = cx - (l2 - tw * 0.0 + 0.0) * scale + tw * 0.0
		t_l = cx - (l2 + tw * 0.9) * scale
		t_r = t_l + tw * scale
		draw_rect(Rect2(Vector2(t_l, up.call(th)), Vector2(tw * scale, th * scale)), ink, false, 1.6)
		match spec.tower_roof:
			&"spire", &"pyramid":
				var rh: float = tw * (spec.spire_pitch * 2.2 if spec.tower_roof == &"spire" else 0.75)
				draw_colored_polygon(PackedVector2Array([
					Vector2(t_l, up.call(th)), Vector2(t_r, up.call(th)),
					Vector2((t_l + t_r) / 2.0, up.call(th + rh))]), light)
				draw_polyline(PackedVector2Array([
					Vector2(t_l, up.call(th)), Vector2((t_l + t_r) / 2.0, up.call(th + rh)),
					Vector2(t_r, up.call(th)), Vector2(t_l, up.call(th))]), ink, 1.6)
			&"belfry":
				pass
			_:
				draw_line(Vector2(t_l - 2, up.call(th)), Vector2(t_r + 2, up.call(th)), ink, 2.0)
		# door in tower base
		var dw: float = 1.4 * scale
		draw_arc(Vector2((t_l + t_r) / 2.0, up.call(minf(h * 0.32, 3.4))),
			dw / 2.0, PI, TAU, 8, ink, 1.5)
		draw_rect(Rect2(Vector2((t_l + t_r) / 2.0 - dw / 2.0, up.call(minf(h * 0.32, 3.4))),
			Vector2(dw, minf(h * 0.32, 3.4) * scale)), ink, false, 1.5)

	# nave body
	draw_rect(Rect2(Vector2(z_left, up.call(h)), Vector2(z_right - z_left, h * scale)), ink, false, 2.0)

	# gable roof profile over the length (side view shows the slope as shallow line)
	var rise: float = spec.width * spec.roof_pitch
	draw_line(Vector2(z_left, up.call(h)), Vector2(z_right, up.call(h)), ink, 1.0)
	# roof edge visible from side: eave line slightly below roof top
	draw_line(Vector2(z_left - 4, up.call(h + rise * 0.08)), Vector2(z_right + 4, up.call(h + rise * 0.08)), light, 1.2)

	# east gable triangle (visible end)
	var apex := Vector2(z_right, up.call(h + rise))
	draw_polyline(PackedVector2Array([
		Vector2(z_right, up.call(h)), apex, Vector2(z_right, up.call(h))]), ink, 1.5)

	# apse bump at east end
	if spec.apse:
		var ar: float = spec.apse_radius
		var acen := Vector2(cx + (l2 + ar * 0.6) * scale, up.call(h * 0.85 / 2.0))
		draw_arc(acen, ar * scale, -PI / 2.0, PI / 2.0, 12, ink, 1.6)
		draw_line(acen + Vector2(0, -ar * scale), Vector2(z_right, acen.y - ar * scale), ink, 1.2)
		draw_line(acen + Vector2(0, ar * scale), Vector2(z_right, acen.y + ar * scale), ink, 1.2)

	# windows along the side elevation
	var nw: int = int(spec.length / 3.2)
	for i in range(nw):
		var wz: float = -l2 + spec.length / float(nw + 1) * (i + 1)
		var wx: float = cx + wz * scale
		var ww: float = spec.window_w * scale
		var wh: float = spec.window_h * scale
		var wy: float = up.call(h * 0.58) - wh / 2.0
		if spec.window_style == &"pointed":
			var pts := PackedVector2Array([
				Vector2(wx - ww / 2.0, wy + wh),
				Vector2(wx - ww / 2.0, wy + wh * 0.3),
				Vector2(wx, wy),
				Vector2(wx + ww / 2.0, wy + wh * 0.3),
				Vector2(wx + ww / 2.0, wy + wh)])
			draw_polyline(pts, ink, 1.2)
		elif spec.window_style == &"round":
			draw_arc(Vector2(wx, wy + wh / 2.0), ww / 2.0, PI, TAU, 8, ink, 1.2)
			draw_line(Vector2(wx - ww / 2.0, wy + wh / 2.0), Vector2(wx - ww / 2.0, wy + wh), ink, 1.2)
			draw_line(Vector2(wx + ww / 2.0, wy + wh / 2.0), Vector2(wx + ww / 2.0, wy + wh), ink, 1.2)
		else:
			draw_rect(Rect2(Vector2(wx - ww / 2.0, wy), Vector2(ww, wh)), ink, false, 1.2)

	# height dimension at right
	_dim_line_v(Vector2(cx + ground_span / 2.0 * scale + 20, up.call(total_h)),
		Vector2(cx + ground_span / 2.0 * scale + 20, gy),
		"%.1f m" % total_h, ink, light)

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
