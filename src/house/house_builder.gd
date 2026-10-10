class_name HouseBuilder
extends MassBuilder
## HousePlan -> ArrayMesh: the shell only. The furniture is not mesh at all --
## it is a list of prop instances that HouseAssembler adds to the scene, so the
## same plan can be measured headlessly by the QA suites and dressed with real
## art in the viewer.
##
## Walls are emitted run by run, with the doors and windows cut out of them as
## actual holes: piers either side, a panel over the head, a panel under the
## sill. That matters beyond looks -- the navigation check walks the rasterized
## shell, so a "door" painted on a solid wall would be a door nobody can use,
## and it would say so.
##
## Surfaces: 0 = wall, 1 = trim (frames, sills, posts), 2 = roof, 3 = floor.

const SURF_WALL := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_FLOOR := 3
const HAN_DOME_SEGMENTS := 16
const HAN_DOME_BANDS := 5
const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")
var plan: HousePlan
var spec: HouseSpec
var emitted_mesh: ArrayMesh
var roof_enabled := false
## Actual emitted architectural faces, including cut host pieces and dormer joins.
## Each row is also a row of `component_log`; see MassBuilder.
var roof_components: Array[Dictionary] = []
## Evidence emitted for each authored hole. Unlike a structural mass this is
## intentionally not a solid AABB: CourtCheck and HammamCheck use it to
## distinguish an empty column from a roof box that merely carries a label.
var roof_opening_log: Array[Dictionary] = []
## Emission counter that names each opening's surround, so the trim round the
## third window is identifiably the third window's on every rebuild.
var _opening_seq := 0


## `with_roof` is the one thing a caller may switch off: a furnished interior
## cannot be photographed through its own thatch. Nothing else changes, so the
## walls and the openings the checks measure are the same either way.
func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	plan = p_plan
	spec = p_plan.spec
	begin(4)
	roof_enabled = with_roof
	total_height = spec.height

	_build_floor()
	_build_trapdoor_panels()
	_build_plinth()
	_build_exterior_walls()
	_build_partitions()
	_build_secret_door_panels()
	if plan.has_court():
		_build_court_walls()
	if spec.material != &"stone":
		_build_jetty()
		_build_timber_frame()
		_build_interior_timber_bays()
	# HOUSE-RICH: the crown, the belt bands and the pediments. Every one of
	# them is behind its own spec field, so an ordinary house returns from this
	# having emitted nothing and its mesh is unchanged vertex for vertex.
	_build_witch_interior_finish()
	_build_rich_trim()
	# HOUSE-CULTURE: the two pieces that stand at or below the wall head. The
	# three that belong to the roof are emitted from _build_roof, because they
	# are placed against the roof that was actually built.
	_build_culture()
	if with_roof:
		_build_roof()
		_build_ceiling()
	_build_porch()
	_build_chimney()
	_build_yard()
	_build_witch_cauldron_heat()
	_build_hearth_breast()
	_build_rugs()
	_build_han_features()
	_build_vihara_features()
	_build_vastu_features()
	return commit()


## Continue the top room's perimeter into a castle range's unoccupied roof void.
func extend_upper_walls(height: float) -> void:
	var occupied_top := spec.height * spec.storeys
	if height <= occupied_top + 0.001:
		return
	for run in HouseGeometry.shell_runs(plan, spec.storeys - 1):
		var thick := float(run.get("thickness", HouseGeometry.wall_thickness(spec)))
		_wall_run(run.from, run.to, thick, height - occupied_top,
			[], 0, occupied_top, false)


func _build_hearth_breast() -> void:
	var breast := HouseGeometry.hearth_breast(plan)
	if breast.is_empty():
		return
	if not _is_ordinary_domestic_hearth():
		_emit_solid_hearth_breast(breast)
		return
	var level := int(breast["storey"])
	var y0 := level * spec.height
	var centre: Vector2 = breast["centre"]
	var breast_width: float = float(breast["width"])
	var breast_depth: float = float(breast["depth"])
	var opening_width: float = minf(1.15, breast_width - 0.28)
	var opening_bottom: float = 0.34
	var opening_clear_top: float = minf(1.26, spec.height - 0.72)
	var lintel_height: float = 0.18
	if opening_width < 0.65 or opening_clear_top <= opening_bottom + 0.25:
		_emit_solid_hearth_breast(breast)
		return
	tag("chimney_breast")
	host("hearth", level)
	var side_width: float = (breast_width - opening_width) * 0.5
	var yaw: float = float(breast["yaw"])
	var lintel_center_y: float = opening_clear_top + lintel_height * 0.5
	# Keep the same breast envelope and flue mass, but leave a real firebox
	# mouth through the room-facing masonry. The room wall behind it is the
	# firebox back; the opening is a recess, not a dark rectangle on the face.
	_hearth_breast_box("hearth_breast_left", Vector3(side_width, spec.height,
		breast_depth), centre, y0, spec.height * 0.5, -opening_width * 0.5 - side_width * 0.5,
		0.0, yaw, SURF_WALL)
	_hearth_breast_box("hearth_breast_right", Vector3(side_width, spec.height,
		breast_depth), centre, y0, spec.height * 0.5, opening_width * 0.5 + side_width * 0.5,
		0.0, yaw, SURF_WALL)
	_hearth_breast_box("hearth_breast_foot", Vector3(opening_width, opening_bottom,
		breast_depth), centre, y0, opening_bottom * 0.5, 0.0, 0.0, yaw, SURF_WALL)
	_hearth_breast_box("hearth_lintel", Vector3(opening_width, lintel_height,
		breast_depth), centre, y0, lintel_center_y, 0.0, 0.0, yaw, SURF_TRIM)
	var header_bottom: float = lintel_center_y + lintel_height * 0.5
	if spec.height > header_bottom:
		var mantel_depth: float = minf(0.12, breast_depth * 0.25)
		_hearth_breast_box("hearth_breast_header", Vector3(opening_width,
			spec.height - header_bottom, breast_depth - mantel_depth), centre, y0,
			header_bottom + (spec.height - header_bottom) * 0.5,
			0.0, mantel_depth * 0.5, yaw, SURF_WALL)
	# Short returns form the inside cheeks of the recess; they stop at the host
	# wall, which remains the firebox back.
	var cheek_depth: float = breast_depth * 0.68
	var cheek_height: float = opening_clear_top - opening_bottom
	var cheek_z: float = -breast_depth * 0.5 + cheek_depth * 0.5
	for side in [-1.0, 1.0]:
		_hearth_breast_box("hearth_jamb", Vector3(0.10, cheek_height, cheek_depth),
			centre, y0, opening_bottom + cheek_height * 0.5,
			side * (opening_width * 0.5 - 0.05), cheek_z, yaw, SURF_TRIM)
	# A restrained mantel sits on the lintel and within the recorded envelope.
	var mantel_depth: float = minf(0.12, breast_depth * 0.25)
	_hearth_breast_box("hearth_mantel", Vector3(opening_width + 0.24, 0.10,
		mantel_depth), centre, y0, header_bottom + 0.05, 0.0,
		-breast_depth * 0.5 + mantel_depth * 0.5, yaw, SURF_TRIM)
	var rect: Rect2 = breast["rect"]
	_log_mass("chimney_breast", AABB(Vector3(rect.position.x, y0, rect.position.y), Vector3(rect.size.x, spec.height, rect.size.y)), y0)
	host_end()


func _is_ordinary_domestic_hearth() -> bool:
	return plan != null and spec != null and plan.spec == spec \
		and spec.get_script() == BASE_HOUSE_SPEC \
		and spec.trade == &"none" and plan.world_family == &"" \
		and not spec.has_method("room_program") and not spec.has_method("custom_room_rects")


func _emit_solid_hearth_breast(breast: Dictionary) -> void:
	var level: int = int(breast["storey"])
	var y0: float = float(level) * spec.height
	var centre: Vector2 = breast["centre"]
	var size := Vector3(float(breast["width"]), spec.height, float(breast["depth"]))
	var xf := Transform3D(Basis(Vector3.UP, float(breast["yaw"])),
		Vector3(centre.x, y0 + spec.height * 0.5, centre.y))
	tag("chimney_breast")
	host("hearth", level)
	component_box("chimney_breast", size, xf, SURF_WALL)
	var rect: Rect2 = breast["rect"]
	_log_mass("chimney_breast", AABB(Vector3(rect.position.x, y0, rect.position.y),
		Vector3(rect.size.x, spec.height, rect.size.y)), y0)
	host_end()


func _hearth_breast_box(role: String, size: Vector3, centre: Vector2, y0: float,
		y_local: float, x_local: float, z_local: float, yaw: float, surface: int) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var local_offset := basis * Vector3(x_local, 0.0, z_local)
	var xf := Transform3D(basis, Vector3(centre.x, y0 + y_local, centre.y) + local_offset)
	component_box(role, size, xf, surface)


func _build_rugs() -> void:
	var st: SurfaceTool = _kit._sts[SURF_FLOOR]
	for rug in plan.rugs:
		var rect: Rect2 = rug["rect"]
		var y := int(rug["storey"]) * spec.height + HouseGeometry.FLOOR_T + 0.002
		if plan.on_dais(int(rug["room"]), rect.get_center()):
			y += plan.dais_rise()
		var points := Poly.from_rect(rect)
		var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		st.set_color(Color.BLACK) # Dedicated textile region within the stable floor surface.
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[index])
			st.add_vertex(Vector3(points[index].x, y, points[index].y))
		st.set_color(Color.WHITE)
		_log_part("rug", Vector3(rect.get_center().x, y, rect.get_center().y), Vector3(rect.size.x, 0, rect.size.y))


## The han's open-air kiosk and winter-hall dome are structural, named masses.
## They are emitted here so CourtCheck, mass rules and renderers all see the
## same geometry rather than plan-only symbols.
func _build_han_features() -> void:
	if plan.world_subkind != &"sultan_han":
		return
	var kiosk: Rect2 = plan.world_meta["kiosk_rect"]
	var flood: Rect2 = plan.world_meta["flood_rect"]
	var centre := kiosk.get_center()
	var half := kiosk.size * 0.5
	var water_gap := kiosk.grow(0.16)
	var water_bands: Array[Rect2] = [
		Rect2(flood.position, Vector2(flood.size.x, water_gap.position.y - flood.position.y)),
		Rect2(Vector2(flood.position.x, water_gap.end.y),
			Vector2(flood.size.x, flood.end.y - water_gap.end.y)),
		Rect2(Vector2(flood.position.x, water_gap.position.y),
			Vector2(water_gap.position.x - flood.position.x, water_gap.size.y)),
		Rect2(Vector2(water_gap.end.x, water_gap.position.y),
			Vector2(flood.end.x - water_gap.end.x, water_gap.size.y))]
	tag("han_court_water")
	host("court_water", 0)
	for band in water_bands:
		if not band.has_area():
			continue
		var points := PackedVector3Array()
		for p in Poly.from_rect(band):
			points.append(Vector3(p.x, plan.water_plane, p.y))
		component_slab("han_court_flood", points, 0.015, SURF_FLOOR, false)
	host_end()

	var post_offset := Vector2(half.x - 0.42, half.y - 0.42)
	tag("han_kiosk")
	host("kiosk", 0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pos := Vector3(centre.x + post_offset.x * sx, 1.81,
				centre.y + post_offset.y * sz)
			var size := Vector3(0.34, 3.62, 0.34)
			component_box("han_kiosk_pier", size,
				Transform3D(Basis.IDENTITY, pos), SURF_WALL)
	var deck_size := Vector3(kiosk.size.x, 0.36, kiosk.size.y)
	var deck_pos := Vector3(centre.x, 2.72, centre.y)
	component_box("han_kiosk_deck", deck_size,
		Transform3D(Basis.IDENTITY, deck_pos), SURF_TRIM)
	var canopy_side := maxf(2.8, kiosk.size.x - 0.42)
	var canopy_size := Vector3(canopy_side, 0.22, canopy_side)
	var canopy_pos := Vector3(centre.x, 3.72, centre.y)
	component_box("han_kiosk_canopy", canopy_size,
		Transform3D(Basis.IDENTITY, canopy_pos), SURF_ROOF)
	var kiosk_bounds := AABB(Vector3(kiosk.position.x, 0.0, kiosk.position.y),
		Vector3(kiosk.size.x, canopy_pos.y + canopy_size.y * 0.5,
			kiosk.size.y))
	_log_mass("han_kiosk", kiosk_bounds)
	total_height = maxf(total_height, kiosk_bounds.end.y)
	host_end()

	var hall: Rect2 = plan.world_meta["winter_hall_rect"]
	var radius := float(plan.world_meta["dome_radius"])
	var base_y := float(plan.world_meta["dome_base_y"])
	var rise := float(plan.world_meta["dome_rise"])
	var dome_centre := hall.get_center()
	tag("han_winter_hall")
	host("winter_hall", 0)
	var top_angle := PI * 0.5 - 0.035
	for band in range(HAN_DOME_BANDS):
		var theta0 := top_angle * float(band) / float(HAN_DOME_BANDS)
		var theta1 := top_angle * float(band + 1) / float(HAN_DOME_BANDS)
		for segment in range(HAN_DOME_SEGMENTS):
			var phi0 := TAU * float(segment) / float(HAN_DOME_SEGMENTS)
			var phi1 := TAU * float(segment + 1) / float(HAN_DOME_SEGMENTS)
			var points := PackedVector3Array([
				_dome_point(dome_centre, radius, base_y, rise, theta0, phi0),
				_dome_point(dome_centre, radius, base_y, rise, theta0, phi1),
				_dome_point(dome_centre, radius, base_y, rise, theta1, phi1),
				_dome_point(dome_centre, radius, base_y, rise, theta1, phi0)])
			component_slab("han_dome_segment", points, 0.14, SURF_ROOF, false)
	var apex := Vector3(dome_centre.x, base_y + rise, dome_centre.y)
	for segment in range(HAN_DOME_SEGMENTS):
		var phi0 := TAU * float(segment) / float(HAN_DOME_SEGMENTS)
		var phi1 := TAU * float(segment + 1) / float(HAN_DOME_SEGMENTS)
		var cap := PackedVector3Array([apex,
			_dome_point(dome_centre, radius, base_y, rise, top_angle, phi0),
			_dome_point(dome_centre, radius, base_y, rise, top_angle, phi1)])
		component_slab("han_dome_cap", cap, 0.14, SURF_ROOF, false)
	var dome_size := Vector3(radius * 2.0, rise + 0.16, radius * 2.0)
	_log_mass("han_winter_dome", AABB(
		Vector3(dome_centre.x - radius, base_y - 0.08, dome_centre.y - radius), dome_size))
	total_height = maxf(total_height, base_y + rise)
	host_end()


## The open court's low stone well is a real, separately measured feature.
func _build_vihara_features() -> void:
	if plan.world_subkind != &"monks_cloister":
		return
	var basin: Rect2 = plan.world_meta.get("well_rect", Rect2())
	if not basin.has_area():
		return
	var thickness := 0.18
	var wall_height := 0.78
	var wall_center_y := wall_height * 0.5
	var center := basin.get_center()
	tag("vihara_well")
	host("court_well", 0)
	var x_side := Vector3(thickness, wall_height, basin.size.y)
	var z_side := Vector3(basin.size.x - thickness * 2.0, wall_height, thickness)
	for x in [basin.position.x + thickness * 0.5, basin.end.x - thickness * 0.5]:
		component_box("vihara_well_rim", x_side,
			Transform3D(Basis.IDENTITY, Vector3(x, wall_center_y, center.y)), SURF_TRIM)
	for z in [basin.position.y + thickness * 0.5, basin.end.y - thickness * 0.5]:
		component_box("vihara_well_rim", z_side,
			Transform3D(Basis.IDENTITY, Vector3(center.x, wall_center_y, z)), SURF_TRIM)
	var water := basin.grow(-thickness)
	var points := PackedVector3Array()
	for p in Poly.from_rect(water):
		points.append(Vector3(p.x, plan.water_plane, p.y))
	component_slab("vihara_well_water", points, 0.025, SURF_FLOOR, false)
	_log_mass("vihara_well", AABB(Vector3(basin.position.x, 0.0, basin.position.y),
		Vector3(basin.size.x, wall_height, basin.size.y)))
	total_height = maxf(total_height, wall_height)
	host_end()


## A haveli's north-east well and upper street projections are structural
## features. They stay in the house builder so the public world family uses
## the same shell, mass log and assembler as every other plan-first house.
func _build_vastu_features() -> void:
	if plan.world_family != &"vastu":
		return
	var well: Rect2 = plan.world_meta.get("well_rect", Rect2())
	if well.has_area():
		var rim_t := 0.16
		var rim_h := 0.72
		var centre := well.get_center()
		tag("vastu_well")
		host("vastu_well", 0)
		var x_side := Vector3(rim_t, rim_h, well.size.y)
		var z_side := Vector3(well.size.x - rim_t * 2.0, rim_h, rim_t)
		for x in [well.position.x + rim_t * 0.5, well.end.x - rim_t * 0.5]:
			component_box("vastu_well_rim", x_side,
				Transform3D(Basis.IDENTITY, Vector3(x, rim_h * 0.5, centre.y)), SURF_TRIM)
		for z in [well.position.y + rim_t * 0.5, well.end.y - rim_t * 0.5]:
			component_box("vastu_well_rim", z_side,
				Transform3D(Basis.IDENTITY, Vector3(centre.x, rim_h * 0.5, z)), SURF_TRIM)
		_log_mass("vastu_well", AABB(Vector3(well.position.x, 0.0, well.position.y),
			Vector3(well.size.x, rim_h, well.size.y)))
		total_height = maxf(total_height, rim_h)
		host_end()

	var site := HouseGeometry.site_rect(spec)
	var base_y := float(plan.world_meta.get("jharokha_floor", spec.height))
	var projection := Vector3(minf(2.4, site.size.x * 0.18), 2.2, 0.8)
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var pos := Vector3(side * site.size.x * 0.24,
			base_y + projection.y * 0.5, site.position.y - projection.z * 0.5)
		var xf := Transform3D(Basis.IDENTITY, pos)
		tag("jharokha_%d" % index)
		host("jharokha_%d" % index, 1)
		component_box("jharokha_bay", projection, xf, SURF_TRIM)
		_log_mass("jharokha_%d" % index,
			AABB(pos - projection * 0.5, projection), base_y)
		total_height = maxf(total_height, base_y + projection.y)
		host_end()


func _dome_point(centre: Vector2, radius: float, base_y: float, rise: float,
		theta: float, phi: float) -> Vector3:
	var ring: float = cos(theta) * radius
	return Vector3(centre.x + ring * cos(phi), base_y + rise * sin(theta),
		centre.y + ring * sin(phi))


# ------------------------------------------------------------------ floor

## Reset the house's own per-build records alongside the shared logs. This
## belongs on begin() rather than on build(): HotelBuilder overrides build()
## and does not call super, so a subclass would otherwise carry the previous
## run's opening numbering into the next one and its component identities
## would drift.
func begin(surface_count: int) -> void:
	super.begin(surface_count)
	roof_components.clear()
	roof_opening_log.clear()
	_opening_seq = 0
	emitted_mesh = null
	roof_enabled = false


func commit() -> ArrayMesh:
	# A world plan is dressed slot by slot, and a roof-off cutaway omits the
	# roof surface ahead of the floor; name the survivors. Ordinary houses
	# are left exactly as they were.
	emitted_mesh = commit_named() if plan != null and plan.world_family != &"" \
		else super.commit()
	return emitted_mesh


## How far a slab is tucked out of the faces it would otherwise share (WALK-QA,
## 6 Oct). A floor laid exactly to the outside of the walls puts its edge in
## the wall's own plane, and its underside in the plane of every upper
## partition's foot: the renderer cannot order either pair and the walk-through
## saw a flickering stripe along each floor line and a sawtooth across a
## ceiling. The slab now stops this far inside the outer faces and hangs this
## far below its storey line, where both seams are buried in masonry. The
## walking surface, `y0 + FLOOR_T`, is unchanged, and so is the logged mass.
const SLAB_TUCK := 0.006
## The same idea for an opening's frame: the jambs, head and sill were laid
## exactly against the wall's cut, so the jamb's inner face and the reveal were
## one plane and flickered (WALK-QA, 6 Oct, hotel pin 1). The frame now stands
## this far into the opening and hides the cut. The clear opening loses twice
## this, 12 mm, nowhere near anything a body or the nav grid can notice.
const TRIM_TUCK := 0.006


## The top storey's ceiling: a plaster slab across the wall heads, so that
## looking up indoors meets a ceiling and not the underside of the roof boards
## (WALK-QA, 6 Oct, shop pin 7: "no ceiling"). The plan already assumes one --
## `spec.height` is floor to ceiling, chandeliers hang from it, and a dormer
## lights an attic, not a room -- and every lower storey has one in the floor
## above. It lies ON the wall heads, out to the walls' centre lines, so its
## underside meets the tops of the walls back to back and shares no plane with
## them.
##
## Not for a cutaway (the roof is off to show the rooms), a yard plan, a
## shaped storey, a flat or conical roof (the roof IS the ceiling there), a
## plan with authored roof openings (an oculus or a compluvium must stay open
## to the sky), or a family of the wider world (it owns its interiors).
const CEILING_T := 0.06


func _build_ceiling(any_roof := false, roofed := false) -> void:
	if not (roof_enabled or roofed) or plan.has_court() or plan.world_family != &"" \
			or not plan.roof_openings.is_empty():
		return
	if not any_roof and spec.roof_type not in [&"gable", &"half_hipped", &"hipped"]:
		return
	var levels := _levels()
	var level: int = levels.max()
	if _shaped_room(level) >= 0:
		return
	var r: Rect2 = HouseGeometry.storey_rect(plan, level).grow(-HouseGeometry.wall_thickness(spec) * 0.5)
	var bay: Dictionary = HouseGeometry.roof_layout(plan).get("witch_bay", {})
	if not bay.is_empty():
		_build_witch_bay_ceiling(r, float(level + 1) * spec.height, bay, level)
		_build_witch_hall_ceiling_ties(level, float(level + 1) * spec.height)
		return
	var y := float(level + 1) * spec.height
	tag("ceiling")
	host("ceiling", level)
	component_box("ceiling", Vector3(r.size.x, CEILING_T, r.size.y),
		Transform3D(Basis(), Vector3(r.get_center().x, y + CEILING_T * 0.5, r.get_center().y)),
		SURF_WALL)
	host_end()
	_build_witch_hall_ceiling_ties(level, y)


func _build_witch_bay_ceiling(main_rect: Rect2, ceiling_y: float,
		bay: Dictionary, level: int) -> void:
	var room := int(bay["room"])
	var room_rect: Rect2 = bay.get("wing_rect", HouseGeometry.room_floor_rect(plan, room))
	var flat_pieces: Array[PackedVector2Array] = RoofShape.subtract(Poly.from_rect(main_rect), Poly.from_rect(room_rect))
	tag("ceiling")
	host("ceiling", level)
	for piece in flat_pieces:
		var points := PackedVector3Array()
		for p in piece:
			points.append(Vector3(p.x, ceiling_y + CEILING_T * 0.5, p.y))
		component_slab("ceiling", points, CEILING_T, SURF_WALL, true)
	host_end()
	var xf: Transform3D = bay["transform"]
	var axis := int(bay["axis"])
	var outer := float(bay["ceiling_outer"])
	var inner := float(bay["ceiling_inner"])
	var lo := float(bay["ceiling_along_lo"])
	var hi := float(bay["ceiling_along_hi"])
	var outer_plane := float(bay["outer"])
	var inner_plane := float(bay["inner"])	
	var roof_bottom := float(bay["eave_y"]) - RoofShape.DEPTH * 0.5 - 0.0075
	var slope_rise := float(bay["join_y"]) - float(bay["eave_y"])
	var face := PackedVector3Array()
	for p in bay["ceiling_outline"]:
		var coord: float = p.x if axis == 0 else p.y
		var t := clampf((coord - outer_plane) / (inner_plane - outer_plane), 0.0, 1.0)
		var y := roof_bottom + slope_rise * t
		face.append(xf * Vector3(p.x, y, p.y))
	tag("witch_workshop_bay_ceiling")
	host("witch_workshop_bay_ceiling", level)
	component_slab("witch_workshop_bay_ceiling", face, 0.015, SURF_WALL, true)
	host_end()


func _build_witch_hall_ceiling_ties(level: int, ceiling_y: float) -> void:
	if not HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family):
		return
	var wall_t: float = HouseGeometry.wall_thickness(spec)
	var tie_h := 0.14
	var end_bearing := wall_t * 0.35
	for room_index in range(plan.rooms.size()):
		if plan.kind_of(room_index) != &"hall" or plan.storey_of_room(room_index) != level:
			continue
		if plan.is_polygonal(room_index):
			continue
		var room: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
		var short_span := minf(room.size.x, room.size.y)
		var long_span := maxf(room.size.x, room.size.y)
		if short_span < 2.4 or long_span < 3.6:
			continue
		var across_x := room.size.x <= room.size.y
		var tie_count := clampi(int(floor((long_span - 2.4) / 2.4)) + 1, 1, 3)
		var station_gap := long_span / float(tie_count + 1)
		var span := short_span + end_bearing * 2.0
		var size := Vector3(span, tie_h, 0.14) if across_x else Vector3(0.14, tie_h, span)
		host("witch_hall_ceiling_ties_room%d" % room_index, level)
		for tie_index in range(tie_count):
			var station := station_gap * float(tie_index + 1)
			var center := room.position + room.size * 0.5
			if across_x:
				center.y = room.position.y + station
			else:
				center.x = room.position.x + station
			var xf := Transform3D(Basis(), Vector3(center.x, ceiling_y - tie_h * 0.5, center.y))
			if _witch_tie_conflicts_with_aperture(room, center, size,
					across_x, ceiling_y - tie_h, ceiling_y, plan.doors + plan.windows,
					wall_t, plan.storey_of_room(room_index), float(level) * spec.height):
				continue
			component_box("witch_hall_ceiling_tie", size, xf, SURF_TRIM)
		host_end()



static func _witch_tie_conflicts_with_aperture(room: Rect2, center: Vector2,
		tie_size: Vector3, across_x: bool, tie_bottom: float, tie_top: float,
		openings: Array, wall_t: float, level: int, floor_datum := 0.0) -> bool:
	for opening in openings:
		if (opening.has("storey") or opening.has("level")) and int(opening.get("storey", opening.get("level", 0))) != level:
			continue
		var bottom := float(opening.get("bottom", float(opening.get("sill", 0.0)) + floor_datum))
		var top := float(opening.get("top", float(opening.get("head", HouseGeometry.DOOR_H)) + floor_datum))
		if top <= tie_bottom or bottom >= tie_top:
			continue
		var pos: Vector2 = opening["pos"]
		var normal: Vector2 = opening["normal"].normalized()
		var width := float(opening.get("w", opening.get("width", -1.0)))
		if width <= 0.0:
			continue
		var same_support_wall := false
		var opening_center: float
		var tie_lo: float
		var tie_hi: float
		if across_x and absf(normal.x) > 0.9:
			same_support_wall = absf(pos.x - room.position.x) <= wall_t or absf(pos.x - room.end.x) <= wall_t
			opening_center = pos.y
			tie_lo = center.y - tie_size.z * 0.5
			tie_hi = center.y + tie_size.z * 0.5
		elif not across_x and absf(normal.y) > 0.9:
			same_support_wall = absf(pos.y - room.position.y) <= wall_t or absf(pos.y - room.end.y) <= wall_t
			opening_center = pos.x
			tie_lo = center.x - tie_size.x * 0.5
			tie_hi = center.x + tie_size.x * 0.5
		else:
			continue
		if same_support_wall and tie_lo < opening_center + width * 0.5 and tie_hi > opening_center - width * 0.5:
			return true
	return false


func _build_floor() -> void:
	tag("floor")
	var t: float = HouseGeometry.FLOOR_T
	for level in _levels():
		var r: Rect2 = HouseGeometry.storey_rect(plan, level)
		var y0 := float(level) * spec.height
		var a := AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y))
		# the emitted slab: inside the outer faces, and down past the storey
		# line -- except the lowest, whose underside is on the ground and seen
		# by nobody, and which must not reach below the planned shell
		var drop := 0.0 if level == _lowest() else SLAB_TUCK
		var slab := AABB(Vector3(r.position.x + SLAB_TUCK, y0 - drop, r.position.y + SLAB_TUCK),
			Vector3(r.size.x - SLAB_TUCK * 2.0, t + drop, r.size.y - SLAB_TUCK * 2.0))
		var holes: Array[int] = plan.courts_on(level)
		if not holes.is_empty():
			# The floor is laid round the yard, band by band, so the court is
			# left as open ground for the walk grid to rasterise.
			_emit_floor_round_courts(r, y0, t, level, holes)
			continue
		var shaped: int = _shaped_room(level)
		if shaped >= 0:
			# The floor of a shaped storey is the shape, pushed out to the
			# middle of its own wall so the slab and the masonry meet.
			var room_thick := float(plan.rooms[shaped].get("wall_thickness",
				HouseGeometry.wall_thickness(spec)))
			var poly: PackedVector2Array = Poly.offset(plan.outline_of(shaped),
				room_thick / 2.0)
			var pieces: Array[PackedVector2Array] = [poly]
			for opening in _floor_openings(level):
				var remaining: Array[PackedVector2Array] = []
				for piece in pieces:
					remaining.append_array(RoofShape.subtract(piece, Poly.from_rect(opening)))
				pieces = remaining
			for pi in pieces.size():
				_kit.slab_poly(_lift(pieces[pi], y0 + (t - drop) / 2.0), t + drop, SURF_FLOOR)
				var bounds := Poly.bounding_rect(pieces[pi])
				var floor_name := "floor" if _levels().size() == 1 else "floor_%d" % level
				if pieces.size() > 1:
					floor_name += "_%d" % pi
				_log_mass(floor_name, AABB(Vector3(bounds.position.x, y0, bounds.position.y),
					Vector3(bounds.size.x, t, bounds.size.y)), y0)
			continue
		var openings := _floor_openings(level)
		if not openings.is_empty():
			_emit_floor_around_many(r, openings, y0, t, level, drop)
		else:
			box(slab.size, slab.position + slab.size / 2.0, SURF_FLOOR)
			_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level, a, y0)
	_build_pits()
	_emit_stairs()


func _floor_openings(level: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var stair := _stair_opening(level)
	if stair.has_area():
		out.append(stair)
	for hatch in plan.trapdoors:
		if int(hatch.get("upper_storey", 0)) == level and hatch.get("rect") is Rect2:
			out.append(hatch["rect"])
	return out


## The sealed cellar hatch is a closed visible panel laid over the hole. It is
## an emitted named component; the plan record controls access semantics.
func _build_trapdoor_panels() -> void:
	for hatch in plan.trapdoors:
		var level := int(hatch.get("upper_storey", 0))
		var rect: Rect2 = hatch.get("rect", Rect2())
		if not rect.has_area():
			continue
		tag("trapdoor")
		host("cellar_hatch", level)
		var thickness := 0.045
		var y := float(level) * spec.height + HouseGeometry.FLOOR_T + thickness / 2.0 + 0.006
		var xform := Transform3D(Basis.IDENTITY, Vector3(rect.get_center().x, y, rect.get_center().y))
		component_box("trapdoor_panel", Vector3(rect.size.x, thickness, rect.size.y), xform, SURF_TRIM)


## A storey below the ground is dug, not raised (INT-016): the pit is logged
## as a negative mass, `dug`, the size of the site and a storey deep, so the
## structural rules know there is earth outside the cellar's walls rather
## than air. The walls and floor inside it stand on the pit floor.
func _build_pits() -> void:
	var r: Rect2 = HouseGeometry.site_rect(spec)
	for level in _levels():
		if level >= 0:
			continue
		var y0 := float(level) * spec.height
		var pit := AABB(Vector3(r.position.x - HouseGeometry.wall_thickness(spec), y0, r.position.y - HouseGeometry.wall_thickness(spec)),
			Vector3(r.size.x + 2.0 * HouseGeometry.wall_thickness(spec), spec.height, r.size.y + 2.0 * HouseGeometry.wall_thickness(spec)))
		mass_log.append({"name": "pit_%d" % level, "aabb": pit, "ground": y0, "kind": "dug"})


func _emit_floor_around_many(r: Rect2, holes: Array[Rect2], y0: float, t: float,
		level: int, drop := SLAB_TUCK) -> void:
	var xs: Array[float] = [r.position.x, r.end.x]
	var ys: Array[float] = [r.position.y, r.end.y]
	for hole in holes:
		var clipped := r.intersection(hole)
		if clipped.has_area():
			xs.append(clipped.position.x)
			xs.append(clipped.end.x)
			ys.append(clipped.position.y)
			ys.append(clipped.end.y)
	xs.sort()
	ys.sort()
	var emitted := 0
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			var p := Rect2(Vector2(xs[xi], ys[yi]), Vector2(xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))
			if p.size.x <= 0.01 or p.size.y <= 0.01:
				continue
			var centre2 := p.get_center()
			var in_hole := false
			for hole in holes:
				if hole.has_point(centre2):
					in_hole = true
					break
			if in_hole:
				continue
			var size := Vector3(p.size.x, t, p.size.y)
			var centre := Vector3(centre2.x, y0 + t / 2.0, centre2.y)
			# emitted tucked like the whole slab; logged as planned
			var tucked := p.intersection(r.grow(-SLAB_TUCK))
			box(Vector3(tucked.size.x, t + drop, tucked.size.y),
				Vector3(tucked.get_center().x, y0 + (t - drop) / 2.0, tucked.get_center().y),
				SURF_FLOOR)
			_log_mass("floor_%d_%d" % [level, emitted], AABB(centre - size / 2.0, size), y0)
			emitted += 1


func _stair_opening(level: int) -> Rect2:
	if level <= _lowest():
		return Rect2()
	var stairs = plan.get("stairs")
	if stairs == null:
		return Rect2()
	for stair in stairs:
		if not (stair is Dictionary):
			continue
		if not bool(stair.get("satisfied", true)):
			continue
		var from_level := int(stair.get("storey",
			stair.get("from_storey", stair.get("from_level", level - 1))))
		if from_level + 1 != level:
			continue
		var raw = stair.get("upper_rect", stair.get("rect", stair.get("opening", Rect2())))
		if raw is Rect2:
			return raw
	return Rect2()


func _emit_stairs() -> void:
	var stairs = plan.get("stairs")
	if stairs == null:
		return
	tag("stair")
	for index in range(stairs.size()):
		var stair = stairs[index]
		if not (stair is Dictionary):
			continue
		var raw = stair.get("lower_rect", stair.get("rect", stair.get("opening", Rect2())))
		if not (raw is Rect2):
			continue
		var footprint: Rect2 = raw
		var from_level := int(stair.get("storey",
			stair.get("from_storey", stair.get("from_level", 0))))
		if not bool(stair.get("satisfied", true)):
			continue
		var steps := maxi(4, int(stair.get("steps", 10)))
		var step_h := spec.height / float(steps)
		# the flight climbs along the footprint's long side, which is the axis
		# the planner laid the well on (it runs the room's long way, LAY-005)
		var along_x: bool = footprint.size.x > footprint.size.y
		var run: float = footprint.size.x if along_x else footprint.size.y
		# from whichever end has floor in front of it (HouseGeometry.stair_climb)
		var climb: float = HouseGeometry.stair_climb(plan, stair)
		var step_base_y: float = float(from_level) * spec.height
		if bool(stair.get("domestic_profile", false)):
			# Domestic treads rise from the walking surface on top of the lower
			# floor slab. Legacy/custom flights keep their original datum.
			step_base_y += HouseGeometry.FLOOR_T
		for s in range(steps):
			var t: float = run * (float(s) + 0.5) / steps
			if climb < 0.0:
				t = run - t
			var h := step_h * float(s + 1)
			var step_size := Vector3(run / steps, h, footprint.size.y) if along_x \
				else Vector3(footprint.size.x, h, run / steps)
			var step_center := Vector3(footprint.position.x + t,
					step_base_y + h / 2.0, footprint.get_center().y) \
				if along_x else Vector3(footprint.get_center().x,
					step_base_y + h / 2.0, footprint.position.y + t)
			box(step_size, step_center, SURF_FLOOR)
			_log_mass("stair_%d_step_%d" % [index, s],
				AABB(step_center - step_size / 2.0, step_size), step_base_y)
		if bool(stair.get("domestic_profile", false)):
			_emit_stair_guards(index, footprint, from_level, climb)


## The open long edges of a domestic flight are guarded at both heights. These
## are real emitted components, hosted to the stair, so exterior/component QA
## can compare their log with the triangles that were built.
func _emit_stair_guards(index: int, footprint: Rect2, from_level: int,
		climb: float) -> void:
	var along_x := footprint.size.x > footprint.size.y
	var width := footprint.size.y if along_x else footprint.size.x
	var foot_2d: Vector2
	var head_2d: Vector2
	if along_x:
		foot_2d = Vector2(footprint.position.x if climb > 0.0 else footprint.end.x,
			footprint.get_center().y)
		head_2d = Vector2(footprint.end.x if climb > 0.0 else footprint.position.x,
			footprint.get_center().y)
	else:
		foot_2d = Vector2(footprint.get_center().x,
			footprint.position.y if climb > 0.0 else footprint.end.y)
		head_2d = Vector2(footprint.get_center().x,
			footprint.end.y if climb > 0.0 else footprint.position.y)
	var base_y := float(from_level) * spec.height + HouseGeometry.FLOOR_T
	var foot := Vector3(foot_2d.x, base_y, foot_2d.y)
	var head := Vector3(head_2d.x, base_y + spec.height, head_2d.y)
	var direction := (head - foot).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized()
	var up := side.cross(direction).normalized()
	var basis := Basis(direction, up, side)
	host("stair_%d" % index, from_level)
	for edge: float in [-1.0, 1.0]:
		var offset: Vector3 = side * (width * 0.5 - HouseGeometry.STAIR_GUARD_EDGE_OFFSET) * edge
		var a: Vector3 = foot + offset
		var b: Vector3 = head + offset
		_emit_stair_guard_beam("stair_rail_top", a + Vector3.UP * 0.9,
			b + Vector3.UP * 0.9, basis)
		_emit_stair_guard_beam("stair_rail_mid", a + Vector3.UP * 0.46,
			b + Vector3.UP * 0.46, basis)
		for fraction: float in [0.0, 0.5, 1.0]:
			var at: Vector3 = a.lerp(b, fraction)
			var rise: float = lerpf(0.0, spec.height, fraction)
			var post_xf := Transform3D(Basis.IDENTITY,
				Vector3(at.x, base_y + rise + 0.45, at.z))
			component_box("stair_guard_post", Vector3(HouseGeometry.STAIR_GUARD_THICKNESS,
				0.9, HouseGeometry.STAIR_GUARD_THICKNESS),
				post_xf, SURF_TRIM)
	_emit_upper_well_guards(index, footprint, from_level, climb)
	host_end()


## At the upper floor the inclined flight rail is not a substitute for the
## guard at the edge of the open well. Emit a separate level rail along each
## long edge of the floor opening; the head end stays open onto its landing.
func _emit_upper_well_guards(index: int, footprint: Rect2, from_level: int,
		climb: float) -> void:
	var along_x := footprint.size.x > footprint.size.y
	var run := footprint.size.x if along_x else footprint.size.y
	var width := footprint.size.y if along_x else footprint.size.x
	var floor_y := float(from_level + 1) * spec.height + HouseGeometry.FLOOR_T
	var edge_offset := width * 0.5 - HouseGeometry.STAIR_GUARD_EDGE_OFFSET
	for edge: float in [-1.0, 1.0]:
		var cx := footprint.get_center().x
		var cz := footprint.get_center().y
		if along_x:
			cz += edge_offset * edge
		else:
			cx += edge_offset * edge
		var rail_size := Vector3(run, HouseGeometry.STAIR_GUARD_THICKNESS,
			HouseGeometry.STAIR_GUARD_THICKNESS) if along_x else Vector3(
			HouseGeometry.STAIR_GUARD_THICKNESS, HouseGeometry.STAIR_GUARD_THICKNESS, run)
		component_box("stair_well_rail_top", rail_size,
			Transform3D(Basis.IDENTITY, Vector3(cx, floor_y + 0.9, cz)), SURF_TRIM)
		component_box("stair_well_rail_mid", rail_size,
			Transform3D(Basis.IDENTITY, Vector3(cx, floor_y + 0.46, cz)), SURF_TRIM)
		for fraction: float in [0.0, 0.5, 1.0]:
			# The inclined guard already supplies this upper head-corner post.
			# Keep one solid post at the joint, not two coincident boxes.
			if is_equal_approx(fraction, 1.0 if climb > 0.0 else 0.0):
				continue
			var along := lerpf(-run * 0.5, run * 0.5, fraction)
			var px := footprint.get_center().x + (along if along_x else 0.0)
			var pz := footprint.get_center().y + (along if not along_x else 0.0)
			if along_x:
				pz += edge_offset * edge
			else:
				px += edge_offset * edge
			component_box("stair_well_guard_post", Vector3(HouseGeometry.STAIR_GUARD_THICKNESS,
				0.9, HouseGeometry.STAIR_GUARD_THICKNESS),
				Transform3D(Basis.IDENTITY, Vector3(px, floor_y + 0.45, pz)), SURF_TRIM)
	# The foot end borders the drop too. The head end stays open so the
	# upper flight arrives onto its landing without a rail across the route.
	var foot_x := footprint.position.x if climb > 0.0 else footprint.end.x
	var foot_z := footprint.position.y if climb > 0.0 else footprint.end.y
	var cross_size := Vector3(HouseGeometry.STAIR_GUARD_THICKNESS,
		HouseGeometry.STAIR_GUARD_THICKNESS, width) if along_x else Vector3(
		width, HouseGeometry.STAIR_GUARD_THICKNESS, HouseGeometry.STAIR_GUARD_THICKNESS)
	var cross_center := Vector3(foot_x, floor_y, footprint.get_center().y) if along_x \
		else Vector3(footprint.get_center().x, floor_y, foot_z)
	for rail_height: float in [0.46, 0.9]:
		component_box("stair_well_foot_rail", cross_size,
			Transform3D(Basis.IDENTITY, cross_center + Vector3.UP * rail_height), SURF_TRIM)
	# The two corner posts already belong to the long-side rails. One centre
	# post splits this short rail span without placing another post on either
	# corner; the adjacent boxes would overlap by more than their half-thickness.
	var middle_post := Vector3(foot_x, floor_y + 0.45,
		footprint.get_center().y) if along_x else Vector3(
		footprint.get_center().x, floor_y + 0.45, foot_z)
	component_box("stair_well_foot_guard_post", Vector3(
			HouseGeometry.STAIR_GUARD_THICKNESS, 0.9,
			HouseGeometry.STAIR_GUARD_THICKNESS),
			Transform3D(Basis.IDENTITY, middle_post), SURF_TRIM)


func _emit_stair_guard_beam(role: String, start: Vector3, finish: Vector3,
		basis: Basis) -> void:
	var centre := (start + finish) * 0.5
	var length := start.distance_to(finish)
	var xf := Transform3D(basis, centre)
	component_box(role, Vector3(length, HouseGeometry.STAIR_GUARD_THICKNESS,
		HouseGeometry.STAIR_GUARD_THICKNESS), xf, SURF_TRIM)


# ------------------------------------------------------------------ plinth

func _build_plinth() -> void:
	tag("plinth")
	var plinth_h: float = minf(spec.plinth_height, HouseGeometry.WINDOW_SILL - 0.18)
	if plinth_h <= 0.05 or (spec.stone_ground_floor and _storeys() > 1):
		return
	var thick: float = HouseGeometry.wall_thickness(spec) + HouseGeometry.PLINTH_EXTRA * 2.0
	for run in HouseGeometry.exterior_runs(spec):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var normal: Vector2 = run["normal"]
		var openings: Array[Dictionary] = []
		# Leave gaps for exterior doors on level 0
		for d in plan.doors:
			if _opening_storey(d) != 0 and _has_storey_metadata(d):
				continue
			if not d["exterior"]:
				continue
			if not _on_run(from, to, normal, d["pos"], d["normal"]):
				continue
			var interval := _door_interval(d)
			var plinth_bottom: float = maxf(float(interval[0]), 0.0) if interval[2] else 0.0
			var plinth_top: float = plinth_h + 0.05 if not interval[2] else minf(float(interval[1]), plinth_h)
			if plinth_bottom >= plinth_h - 0.001 or plinth_top <= plinth_bottom + 0.001:
				continue
			openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]) + 0.12,
				"bottom": plinth_bottom, "top": plinth_top,
				"kind": "door", "normal": normal})
		# These are clearances, not additional framed doors. Framing the short
		# plinth opening used to put a second lintel across the real doorway.
		_wall_run(from, to, thick, plinth_h, openings, SURF_FLOOR, 0.0, false,
			_corner_ext(run, thick))
		# Chamfered stone water-table moulding at the top of the plinth
		var seg: Vector2 = to - from
		var run_len: float = seg.length()
		if run_len > 0.1:
			_wall_run(from, to, thick + 0.04, 0.06, openings, SURF_FLOOR,
				plinth_h - 0.03, false, _corner_ext(run, thick + 0.04))


# ------------------------------------------------------------------ walls

func _build_exterior_walls() -> void:
	tag("wall")
	var h: float = spec.height
	for level in _levels():
		var y0 := float(level) * h
		var surf: int = SURF_FLOOR if (spec.stone_ground_floor and level == 0) else SURF_WALL
		for run in HouseGeometry.shell_runs(plan, level):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var normal: Vector2 = run["normal"]
			var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec)))
			if _build_colonnade_run(run, level, y0, h, thick):
				continue
			var openings: Array[Dictionary] = _openings_on(from, to, normal, level, thick)
			_wall_run(from, to, thick, h, openings, surf, y0, true, _corner_ext(run, thick))
			var a: AABB = _run_aabb(from, to, thick, h, y0)
			var suffix := "" if _levels().size() == 1 else "_%d" % level
			_log_mass("wall_%s%s" % [String(run["side"]), suffix], a, y0)
	total_height = maxf(total_height, h * _storeys())


## Replace a planned arcade wall with authored posts and lintels. A portal is
## the one solid interval on the market hall's front: its real door is still
## cut by the ordinary opening path.
func _build_colonnade_run(run: Dictionary, level: int, y0: float,
		height: float, thick: float) -> bool:
	var from: Vector2 = run["from"]
	var to: Vector2 = run["to"]
	var dir := (to - from).normalized()
	var outward: Vector2 = run["normal"]
	var selected_room := -1
	var selected_wall := -1
	var selected_record: Dictionary = {}
	for room in range(plan.room_count()):
		if _room_storey(plan.rooms[room]) != level:
			continue
		var walls := HouseGeometry.room_walls(plan, room)
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			if wall.get("kind", &"solid") != &"colonnade":
				continue
			var wall_dir := (Vector2(wall["to"]) - Vector2(wall["from"])).normalized()
			if absf(wall_dir.dot(dir)) < 0.98 or Vector2(wall["normal"]).dot(outward) > -0.95:
				continue
			var midpoint: Vector2 = (Vector2(wall["from"]) + Vector2(wall["to"])) * 0.5
			if absf((midpoint - from).dot(outward)) > thick + 0.35:
				continue
			selected_room = room
			selected_wall = wi
			selected_record = wall
			break
		if selected_room >= 0:
			break
	if selected_room < 0:
		return false
	var posts: Array[Dictionary] = []
	for column in plan.columns:
		if int(column.get("room", -1)) == selected_room \
				and int(column.get("wall", -1)) == selected_wall \
				and int(column.get("storey", level)) == level:
			posts.append(column)
	if posts.is_empty():
		return false
	tag("colonnade")
	var portal: Dictionary = selected_record.get("portal", {})
	var portal_interval := Vector2(-INF, -INF)
	if not portal.is_empty():
		var wf: Vector2 = selected_record["from"]
		var wt: Vector2 = selected_record["to"]
		var wlen := wf.distance_to(wt)
		var world_a := wf.lerp(wt, float(portal["start"]) / wlen)
		var world_b := wf.lerp(wt, float(portal["end"]) / wlen)
		portal_interval = Vector2((world_a - from).dot(dir), (world_b - from).dot(dir))
	for column in posts:
		var pos: Vector2 = column["pos"]
		var size: Vector2 = column["size"]
		var post_height := float(column["height"])
		var centre := Vector3(pos.x, y0 + post_height * 0.5, pos.y)
		var post_size := Vector3(size.x, post_height, size.y)
		var xform := Transform3D(Basis.IDENTITY, centre)
		host("colonnade_%d_%d" % [selected_room, selected_wall], level)
		component_box("colonnade_column", post_size, xform, SURF_TRIM)
		_log_mass("colonnade_column_%d_%d_%d" % [selected_room, selected_wall, posts.find(column)],
			AABB(centre - post_size * 0.5, post_size), y0)
	host_end()
	var sorted_posts := posts.duplicate()
	sorted_posts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (Vector2(a["pos"]) - from).dot(dir) < (Vector2(b["pos"]) - from).dot(dir))
	var lintel_h := minf(0.26, height * 0.12)
	var lintel_y := y0 + height - lintel_h * 0.5
	var yaw := atan2(-dir.y, dir.x)
	for pi in range(sorted_posts.size() - 1):
		var a: Dictionary = sorted_posts[pi]
		var b: Dictionary = sorted_posts[pi + 1]
		var pa: Vector2 = a["pos"]
		var pb: Vector2 = b["pos"]
		var ta := (pa - from).dot(dir)
		var tb := (pb - from).dot(dir)
		if portal_interval.x >= -1.0 and ta < portal_interval.y and tb > portal_interval.x:
			continue
		var length := pa.distance_to(pb) + minf(float(a["size"].x), float(b["size"].x))
		var centre2 := (pa + pb) * 0.5
		var lintel_size := Vector3(length, lintel_h, thick)
		var lintel_xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(centre2.x, lintel_y, centre2.y))
		host("colonnade_%d_%d" % [selected_room, selected_wall], level)
		component_box("colonnade_lintel", lintel_size, lintel_xf, SURF_TRIM)
		var lintel_mass := _oriented_box_aabb(centre2, lintel_y, length, lintel_h, thick, yaw)
		_log_mass("colonnade_lintel_%d_%d_%d" % [selected_room, selected_wall, pi],
			lintel_mass, lintel_mass.position.y)
	host_end()
	if not portal.is_empty():
		var p0: Vector2 = from + dir * portal_interval.x
		var p1: Vector2 = from + dir * portal_interval.y
		var openings := _openings_on(p0, p1, outward, level, thick)
		_wall_run(p0, p1, thick, height, openings, SURF_WALL, y0)
		_log_mass("wall_%s_portal" % String(run["side"]),
			_run_aabb(p0, p1, thick, height, y0), y0)
	return true


func _oriented_box_aabb(centre: Vector2, y: float, along: float,
		height: float, across: float, yaw: float) -> AABB:
	var sx := absf(cos(yaw)) * along + absf(sin(yaw)) * across
	var sz := absf(sin(yaw)) * along + absf(cos(yaw)) * across
	return AABB(Vector3(centre.x - sx * 0.5, y - height * 0.5,
		centre.y - sz * 0.5), Vector3(sx, height, sz))


# ------------------------------------------------------------------ jetty

func _build_jetty() -> void:
	if not spec.jetty or _storeys() <= 1 or plan.has_court() or HouseGeometry.is_shaped(plan) or spec.has_method("room_program"):
		return
	tag("jetty")
	host("jetty", 1)
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var j_depth: float = spec.jetty_depth
	var bressummer_y: float = spec.height
	var beam_h := 0.22
	var beam_w := 0.20

	# 1. Bressummer beam running along the front wall at y = spec.height
	var bw_len: float = r.size.x + 0.35
	component_box("jetty_bressummer", Vector3(bw_len, beam_h, beam_w),
		Transform3D(Basis(), Vector3(0.0, bressummer_y - beam_h / 2.0, r.position.y - j_depth + beam_w / 2.0)), SURF_TRIM)

	# 2. Exposed floor joist ends projecting under the bressummer
	var joist_spacing := 0.65
	var joist_count := maxi(int(r.size.x / joist_spacing), 3)
	for i in range(joist_count + 1):
		var jx: float = r.position.x + float(i) * (r.size.x / float(joist_count))
		component_box("jetty_joist", Vector3(0.12, 0.14, j_depth + 0.10),
			Transform3D(Basis(), Vector3(jx, bressummer_y - beam_h - 0.07, r.position.y - j_depth / 2.0)), SURF_TRIM)

	# 3. Carved knee brackets / corner corbels supporting the bressummer
	for px in [r.position.x + 0.35, r.end.x - 0.35]:
		var bracket_span: float = minf(j_depth * 1.2, 0.35)
		var bracket_lift: float = bracket_span * 1.4
		var span_len: float = sqrt(bracket_span * bracket_span + bracket_lift * bracket_lift)
		var tilt: float = atan2(bracket_lift, bracket_span)
		var xf := Transform3D(Basis(), Vector3(px, bressummer_y - beam_h - bracket_lift / 2.0, r.position.y - j_depth / 2.0))
		xf = xf * Transform3D(Basis(Vector3(1, 0, 0), -tilt), Vector3.ZERO)
		component_box("jetty_bracket", Vector3(0.15, span_len, 0.12), xf, SURF_TRIM)
	host_end()


func _build_partitions() -> void:
	tag("partition")
	var h: float = spec.height
	for level in _levels():
		var y0 := float(level) * h
		var seen := {}
		for i in range(plan.room_count()):
			if _room_storey(plan.rooms[i]) != level and _has_storey_metadata(plan.rooms[i]):
				continue
			for j in range(i + 1, plan.room_count()):
				if _room_storey(plan.rooms[j]) != level and _has_storey_metadata(plan.rooms[j]):
					continue
				var edge: Array = HousePlanOpenings.shared_edge(plan, i, j)
				if edge.is_empty():
					continue
				var normal: Vector2 = edge[0]
				var line: float = edge[1]
				var t0: float = edge[2]
				var t1: float = edge[3]
				# one partition per shared edge, however many rooms lie along it
				var key: String = "%.2f|%.2f|%.2f|%.2f" % [normal.x, line, t0, t1]
				if seen.has(key):
					continue
				seen[key] = true
				var from: Vector2
				var to: Vector2
				if normal.x > 0.5:
					from = Vector2(line, t0)
					to = Vector2(line, t1)
				else:
					from = Vector2(t0, line)
					to = Vector2(t1, line)
				var openings: Array[Dictionary] = []
				for d in plan.doors:
					if _opening_storey(d) != level and _has_storey_metadata(d):
						continue
					if d["exterior"]:
						continue
					if not _on_run(from, to, normal, d["pos"], d["normal"]):
						continue
					var interval := _door_interval(d)
					var is_secret := bool(d.get("secret", false))
					openings.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
						"bottom": interval[0], "top": interval[1], "kind": "secret" if is_secret else "door",
						"normal": normal})
				_wall_run(from, to, HouseGeometry.INNER_WALL_T, h, openings, SURF_WALL, y0)
				var suffix := "" if _levels().size() == 1 else "_%d" % level
				_log_mass("partition_%d_%d%s" % [i, j, suffix],
					_run_aabb(from, to, HouseGeometry.INNER_WALL_T, h, y0), y0)


## The passage remains a real opening to navigation. On its public side, a
## full-height fitted panel makes it read as an unbroken wall or bookcase.
func _build_secret_door_panels() -> void:
	for di in range(plan.doors.size()):
		var door: Dictionary = plan.doors[di]
		if not bool(door.get("secret", false)) or bool(door.get("exterior", false)):
			continue
		var level := _opening_storey(door)
		var y0 := float(level) * spec.height
		var n := Vector2(door.get("normal", Vector2.RIGHT)).normalized()
		var tangent := Vector2(n.y, -n.x)
		var yaw := atan2(-tangent.y, tangent.x)
		var position := Vector2(door["pos"]) - n * (HouseGeometry.INNER_WALL_T * 0.5 + 0.05)
		var width := float(door["width"]) + 0.10
		var height := minf(float(door.get("head", HouseGeometry.DOOR_H)), spec.height - 0.05)
		var xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(position.x, y0 + height * 0.5, position.y))
		tag("secret_bookcase_panel")
		host("secret_door_%d" % di, level)
		component_box("secret_bookcase_panel", Vector3(width, height, 0.10), xf, SURF_TRIM)
		# Two face rails and upright stiles make the fitted slab read as joinery,
		# not as a missing piece of wall. All are emitted and logged components.
		for rail_y in [0.28, height - 0.25]:
			var rail_pos: Vector2 = position - n * 0.06
			var rail_xf := Transform3D(Basis(Vector3.UP, yaw),
				Vector3(rail_pos.x, y0 + rail_y, rail_pos.y))
			component_box("secret_bookcase_rail", Vector3(width - 0.12, 0.07, 0.035), rail_xf, SURF_TRIM)
		for side in [-1.0, 1.0]:
			var stile_pos: Vector2 = position - n * 0.06 \
				+ tangent * float(side) * (width * 0.38)
			var stile_xf := Transform3D(Basis(Vector3.UP, yaw),
				Vector3(stile_pos.x, y0 + height * 0.5, stile_pos.y))
			component_box("secret_bookcase_stile", Vector3(0.07, height - 0.12, 0.035), stile_xf, SURF_TRIM)


## A court edge is an outside wall of its range, even though it is not one of
## the four site edges.  Emit it explicitly so court doors/windows are real
## cuts in the shell rather than plan-only annotations (WLD-001/GEO-003).
func _build_court_walls() -> void:
	var h: float = spec.height
	for level in _levels():
		for ci in range(plan.courts.size()):
			if HousePlan.record_storey(plan.courts[ci]) > level:
				continue
			var court := Rect2(plan.courts[ci]["rect"])
			var rows := [
				{"from": Vector2(court.position.x, court.position.y), "to": Vector2(court.end.x, court.position.y), "normal": Vector2(0, 1), "role": &"fauces"},
				{"from": Vector2(court.position.x, court.end.y), "to": Vector2(court.position.x, court.position.y), "normal": Vector2(1, 0), "role": &"atrium"},
				{"from": Vector2(court.end.x, court.position.y), "to": Vector2(court.end.x, court.end.y), "normal": Vector2(-1, 0), "role": &"tablinum"},
				{"from": Vector2(court.end.x, court.end.y), "to": Vector2(court.position.x, court.end.y), "normal": Vector2(0, -1), "role": &"peristyle"},
			]
			for row in rows:
				var from: Vector2 = row["from"]
				var to: Vector2 = row["to"]
				var normal: Vector2 = row["normal"]
				var thick := HouseGeometry.wall_thickness(spec)
				var openings := _openings_on(from, to, normal, level, thick)
				_wall_run(from, to, thick, h, openings, SURF_WALL,
					float(level) * h)
				_log_mass("court_wall_%d_%d" % [ci, rows.find(row)],
					_run_aabb(from, to, thick, h, float(level) * h), float(level) * h)
		if level == 0 and plan.blind_entry:
			var screen := Rect2(plan.world_meta.get("blind_screen", Rect2()))
			if screen.has_area():
				var screen_from := Vector2(screen.position.x, screen.get_center().y)
				var screen_to := Vector2(screen.end.x, screen.get_center().y)
				var screen_h: float = minf(h * 0.75, 2.0)
				_wall_run(screen_from, screen_to, HouseGeometry.INNER_WALL_T,
					screen_h, [], SURF_WALL, 0.0, false)
				_log_mass("blind_screen", AABB(Vector3(screen.position.x, 0.0,
					screen.position.y), Vector3(screen.size.x, screen_h,
					screen.size.y)), 0.0)


## Every door and window cut into one exterior wall run, as distances along it.
## Shared by the wall builder and the timber frame, so a stud can never be
## planted across a window the wall knows about.
func _openings_on(from: Vector2, to: Vector2, normal: Vector2, level := 0,
		thickness := -1.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in plan.doors:
		if _opening_storey(d) != level and _has_storey_metadata(d):
			continue
		if not d["exterior"] and not _is_court_opening(d):
			continue
		if not _on_run(from, to, normal, d["pos"], d["normal"], thickness):
			continue
		var interval := _door_interval(d)
		if interval[1] <= interval[0] or interval[0] >= spec.height or interval[1] <= 0.0:
			continue
		out.append({"t": _along(from, to, d["pos"]), "w": float(d["width"]),
			"bottom": maxf(interval[0], 0.0), "top": minf(interval[1], spec.height), "kind": "door",
			"normal": normal})
	for w in plan.windows:
		if _opening_storey(w) != level and _has_storey_metadata(w):
			continue
		if not _on_run(from, to, normal, w["pos"], w["normal"], thickness):
			continue
		out.append({"t": _along(from, to, w["pos"]), "w": float(w["width"]),
			"bottom": float(w["sill"]), "top": float(w["head"]),
			"kind": "hatch" if w.get("hatch", false) else "window",
			"normal": normal})
	return out


func _is_court_opening(opening: Dictionary) -> bool:
	var pos: Vector2 = opening["pos"]
	var n: Vector2 = opening["normal"]
	for court in plan.courts:
		if Poly.contains_point(Poly.from_rect(Rect2(court["rect"])),
				pos + n * 0.4, 0.02):
			return true
	return false


## Door vertical interval within its storey.  The legacy path is deliberately
## bit-for-bit equivalent: only records that author sill/head opt into a
## raised or shortened aperture.
func _door_interval(door: Dictionary) -> Array:
	var authored := door.has("sill") or door.has("head")
	var bottom := float(door.get("sill", 0.0))
	var top := float(door.get("head", HouseGeometry.DOOR_H))
	return [bottom, top, authored]


## One wall, with its openings cut out of it.
##
## Piers between the openings, a panel over each head, a panel under each sill.
## The openings arrive as distances along the run, which is the only way to
## place a door on a wall that might run along either axis without writing the
## whole thing twice.
func _wall_run(from: Vector2, to: Vector2, thick: float, height: float,
		openings: Array[Dictionary], surf: int, y_offset := 0.0, decorate := true,
		corner_ext := 0.0) -> void:
	var seg: Vector2 = to - from
	var run: float = seg.length()
	if run < 0.01:
		return
	var dir: Vector2 = seg / run
	var yaw: float = atan2(-dir.y, dir.x)
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))

	# `corner_ext` lengthens (or, negative, shortens) both ends: see _corner_ext.
	# The openings are still measured from `from`.
	var cursor := -corner_ext
	for op in openings:
		var t: float = float(op["t"])
		var w: float = float(op["w"])
		var lo: float = t - w / 2.0
		var hi: float = t + w / 2.0
		if lo > cursor + 0.01:
			_wall_piece(from, dir, yaw, cursor, lo, 0.0, height, thick, surf, y_offset)
		var bottom: float = float(op["bottom"])
		var top: float = float(op["top"])
		if bottom > 0.01:
			_wall_piece(from, dir, yaw, lo, hi, 0.0, bottom, thick, surf, y_offset)
		if top < height - 0.01:
			_wall_piece(from, dir, yaw, lo, hi, top, height, thick, surf, y_offset)
		if decorate and String(op.get("kind", "")) != "secret":
			_opening_trim(from, dir, yaw, t, w, bottom, top, thick, op, y_offset)
		cursor = maxf(cursor, hi)
	if cursor < run + corner_ext - 0.01:
		_wall_piece(from, dir, yaw, cursor, run + corner_ext, 0.0, height, thick, surf, y_offset)


## How far a rectangular shell's run is carried past its centre-line ends.
##
## The four runs go corner to corner along the wall CENTRE lines, so a box laid
## on each stops half a wall short of the outside corner and every corner was
## missing a square column of masonry: a notch the walk-through saw as a pale
## stripe down the corner, with the plinth's end face fighting the wall's
## inside it (WALK-QA, 6 Oct, shop pin 2; hotel pin 4). Front and back now run
## through the corner, and the two sides stop at their inner faces, so the
## corner is solid and no two outside faces share a plane. A shaped shell's
## runs meet at their own angles and are left alone.
static func _corner_ext(run: Dictionary, thick: float) -> float:
	match StringName(run.get("side", &"")):
		&"front", &"back":
			return thick / 2.0
		&"left", &"right":
			return -thick / 2.0
	return 0.0


func _wall_piece(from: Vector2, dir: Vector2, yaw: float, t0: float, t1: float,
		y0: float, y1: float, thick: float, surf: int, y_offset := 0.0) -> void:
	var length: float = t1 - t0
	if length <= 0.01 or y1 - y0 <= 0.01:
		return
	var mid: Vector2 = from + dir * ((t0 + t1) / 2.0)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y_offset + (y0 + y1) / 2.0, mid.y))
	_kit.oriented_box(Vector3(length, y1 - y0, thick), xf, surf)


## The frame round an opening, and the log entry the QA checks read.
##
## `facing` is logged for the normals suite, which proves every opening looks
## OUT through its wall rather than along it -- the same check the churches and
## castles get, and the reason a window cut into the wrong face is caught.
func _opening_trim(from: Vector2, dir: Vector2, yaw: float, t: float, w: float,
		bottom: float, top: float, thick: float, op: Dictionary, y_offset := 0.0) -> void:
	var mid: Vector2 = from + dir * t
	var normal: Vector2 = op["normal"]
	var face: float = atan2(normal.x, normal.y)
	_log_part("window", Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y),
		Vector3(w, top - bottom, 0.0), face, Vector3(normal.x, 0.0, normal.y))
	# Keep the legacy log category for house consumers, while allowing family
	# composition to distinguish an emitted door from an emitted window.
	part_log[part_log.size() - 1]["opening_kind"] = String(op["kind"])
	# The surround belongs to THIS opening. HOUSE-EXT-008 and -010 both need to
	# ask what trim sits beside a given door; a flat list of trim boxes cannot
	# answer that, and reconstructing the answer from the spec would agree with
	# a sill that was never split.
	var outer_host := _comp_host
	var outer_storey := _comp_storey
	host("%s_%d" % [String(op["kind"]), _opening_seq], int(y_offset / maxf(spec.height, 0.01) + 0.5))
	_opening_seq += 1
	var jamb := 0.09
	# The frame stands TRIM_TUCK proud into the opening, so its inner faces
	# cover the wall's reveal and soffit instead of lying in their planes.
	var tuck := TRIM_TUCK
	for side in [-1.0, 1.0]:
		var p: Vector2 = from + dir * (t + side * (w / 2.0 + jamb / 2.0 - tuck))
		var xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(p.x, y_offset + (bottom + top) / 2.0, p.y))
		component_box("opening_jamb", Vector3(jamb, top - bottom, thick + 0.04), xf, SURF_TRIM)
	var head_xf := Transform3D(Basis(Vector3.UP, yaw),
		Vector3(mid.x, y_offset + top + jamb / 2.0 - tuck, mid.y))
	component_box("opening_head", Vector3(w + jamb * 2.0, jamb, thick + 0.04), head_xf, SURF_TRIM)
	if bottom > 0.01:
		var sill_xf := Transform3D(Basis(Vector3.UP, yaw),
			Vector3(mid.x, y_offset + bottom - jamb / 2.0 + tuck, mid.y))
		component_box("opening_sill", Vector3(w + jamb * 2.0, jamb, thick + 0.12), sill_xf, SURF_TRIM)
		if op["kind"] == "window":
			# Inset dark lattice glazing panel
			var pane_xf := Transform3D(Basis(Vector3.UP, yaw),
				Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y))
			_glazing_box("opening_glazing", Vector3(w, top - bottom, 0.04), pane_xf)

			# Vertical timber mullions for wide windows (2-light / 3-light)
			if spec.window_mullions and w >= 0.8:
				if w >= 1.35:
					for mside in [-1.0, 1.0]:
						var mp: Vector2 = from + dir * (t + mside * (w / 3.0))
						var mxf := Transform3D(Basis(Vector3.UP, yaw),
							Vector3(mp.x, y_offset + (bottom + top) / 2.0, mp.y))
						component_box("opening_mullion", Vector3(HouseGeometry.MULLION_W, top - bottom, thick + 0.06), mxf, SURF_TRIM)
				else:
					var mxf := Transform3D(Basis(Vector3.UP, yaw),
						Vector3(mid.x, y_offset + (bottom + top) / 2.0, mid.y))
					component_box("opening_mullion", Vector3(HouseGeometry.MULLION_W, top - bottom, thick + 0.06), mxf, SURF_TRIM)

			# Dripstone hood moulding over window head
			if spec.window_hoods:
				# A dripstone projects OUTSIDE. A symmetric box also put a
				# second hood indoors, through the shoulder space of wall stairs.
				# Recess the inside face into the wall to avoid a coplanar skin;
				# keep the visible outside edge at exactly the same projection.
				var hood_mid := mid + normal * (HouseGeometry.HOOD_PROJECTION + TRIM_TUCK) * 0.5
				var hood_xf := Transform3D(Basis(Vector3.UP, yaw),
					Vector3(hood_mid.x, y_offset + top + jamb + 0.05, hood_mid.y))
				component_box("opening_hood", Vector3(w + jamb * 2.4, 0.07, thick + HouseGeometry.HOOD_PROJECTION - TRIM_TUCK),
					hood_xf, SURF_TRIM)

			# Board-and-batten shutters with strap hinges
			if spec.window_shutters:
				# On a framed wall the shutters hang on the timbers, so they
				# stand in front of the studs. At 3 cm off the plaster they
				# sat inside the frame's own depth and the studs ran through
				# them (WALK-QA, 6 Oct, Wolfmarch Green house_9 pin 4).
				var off: float = thick / 2.0 + 0.03
				var framed_level := int(y_offset / maxf(spec.height, 0.01) + 0.5)
				if spec.timber_frame and spec.material != &"stone" \
						and not (spec.stone_ground_floor and framed_level == 0):
					off = _proud(HouseGeometry.BEAM_D) + HouseGeometry.BEAM_D / 2.0 + 0.03
				for side2 in [-1.0, 1.0]:
					var sp: Vector2 = from + dir * (t + side2 * (w * 0.75)) + normal * off
					var sxf := Transform3D(Basis(Vector3.UP, yaw),
						Vector3(sp.x, y_offset + (bottom + top) / 2.0, sp.y))
					component_box("opening_shutter", Vector3(w * 0.45, top - bottom, 0.05), sxf, SURF_TRIM)
					# Horizontal strap hinges, a hair proud of the leaf on
					# whichever axis the wall faces
					var hp: Vector2 = sp + normal * 0.01
					for hy in [0.25, 0.75]:
						var hxf := Transform3D(Basis(Vector3.UP, yaw),
							Vector3(hp.x, y_offset + bottom + (top - bottom) * hy, hp.y))
						component_box("opening_hinge", Vector3(w * 0.40, 0.04, 0.07), hxf, SURF_TRIM)
	host(outer_host, outer_storey)


## Is an opening on this wall run: same line, and between its ends?
func _on_run(from: Vector2, to: Vector2, normal: Vector2, pos: Vector2,
		op_normal: Vector2, thickness := -1.0) -> bool:
	if absf(absf(normal.x) - absf(op_normal.x)) > 0.01:
		return false
	var seg: Vector2 = to - from
	var run: float = seg.length()
	if run < 0.01:
		return false
	var dir: Vector2 = seg / run
	var rel: Vector2 = pos - from
	var t: float = rel.dot(dir)
	var off: float = absf(rel.dot(Vector2(dir.y, -dir.x)))
	# an exterior opening is recorded on the INNER face of its wall, so allow
	# half a wall's slack across the run
	var slack := HouseGeometry.wall_thickness(spec) if thickness <= 0.0 else thickness
	return off <= slack / 2.0 + 0.02 and t >= -0.01 and t <= run + 0.01


static func _along(from: Vector2, to: Vector2, pos: Vector2) -> float:
	var seg: Vector2 = to - from
	return (pos - from).dot(seg / maxf(seg.length(), 0.01))


static func _run_aabb(from: Vector2, to: Vector2, thick: float, height: float,
		y_offset := 0.0) -> AABB:
	var a := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * (thick / 2.0)
	var b := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * (thick / 2.0)
	return AABB(Vector3(a.x, y_offset, a.y), Vector3(b.x - a.x, height, b.y - a.y))


## Plans made before the upper-floor schema default all records to ground level.
## Storeys above the ground; the roof and the chimney are measured off them.
## The floor of a storey with a yard in it: four bands round the hole, so the
## court itself is left as ground.
func _emit_floor_round_courts(r: Rect2, y0: float, t: float, level: int,
		holes: Array[int]) -> void:
	var court: Rect2 = plan.courts[holes[0]]["rect"]
	for band in [
			Rect2(r.position.x, r.position.y, r.size.x, court.position.y - r.position.y),
			Rect2(r.position.x, court.end.y, r.size.x, r.end.y - court.end.y),
			Rect2(r.position.x, court.position.y, court.position.x - r.position.x, court.size.y),
			Rect2(court.end.x, court.position.y, r.end.x - court.end.x, court.size.y)]:
		if band.size.x < 0.05 or band.size.y < 0.05:
			continue
		box(Vector3(band.size.x, t, band.size.y),
			Vector3(band.get_center().x, y0 + t / 2.0, band.get_center().y),
			SURF_FLOOR)
	_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level,
		AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y)), y0)
	# and the yard itself, as paving a hand's breadth down
	if level == 0:
		var pav := 0.08
		box(Vector3(court.size.x, pav, court.size.y),
			Vector3(court.get_center().x, y0 - pav / 2.0, court.get_center().y),
			SURF_FLOOR)


## The shaped room on `level`, or -1 when that storey is rectangular.
func _shaped_room(level: int) -> int:
	for i in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[i]) == level and plan.is_polygonal(i):
			return i
	return -1


## A plan polygon lifted to a height, for the slab emitters.
static func _lift(poly: PackedVector2Array, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in poly:
		out.append(Vector3(p.x, y, p.y))
	return out


func _storeys() -> int:
	var raw = spec.get("storeys")
	return maxi(1, int(raw)) if raw != null else 1


## Storeys dug below the ground (INT-016), 0 for a house without a cellar.
func _lowest() -> int:
	var raw = spec.get("cellars")
	return -maxi(0, int(raw)) if raw != null else 0


## Every level the shell is built on, lowest first.
func _levels() -> Array[int]:
	var out: Array[int] = []
	for level in range(_lowest(), _storeys()):
		out.append(level)
	return out


static func _has_storey_metadata(record: Dictionary) -> bool:
	return record.has("storey") or record.has("level")


static func _room_storey(record: Dictionary) -> int:
	return int(record.get("storey", record.get("level", 0)))


static func _opening_storey(record: Dictionary) -> int:
	return int(record.get("storey", record.get("level", 0)))


# ---------------------------------------------------------------- timber

## Exposed beams on the outside walls: the half-timbering that makes a
## plastered box read as medieval.
##
## Laid out the way a carpenter would lay it out rather than as a pattern
## stamped on the wall -- sill along the bottom, wall plate along the top,
## heavier posts at the corners, studs between them at the style's own
## spacing, a mid rail at sill height, and a brace across each corner. The
## studs read the same opening list the wall itself was built from, so one can
## never end up planted across a window.
func _build_timber_frame() -> void:
	for level in range(_storeys()):
		_build_timber_frame_level(level)


func _build_timber_frame_level(level := 0) -> void:
	if not spec.timber_frame:
		return
	if spec.stone_ground_floor and level == 0:
		_build_stone_quoins(level)
		return
	tag("timber")
	host("frame_%d" % level, level)
	var h: float = spec.height
	var y0 := float(level) * h
	var plinth_offset := (minf(spec.plinth_height, HouseGeometry.WINDOW_SILL - 0.18) if (level == 0 and not spec.stone_ground_floor and spec.plinth_height > 0.05) else 0.0)
	var y_sill := plinth_offset

	for run in HouseGeometry.shell_runs(plan, level):
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var normal: Vector2 = run["normal"]
		var seg: Vector2 = to - from
		var length: float = seg.length()
		if length < 0.5:
			continue
		var dir: Vector2 = seg / length
		var yaw: float = atan2(-dir.y, dir.x)
		var openings: Array[Dictionary] = _openings_on(from, to, normal, level)

		# sill and wall plate, the full length of the wall
		_rail_between(from, dir, yaw, normal, length, openings,
			y_sill, y_sill + HouseGeometry.SILL_BEAM_H, y0)
		_beam(from, dir, yaw, normal, length / 2.0, length,
			h - HouseGeometry.PLATE_H, h, 0.0, y0)
		if spec.frame_rail:
			var rail_y: float = HouseGeometry.WINDOW_SILL - HouseGeometry.RAIL_H
			_rail_between(from, dir, yaw, normal, length, openings,
				rail_y, rail_y + HouseGeometry.RAIL_H, y0)

		# corner posts, then studs between them
		var post: float = HouseGeometry.POST_W
		for t in [post / 2.0, length - post / 2.0]:
			_beam(from, dir, yaw, normal, t, post, y_sill, h, post * 0.55, y0)
		var pitch: float = spec.stud_pitch
		for t2 in _facade_studs(length, openings, pitch):
			_beam(from, dir, yaw, normal, t2, HouseGeometry.BEAM_W,
				y_sill + HouseGeometry.SILL_BEAM_H, h - HouseGeometry.PLATE_H, 0.0, y0)

		# Bracing patterns
		match spec.framing_pattern:
			&"saltire":
				_saltire_braces(from, dir, yaw, normal, length, h, openings, y0, y_sill)
			&"arch_brace":
				_arch_braces(from, dir, yaw, normal, length, h, openings, y0, y_sill)
			_:
				if spec.frame_braces:
					_corner_braces(from, dir, yaw, normal, length, h, openings, y0)
	host_end()


## Opening jambs establish the bays; extra studs subdivide solid wall between
## those anchors. This keeps the entrance/window rhythm legible at any width.
static func _facade_studs(length: float, openings: Array[Dictionary], pitch: float) -> Array[float]:
	var post := HouseGeometry.POST_W
	var anchors: Array[float] = [post, length - post]
	for opening in openings:
		var half: float = float(opening["w"]) * 0.5 + HouseGeometry.STUD_CLEAR + HouseGeometry.BEAM_W * 0.5
		for at in [float(opening["t"]) - half, float(opening["t"]) + half]:
			if at > post * 2.0 and at < length - post * 2.0 and not _blocked_by_opening(openings, at, HouseGeometry.BEAM_W):
				anchors.append(at)
	anchors.sort()
	var out: Array[float] = []
	for i in range(anchors.size() - 1):
		var a := anchors[i]
		var b := anchors[i + 1]
		if i > 0 and (out.is_empty() or a - out.back() > HouseGeometry.BEAM_W * 1.8):
			out.append(a)
		var bays := maxi(int(ceil((b - a) / maxf(pitch, 0.3))), 1)
		for j in range(1, bays):
			var at := lerpf(a, b, float(j) / bays)
			if not _blocked_by_opening(openings, at, HouseGeometry.BEAM_W) and (out.is_empty() or at - out.back() > HouseGeometry.BEAM_W * 1.8):
				out.append(at)
	return out


## One framed quiet bay per surfaced room, only where the spec actually drew
## exposed timber. Its interval comes from the plan's opening-aware quiet host;
## walls with activity supports, doors or windows are not covered by an
## ornamental grid.
func _build_interior_timber_bays() -> void:
	if not spec.timber_frame or spec.material == &"stone":
		return
	for surface in plan.wall_hosts:
		if String(surface.get("role", "")) != "timber_bay":
			continue
		var room := int(surface.get("room", -1))
		var wall_index := int(surface.get("wall", -1))
		var storey := int(surface.get("storey", 0))
		if room < 0 or room >= plan.room_count():
			continue
		var walls := HouseGeometry.room_walls(plan, room)
		if wall_index < 0 or wall_index >= walls.size():
			continue
		var from: Vector2 = surface.get("from", Vector2.ZERO)
		var to: Vector2 = surface.get("to", Vector2.ZERO)
		var span := from.distance_to(to)
		if span < 1.5:
			continue
		var wall: Dictionary = walls[wall_index]
		var dir := (to - from).normalized()
		var normal: Vector2 = wall["normal"]
		var yaw := atan2(-dir.y, dir.x)
		var bay_width := span - 0.08
		if bay_width < 1.5:
			continue
		var inset := (span - bay_width) * 0.5
		var depth := HouseGeometry.BEAM_D
		var face_offset := normal * (depth * 0.5 - 0.004)
		var start := from + dir * inset + face_offset
		var finish := from + dir * (inset + bay_width) + face_offset
		var floor_y := float(storey) * spec.height + HouseGeometry.FLOOR_T
		# The top edge meets the actual ceiling underside. A short gap turns a
		# structural post into a freestanding picture frame.
		var top_y := float(storey + 1) * spec.height
		var post_width := HouseGeometry.POST_W
		var host_id := "interior_frame_%d_%d" % [room, wall_index]
		var bay_axis := dir
		var bay_lo := from.dot(bay_axis) + inset + post_width * 0.5
		var bay_hi := to.dot(bay_axis) - inset - post_width * 0.5
		var matched_shell_run := false
		var post_positions: Array[Vector2] = []
		# Shell runs sit on wall centre lines and point outward. Translate them to
		# the room's inner face before matching the wall and its real stud stations.
		for run in HouseGeometry.shell_runs(plan, storey):
			var run_from: Vector2 = run["from"]
			var run_to: Vector2 = run["to"]
			var run_normal: Vector2 = run["normal"]
			if run_normal.dot(normal) > -0.99:
				continue
			var half_wall := float(run.get("thickness", HouseGeometry.wall_thickness(spec))) * 0.5
			var inner_from := run_from + normal * half_wall
			var inner_to := run_to + normal * half_wall
			var run_dir := (inner_to - inner_from).normalized()
			if absf((inner_from - Vector2(wall["from"])).cross(dir)) > 0.025 \
					or absf((inner_to - Vector2(wall["from"])).cross(dir)) > 0.025 \
					or absf(run_dir.dot(dir)) < 0.99:
				continue
			matched_shell_run = true
			var run_length := inner_from.distance_to(inner_to)
			var openings := _openings_on(run_from, run_to, run_normal, storey)
			var true_stations: Array[float] = [post_width * 0.5,
				run_length - post_width * 0.5]
			true_stations.append_array(_facade_studs(run_length, openings, spec.stud_pitch))
			for station in true_stations:
				var station_pos := inner_from + run_dir * station + face_offset
				var station_along := station_pos.dot(bay_axis)
				if station_along >= bay_lo - 0.001 and station_along <= bay_hi + 0.001:
					post_positions.append(station_pos)
		if not matched_shell_run:
			# Partitions have no façade stations. Their end posts are inset so the
			# measured beam bodies remain within the clear host envelope.
			post_positions.append(start + dir * (post_width * 0.5))
			post_positions.append(finish - dir * (post_width * 0.5))
			var bay_count := maxi(1, ceili(bay_width / maxf(spec.stud_pitch, 0.3)))
			for station_index in range(1, bay_count):
				post_positions.append(start.lerp(finish, float(station_index) / bay_count))
		elif post_positions.is_empty():
			# The clear exterior span contains no corner, jamb, or true stud station.
			continue
		tag("interior_timber_bay")
		host(host_id, storey)
		post_positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.dot(bay_axis) < b.dot(bay_axis))
		var unique_post_positions: Array[Vector2] = []
		for pos in post_positions:
			if unique_post_positions.is_empty() \
					or pos.distance_to(unique_post_positions.back()) > post_width * 0.6:
				unique_post_positions.append(pos)
		for pos in unique_post_positions:
			component_box("interior_frame_post",
				Vector3(post_width, top_y - floor_y, depth),
				Transform3D(Basis(Vector3.UP, yaw),
					Vector3(pos.x, (floor_y + top_y) * 0.5, pos.y)), SURF_TRIM)
		for beam_y in [floor_y + post_width * 0.5, top_y - post_width * 0.5]:
			var centre := (start + finish) * 0.5
			component_box("interior_frame_rail", Vector3(bay_width, post_width, depth),
				Transform3D(Basis(Vector3.UP, yaw),
					Vector3(centre.x, beam_y, centre.y)), SURF_TRIM)
		host_end()


func _build_stone_quoins(level: int) -> void:
	tag("quoins")
	var h: float = spec.height
	var y0 := float(level) * h
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var corners := [
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.end.x, r.end.y),
	]
	var quoin_h := 0.38
	var courses := int(h / quoin_h)
	for c in corners:
		for i in range(courses):
			var qw := 0.42 if (i % 2 == 0) else 0.56
			var qd := 0.56 if (i % 2 == 0) else 0.42
			box(Vector3(qw, quoin_h - 0.04, qd),
				Vector3(c.x, y0 + float(i) * quoin_h + quoin_h / 2.0, c.y), SURF_FLOOR)


func _saltire_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset: float, y_sill: float) -> void:
	var post: float = HouseGeometry.POST_W
	var pitch: float = spec.stud_pitch
	var bays: int = maxi(int((length - post * 2.0) / pitch), 1)
	var bay_w: float = (length - post * 2.0) / float(bays)
	var bottom: float = y_sill + HouseGeometry.SILL_BEAM_H
	var top: float = h - HouseGeometry.PLATE_H
	var bay_h: float = top - bottom
	var brace_len: float = sqrt(bay_w * bay_w + bay_h * bay_h)
	var tilt: float = atan2(bay_h, bay_w)

	for i in range(bays):
		var t_center: float = post + float(i + 0.5) * bay_w
		if _blocked_by_opening(openings, t_center, bay_w * 0.75):
			continue
		for sign in [1.0, -1.0]:
			var p: Vector2 = from + dir * t_center + normal * _proud(HouseGeometry.BEAM_D)
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + (bottom + top) / 2.0, p.y))
			xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt * sign), Vector3.ZERO)
			component_box("timber_brace", Vector3(brace_len * 0.95,
				HouseGeometry.BEAM_W * 0.72, HouseGeometry.BEAM_D * 0.88), xf, SURF_TRIM)


func _arch_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset: float, y_sill: float) -> void:
	var run: float = _paired_brace_run(minf(HouseGeometry.BRACE_RUN * 1.1, length * 0.28),
		length, openings)
	var rise: float = run * 1.2
	if run <= 0.0 or rise > h - HouseGeometry.PLATE_H - y_sill:
		return
	for side in [1.0, -1.0]:
		var foot: float = HouseGeometry.POST_W + run if side > 0.0 else length - HouseGeometry.POST_W - run
		var mid_t: float = foot - side * run / 2.0
		var mid_y: float = h - HouseGeometry.PLATE_H - rise / 2.0
		var span: float = sqrt(run * run + rise * rise)
		var tilt: float = atan2(rise, run) * side
		var p: Vector2 = from + dir * mid_t + normal * _proud(HouseGeometry.BEAM_D)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + mid_y, p.y))
		xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt), Vector3.ZERO)
		component_box("timber_brace", Vector3(span, HouseGeometry.BEAM_W * 0.9,
			HouseGeometry.BEAM_D), xf, SURF_TRIM)


## A horizontal beam broken by the openings it runs into: it passes over a
## window head or under a sill where it can, and stops at a doorway.
func _rail_between(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, openings: Array[Dictionary], y0: float, y1: float,
		y_offset := 0.0) -> void:
	var cuts: Array = []
	for op in openings:
		if float(op["bottom"]) > y1 or float(op["top"]) < y0:
			continue          # the rail passes clear above or below it
		cuts.append([float(op["t"]) - float(op["w"]) / 2.0,
			float(op["t"]) + float(op["w"]) / 2.0])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cursor := 0.0
	for cut in cuts:
		var lo: float = float(cut[0])
		if lo > cursor + 0.1:
			_beam(from, dir, yaw, normal, (cursor + lo) / 2.0, lo - cursor,
				y0, y1, 0.0, y_offset)
		cursor = maxf(cursor, float(cut[1]))
	if cursor < length - 0.1:
		_beam(from, dir, yaw, normal, (cursor + length) / 2.0, length - cursor,
			y0, y1, 0.0, y_offset)


## The diagonals that stop a timber frame racking, one across each corner of
## the wall. Emitted as a tilted beam, which is what they are.
func _corner_braces(from: Vector2, dir: Vector2, yaw: float, normal: Vector2,
		length: float, h: float, openings: Array[Dictionary], y_offset := 0.0) -> void:
	var run: float = _paired_brace_run(minf(HouseGeometry.BRACE_RUN, length * 0.3),
		length, openings)
	var rise: float = run * 1.15
	if run <= 0.0 or rise > h - HouseGeometry.PLATE_H - HouseGeometry.SILL_BEAM_H:
		return
	for side in [1.0, -1.0]:
		var foot: float = HouseGeometry.POST_W + run if side > 0.0 \
			else length - HouseGeometry.POST_W - run
		var mid_t: float = foot - side * run / 2.0
		var mid_y: float = h - HouseGeometry.PLATE_H - rise / 2.0
		var span: float = sqrt(run * run + rise * rise)
		var tilt: float = atan2(rise, run) * side
		var p: Vector2 = from + dir * mid_t + normal * _proud(HouseGeometry.BEAM_D)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + mid_y, p.y))
		xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt), Vector3.ZERO)
		component_box("timber_brace", Vector3(span, HouseGeometry.BEAM_W * 0.9,
			HouseGeometry.BEAM_D), xf, SURF_TRIM)


## The run both corner braces of a wall can share: the longest, from `run`
## down to MIN_BRACE_RUN, at which NEITHER foot lands on an opening; 0.0 when
## there is none. The braces are a pair. Testing each corner alone dropped the
## one beside a window and kept the other, and a lone diagonal reads as a
## mistake (WALK-QA, 6 Oct, shop pin 1).
const MIN_BRACE_RUN := 0.45


static func _paired_brace_run(run: float, length: float,
		openings: Array[Dictionary]) -> float:
	var r := run
	while r >= MIN_BRACE_RUN - 0.001:
		var near_foot: float = HouseGeometry.POST_W + r
		var far_foot: float = length - HouseGeometry.POST_W - r
		if not _blocked_by_opening(openings, near_foot, r) \
				and not _blocked_by_opening(openings, far_foot, r):
			return r
		r -= 0.05
	return 0.0


## Is a beam of this width going to land on a door or a window?
static func _blocked_by_opening(openings: Array[Dictionary], t: float,
		width: float) -> bool:
	for op in openings:
		var half: float = float(op["w"]) / 2.0 + width / 2.0 + HouseGeometry.STUD_CLEAR
		if absf(t - float(op["t"])) < half:
			return true
	return false


## One beam, standing proud of the wall face it is fixed to.
func _beam(from: Vector2, dir: Vector2, yaw: float, normal: Vector2, t: float,
		length: float, y0: float, y1: float, depth := 0.0, y_offset := 0.0,
		role := "timber") -> void:
	if length <= 0.02 or y1 - y0 <= 0.02:
		return
	var d: float = depth if depth > 0.0 else HouseGeometry.BEAM_D
	var p: Vector2 = from + dir * t + normal * _proud(d)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_offset + (y0 + y1) / 2.0, p.y))
	component_box(role, Vector3(length, y1 - y0, d), xf, SURF_TRIM)


## How far out from the wall centre-line a beam of this depth sits: against the
## plaster, with a hair of overlap so no seam shows.
func _proud(depth: float) -> float:
	return HouseGeometry.wall_thickness(spec) / 2.0 + depth / 2.0 - 0.015


# --------------------------------------------------------------- rich trim

## The ornament that separates a rich dwelling from a tall ordinary one
## (HOUSE-RICH): the crown at the wall head, a belt band at each storey line,
## a pediment over every upper window, and an obelisk on the ridge.
##
## Every piece is driven by its own `HouseSpec` field rather than by a test for
## the style's name, so a style row without the four keys reaches all of this
## and emits nothing at all. That is what keeps the five existing house styles
## byte-identical, and it means the vocabulary is reachable from a chance
## table rather than hard-wired to one word.
func _build_witch_interior_finish() -> void:
	if plan == null or spec == null or plan.spec != spec or spec.style != &"witch_hut" \
			or spec.get_script() != BASE_HOUSE_SPEC or spec.trade != &"none" \
			or plan.world_family != &"" or spec.has_method("room_program") \
			or spec.has_method("custom_room_rects"):
		return
	for room in plan.room_count():
		var kind := StringName(plan.kind_of(room))
		var witch_workshop := kind == &"workshop"
		var witch_shared_hall := kind == &"hall"
		if not witch_workshop and not witch_shared_hall:
			continue
		var level := plan.storey_of_room(room)
		var floor_y := HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
		var panel_h := 0.90
		var panel_depth := 0.045
		var walls := HouseGeometry.room_walls(plan, room)
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			var from: Vector2 = wall["from"]
			var to: Vector2 = wall["to"]
			var normal: Vector2 = wall["normal"]
			var horizontal := absf(normal.y) > 0.5
			var line := from.y if horizontal else from.x
			var lo := minf(from.x, to.x) if horizontal else minf(from.y, to.y)
			var hi := maxf(from.x, to.x) if horizontal else maxf(from.y, to.y)
			var clear_spans: Array[Vector2] = HousePlanFeatures.clear_wall_spans(plan, room, wi, 0.07)
			var candidate_spans: Array[Dictionary] = []
			for host_variant in plan.wall_hosts:
				var finish_host: Dictionary = host_variant
				if int(finish_host.get("room", -1)) != room or int(finish_host.get("wall", -1)) != wi \
						 or String(finish_host.get("role", "")) != "room_finish" \
						 or String(finish_host.get("finish_intent", "")) != "cleanable_working_room":
					continue
				if String(finish_host.get("room_kind", "")) != String(kind):
					continue
				if witch_shared_hall and not _witch_hall_finish_is_shared_work_room(room):
					continue
				var host_span: Vector2 = finish_host.get("span", Vector2.ZERO)
				for clear_span in clear_spans:
					var overlap := Vector2(maxf(host_span.x, clear_span.x), minf(host_span.y, clear_span.y))
					if overlap.y > overlap.x + 0.001:
						candidate_spans.append({"id": String(finish_host.get("id", "")), "span": overlap})
			for span_record in candidate_spans:
				var span: Vector2 = span_record["span"]
				var host_id := String(span_record["id"])
				var a := maxf(lo, span.x)
				var z := minf(hi, span.y)
				var length := z - a
				if length < 0.55:
					continue
				var mid := (a + z) * 0.5
				var band_rect := Rect2(Vector2(a, line if normal.y > 0.0 else line - panel_depth) if horizontal else Vector2(line if normal.x > 0.0 else line - panel_depth, a), Vector2(length, panel_depth) if horizontal else Vector2(panel_depth, length))
				var blocked := false
				for item_variant in plan.furniture:
					var item: Dictionary = item_variant
					if int(item.get("room", -1)) != room:
						continue
					var occupied: Rect2 = item.get("zone", Rect2())
					var key := String(item.get("key", ""))
					var item_origin := PropCatalog.house_origin(item)
					var item_bottom := item_origin.y + PropCatalog.floor_offset(key) * PropCatalog.placement_height_scale(item)
					var item_top := item_bottom + PropCatalog.placement_height(item)
					var model_yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
					var item_scale := float(item.get("scale", 1.0))
					var item_centre := PropCatalog.plan_centre(key, item_origin, model_yaw, item_scale)
					var item_size := PropCatalog.footprint_rotated(key, model_yaw) * item_scale
					var solid := Rect2(item_centre - item_size * 0.5, item_size)
					var solid_overlaps_height := item_bottom < floor_y + panel_h + 0.045 and item_top > floor_y
					if (occupied.has_area() and occupied.grow(0.025).intersects(band_rect)) \
							or (solid_overlaps_height and solid.has_area() and solid.intersects(band_rect)):
						blocked = true
						break
				if blocked:
					continue
				var body_clear := true
				var clearance_rect := band_rect.grow(0.01)
				for zone_variant in plan.zones:
					var use_zone: Dictionary = zone_variant
					if int(use_zone.get("room", -1)) == room and Rect2(use_zone.get("rect", Rect2())).intersects(clearance_rect):
						body_clear = false
						break
				if not body_clear:
					continue
				var point := Vector2(mid, line) if horizontal else Vector2(line, mid)
				var centre := point + normal * (panel_depth * 0.5 - 0.004)
				var yaw := atan2(-(to - from).y, (to - from).x)
				var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, floor_y + panel_h * 0.5, centre.y))
				tag("witch_interior_finish")
				host(host_id, level)
				component_box("witch_service_wainscot", Vector3(length, panel_h, panel_depth), xf, SURF_TRIM)
				component_box("witch_service_rail", Vector3(length, 0.045, panel_depth * 1.12), Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, floor_y + panel_h + 0.0225, centre.y)), SURF_TRIM)
				host_end()


func _witch_hall_finish_is_shared_work_room(room: int) -> bool:
	if room < 0 or room >= plan.room_count() or plan.kind_of(room) != &"hall":
		return false
	var row: Dictionary = plan.rooms[room]
	var functions: Array = row.get("domestic_functions", [])
	return bool(row.get("shared_witchwork", false)) \
		and bool(row.get("shared_cooking", false)) \
		and functions.has(&"cooking") and functions.has(&"witchwork")


func _merge_witch_finish_spans(spans: Array[Vector2]) -> Array[Vector2]:
	var sorted: Array[Vector2] = spans.duplicate()
	for i in range(1, sorted.size()):
		var value: Vector2 = sorted[i]
		var j := i - 1
		while j >= 0 and sorted[j].x > value.x:
			sorted[j + 1] = sorted[j]
			j -= 1
		sorted[j + 1] = value
	var merged: Array[Vector2] = []
	for span in sorted:
		if merged.is_empty() or span.x > merged[-1].y + 0.01:
			merged.append(span)
		else:
			var last: Vector2 = merged[-1]
			merged[-1] = Vector2(last.x, maxf(last.y, span.y))
	return merged


func _build_rich_trim() -> void:
	if spec.cornice:
		_build_rich_cornice()
	if spec.string_courses > 0:
		_build_rich_bands()
	if spec.pediments:
		_build_rich_pediments()


## The crown at the wall head, in three steps, on every elevation of the top
## storey. The corona is the step that oversails: CORNICE_OUT is how far past
## the wall face it reaches, and HouseGeometry.exterior_bounds grows the bound
## by that same number, so a bound cannot be looser than the thing it bounds.
func _build_rich_cornice() -> void:
	tag("cornice")
	var level := _storeys() - 1
	host("cornice", level)
	var head: float = spec.height * float(level)
	var step: float = HouseGeometry.CORNICE_H / 3.0
	var steps := [["cornice_bed", HouseGeometry.CORNICE_BED_OUT],
		["cornice_corona", HouseGeometry.CORNICE_OUT],
		["cornice_crown", HouseGeometry.CORNICE_CROWN_OUT]]
	for i in steps.size():
		var y0: float = head - HouseGeometry.CORNICE_H + step * float(i)
		for run in HouseGeometry.shell_runs(plan, level):
			_moulding(run, y0, step, float(steps[i][1]), String(steps[i][0]))
	host_end()


## A belt band at each storey line, counted down from the top.
##
## A string course marks a storey line by capping the storey BELOW it, so it
## is emitted on that storey's own wall run at the head of that wall -- which
## also keeps it a clear storey-height from the crown, rather than fighting it
## for the same 360 mm of wall.
##
## `y0` is storey-relative, because that is what `_openings_on` reports: the
## wall builder hands the same records to `_wall_run` and adds the storey
## offset at the last moment, and a band that compared a world height against a
## storey-relative one would never see a doorway to break at.
func _build_rich_bands() -> void:
	tag("string_course")
	var wanted: int = mini(spec.string_courses, maxi(_storeys() - 1, 0))
	for i in wanted:
		var level := _storeys() - 2 - i
		host("band_%d" % level, level)
		var offset: float = spec.height * float(level)
		var y0: float = spec.height - HouseGeometry.BAND_H
		for run in HouseGeometry.shell_runs(plan, level):
			var openings := _openings_on(run["from"], run["to"], run["normal"], level,
				float(run.get("thickness", HouseGeometry.wall_thickness(spec))))
			_moulding(run, y0, HouseGeometry.BAND_H, HouseGeometry.BAND_OUT,
				"string_course", openings, offset)
	host_end()


## A pediment over every window above the ground floor, sized to whatever the
## storey has under its own head. A window whose head is close enough to the
## wall head that even PEDIMENT_MIN_RISE would not fit is left plain rather
## than pushed through the roof above it.
func _build_rich_pediments() -> void:
	for wi in plan.windows.size():
		var win: Dictionary = plan.windows[wi]
		var level := HousePlan.record_storey(win)
		if level < 1:
			continue
		var base: float = float(level) * spec.height + float(win["head"])
		var rise: float = minf(HouseGeometry.PEDIMENT_RISE,
			spec.height * float(level + 1) - base - 0.12)
		if rise < HouseGeometry.PEDIMENT_MIN_RISE:
			continue
		host("pediment_%d" % wi, level)
		_pediment(win, base, rise)
	host_end()


## One pediment: a horizontal cornice across the head, a raking cornice up each
## slope, and the tympanum between them. The window record sits on the
## interior wall face, so every piece is set out from the wall CENTRE-line.
func _pediment(win: Dictionary, base: float, rise: float) -> void:
	var normal: Vector2 = win["normal"]
	var along := Vector2(-normal.y, normal.x)
	var yaw := atan2(-along.y, along.x)
	var half: float = float(win["width"]) * 0.5 + HouseGeometry.PEDIMENT_MARGIN
	var wall: float = HouseGeometry.wall_thickness(spec)
	var centre: Vector2 = Vector2(win["pos"]) + normal * (wall * 0.5)
	var foot: float = base + 0.10
	# The tympanum and its raking cornices sit a PEDIMENT_OUT clear of the wall
	# face; the horizontal cornice below spans the whole wall thickness.
	var proud: Vector2 = normal * (wall * 0.5 + HouseGeometry.PEDIMENT_OUT * 0.5)
	var face: Vector2 = centre + proud
	component_box("pediment_cornice", Vector3(half * 2.0, 0.10,
		wall + HouseGeometry.PEDIMENT_OUT * 2.0),
		Transform3D(Basis(Vector3.UP, yaw),
			Vector3(centre.x, base + 0.05, centre.y)), SURF_TRIM)
	var apex := Vector3(face.x, foot + rise, face.y)
	component_slab("pediment_face", PackedVector3Array([
		Vector3(face.x - along.x * half, foot, face.y - along.y * half),
		Vector3(face.x + along.x * half, foot, face.y + along.y * half),
		apex]), HouseGeometry.PEDIMENT_OUT, SURF_TRIM, false)
	var span: float = sqrt(half * half + rise * rise)
	# The corner end of each rake is DOWN and the apex end is UP, so the tilt
	# is negated for the corner that lies along +X of the run's own frame.
	var tilt := -atan2(rise, half)
	for side in [-1.0, 1.0]:
		var corner: Vector2 = centre + along * (half * side) + proud
		var mid := Vector3((corner.x + face.x) * 0.5, foot + rise * 0.5,
			(corner.y + face.y) * 0.5)
		var xf := Transform3D(Basis(Vector3.UP, yaw), mid)
		xf = xf * Transform3D(Basis(Vector3(0, 0, 1), tilt * side), Vector3.ZERO)
		component_box("pediment_rake", Vector3(span, 0.08, HouseGeometry.PEDIMENT_OUT),
			xf, SURF_TRIM)


## One continuous moulding along a wall run: a step of the crown, or a belt
## band. `openings` breaks it wherever an opening comes through, so a band
## never runs across a doorway -- the same rule the timber mid rail follows.
## `y0` and `y_offset` are the storey's own vertical frame, as above.
func _moulding(run: Dictionary, y0: float, height: float, out: float, role: String,
		openings: Array = [], y_offset := 0.0) -> void:
	var from: Vector2 = run["from"]
	var to: Vector2 = run["to"]
	var seg: Vector2 = to - from
	var length: float = seg.length()
	if length <= 0.02 or height <= 0.01:
		return
	var dir: Vector2 = seg / length
	var yaw := atan2(-dir.y, dir.x)
	var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec))) \
		+ out * 2.0
	var cuts: Array = []
	for op in openings:
		if float(op["bottom"]) > y0 + height or float(op["top"]) < y0:
			continue          # the band passes clear above or below it
		cuts.append([float(op["t"]) - float(op["w"]) * 0.5,
			float(op["t"]) + float(op["w"]) * 0.5])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cursor := 0.0
	for cut in cuts:
		var lo: float = float(cut[0])
		if lo > cursor + 0.02:
			_moulding_piece(from, dir, yaw, cursor, lo, y0, height, thick, role, y_offset)
		cursor = maxf(cursor, float(cut[1]))
	if cursor < length - 0.02:
		_moulding_piece(from, dir, yaw, cursor, length, y0, height, thick, role, y_offset)


## The box one unbroken stretch of moulding emits, centred on the wall it is
## fixed to and standing `out` proud of that wall's face.
func _moulding_piece(from: Vector2, dir: Vector2, yaw: float, t0: float, t1: float,
		y0: float, height: float, thick: float, role: String,
		y_offset := 0.0) -> void:
	var length: float = t1 - t0
	if length <= 0.02:
		return
	var mid: Vector2 = from + dir * ((t0 + t1) * 0.5)
	component_box(role, Vector3(length, height, thick),
		Transform3D(Basis(Vector3.UP, yaw),
			Vector3(mid.x, y_offset + y0 + height * 0.5, mid.y)), SURF_TRIM)

## ----------------------------------------------------------------- culture
##
## Six dwellings that are not a timber cottage. Each piece below is a NAMED
## component with its own host, emitted through component_box/component_slab
## so `qa/component_check.gd` re-emits it against real triangles and
## `qa/vernacular_house_check.gd` can ask what a parapet is made of rather than
## whether a count fell. Every number comes from HouseGeometry, which is also
## where the exterior bound reads them from.

func _build_culture() -> void:
	_build_corner_piers()
	_build_veranda()


## Rounded mud corners: a regular octagon standing on each corner of each
## storey. A daub wall is built up in lifts and washed by the first rain, and
## the corners go first, so they are the first thing rebuilt -- and what they
## are rebuilt as is a round pier, not a square one. It reaches PIER_R past
## the wall line, which every roof that carries one already oversails.
func _build_corner_piers() -> void:
	if not spec.corner_piers:
		return
	tag("corner_pier")
	for level in range(_storeys()):
		host("corner_piers", level)
		var y0: float = spec.height * float(level)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var centre := Vector2(float(sx) * spec.width * 0.5,
					float(sz) * spec.length * 0.5)
				# A vertical slab is centred on the plane it is handed, so the
				# pier's plane is its own mid-height. Centred on the floor
				# instead, half of every pier stands in the ground.
				component_slab("corner_pier", _pier_ring(centre, HouseGeometry.PIER_R,
					y0 + spec.height * 0.5), spec.height, SURF_WALL, true)
	host_end()


func _pier_ring(centre: Vector2, radius: float, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = HouseGeometry.PIER_SIDES
	for i in range(n):
		var a := TAU * float(i) / float(n)
		out.append(Vector3(centre.x + cos(a) * radius, y, centre.y + sin(a) * radius))
	return out


## A veranda: a platform on the ground, posts, a head beam and a shed rooflet
## over all three, on the wall the entrance is actually on -- so it is a
## veranda and not a porch bolted to the wrong elevation. The rooflet falls
## outward and oversails the posts, which is what shades them.
func _build_veranda() -> void:
	if not spec.veranda:
		return
	var d: int = plan.entrance()
	if d < 0:
		return
	tag("veranda")
	host("veranda", 0)
	var door: Dictionary = plan.doors[d]
	var n: Vector2 = door["normal"]
	# Local +Z points OUT of the door, +X runs along the wall, and the origin is
	# the door's own place in the plan. A veranda built at the world origin is
	# a veranda in the middle of the house, and its bound is still correct.
	var xf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)),
		Vector3(door["pos"].x, 0.0, door["pos"].y))
	var face: float = HouseGeometry.wall_thickness(spec) * 0.5
	var depth: float = spec.veranda_depth
	var head: float = HouseGeometry.veranda_head(spec)
	var pw: float = HouseGeometry.VERANDA_POST_W
	var w: float = float(door["width"]) * 2.0 + pw * float(HouseGeometry.VERANDA_POSTS)
	var front: float = face + depth
	component_box("veranda_deck", Vector3(w, HouseGeometry.VERANDA_DECK_T, depth),
		xf * Transform3D(Basis(), Vector3(0.0, HouseGeometry.VERANDA_DECK_T * 0.5,
			face + depth * 0.5)), SURF_FLOOR)
	var run: float = w - pw
	for i in range(HouseGeometry.VERANDA_POSTS):
		var px: float = -run * 0.5 + run * float(i) / float(HouseGeometry.VERANDA_POSTS - 1)
		component_box("veranda_post", Vector3(pw, head, pw),
			xf * Transform3D(Basis(), Vector3(px, head * 0.5, front - pw * 0.5)), SURF_TRIM)
	component_box("veranda_beam", Vector3(run + pw * 2.0, HouseGeometry.VERANDA_BEAM_H,
		HouseGeometry.VERANDA_BEAM_W),
		xf * Transform3D(Basis(), Vector3(0.0, head + HouseGeometry.VERANDA_BEAM_H * 0.5,
			front - pw * 0.5)), SURF_TRIM)
	# The rooflet, in segments: a shed roof over a veranda is a slab that
	# falls, and the kit extrudes a slab along one axis, so the veranda's width
	# is the axis it cannot be extruded along.
	var edge: float = front + HouseGeometry.VERANDA_EAVE_OUT
	var rt: float = HouseGeometry.VERANDA_ROOF_T
	var fall: float = HouseGeometry.VERANDA_ROOF_FALL
	var segs: int = 4
	for i in range(segs):
		var x0: float = -w * 0.5 + w * (float(i) + 0.5) / float(segs)
		var seg: float = w / float(segs)
		_roof_face(xf, PackedVector3Array([
			Vector3(x0, head, face), Vector3(x0, head - fall, edge),
			Vector3(x0, head - fall - rt, edge), Vector3(x0, head - rt, face)]),
			SURF_ROOF, "veranda_roof_%d" % i, false, seg)
	host_end()


## The roof's plan half-extents, span first, in the 64-bit floats the emitter
## lays in. Read from the layout the builder laid out rather than recomputed
## from the spec, so a piece that stands ON the eave cannot be placed against a
## different roof than the one above it. `HouseGeometry.roof_oversail` would do
## this in one line and in 32 bits; see HouseGeometry.roof_span_out for why that
## is not a cosmetic difference.
func _eave_half_x(layout: Dictionary) -> float:
	return float(layout["span"]) * 0.5 + HouseGeometry.roof_span_out(spec)


func _eave_half_y(layout: Dictionary) -> float:
	return float(layout["along"]) * 0.5 + HouseGeometry.roof_along_out(spec)


## A parapet on the roof edge, with its outer face ON the eave rather than
## past it -- so it costs the plan bound nothing and the roof behind it is the
## roof that contains it. It only reads against a shallow pitch, which is
## exactly the roof the styles that ask for it are given.
func _build_parapet(layout: Dictionary) -> void:
	if not spec.parapet:
		return
	tag("parapet")
	host("parapet", _storeys() - 1)
	var hx: float = _eave_half_x(layout)
	var hy: float = _eave_half_y(layout)
	var t: float = HouseGeometry.PARAPET_T
	var y0: float = HouseGeometry.PARAPET_BASE
	for side in [-1.0, 1.0]:
		var s := float(side)
		component_box("parapet", Vector3(t, HouseGeometry.PARAPET_H, hy * 2.0),
			layout["transform"] * Transform3D(Basis(),
				Vector3(s * (hx - t * 0.5), y0 + HouseGeometry.PARAPET_H * 0.5, 0.0)), SURF_WALL)
		component_box("parapet", Vector3(hx * 2.0, HouseGeometry.PARAPET_H, t),
			layout["transform"] * Transform3D(Basis(),
				Vector3(0.0, y0 + HouseGeometry.PARAPET_H * 0.5, s * (hy - t * 0.5))), SURF_WALL)
	host_end()


## The eave sweep: a fin at each of the four roof corners, standing SWEEP_UP
## above the eave and reaching SWEEP_RUN back along it. Set inboard of the
## eave and stopped there, so it is the roof's own oversail that bounds it and
## a house that did not widen its roof got no sweep.
func _build_eave_sweep(layout: Dictionary) -> void:
	if not spec.eave_sweep:
		return
	tag("eave_sweep")
	host("eave_sweep", _storeys() - 1)
	var hx: float = _eave_half_x(layout)
	var hy: float = _eave_half_y(layout)
	var t: float = HouseGeometry.SWEEP_T
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var sx := float(side)
			var ez := float(end)
			# The fin is a vertical triangle extruded ACROSS its own plane, so
			# the slab straddles the plane rather than starting at it. Setting
			# the plane half a fin inboard lands the fin's outer face exactly
			# on the eave, whichever corner of the roof this is.
			var plane: float = sx * (hx - t * 0.5)
			_roof_face(layout["transform"], PackedVector3Array([
				Vector3(plane, 0.0, ez * hy),
				Vector3(plane, 0.0, ez * (hy - HouseGeometry.SWEEP_RUN)),
				Vector3(plane, HouseGeometry.SWEEP_UP, ez * hy)]),
				SURF_ROOF, "eave_sweep_%d_%d" % [int(sx), int(ez)], false, t)
	host_end()


## The thatch roll. Reeds are combed and BUNDLED at the ridge at intervals
## rather than run as one continuous capping, so the roll is a short fin every
## ROLL_PITCH along it; the eave is one thick bundle capping both eaves. Only
## the roll stands above the slab, so only the roll moves the height bound.
func _build_thatch_roll(layout: Dictionary, authored: Array) -> void:
	if not HouseGeometry.roof_has_thatch_roll(spec, plan.world_family):
		return
	tag("thatch_roll")
	host("thatch_roll", _storeys() - 1)
	var xf: Transform3D = layout["transform"]
	var hx: float = _eave_half_x(layout)
	var hy: float = _eave_half_y(layout)
	var rise: float = layout["rise"]
	var faces: Array[PackedVector3Array] = layout["faces"]
	var witch_roofcraft: bool = HouseGeometry.has_witch_roofcraft(spec, plan.world_family)
	var roll_cuts: Array = authored.duplicate()
	roll_cuts.append_array(layout.get("dormers", []))
	var bay_cut: Dictionary = layout.get("witch_bay", {})
	if not bay_cut.is_empty():
		roll_cuts.append({"polygon": bay_cut["outline"]})
	var ew: float = HouseGeometry.THATCH_EAVE_W
	for side in [-1.0, 1.0]:
		if not witch_roofcraft:
			component_box("thatch_eave", Vector3(ew, HouseGeometry.THATCH_EAVE_H, hy * 2.0),
				xf * Transform3D(Basis(), Vector3(float(side) * (hx - ew * 0.5),
				RoofShape.DEPTH * 0.5 - HouseGeometry.THATCH_EAVE_H * 0.5, 0.0)), SURF_ROOF)
			continue
		var eave_ranges: Array[Vector2] = [Vector2(-hy, hy)]
		var bay: Dictionary = layout.get("witch_bay", {})
		if int(bay.get("axis", -1)) == 0 and is_equal_approx(signf(float(bay.get("outer", 0.0))), float(side)):
			eave_ranges = _subtract_thatch_interval(eave_ranges,
				Vector2(float(bay["along_lo"]) - 0.01, float(bay["along_hi"]) + 0.01))
		var eave_inner_x: float = float(side) * (hx - ew)
		var eave_outer_x: float = float(side) * hx
		var eave_lo_x := minf(eave_inner_x, eave_outer_x)
		var eave_hi_x := maxf(eave_inner_x, eave_outer_x)
		for op in roll_cuts:
			var cut_polygon: PackedVector2Array = _thatch_cut_polygon(op)
			if cut_polygon.size() < 3:
				continue
			var hole: Rect2 = Poly.bounding_rect(cut_polygon)
			if hole.end.x <= eave_lo_x or hole.position.x >= eave_hi_x:
				continue
			eave_ranges = _subtract_thatch_interval(eave_ranges,
				Vector2(hole.position.y - 0.01, hole.end.y + 0.01))
		for eave_range in eave_ranges:
			if eave_range.y - eave_range.x <= 0.10:
				continue
			var eave_face: PackedVector3Array = faces[0] if side < 0.0 else faces[1]
			var inner_x: float = float(side) * (hx - ew)
			var outer_x: float = float(side) * hx
			var middle_x: float = (inner_x + outer_x) * 0.5
			var z: float = (eave_range.x + eave_range.y) * 0.5
			var inner_y: float = _roof_top_surface_y(eave_face, faces, Vector2(inner_x, z))
			var middle_y: float = _roof_top_surface_y(eave_face, faces, Vector2(middle_x, z))
			var outer_y: float = _roof_top_surface_y(eave_face, faces, Vector2(outer_x, z))
			var shoulder_h: float = HouseGeometry.THATCH_EAVE_H * 0.42
			var eave_profile := PackedVector3Array([
				Vector3(inner_x, inner_y, z),
				Vector3(lerpf(inner_x, outer_x, 0.25),
					lerpf(inner_y, outer_y, 0.25) + shoulder_h, z),
				Vector3(middle_x, middle_y + HouseGeometry.THATCH_EAVE_H, z),
				Vector3(lerpf(inner_x, outer_x, 0.75),
					lerpf(inner_y, outer_y, 0.75) + shoulder_h, z),
				Vector3(outer_x, outer_y, z),
			])
			var eave_world := PackedVector3Array()
			for profile_point in eave_profile:
				eave_world.append(xf * profile_point)
			component_slab("thatch_eave", eave_world, eave_range.y - eave_range.x,
				SURF_ROOF, false)
	var ridge: float = HouseGeometry.ridge_half_for(spec, float(layout["span"]),
		float(layout["along"]), plan.world_family)
	if ridge <= 0.05:
		host_end()
		return
	# A roll is a bundle ROLL_T deep, and `slab_poly` straddles the plane it is
	# handed, so the first one starts a half-bundle in from the ridge end and the
	# last one stops a half-bundle short of the other. Spacing the centres off
	# the ends rather than off -ridge is what keeps a 14 m cottage's roll from
	# hanging half a metre over the gable.
	var rw: float = HouseGeometry.ROLL_W
	if not witch_roofcraft:
		var legacy_first: float = -ridge + HouseGeometry.ROLL_T * 0.5
		var legacy_last: float = ridge - HouseGeometry.ROLL_T * 0.5
		var legacy_count: int = maxi(int((legacy_last - legacy_first) / HouseGeometry.ROLL_PITCH) + 1, 1)
		for i in range(legacy_count):
			var z: float = legacy_first if legacy_count == 1 else lerpf(legacy_first, legacy_last, float(i) / float(legacy_count - 1))
			_roof_face(xf, PackedVector3Array([
				Vector3(-rw * 0.5, rise, z), Vector3(rw * 0.5, rise, z),
				Vector3(0.0, rise + HouseGeometry.ROLL_H, z)]),
				SURF_ROOF, "thatch_roll_%d" % i, false, HouseGeometry.ROLL_T)
		host_end()
		return
	var ridge_x: float = float(layout.get("ridge_x", 0.0))
	var ranges: Array[Vector2] = [Vector2(-ridge, ridge)]
	for op in roll_cuts:
		var cut_polygon: PackedVector2Array = _thatch_cut_polygon(op)
		if cut_polygon.size() < 3:
			continue
		var hole: Rect2 = Poly.bounding_rect(cut_polygon)
		if hole.end.x <= ridge_x - rw * 0.5 or hole.position.x >= ridge_x + rw * 0.5:
			continue
		var next_ranges: Array[Vector2] = []
		for span_range in ranges:
			if hole.end.y <= span_range.x or hole.position.y >= span_range.y:
				next_ranges.append(span_range)
				continue
			var hole_lo: float = hole.position.y - HouseGeometry.ROLL_T * 0.5
			var hole_hi: float = hole.end.y + HouseGeometry.ROLL_T * 0.5
			if hole_lo > span_range.x + 0.02:
				next_ranges.append(Vector2(span_range.x, minf(hole_lo, span_range.y)))
			if hole_hi < span_range.y - 0.02:
				next_ranges.append(Vector2(maxf(hole_hi, span_range.x), span_range.y))
		ranges = next_ranges
	var roll_index := 0
	for span_range in ranges:
		var first: float = span_range.x + HouseGeometry.ROLL_T * 0.5
		var last: float = span_range.y - HouseGeometry.ROLL_T * 0.5
		if last < first:
			continue
		var count: int = maxi(int((last - first) / HouseGeometry.ROLL_PITCH) + 1, 1)
		for i in range(count):
			var z: float = first if count == 1 else lerpf(first, last, float(i) / float(count - 1))
			var left_x: float = ridge_x - rw * 0.5
			var right_x: float = ridge_x + rw * 0.5
			var left_face: PackedVector3Array = faces[0] if left_x < ridge_x else faces[1]
			var right_face: PackedVector3Array = faces[0] if right_x < ridge_x else faces[1]
			var left_top: float = _roof_top_surface_y(left_face, faces, Vector2(left_x, z))
			var right_top: float = _roof_top_surface_y(right_face, faces, Vector2(right_x, z))
			if not is_finite(left_top) or not is_finite(right_top):
				continue
			var left_mid_x := lerpf(left_x, ridge_x, 0.55)
			var right_mid_x := lerpf(right_x, ridge_x, 0.55)
			var left_mid_face: PackedVector3Array = faces[0] if left_mid_x < ridge_x else faces[1]
			var right_mid_face: PackedVector3Array = faces[0] if right_mid_x < ridge_x else faces[1]
			var left_mid_y := _roof_top_surface_y(left_mid_face, faces, Vector2(left_mid_x, z)) + HouseGeometry.ROLL_H * 0.38
			var right_mid_y := _roof_top_surface_y(right_mid_face, faces, Vector2(right_mid_x, z)) + HouseGeometry.ROLL_H * 0.38
			_roof_face(xf, PackedVector3Array([
				Vector3(left_x, left_top, z), Vector3(left_mid_x, left_mid_y, z),
				Vector3(ridge_x, RoofShape.height_at(faces, Vector2(ridge_x, z)) + HouseGeometry.ROLL_H, z),
				Vector3(right_mid_x, right_mid_y, z), Vector3(right_x, right_top, z)]),
				SURF_ROOF, "thatch_roll_%d" % roll_index, false, HouseGeometry.ROLL_T)
			roll_index += 1
	host_end()


func _subtract_thatch_interval(ranges: Array[Vector2], cut: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for span_range in ranges:
		if cut.y <= span_range.x or cut.x >= span_range.y:
			out.append(span_range)
			continue
		if cut.x > span_range.x + 0.02:
			out.append(Vector2(span_range.x, minf(cut.x, span_range.y)))
		if cut.y < span_range.y - 0.02:
			out.append(Vector2(maxf(cut.y, span_range.x), span_range.y))
	return out


func _thatch_cut_polygon(op: Dictionary) -> PackedVector2Array:
	if op.has("polygon"):
		return op["polygon"]
	if op.has("opening"):
		return op["opening"]
	return PackedVector2Array()


func _roof_top_surface_y(face: PackedVector3Array, faces: Array[PackedVector3Array], point: Vector2) -> float:
	if face.size() < 3:
		return NAN
	# The main roof uses slab_poly(..., vertical_depth=true), so its upper face
	# is a vertical offset, not a normal offset on the sloped plane.
	return RoofShape.height_at(faces, point) + RoofShape.DEPTH * 0.5


# ------------------------------------------------------------------- roof

## How far the roof runs past the end wall at the gable: the verge.
const VERGE := 0.25
## How much of a half-hipped roof is still gable, measured up from the wall
## head. The rest is hipped off.
const HIP_CUT := 0.62


## A court is SKY. The roof is the footprint MINUS the courts, and with only
## slabs and boxes to build from, the honest way to say that is to roof each
## RANGE rather than the whole box: a lean-to falling from the outer wall in
## to the courtyard eaves, which is what a range round a yard actually has
## (GEO-003).
func _build_court_roofs() -> void:
	tag("roof")
	host("roof", _storeys() - 1)
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var wall_top: float = spec.height * _storeys()
	# Courtyard ranges are shallow lean-tos, not a second storey. The ordinary
	# roof pitch is sized for a full house span; bound this ring to a modest
	# fraction of the footprint so its outer support fascia stays below 0.7m.
	var rise: float = minf(HouseGeometry.roof_rise(spec) * 0.12,
		minf(site.size.x, site.size.y) * 0.04)
	var shell_t: float = HouseGeometry.wall_thickness(spec)
	var fascia := [
		{"size": Vector3(site.size.x, rise, shell_t),
			"pos": Vector3(site.get_center().x, wall_top + rise * 0.5,
				site.position.y + shell_t * 0.5)},
		{"size": Vector3(site.size.x, rise, shell_t),
			"pos": Vector3(site.get_center().x, wall_top + rise * 0.5,
				site.end.y - shell_t * 0.5)},
		{"size": Vector3(shell_t, rise, site.size.y),
			"pos": Vector3(site.position.x + shell_t * 0.5,
				wall_top + rise * 0.5, site.get_center().y)},
		{"size": Vector3(shell_t, rise, site.size.y),
			"pos": Vector3(site.end.x - shell_t * 0.5,
				wall_top + rise * 0.5, site.get_center().y)}]
	for fi in range(fascia.size()):
		var fs: Vector3 = fascia[fi]["size"]
		var fp: Vector3 = fascia[fi]["pos"]
		component_box("court_roof_fascia_%d" % fi, fs,
			Transform3D(Basis(), fp), SURF_WALL)
		_log_mass("court_roof_fascia_%d" % fi,
			AABB(fp - fs * 0.5, fs), wall_top)
	# A one-court house of several storeys carries one court record per storey,
	# all the same rectangle. That is still one court and one four-range ring,
	# not a multi-court compound: only DISTINCT rectangles take the multi path.
	var distinct_courts: Array[Rect2] = []
	for court_row in plan.courts:
		var cr := Rect2(court_row["rect"])
		var known := false
		for seen in distinct_courts:
			if seen.position.distance_to(cr.position) < 0.01 and seen.size.distance_to(cr.size) < 0.01:
				known = true
				break
		if not known:
			distinct_courts.append(cr)
	for ci in range(plan.courts.size()):
		if distinct_courts.size() > 1:
			_build_multi_court_roofs(site, wall_top, rise)
			break
		# A multi-storey courtyard repeats its plan court at each level, but the
		# building has one roof ring. Emitting every record stacked identical
		# plates at the top and made the roof look like floating bands.
		if ci != plan.courts.size() - 1:
			continue
		var court: Rect2 = plan.courts[ci]["rect"]
		for side in range(4):
			var band: Rect2
			var horizontal: bool = side <= 1
			match side:
				0:
					band = Rect2(site.position.x, site.position.y,
						site.size.x, court.position.y - site.position.y)
				1:
					band = Rect2(site.position.x, court.end.y,
						site.size.x, site.end.y - court.end.y)
				2:
					band = Rect2(site.position.x, court.position.y,
						court.position.x - site.position.x, court.size.y)
				_:
					band = Rect2(court.end.x, court.position.y,
						site.end.x - court.end.x, court.size.y)
			if band.size.x < 0.3 or band.size.y < 0.3:
				continue
			# One sloping plate to a range, falling from the outer wall in to
			# the courtyard eaves -- which is what a cloister range has, and
			# the only roof shape that leaves the yard open.
			var quad := PackedVector3Array()
			# Each range is a trapezoid: its outer edge follows the site wall,
			# while its inner edge follows only the matching court edge. Adjacent
			# faces therefore meet at the same outer/court corner endpoints.
			match side:
				0:
					quad = PackedVector3Array([
						Vector3(site.position.x, wall_top + rise, site.position.y),
						Vector3(site.end.x, wall_top + rise, site.position.y),
						Vector3(court.end.x, wall_top, court.position.y),
						Vector3(court.position.x, wall_top, court.position.y)])
				1:
					quad = PackedVector3Array([
						Vector3(site.end.x, wall_top + rise, site.end.y),
						Vector3(site.position.x, wall_top + rise, site.end.y),
						Vector3(court.position.x, wall_top, court.end.y),
						Vector3(court.end.x, wall_top, court.end.y)])
				2:
					quad = PackedVector3Array([
						Vector3(site.position.x, wall_top + rise, site.end.y),
						Vector3(site.position.x, wall_top + rise, site.position.y),
						Vector3(court.position.x, wall_top, court.position.y),
						Vector3(court.position.x, wall_top, court.end.y)])
				_:
					quad = PackedVector3Array([
						Vector3(site.end.x, wall_top + rise, site.position.y),
						Vector3(site.end.x, wall_top + rise, site.end.y),
						Vector3(court.end.x, wall_top, court.end.y),
						Vector3(court.end.x, wall_top, court.position.y)])
			roof_components.append(
				component_slab("roof_court_%d_%d" % [ci, side], quad, 0.24, SURF_ROOF))
			_log_mass("roof_court_%d_%d" % [ci, side],
				AABB(Vector3(band.position.x, wall_top - 0.12, band.position.y),
					Vector3(band.size.x, rise + 0.24, band.size.y)))
			total_height = maxf(total_height, wall_top + rise)
	_record_court_roof_openings(wall_top)
	# The main hall is the ceremonial and visual apex of a Siheyuan. This
	# courtyard roof path returns before the ordinary roof emitter, so author
	# its ridge here as emitted geometry and a named mass, not QA metadata.
	if plan.world_family == &"siheyuan":
		var hall: Rect2 = plan.world_meta.get("main_hall_rect", Rect2())
		var ridge_top := float(plan.world_meta.get("hall_ridge_height", wall_top + rise + 0.25))
		var support_size := Vector3(0.24, ridge_top, 0.24)
		for side in [-1.0, 1.0]:
			var support_center := Vector3(hall.get_center().x + side * 1.5,
				ridge_top * 0.5, hall.get_center().y)
			box(support_size, support_center, SURF_TRIM)
			_log_mass("siheyuan_ridge_support",
				AABB(support_center - support_size * 0.5, support_size))
		var ridge_size := Vector3(hall.size.x + 0.4, 0.3, 0.28)
		var ridge_center := Vector3(hall.get_center().x, ridge_top - ridge_size.y * 0.5,
			hall.get_center().y)
		tag("roof")
		host("main_hall_ridge")
		box(ridge_size, ridge_center, SURF_ROOF)
		_log_mass("siheyuan_main_hall_ridge",
			AABB(ridge_center - ridge_size * 0.5, ridge_size), ridge_center.y - ridge_size.y * 0.5)
		total_height = maxf(total_height, ridge_top)
		host_end()
	host_end()


## A multi-court compound has open court rectangles, not one giant lightwell.
## Keep the side ranges outside the outer court edges and roof only the axial
## halls between them; the span polygons leave every court open to the sky.
func _build_multi_court_roofs(site: Rect2, wall_top: float, rise: float) -> void:
	var ordered: Array[Rect2] = []
	for court_row in plan.courts:
		ordered.append(Rect2(court_row["rect"]))
	ordered.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
	var first: Rect2 = ordered[0]
	var last: Rect2 = ordered[ordered.size() - 1]
	var depth := 0.24
	var front_quad := PackedVector3Array([
		Vector3(site.position.x, wall_top + rise, site.position.y),
		Vector3(site.end.x, wall_top + rise, site.position.y),
		Vector3(first.end.x, wall_top, first.position.y),
		Vector3(first.position.x, wall_top, first.position.y)])
	component_slab("roof_court_multi_front", front_quad, depth, SURF_ROOF)
	_log_mass("roof_court_multi_front", AABB(Vector3(site.position.x, wall_top - depth * 0.5, site.position.y),
		Vector3(site.size.x, rise + depth, first.position.y - site.position.y)))
	var rear_quad := PackedVector3Array([
		Vector3(site.end.x, wall_top + rise, site.end.y),
		Vector3(site.position.x, wall_top + rise, site.end.y),
		Vector3(last.position.x, wall_top, last.end.y),
		Vector3(last.end.x, wall_top, last.end.y)])
	component_slab("roof_court_multi_rear", rear_quad, depth, SURF_ROOF)
	_log_mass("roof_court_multi_rear", AABB(Vector3(site.position.x, wall_top - depth * 0.5, last.end.y),
		Vector3(site.size.x, rise + depth, site.end.y - last.end.y)))
	var left_quad := PackedVector3Array([
		Vector3(site.position.x, wall_top + rise, first.position.y),
		Vector3(site.position.x, wall_top + rise, last.end.y),
		Vector3(first.position.x, wall_top, last.end.y),
		Vector3(first.position.x, wall_top, first.position.y)])
	component_slab("roof_court_multi_west", left_quad, depth, SURF_ROOF)
	_log_mass("roof_court_multi_west", AABB(Vector3(site.position.x, wall_top - depth * 0.5, first.position.y),
		Vector3(first.position.x - site.position.x, rise + depth, last.end.y - first.position.y)))
	var right_quad := PackedVector3Array([
		Vector3(site.end.x, wall_top + rise, last.end.y),
		Vector3(site.end.x, wall_top + rise, first.position.y),
		Vector3(last.end.x, wall_top, first.position.y),
		Vector3(last.end.x, wall_top, last.end.y)])
	component_slab("roof_court_multi_east", right_quad, depth, SURF_ROOF)
	_log_mass("roof_court_multi_east", AABB(Vector3(last.end.x, wall_top - depth * 0.5, first.position.y),
		Vector3(site.end.x - last.end.x, rise + depth, last.end.y - first.position.y)))
	for ci in range(ordered.size() - 1):
		var gap := Rect2(Vector2(site.position.x, ordered[ci].end.y),
			Vector2(site.size.x, ordered[ci + 1].position.y - ordered[ci].end.y))
		if gap.size.y <= 0.0:
			continue
		var size := Vector3(gap.size.x, depth, gap.size.y)
		var center := Vector3(gap.get_center().x, wall_top + rise * 0.55, gap.get_center().y)
		component_box("roof_court_multi_hall_%d" % ci, size,
			Transform3D(Basis(), center), SURF_ROOF)
		_log_mass("roof_court_multi_hall_%d" % ci,
			AABB(center - size * 0.5, size))
	total_height = maxf(total_height, wall_top + rise)


func _build_roof() -> void:
	if plan.has_court():
		_build_court_roofs()
		return
	tag("roof")
	host("roof", _storeys() - 1)
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var faces: Array[PackedVector3Array] = layout["faces"]
	var span: float = layout["span"]
	var along: float = layout["along"]
	var rise: float = layout["rise"]
	var authored := []
	for op in HouseGeometry.roof_openings(plan):
		if op["kind"] != &"dormer":
			authored.append(op)
	for fi in range(faces.size()):
		var pieces: Array[PackedVector2Array] = [RoofShape.footprint(faces[fi])]
		for dormer in layout["dormers"]:
			if int(dormer["face"]) != fi:
				continue
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(RoofShape.subtract(piece, dormer["opening"]))
			pieces = next
		for op in authored:
			var hole: PackedVector2Array = op["polygon"]
			if Poly.intersection_area(RoofShape.footprint(faces[fi]), hole) <= 0.0001:
				continue
			var next_authored: Array[PackedVector2Array] = []
			for piece in pieces:
				next_authored.append_array(RoofShape.subtract(piece, hole))
			pieces = next_authored
		var bay_cut: Dictionary = layout.get("witch_bay", {})
		if not bay_cut.is_empty():
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				remaining.append_array(RoofShape.subtract(piece, bay_cut["outline"]))
			pieces = remaining
		for piece in pieces:
			_roof_face(xf, RoofShape.lift(piece, faces[fi]), SURF_ROOF, "roof_face_%d" % fi)
	var bay_roof: Dictionary = layout.get("witch_bay", {})
	if not bay_roof.is_empty():
		_build_witch_workshop_bay_roof(xf, bay_roof, faces)
		# Bay emitters have their own hosts. Resume the main roof before its wall and frame parts.
		tag("roof")
		host("roof", _storeys() - 1)
	_record_sloped_roof_openings(layout, authored)

	# Close the wall head to the roof UNDERSIDE on every facade. This also
	# fills the small raised eave band on hip roofs, not just gable triangles.
	var h := span * 0.5
	var f := along * 0.5
	for run in [[Vector2(-h, -f), Vector2(h, -f), Vector2(0, 1)],
			[Vector2(-h, f), Vector2(h, f), Vector2(0, -1)],
			[Vector2(-h, -f), Vector2(-h, f), Vector2(1, 0)],
			[Vector2(h, -f), Vector2(h, f), Vector2(-1, 0)]]:
		var profile := RoofShape.wall_profile(faces, run[0], run[1])
		var wall_profiles: Array[PackedVector3Array] = [profile]
		if not bay_roof.is_empty():
			wall_profiles = _witch_bay_wall_profiles(faces, run[0], run[1], bay_roof, xf, profile)
		var inward: Vector2 = run[2] * HouseGeometry.wall_thickness(spec) * 0.5
		var shift := Transform3D(Basis(), Vector3(inward.x, 0, inward.y))
		for wall_profile in wall_profiles:
			if wall_profile.size() >= 3:
				_roof_face(xf * shift, wall_profile, SURF_WALL, "roof_wall", false, HouseGeometry.wall_thickness(spec))
	if not bay_roof.is_empty():
		_build_witch_bay_outboard_gables(xf, bay_roof, faces)

	# One ridge length for the cap and the crown that may stand on it, so the
	# two can never disagree about whether there IS a ridge.
	var ridge: float = HouseGeometry.ridge_half_for(spec, span, along, plan.world_family)
	var ridge_x := float(layout.get("ridge_x", 0.0))
	if ridge > 0.05:
		_emit_ridge_cap_segments(xf, rise, ridge, authored, ridge_x)
	var over_x := HouseGeometry.roof_span_out(spec)
	var over_y := HouseGeometry.roof_along_out(spec)
	var roof_bounds: AABB = xf * AABB(Vector3(-h - over_x, -RoofShape.DEPTH * 0.5, -f - over_y),
		Vector3(span + over_x * 2.0, rise + RoofShape.DEPTH * 0.5 + HouseGeometry.roof_slab_top(spec, plan.world_family),
			along + over_y * 2.0))
	_log_mass("roof" if _storeys() == 1 else "roof_%d" % (_storeys() - 1), roof_bounds)
	total_height = maxf(total_height, xf.origin.y + rise + HouseGeometry.roof_slab_top(spec, plan.world_family))
	if spec.roof_type in [&"gable", &"half_hipped"]:
		var wall_peak := RoofShape.height_at(faces, Vector2(0, f))
		if spec.timber_frame:
			if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family):
				_witch_gable_frame(xf, span, along, rise, ridge_x, bay_roof, faces)
			else:
				_gable_frame(xf, span, along, rise, wall_peak)
		var verge_top := rise * RoofShape.HALF_HIP if spec.roof_type == &"half_hipped" else rise
		if not HouseGeometry.has_witch_roofcraft(spec, plan.world_family):
			_build_bargeboards(xf, span, along, rise, verge_top, ridge_x)
	_build_ridge_crown(xf, rise, ridge, ridge_x)
	_build_eaves_tails(xf, span, along, rise)
	_build_dormers(xf, layout["dormers"])
	_build_parapet(layout)
	_build_eave_sweep(layout)
	_build_thatch_roll(layout, authored)
	host_end()


## A centred oculus can cross the ridge. The slope pieces are clipped above,
## but the decorative ridge cap is a separate solid box, so it must be split
## around the same local-XZ opening projection or a vertical ray still hits it.
func _witch_bay_wall_profiles(_faces: Array[PackedVector3Array], run_a: Vector2, run_b: Vector2, bay: Dictionary, _xf: Transform3D, profile: PackedVector3Array) -> Array[PackedVector3Array]:
	var unchanged: Array[PackedVector3Array] = [profile]
	if int(bay["axis"]) != 0 or profile.size() < 3:
		return unchanged
	var d := run_b - run_a
	var dir := d.normalized()
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var zlo := float(bay["along_lo"])
	var zhi := float(bay["along_hi"])
	var plane_lo := float(bay["eave_y"])
	var plane_hi := float(bay["join_y"])
	var half_depth := maxf(RoofShape.DEPTH * 0.5 - 0.005, 0.0)
	var t0 := 0.0
	var t1 := 0.0
	var y0 := 0.0
	var y1 := 0.0
	if absf(dir.y) > 0.95:
		# Eave-side wall: its roof-local X is the actual wall plane.
		var wall_x := run_a.x
		if absf(wall_x - float(bay["wall_outer"])) > 0.12 or absf(run_b.x - wall_x) > 0.02:
			return unchanged
		if wall_x < minf(outer, inner) - 0.02 or wall_x > maxf(outer, inner) + 0.02:
			return unchanged
		var lo := maxf(minf(run_a.y, run_b.y), zlo)
		var hi := minf(maxf(run_a.y, run_b.y), zhi)
		if hi - lo < 0.02:
			return unchanged
		t0 = (lo - run_a.y) / dir.y
		t1 = (hi - run_a.y) / dir.y
		y0 = lerpf(plane_lo, plane_hi, clampf((wall_x - outer) / (inner - outer), 0.0, 1.0))
		y1 = y0
	elif absf(dir.x) > 0.95:
		# Gable-end wall: the shed plane crosses this profile at a sloping line.
		var wall_z := run_a.y
		if absf(run_b.y - wall_z) > 0.02 or wall_z < zlo - 0.02 or wall_z > zhi + 0.02:
			return unchanged
		var lo_x := maxf(minf(run_a.x, run_b.x), minf(outer, inner))
		var hi_x := minf(maxf(run_a.x, run_b.x), maxf(outer, inner))
		if hi_x - lo_x < 0.02:
			return unchanged
		t0 = (lo_x - run_a.x) / dir.x
		t1 = (hi_x - run_a.x) / dir.x
		y0 = lerpf(plane_lo, plane_hi, clampf((lo_x - outer) / (inner - outer), 0.0, 1.0))
		y1 = lerpf(plane_lo, plane_hi, clampf((hi_x - outer) / (inner - outer), 0.0, 1.0))
	else:
		return unchanged
	var first_t := minf(t0, t1)
	var last_t := maxf(t0, t1)
	var first_y := y0 if t0 <= t1 else y1
	var last_y := y1 if t0 <= t1 else y0
	var flattened := PackedVector2Array()
	for vertex in profile:
		var t := (Vector2(vertex.x, vertex.z) - run_a).dot(dir)
		flattened.append(Vector2(t, vertex.y))
	var wall_top := -INF
	for vertex in flattened:
		wall_top = maxf(wall_top, vertex.y)
	# The shed roof replaces the entire former gable/eave infill above its
	# underside. Leaving the old upper triangle would make a floating wall.
	var hole := PackedVector2Array([Vector2(first_t, first_y - half_depth), Vector2(last_t, last_y - half_depth), Vector2(last_t, wall_top + 0.2), Vector2(first_t, wall_top + 0.2)])
	var clipped := RoofShape.subtract(flattened, hole)
	var out: Array[PackedVector3Array] = []
	for piece in clipped:
		var points := PackedVector3Array()
		for point in piece:
			var pos := run_a + dir * point.x
			points.append(Vector3(pos.x, point.y, pos.y))
		if points.size() >= 3:
			out.append(points)
	if absf(dir.x) > 0.95:
		out.append_array(_witch_bay_gable_closure_profiles(_faces, run_a, run_b, bay, profile))
	return out



func _witch_bay_gable_closure_profiles(faces: Array[PackedVector3Array], run_a: Vector2,
		run_b: Vector2, bay: Dictionary, profile: PackedVector3Array) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	var wall_z := (run_a.y + run_b.y) * 0.5
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var lo_x := maxf(minf(run_a.x, run_b.x), minf(outer, inner))
	var hi_x := minf(maxf(run_a.x, run_b.x), maxf(outer, inner))
	var wall_t := HouseGeometry.wall_thickness(spec)
	var bay_lo := float(bay["along_lo"])
	var bay_hi := float(bay["along_hi"])
	# The bay roof can continue past the high-core roof profile to the actual
	# facade run. Close that measured end-wall station whenever it lies inside
	# the bay's emitted along-span; do not require it to equal a bay endpoint.
	if hi_x - lo_x < 0.02 or wall_z < bay_lo - wall_t * 0.5 - 0.02 \
			or wall_z > bay_hi + wall_t * 0.5 + 0.02:
		return out
	var stations: Array[float] = [lo_x, hi_x]
	for vertex in profile:
		var duplicate_station := false
		for existing_station in stations:
			if absf(float(existing_station) - vertex.x) < 0.001:
				duplicate_station = true
				break
		if vertex.x > lo_x + 0.001 and vertex.x < hi_x - 0.001 and not duplicate_station:
			stations.append(vertex.x)
	stations.sort()
	var roots: Array[float] = []
	for root_index in range(stations.size() - 1):
		var root_x0 := stations[root_index]
		var root_x1 := stations[root_index + 1]
		var root_main0 := _witch_bay_gable_wall_top(faces, root_x0, wall_z)
		var root_main1 := _witch_bay_gable_wall_top(faces, root_x1, wall_z)
		var root_bay0 := _witch_bay_shed_wall_top(bay, root_x0)
		var root_bay1 := _witch_bay_shed_wall_top(bay, root_x1)
		var root_gap0 := root_bay0 - root_main0
		var root_gap1 := root_bay1 - root_main1
		if root_gap0 * root_gap1 < -0.000001:
			roots.append(lerpf(root_x0, root_x1, root_gap0 / (root_gap0 - root_gap1)))
	stations.append_array(roots)
	stations.sort()
	for panel_index in range(stations.size() - 1):
		var panel_x0 := stations[panel_index]
		var panel_x1 := stations[panel_index + 1]
		if panel_x1 - panel_x0 <= 0.001:
			continue
		var panel_main0 := _witch_bay_gable_wall_top(faces, panel_x0, wall_z)
		var panel_main1 := _witch_bay_gable_wall_top(faces, panel_x1, wall_z)
		var panel_bay0 := _witch_bay_shed_wall_top(bay, panel_x0)
		var panel_bay1 := _witch_bay_shed_wall_top(bay, panel_x1)
		var panel_gap0 := panel_bay0 - panel_main0
		var panel_gap1 := panel_bay1 - panel_main1
		if maxf(panel_gap0, panel_gap1) <= 0.001:
			continue
		var closure := PackedVector3Array()
		if panel_gap0 <= 0.001:
			closure.append(Vector3(panel_x0, panel_main0, wall_z))
			closure.append(Vector3(panel_x1, panel_main1, wall_z))
			closure.append(Vector3(panel_x1, panel_bay1, wall_z))
		elif panel_gap1 <= 0.001:
			closure.append(Vector3(panel_x0, panel_main0, wall_z))
			closure.append(Vector3(panel_x1, panel_main1, wall_z))
			closure.append(Vector3(panel_x0, panel_bay0, wall_z))
		else:
			closure.append(Vector3(panel_x0, panel_main0, wall_z))
			closure.append(Vector3(panel_x1, panel_main1, wall_z))
			closure.append(Vector3(panel_x1, panel_bay1, wall_z))
			closure.append(Vector3(panel_x0, panel_bay0, wall_z))
		if closure.size() >= 3:
			out.append(closure)
	return out
func _build_witch_bay_outboard_gables(xf: Transform3D, bay: Dictionary,
		faces: Array[PackedVector3Array]) -> void:
	if int(bay.get("axis", -1)) != 0:
		return
	var service_normal: Vector2 = Vector2(bay["normal"]).normalized()
	var core_edge := float(bay.get("wall_outer", bay["inner"]))
	var wall_t := HouseGeometry.wall_thickness(spec)
	for run_variant in HouseGeometry.exterior_runs(spec, 0):
		var end_run: Dictionary = run_variant
		var end_normal: Vector2 = end_run["normal"]
		if absf(end_normal.dot(service_normal)) > 0.10:
			continue
		var from: Vector2 = end_run["from"]
		var to: Vector2 = end_run["to"]
		# The end wall meets the Witch service-side exterior wall at the corner
		# farthest along the service normal. exterior_runs already locates this
		# at the measured wall centre line (site edge inset by half wall depth).
		var corner := from if from.dot(service_normal) >= to.dot(service_normal) else to
		var local_corner: Vector3 = xf.affine_inverse() * Vector3(corner.x, xf.origin.y, corner.y)
		var end_wall_z := local_corner.z
		var cross_lo := minf(local_corner.x, core_edge)
		var cross_hi := maxf(local_corner.x, core_edge)
		if cross_hi - cross_lo <= 0.02:
			continue
		var actual_end_profile := RoofShape.wall_profile(faces,
			Vector2(cross_lo, end_wall_z), Vector2(cross_hi, end_wall_z))
		var panels := _witch_bay_gable_closure_profiles(faces,
			Vector2(cross_lo, end_wall_z), Vector2(cross_hi, end_wall_z),
			bay, actual_end_profile)
		for panel in panels:
			if panel.size() >= 3:
				_roof_face(xf, panel, SURF_WALL, "roof_wall", false, wall_t)

func _witch_bay_gable_wall_top(faces: Array[PackedVector3Array], x: float, z: float) -> float:
	var roof_y := RoofShape.height_at(faces, Vector2(x, z))
	return maxf(0.0, roof_y - RoofShape.DEPTH * 0.5) if is_finite(roof_y) else 0.0

func _witch_bay_shed_wall_top(bay: Dictionary, x: float) -> float:
	var cross_t := clampf((x - float(bay["outer"])) / (float(bay["inner"]) - float(bay["outer"])), 0.0, 1.0)
	return float(bay["eave_y"]) + (float(bay["join_y"]) - float(bay["eave_y"])) * cross_t - RoofShape.DEPTH * 0.5 + 0.005


func _build_witch_workshop_bay_roof(xf: Transform3D, bay: Dictionary, faces: Array[PackedVector3Array]) -> void:
	var axis := int(bay["axis"])
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var lo := float(bay["along_lo"])
	var hi := float(bay["along_hi"])
	var eave_y := float(bay["eave_y"])
	var join_y := float(bay["join_y"])
	var host_y := float(bay["host_y"])
	var a := Vector3(outer, eave_y, lo) if axis == 0 else Vector3(lo, eave_y, outer)
	var b := Vector3(outer, eave_y, hi) if axis == 0 else Vector3(hi, eave_y, outer)
	var c := Vector3(inner, join_y, hi) if axis == 0 else Vector3(hi, join_y, inner)
	var d := Vector3(inner, join_y, lo) if axis == 0 else Vector3(lo, join_y, inner)
	tag("witch_workshop_bay")
	host("roof", _storeys() - 1)
	_roof_face(xf, PackedVector3Array([a, b, c, d]), SURF_ROOF, "witch_workshop_bay_roof")
	if HouseGeometry.has_witch_roofcraft(spec, plan.world_family):
		_build_witch_bay_thatch_eave(xf, bay)
	# A framed infill closes the stepped junction against the higher host roof.
	var fascia_a := Vector3(inner, join_y, lo) if axis == 0 else Vector3(lo, join_y, inner)
	var host_y_lo := float(bay.get("host_y_lo", host_y))
	var host_y_hi := float(bay.get("host_y_hi", host_y))
	var fascia_b := Vector3(inner, host_y_lo, lo) if axis == 0 else Vector3(lo, host_y_lo, inner)
	var fascia_c := Vector3(inner, host_y_hi, hi) if axis == 0 else Vector3(hi, host_y_hi, inner)
	var fascia_d := Vector3(inner, join_y, hi) if axis == 0 else Vector3(hi, join_y, inner)
	if maxf(host_y_lo, host_y_hi) > join_y + 0.04:
		_roof_face(xf, PackedVector3Array([fascia_a, fascia_b, fascia_c, fascia_d]), SURF_WALL, "witch_workshop_bay_host_fascia", false, HouseGeometry.wall_thickness(spec))
	_build_witch_workshop_bay_returns(xf, bay, faces)
	_build_witch_workshop_bay_bearing(xf, bay)
	_build_witch_workshop_bay_supports(xf, bay)


## Combed reeds cap the exposed outer edge of the lower service roof. The
## profile is derived from the actual shed plane and bears at both ends on that
## plane; it does not pretend the interrupted high-roof eave continues through
## the bay.
func _build_witch_bay_thatch_eave(xf: Transform3D, bay: Dictionary) -> void:
	var axis := int(bay["axis"])
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var lo := float(bay["along_lo"])
	var hi := float(bay["along_hi"])
	var eave_y := float(bay["eave_y"]) + RoofShape.DEPTH * 0.5
	var join_y := float(bay["join_y"]) + RoofShape.DEPTH * 0.5
	var cross_run := absf(inner - outer)
	if cross_run <= 0.10 or hi - lo <= 0.10:
		return
	var slope := Vector2(signf(inner - outer) * cross_run, join_y - eave_y)
	var slope_length := slope.length()
	if slope_length <= 0.10:
		return
	var outward_normal := Vector2(-slope.y, slope.x).normalized()
	if outward_normal.y < 0.0:
		outward_normal = -outward_normal
	var bundle_run := minf(0.28, slope_length * 0.55)
	var shoulder := HouseGeometry.THATCH_EAVE_H * 0.42
	var crown := HouseGeometry.THATCH_EAVE_H
	var profile := PackedVector3Array()
	for entry in [Vector2(0.0, 0.0), Vector2(0.25, shoulder),
			Vector2(0.5, crown), Vector2(0.75, shoulder), Vector2(1.0, 0.0)]:
		var distance: float = bundle_run * entry.x
		var t: float = distance / slope_length
		var cross_coord := lerpf(outer, inner, t)
		var roof_y := lerpf(eave_y, join_y, t)
		var cross_point: Vector2 = Vector2(cross_coord, roof_y) + outward_normal * entry.y
		profile.append(Vector3(cross_point.x, cross_point.y, (lo + hi) * 0.5)
			if axis == 0 else Vector3((lo + hi) * 0.5, cross_point.y, cross_point.x))
	tag("thatch_eave")
	host("witch_workshop_bay_roof", _storeys() - 1)
	_roof_face(xf, profile, SURF_ROOF, "thatch_eave_service", false, hi - lo)
	host_end()


func _build_witch_workshop_bay_returns(xf: Transform3D, bay: Dictionary, faces: Array[PackedVector3Array]) -> void:
	if int(bay["axis"]) != 0:
		return
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var lo := float(bay["along_lo"])
	var hi := float(bay["along_hi"])
	var partition_head := float(bay.get("partition_head_y", 0.0))
	var wall_t := HouseGeometry.wall_thickness(spec)
	var endpoints: Array[Dictionary] = [
		{"z": lo, "internal": bool(bay.get("return_at_lo", false))},
		{"z": hi, "internal": bool(bay.get("return_at_hi", false))},
	]
	var emitted := false
	for endpoint in endpoints:
		if not bool(endpoint["internal"]):
			continue # the outer gable continues to its roof edge; it is not a return wall
		var z := float(endpoint["z"])
		var main_outer := RoofShape.height_at(faces, Vector2(outer, z)) - RoofShape.DEPTH * 0.5
		var main_inner := RoofShape.height_at(faces, Vector2(inner, z)) - RoofShape.DEPTH * 0.5
		if not is_finite(main_inner):
			continue
		if not is_finite(main_outer):
			main_outer = float(bay["eave_y"]) - RoofShape.DEPTH * 0.5
		if maxf(maxf(partition_head, main_outer), main_inner) <= partition_head + 0.04:
			continue
		# The internal return rises from the actual partition wall head and
		# closes only the remaining host-roof void above the shed junction.
		var points := PackedVector3Array([
			Vector3(outer, partition_head, z), Vector3(inner, partition_head, z),
			Vector3(inner, main_inner, z), Vector3(outer, maxf(partition_head, main_outer), z)])
		if not emitted:
			tag("witch_workshop_bay_returns")
			host("witch_workshop_bay_returns", 0)
			emitted = true
		_roof_face(xf, points, SURF_WALL, "witch_workshop_bay_return", false, wall_t)
	if emitted:
		host_end()


func _build_witch_workshop_bay_supports(xf: Transform3D, bay: Dictionary, ground_offset := 0.0) -> void:
	var axis := int(bay["axis"])
	var outer := float(bay["outer"])
	var lo := float(bay["along_lo"])
	var hi := float(bay["along_hi"])
	var eave_y := float(bay["eave_y"])
	var beam_h := 0.16
	var beam_w := 0.18
	var beam_y := eave_y - RoofShape.DEPTH * 0.5 - beam_h * 0.5
	var beam_center := Vector3(outer, beam_y, (lo + hi) * 0.5) if axis == 0 else Vector3((lo + hi) * 0.5, beam_y, outer)
	var beam_size := Vector3(beam_w, beam_h, hi - lo) if axis == 0 else Vector3(hi - lo, beam_h, beam_w)
	tag("witch_workshop_bay_supports")
	host("witch_workshop_bay_frame", 0)
	component_box("witch_workshop_bay_eave_beam", beam_size, xf * Transform3D(Basis(), beam_center), SURF_TRIM)
	var post_h := maxf(xf.origin.y + beam_y - beam_h * 0.5 - ground_offset, 0.0)
	var post_w := 0.16
	for station in [lo + post_w * 0.5, hi - post_w * 0.5]:
		var post_center := Vector3(outer, -xf.origin.y + ground_offset + post_h * 0.5, station) if axis == 0 else Vector3(station, -xf.origin.y + ground_offset + post_h * 0.5, outer)
		component_box("witch_workshop_bay_post", Vector3(post_w, post_h, post_w), xf * Transform3D(Basis(), post_center), SURF_TRIM)
	host_end()


func _emit_ridge_cap_segments(xf: Transform3D, rise: float,
		ridge_half: float, authored: Array, ridge_x := 0.0) -> void:
	var ranges: Array[Vector2] = [Vector2(-ridge_half, ridge_half)]
	for op in authored:
		var hole: Rect2 = Poly.bounding_rect(op["polygon"])
		if hole.end.x < ridge_x - 0.11 or hole.position.x > ridge_x + 0.11:
			continue
		var next: Array[Vector2] = []
		for span in ranges:
			if hole.end.y <= span.x or hole.position.y >= span.y:
				next.append(span)
				continue
			if hole.position.y > span.x + 0.02:
				next.append(Vector2(span.x, minf(hole.position.y, span.y)))
			if hole.end.y < span.y - 0.02:
				next.append(Vector2(maxf(hole.end.y, span.x), span.y))
		ranges = next
	for span in ranges:
		if span.y - span.x <= 0.02:
			continue
		component_box("ridge_cap", Vector3(0.22, 0.16, span.y - span.x),
			xf * Transform3D(Basis(), Vector3(ridge_x, rise + 0.14,
			(span.x + span.y) * 0.5)), SURF_ROOF)


## Record an authored opening only when it lies on an emitted roof face. A
## malformed/off-roof request therefore cannot masquerade as proof of a cut.
func _record_sloped_roof_openings(layout: Dictionary, authored: Array) -> void:
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	for op in authored:
		var poly: PackedVector2Array = op["polygon"]
		var covered := false
		for face in faces:
			if Poly.intersection_area(RoofShape.footprint(face), poly) > 0.0001:
				covered = true
				break
		if not covered:
			continue
		var centre := Poly.bounding_rect(poly).get_center()
		var h := RoofShape.height_at(faces, centre)
		if not is_finite(h):
			h = spec.height * _storeys()
		var world_poly := PackedVector3Array()
		for p in poly:
			var ph := RoofShape.height_at(faces, p)
			if not is_finite(ph):
				ph = h
			world_poly.append(xf * Vector3(p.x, ph, p.y))
		_record_roof_opening(op, world_poly, xf * Vector3(centre.x, h, centre.y))


func _record_court_roof_openings(wall_top: float) -> void:
	for op in HouseGeometry.roof_openings(plan):
		if op["kind"] == &"dormer":
			continue
		var poly: PackedVector2Array = op["polygon"]
		var inside_court := false
		for court in plan.courts:
			if Poly.intersection_area(poly, Poly.from_rect(Rect2(court["rect"]))) > 0.0001:
				inside_court = true
				break
		if not inside_court:
			continue
		var centre := Poly.bounding_rect(poly).get_center()
		_record_roof_opening(op, PackedVector3Array([
			Vector3(poly[0].x, wall_top, poly[0].y),
			Vector3(poly[1].x, wall_top, poly[1].y),
			Vector3(poly[2].x, wall_top, poly[2].y)]),
			Vector3(centre.x, wall_top, centre.y))


func _record_roof_opening(op: Dictionary, world_poly: PackedVector3Array,
		centre: Vector3) -> void:
	if world_poly.size() < 3:
		return
	var box := AABB(world_poly[0], Vector3.ZERO)
	for p in world_poly:
		box = box.expand(p)
	var row := {"id": String(op["id"]), "kind": op["kind"],
		"storey": int(op["storey"]), "room": int(op.get("room", -1)),
		"polygon": op["polygon"], "world_polygon": world_poly,
		"aabb": box, "center": centre}
	roof_opening_log.append(row)
	part_log.append({"kind": "roof_opening", "id": row["id"],
		"opening_kind": row["kind"], "storey": row["storey"],
		"room": row["room"], "pos": centre, "size": box.size,
		"rot_y": 0.0, "facing": Vector3.UP, "tag": _tag})


func _roof_face(xf: Transform3D, local: PackedVector3Array, surface: int,
		role: String, vertical := true, depth := RoofShape.DEPTH) -> void:
	var world := PackedVector3Array()
	for p in local:
		world.append(xf * p)
	# One row, two readers: roof_components is the roof-shaped view the roof
	# suites already measure, component_log is the whole-exterior view. They
	# are the SAME dictionary, so they cannot drift apart.
	roof_components.append(component_slab(role, world, depth, surface, vertical))


## Keep the four-slot shell contract, including roof-off builds. A vertex
## marker selects fixed glazing treatment inside the house roof material;
## it is not a fifth stream which Godot would compact when the roof is empty.
func _glazing_box(role: String, size: Vector3, xf: Transform3D) -> void:
	_kit.surface(SURF_ROOF).set_color(Color.BLACK)
	component_box(role, size, xf, SURF_ROOF)
	_kit.surface(SURF_ROOF).set_color(Color.WHITE)


func _build_bargeboards(xf: Transform3D, span: float, along: float, rise: float,
		top: float, ridge_x := 0.0) -> void:
	if not spec.bargeboards:
		return
	tag("bargeboards")
	# The eave the board is nailed to is the roof this house actually built,
	# not a hard-coded 0.35 m: a house with a deeper eave gets its verge board
	# at that eave, and `verge_overhang` reads the same number.
	var half: float = (span + HouseGeometry.roof_span_out(spec) * 2.0) * 0.5
	var ang := atan2(rise, half)
	var bb_w: float = HouseGeometry.BARGEBOARD_W
	var bb_thick := 0.05
	var kick: float = HouseGeometry.VERGE_KICK
	# where the board finishes: the apex, or the hip line on a half hip
	var up := Vector2(half * (1.0 - top / rise), top)
	for end_v in [-1.0, 1.0]:
		var z: float = float(end_v) * (along / 2.0 + HouseGeometry.VERGE_END_OUT)
		for side in [-1.0, 1.0]:
			var a := Vector2(float(side) * half, 0.0)
			var b := Vector2(ridge_x + float(side) * (up.x if absf(ridge_x) < 0.001 else 0.0), up.y)
			var dir: Vector2 = (a - b).normalized()
			var foot: Vector2 = a + dir * kick
			var mid: Vector2 = (foot + b) / 2.0
			var board_angle := -float(side) * ang if absf(ridge_x) < 0.001 else atan2((b - a).y, (b - a).x)
			var t := xf * Transform3D(Basis(Vector3(0, 0, 1), board_angle),
				Vector3(mid.x, mid.y, z))
			component_box("verge_board", Vector3((foot - b).length(), bb_w, bb_thick),
				t, SURF_TRIM)
		# A finial stands on an apex. A half hip has none, so it gets none.
		if is_equal_approx(top, rise):
			component_box("verge_finial",
				Vector3(HouseGeometry.FINIAL_D, 0.55, HouseGeometry.FINIAL_D),
				xf * Transform3D(Basis(), Vector3(ridge_x, rise + 0.22, z)), SURF_TRIM)
		# Drop pendants at the eaves
		for side2 in [-1.0, 1.0]:
			component_box("verge_pendant", Vector3(HouseGeometry.VERGE_PENDANT_D,
				0.24, HouseGeometry.VERGE_PENDANT_D),
				xf * Transform3D(Basis(), Vector3(float(side2) * half, -0.05, z)),
				SURF_TRIM)


## The obelisk that crowns a rich ridge (HOUSE-RICH), standing on the ridge
## cap beside the verge boards rather than as part of them.
##
## It is emitted in the roof's own frame at exactly the height
## HouseGeometry.roof_top_above_walls adds to the rise, so the silhouette the
## exterior bound promises and the mesh that bound must contain agree to the
## millimetre rather than to a tolerance. A roof with no ridge to stand on
## gets no crown, and the bound knows it too.
func _build_ridge_crown(xf: Transform3D, rise: float, ridge: float, ridge_x := 0.0) -> void:
	if not spec.ridge_finial or ridge <= 0.05:
		return
	tag("ridge_crown")
	host("ridge_crown", _storeys() - 1)
	var seat: float = rise + HouseGeometry.RIDGE_CAP_TOP
	component_box("ridge_crown_plinth",
		Vector3(HouseGeometry.CROWN_BASE_W, HouseGeometry.CROWN_BASE_H,
			HouseGeometry.CROWN_BASE_W),
		xf * Transform3D(Basis(), Vector3(ridge_x,
			seat + HouseGeometry.CROWN_BASE_H * 0.5, 0.0)), SURF_TRIM)
	component_box("ridge_crown",
		Vector3(HouseGeometry.CROWN_W, HouseGeometry.CROWN_H, HouseGeometry.CROWN_W),
		xf * Transform3D(Basis(), Vector3(ridge_x, seat + HouseGeometry.CROWN_BASE_H
			+ HouseGeometry.CROWN_H * 0.5, 0.0)), SURF_TRIM)
	host_end()


func _build_eaves_tails(xf: Transform3D, span: float, along: float, rise: float) -> void:
	if spec.roof_type == &"flat":
		return
	tag("eaves")
	# Half a wall's span, plus the 0.15 m the tails always stood out, plus
	# whatever EXTRA eave this house has. Adding the extra rather than reading
	# a resolved number is what keeps an ordinary eave bit-for-bit what it was.
	var extra: float = maxf(0.0, HouseGeometry.roof_span_out(spec) - HouseGeometry.ROOF_SPAN_OUT)
	var half: float = span / 2.0
	var tail_spacing := 0.75
	var count := maxi(int(along / tail_spacing), 3)
	for side in [-1.0, 1.0]:
		var ex: float = float(side) * (half + HouseGeometry.EAVE_TAIL_OUT + extra)
		for i in range(count + 1):
			var ez: float = -along / 2.0 + float(i) * (along / float(count))
			component_box("eave_tail", Vector3(0.12, 0.09, 0.22),
				xf * Transform3D(Basis(), Vector3(ex, -0.05, ez)), SURF_TRIM)


func _build_dormers(xf: Transform3D, dormers: Array) -> void:
	# A dormer is a BUILDING PART, not three loose boxes on the roof: give it
	# its own host so QA can ask what dormer_1 is made of, and notice when one
	# of its pieces goes missing or slides off the slope it sits on.
	for d in dormers:
		host(String(d["id"]), _storeys() - 1)
		var front: float = d["front"]
		var z: float = d["z"]
		var base: float = d["base"] - RoofShape.DEPTH * 0.5
		var eave: float = d["eave"]
		var hw: float = float(d["width"]) * 0.5
		var rh: float = d["roof_half"]
		var peak: float = eave + 0.45
		var side_top := eave + 0.45 * (1.0 - hw / rh) - RoofShape.DEPTH * 0.5
		var role: String = d["id"]
		# Rooflets end on the actual valley line, not in a rectangular box
		# behind the host slope. Cheeks taper to zero at that same intersection.
		for side in [-1.0, 1.0]:
			_roof_face(xf, PackedVector3Array([
				Vector3(front - 0.12, eave, z + side * rh),
				Vector3(d["side_x"], eave, z + side * rh),
				Vector3(d["peak_x"], peak, z),
				Vector3(front - 0.12, peak, z)]), SURF_ROOF, role + "_roof")
			_roof_face(xf, PackedVector3Array([
				Vector3(front, base, z + side * hw),
				Vector3(front, side_top, z + side * hw),
				Vector3(d["cheek_x"], side_top, z + side * hw)]),
				SURF_WALL, role + "_cheek", false, 0.08)
		var head := eave - RoofShape.DEPTH * 0.5
		_roof_face(xf, PackedVector3Array([
			Vector3(front, head, z - hw), Vector3(front, head, z + hw),
			Vector3(front, side_top, z + hw),
			Vector3(front, peak - RoofShape.DEPTH * 0.5, z),
			Vector3(front, side_top, z - hw)]), SURF_WALL, role + "_gable", false, 0.10)
		var win_bottom := base + 0.20
		var win_top := head - 0.13
		var win_w := float(d["width"]) * 0.65
		for side in [-1.0, 1.0]:
			component_box("dormer_jamb", Vector3(0.10, head - base, hw - win_w * 0.5),
				xf * Transform3D(Basis(), Vector3(front, (head + base) * 0.5,
					z + side * (hw + win_w * 0.5) * 0.5)), SURF_TRIM)
		for band in [[base, win_bottom], [win_top, head]]:
			component_box("dormer_panel", Vector3(0.10, band[1] - band[0], win_w),
				xf * Transform3D(Basis(), Vector3(front, (band[0] + band[1]) * 0.5, z)), SURF_TRIM)
		_glazing_box("dormer_glazing", Vector3(0.04, win_top - win_bottom, win_w),
			xf * Transform3D(Basis(), Vector3(front - 0.04, (win_top + win_bottom) * 0.5, z)))
		component_box("dormer_mullion", Vector3(0.05, win_top - win_bottom, 0.055),
			xf * Transform3D(Basis(), Vector3(front - 0.065, (win_top + win_bottom) * 0.5, z)), SURF_TRIM)
		host("roof", _storeys() - 1)


## The frame in the gable -- and every member of it stays UNDER THE RAFTERS.
##
## Each strut used to be stated as a run, a lift and a tilt that all had to
## agree with a roof pitch stated somewhere else, and they did not. A
## queen-post strut ran up-and-OUT from its post while the rafter it braces
## runs down-and-out, so the strut left the roof and finished three and a half
## metres out in the open air, reading as a stray roof plane crossing the real
## ones. Members are stated by their two ENDS now, and the outer end is put ON
## the rafter line rather than guessed at, so a member cannot escape the roof
## whatever the pitch turns out to be.
func _gable_frame(xf: Transform3D, span: float, along: float, rise: float,
		top: float) -> void:
	var half: float = span / 2.0
	# The slabs overhang the wall, so the rafter over the wall face is a little
	# higher than the wall head: this is the roof's half span, not the wall's.
	var roof_half: float = (span + 0.7) / 2.0
	_frame_top = top
	for end_v in [-1.0, 1.0]:
		var z: float = end_v * (along / 2.0 + HouseGeometry.BEAM_D / 2.0 - 0.01)
		# Tie beam across the base of the gable
		component_box("gable_tie", Vector3(span, HouseGeometry.PLATE_H, HouseGeometry.BEAM_D),
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
func _witch_gable_frame(xf: Transform3D, span: float, along: float,
		rise: float, ridge_x: float, bay: Dictionary = {},
		roof_faces: Array[PackedVector3Array] = []) -> void:
	# Rafters sit just inside the real roof slab and bear on the wall plate.
	var roof_half := (span + HouseGeometry.roof_span_out(spec) * 2.0) * 0.5
	var wall_half := span * 0.5
	var frame_rise := rise
	var collar_raw := frame_rise * 0.48
	var collar_t := collar_raw / frame_rise
	var left_collar_x := lerpf(-roof_half, ridge_x, collar_t)
	var right_collar_x := lerpf(roof_half, ridge_x, collar_t)
	var left_collar_y := _witch_roof_y(-roof_half, 0.0, ridge_x, frame_rise, left_collar_x)
	var right_collar_y := _witch_roof_y(roof_half, 0.0, ridge_x, frame_rise, right_collar_x)
	_frame_top = frame_rise
	for end_v in [-1.0, 1.0]:
		var z: float = float(end_v) * (along / 2.0 + HouseGeometry.BEAM_D / 2.0 - 0.01)
		if not bay.is_empty() and z >= float(bay["along_lo"]) and z <= float(bay["along_hi"]):
			continue # this gable frame station is cut by the actual shed roof plane
		component_box("gable_tie", Vector3(span, HouseGeometry.PLATE_H, HouseGeometry.BEAM_D),
			xf * Transform3D(Basis(), Vector3(0.0, HouseGeometry.PLATE_H / 2.0, z)), SURF_TRIM)
		if HouseGeometry.uses_witch_half_hip_roof(spec, plan.world_family) and not roof_faces.is_empty():
			# Use roof-plane-clipped timber strips. Their upper faces sit 2 mm
			# below emitted slab undersides; inboard ends are the established
			# analytic birdsmouth seats on the wall plate. Clipping every piece to
			# its host roof polygon mitres the shoulder/hip edges.
			_emit_witch_half_hip_end_frame(xf, span, along, rise, ridge_x,
				roof_faces, float(end_v), z)
			continue
		var left_a := _witch_rafter_foot(-1.0, roof_half, wall_half, ridge_x, frame_rise)
		var right_a := _witch_rafter_foot(1.0, roof_half, wall_half, ridge_x, frame_rise)
		var ridge := Vector2(ridge_x, frame_rise)
		var left_rafter := _witch_rafter_points(left_a, ridge)
		var right_rafter := _witch_rafter_points(right_a, ridge)
		_witch_gable_member(xf, left_rafter[0], left_rafter[1], z, HouseGeometry.BEAM_W, "witch_rafter")
		_witch_gable_member(xf, right_rafter[0], right_rafter[1], z, HouseGeometry.BEAM_W, "witch_rafter")
		var collar_offset := HouseGeometry.BEAM_W * 0.9 * 0.5
		var left_n := _witch_roof_up_normal(left_a, ridge)
		var right_n := _witch_roof_up_normal(right_a, ridge)
		var left_collar := Vector2(left_collar_x, left_collar_y) - left_n * collar_offset
		var right_collar := Vector2(right_collar_x, right_collar_y) - right_n * collar_offset
		_witch_gable_member(xf, left_collar, right_collar, z, HouseGeometry.BEAM_W * 0.9, "witch_collar")
		_witch_gable_member(xf, Vector2(ridge_x, HouseGeometry.PLATE_H),
			Vector2(ridge_x, frame_rise - RoofShape.DEPTH * 0.5 - 0.001), z, HouseGeometry.BEAM_W, "witch_kingpost")
		# Unequal roof pitches get paired raking braces. Each lower end bears on
		# the collar and each upper end lands on the measured principal-rafter
		# centreline, making the asymmetry structural rather than painted on.
		var brace_width := HouseGeometry.BEAM_W * 0.72
		var left_brace_start := left_collar.lerp(right_collar, 0.22)
		var right_brace_start := left_collar.lerp(right_collar, 0.78)
		var left_run := left_rafter[0].distance_to(left_rafter[1])
		var right_run := right_rafter[0].distance_to(right_rafter[1])
		# Give the longer roof plane the deeper brace. The measured sloping runs
		# set unequal supports without moving either end off its bearing member.
		var support_bias := clampf(absf(left_run - right_run) * 0.075, 0.0, 0.10)
		var deep_t := 0.72 + support_bias
		var shallow_t := 0.72 - support_bias
		var left_t := deep_t if left_run > right_run else shallow_t
		var right_t := deep_t if right_run > left_run else shallow_t
		var left_brace_end := left_rafter[0].lerp(left_rafter[1], left_t)
		var right_brace_end := right_rafter[0].lerp(right_rafter[1], right_t)
		_witch_gable_member(xf, left_brace_start, left_brace_end, z, brace_width, "witch_gable_raking_brace")
		_witch_gable_member(xf, right_brace_start, right_brace_end, z, brace_width, "witch_gable_raking_brace")


func _emit_witch_half_hip_end_frame(xf: Transform3D, span: float, along: float,
		rise: float, ridge_x: float, faces: Array[PackedVector3Array],
		end_sign: float, station: float) -> void:
	var roof_half := (span + HouseGeometry.roof_span_out(spec) * 2.0) * 0.5
	var wall_half := span * 0.5
	var band_half := HouseGeometry.BEAM_D * 0.5
	for side in [-1.0, 1.0]:
		var foot := _witch_rafter_foot(side, roof_half, wall_half, ridge_x, rise)
		var side_face_index := 0 if side < 0.0 else 1
		var subject := PackedVector2Array([
			Vector2(minf(foot.x, ridge_x), station - band_half),
			Vector2(maxf(foot.x, ridge_x), station - band_half),
			Vector2(maxf(foot.x, ridge_x), station + band_half),
			Vector2(minf(foot.x, ridge_x), station + band_half),
		])
		_emit_witch_roof_support_strip(xf, faces[side_face_index], subject,
			"witch_half_hip_end_rafter")
	# Each diagonal hip seam carries a timber under its actual hip plane. The
	# clipped strips end on the shoulder and ridge edges, where the side rafters
	# and ridge support meet them; no rectangular bar crosses either seam.
	var hip_face_index := 2 if end_sign < 0.0 else 3
	var hip_face: PackedVector3Array = faces[hip_face_index]
	var ridge_tip := Vector2(hip_face[2].x, hip_face[2].z)
	for shoulder_index in [0, 1]:
		var shoulder := Vector2(hip_face[shoulder_index].x, hip_face[shoulder_index].z)
		var direction := (ridge_tip - shoulder).normalized()
		var across := Vector2(-direction.y, direction.x) * HouseGeometry.BEAM_W * 0.5
		var subject := PackedVector2Array([
			shoulder + across, ridge_tip + across,
			ridge_tip - across, shoulder - across,
		])
		_emit_witch_roof_support_strip(xf, hip_face, subject,
			"witch_half_hip_end_hip_rafter")


func _emit_witch_roof_support_strip(xf: Transform3D,
		face: PackedVector3Array, subject: PackedVector2Array, role: String) -> void:
	var footprint := RoofShape.footprint(face)
	var clipped := Poly.clip_convex(subject, footprint)
	if Poly.area(clipped) < 0.003:
		return
	var normal := (face[1] - face[0]).cross(face[2] - face[0])
	if normal.y < 0.0:
		normal = -normal
	normal = normal.normalized()
	var points := RoofShape.lift(clipped, face)
	for i in range(points.size()):
		# The roof midpoint minus half DEPTH is its actual emitted underside.
		# The timber prism is centred one half-width below that plane so its
		# upper face has a measured 2 mm air gap and its lower face carries load.
		points[i] -= Vector3.UP * (RoofShape.DEPTH * 0.5 + 0.002)
		points[i] -= normal * (HouseGeometry.BEAM_W * 0.5)
		points[i] = xf * points[i]
	component_slab(role, points, HouseGeometry.BEAM_W, SURF_TRIM, false)


func _witch_rafter_foot(side: float, roof_half: float, wall_half: float,
		ridge_x: float, rise: float) -> Vector2:
	var eave_x := side * roof_half
	var ridge := Vector2(ridge_x, rise)
	var eave := Vector2(eave_x, 0.0)
	var normal := _witch_roof_up_normal(eave, ridge)
	# Place the foot inside the wall span where the rafter underside meets the
	# centre of the measured tie plate. This is a birdsmouth seat, not a guess.
	# The rafter's lower face, not its centre plane, lands on the tie top.
	# Account for the full beam depth and the vertical-depth roof underside.
	var seat_y := HouseGeometry.PLATE_H + RoofShape.DEPTH * 0.5 + 0.002 \
		+ normal.y * HouseGeometry.BEAM_W
	var t := clampf(seat_y / rise, 0.0, 1.0)
	var bearing_margin := 0.02
	var min_roof_x := -wall_half + bearing_margin + normal.x * HouseGeometry.BEAM_W
	var max_roof_x := wall_half - bearing_margin + normal.x * HouseGeometry.BEAM_W
	var x := clampf(lerpf(eave_x, ridge_x, t), min_roof_x, max_roof_x)
	return Vector2(x, _witch_roof_y(eave_x, 0.0, ridge_x, rise, x))


func _witch_roof_y(eave_x: float, eave_y: float, ridge_x: float, rise: float, x: float) -> float:
	if x <= ridge_x:
		return lerpf(eave_y, rise, inverse_lerp(eave_x, ridge_x, x))
	return lerpf(rise, eave_y, inverse_lerp(ridge_x, eave_x, x))


func _witch_roof_up_normal(a: Vector2, b: Vector2) -> Vector2:
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	return normal if normal.y >= 0.0 else -normal


func _witch_rafter_points(eave: Vector2, ridge: Vector2) -> PackedVector2Array:
	var normal := _witch_roof_up_normal(eave, ridge)
	var offset := normal * (HouseGeometry.BEAM_W * 0.5) + Vector2(0.0, RoofShape.DEPTH * 0.5 + 0.001)
	return PackedVector2Array([eave - offset, ridge - offset])


func _witch_gable_member(xf: Transform3D, a: Vector2, b: Vector2, z: float,
		width: float, role: String) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.05:
		return
	var centre := (a + b) * 0.5
	component_box(role, Vector3(length, width, HouseGeometry.BEAM_D),
		xf * Transform3D(Basis(Vector3(0, 0, 1), atan2(delta.y, delta.x)),
			Vector3(centre.x, centre.y, z)), SURF_TRIM)


func _under_rafter(x: float, roof_half: float, rise: float) -> float:
	return clampf(rise * (1.0 - absf(x) / roof_half) - RoofShape.DEPTH * 0.5 - HouseGeometry.BEAM_W * 0.5 - 0.02,
		0.0, maxf(_frame_top - RoofShape.DEPTH * 0.5 - HouseGeometry.BEAM_W * 0.5 - 0.02, 0.0))


## Where the gable the frame stands in stops, set by _gable_frame before it
## places anything. A truss inside a half-hipped gable may not climb past the
## hip any more than the wall may.
var _frame_top := INF


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
	component_box("gable_member", Vector3(run, width, HouseGeometry.BEAM_D),
		xf * Transform3D(Basis(Vector3(0, 0, 1), atan2(d.y, d.x)),
			Vector3(mid.x, mid.y, z)), SURF_TRIM)


func _build_porch() -> void:
	if not spec.porch:
		return
	var d: int = plan.entrance()
	if d < 0:
		return
	tag("porch")
	# A porch has a roof, and it is NOT the house's roof. Giving it its own
	# host is what keeps the vertical-shell check counting one main roof.
	host("porch", 0)
	var door: Dictionary = plan.doors[d]
	var depth: float = HouseGeometry.porch_depth(spec)
	var w: float = float(door["width"]) + 1.1
	var head: float = HouseGeometry.DOOR_H + 0.35
	if spec.style == &"witch_hut":
		# The witch canopy follows the actual entrance wall. Its step has the same
		# asymmetric in-wall/outward footprint as HouseGeometry.porch_rect().
		var normal: Vector2 = door["normal"]
		var across := Vector2(normal.y, -normal.x)
		var normal3 := Vector3(normal.x, 0.0, normal.y)
		var across3 := Vector3(across.x, 0.0, across.y)
		var frame := Basis(across3, Vector3.UP, normal3)
		var porch_wall: Vector2 = HouseGeometry.porch_center(plan)
		var step_span: float = depth + 0.2 + HouseGeometry.wall_thickness(spec)
		var step_centre2: Vector2 = porch_wall + normal * ((depth - HouseGeometry.wall_thickness(spec)) * 0.5)
		var step_centre := Vector3(step_centre2.x, HouseGeometry.FLOOR_T * 0.5, step_centre2.y)
		var step_xf := Transform3D(frame, step_centre)
		component_box("witch_entry_step", Vector3(w, HouseGeometry.FLOOR_T, step_span), step_xf, SURF_FLOOR)
		var step_half := across.abs() * (w * 0.5) + normal.abs() * (step_span * 0.5)
		_log_mass("porch_step", AABB(Vector3(step_centre2.x - step_half.x, 0.0,
			step_centre2.y - step_half.y), Vector3(step_half.x * 2.0, HouseGeometry.FLOOR_T,
			step_half.y * 2.0)))
		# Keep the full slab, including its normal thickness, between the
		# exterior wall face and the planned porch end. The 2 cm inset exceeds
		# this slope's 1.9 cm horizontal half-thickness.
		var roof_edge_inset := 0.02
		var roof_thickness := 0.10
		var roof_rise: float = minf(0.42, maxf(spec.height - head - roof_thickness * 0.5 - 0.02, 0.0))
		var porch_along: float = depth + 0.1 - HouseGeometry.wall_thickness(spec) - roof_edge_inset * 2.0
		var roof_near: float = HouseGeometry.wall_thickness(spec) + roof_edge_inset
		var roof_far: float = depth + 0.1 - roof_edge_inset
		var roof_centre2: Vector2 = porch_wall + normal * ((roof_near + roof_far) * 0.5)
		var roof_xf := Transform3D(frame, Vector3(roof_centre2.x, head, roof_centre2.y))
		# A wall ledger carries the canopy high edge on every cardinal facade.
		# Set the roof rise against the wall top, then place the ledger top at
		# the measured slab underside at its outer face. Its inner face sits
		# flush against the exterior wall; this is a bearing joint, not a gap.
		var roof_angle := atan2(roof_rise, porch_along)
		var ledger_depth := 0.10
		var ledger_height := 0.12
		var ledger_outer := HouseGeometry.wall_thickness(spec) + ledger_depth
		var ledger_top := head + roof_rise * (roof_far - ledger_outer) / porch_along
		ledger_top -= roof_thickness * 0.5 / cos(roof_angle)
		var ledger_centre2: Vector2 = porch_wall + normal * (HouseGeometry.wall_thickness(spec) + ledger_depth * 0.5)
		var ledger_xf := Transform3D(frame, Vector3(ledger_centre2.x, ledger_top - ledger_height * 0.5, ledger_centre2.y))
		component_box("witch_entry_wall_ledger", Vector3(w + 0.12, ledger_height, ledger_depth), ledger_xf, SURF_TRIM)
		var post_centre2: Vector2 = porch_wall + normal * (depth * 0.5)
		var post_along: float = depth - 0.12
		var post_top: float = head + roof_rise * (roof_far - post_along) / porch_along - roof_thickness * 0.5 / cos(roof_angle)
		for side in [-1.0, 1.0]:
			var post2: Vector2 = post_centre2 + across * side * (w * 0.5 - 0.1) + normal * (depth * 0.5 - 0.12)
			var post_xf := Transform3D(frame, Vector3(post2.x, post_top * 0.5, post2.y))
			component_box("witch_entry_support_%s" % ("left" if side < 0.0 else "right"),
				Vector3(0.14, post_top, 0.14), post_xf, SURF_TRIM)
			var post_half := across.abs() * 0.07 + normal.abs() * 0.07
			_log_mass("porch_post_%s" % ("left" if side < 0.0 else "right"),
				AABB(Vector3(post2.x - post_half.x, 0.0, post2.y - post_half.y),
					Vector3(post_half.x * 2.0, post_top, post_half.y * 2.0)))
		component_slab("witch_entry_lean_to", PackedVector3Array([
			roof_xf * Vector3(-w * 0.5, roof_rise, -porch_along * 0.5),
			roof_xf * Vector3(w * 0.5, roof_rise, -porch_along * 0.5),
			roof_xf * Vector3(w * 0.5, 0.0, porch_along * 0.5),
			roof_xf * Vector3(-w * 0.5, 0.0, porch_along * 0.5)]), roof_thickness, SURF_ROOF, false)
		host_end()
		return
	var normal: Vector2 = Vector2(door["normal"]).normalized()
	var wall_t: float = HouseGeometry.wall_thickness(spec)
	# Door positions are on the interior wall face. Start the canopy at the
	# exterior face, then run it outward to the existing porch bound. The old
	# centre-at-door-plus-half-depth formula began 10 cm inside the room.
	var outer_face: Vector2 = Vector2(door["pos"]) + normal * wall_t
	var porch_along: float = depth + 0.1 - wall_t
	var roof_centre: Vector2 = outer_face + normal * (porch_along / 2.0)
	var step_depth: float = depth + 0.2 + wall_t
	var step_centre: Vector2 = Vector2(door["pos"]) + normal * ((depth - wall_t) / 2.0)
	var step_size: Vector3 = Vector3(step_depth, HouseGeometry.FLOOR_T, w) \
		if absf(normal.x) > 0.5 else Vector3(w, HouseGeometry.FLOOR_T, step_depth)
	var step := AABB(Vector3(step_centre.x - step_size.x * 0.5, 0.0,
		step_centre.y - step_size.z * 0.5), step_size)
	box(step.size, step.position + step.size / 2.0, SURF_FLOOR)
	_log_mass("porch_step", step)
	var across: Vector2 = Vector2(normal.y, -normal.x)
	for side in [-1.0, 1.0]:
		var p: Vector2 = Vector2(door["pos"]) + across * (side * (w / 2.0 - 0.1)) \
			+ normal * (depth - 0.12)
		box(Vector3(0.14, head, 0.14), Vector3(p.x, head / 2.0, p.y), SURF_TRIM)
		_log_mass("porch_post_%s" % ("left" if side < 0.0 else "right"),
			AABB(Vector3(p.x - 0.07, 0.0, p.y - 0.07), Vector3(0.14, head, 0.14)))
	var yaw: float = atan2(normal.x, normal.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(roof_centre.x, head, roof_centre.y))
	component_note("porch_roof", "ridge", SURF_ROOF, {"xf": xf, "span": w,
		"along": porch_along, "rise": 0.42,
		"aabb": xf * AABB(Vector3(-w * 0.5, -RoofShape.DEPTH * 0.5,
			-porch_along * 0.5), Vector3(w, 0.42 + RoofShape.DEPTH, porch_along))})
	_kit.ridge_roof(xf, w, porch_along, 0.42, SURF_ROOF)
	host_end()


## The yard's BUILT pieces (HouseYard): rails, posts, logs, a trough, a lean-to.
## The plan owns every box; this only emits them, each as a named component on
## host "yard" carrying its piece id, so exterior QA can say which fence moved.
## Nothing here when `exterior_props` is off, so the bare shell is bit-identical.
func _build_yard() -> void:
	if not spec.exterior_props or plan.yard_pieces.is_empty():
		return
	tag("yard")
	host("yard", 0)
	for piece in plan.yard_pieces:
		for part in piece["parts"]:
			var surf := SURF_WALL if str(part["surf"]) == "wall" else SURF_TRIM
			if str(part["surf"]) == "roof":
				surf = SURF_ROOF
			if str(part["surf"]) == "floor":
				surf = SURF_FLOOR
				_kit.surface(surf).set_color(Color(1, 0, 1)) # Exterior paving, not timber or rug.
			var row := component_box(str(part["role"]), part["size"], HouseYard.part_xform(part), surf)
			_kit.surface(surf).set_color(Color.WHITE)
			row["piece"] = piece["id"]
	host_end()


## How far a flue finishes above the ridge it comes out of.
const CHIMNEY_CLEAR := 0.6


## Measure the roof where the flue actually passes through it. The roof skin
## sampler returns the slab top; Witch eave bundles are separate logged slabs
## emitted earlier in _build_roof, so include their local profile only where
## their emitted footprint covers one of the flue samples.
func _roof_top_surface_near_flue(centre: Vector2, footprint: Vector2, radius: float) -> float:
	var highest := _roof_top_surface_in_flue_footprint(centre, footprint)
	if not is_finite(highest):
		return NAN
	# Derive once for this measurement. Nothing is cached on the mutable plan.
	var layout := HouseGeometry.roof_layout(plan)
	var openings := HouseGeometry.roof_openings(plan)
	# Sample the actual plan roof planes across a fixed safety neighbourhood,
	# not only directly under masonry. The radial stations cover diagonal slopes
	# and eaves while keeping the local contract bounded around this flue.
	for ring in [0.25, 0.5, 1.0, 1.5, 2.0, 2.5, radius]:
		if float(ring) > radius:
			continue
		for sector in range(96):
			var angle := TAU * float(sector) / 96.0
			var sample := centre + Vector2(cos(angle), sin(angle)) * float(ring)
			if _witch_roof_sample_is_open(sample, layout, openings):
				continue
			var roof_y := HouseGeometry._roof_top_surface_in_layout(plan, layout, sample)
			if is_finite(roof_y):
				highest = maxf(highest, roof_y)
	# The ridge/eave bundles are emitted components above the plane. Their
	# measured profile vertices plus half the emitted slab depth bound the real
	# crown; only bundles whose emitted footprint enters the same radius count.
	for row in components("thatch_roll_") + components("thatch_eave"):
		var points: PackedVector3Array = row.get("points", PackedVector3Array())
		if points.is_empty():
			continue
		var depth_half := float(row.get("depth", 0.0)) * 0.5
		var profile_normal_y := 0.0
		if points.size() >= 3:
			profile_normal_y = absf((points[1] - points[0]).cross(points[2] - points[0]).normalized().y)
		var vertical_half := depth_half * profile_normal_y
		var enters_neighbourhood := false
		for point in points:
			if Vector2(point.x - centre.x, point.z - centre.y).length() <= radius + depth_half:
				enters_neighbourhood = true
				break
		if enters_neighbourhood:
			for point in points:
				highest = maxf(highest, point.y + vertical_half)
	# A centimetre covers the remaining angular sampling error in the bounded
	# neighbourhood. The public contract is minimum safe clearance, not a
	# falsely exact equality to a sampled mesh maximum.
	return highest + 0.01


func _witch_roof_sample_is_open(world_xz: Vector2, layout: Dictionary,
		openings: Array[Dictionary]) -> bool:
	var xf: Transform3D = layout["transform"]
	var local := xf.affine_inverse() * Vector3(world_xz.x, xf.origin.y, world_xz.y)
	var point := Vector2(local.x, local.z)
	for opening in openings:
		var polygon: PackedVector2Array = opening.get("polygon", PackedVector2Array())
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _roof_top_surface_in_flue_footprint(centre: Vector2, footprint: Vector2) -> float:
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var inverse := xf.affine_inverse()
	var highest := HouseGeometry.roof_top_surface_in_footprint(plan, centre, footprint)
	if not is_finite(highest):
		return NAN
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			var world_sample := centre + Vector2(float(fx) * footprint.x,
				float(fz) * footprint.y)
			var local_sample := inverse * Vector3(world_sample.x, xf.origin.y, world_sample.y)
			for row in components("thatch_eave"):
				if int(row.get("surface", -1)) != SURF_ROOF or String(row.get("form", "")) != "slab":
					continue
				var points: PackedVector3Array = row.get("points", PackedVector3Array())
				if points.size() < 2:
					continue
				var local_points := PackedVector3Array()
				for world_point in points:
					local_points.append(inverse * Vector3(world_point))
				var half_depth := float(row.get("depth", 0.0)) * 0.5
				var z_lo := local_points[0].z - half_depth
				var z_hi := local_points[0].z + half_depth
				if local_sample.z < z_lo - 0.001 or local_sample.z > z_hi + 0.001:
					continue
				for i in range(local_points.size() - 1):
					var a: Vector3 = local_points[i]
					var b: Vector3 = local_points[i + 1]
					if local_sample.x < minf(a.x, b.x) - 0.001 \
							or local_sample.x > maxf(a.x, b.x) + 0.001 \
							or absf(b.x - a.x) < 0.000001:
						continue
					var t := clampf((local_sample.x - a.x) / (b.x - a.x), 0.0, 1.0)
					highest = maxf(highest, xf.origin.y + lerpf(a.y, b.y, t))
	return highest


func _build_chimney() -> void:
	if not spec.chimney:
		return
	tag("chimney")
	var s: float = HouseGeometry.chimney_size(spec)
	var c := HouseGeometry.chimney_center(plan)

	var wall_top: float = spec.height * _storeys()
	# Above the RIDGE, not above an assumed two-metre roof. The old
	# minf(roof_rise, 2.0) sized every stack as though no roof rose higher than
	# that, so a longhall with a 5.4 m rise got a flue that stopped two and a
	# half metres short of its own ridge -- a chimney you could see the roof
	# over, which both looks wrong and would smoke back down itself.
	var roll_clearance: float = HouseGeometry.THATCH_ROLL_TOP \
		if HouseGeometry.has_witch_roofcraft(spec, plan.world_family) else 0.0
	var plan_roof_rise: float = HouseGeometry.roof_rise(spec)
	var sampled_roof_top := NAN
	if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family):
		# The Witch flue exits through the roof at its own measured footprint.
		# Sampling a three-metre neighbourhood chose the ridge when the stack sat
		# at the eave, making the chimney tower far above its real roof opening.
		# The exact footprint sampler includes the emitted eave roll where it
		# crosses the flue, while leaving the distant ridge cap out of the stack.
		var measured_flue_s: float = HouseGeometry.chimney_flue_size(spec, plan.world_family)
		sampled_roof_top = _roof_top_surface_in_flue_footprint(c,
			Vector2.ONE * measured_flue_s)
		if is_finite(sampled_roof_top):
			plan_roof_rise = sampled_roof_top - wall_top
	# The sampled surface already includes the roof's slab crown/roll allowance.
	# Add the physical 0.6 m flue clearance once, not a second roll height.
	var top: float = sampled_roof_top + CHIMNEY_CLEAR if is_finite(sampled_roof_top) \
		else wall_top + plan_roof_rise + roll_clearance + CHIMNEY_CLEAR
	var flue_s: float = HouseGeometry.chimney_flue_size(spec, plan.world_family)

	# Stepped chimney stack
	var base_h: float = minf(top * 0.45, 2.5)
	if spec.chimney_style == &"stepped":
		var base_s: float = s + HouseGeometry.CHIMNEY_BASE_EXTRA
		box(Vector3(base_s, base_h, base_s), Vector3(c.x, base_h / 2.0, c.y), SURF_FLOOR)
		var sh_h := 0.25
		box(Vector3(base_s - 0.08, sh_h, base_s - 0.08), Vector3(c.x, base_h + sh_h / 2.0, c.y), SURF_FLOOR)
		var flue_h: float = top - (base_h + sh_h)
		if flue_h > 0.05:
			var upper_s: float = flue_s if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family) else s
			box(Vector3(upper_s, flue_h, upper_s), Vector3(c.x, base_h + sh_h + flue_h / 2.0, c.y), SURF_FLOOR)
	else:
		box(Vector3(s, top, s), Vector3(c.x, top / 2.0, c.y), SURF_FLOOR)

	var crown_s: float = flue_s + 0.22 if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family) else s + 0.22
	var chimney_footprint: float = s
	var chimney_height: float = top
	if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family):
		chimney_footprint = maxf(s + HouseGeometry.CHIMNEY_BASE_EXTRA, crown_s)
		chimney_height = top + 0.18 + HouseGeometry.CHIMNEY_POT_H
	_log_mass("chimney", AABB(Vector3(c.x - chimney_footprint / 2.0, 0.0, c.y - chimney_footprint / 2.0),
		Vector3(chimney_footprint, chimney_height, chimney_footprint)))
	box(Vector3(crown_s, 0.18, crown_s), Vector3(c.x, top + 0.09, c.y), SURF_TRIM)
	total_height = maxf(total_height, top + 0.18)

	_emit_chimney_pots(c, top, flue_s)
	total_height = maxf(total_height, top + 0.18 + HouseGeometry.CHIMNEY_POT_H)


## Emit only the removable pottery crown. Keeping it separate lets the roof QA
## remove the real cap as a physical negative while retaining the masonry stack.
func _emit_chimney_pots(c: Vector2, top: float, flue_s: float) -> void:
	var pot_r: float = HouseGeometry.CHIMNEY_POT_R
	var pot_h: float = HouseGeometry.CHIMNEY_POT_H
	var pots: int = clampi(spec.chimney_pots, 1, 2)
	if pots == 1:
		_kit.drum(Vector3(c.x, top + 0.18, c.y), pot_r, pot_r, pot_h, SURF_FLOOR, 10)
		_kit.drum(Vector3(c.x, top + 0.18 + pot_h - 0.06, c.y), pot_r * 1.15, pot_r * 1.15, 0.06, SURF_TRIM, 10)
	else:
		var off: float = flue_s * 0.22 if HouseGeometry.uses_witch_asymmetric_roof(spec, plan.world_family) else HouseGeometry.chimney_size(spec) * 0.22
		for pside in [-1.0, 1.0]:
			var px: float = c.x + (off * pside if plan.hearth_wall() <= 1 else 0.0)
			var pz: float = c.y + (off * pside if plan.hearth_wall() > 1 else 0.0)
			_kit.drum(Vector3(px, top + 0.18, pz), pot_r, pot_r, pot_h, SURF_FLOOR, 10)
			_kit.drum(Vector3(px, top + 0.18 + pot_h - 0.06, pz), pot_r * 1.15, pot_r * 1.15, 0.06, SURF_TRIM, 10)


## Low firewood belongs inside the measured footprint of the Witch's Cauldron.
## These named shell components are supported by the same floor as the pot; they
## add no separate obstacle or clearance reservation to the plan.
func _build_witch_cauldron_heat() -> void:
	if spec.style != &"witch_hut":
		return
	tag("witch_cauldron_heat")
	for furniture_index in range(plan.furniture.size()):
		var furniture_placement: Dictionary = plan.furniture[furniture_index]
		if String(furniture_placement.get("key", "")) == "Cauldron":
			_emit_witch_cauldron_logs(furniture_placement, true, "furniture_%d" % furniture_index)
	host_end()

func _emit_witch_cauldron_logs(placement: Dictionary, centred: bool, placement_id: String) -> void:
	var model_yaw: float = float(placement.get("yaw", 0.0)) + PropCatalog.face_offset("Cauldron")
	var scale_factor: float = float(placement.get("scale", 1.0))
	var height_scale: float = PropCatalog.placement_height_scale(placement)
	var origin: Vector3
	if centred:
		origin = PropCatalog.house_origin(placement)
	else:
		var pos: Vector3 = Vector3(placement.get("pos", Vector3.ZERO))
		var drop: float = PropCatalog.seat_offset("Cauldron") * height_scale
		if PropCatalog.has_tag("Cauldron", PropCatalog.WALL_MOUNTED) or PropCatalog.has_tag("Cauldron", PropCatalog.CEILING):
			drop = 0.0
		origin = Vector3(pos.x, pos.y - drop, pos.z)
	var floor_y: float = PropCatalog.floor_offset("Cauldron")
	var lower_h := 0.035
	var upper_h := 0.032
	host("witch_cauldron_%s" % placement_id, int(placement.get("storey", 0)))
	# Two parallel floor-supported sticks stay inside the measured three-leg
	# ring (about 0.30 m radius) and leave the central bowl underside clear.
	for side in [-1.0, 1.0]:
		var centre_local := Vector3(side * 0.035, floor_y + lower_h * 0.5, 0.0)
		var centre_world: Vector3 = origin + Basis(Vector3.UP, model_yaw) * Vector3(centre_local.x * scale_factor, centre_local.y * height_scale, centre_local.z * scale_factor)
		var size := Vector3(0.035 * scale_factor, lower_h * height_scale, 0.22 * scale_factor)
		component_box("witch_cauldron_heat_log_lower", size, Transform3D(Basis(Vector3.UP, model_yaw), centre_world), SURF_TRIM)
	# A cross-piece bears on both lower logs instead of floating above the embers.
	var top_local := Vector3(0.0, floor_y + lower_h + upper_h * 0.5, 0.0)
	var top_world: Vector3 = origin + Basis(Vector3.UP, model_yaw) * Vector3(top_local.x * scale_factor, top_local.y * height_scale, top_local.z * scale_factor)
	var top_size := Vector3(0.18 * scale_factor, upper_h * height_scale, 0.035 * scale_factor)
	component_box("witch_cauldron_heat_log_upper", top_size, Transform3D(Basis(Vector3.UP, model_yaw), top_world), SURF_TRIM)

func _build_witch_workshop_bay_bearing(xf: Transform3D, bay: Dictionary) -> void:
	# Bear the raised roof seam on the actual shared room wall. The roof joins
	# farther in over the high-core plane; a floor-to-roof post there would stand
	# inside the Hall instead of supporting the wall plate.
	var bearing_x := float(bay.get("wall_outer", bay["inner"]))
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var eave_y := float(bay["eave_y"])
	var join_y := float(bay["join_y"])
	var along_lo := float(bay["ceiling_along_lo"])
	var along_hi := float(bay["ceiling_along_hi"])
	var wall_t := HouseGeometry.wall_thickness(spec)
	var t := clampf((bearing_x - outer) / (inner - outer), 0.0, 1.0)
	var top := lerpf(eave_y, join_y, t) - RoofShape.DEPTH * 0.5
	if top <= 0.05:
		return
	var face := PackedVector3Array([Vector3(bearing_x, 0.0, along_lo), Vector3(bearing_x, 0.0, along_hi), Vector3(bearing_x, top, along_hi), Vector3(bearing_x, top, along_lo)])
	tag("witch_workshop_bay_bearing")
	host("witch_workshop_bay_bearing", 0)
	_roof_face(xf, face, SURF_WALL, "witch_workshop_bay_bearing", false, wall_t)
	host_end()
