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

	# aisles: one ring per spec.aisles, each lapping the one inside it
	if spec.aisles > 0:
		for side in [-1.0, 1.0]:
			for ring in range(spec.aisles):
				var ar: Rect2 = plan_rect.call(ChurchGeometry.aisle_aabb(spec, side, ring))
				draw_rect(ar, Color(0.15, 0.28, 0.43, 0.06), true)
				draw_rect(ar, light, false, 1.0)

	# flying buttresses: piers clear of the aisle wall, with a flyer line to the nave
	if spec.flying_buttresses:
		var pier_w: float = ChurchGeometry.FLYER_PIER_W * scale
		for side in [-1.0, 1.0]:
			var pier_x: float = ChurchGeometry.flyer_pier_x(spec, side)
			for i in range(maxi(spec.buttress_count_per_side, 1)):
				var pier_z: float = ChurchGeometry.flyer_z(spec, i)
				var pc: Vector2 = to_paper.call(Vector2(pier_x, pier_z))
				draw_rect(Rect2(pc - Vector2(pier_w, pier_w) / 2.0,
					Vector2(pier_w, pier_w)), ink, false, 1.2)
				var wall_pt: Vector2 = to_paper.call(Vector2(side * spec.width / 2.0, pier_z))
				draw_line(pc, wall_pt, light, 1.0)

	# transept
	if spec.transept:
		draw_rect(plan_rect.call(ChurchGeometry.transept_aabb(spec)), light, false, 1.2)

	# nave outline
	draw_rect(plan_rect.call(ChurchGeometry.nave_aabb(spec)), ink, false, 2.0)

	# apse: semicircle springing from the east wall, bulging east
	if spec.apse:
		var ac: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.apse_springing_z(spec)))
		draw_arc(ac, spec.apse_radius * scale, -PI / 2.0, PI / 2.0, 16, ink, 2.0)

	# ambulatory: aisle ring carried around the apse
	if spec.ambulatory:
		var amc: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.apse_springing_z(spec)))
		draw_arc(amc, ChurchGeometry.ambulatory_radius(spec) * scale,
			-PI / 2.0, PI / 2.0, 20, light, 1.2)

	# radiating chapels: small alcoves off the ambulatory (or the apse itself)
	for i in range(spec.radiating_chapels):
		var cc3: Vector3 = ChurchGeometry.chapel_center(spec, i)
		var cc: Vector2 = to_paper.call(Vector2(cc3.x, cc3.z))
		draw_arc(cc, spec.chapel_radius * scale, 0.0, TAU, 12, light, 1.0)

	# crossing tower: bold outline, same wall-above mark as the west tower
	if spec.crossing_tower:
		var ctr: Rect2 = plan_rect.call(ChurchGeometry.crossing_tower_aabb(spec))
		draw_rect(ctr, ink, false, 2.0)
		draw_line(ctr.position, ctr.position + ctr.size, light, 1.0)
		draw_line(Vector2(ctr.position.x + ctr.size.x, ctr.position.y),
			Vector2(ctr.position.x, ctr.position.y + ctr.size.y), light, 1.0)

	# dome: circle over the crossing, or an octagon for an octagonal drum
	if spec.dome:
		var dc: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.crossing_center_z(spec)))
		var dr: float = spec.dome_radius * scale
		if spec.dome_shape == &"octagonal":
			var pts := PackedVector2Array()
			for k in range(9):
				var th: float = TAU * float(k) / 8.0
				pts.append(dc + Vector2(cos(th), sin(th)) * dr)
			draw_polyline(pts, ink, 1.6)
		else:
			draw_arc(dc, dr, 0.0, TAU, 24, ink, 1.6)

	# west tower(s): one pair for twin facades, one for a single tower
	if spec.tower:
		for side in ChurchGeometry.west_tower_sides(spec):
			var tr: Rect2 = plan_rect.call(ChurchGeometry.tower_aabb(spec, side))
			draw_rect(tr, ink, false, 2.0)
			# diagonals: conventional mark for walls continuing above
			draw_line(tr.position, tr.position + tr.size, light, 1.0)
			draw_line(Vector2(tr.position.x + tr.size.x, tr.position.y),
				Vector2(tr.position.x, tr.position.y + tr.size.y), light, 1.0)

	# narthex: vestibule across the west front, drawn light like the transept
	if spec.narthex:
		draw_rect(plan_rect.call(ChurchGeometry.narthex_aabb(spec)), light, false, 1.0)

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

	# tower at the west end -- twin towers overlap in a south elevation, so
	# only the westmost of them is drawn here (they share height and roof).
	var tower_sides: Array[float] = ChurchGeometry.west_tower_sides(spec)
	if spec.tower and tower_sides.size() > 0:
		var ta: AABB = ChurchGeometry.tower_aabb(spec, tower_sides[0])
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

	# crossing tower: the horizontal axis here is Z, so its width is the
	# crossing bay's depth, not the nave width.
	if spec.crossing_tower:
		var cbd: float = ChurchGeometry.crossing_bay_depth(spec)
		var ccz: float = ChurchGeometry.crossing_center_z(spec)
		var c_l: float = zx.call(ccz - cbd / 2.0)
		var c_r: float = zx.call(ccz + cbd / 2.0)
		draw_rect(Rect2(Vector2(c_l, up.call(spec.crossing_tower_height)),
			Vector2(c_r - c_l, spec.crossing_tower_height * scale)), ink, false, 1.6)

	# dome: drum + shell, with a lantern box if the style carries one
	if spec.dome:
		var dcz: float = zx.call(ChurchGeometry.crossing_center_z(spec))
		var dr: float = spec.dome_radius * scale
		var drum_base: float = ChurchGeometry.dome_base_height(spec)
		var drum_top: float = drum_base + spec.dome_drum_height
		draw_rect(Rect2(Vector2(dcz - dr, up.call(drum_top)),
			Vector2(dr * 2.0, spec.dome_drum_height * scale)), ink, false, 1.6)
		var shell_rise: float = ChurchGeometry.dome_shell_rise(spec)
		var shell_top: float = drum_top + shell_rise
		if spec.dome_shape == &"onion":
			# bulged ogee: swells past the drum width before pinching to the apex
			draw_polyline(PackedVector2Array([
				Vector2(dcz - dr, up.call(drum_top)),
				Vector2(dcz - dr * 1.18, up.call(drum_top + shell_rise * 0.4)),
				Vector2(dcz - dr * 0.3, up.call(drum_top + shell_rise * 0.85)),
				Vector2(dcz, up.call(shell_top)),
				Vector2(dcz + dr * 0.3, up.call(drum_top + shell_rise * 0.85)),
				Vector2(dcz + dr * 1.18, up.call(drum_top + shell_rise * 0.4)),
				Vector2(dcz + dr, up.call(drum_top))]), ink, 1.6)
		else:
			draw_arc(Vector2(dcz, up.call(drum_top)), dr, PI, TAU, 16, ink, 1.6)
		if spec.dome_lantern:
			var lh: float = spec.dome_radius * ChurchGeometry.LANTERN_RATIO * scale
			var lw: float = dr * 0.35
			draw_rect(Rect2(Vector2(dcz - lw / 2.0, up.call(shell_top) - lh),
				Vector2(lw, lh)), ink, false, 1.4)

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
