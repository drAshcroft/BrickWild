class_name BlueprintView
extends Control
## Draws a 2D blueprint sheet for a ChurchSpec: floor plan (top) + south
## elevation (bottom), with dimension lines. Blueprint-blue on white.
##
## Every position here comes from ChurchGeometry -- the same module the mesh
## builder uses. This file must not derive massing of its own: when it did, the
## drawing silently drifted from the model it claimed to depict.

var spec: ChurchSpec
var village: VillagePlan
## The house sheet, when the Studio is showing a house, a shop or a hotel.
var house: HouseSheet
## Shown instead of a sheet when there is nothing to draw -- a castle, for now.
var note: String = ""


## Geometry inventory for the +X elevation. This is also consumed by the
## focused structural fixture, so a claimed feature cannot vanish from both
## drawing and test expectations unnoticed.
static func south_elevation_inventory(p_spec: ChurchSpec) -> Dictionary:
	var aisles: Array[Dictionary] = []
	for ring in range(p_spec.aisles):
		aisles.append({"bounds": ChurchGeometry.aisle_aabb(p_spec, 1.0, ring),
			"roof_high": ChurchGeometry.aisle_roof_high(p_spec, ring)})
	var buttresses: Array[float] = []
	if p_spec.buttresses:
		for i in range(p_spec.buttress_count_per_side):
			buttresses.append(ChurchGeometry.nave_buttress_z(p_spec, i))
	var flyers: Array[Dictionary] = []
	if p_spec.flying_buttresses:
		for i in range(ChurchGeometry.flyer_count(p_spec)):
			flyers.append({"z": ChurchGeometry.flyer_z(p_spec, i), "tiers": p_spec.flyer_tiers})
	var chapels: Array[AABB] = []
	for i in range(p_spec.radiating_chapels):
		chapels.append(ChurchGeometry.chapel_aabb(p_spec, i))
	# hero landmark composition (spec.hero): the same functions the mesh reads
	var tribunes: Array[AABB] = []
	for i in range(ChurchGeometry.tribune_count(p_spec)):
		tribunes.append(ChurchGeometry.tribune_aabb(p_spec, i))
	var piers: Array[AABB] = []
	if ChurchGeometry.hagia_bearing(p_spec):
		var psize: float = ChurchGeometry.hagia_pier_size(p_spec)
		var base: float = ChurchGeometry.dome_base_height(p_spec)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var pc: Vector3 = ChurchGeometry.hagia_pier_center(p_spec, sx, sz)
				piers.append(AABB(Vector3(pc.x - psize / 2.0, base, pc.z - psize / 2.0),
					Vector3(psize, ChurchGeometry.hagia_pier_top(p_spec) - base, psize)))
	return {
		"aisles": aisles,
		"clerestory": ChurchGeometry.clerestory_windows(p_spec),
		"transept": ChurchGeometry.transept_aabb(p_spec) if p_spec.transept else AABB(),
		"buttresses": buttresses,
		"flyers": flyers,
		"chapels": chapels,
		"dome": p_spec.dome,
		"dome_shape": p_spec.dome_shape,
		"half_domes": p_spec.dome and p_spec.half_domes,
		"exedrae": p_spec.dome and p_spec.half_domes and p_spec.exedrae,
		"crossing_octagon": ChurchGeometry.octagon_aabb(p_spec) \
			if ChurchGeometry.octagon_crossing(p_spec) else AABB(),
		"tribunes": tribunes,
		"podium": ChurchGeometry.podium_aabb(p_spec) \
			if ChurchGeometry.podium_height(p_spec) > 0.0 else AABB(),
		"bearing": ChurchGeometry.pendentive_aabb(p_spec) \
			if ChurchGeometry.hagia_bearing(p_spec) else AABB(),
		"piers": piers,
		"tent": ChurchGeometry.basil_core(p_spec),
	}

func setup(p_spec: ChurchSpec) -> void:
	spec = p_spec
	village = null
	house = null
	note = ""
	queue_redraw()


## Draw a house, shop or hotel: a plan per storey, the front elevation and the
## room schedule, all from the HousePlan (see HouseSheet).
func setup_house(plan: HousePlan) -> void:
	spec = null
	village = null
	house = HouseSheet.new(plan)
	note = ""
	queue_redraw()

## Put the sheet away and say why. Leaving the previous church's plan on screen
## while the viewport showed a castle was worse than drawing nothing.
func show_note(text: String) -> void:
	spec = null
	village = null
	house = null
	note = text
	queue_redraw()

func _draw() -> void:
	if house != null:
		house.draw(self)
		return
	if village != null:
		_draw_village()
		return
	if spec == null:
		if note != "":
			draw_rect(Rect2(Vector2.ZERO, size), Color("f4f7fa"), true)
			draw_multiline_string(ThemeDB.fallback_font, Vector2(14, 28), note,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 13,
				-1, Color(0.15, 0.28, 0.43, 0.75))
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


func setup_village(plan: VillagePlan) -> void:
	spec = null
	village = plan
	house = null
	note = ""
	queue_redraw()


## Every layer comes from the retained VillagePlan, in its site frame.
## No road, lot, entrance or shoreline is inferred from the preview mesh.
func _draw_village() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f3f0e6"), true)
	if size.x < 100 or size.y < 100 or village.site.size.x <= 0:
		return
	var ink := Color("304958")
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(14, 22), "%s / %s" % [village.spec.variant_name, String(village.spec.form).capitalize()], HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 15, ink)
	draw_string(font, Vector2(14, 40), "%d people  |  %d buildings  |  seed %d" % [village.spec.population, village.buildings.size(), village.spec.seed], HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 11, Color("667773"))
	var paper := Rect2(22, 54, size.x - 44, size.y - 86)
	var scale := minf(paper.size.x / village.site.size.x, paper.size.y / village.site.size.y)
	var centre := paper.get_center()
	var transform := func(p: Vector2) -> Vector2:
		return centre + (p - village.site.get_center()) * scale
	var polygon := func(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points: result.append(transform.call(point))
		return result
	for field in village.fields:
		var points: PackedVector2Array = polygon.call(field["poly"])
		if points.size() >= 3: draw_colored_polygon(points, Color("e4dcb9"))
	for common in village.commons:
		var points: PackedVector2Array = polygon.call(common["poly"])
		if points.size() >= 3: draw_colored_polygon(points, Color("b4c9a1"))
	for water in village.water:
		var points: PackedVector2Array = polygon.call(water["poly"])
		if points.size() >= 3: draw_colored_polygon(points, Color("98c7d2"))
	for lot in village.lots:
		var points: PackedVector2Array = polygon.call(lot["poly"])
		if points.size() >= 3:
			draw_colored_polygon(points, Color(0.75, 0.67, 0.5, 0.14))
			points.append(points[0])
			draw_polyline(points, Color("a89a7e"), 0.8, true)
		var front: PackedVector2Array = polygon.call(lot["front"])
		if front.size() >= 2: draw_polyline(front, Color("d49843"), 2.0, true)
	for road in village.roads:
		var points: PackedVector2Array = polygon.call(road["points"])
		if points.size() >= 2:
			draw_polyline(points, Color("fdf9ed"), maxf(1.5, road["width"] * scale), true)
	for building in village.buildings:
		var points: PackedVector2Array = polygon.call(Placement.world_rect(building["placement"], building["transform"], true))
		if points.size() >= 3:
			draw_colored_polygon(points, Color("936651") if building["kind"] != &"church" else Color("6e7685"))
		var door: Vector3 = building["door"]
		draw_circle(transform.call(Vector2(door.x, door.z)), 1.7, Color("f7e4a7"))
	var boundary := VillageEnclosurePlan.build(village)
	var edge: PackedVector2Array = village.enclosure if not village.enclosure.is_empty() else boundary["edge"]
	if village.spec.enclosure != &"none" and edge.size() >= 3:
		var points: PackedVector2Array = polygon.call(edge)
		points.append(points[0])
		draw_polyline(points, Color("526749"), 2.2, true)
	var gates: Array = village.gate_crossings if not village.gate_crossings.is_empty() else boundary["gates"]
	for gate in gates if village.spec.enclosure != &"none" else []:
		draw_circle(transform.call(gate["pos"]), 3.0, Color("f3f0e6"))
	draw_string(font, Vector2(size.x - 32, 24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	draw_line(Vector2(size.x - 27, 32), Vector2(size.x - 27, 48), ink, 1.3)
	draw_string(font, Vector2(14, size.y - 12), "Roads / cream    Lots / ochre    Fronts / gold    Common / green    Water / blue    Edge / dark green", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 10, ink)

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

	# podium: the raised platform under St Basil's whole cluster
	if ChurchGeometry.podium_height(spec) > 0.0:
		draw_rect(plan_rect.call(ChurchGeometry.podium_aabb(spec)), light, false, 1.0)

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

	# the octagonal crossing and its three tribunes (Florence)
	if ChurchGeometry.octagon_crossing(spec):
		var oc: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.crossing_center_z(spec)))
		var opts := PackedVector2Array()
		for k in range(9):
			var oth: float = PI / 8.0 + TAU * float(k) / 8.0
			opts.append(oc + Vector2(cos(oth), sin(oth))
				* ChurchGeometry.octagon_circumradius(spec) * scale)
		draw_polyline(opts, ink, 2.0)
	for i in range(ChurchGeometry.tribune_count(spec)):
		var tc3: Vector3 = ChurchGeometry.tribune_center(spec, i)
		var tc: Vector2 = to_paper.call(Vector2(tc3.x, tc3.z))
		# plan: paper x = model Z, paper y = model X, so a revolve angle th
		# (x = cos th, z = sin th) lands at (sin th, cos th) on the sheet
		var tpts := PackedVector2Array()
		var tstart: float = ChurchGeometry.tribune_arc_start(spec, i)
		for k in range(13):
			var tth: float = tstart + PI * float(k) / 12.0
			tpts.append(tc + Vector2(sin(tth), cos(tth)) * ChurchGeometry.tribune_radius(spec) * scale)
		draw_polyline(tpts, ink, 1.8)

	# Hagia Sophia's square bearing, with a pier at each corner
	if ChurchGeometry.hagia_bearing(spec):
		draw_rect(plan_rect.call(ChurchGeometry.pendentive_aabb(spec)), ink, false, 1.4)
		for pier in south_elevation_inventory(spec)["piers"]:
			draw_rect(plan_rect.call(pier), ink, false, 1.6)

	# dome: circle over the crossing, or an octagon for an octagonal drum
	if spec.dome:
		var dc: Vector2 = to_paper.call(Vector2(0, ChurchGeometry.crossing_center_z(spec)))
		var dr: float = spec.dome_radius * scale
		if spec.dome_shape == &"octagonal":
			var pts := PackedVector2Array()
			for k in range(9):
				var th: float = PI / 8.0 + TAU * float(k) / 8.0
				pts.append(dc + Vector2(cos(th), sin(th))
					* dr * ChurchGeometry.OCTAGONAL_RADIUS_FACTOR)
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
	# Reserve margin for the right-hand dimension and its text. Long churches
	# used to consume the whole width and clip that label at the page edge.
	var scale: float = minf((r.size.x - 116) / ground_span, (r.size.y - 68) / total_h)
	if scale <= 0:
		return
	var zmid: float = (zext.x + zext.y) / 2.0
	var gy: float = r.position.y + r.size.y - 24     # ground line
	var cx: float = r.position.x + (r.size.x - 58) / 2.0
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 16, r.position.y + 17),
		"SOUTH ELEVATION  /  +X SIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 16, r.position.y + 32),
		"Depth is projected; chapel masses share their true Z positions.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, light)

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

	# Lower aisle walls and their shed-roof profiles. The south ring is visible
	# in this projection; nested rings retain the builder's exact tier heights.
	var elevation: Dictionary = south_elevation_inventory(spec)
	var aisle_parts: Array[Dictionary] = elevation["aisles"]
	for ring in range(aisle_parts.size()):
		var aisle: AABB = aisle_parts[ring]["bounds"]
		var a0: float = zx.call(aisle.position.z)
		var a1: float = zx.call(aisle.position.z + aisle.size.z)
		var wall_top: float = aisle.size.y
		draw_rect(Rect2(Vector2(a0, up.call(wall_top)), Vector2(a1 - a0, wall_top * scale)),
			Color(0.15, 0.28, 0.43, 0.08), true)
		draw_rect(Rect2(Vector2(a0, up.call(wall_top)), Vector2(a1 - a0, wall_top * scale)),
			light, false, 0.9)
		var roof_high: float = aisle_parts[ring]["roof_high"]
		draw_polyline(PackedVector2Array([
			Vector2(a0, up.call(roof_high)), Vector2(a1, up.call(roof_high)),
			Vector2(a1, up.call(wall_top)), Vector2(a0, up.call(wall_top)),
			Vector2(a0, up.call(roof_high))]), ink, 1.3)

	# Buttress positions are shared with ChurchBuilder. From the south they read
	# as piers; flyer glyphs below mark the number and tier of the cross-braces.
	if spec.buttresses:
		var buttress_z: Array[float] = elevation["buttresses"]
		for bz in buttress_z:
			var bw: float = maxf(0.32, spec.buttress_depth * 0.55) * scale
			var top: float = h * 0.72
			draw_rect(Rect2(Vector2(zx.call(bz) - bw / 2.0, up.call(top)),
				Vector2(bw, top * scale)), ink, false, 1.0)

	# The transept ridge runs across X and appears end-on in a south elevation.
	# Keep its true Z bay, and distinguish its roof from the nave gable.
	var transept_bounds: AABB = elevation["transept"]
	if transept_bounds != AABB():
		var ta: AABB = transept_bounds
		var tz0: float = zx.call(ta.position.z)
		var tz1: float = zx.call(ta.position.z + ta.size.z)
		var tc: float = zx.call(ChurchGeometry.transept_center_z(spec))
		var trise: float = spec.width * spec.roof_pitch * 0.9
		draw_rect(Rect2(Vector2(tz0, up.call(h)), Vector2(tz1 - tz0, h * scale)), light, false, 1.0)
		draw_polyline(PackedVector2Array([
			Vector2(tz0, up.call(h)), Vector2(tc, up.call(h + trise)),
			Vector2(tz1, up.call(h))]), ink, 1.4)

	# apse: springs from the east wall, projecting one radius east
	if spec.apse:
		var aa: AABB = ChurchGeometry.apse_aabb(spec)
		var a_z0: float = zx.call(aa.position.z)
		var a_z1: float = zx.call(aa.position.z + aa.size.z)
		var a_top: float = up.call(aa.size.y)
		draw_line(Vector2(a_z0, a_top), Vector2(a_z1, a_top), ink, 1.2)
		draw_arc(Vector2(a_z0, a_top), a_z1 - a_z0, -PI / 2.0, 0.0, 12, ink, 1.6)
		draw_line(Vector2(a_z1, a_top), Vector2(a_z1, gy), ink, 1.2)
	if spec.ambulatory:
		var am: AABB = ChurchGeometry.ambulatory_aabb(spec)
		var am0: float = zx.call(am.position.z)
		var am1: float = zx.call(am.position.z + am.size.z)
		draw_rect(Rect2(Vector2(am0, up.call(am.size.y)),
			Vector2(am1 - am0, am.size.y * scale)), light, false, 0.9)
	# The south projection folds the chapel fan in depth. Their actual Z bounds
	# remain distinct, which is why Chartres reads as a row rather than a blob.
	var chapel_parts: Array[AABB] = elevation["chapels"]
	for chapel in chapel_parts:
		var ch0: float = zx.call(chapel.position.z)
		var ch1: float = zx.call(chapel.position.z + chapel.size.z)
		var ch_top: float = chapel.size.y
		if ch1 - ch0 > 0.03:
			draw_rect(Rect2(Vector2(ch0, up.call(ch_top)),
				Vector2(ch1 - ch0, ch_top * scale)), Color(0.15, 0.28, 0.43, 0.06), true)
			draw_rect(Rect2(Vector2(ch0, up.call(ch_top)),
				Vector2(ch1 - ch0, ch_top * scale)), ink, false, 0.9)

	# podium, octagonal crossing, tribunes, bearing and piers
	var podium: AABB = elevation["podium"]
	if podium != AABB():
		draw_rect(Rect2(Vector2(zx.call(podium.position.z), up.call(podium.size.y)),
			Vector2(podium.size.z * scale, podium.size.y * scale)), ink, false, 1.2)
	var octagon: AABB = elevation["crossing_octagon"]
	if octagon != AABB():
		draw_rect(Rect2(Vector2(zx.call(octagon.position.z), up.call(octagon.size.y)),
			Vector2(octagon.size.z * scale, octagon.size.y * scale)), ink, false, 1.8)
	for tribune in elevation["tribunes"]:
		var tb: AABB = tribune
		draw_rect(Rect2(Vector2(zx.call(tb.position.z), up.call(tb.size.y)),
			Vector2(tb.size.z * scale, tb.size.y * scale)), ink, false, 1.2)
	var bearing: AABB = elevation["bearing"]
	if bearing != AABB():
		draw_rect(Rect2(Vector2(zx.call(bearing.position.z), up.call(bearing.end.y)),
			Vector2(bearing.size.z * scale, bearing.size.y * scale)), ink, false, 1.8)
		for pier in elevation["piers"]:
			var pb: AABB = pier
			draw_rect(Rect2(Vector2(zx.call(pb.position.z), up.call(pb.end.y)),
				Vector2(pb.size.z * scale, pb.size.y * scale)), light, false, 1.2)

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
	if elevation["dome"]:
		var dcz: float = zx.call(ChurchGeometry.crossing_center_z(spec))
		var dr: float = spec.dome_radius * scale
		var drum_base: float = ChurchGeometry.dome_base_height(spec) \
			+ ChurchGeometry.pendentive_height(spec)
		var drum_top: float = drum_base + spec.dome_drum_height
		draw_rect(Rect2(Vector2(dcz - dr, up.call(drum_top)),
			Vector2(dr * 2.0, spec.dome_drum_height * scale)), ink, false, 1.6)
		var shell_rise: float = ChurchGeometry.dome_shell_rise(spec)
		var shell_top: float = drum_top + shell_rise
		if elevation["tent"]:
			# the tent narrows to a little drum and onion at its tip
			draw_polyline(PackedVector2Array([
				Vector2(dcz - dr, up.call(drum_top)),
				Vector2(dcz - dr * 0.8, up.call(drum_top + shell_rise * 0.30)),
				Vector2(dcz - dr * 0.36, up.call(drum_top + shell_rise * 0.78)),
				Vector2(dcz - dr * 0.14, up.call(shell_top)),
				Vector2(dcz + dr * 0.14, up.call(shell_top)),
				Vector2(dcz + dr * 0.36, up.call(drum_top + shell_rise * 0.78)),
				Vector2(dcz + dr * 0.8, up.call(drum_top + shell_rise * 0.30)),
				Vector2(dcz + dr, up.call(drum_top))]), ink, 1.6)
			var cap: float = ChurchGeometry.tent_cap_height(spec)
			draw_rect(Rect2(Vector2(dcz - dr * 0.26, up.call(shell_top + cap * 0.76)),
				Vector2(dr * 0.52, cap * 0.76 * scale)), ink, false, 1.4)
		elif spec.dome_shape == &"onion":
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
			var lh: float = ChurchGeometry.lantern_height(spec) * scale
			var lw: float = ChurchGeometry.lantern_cap_width(spec) * scale
			draw_rect(Rect2(Vector2(dcz - lw / 2.0, up.call(shell_top) - lh),
				Vector2(lw, lh)), ink, false, 1.4)
	if elevation["half_domes"]:
		var hr: float = ChurchGeometry.half_dome_radius(spec)
		var base: float = ChurchGeometry.dome_base_height(spec)
		for direction in [-1.0, 1.0]:
			_draw_projected_half_dome(ChurchGeometry.half_dome_face_z(spec, direction), base,
				hr, ChurchGeometry.half_dome_rise(spec), direction, scale, zx, up, ink)
			if elevation["exedrae"]:
				var er: float = hr * 0.4
				var ez: float = ChurchGeometry.crossing_center_z(spec) + direction * hr * 0.62
				_draw_projected_half_dome(ez, base * 0.55 + base * 0.3,
					er, base * 0.24, direction, scale, zx, up, light)

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
	var clerestory_parts: Array[Dictionary] = elevation["clerestory"]
	if not clerestory_parts.is_empty():
		for opening in clerestory_parts:
			var pos: Vector3 = opening["pos"]
			var ww: float = float(opening["width"]) * scale
			var wh: float = float(opening["height"]) * scale
			_draw_window(Vector2(zx.call(pos.z), up.call(pos.y + float(opening["height"]) / 2.0)),
				ww, wh, ink)
	# The braces run across X and project to each bay from this viewpoint. These
	# small arch glyphs preserve the real tier/rhythm without suggesting they
	# occupy additional nave length.
	var flyer_parts: Array[Dictionary] = elevation["flyers"]
	if not flyer_parts.is_empty():
		for flyer in flyer_parts:
			var fz: float = zx.call(flyer["z"])
			for tier in range(flyer["tiers"]):
				var drop: float = float(tier) * ChurchGeometry.flyer_tier_drop(spec)
				var low: float = ChurchGeometry.flyer_pier_height(spec) - drop
				var high: float = ChurchGeometry.flyer_spring_height(spec) - drop
				var glyph: float = maxf(1.1, ChurchGeometry.flyer_pier_width(spec) * 0.38) * scale
				draw_polyline(PackedVector2Array([
					Vector2(fz - glyph, up.call(low)), Vector2(fz - glyph * 0.45, up.call((low + high) * 0.5)),
					Vector2(fz, up.call(maxf(low, high) + glyph * 0.2)),
					Vector2(fz + glyph * 0.45, up.call((low + high) * 0.5)),
					Vector2(fz + glyph, up.call(low))]), ink, 1.2)

	_dim_line_v(Vector2(cx + ground_span / 2.0 * scale + 24, up.call(total_h)),
		Vector2(cx + ground_span / 2.0 * scale + 24, gy),
		"%.1f m" % total_h, ink, light)


func _draw_projected_half_dome(center_z: float, base_y: float, radius: float,
		rise: float, direction: float, scale: float, zx: Callable,
		up: Callable, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		var z: float = center_z + direction * radius * (1.0 - t)
		var y: float = base_y + rise * sin(t * PI * 0.5)
		points.append(Vector2(zx.call(z), up.call(y)))
	points.append(Vector2(zx.call(center_z), up.call(base_y)))
	draw_polyline(points, color, maxf(0.8, scale * 0.16))


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
