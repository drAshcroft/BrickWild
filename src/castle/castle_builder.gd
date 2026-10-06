class_name CastleBuilder
extends MassBuilder
## CastleSpec -> ArrayMesh. Massing-first, and which masses exist is decided by
## the tier the footprint fell into:
##
##   house     one hall block, a porch, an annexe, external chimney stacks
##   manor     a main range with cross wings round a court, optional front range
##   castle    a curtain wall with towers and a gatehouse, keep and hall inside
##   fortress  all of that, with a second enceinte inside the first and a walled
##             causeway joining the two gatehouses
##
## Every position comes from CastleGeometry. Nothing here derives massing of its
## own -- when the church builder and its blueprint each derived their own, the
## drawing quietly stopped being a drawing of the model.
##
## Surfaces: 0 = stone, 1 = trim, 2 = roof, 3 = openings, 4 = water.

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_OPEN := 3
const SURF_WATER := 4
## Slot 4 is the ground skin of the whole site -- water, beaten earth, bank,
## grass -- and slot 5 the small timber, hay and cloth of the working yards.
## Both are vertex-coloured (CastleAssembler turns that on), so a new colour
## costs no new material. QA treats slot 4 as it always treated water: a thin
## sheet, not masonry.
const SURF_GROUND := 4
const SURF_DRESS := 5
const SURFACES := 6

## Steps a battered wall or tower is emitted in. More steps is a smoother
## talus; four reads as masonry courses rather than as a ramp.
const BATTER_STEPS := 4
const EAVE := 0.5              # roof overhang past the wall it caps
const SLIT_BAY := 4.5          # metres of wall per arrow slit

var spec: CastleSpec
var _roof_faces: Array[PackedVector3Array] = []
var _roof_covers: Array[PackedVector3Array] = []
var _roof_openings: Array[Dictionary] = []
var interiors: Array[Dictionary] = []
var interior_errors: Array[String] = []
## Measured bailey-only yard occupancy. Interior shop furniture is counted
## separately and never inflates the exterior fixture total.
var yard_report: Dictionary = {}
var _yard_ranges: Array[Dictionary] = []
var _yard_well: Dictionary = {}
var _yards: Array[Dictionary] = []
var _skin_used := false
var _dress_used := false
var _planned_interiors := {}
const Interiors = preload("castle_interiors.gd")
const KeepPlan = preload("castle_keep_plan.gd")


func build(p_spec: CastleSpec) -> ArrayMesh:
	spec = p_spec
	begin_metric(SURFACES)
	_roof_faces.clear()
	_roof_covers.clear()
	_roof_openings.clear()
	interiors.clear()
	interior_errors.clear()
	yard_report.clear()
	_yard_ranges.clear()
	_yard_well.clear()
	_yards.clear()
	_skin_used = false
	_dress_used = false
	_planned_interiors = Interiors.primary(spec)
	total_height = spec.height

	if CastleGeometry.is_tower_house(spec):
		_build_tower_house()
		return _dressed()
	if CastleGeometry.is_ridge(spec):
		_build_ridge()
		return _dressed()
	if CastleGeometry.is_sky(spec):
		_build_sky_rock()
		_build_sky_citadel()
		return _dressed()
	match spec.tier:
		&"house":
			_build_house()
		&"manor":
			_build_manor()
		_:
			_build_enclosure()
	return _dressed()


## The garrison moves in. The dressing is prop PLACEMENTS rather than geometry,
## so it costs the mesh nothing and CastleAssembler is the only thing that ever
## loads a model. Every tier leaves through here, so no tier can be given a
## shell and then quietly forgotten.
func _dressed() -> ArrayMesh:
	_join_roofs()
	CastleApron.emit(self)
	prop_log = CastleFurnisher.dress(spec, {"ranges": _yard_ranges, "well": _yard_well,
		"yards": _yards})
	# Old decorative furniture must not overlap the actual plan's furniture.
	prop_log = prop_log.filter(func(p: Dictionary) -> bool:
		for row in interiors:
			var at: Vector3 = p["pos"]
			var bounds: AABB = row.bounds
			if bounds.grow(0.2).has_point(at):
				return false
		return true)
	if CastleGeometry.is_enclosed(spec):
		yard_report = CastleFurnisher.yard_report(spec, prop_log, interiors,
			{"ranges": _yard_ranges, "well": _yard_well, "yards": _yards})
	_keep_surface_slots()
	var mesh: ArrayMesh = commit()
	return _elevate_sky(mesh) if CastleGeometry.is_sky(spec) else mesh


## The ground skin is slot 4 and the yard dressing slot 5. A SurfaceTool with
## nothing in it adds no surface, which would slide slot 5 down into slot 4 and
## put timber where QA expects water. When only the dressing was used, slot 4
## gets a one-millimetre speck so that every slot stays where its constant says.
func _keep_surface_slots() -> void:
	if _skin_used or not _dress_used:
		return
	var st := _kit.surface(SURF_GROUND)
	var p := Vector3(0.0, 0.0, 0.0)
	st.set_normal(Vector3.UP)
	st.add_vertex(p)
	st.set_normal(Vector3.UP)
	st.add_vertex(p + Vector3(0.0, 0.0, 0.001))
	st.set_normal(Vector3.UP)
	st.add_vertex(p + Vector3(0.001, 0.0, 0.0))


## Say that slot 4 carries something, so no speck is needed to hold its place.
func mark_ground_skin() -> void:
	_skin_used = true


## Say that slot 5 carries something.
func mark_dress() -> void:
	_dress_used = true


## Emit in the castle's local frame, where its floor is y=0. `_elevate_sky`
## moves this rock and the whole finished castle together so the rock point
## remains below world zero while its top becomes the building's ground plane.
func _build_sky_rock() -> void:
	var depth: float = CastleGeometry.sky_rock_depth(spec)
	var radius: float = CastleGeometry.sky_rock_radius(spec)
	tag("rock")
	_kit.inverted_batter(radius, depth, Vector3.ZERO, SURF_STONE, 24, PI / 24.0)
	var local := AABB(Vector3(-radius, -depth, -radius),
		Vector3(radius * 2.0, depth, radius * 2.0))
	_log_part("inverted_batter", local.get_center(), local.size)
	_log_mass("rock", local, -depth)


func _elevate_sky(mesh: ArrayMesh) -> ArrayMesh:
	var ground: float = CastleGeometry.sky_ground_level(spec)
	var lift := Vector3.UP * ground
	for part in part_log:
		part["pos"] = (part["pos"] as Vector3) + lift
	for mass in mass_log:
		var a: AABB = mass["aabb"]
		mass["aabb"] = AABB(a.position + lift, a.size)
		mass["ground"] = 0.0 if mass["name"] == "rock" else ground
	for prop in prop_log:
		prop["pos"] = (prop["pos"] as Vector3) + lift
	for row in interiors:
		var bounds: AABB = row.bounds
		row["bounds"] = AABB(bounds.position + lift, bounds.size)
		var xf: Transform3D = row.transform
		xf.origin += lift
		row["transform"] = xf
	total_height += ground
	return MeshKit.translated(mesh, lift)


## Uneven turret-islands, pointed beneath as well as above, joined by two
## concentric families of flying arches. There is deliberately no conventional
## curtain or bailey here: those were what made the first sky pass read as a
## normal castle sitting on an oddly shaped hill.
func _build_sky_citadel() -> void:
	var towers: Array[Dictionary] = CastleGeometry.sky_towers(spec)
	tag("sky_tower")
	var i := 0
	for tower in towers:
		var base: Vector3 = tower["pos"]
		var radius: float = tower["radius"]
		var height: float = tower["height"]
		var tail: float = tower["tail"]
		_kit.inverted_batter(radius * 1.08, tail, base, SURF_STONE, 12,
			PI / 12.0 + float(i) * 0.11)
		_kit.drum(base, radius * 1.08, radius, height, SURF_STONE, 12,
			PI / 12.0 + float(i) * 0.11)
		var roof_h: float = radius * (2.0 + float(i % 3) * 0.55)
		_kit.cone(radius * 1.12, roof_h, base + Vector3.UP * height,
			SURF_ROOF, 12, PI / 12.0)
		var outward := Vector3(base.x, 0.0, base.z).normalized()
		var face: float = atan2(outward.x, outward.z)
		var face_r: float = radius * cos(PI / 12.0) + CastleGeometry.OPENING_EPS
		for level in [0.34, 0.68]:
			_opening(base + outward * face_r + Vector3.UP * (height * level),
				face, minf(radius * 0.42, 1.5), minf(height * 0.12, 2.8), &"arched")
		_log_part("sky_tower", (tower["aabb"] as AABB).get_center(),
			(tower["aabb"] as AABB).size)
		_log_mass("sky_tower_%d" % i, tower["aabb"])
		total_height = maxf(total_height, base.y + height + roof_h)
		i += 1

	tag("sky_arch")
	var bi := 0
	for bridge in CastleGeometry.sky_bridges(spec):
		var from_p: Vector3 = bridge["from"]
		var to_p: Vector3 = bridge["to"]
		var flat := Vector3(to_p.x - from_p.x, 0.0, to_p.z - from_p.z).normalized()
		var side := Vector3(-flat.z, 0.0, flat.x) * 0.72
		# Paired ribs make a traversable-width arcade in silhouette rather than
		# a single cable. The second ring of skip-one chords crosses the ward.
		for offset in [-side, side]:
			_kit.arc_ribbon(from_p + offset, to_p + offset, float(bridge["rise"]),
				0.48, 0.38, SURF_TRIM, 8)
			_log_part("sky_arch", (from_p + to_p) * 0.5 + offset,
				Vector3(0.48, float(bridge["rise"]), from_p.distance_to(to_p)))
		_log_mass("sky_bridge_%d" % bi, bridge["aabb"])
		bi += 1


func _join_roofs() -> void:
	var covers: Array[PackedVector3Array] = _roof_faces.duplicate()
	covers.append_array(_roof_covers)
	if CastleGeometry.is_ridge(spec):
		# A ridge has deliberate roof overlaps at every vertex: two ranges dive
		# into the same tower from different headings.  The generic envelope
		# clipper treats each sloping neighbour as a convex hole and can peel
		# away the wrong wedge at a bend.  Towers are the structural ownership
		# boundary, so clip each slope only by the actual tower top footprints;
		# the two range skins then meet under masonry instead of crossing in the
		# visible envelope.
		for i in range(_roof_faces.size()):
			var face := _roof_faces[i]
			for piece in _exposed_roof_pieces(face, i, _roof_covers, -1):
				_kit.slab_poly(piece, RoofShape.DEPTH, SURF_ROOF, true)
		return
	for mass in mass_log:
		var name: String = mass["name"]
		# Curved and battered towers use their own inscribed footprint below.
		if name.begins_with("tower") or name.begins_with("wall") or name == "keep":
			continue
		if not (name in ["hall", "porch", "annexe", "chapel", "range_front"] or name.begins_with("wing") or name.begins_with("chimney") or name.begins_with("yard_")):
			continue
		if CastleGeometry.is_ridge(spec) and (name == "hall" or name.begins_with("range")):
			continue # the AABB is wider than the rotated range
		var a: AABB = mass["aabb"]
		covers.append(PackedVector3Array([Vector3(a.position.x, a.end.y, a.position.z),
			Vector3(a.end.x, a.end.y, a.position.z), a.end, Vector3(a.position.x, a.end.y, a.end.z)]))
	for i in range(_roof_faces.size()):
		var face := _roof_faces[i]
		for piece in _exposed_roof_pieces(face, i, covers, i):
			_kit.slab_poly(piece, RoofShape.DEPTH, SURF_ROOF, true)


## Dormer footprints are removed before cover clipping, so the roof which owns
## a dormer has a real hole rather than a plane behind its glazing.
func _exposed_roof_pieces(face: PackedVector3Array, face_index: int,
		covers: Array[PackedVector3Array], own_index: int) -> Array[PackedVector3Array]:
	var pieces: Array[PackedVector2Array] = [RoofShape.footprint(face)]
	for opening in _roof_openings:
		if int(opening["face_index"]) != face_index:
			continue
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			next.append_array(RoofShape.subtract(piece, opening["polygon"]))
		pieces = next
	var out: Array[PackedVector3Array] = []
	for piece in pieces:
		var cut_face := RoofShape.lift(piece, face)
		for exposed_piece in RoofShape.exposed(cut_face, covers, own_index):
			out.append(RoofShape.lift(exposed_piece, cut_face))
	return out


# -------------------------------------------------------- motte and bailey

## The mound, the shell keep on it and the curtain that climbs to it.
func _build_motte() -> void:
	var m: AABB = CastleGeometry.motte_aabb(spec)
	var c: Vector2 = CastleGeometry.motte_center(spec)
	var rb: float = CastleGeometry.motte_base_radius(spec)
	var rt: float = CastleGeometry.motte_top_radius(spec)
	tag("motte")
	_kit.drum(Vector3(c.x, 0.0, c.y), rb, rt, spec.motte_height, SURF_STONE, 24)
	_log_mass("motte", m)

	tag("keep")
	var k: AABB = CastleGeometry.shell_keep_aabb(spec)
	var base := Vector3(c.x, spec.motte_height, c.y)
	var t: float = spec.shell_thickness
	var planned_shell := _planned_interiors.has("keep_shell")
	if planned_shell:
		Interiors.emit(self, _planned_interiors["keep_shell"])
		_motte_flue(_planned_interiors["keep_shell"])
	else:
		_kit.oval_ring(base, k.size.x / 2.0, k.size.z / 2.0, t, k.size.y, SURF_STONE, 28)
	_log_mass("keep_shell", k)
	# the parapet, merlon by merlon round the oval
	if spec.battlements:
		var n := 28
		for i in range(n):
			var a: float = TAU * float(i) / n
			var p := base + Vector3(cos(a) * (k.size.x / 2.0 - t / 2.0), k.size.y + spec.merlon_h / 2.0,
				sin(a) * (k.size.z / 2.0 - t / 2.0))
			box(Vector3(CastleGeometry.MERLON_W, spec.merlon_h, minf(t, 0.6)), p, SURF_TRIM, -a)
	# The occupied plan owns the shell doorway and its actual cut.  The legacy
	# painted opening remains only for unplanned callers.
	if not planned_shell:
		_opening(base + Vector3(0.0, 1.6, -(k.size.z / 2.0 + CastleGeometry.OPENING_EPS)),
			PI, minf(k.size.x * 0.12, 1.6), 2.6, &"arched", true)
	total_height = maxf(total_height, spec.motte_height + k.size.y + spec.merlon_h)

	tag("climb")
	var w: Dictionary = CastleGeometry.climb_wall(spec)
	var a: Vector3 = w["from"]
	var b: Vector3 = w["to"]
	var dir: Vector3 = (b - a).normalized()
	var length: float = a.distance_to(b)
	var up := Vector3(0.0, dir.z, -dir.y).normalized()
	if up.y < 0.0:
		up = -up
	var h: float = float(w["height"])
	var th: float = float(w["thickness"])
	var centre: Vector3 = a + dir * (length / 2.0) + up * (h / 2.0)
	var xf := Transform3D(Basis(Vector3.RIGHT, up, dir), centre)
	_kit.oriented_box(Vector3(th, h, length), xf, SURF_STONE)
	_log_mass("climb", CastleGeometry.climb_aabb(spec))
	if planned_shell:
		var shell_row: Dictionary = _planned_interiors["keep_shell"]
		var shell_plan: HousePlan = shell_row.plan
		var shell_door: Dictionary = shell_plan.doors[shell_plan.entrance()]
		var shell_door_world: Vector3 = shell_row.transform * Vector3(shell_door.pos.x, 0.0, shell_door.pos.y)
		_motte_approach_steps(w, Vector2(shell_door_world.x, shell_door_world.z))
	else:
		_motte_approach_steps(w)


func _motte_flue(row: Dictionary) -> void:
	var flue := CastleMottePlan.flue(row.plan, spec.merlon_h + 0.45)
	if flue.is_empty():
		return
	var size: Vector3 = flue.size
	var xf: Transform3D = row.transform * Transform3D(flue.transform)
	var previous_tag := _tag
	tag("keep_shell_flue")
	host("keep_shell", int(flue.storey))
	component_box("motte_flue", size, xf, SURF_STONE)
	var cap := xf.translated(Vector3.UP * (size.y * 0.5 + 0.09))
	component_box("motte_flue_cap", Vector3(size.x + 0.2, 0.18, size.z + 0.2), cap, SURF_TRIM)
	host_end()
	# Like the parapet, this wall-hosted exterior component is checked against
	# real triangles; it does not replace the shell's occupied-volume mass.
	total_height = maxf(total_height, cap.origin.y + 0.09)
	tag(previous_tag)


# ------------------------------------------------------------ ridge castle

## Ranges along the spine, each a rotated block under its own ridge roof with
## a row of windows a storey, diving into the tower at either end; a tower at
## every vertex. No curtain, no gate, no bailey: the ranges are the walls.
func _build_ridge() -> void:
	var storeys: int = CastleGeometry.ridge_storeys(spec)
	for seg in CastleGeometry.ridge_ranges(spec):
		var name: String = seg["name"]
		tag("hall" if name == "hall" else "range")
		var a: Vector2 = seg["from"]
		var b: Vector2 = seg["to"]
		var mid: Vector2 = (a + b) / 2.0
		var yaw: float = seg["yaw"]
		var length: float = seg["length"]
		var width: float = seg["width"]
		var height: float = seg["height"]
		# Ranges can have their own storey count within the silhouette. The
		# facade contract measures these rows against the range, not the castle's
		# tallest segment.
		var sh: float = height / float(storeys)
		var planned: bool = _planned_interiors.has(name)
		if planned:
			Interiors.emit(self, _planned_interiors[name])
		else:
			box(Vector3(length, height, width), Vector3(mid.x, height / 2.0, mid.y), SURF_STONE, yaw)
		_log_mass(name, CastleGeometry.ridge_range_aabb(seg))
		# the roof runs along the range: local Z of the roof transform is the
		# direction of the segment
		var dir: Vector2 = seg["dir"]
		var rise: float = width * spec.roof_pitch * 0.5
		# Lift the slab centre by half its thickness: its underside then clears
		# the wall head by a millimetre instead of sharing the exact eave plane.
		var roof_base: float = height + RoofShape.DEPTH * 0.5 + 0.01
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(mid.x, roof_base, mid.y))
		# Masonry dives into the vertex towers.  The roofs are allowed to run
		# beneath their decks, where the tower footprint owns the join; clipping
		# them at the outer shoulder would leave a visible wall-head gap.
		var roof_length: float = float(seg.get("roof_length", length)) + EAVE * 0.25
		# A range dies into a vertex tower, so its end is a shallow hip rather
		# than a freestanding gable wall.  The old gable closures projected past
		# the tower footprint at every bend; those exposed vertical wedges were
		# the dark "holes" in the joined envelope.  Keep the hip faces deferred
		# so the deck below can occlude their buried ends.
		var roof_start := _roof_faces.size()
		var local_roof := RoofShape.faces(width + EAVE, roof_length, rise, &"half_hipped")
		for face in local_roof:
			_roof_faces.append(xf * face)
		_ridge_end_fascia(xf, width + EAVE, roof_length, rise)
		if spec.dormers:
			_roof_dormers(xf, local_roof, roof_start, length, name,
				(width + EAVE) * 0.5, rise, true)
		total_height = maxf(total_height, roof_base + rise)
		# windows: a row a storey on both long faces, on the rotated face.
		#
		# A planned range cuts its OWN openings for the storeys it occupies,
		# and emitting these as well would put two sets of holes through one
		# wall. Each occupied band owns its room-backed openings; rows above
		# the complete occupied height belong only to any remaining roof void.
		var occupied_top := 0.0
		if planned:
			var ps: HouseSpec = (_planned_interiors[name].plan as HousePlan).spec
			occupied_top = minf(ps.height * float(maxi(ps.storeys, 1)), height)
		var n: Vector2 = seg["normal"]
		if spec.style in [&"bavarian", &"french_chateau"]:
			host("ridge_%s_courses" % name)
			for level in range(1, storeys + 1):
				for side in [-1.0, 1.0]:
					var p: Vector2 = mid + n * float(side) * (width * 0.5)
					component_box("range_string_course", Vector3(length, 0.18, 0.18),
						Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, level * sh - 0.12, p.y)), SURF_TRIM)
			host_end()
		# The hall is the principal range. Give it a calmer, wider bay rhythm;
		# the shorter connecting ranges carry the denser secondary cadence.
		var count: int = clampi(int(length / (5.0 if name == "hall" else 3.5)), 1, 24)
		for s in range(storeys):
			var y: float = (float(s) + 0.55) * sh
			if planned and y - spec.window_h * 0.5 < occupied_top:
				continue          # the plan already cut this storey's openings
			for side in [1.0, -1.0]:
				var face_n: Vector2 = n * side
				var ang: float = atan2(face_n.x, face_n.y)
				for i in range(count):
					var t: float = (float(i) + 1.0) / (float(count) + 1.0) - 0.5
					var p: Vector2 = mid + dir * (length * t) + face_n * (width / 2.0 + CastleGeometry.OPENING_EPS)
					var principal_bay := name == "hall" and i == int(count / 2)
					_opening(Vector3(p.x, y, p.y), ang,
						spec.window_w * (1.18 if principal_bay else 1.0),
						spec.window_h * (1.08 if principal_bay else 1.0), spec.window_style)
	tag("tower")
	var i2 := 0
	var spire_vertex: int = CastleGeometry.spine(spec).size() / 2
	for tc in CastleGeometry.ridge_tower_centers(spec):
		if spec.style != &"dark" or i2 != spire_vertex:
			_tower(tc["pos"], 0, "tower_0_corner_%d" % i2, tc["away"], i2)
		i2 += 1
	if spec.style == &"dark" and spec.keep:
		_build_dark_spire()


## Close only the two range ends, with a thin roof-coloured fascia.  Passing an
## end surface to MeshKit.ridge_roof closes all four wall-head edges and makes
## a second sloping wall along each eave; at a zig-zag bend those end walls are
## the dark crossing wedges.  The range shell owns the long wall heads, while
## this fascia owns the exposed underside at each tower shoulder.
func _ridge_end_fascia(xf: Transform3D, span: float, along: float, rise: float) -> void:
	var roof := RoofShape.faces(span, along, rise, &"half_hipped")
	for end_v in [-1.0, 1.0]:
		var a := Vector2(-span * 0.5, end_v * along * 0.5)
		var b := Vector2(span * 0.5, end_v * along * 0.5)
		var profile := RoofShape.wall_profile(roof, a, b)
		_kit.slab_poly(xf * profile, 0.18, SURF_ROOF, true)


## One revolved needle at the ridge's centre. Its broad lower shoulders dive
## into the ranges; above their roofs it contracts twice before reaching the
## point, so this is a spire-shaped keep rather than a keep with a roof prop.
func _build_dark_spire() -> void:
	var a: AABB = CastleGeometry.dark_spire_aabb(spec)
	if a.size.y <= 0.0:
		return
	var c: Vector3 = CastleGeometry.dark_spire_center(spec)
	var r: float = a.size.x * 0.5
	tag("keep")
	_kit.revolve(PackedVector2Array([
		Vector2(r, 0.0), Vector2(r, spec.height * 0.72),
		Vector2(r * 0.68, spec.height), Vector2(r * 0.42, spec.keep_height * 0.62),
		Vector2(0.0, spec.keep_height),
	]), c, SURF_STONE, 12, TAU, PI / 12.0)
	_log_part("spire", c + Vector3.UP * (spec.keep_height * 0.5), a.size)
	_log_mass("keep", a)
	total_height = maxf(total_height, spec.keep_height)


## Dormers sit on the measured roof plane and cut their footprint out of it.
## The local roof frame is X across the pitch and Z along the ridge.
func _roof_dormers(xf: Transform3D, roof: Array[PackedVector3Array],
		roof_start: int, run: float, range_name: String, half: float,
		rise: float, ridge_style: bool) -> void:
	if roof.size() < 2 or half <= 0.0 or rise <= 0.0:
		return
	var count: int = clampi(int(run / (8.0 if range_name == "hall" else 6.0)), 1, 8) if ridge_style \
		else clampi(int(run / (7.0 if range_name == "hall" else 9.0)), 1, 6)
	var dormer_width: float = minf(1.8 if range_name == "hall" else 1.25,
		(half * 2.0) * (0.2 if ridge_style else (0.28 if range_name == "hall" else 0.18)))
	for face_side in [-1.0, 1.0]:
		var face_index := 0 if face_side < 0.0 else 1
		var seat := RoofShape.dormer_seat(half, rise, face_side * half * 0.62, dormer_width)
		if not bool(seat.get("fits", false)):
			continue
		var rh: float = seat["roof_half"]
		var out_dir: float = signf(float(seat["front"]))
		var host: PackedVector2Array = RoofShape.footprint(roof[face_index])
		for i in range(count):
			var z := -run * 0.38 + run * 0.76 * (float(i) + 0.5) / float(count)
			var cover := PackedVector2Array([
				Vector2(float(seat["front"]) + out_dir * 0.12, z - rh),
				Vector2(float(seat["side_x"]), z - rh),
				Vector2(float(seat["peak_x"]), z),
				Vector2(float(seat["side_x"]), z + rh),
				Vector2(float(seat["front"]) + out_dir * 0.12, z + rh)])
			if not _roof_polygon_fits(host, cover):
				continue
			var opening := PackedVector2Array([
				Vector2(float(seat["front"]), z - dormer_width * 0.5),
				Vector2(float(seat["cheek_x"]), z - dormer_width * 0.5),
				Vector2(float(seat["peak_x"]), z),
				Vector2(float(seat["cheek_x"]), z + dormer_width * 0.5),
				Vector2(float(seat["front"]), z + dormer_width * 0.5)])
			var world_opening := PackedVector2Array()
			for p in opening:
				var wp := xf * Vector3(p.x, 0.0, p.y)
				world_opening.append(Vector2(wp.x, wp.z))
			var owner := "dormer:%s:%d:%d" % [range_name, int(face_side), i]
			_roof_openings.append({"face_index": roof_start + face_index,
				"polygon": world_opening, "owner": owner})
			_emit_seated_roof_dormer(xf, seat, z, dormer_width, owner)


static func _roof_polygon_fits(host: PackedVector2Array, candidate: PackedVector2Array) -> bool:
	for p in candidate:
		if not Poly.contains_point(host, p):
			return false
		for i in range(host.size()):
			var edge: Vector2 = host[(i + 1) % host.size()] - host[i]
			if edge.length() > 0.0 and absf(edge.cross(p - host[i])) / edge.length() < 0.12:
				return false
	return true


func _emit_seated_roof_dormer(xf: Transform3D, seat: Dictionary, z: float,
		dormer_width: float, owner: String) -> void:
	var front: float = seat["front"]
	var out_dir: float = signf(front)
	var base: float = seat["base"]
	var eave: float = seat["eave"]
	var peak: float = seat["peak"]
	var rh: float = seat["roof_half"]
	var hw: float = dormer_width * 0.5
	var lift: float = peak - eave
	var side_top: float = eave + lift * (1.0 - hw / rh) - RoofShape.DEPTH * 0.5
	var head: float = eave - RoofShape.DEPTH * 0.5
	host(owner)
	for side in [-1.0, 1.0]:
		var rooflet := PackedVector3Array([
			xf * Vector3(front + out_dir * 0.12, eave, z + side * rh),
			xf * Vector3(float(seat["side_x"]), eave, z + side * rh),
			xf * Vector3(float(seat["peak_x"]), peak, z),
			xf * Vector3(front + out_dir * 0.12, peak, z)])
		component_slab("dormer_roof", rooflet, RoofShape.DEPTH, SURF_ROOF, true)
		var cheek := PackedVector3Array([
			xf * Vector3(front, base, z + side * hw),
			xf * Vector3(front, side_top, z + side * hw),
			xf * Vector3(float(seat["cheek_x"]), side_top, z + side * hw)])
		component_slab("dormer_cheek", cheek, 0.08, SURF_STONE, false)
	var gable := PackedVector3Array([
		xf * Vector3(front, base, z - hw), xf * Vector3(front, base, z + hw),
		xf * Vector3(front, side_top, z + hw),
		xf * Vector3(front, peak - RoofShape.DEPTH * 0.5, z),
		xf * Vector3(front, side_top, z - hw)])
	component_slab("dormer_gable", gable, 0.10, SURF_STONE, false)
	var normal := xf.basis.x * out_dir
	var face_angle := atan2(normal.x, normal.z)
	var window_pos := xf * Vector3(front + out_dir * 0.06, (base + head) * 0.5, z)
	_opening(window_pos, face_angle, dormer_width * 0.48,
		maxf((head - base) * 0.64, 0.35), &"arched")
	part_log.back()["component_host"] = owner
	host_end()


# ------------------------------------------------------------- tower house

## One tall block, storey by storey, each a little wider than the one above
## (the walls thicken toward the foot); a fighting platform on top; a raised
## door on the front face and rows of windows above it; and the jog off one
## corner. The `hall` mass is the shaft as a whole -- the anchor every
## unwalled tier is measured from -- and each storey is logged as its own
## mass so TowerCheck can read the wall thickness off the foot and the top.
func _build_tower_house() -> void:
	var t: AABB = CastleGeometry.tower_house_aabb(spec)
	tag("hall")
	_log_mass("hall", t)
	var planned_tower := _planned_interiors.has("tower_house")
	if planned_tower:
		Interiors.emit(self, _planned_interiors["tower_house"])
	tag("storey")
	var n: int = maxi(spec.tower_storeys, 1)
	for s in range(n):
		var a: AABB = CastleGeometry.tower_storey_aabb(spec, s)
		if not planned_tower:
			if spec.style == &"wizard":
				_kit.oval_ring(a.position + Vector3(a.size.x / 2.0, 0.0, a.size.z / 2.0),
					a.size.x / 2.0, a.size.z / 2.0,
					CastleGeometry.tower_wall_thickness(spec, s), a.size.y, SURF_STONE, 24)
			else:
				_box_aabb(a, SURF_STONE)
		_log_mass("storey_%d" % s, a)
	tag("platform")
	var p: AABB = CastleGeometry.tower_platform_aabb(spec)
	if spec.style == &"wizard":
		_kit.oval_ring(p.position + Vector3(p.size.x / 2.0, 0.0, p.size.z / 2.0),
			p.size.x / 2.0, p.size.z / 2.0, minf(p.size.x, p.size.z) * 0.49,
			p.size.y, SURF_STONE, 24)
	else:
		_box_aabb(p, SURF_STONE)
	_log_mass("platform", p)
	if spec.style == &"wizard":
		var cap_r: float = maxf(p.size.x, p.size.z) * 0.54
		var cap_h: float = maxf(spec.width, spec.length) * spec.roof_pitch
		_kit.cone(cap_r, cap_h, Vector3(0.0, p.end.y, 0.0), SURF_ROOF, 24)
		total_height = maxf(total_height, p.end.y + cap_h)
	else:
		_crenellate_rect(p, p.position.y + p.size.y, SURF_TRIM)
		total_height = maxf(total_height, p.position.y + p.size.y + spec.merlon_h)

	if spec.style == &"wizard":
		tag("balcony")
		var bi := 0
		for balcony in CastleGeometry.wizard_balconies(spec):
			_kit.balcony_ring(float(balcony["radius"]), float(balcony["width"]),
				float(balcony["y"]), float(balcony["arc"]), SURF_TRIM,
				Vector2.ZERO, float(balcony["start"]), CastleGeometry.WIZARD_BALCONY_THICK)
			_log_part("balcony_ring", Vector3(0.0, float(balcony["y"]), 0.0),
				(balcony["aabb"] as AABB).size, float(balcony["start"]))
			_log_mass("balcony_%d" % bi, balcony["aabb"])
			bi += 1

	# The plan owns the raised doorway and its sill interval.  Keep the old
	# opening only for an unplanned tower caller.
	var sill: float = CastleGeometry.tower_door_sill(spec)
	var door_h: float = minf(CastleGeometry.tower_storey_height(spec) * 0.7, 2.6)
	var door_storey: int = clampi(int(sill / CastleGeometry.tower_storey_height(spec)), 0, n - 1)
	if not planned_tower:
		tag("door")
		var ds: AABB = CastleGeometry.tower_storey_aabb(spec, door_storey)
		_opening(Vector3(t.position.x + t.size.x / 2.0, sill + door_h / 2.0,
			ds.position.z - CastleGeometry.OPENING_EPS), PI, minf(t.size.x * 0.25, 1.4),
			door_h, &"arched", true)
	else:
		var tower_row: Dictionary = _planned_interiors["tower_house"]
		var tower_plan: HousePlan = tower_row.plan
		var tower_door: Dictionary = tower_plan.doors[tower_plan.entrance()]
		var tower_door_world: Vector3 = tower_row.transform * Vector3(tower_door.pos.x, 0.0, tower_door.pos.y)
		_tower_approach_steps(t, sill, Vector2(tower_door_world.x, tower_door_world.z))

	# windows on every storey above the lift, on all four faces of that
	# storey's own box -- never on the ground storey, which is blind
	if not planned_tower:
		tag("window")
		for s2 in range(n):
			var a2: AABB = CastleGeometry.tower_storey_aabb(spec, s2)
			var y: float = a2.position.y + a2.size.y * 0.55
			if y - spec.window_h / 2.0 < CastleGeometry.TOWER_LIFT_MIN:
				continue
			var only: Array = []
			if s2 == door_storey:
				only = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
			_face_openings(a2, y, spec.window_style, only, 3.5)

	tag("wing")
	var j := 0
	for jog in CastleGeometry.tower_jog_aabbs(spec):
		# the face it shares with the shaft is buried; the jog looks the
		# other three ways, and only above the lift
		var buried := Vector3(0, 0, 1) if j == 0 else Vector3(0, 0, -1)
		var faces: Array = []
		for f in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
			if (f as Vector3).dot(buried) < 0.9:
				faces.append(f)
		_box_aabb(jog, SURF_STONE)
		_log_mass("wing_jog_%d" % j, jog)
		var jp := AABB(Vector3(jog.position.x - 0.2, jog.position.y + jog.size.y, jog.position.z - 0.2),
			Vector3(jog.size.x + 0.4, 0.4, jog.size.z + 0.4))
		_box_aabb(jp, SURF_STONE)
		_crenellate_rect(jp, jp.position.y + jp.size.y, SURF_TRIM)
		var rows: int = maxi(int(jog.size.y / CastleGeometry.tower_storey_height(spec)), 1)
		for row in range(rows):
			var jy: float = (float(row) + 0.55) * CastleGeometry.tower_storey_height(spec)
			if jy - spec.window_h / 2.0 < CastleGeometry.TOWER_LIFT_MIN or jy > jog.size.y - 0.5:
				continue
			_face_openings(jog, jy, spec.window_style, faces, 3.5)
		j += 1


## A short, physical stair from the terrain to the raised tower entrance.  The
## rows are appended far-to-near so route QA can verify the chain without
## reconstructing it from a mass AABB.
func _tower_approach_steps(t: AABB, sill: float, door_xz: Vector2) -> void:
	var count := maxi(4, int(ceil(sill / 0.28)))
	var depth := clampf(maxf(t.size.z * 0.08, 0.8), 0.8, 1.5)
	var width := clampf(maxf(t.size.x * 0.28, 2.0), 2.0, 3.6)
	for i in range(count):
		var h := sill * float(i + 1) / float(count)
		var centre := Vector3(door_xz.x,
			h * 0.5,
			door_xz.y - depth * (float(count - i) - 0.5))
		var size := Vector3(width, h, depth)
		_log_part("tower_approach_step", centre, size, 0.0,
			Vector3(0.0, 1.0, 0.0))
		_kit.box(size, centre, SURF_STONE)


## Physical steps follow the existing climb from bailey ground to the shell
## threshold.  They terminate at the plan's inner shell face, in the same
## local frame as the `keep_shell` interior record.
func _motte_approach_steps(_wall: Dictionary, door_xz := Vector2(INF, INF)) -> void:
	for step in preload("castle_access_geometry.gd").motte_approach(spec, door_xz):
		_log_part("motte_approach_step", step.pos, step.size, step.rot_y, Vector3.UP)
		_kit.box(step.size, step.pos, SURF_STONE, step.rot_y)


func _motte_door_target() -> Vector2:
	if not _planned_interiors.has("keep_shell"):
		return Vector2(INF, INF)
	var row: Dictionary = _planned_interiors["keep_shell"]
	var plan: HousePlan = row.plan
	if plan.entrance() < 0:
		return Vector2(INF, INF)
	var door: Dictionary = plan.doors[plan.entrance()]
	var at: Vector3 = row.transform * Vector3(door.pos.x, 0.0, door.pos.y)
	return Vector2(at.x, at.z)


# ------------------------------------------------------------------- house

func _build_house() -> void:
	tag("hall")
	var a: AABB = CastleGeometry.house_range_aabb(spec)
	_range(a, "hall", SURF_STONE, true)

	tag("annexe")
	var ann: AABB = CastleGeometry.annexe_aabb(spec)
	if ann.size.x > 0.0:
		_range(ann, "annexe", SURF_STONE, true)

	_build_porch()
	_build_chimneys()


# ------------------------------------------------------------------- manor

func _build_manor() -> void:
	tag("range")
	_range(CastleGeometry.house_range_aabb(spec), "hall", SURF_STONE, true)

	tag("wing")
	for side in CastleGeometry.wing_sides(spec):
		var w: AABB = CastleGeometry.manor_wing_aabb(spec, side)
		_range(w, "wing_%s" % ("left" if side < 0.0 else "right"), SURF_STONE, true)

	tag("range")
	var fr: AABB = CastleGeometry.manor_front_range_aabb(spec)
	if fr.size.x > 0.0:
		_range(fr, "range_front", SURF_STONE, true)

	tag("tower")
	var i := 0
	for c in CastleGeometry.manor_tower_centers(spec):
		_tower(c, 0, "tower_manor_%d" % i, Vector3(0, 0, -1))
		i += 1

	_build_porch()
	_build_chimneys()


## The entrance block: a porch on an open court, a gate passage through a
## closed one. Either way it laps the range it serves, so it reads as built
## into the house rather than parked against it.
func _build_porch() -> void:
	var p: AABB = CastleGeometry.porch_aabb(spec)
	if p.size.x <= 0.0:
		return
	tag("porch")
	_passage(p, minf(p.size.x * 0.5, 2.0), minf(p.size.y - 0.2, HouseGeometry.DOOR_H))
	_log_mass("porch", p)
	var xf := Transform3D(Basis(), Vector3(0.0, p.size.y, p.position.z + p.size.z / 2.0))
	_kit.ridge_roof(xf, p.size.x + 0.3, p.size.z + 0.3,
		p.size.x * spec.roof_pitch * 0.4, SURF_ROOF, SURF_STONE, p.size.x, p.size.z, 0.3, 0.0, _roof_faces)
	total_height = maxf(total_height, p.size.y + p.size.x * spec.roof_pitch * 0.4)


func _build_chimneys() -> void:
	if spec.chimneys <= 0:
		return
	tag("chimney")
	for i in range(spec.chimneys):
		var c: AABB = CastleGeometry.chimney_aabb(spec, i)
		_box_aabb(c, SURF_STONE)
		_log_mass("chimney_%d" % i, c)
		# the coping course that stops a stack reading as a bare post
		box(Vector3(c.size.x + 0.3, 0.25, c.size.z + 0.3),
			Vector3(c.position.x + c.size.x / 2.0, c.size.y + 0.12,
				c.position.z + c.size.z / 2.0), SURF_TRIM)
		total_height = maxf(total_height, c.size.y + 0.25)


# --------------------------------------------------------------- enclosure

func _build_enclosure() -> void:
	_collect_loop_blockers()
	for r in CastleGeometry.rings(spec):
		_build_ring(r)
	if spec.plan_kind == &"terraced":
		_build_terrace_stair()
	_build_wall_stairs()

	tag("barbican")
	var bar: AABB = CastleGeometry.barbican_aabb(spec)
	if bar.size.x > 0.0:
		_passage(bar, minf(bar.size.x * 0.45, 2.4), minf(bar.size.y * 0.55, 5.0))
		_log_mass("barbican", bar)
		_crenellate_rect(bar, bar.size.y, SURF_TRIM)
	_build_water_moats()
	_build_drawbridge()
	_build_causeway()

	tag("link")
	for side in [-1.0, 1.0]:
		var lk: AABB = CastleGeometry.gate_link_aabb(spec, side)
		if lk.size.z <= 0.0:
			continue
		_box_aabb(lk, SURF_STONE)
		_log_mass("link_%s" % ("left" if side < 0.0 else "right"), lk)
		_crenellate_rect(lk, lk.size.y, SURF_TRIM)

	tag("keep")
	if spec.keep:
		_build_keep()
	if CastleGeometry.is_motte(spec):
		_build_motte()
	if spec.plan_kind == &"terraced":
		_build_terrace()

	# The hall and the chapel look into the bailey (CAS-003): windows on the
	# courtyard face and the free short end, none through the curtain they
	# stand against, and a row of them rather than one every five metres.
	tag("hall")
	var hall: AABB = CastleGeometry.hall_aabb(spec)
	if hall.size.x > 0.0:
		_range(hall, "hall", SURF_STONE, true, [Vector3(1, 0, 0), Vector3(0, 0, -1)], RANGE_BAY)

	tag("chapel")
	var chapel: AABB = CastleGeometry.chapel_aabb(spec)
	if chapel.size.x > 0.0:
		_range(chapel, "chapel", SURF_STONE, true, [Vector3(-1, 0, 0)], RANGE_BAY)
		_build_apse()
	_close_curtain_slivers()
	_build_yard()
	if spec.plan_kind == &"terraced":
		var inner_ground := CastleGeometry.ring_ground_y(spec,
			CastleGeometry.inner_ring(spec))
		for mass in mass_log:
			var nm: String = mass["name"]
			if nm in ["keep", "hall", "chapel", "apse", "well"] \
					or nm.begins_with("yard_") or nm.begins_with("yardwork_") \
					or nm.begins_with("forebuilding"):
				if (mass["aabb"] as AABB).position.y >= inner_ground - 0.01:
					mass["ground"] = inner_ground


func _build_water_moats() -> void:
	for trench in CastleGeometry.moat_aabbs(spec):
		_log_mass(String(trench.name), trench.aabb)
		mass_log.back()["kind"] = trench.kind
		mass_log.back()["depth"] = trench.depth
		mass_log.back()["width"] = trench.width
		mass_log.back()["ring"] = trench.ring
	# The trench stays the measured negative mass. What shows is the water that
	# stands in it, the banks that hold it and the revetment along the curtain.
	CastleMoatBuilder.emit(self)


func _build_causeway() -> void:
	CastleMoatBuilder.causeway(self)


func _build_drawbridge() -> void:
	var bridge := CastleGeometry.drawbridge_aabb(spec)
	if bridge.size.z <= 0.0:
		return
	tag("drawbridge")
	host("drawbridge")
	# Two longitudinal bearers carry transverse planks; the small open joints
	# read as timber, while every walking lane has continuous support beneath.
	for side in [-1.0, 1.0]:
		component_box("drawbridge_bearer", Vector3(0.2, 0.12, bridge.size.z),
			Transform3D(Basis.IDENTITY, Vector3(side * bridge.size.x * 0.32, 0.06, bridge.get_center().z)), SURF_TRIM)
	var boards := maxi(2, int(ceil(bridge.size.z / 0.28)))
	var pitch := bridge.size.z / boards
	for board in boards:
		component_box("drawbridge_plank", Vector3(bridge.size.x, 0.1, pitch - 0.008),
			Transform3D(Basis.IDENTITY, Vector3(0, 0.17, bridge.position.z + (board + 0.5) * pitch)), SURF_ROOF)
	# Hinges are on the gate sill, clear of the wheel lanes. Upright chains
	# remain outside the usable deck, so an open bridge is actually passable.
	for side in [-1.0, 1.0]:
		component_box("drawbridge_hinge", Vector3(0.22, 0.22, 0.28),
			Transform3D(Basis.IDENTITY, Vector3(side * (bridge.size.x * 0.5 - 0.11), 0.11, bridge.end.z - 0.14)), SURF_TRIM)
		var low := Vector3(side * (bridge.size.x * 0.5 + 0.08), 0.22, bridge.position.z + 0.2)
		var high := Vector3(low.x, 3.0, bridge.end.z)
		var length := low.distance_to(high)
		var basis := Basis.looking_at((high - low).normalized(), Vector3.UP)
		component_box("drawbridge_chain", Vector3(0.06, 0.06, length),
			Transform3D(basis, (low + high) * 0.5), SURF_TRIM)
	_log_mass("drawbridge", bridge)
	host_end()


func _build_wall_stairs() -> void:
	var index := 0
	for stair in CastleGeometry.wall_stairs(spec):
		var name := "wall_stair_%d" % index
		tag(name)
		host(name)
		var bounds := AABB()
		var first := true
		for piece in preload("castle_access_geometry.gd").pieces(stair):
			var surface := SURF_TRIM if "rail" in String(piece.role) else SURF_STONE
			var row := component_box(piece.role, piece.size, piece.xf, surface)
			bounds = component_aabb(row) if first else bounds.merge(component_aabb(row))
			first = false
		_log_mass(name, bounds)
		mass_log.back()["ring"] = stair.ring
		mass_log.back()["walk_height"] = stair.height
		mass_log.back()["footprint"] = stair.poly
		host_end()
		index += 1


## No slot narrower than a passage between a ward building and the curtain.
##
## A Bergfried and its Palas are fitted back from the curtain until their base
## corners clear a polygon's sloping sides, which can leave them half a metre
## short of the back wall: a slot open from the wall-walk to the ground that
## nobody can use and a walker steps into (walk-QA, Thorncliffe pin 10). The
## slot is built up solid to the wall head and capped flush with the walk.
const SLIVER_MAX := 1.2


func _close_curtain_slivers() -> void:
	if not CastleGeometry.is_enclosed(spec) or CastleGeometry.is_motte(spec):
		return
	var ring := CastleGeometry.inner_ring(spec)
	var ward := CastleGeometry.inner_polygon(spec, ring)
	if ward.size() < 3:
		return
	var lip := Geometry2D.offset_polygon(ward, -CastleGeometry.WALK_LIP)
	var h := CastleGeometry.wall_height(spec, ring)
	var ground := CastleGeometry.ring_ground_y(spec, ring)
	for name in ["keep", "hall", "chapel"]:
		var b := mass_aabb(name)
		if b.size.x <= 0.0 or b.end.y < ground + h * 0.5:
			continue
		var plan := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		for dir in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			var half := plan.size * 0.5
			var face := plan.get_center() + Vector2(dir.x * half.x, dir.y * half.y)
			var reach := _ward_reach(ward, face, dir)
			if reach <= 0.02 or reach >= SLIVER_MAX:
				continue
			# The slot: the building's face, swept out to the curtain.
			var slot := Rect2(face, Vector2.ZERO).expand(face + dir * reach)
			if dir.x == 0.0:
				slot = Rect2(plan.position.x, slot.position.y, plan.size.x, slot.size.y)
			else:
				slot = Rect2(slot.position.x, plan.position.y, slot.size.x, plan.size.y)
			var fill := AABB(Vector3(slot.position.x, ground, slot.position.y),
				Vector3(slot.size.x, h, slot.size.y))
			tag("curtain")
			box(fill.size, fill.get_center(), SURF_STONE)
			if not lip.is_empty():
				var rect := PackedVector2Array([slot.position, Vector2(slot.end.x, slot.position.y),
					slot.end, Vector2(slot.position.x, slot.end.y)])
				for piece in Geometry2D.intersect_polygons(rect, lip[0]):
					var pts := PackedVector3Array()
					for p in piece:
						pts.append(Vector3(p.x, ground + h + CastleGeometry.PARAPET_RISE * 0.5, p.y))
					component_slab("curtain_fill_coping", pts, CastleGeometry.PARAPET_RISE, SURF_TRIM)
			var side := "back" if dir.y > 0.0 else ("front" if dir.y < 0.0 else ("east" if dir.x > 0.0 else "west"))
			_log_mass("wall_%d_fill_%s_%s" % [ring, name, side], AABB(fill.position,
				fill.size + Vector3(0.0, CastleGeometry.PARAPET_RISE, 0.0)))


## How far from `from`, along `dir`, the ward polygon's boundary lies.
static func _ward_reach(ward: PackedVector2Array, from: Vector2, dir: Vector2) -> float:
	var best := INF
	for i in ward.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(from, from + dir * 1000.0,
			ward[i], ward[(i + 1) % ward.size()])
		if hit != null:
			best = minf(best, from.distance_to(hit))
	return best


## The chapel's apse: a half-drum on the end toward the gate, under a half
## cone, embedded in the chapel the way the church's is in its nave.
func _build_apse() -> void:
	var a: AABB = CastleGeometry.apse_aabb(spec)
	if a.size.x <= 0.0:
		return
	tag("apse")
	var r: float = CastleGeometry.apse_radius(spec)
	var h: float = a.size.y
	var origin := Vector3(a.position.x + a.size.x / 2.0, a.position.y,
		a.position.z + a.size.z)
	if _planned_interiors.has("apse"):
		Interiors.emit(self, _planned_interiors["apse"])
		_kit.revolve(PackedVector2Array([Vector2(r * 1.08, h), Vector2(0.0, h + r * 0.9)]),
			origin, SURF_ROOF, 10, PI, PI)
		_log_mass("apse", a)
		_log_part("apse", a.get_center(), a.size)
		total_height = maxf(total_height, h + r * 0.9)
		return
	var aperture := PackedVector2Array()
	var planned := _planned_interiors.has("chapel")
	if planned:
		var row: Dictionary = _planned_interiors["chapel"]
		var plan: HousePlan = row.plan
		var entry := plan.entrance()
		if entry >= 0:
			var door: Dictionary = plan.doors[entry]
			var xf: Transform3D = row.transform
			var normal := xf.basis * Vector3(door.normal.x, 0, door.normal.y)
			if normal.z < -0.9:
				var centre := xf * Vector3(door.pos.x, 0, door.pos.y)
				var half := float(door.width) * 0.5
				aperture = PackedVector2Array([
					Vector2(centre.x - half, origin.z - r - 1),
					Vector2(centre.x + half, origin.z - r - 1),
					Vector2(centre.x + half, origin.z + 1),
					Vector2(centre.x - half, origin.z + 1)])
	if planned:
		# A partial revolve closes its diameter with a solid radial face, which
		# sealed the chapel door even after the curved front was cut. The plan's
		# front wall supplies that closure now. These mitered wall segments have
		# both masonry faces, 0.6m apart, and retain the original ten outer bays.
		var inner_r := maxf(r - 0.6 / cos(PI / 20.0), 0.01)
		for segment in 10:
			var angle0 := PI + PI * float(segment) / 10.0
			var angle1 := PI + PI * float(segment + 1) / 10.0
			var centre := Vector2(origin.x, origin.z)
			var d0 := Vector2(cos(angle0), sin(angle0))
			var d1 := Vector2(cos(angle1), sin(angle1))
			var footprint := PackedVector2Array([centre + d0 * r, centre + d1 * r,
				centre + d1 * inner_r, centre + d0 * inner_r])
			var pieces: Array[PackedVector2Array] = [footprint]
			if not aperture.is_empty():
				pieces = RoofShape.subtract(footprint, aperture)
			for piece in pieces:
				var vertices := PackedVector3Array()
				for point in piece:
					vertices.append(Vector3(point.x, h * 0.5, point.y))
				_kit.slab_poly(vertices, h, SURF_STONE, true)
			if not aperture.is_empty():
				var over := Poly.clip_convex(footprint, aperture)
				var header := PackedVector3Array()
				for point in over:
					header.append(Vector3(point.x, (h + HouseGeometry.DOOR_H) * 0.5, point.y))
				if h > HouseGeometry.DOOR_H:
					_kit.slab_poly(header, h - HouseGeometry.DOOR_H, SURF_STONE, true)
	else:
		# The half of a revolve that lies at -Z: angles PI .. 2PI.
		_kit.revolve(PackedVector2Array([Vector2(r, 0.0), Vector2(r, h)]), origin,
			SURF_STONE, 10, PI, PI)
	_kit.revolve(PackedVector2Array([Vector2(r * 1.08, h), Vector2(0.0, h + r * 0.9)]),
		origin, SURF_ROOF, 10, PI, PI)
	_log_mass("apse", a)
	_log_part("apse", a.position + a.size / 2.0, a.size)
	# Keep the existing high window, but never paint it across the real door.
	var window_y := h * 0.5
	if not aperture.is_empty():
		window_y = maxf(window_y, HouseGeometry.DOOR_H + spec.window_h * 0.5 + 0.2)
	if window_y + spec.window_h * 0.5 < h:
		_opening(origin + Vector3(0.0, window_y, -(r + CastleGeometry.OPENING_EPS)),
			PI, spec.window_w, spec.window_h, spec.window_style)
	total_height = maxf(total_height, h + r * 0.9)


func _build_ring(r: int) -> void:
	var lift: float = CastleGeometry.ring_ground_y(spec, r)
	var part_start := part_log.size()
	var mass_start := mass_log.size()
	var component_start := component_log.size()
	_kit.emission_offset.y = lift
	if CastleGeometry.is_polygonal(spec):
		_build_ring_walls_poly(r)
	else:
		_build_ring_walls_rect(r)

	tag("tower")
	var i := 0
	for c in CastleGeometry.vertex_tower_centers(spec, r):
		# a vertex tower's free faces are the ones on the outward bisector
		var away := Vector3(signf(c.x), 0.0, signf(c.z)).normalized()
		if CastleGeometry.is_polygonal(spec):
			var mid: Vector2 = CastleGeometry.polygon_bbox(
				CastleGeometry.enceinte_polygon(spec, r)).get_center()
			away = Vector3(c.x - mid.x, 0.0, c.z - mid.y).normalized()
		_tower(c, r, "tower_%d_corner_%d" % [r, i], away, i)
		i += 1
	i = 0
	for slot in CastleGeometry.side_tower_slots(spec, r):
		_tower(slot["pos"], r, "tower_%d_side_%d" % [r, i], slot["facing"])
		i += 1
	i = 0
	for c2 in CastleGeometry.gate_tower_centers(spec, r):
		_tower(c2, r, "tower_%d_gate_%d" % [r, i], Vector3(0, 0, -1))
		i += 1
	tag("gate")
	var g: AABB = CastleGeometry.gatehouse_aabb(spec, r)
	if g.size.x > 0.0:
		var door_h: float = minf(g.size.y * 0.4, 5.0)
		var gate_id := "gate_%d" % r
		if _planned_interiors.has(gate_id):
			_build_gate_chamber(g, r, door_h, _planned_interiors[gate_id])
		else:
			_passage(g, minf(g.size.x * 0.4, 4.0), door_h, r)
		_log_mass("gate_%d" % r, g)
		_crenellate_rect(g, g.size.y, SURF_TRIM)
		if not _planned_interiors.has(gate_id):
			for k in range(3):
				var x: float = lerpf(-g.size.x * 0.3, g.size.x * 0.3, float(k) / 2.0)
				_opening(Vector3(x, g.size.y * 0.72, g.position.z - CastleGeometry.OPENING_EPS),
					PI, 0.4, 0.6, &"square")
		total_height = maxf(total_height, g.size.y + CastleGeometry.PARAPET_RISE + spec.merlon_h)
	_kit.emission_offset = Vector3.ZERO
	_translate_ring_records(part_start, mass_start, component_start, lift)
	if lift > 0.0:
		total_height = maxf(total_height, lift + CastleGeometry.wall_height(spec, r)
			+ CastleGeometry.PARAPET_RISE + spec.merlon_h)


func _build_gate_chamber(gate: AABB, ring: int, passage_h: float, row: Dictionary) -> void:
	var room: AABB = row.bounds
	# Only the masonry below the chamber remains a passage mass. Emitting
	# the original full-height header would fill every new room and window.
	var base := AABB(gate.position, Vector3(gate.size.x,
		room.position.y - gate.position.y, gate.size.z))
	_passage(base, minf(gate.size.x * 0.4, 4.0), passage_h, ring)
	Interiors.emit(self, row)
	host(row.id)
	component_box("gate_chamber_ceiling", Vector3(gate.size.x, 0.18, gate.size.z),
		Transform3D(Basis.IDENTITY, Vector3(gate.get_center().x, gate.end.y - 0.09,
			gate.get_center().z)), SURF_STONE)
	for rect in row.gallery:
		var area: Rect2 = rect
		component_box("gate_access_gallery", Vector3(area.size.x, 0.22, area.size.y),
			Transform3D(Basis.IDENTITY, Vector3(area.get_center().x,
				float(row.walk_y) - 0.11, area.get_center().y)), SURF_TRIM)
	var support: Vector2 = row.support
	var support_h := float(row.walk_y) - 0.22
	component_box("gate_gallery_pier", Vector3(0.8, support_h, 0.8),
		Transform3D(Basis.IDENTITY, Vector3(support.x, support_h * 0.5, support.y)), SURF_STONE)
	host_end()


## MeshKit lifts only the vertices emitted for a ring. Keep all three QA logs
## in that same world frame, including component transforms and slabs.
func _translate_ring_records(part_start: int, mass_start: int, component_start: int,
		lift: float) -> void:
	if absf(lift) < 0.001:
		return
	var offset := Vector3.UP * lift
	for i in range(part_start, part_log.size()):
		part_log[i]["pos"] = (part_log[i]["pos"] as Vector3) + offset
	for i in range(mass_start, mass_log.size()):
		var a: AABB = mass_log[i]["aabb"]
		mass_log[i]["aabb"] = AABB(a.position + offset, a.size)
		mass_log[i]["ground"] = lift
	for i in range(component_start, component_log.size()):
		var row: Dictionary = component_log[i]
		if row.has("xf"):
			var xf: Transform3D = row["xf"]
			xf.origin += offset
			row["xf"] = xf
		if row.has("points"):
			var points: PackedVector3Array = row["points"]
			for p in range(points.size()):
				points[p] += offset
			row["points"] = points
		if row.has("aabb"):
			var a: AABB = row["aabb"]
			row["aabb"] = AABB(a.position + offset, a.size)


## Solid shrinking stone courses. The widest course is at world ground; each
## course steps inward as it rises, giving the retaining side its batter.
func _build_terrace() -> void:
	var rise: float = spec.terrace_rise
	if rise < 3.0 or not spec.inner_ward:
		return
	var poly: PackedVector2Array = CastleGeometry.enceinte_polygon(spec, 1)
	var centre: Vector2 = CastleGeometry.polygon_bbox(poly).get_center()
	var t: float = CastleGeometry.wall_thickness(spec, 1)
	var half: Vector2 = CastleGeometry.polygon_bbox(poly).size * 0.5
	var base_inset := Vector2(t * 0.35, t * 0.35)
	# The cap laps the inner curtain footing by 0.2 wall-thickness. The stair
	# surface and curtain therefore meet at the same terrace elevation.
	var top_inset := Vector2(t * 0.8, t * 0.8)
	var overall := AABB(Vector3(centre.x - half.x + base_inset.x, 0.0,
		centre.y - half.y + base_inset.y),
		Vector3(maxf(half.x * 2.0 - 2.0 * base_inset.x, 1.0), rise,
			maxf(half.y * 2.0 - 2.0 * base_inset.y, 1.0)))
	tag("terrace")
	var levels := 4
	for level in range(levels):
		var f: float = float(level + 1) / float(levels)
		var inset: Vector2 = base_inset.lerp(top_inset, f)
		var points := PackedVector3Array()
		for p in poly:
			var q := centre + Vector2((p.x - centre.x) * maxf(0.1, (half.x - inset.x) / half.x),
				(p.y - centre.y) * maxf(0.1, (half.y - inset.y) / half.y))
			points.append(Vector3(q.x,
				rise * (float(level) + 0.5) / float(levels), q.y))
		_kit.slab_poly(points, rise / float(levels), SURF_STONE, true)
		_log_part("terrace_course", overall.get_center(),
			Vector3(overall.size.x, rise / float(levels), overall.size.z))
	_log_mass("terrace", overall, 0.0)
	total_height = maxf(total_height, rise)


## One narrow stone flight climbs from the outer gate approach to the raised
## inner gate. Treads remain separate so the voxel walker can pass above them.
func _build_terrace_stair() -> void:
	if not spec.inner_ward:
		return
	var rise: float = spec.terrace_rise
	var outer: AABB = CastleGeometry.gatehouse_aabb(spec, 0)
	var inner: AABB = CastleGeometry.gatehouse_aabb(spec, 1)
	var front: float = outer.position.z + outer.size.z
	var back: float = inner.position.z
	var run: float = back - front
	if run < rise * 1.2:
		front = outer.position.z + outer.size.z * 0.45
		run = back - front
	if run <= 0.5:
		return
	var width := minf(3.0, maxf(1.8, spec.gate_width * 0.3))
	var steps := maxi(int(ceil(rise / 0.2)), 8)
	var tread := run / float(steps)
	tag("terrace_stair")
	var low_z := front
	var bounds := AABB(Vector3(-width * 0.5, 0.0, low_z),
		Vector3(width, rise, run))
	for i in range(steps):
		var y: float = rise * float(i + 1) / float(steps)
		var z: float = low_z + tread * (float(i) + 0.5)
		box(Vector3(width, y, tread * 1.02), Vector3(0.0, y * 0.5, z), SURF_STONE)
	_log_mass("terrace_stair_1", bounds, 0.0)
	mass_log.back()["walk_height"] = rise
	mass_log.back()["ring"] = 1


## A real tunnel through the gate mass, with no dark collision box sealing it.
## The top-level gate AABB still describes its full masonry envelope.
func _passage(bounds: AABB, width: float, height: float, portcullis_ring := -1) -> void:
	var centre := bounds.get_center()
	var side_w := (bounds.size.x - width) * 0.5
	for side in [-1.0, 1.0]:
		if portcullis_ring < 0:
			box(Vector3(side_w, bounds.size.y, bounds.size.z),
				Vector3(centre.x + side * (width + side_w) * 0.5, centre.y, centre.z), SURF_STONE)
		else:
			# A true slot in the side masonry, with a thin guide at its back.
			# A dark stripe on an uncut wall would not be a portcullis groove.
			var slot_width := 0.24
			var slot_depth := minf(0.18, side_w * 0.3)
			var slot_z := bounds.position.z + bounds.size.z * 0.3
			for interval in [Vector2(bounds.position.z, slot_z - slot_width * 0.5),
				Vector2(slot_z + slot_width * 0.5, bounds.end.z)]:
				box(Vector3(side_w, bounds.size.y, interval.y - interval.x),
					Vector3(centre.x + side * (width + side_w) * 0.5, centre.y, (interval.x + interval.y) * 0.5), SURF_STONE)
			box(Vector3(side_w - slot_depth, bounds.size.y, slot_width),
				Vector3(centre.x + side * (width + side_w + slot_depth) * 0.5, centre.y, slot_z), SURF_STONE)
			var name := "portcullis_%d_%s" % [portcullis_ring, "left" if side < 0 else "right"]
			host(name)
			var guide_height := minf(height + 0.6, bounds.size.y)
			var at := Vector3(centre.x + side * (width * 0.5 + slot_depth - 0.02),
				bounds.position.y + guide_height * 0.5, slot_z)
			var guide := component_box("portcullis_guide", Vector3(0.04, guide_height, slot_width),
				Transform3D(Basis.IDENTITY, at), SURF_TRIM)
			_log_mass(name, component_aabb(guide))
			_log_part("portcullis_groove", Vector3(centre.x + side * (width + slot_depth) * 0.5,
				bounds.position.y + height * 0.5, slot_z), Vector3(slot_depth, height, slot_width))
			host_end()
	box(Vector3(width, bounds.size.y - height, bounds.size.z),
		Vector3(centre.x, bounds.position.y + (height + bounds.size.y) * 0.5, centre.z), SURF_STONE)
	_log_part("passage", Vector3(centre.x, bounds.position.y + height * 0.5, centre.z),
		Vector3(width, height, bounds.size.z))


## The four axis-aligned runs of a rectangular enceinte -- the N = 4 plan, kept
## on its own path because every box in it lands on an axis and there is no
## reason to put it through a rotation that would only round it.
func _build_ring_walls_rect(r: int) -> void:
	tag("curtain")
	var t: float = CastleGeometry.wall_thickness(spec, r)
	for which in CastleGeometry.wall_names(spec, r):
		var a: AABB = CastleGeometry.wall_aabb(spec, r, which)
		if a.size.x < CastleGeometry.MIN_WALL_RUN and a.size.z < CastleGeometry.MIN_WALL_RUN:
			continue
		var outward: Vector3 = _wall_outward(which)
		var slit_points := _wall_slit_positions(a, outward, t)
		var passage := Rect2()
		if CastleGeometry.is_motte(spec) and r == 0 and which == &"back":
			passage = preload("castle_access_geometry.gd").motte_passage(spec, a, _motte_door_target())
			# An arrow slit cannot occupy the same masonry as the postern.
			slit_points = slit_points.filter(func(p: Vector3) -> bool:
				return not passage.intersects(Rect2(p.x - EMBRASURE_W * 0.5 - 0.2, 0.0, EMBRASURE_W + 0.4, EMBRASURE_H)))
		_battered_wall(a, t, outward, slit_points, passage)
		_log_mass("wall_%d_%s" % [r, String(which)], a)
		if passage.has_area() and passage.end.y >= a.size.y - 0.01:
			# A low curtain may have no room for a lintel. Keep its coping out of
			# the route too, rather than sealing the opening with the wall walk.
			for interval in [Vector2(a.position.x, passage.position.x), Vector2(passage.end.x, a.end.x)]:
				if interval.y > interval.x + 0.01:
					_wall_top(AABB(Vector3(interval.x, a.position.y, a.position.z),
						Vector3(interval.y - interval.x, a.size.y, a.size.z)), outward, t)
		else:
			_wall_top(a, outward, t)
		_emit_wall_slits(slit_points, outward, true,
			_loop_reveal(a.size.x if absf(outward.x) > 0.5 else a.size.z, t, a.size.y))
		total_height = maxf(total_height, a.size.y + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## The runs of a polygonal enceinte: the same battered wall, wall walk,
## crenellations and slits, but aligned to the edge instead of to an axis.
## Every box is emitted rotated about Y, and every opening is placed on the
## rotated FACE -- on a hexagon the difference between the wall and its bounding
## box is metres, so an opening on the box hangs in open air.
func _build_ring_walls_poly(r: int) -> void:
	tag("curtain")
	for seg in CastleGeometry.wall_segments(spec, r):
		_wall_run(seg, r)


# ------------------------------------------------------------ arrow loops
## A loop is only worth cutting where an archer can stand behind it. Through
## slits at 62% of the curtain's height opened into four metres of solid wall
## with no floor behind them (walk-QA, Thorncliffe pin 14). A curtain's loops
## are now the embrasured kind: the slit pierces only the outer skin, at an
## archer's eye on the ward's ground, and behind it a recess a person can walk
## into opens off the ward.
const LOOP_Y := 1.4               # slit centre above the ward's ground
const LOOP_H := 1.5
const LOOP_W := 0.32
const EMBRASURE_W := 1.0
const EMBRASURE_H := 2.2
const LOOP_SKIN := 0.6            # the outer masonry the slit alone pierces
## In front of an embrasure's mouth: room to stand in the ward.
const LOOP_APPROACH := 0.9
## The deepest skin an archer can shoot through (CastleLoopCheck.STAND).
const LOOP_STAND := 1.0

## Where loops may not open, filled by _build_enclosure: plan rectangles of the
## buildings and stairs against the curtain, and the outlines of the towers
## and gatehouses whose masonry would swallow a loop.
var _loop_rects: Array[Rect2] = []
var _loop_polys: Array[PackedVector2Array] = []


func _collect_loop_blockers() -> void:
	_loop_rects = CastleGeometry.bailey_obstacles(spec)
	if CastleGeometry.is_motte(spec):
		var m: AABB = CastleGeometry.motte_aabb(spec)
		_loop_rects.append(Rect2(m.position.x, m.position.z, m.size.x, m.size.z))
	_loop_polys.clear()
	var access := preload("castle_access_geometry.gd")
	for r in CastleGeometry.rings(spec):
		var vertices := CastleGeometry.vertex_tower_centers(spec, r)
		for index in vertices.size():
			_loop_polys.append(access._tower_outline(spec, r, vertices[index], index))
		var towers := CastleGeometry.gate_tower_centers(spec, r)
		for slot in CastleGeometry.side_tower_slots(spec, r):
			towers.append(slot.pos)
		for tower in towers:
			_loop_polys.append(access._tower_outline(spec, r, tower))
		var g: AABB = CastleGeometry.gatehouse_aabb(spec, r)
		if g.size.x > 0.0:
			_loop_polys.append(Poly.from_rect(Rect2(g.position.x, g.position.z, g.size.x, g.size.z)))


## May a loop open at inner-face point `mouth` (plan) whose slit is at `slit`?
func _loop_clear(mouth: Vector2, slit: Vector2, inward: Vector2, along: Vector2) -> bool:
	var half := along * (EMBRASURE_W * 0.5 + 0.2)
	var front := mouth + inward * LOOP_APPROACH
	var approach := Poly.bounding_rect(PackedVector2Array([mouth - half, mouth + half,
		front + half, front - half]))
	for rect in _loop_rects:
		if rect.grow(0.1).intersects(approach):
			return false
	for poly in _loop_polys:
		for p in [mouth, slit, mouth - half, mouth + half, slit - half, slit + half]:
			if Geometry2D.is_point_in_polygon(p, poly):
				return false
	return true


## How deep the embrasure goes in from the inner face, for a course `th`
## thick at the loop on a curtain `h` tall; 0 for a wall thin enough to shoot
## straight through. Castle QA walks the curtain's centre line at half its
## height, so on a low curtain the recess stops short of the middle.
static func _embrasure_depth(th: float, h: float) -> float:
	var depth := th - LOOP_SKIN
	if h * 0.5 - EMBRASURE_H < 0.5:
		depth = minf(depth, th * 0.5 - 0.3)
	return depth if depth >= 0.4 else 0.0


## A wall can carry loops only if the slit and a course above it fit, and an
## archer can stand within a metre of the outer face: straight through a thin
## wall, or at the back of the embrasure in a thick one.
static func _loops_fit(h: float, base := 0.0, top := 0.0) -> bool:
	if h < LOOP_Y + LOOP_H * 0.5 + 1.0:
		return false
	if top <= 0.0:
		return true
	var th := _batter_thickness(base, top, LOOP_Y, h)
	var emb := _embrasure_depth(_batter_thickness(base, top, minf(EMBRASURE_H, h) - 0.01, h), h)
	return th - emb <= LOOP_STAND


## A course's thickness: its batter step's, not its own sub-band's, so the
## extra levels a loop adds put no micro-steps in the outer face.
static func _batter_thickness(base: float, top: float, y: float, h: float) -> float:
	var step := h / float(BATTER_STEPS)
	var band := clampf(floorf(y / step), 0.0, float(BATTER_STEPS - 1))
	return lerpf(base, top, (band + 0.5) * step / h)


## The levels a course stack must break at for its loops.
static func _loop_levels(levels: Array[float], h: float, emb: bool) -> void:
	for y in [LOOP_Y - LOOP_H * 0.5, LOOP_Y + LOOP_H * 0.5]:
		levels.append(clampf(y, 0.0, h))
	if emb:
		levels.append(clampf(EMBRASURE_H, 0.0, h))


## One course between y0 and y1, `th` thick, along u in [u_lo, u_hi], as
## pieces Vector4(u0, u1, d0, d1) with d measured in from the inner face:
## whole where nothing is cut; round each loop, the inner masonry cut by the
## embrasure and the outer skin by the slit.
static func _course_cuts(u_lo: float, u_hi: float, y0: float, y1: float, th: float,
		loops: Array[float], emb_depth: float) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var ymid := (y0 + y1) * 0.5
	var in_slit := not loops.is_empty() and absf(ymid - LOOP_Y) < LOOP_H * 0.5
	var in_emb := not loops.is_empty() and emb_depth > 0.0 and ymid < EMBRASURE_H
	var none: Array[float] = []
	if not in_slit and not in_emb:
		out.append(Vector4(u_lo, u_hi, 0.0, th))
	elif emb_depth <= 0.0:
		_cut_span(out, u_lo, u_hi, 0.0, th, loops, LOOP_W)
	else:
		_cut_span(out, u_lo, u_hi, 0.0, emb_depth, loops if in_emb else none, EMBRASURE_W)
		_cut_span(out, u_lo, u_hi, emb_depth, th, loops if in_slit else none, LOOP_W)
	return out


static func _cut_span(out: Array[Vector4], u_lo: float, u_hi: float, d0: float, d1: float,
		loops: Array[float], width: float) -> void:
	var sorted := loops.duplicate()
	sorted.sort()
	var cursor := u_lo
	for u in sorted:
		var start := clampf(float(u) - width * 0.5, u_lo, u_hi)
		if start > cursor + 0.01:
			out.append(Vector4(cursor, start, d0, d1))
		cursor = maxf(cursor, clampf(float(u) + width * 0.5, u_lo, u_hi))
	if u_hi > cursor + 0.01:
		out.append(Vector4(cursor, u_hi, d0, d1))


func _wall_run(seg: Dictionary, r: int) -> void:
	if spec.curved_edges:
		_curved_wall_run(seg, r)
		return
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var h: float = CastleGeometry.wall_height(spec, r)
	var run: float = seg["length"]
	var yaw: float = seg["yaw"]
	var outward: Vector3 = seg["outward"]
	# the inner face, which is vertical at every course
	var mid: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var inner := Vector3(mid.x - outward.x * t, 0.0, mid.y - outward.z * t)
	var run_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	var loops := _run_loops(seg, r)
	# The recess is as deep as the thinnest course it passes through allows.
	var emb := 0.0
	if not loops.is_empty():
		emb = _embrasure_depth(_batter_thickness(tb, t, minf(EMBRASURE_H, h) - 0.01, h), h)
	var levels: Array[float] = [0.0, h]
	for i in range(1, BATTER_STEPS):
		levels.append(h * float(i) / BATTER_STEPS)
	if not loops.is_empty():
		_loop_levels(levels, h, emb > 0.0)
	levels.sort()
	for i in range(levels.size() - 1):
		var y0: float = levels[i]
		var y1: float = levels[i + 1]
		if y1 <= y0 + 0.001:
			continue
		var ymid := (y0 + y1) * 0.5
		var th: float = _batter_thickness(tb, t, ymid, h)
		for piece in _course_cuts(-run * 0.5, run * 0.5, y0, y1, th, loops, emb):
			box(Vector3(piece.y - piece.x, y1 - y0, piece.w - piece.z),
				inner + outward * ((piece.z + piece.w) * 0.5) + run_axis * ((piece.x + piece.y) * 0.5)
				+ Vector3(0.0, ymid, 0.0), SURF_STONE, yaw)
	_log_mass("wall_%d_%s" % [r, String(seg["name"])],
		CastleGeometry.segment_aabb(spec, r, seg))

	# wall walk and merlons, following the run's own top face
	var walk: Vector3 = inner + outward * (t / 2.0) + Vector3(0.0, h + CastleGeometry.PARAPET_RISE / 2.0, 0.0)
	box(Vector3(run, CastleGeometry.PARAPET_RISE, t + 2.0 * CastleGeometry.WALK_LIP), walk, SURF_TRIM, yaw)
	if spec.battlements:
		var edge: Vector3 = inner + outward * (t - spec.merlon_h * 0.35)
		var along := Vector3(cos(yaw), 0.0, -sin(yaw)) * (run / 2.0)
		_crenellate_run(edge - along, edge + along, h + CastleGeometry.PARAPET_RISE,
			spec.merlon_h * 0.7, yaw, SURF_TRIM)
	_run_slits(seg, r, loops, emb)
	total_height = maxf(total_height, h + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## Elven curtains bow between the original polygon vertices. Sampling includes
## both sides of every slit, so the mesh cut and its logged opening share the
## same curved surface coordinates. Corner towers still use CastleGeometry's
## unshifted polygon vertices.
func _curved_wall_run(seg: Dictionary, r: int) -> void:
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var h: float = CastleGeometry.wall_height(spec, r)
	var run: float = float(seg["length"])
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	var outward: Vector2 = Vector2(float(seg["outward"].x), float(seg["outward"].z))
	var sagitta: float = run * 0.16
	var slit_y: float = h * 0.62
	var slit_h := minf(1.5, h * 0.24)
	var slit_w := 0.32
	var slit_count: int = clampi(int(run / SLIT_BAY), 1, 24)
	var slit_t: Array[float] = []
	var ts: Array[float] = [0.0, 1.0]
	var baseline_steps: int = clampi(int(ceil(run / 1.5)), 12, 64)
	for i in range(1, baseline_steps):
		ts.append(float(i) / float(baseline_steps))
	for i in range(slit_count):
		var center_t: float = (float(i) + 1.0) / float(slit_count + 1)
		slit_t.append(center_t)
		ts.append(center_t)
		var half_t: float = (slit_w * 0.5 + 0.03) / run
		ts.append(clampf(center_t - half_t, 0.0, 1.0))
		ts.append(clampf(center_t + half_t, 0.0, 1.0))
	ts.sort()
	var unique_ts: Array[float] = []
	for value in ts:
		if unique_ts.is_empty() or value > unique_ts.back() + 0.00001:
			unique_ts.append(value)
	var pts := PackedVector3Array()
	var distances := PackedFloat32Array([0.0])
	for i in range(unique_ts.size()):
		var f: float = unique_ts[i]
		var p: Vector2 = a.lerp(b, f) + outward * (4.0 * sagitta * f * (1.0 - f))
		pts.append(Vector3(p.x, 0.0, p.y))
		if i > 0:
			distances.append(distances[i - 1] + pts[i - 1].distance_to(pts[i]))
	var openings: Array[Rect2] = []
	var wall_band := Vector2(clampf(slit_y - slit_h * 0.5, 0.25, h - slit_h - 0.25), slit_h)
	for center_t in slit_t:
		var index := 0
		for i in range(unique_ts.size()):
			if unique_ts[i] >= center_t:
				index = i
				break
		var distance: float = distances[index]
		openings.append(Rect2(distance - slit_w * 0.5, wall_band.x, slit_w, wall_band.y))
	var wall_bounds := _kit.curved_wall(pts, h, tb, t, SURF_STONE, openings)
	_log_mass("wall_%d_%s" % [r, String(seg["name"])], wall_bounds)

	# A bowed wall walk is a second shallow curved shell, not a box on the chord.
	var walk_h: float = CastleGeometry.PARAPET_RISE
	_kit.curved_wall(pts, walk_h, t + 2.0 * CastleGeometry.WALK_LIP, t + 2.0 * CastleGeometry.WALK_LIP, SURF_TRIM, [], h)
	if spec.battlements:
		var mw: float = CastleGeometry.merlon_width(spec)
		var pitch: float = mw + CastleGeometry.MERLON_GAP
		var count: int = int(run / pitch)
		for i in range(count):
			var f: float = (float(i) + 0.5) / float(count)
			var p: Vector2 = a.lerp(b, f) + outward * (4.0 * sagitta * f * (1.0 - f))
			var derivative: Vector2 = (b - a) + outward * (4.0 * sagitta * (1.0 - 2.0 * f))
			var tangent := derivative.normalized()
			var face_yaw := atan2(tangent.y, tangent.x) + PI * 0.5
			_emit_merlon(Vector3(mw, spec.merlon_h, t + 0.3),
				Vector3(p.x, h + walk_h + spec.merlon_h * 0.5, p.y), SURF_TRIM, face_yaw)

	for center_t in slit_t:
		var f: float = center_t
		var p: Vector2 = a.lerp(b, f) + outward * (4.0 * sagitta * f * (1.0 - f))
		var derivative: Vector2 = (b - a) + outward * (4.0 * sagitta * (1.0 - 2.0 * f))
		var tangent := derivative.normalized()
		var normal := Vector2(tangent.y, -tangent.x)
		var thick: float = lerpf(tb, t, slit_y / h)
		var surface_point: Vector2 = p + normal * (thick * 0.5 + CastleGeometry.OPENING_EPS)
		var angle: float = atan2(normal.x, normal.y)
		_opening(Vector3(surface_point.x, slit_y, surface_point.y), angle,
			slit_w, slit_h, &"slit", false, true, thick)
	total_height = maxf(total_height, h + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## Arrow slits down a slanted run, on the battered face itself.
func _run_slits(seg: Dictionary, r: int, loops: Array[float], emb: float) -> void:
	if loops.is_empty():
		return
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var h: float = CastleGeometry.wall_height(spec, r)
	var outward: Vector3 = seg["outward"]
	var mid: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var inner := Vector3(mid.x - outward.x * t, 0.0, mid.y - outward.z * t)
	var th: float = _batter_thickness(tb, t, LOOP_Y, h)
	var face: Vector3 = inner + outward * (th + CastleGeometry.OPENING_EPS)
	var along := Vector3(cos(seg["yaw"]), 0.0, -sin(seg["yaw"]))
	var points: Array[Vector3] = []
	for u in loops:
		points.append(face + along * u + Vector3(0.0, LOOP_Y, 0.0))
	# The slit's reveals line the skin it pierces, not the recess behind it.
	_emit_wall_slits(points, outward, true, th - emb)


## Where along a straight run its loops go: evenly spaced, less any that would
## open behind a building or stair or inside a tower.
func _run_loops(seg: Dictionary, r: int) -> Array[float]:
	var out: Array[float] = []
	var h: float = CastleGeometry.wall_height(spec, r)
	if not _loops_fit(h, CastleGeometry.wall_base_thickness(spec, r), CastleGeometry.wall_thickness(spec, r)):
		return out
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var run: float = seg["length"]
	var outward: Vector3 = seg["outward"]
	var mid: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var out2 := Vector2(outward.x, outward.z)
	var inner := mid - out2 * t
	var along := Vector2(cos(seg["yaw"]), -sin(seg["yaw"]))
	var th: float = _batter_thickness(tb, t, LOOP_Y, h)
	var n: int = clampi(int(run / SLIT_BAY), 1, 24)
	for i in range(n):
		var u: float = ((float(i) + 1.0) / (float(n) + 1.0) - 0.5) * run
		var mouth := inner + along * u
		if _loop_clear(mouth, mouth + out2 * th, -out2, along):
			out.append(u)
	return out


## The keep: a great square tower, a drum, a shell keep on its own plinth, or
## the tiered tenshu of a Japanese castle.
func _build_keep() -> void:
	var k: AABB = CastleGeometry.keep_aabb(spec)
	var c := Vector3(k.position.x + k.size.x / 2.0, k.position.y,
		k.position.z + k.size.z / 2.0)
	_log_mass("keep", k)
	var planned := _planned_interiors.has("keep")
	if planned:
		Interiors.emit(self, _planned_interiors["keep"])
		_build_planned_keep_crown(k)
		if spec.plan_kind != &"terraced" and not spec.terraced_fallback:
			_build_forebuilding()
		total_height = maxf(total_height, k.end.y + CastleGeometry.roof_rise(spec, k))
		return
	var opening_y: float = k.size.y * 0.55
	match spec.keep_shape:
		&"round", &"shell":
			var base_r: float = minf(k.size.x, k.size.z) / 2.0
			var top_r: float = base_r * 0.94
			_cut_keep_drum(c, base_r, top_r, k.size.y, opening_y, 14)
			_crenellate_ring(c, top_r, k.size.y, 14, SURF_TRIM)
		&"tiered":
			# A battered stone base carrying diminishing timber storeys. drum()
			# takes a CIRCUMradius: handing it the half-side made the plinth a
			# square inscribed in the keep's own footprint, which shrank it off
			# the wall it is supposed to lap and left the tenshu standing free.
			# A tenshu is squat: a deep stone base carrying storeys that step
			# down over most of the footprint. Three narrow tiers on a shallow
			# plinth gave a spike, not Himeji.
			var half: float = minf(k.size.x, k.size.z) / 2.0
			var plinth: float = k.size.y * CastleGeometry.TENSHU_PLINTH
			var corner: float = half * sqrt(2.0)
			_kit.drum(c, corner, corner * 0.88, plinth, SURF_STONE, 4, PI / 4.0)
			_kit.tiered_taper(c + Vector3(0, plinth, 0), half * 1.85,
				k.size.y - plinth, SURF_ROOF, CastleGeometry.TENSHU_TIERS, 0.14)
			_shell_openings(c, corner * 0.91, plinth * 0.5, 4, PI / 4.0)
		_:
			if not planned:
				_cut_keep_shell(k, opening_y)
			_crenellate_rect(k, k.size.y, SURF_TRIM)
			_kit.hip_roof_at(Transform3D(Basis(), c + Vector3(0, k.size.y, 0)),
				k.size.x * 0.8, k.size.z * 0.8, CastleGeometry.roof_rise(spec, k), SURF_ROOF)
			if not planned:
				_keep_windows(k, opening_y, spec.window_style)
	total_height = maxf(total_height, k.size.y + CastleGeometry.roof_rise(spec, k))


## A guarded first-floor entrance: masonry cheeks, real treads and a slate
## lean-to shelter. No solid envelope is emitted across the route inside it.
func _build_forebuilding() -> void:
	var fore := CastleGeometry.forebuilding(spec)
	if fore.is_empty():
		return
	if spec.plan_kind == &"bergfried":
		_build_bergfried_forebuilding(fore)
		return
	tag("forebuilding")
	host("forebuilding")
	var front: Vector2 = fore.front
	var run: float = fore.run
	var height: float = fore.height
	var clear: float = fore.clear
	var width: float = fore.width
	var wall: float = fore.wall
	var bounds := AABB()
	var first := true
	for step in int(fore.steps):
		var top := height * (step + 1) / int(fore.steps)
		var z := front.y + (step + 0.5) * preload("castle_access_geometry.gd").TREAD
		var size := Vector3(clear, top, preload("castle_access_geometry.gd").TREAD)
		var at := Vector3(front.x, top * 0.5, z)
		var row := component_box("forebuilding_tread", size, Transform3D(Basis.IDENTITY, at), SURF_STONE)
		_log_part("forebuilding_step", at, size)
		bounds = component_aabb(row) if first else bounds.merge(component_aabb(row))
		first = false
	var landing_start := front.y + run
	for side in [-1.0, 1.0]:
		var x := front.x + float(side) * (clear + wall) * 0.5
		var cheek := component_slab("forebuilding_wall", PackedVector3Array([
			Vector3(x, 0, front.y), Vector3(x, 0, landing_start),
			Vector3(x, height + 2.45, landing_start), Vector3(x, 2.45, front.y)]), wall, SURF_STONE, false)
		bounds = bounds.merge(component_aabb(cheek))
	var end: Vector2 = fore.at
	var landing_row := component_box("forebuilding_landing", Vector3(clear, 0.2, end.y - landing_start + 0.05),
		Transform3D(Basis.IDENTITY, Vector3(front.x, height - 0.1, (landing_start + end.y + 0.05) * 0.5)), SURF_STONE)
	bounds = bounds.merge(component_aabb(landing_row))
	var outer: Vector2 = fore.door_outer
	for side in [-1.0, 1.0]:
		var cheek := component_box("forebuilding_wall", Vector3(wall, 2.5, outer.y - landing_start),
			Transform3D(Basis.IDENTITY, Vector3(front.x + side * (clear + wall) * 0.5, height + 1.25, (landing_start + outer.y) * 0.5)), SURF_STONE)
		bounds = bounds.merge(component_aabb(cheek))
	var roof_half := width * 0.5 + 0.12
	for band in [Vector3(front.y - 0.12, landing_start, 0), Vector3(landing_start, outer.y, 1)]:
		var low := 2.5 if band.z == 0 else height + 2.5
		var high := height + 2.5
		var roof := component_slab("forebuilding_roof", PackedVector3Array([
			Vector3(front.x - roof_half, low, band.x), Vector3(front.x + roof_half, low, band.x),
			Vector3(front.x + roof_half, high, band.y), Vector3(front.x - roof_half, high, band.y)]), 0.15, SURF_ROOF)
		bounds = bounds.merge(component_aabb(roof))
	_log_mass("forebuilding", bounds)
	mass_log[-1].entry_height = height
	mass_log[-1].footprint = fore.footprint
	host_end()
	tag("keep")


## A side-facing Bergfried door gets a matching stair axis. The hall stands
## beyond its toe, leaving the protected ascent clear.
func _build_bergfried_forebuilding(fore: Dictionary) -> void:
	tag("forebuilding")
	host("forebuilding")
	var front: Vector2 = fore.front
	var normal: Vector2 = fore.normal
	var direction := -normal
	var side := Vector2(direction.y, -direction.x)
	var basis := Basis(Vector3(side.x, 0, side.y), Vector3.UP,
		Vector3(direction.x, 0, direction.y))
	var height: float = fore.height
	var run: float = fore.run
	var steps: int = int(fore.steps)
	var clear: float = fore.clear
	var wall: float = fore.wall
	var bounds := AABB()
	var first := true
	for step in steps:
		var top := height * float(step + 1) / float(steps)
		var at := front + direction * ((float(step) + 0.5) * preload("castle_access_geometry.gd").TREAD)
		var centre := Vector3(at.x, top * 0.5, at.y)
		var row := component_box("forebuilding_tread",
			Vector3(clear, top, preload("castle_access_geometry.gd").TREAD),
			Transform3D(basis, centre), SURF_STONE)
		_log_part("forebuilding_step", centre, Vector3(clear, top,
			preload("castle_access_geometry.gd").TREAD))
		var box := component_aabb(row)
		bounds = box if first else bounds.merge(box)
		first = false
	var landing_start := front + direction * run
	var door_at: Vector2 = fore.at
	var landing_len: float = maxf(float(fore.landing), 0.8)
	var landing_centre := landing_start + direction * landing_len * 0.5
	var landing := component_box("forebuilding_landing", Vector3(clear, 0.2, landing_len),
		Transform3D(basis, Vector3(landing_centre.x, height - 0.1, landing_centre.y)), SURF_STONE)
	bounds = bounds.merge(component_aabb(landing))
	for sign in [-1.0, 1.0]:
		var offset: Vector2 = side * float(sign) * (clear + wall) * 0.5
		var toe: Vector2 = front + offset
		var landing_toe: Vector2 = landing_start + offset
		var door_toe: Vector2 = door_at + offset
		var cheek := component_slab("forebuilding_wall", PackedVector3Array([
			Vector3(toe.x, 0.0, toe.y),
			Vector3(landing_toe.x, 0.0, landing_toe.y),
			Vector3(door_toe.x, height + 2.75, door_toe.y),
			Vector3(toe.x, 2.75, toe.y)]), wall, SURF_STONE, false)
		bounds = bounds.merge(component_aabb(cheek))
	# A single pitched roof plane follows the stair from its toe to the raised
	# landing. It remains above the headroom line at every logged tread.
	var roof_half: float = float(fore.width) * 0.5 + 0.12
	var roof_vertices := PackedVector3Array([
		Vector3(front.x + side.x * roof_half, 2.8, front.y + side.y * roof_half),
		Vector3(front.x - side.x * roof_half, 2.8, front.y - side.y * roof_half),
		Vector3(door_at.x - side.x * roof_half, height + 2.8, door_at.y - side.y * roof_half),
		Vector3(door_at.x + side.x * roof_half, height + 2.8, door_at.y + side.y * roof_half)])
	var roof := component_slab("forebuilding_roof", roof_vertices, 0.15, SURF_ROOF)
	bounds = bounds.merge(component_aabb(roof))
	_log_mass("forebuilding", bounds)
	mass_log.back().entry_height = height
	mass_log.back().footprint = fore.footprint
	host_end()
	tag("keep")


## The plan owns the occupied outline. Crowns cover that same outline and
## never restore the former solid drum/plinth over the new rooms.
func _build_planned_keep_crown(k: AABB) -> void:
	var row: Dictionary = _planned_interiors["keep"]
	var p: HousePlan = row.plan
	var xf: Transform3D = row.transform
	var top_outline := KeepPlan.outer_outline(spec, p.spec.storeys - 1, p.spec.storeys)
	var roof_y := k.size.y
	var face := PackedVector3Array()
	for point in top_outline:
		face.append(xf * Vector3(point.x, roof_y, point.y))
	_kit.slab_poly(face, RoofShape.DEPTH, SURF_ROOF, true)
	if spec.keep_shape in [&"round", &"shell"]:
		_crenellate_ring(Vector3(k.get_center().x, k.position.y, k.get_center().z),
			minf(k.size.x,k.size.z) * 0.5, k.size.y, 14, SURF_TRIM)
	elif spec.keep_shape == &"tiered":
		# Roof rings cap the exposed shoulders of every receding storey.
		for level in range(1, p.spec.storeys):
			var lower := Poly.offset(KeepPlan.outer_outline(spec, level - 1, p.spec.storeys), 0.18)
			var upper := KeepPlan.outer_outline(spec, level, p.spec.storeys)
			for piece in RoofShape.subtract(lower, upper):
				var ring := PackedVector3Array()
				for point in piece:
					ring.append(xf * Vector3(point.x, level * p.spec.height, point.y))
				_kit.slab_poly(ring, RoofShape.DEPTH, SURF_ROOF, true)
		var bounds := Poly.bounding_rect(top_outline)
		_kit.hip_roof_at(xf.translated_local(Vector3(0, roof_y, 0)), bounds.size.x + 0.3,
			bounds.size.y + 0.3, CastleGeometry.roof_rise(spec, k), SURF_ROOF)
	else:
		_crenellate_rect(k, k.size.y, SURF_TRIM)
		_kit.hip_roof_at(xf.translated_local(Vector3(0, roof_y, 0)),
			k.size.x * 0.8, k.size.z * 0.8, CastleGeometry.roof_rise(spec, k), SURF_ROOF)


# --------------------------------------------------------------- primitives

## Cut the four keep lights from their emitted polygon facets. A 14-sided
## drum has no exact east/west facet, so choose the nearest face and put the
## log, trim, and stone partition on that same chord.
func _cut_keep_drum(c: Vector3, base_r: float, top_r: float, h: float,
		window_y: float, sides: int, rot := 0.0) -> void:
	var cut_facets: Dictionary = {}
	for cardinal in range(4):
		var wanted := Vector3(sin(float(cardinal) * PI * 0.5), 0.0,
			cos(float(cardinal) * PI * 0.5))
		var picked := 0
		var best := -INF
		for side in range(sides):
			var mid := rot + TAU * (float(side) + 0.5) / float(sides)
			var score := Vector3(cos(mid), 0.0, sin(mid)).dot(wanted)
			if score > best:
				best = score
				picked = side
		cut_facets[picked] = true
	var window_h: float = minf(spec.window_h, h * 0.28)
	var bottom: float = clampf(window_y - window_h * 0.5, 0.3, h - window_h - 0.3)
	var top: float = bottom + window_h
	var center_y: float = (bottom + top) * 0.5
	var mid_r: float = lerpf(base_r, top_r, center_y / h)
	var half_span: float = mid_r * sin(PI / float(sides))
	var window_w: float = minf(spec.window_w, half_span * 1.3)
	var lo: float = clampf(0.5 - window_w / (4.0 * half_span), 0.08, 0.42)
	var hi: float = 1.0 - lo
	var st := _kit.surface(SURF_STONE)
	for side in range(sides):
		var a0: float = rot + TAU * float(side) / float(sides)
		var a1: float = rot + TAU * float(side + 1) / float(sides)
		if cut_facets.has(side):
			for panel in [Vector4(0.0, lo, 0.0, h), Vector4(hi, 1.0, 0.0, h),
					Vector4(lo, hi, 0.0, bottom), Vector4(lo, hi, top, h)]:
				_keep_drum_panel(st, c, base_r, top_r, h, a0, a1, panel)
		else:
			_keep_drum_panel(st, c, base_r, top_r, h, a0, a1,
				Vector4(0.0, 1.0, 0.0, h))
		var cap := c + Vector3.UP * h
		var p0 := cap + Vector3(cos(a0) * top_r, 0.0, sin(a0) * top_r)
		var p1 := cap + Vector3(cos(a1) * top_r, 0.0, sin(a1) * top_r)
		_kit._tri(st, p0, p1, cap)
	for side in cut_facets:
		var mid: float = rot + TAU * (float(side) + 0.5) / float(sides)
		var normal := Vector3(cos(mid), 0.0, sin(mid))
		var angle := atan2(normal.x, normal.z)
		var face_r: float = mid_r * cos(PI / float(sides)) + CastleGeometry.OPENING_EPS
		var pos := c + normal * face_r + Vector3.UP * center_y
		_opening(pos, angle, window_w, window_h, spec.window_style, false, true,
			minf(spec.wall_thickness, top_r * 0.5))


func _keep_drum_panel(st: SurfaceTool, c: Vector3, base_r: float,
		top_r: float, h: float, a0: float, a1: float, panel: Vector4) -> void:
	if panel.y - panel.x <= 0.001 or panel.w - panel.z <= 0.001:
		return
	var p0 := _drum_point(c, base_r, top_r, h, a0, a1, panel.x, panel.z)
	var p1 := _drum_point(c, base_r, top_r, h, a0, a1, panel.y, panel.z)
	var p2 := _drum_point(c, base_r, top_r, h, a0, a1, panel.y, panel.w)
	var p3 := _drum_point(c, base_r, top_r, h, a0, a1, panel.x, panel.w)
	_kit._quad(st, p0, p1, p2, p3)


## Emit a battered tower skin as facet panels, omitting a rectangular aperture
## from the facet that faces the curtain. CastleGeometry's circumradii are used
## at both ends, so the opening follows the real polygon face as it tapers.
func _battered_tower_skin(c: Vector3, base_r: float, top_r: float, h: float,
		sides: int, rot: float, outward: Vector3) -> Dictionary:
	var picked := -1
	var best := -INF
	for side in range(sides):
		var mid := rot + TAU * (float(side) + 0.5) / sides
		var n := Vector3(cos(mid), 0, sin(mid))
		var score := n.dot(outward.normalized())
		if score > best:
			best = score
			picked = side
	var slit_y := h * 0.6
	var slit_h := minf(1.4, h * 0.3)
	var slit_w := 0.32
	var bottom := slit_y - slit_h * 0.5
	var top := slit_y + slit_h * 0.5
	var picked_mid := rot + TAU * (float(picked) + 0.5) / sides
	var mid_radius := lerpf(base_r, top_r, slit_y / h)
	var half_span := maxf(mid_radius * sin(PI / float(sides)), 0.1)
	var s0 := clampf(0.5 - slit_w / (4.0 * half_span), 0.08, 0.42)
	var s1 := 1.0 - s0
	var st := _kit.surface(SURF_STONE)
	for side in range(sides):
		var a0 := rot + TAU * float(side) / sides
		var a1 := rot + TAU * float(side + 1) / sides
		var is_cut := side == picked
		var left_end := s0 if is_cut else 1.0
		var ranges: Array[Vector4] = []
		if is_cut:
			ranges.append(Vector4(0.0, left_end, 0.0, h))
			ranges.append(Vector4(s1, 1.0, 0.0, h))
			ranges.append(Vector4(s0, s1, 0.0, bottom))
			ranges.append(Vector4(s0, s1, top, h))
		else:
			ranges.append(Vector4(0.0, 1.0, 0.0, h))
		for rrange in ranges:
			if rrange.x >= rrange.y or rrange.z >= rrange.w:
				continue
			var p0 := _drum_point(c, base_r, top_r, h, a0, a1, rrange.x, rrange.z)
			var p1 := _drum_point(c, base_r, top_r, h, a0, a1, rrange.y, rrange.z)
			var p2 := _drum_point(c, base_r, top_r, h, a0, a1, rrange.y, rrange.w)
			var p3 := _drum_point(c, base_r, top_r, h, a0, a1, rrange.x, rrange.w)
			_kit._quad(st, p0, p1, p2, p3)
	var cap := c + Vector3.UP * h
	for side in range(sides):
		var a0 := rot + TAU * float(side) / sides
		var a1 := rot + TAU * float(side + 1) / sides
		var p0 := cap + Vector3(cos(a0) * top_r, 0, sin(a0) * top_r)
		var p1 := cap + Vector3(cos(a1) * top_r, 0, sin(a1) * top_r)
		_kit._tri(st, p0, p1, cap)
	var normal := Vector3(cos(picked_mid), 0, sin(picked_mid))
	var angle := atan2(normal.x, normal.z)
	var face_r := mid_radius * cos(PI / float(sides)) + CastleGeometry.OPENING_EPS
	return {"pos": c + normal * face_r + Vector3.UP * slit_y,
		"angle": angle, "width": slit_w, "height": slit_h,
		"depth": maxf(spec.wall_thickness, 0.35)}


func _drum_point(c: Vector3, base_r: float, top_r: float, h: float,
		a0: float, a1: float, along: float, y: float) -> Vector3:
	var f := y / h
	var radius := lerpf(base_r, top_r, f)
	var p0 := c + Vector3(cos(a0) * radius, y, sin(a0) * radius)
	var p1 := c + Vector3(cos(a1) * radius, y, sin(a1) * radius)
	return p0.lerp(p1, along)

## A square keep is a masonry shell around a narrow through-window band. The
## four inner returns are real reveals: the stone wall is absent through its
## thickness, rather than hidden behind the dark opening material.
func _cut_keep_shell(a: AABB, window_y: float) -> void:
	var w: float = minf(spec.window_w, minf(a.size.x, a.size.z) * 0.28)
	var h: float = minf(spec.window_h, a.size.y * 0.22)
	var y0: float = clampf(window_y - h * 0.5, 0.4, a.size.y - h - 0.4)
	var y1: float = y0 + h
	var cx: float = a.position.x + a.size.x * 0.5
	var cz: float = a.position.z + a.size.z * 0.5
	var x0: float = a.position.x
	var x1: float = a.position.x + a.size.x
	if y0 > 0.01:
		box(Vector3(a.size.x, y0, a.size.z), Vector3(cx, y0 * 0.5, cz), SURF_STONE)
	if y1 < a.size.y - 0.01:
		box(Vector3(a.size.x, a.size.y - y1, a.size.z),
			Vector3(cx, (y1 + a.size.y) * 0.5, cz), SURF_STONE)
	var half_w := w * 0.5
	var left := cx - half_w - x0
	var right := x1 - (cx + half_w)
	var depth := minf(spec.wall_thickness, minf(a.size.x, a.size.z) * 0.22)
	var front_z := a.position.z + depth * 0.5
	var back_z := a.position.z + a.size.z - depth * 0.5
	var band_y := (y0 + y1) * 0.5
	for face_z in [front_z, back_z]:
		if left > 0.01:
			box(Vector3(left, h, depth), Vector3((x0 + cx - half_w) * 0.5, band_y, face_z), SURF_STONE)
		if right > 0.01:
			box(Vector3(right, h, depth), Vector3((cx + half_w + x1) * 0.5, band_y, face_z), SURF_STONE)
	var cut_z0 := cz - half_w
	var cut_z1 := cz + half_w
	var back_len := maxf(0.0, a.position.z + a.size.z - depth - cut_z1)
	var front_len := maxf(0.0, cut_z0 - (a.position.z + depth))
	for face_x in [a.position.x + depth * 0.5, a.position.x + a.size.x - depth * 0.5]:
		if front_len > 0.01:
			box(Vector3(depth, h, front_len), Vector3(face_x, band_y, a.position.z + depth + front_len * 0.5), SURF_STONE)
		if back_len > 0.01:
			box(Vector3(depth, h, back_len), Vector3(face_x, band_y, cut_z1 + back_len * 0.5), SURF_STONE)


func _keep_windows(a: AABB, y: float, style: StringName) -> void:
	var w: float = minf(spec.window_w, minf(a.size.x, a.size.z) * 0.28)
	var h: float = minf(spec.window_h, a.size.y * 0.22)
	var cx := a.position.x + a.size.x * 0.5
	var cz := a.position.z + a.size.z * 0.5
	var zfront := a.position.z - CastleGeometry.OPENING_EPS
	var zback := a.position.z + a.size.z + CastleGeometry.OPENING_EPS
	var xleft := a.position.x - CastleGeometry.OPENING_EPS
	var xright := a.position.x + a.size.x + CastleGeometry.OPENING_EPS
	var reveal_depth := minf(spec.wall_thickness, minf(a.size.x, a.size.z) * 0.22)
	_opening(Vector3(cx, y, zfront), PI, w, h, style, false, true, reveal_depth)
	_opening(Vector3(cx, y, zback), 0.0, w, h, style, false, true, reveal_depth)
	_opening(Vector3(xleft, y, cz), -PI * 0.5, w, h, style, false, true, reveal_depth)
	_opening(Vector3(xright, y, cz), PI * 0.5, w, h, style, false, true, reveal_depth)

## Metres of bailey-facing wall per window on a hall or chapel: a row of
## windows, not one every five metres.
const RANGE_BAY := 3.0


## A block, its roof, and a window in each long face: the shape of every range
## in the design, whether it is a hall, a wing or a whole house. `faces` limits
## the windows to the listed outward normals (empty = every face); `bay` is
## the metres of wall per window.
## What stands in the bailey besides the keep, the hall and the chapel
## (CAS-012). The layout is the generator's -- see `CastleGenerator
## .bailey_buildings` -- and all this does is raise the shell of each and log
## it, so the massing check has something to measure and the assembler has
## somewhere to set the real shop down.
func _build_yard() -> void:
	tag("yard")
	_yard_ranges = CastleGenerator.bailey_buildings(spec)
	_yard_well = CastleGenerator.bailey_well(spec)
	for b in _yard_ranges:
		var rect: Rect2 = b["rect"]
		var h: float = YARD_WALL_H
		var a := AABB(Vector3(rect.position.x,
			CastleGeometry.ring_ground_y(spec, CastleGeometry.inner_ring(spec)),
			rect.position.y),
			Vector3(rect.size.x, h, rect.size.y))
		var row := Interiors.yard(spec, b)
		var id := "yard_%s" % String(b["business"])
		if row.has("errors"):
			interior_errors.append("%s: %s" % [id, row.errors])
		else:
			_planned_interiors[id] = row
		_range(a, id, SURF_STONE, true, [], RANGE_BAY)
	var well: Dictionary = _yard_well
	_yards = CastleYards.plan(spec, _yard_ranges, well)
	if not _yards.is_empty():
		mark_dress()
		CastleYardBuilder.emit(self, _yards)
	if well.is_empty():
		return
	var at: Vector2 = well["pos"]
	var kit := PropKit.new(_kit, SURF_STONE, SURF_TRIM, SURF_ROOF, SURF_OPEN)
	var ground: float = CastleGeometry.ring_ground_y(spec, CastleGeometry.inner_ring(spec))
	var box: AABB = kit.well(Vector3(at.x, ground, at.y), 0.0, float(well["radius"]))
	if box.size.x > 0.01:
		_log_mass("well", box)
		total_height = maxf(total_height, box.position.y + box.size.y)


## How high a yard building stands to its eaves. A stable and a cookshop are
## single-storey buildings in a courtyard, not ranges against the wall.
const YARD_WALL_H := 3.2


func _range(a: AABB, mass_name: String, surf: int, roofed: bool,
		faces: Array = [], bay := 5.0) -> void:
	if _planned_interiors.has(mass_name):
		Interiors.emit(self, _planned_interiors[mass_name])
	else:
		_box_aabb(a, surf)
	_log_mass(mass_name, a)
	var cx: float = a.position.x + a.size.x / 2.0
	var cz: float = a.position.z + a.size.z / 2.0
	if roofed:
		var rise: float = CastleGeometry.roof_rise(spec, a)
		var along_x: bool = CastleGeometry.ridge_along_x(a)
		var yaw: float = PI / 2.0 if along_x else 0.0
		var span: float = a.size.z if along_x else a.size.x
		var along: float = a.size.x if along_x else a.size.z
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(cx, a.size.y, cz))
		var roof_start := _roof_faces.size()
		var local_roof := RoofShape.faces(span + EAVE, along + EAVE * 0.8, rise)
		_kit.ridge_roof(xf, span + EAVE, along + EAVE * 0.8, rise, SURF_ROOF,
			SURF_STONE, span, along, 0.3, 0.0, _roof_faces)
		total_height = maxf(total_height, a.size.y + rise)
		if spec.dormers:
			_roof_dormers(xf, local_roof, roof_start, along, mass_name,
				(span + EAVE) * 0.5, rise, false)
	if not _planned_interiors.has(mass_name):
		_face_openings(a, a.size.y * 0.5, spec.window_style, faces, bay)


## Windows in the middle of each of a block's four faces, facing out of it.
## Bays are spaced off the face, so a long range gets a row and a small annexe
## gets one.
func _face_openings(a: AABB, y: float, style: StringName, only: Array = [],
		bay := 5.0) -> void:
	var eps: float = CastleGeometry.OPENING_EPS
	var faces := [
		{"n": Vector3(0, 0, -1), "len": a.size.x, "ang": PI},
		{"n": Vector3(0, 0, 1), "len": a.size.x, "ang": 0.0},
		{"n": Vector3(-1, 0, 0), "len": a.size.z, "ang": -PI / 2.0},
		{"n": Vector3(1, 0, 0), "len": a.size.z, "ang": PI / 2.0},
	]
	var c := Vector3(a.position.x + a.size.x / 2.0, y, a.position.z + a.size.z / 2.0)
	for f in faces:
		var n: Vector3 = f["n"]
		if not only.is_empty():
			var wanted := false
			for o in only:
				if (o as Vector3).dot(n) > 0.9:
					wanted = true
			if not wanted:
				continue
		var run: float = f["len"]
		var count: int = clampi(int(run / bay), 1, 12)
		var half: Vector3 = Vector3(a.size.x, 0.0, a.size.z) / 2.0
		var face_c: Vector3 = c + Vector3(n.x * (half.x + eps), 0.0, n.z * (half.z + eps))
		var along := Vector3(n.z, 0.0, -n.x)      # the face's own long axis
		for i in range(count):
			var t: float = (float(i) + 1.0) / (float(count) + 1.0) - 0.5
			_opening(face_c + along * (run * t), f["ang"], spec.window_w,
				spec.window_h, style)


## Openings round a revolved shaft, one to each cardinal face.
##
## A drum or a tiered keep is narrower than the box its mass is logged as, so
## an opening placed on that box hangs in the air beside the building -- which
## is what the voxel sweep caught the tenshu doing. `radius` is the shell's
## CIRCUMradius at the height the openings sit; the face itself is the apothem,
## and on a four-sided shaft the difference between the two is 30% of the keep.
func _shell_openings(c: Vector3, radius: float, y: float, sides: int,
		rot := 0.0) -> void:
	var eps: float = CastleGeometry.OPENING_EPS
	var face_r: float = radius * cos(PI / float(sides)) + eps
	for k in range(4):
		var ang: float = rot + PI / 2.0 * k
		_opening(c + Vector3(sin(ang) * face_r, y, cos(ang) * face_r),
			ang, spec.window_w, spec.window_h, spec.window_style)


## A wall run emitted as a battered stack: the inner face is vertical at every
## course, the outer face spreads as it descends. Pinning the inner face is what
## lets everything inside the bailey ignore the talus completely.
func _battered_wall(a: AABB, top_thick: float, outward: Vector3,
		cutouts: Array[Vector3] = [], passage := Rect2()) -> void:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	var h: float = a.size.y
	var run_min: float = a.position.z if axis == 0 else a.position.x
	var run_max: float = run_min + (a.size.z if axis == 0 else a.size.x)
	# The loops (see LOOP_Y): positions along the run; each is embrasured.
	var loops: Array[float] = []
	for cut in cutouts:
		loops.append(cut.z if axis == 0 else cut.x)
	var emb := 0.0
	if not loops.is_empty():
		emb = _embrasure_depth(_batter_thickness(base_thick, top_thick,
			minf(EMBRASURE_H, h) - 0.01, h), h)
	var levels: Array[float] = [0.0, h]
	for i in range(1, BATTER_STEPS):
		levels.append(h * float(i) / BATTER_STEPS)
	if not loops.is_empty():
		_loop_levels(levels, h, emb > 0.0)
	if passage.has_area():
		levels.append(clampf(passage.position.y, 0.0, h))
		levels.append(clampf(passage.end.y, 0.0, h))
	levels.sort()
	for i in range(levels.size() - 1):
		var y0: float = levels[i]
		var y1: float = levels[i + 1]
		if y1 <= y0 + 0.001:
			continue
		var ymid := (y0 + y1) * 0.5
		var th: float = _batter_thickness(base_thick, top_thick, ymid, h)
		var pieces := _course_cuts(run_min, run_max, y0, y1, th, loops, emb)
		if passage.has_area() and ymid >= passage.position.y and ymid <= passage.end.y:
			var cut: Array[Vector4] = []
			for piece in pieces:
				for keep in [Vector2(piece.x, minf(piece.y, passage.position.x)),
						Vector2(maxf(piece.x, passage.end.x), piece.y)]:
					if keep.y > keep.x + 0.01:
						cut.append(Vector4(keep.x, keep.y, piece.z, piece.w))
			pieces = cut
		for piece in pieces:
			var c: float = inner + outward[axis] * (piece.z + piece.w) * 0.5
			var u: float = (piece.x + piece.y) * 0.5
			var size := Vector3(piece.w - piece.z if axis == 0 else piece.y - piece.x, y1 - y0,
				piece.y - piece.x if axis == 0 else piece.w - piece.z)
			var pos := Vector3(c if axis == 0 else u, ymid, u if axis == 0 else c)
			box(size, pos, SURF_STONE)


## The wall walk and its merlons, following the wall's own top face.
func _wall_top(a: AABB, outward: Vector3, top_thick: float) -> void:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	var walk: float = inner + outward[axis] * top_thick / 2.0
	var run: float = a.size.z if axis == 0 else a.size.x
	var cx: float = walk if axis == 0 else a.position.x + a.size.x / 2.0
	var cz: float = a.position.z + a.size.z / 2.0 if axis == 0 else walk
	var coping: float = top_thick + 2.0 * CastleGeometry.WALK_LIP
	box(Vector3(coping if axis == 0 else run, CastleGeometry.PARAPET_RISE,
			run if axis == 0 else coping),
		Vector3(cx, a.size.y + CastleGeometry.PARAPET_RISE / 2.0, cz), SURF_TRIM)
	if not spec.battlements:
		return
	var edge: float = inner + outward[axis] * (top_thick - spec.merlon_h * 0.35)
	var from_p: Vector3
	var to_p: Vector3
	if axis == 0:
		from_p = Vector3(edge, 0.0, a.position.z)
		to_p = Vector3(edge, 0.0, a.position.z + a.size.z)
	else:
		from_p = Vector3(a.position.x, 0.0, edge)
		to_p = Vector3(a.position.x + a.size.x, 0.0, edge)
	_crenellate(from_p, to_p, a.size.y + CastleGeometry.PARAPET_RISE,
		spec.merlon_h * 0.7, SURF_TRIM)


## Arrow slits down the outer face of a wall run. The face is battered, so the
## slit has to follow it: placed on the base plane instead, every one of them
## would hang in the air a metre outside a wall that had already stepped in.
func _wall_slit_positions(a: AABB, outward: Vector3, top_thick: float) -> Array[Vector3]:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	var points: Array[Vector3] = []
	if not _loops_fit(a.size.y, base_thick, top_thick):
		return points
	var y: float = LOOP_Y
	var th: float = _batter_thickness(base_thick, top_thick, y, a.size.y)
	var face: float = inner + outward[axis] * (th + CastleGeometry.OPENING_EPS)
	var run: float = a.size.z if axis == 0 else a.size.x
	var n: int = clampi(int(run / SLIT_BAY), 1, 24)
	var out2 := Vector2(outward.x, outward.z)
	var along := Vector2(0.0, 1.0) if axis == 0 else Vector2(1.0, 0.0)
	for i in range(n):
		var f: float = (float(i) + 1.0) / (float(n) + 1.0)
		var p: Vector3
		if axis == 0:
			p = Vector3(face, y, lerpf(a.position.z, a.position.z + a.size.z, f))
		else:
			p = Vector3(lerpf(a.position.x, a.position.x + a.size.x, f), y, face)
		var slit := Vector2(p.x, p.z)
		var mouth := slit - out2 * (th + CastleGeometry.OPENING_EPS)
		if _loop_clear(mouth, slit, -out2, along):
			points.append(p)
	return points


## How deep a straight wall's slit reveals go: the skin, not the recess.
static func _loop_reveal(base_thick: float, top_thick: float, h: float) -> float:
	var th := _batter_thickness(base_thick, top_thick, LOOP_Y, h)
	return th - _embrasure_depth(_batter_thickness(base_thick, top_thick,
		minf(EMBRASURE_H, h) - 0.01, h), h)


func _emit_wall_slits(points: Array[Vector3], outward: Vector3,
		through := false, reveal_depth := 0.14) -> void:
	var ang: float = atan2(outward.x, outward.z)
	for p in points:
		_opening(p, ang, 0.32, 1.5, &"slit", false, through, reveal_depth)


## One castle tower: a battered shaft, its cap, its parapet and its slits. The
## shape (round, square, polygonal) is a segment count on the same primitive.
## `vertex` is the tower's index on its ring, so the great tower (CAS-002)
## is built at its own size; -1 for a side or gate tower.
func _tower(c: Vector3, r: int, mass_name: String, outward: Vector3,
		vertex := -1) -> void:
	var sides: int = CastleGeometry.tower_sides(spec)
	var rot: float = CastleGeometry.tower_rotation(spec)
	var h: float = CastleGeometry.tower_height_at(spec, r, vertex)
	var top_r: float = CastleGeometry.tower_radius_for(spec,
		CastleGeometry.tower_half_at(spec, r, vertex))
	var base_r: float = CastleGeometry.tower_radius_for(spec,
		CastleGeometry.tower_base_half_at(spec, r, vertex))
	var palatial := spec.style in [&"bavarian", &"french_chateau"]
	var slit: Dictionary = {}
	if _planned_interiors.has(mass_name):
		var row: Dictionary = _planned_interiors[mass_name]
		Interiors.emit(self, row)
		_mural_landing(row)
	elif palatial:
		_palatial_tower_skin(c, base_r, top_r, h, sides, rot, outward)
	else:
		slit = _battered_tower_skin(c, base_r, top_r, h, sides, rot, outward)
	# A flat-topped tower needs a real deck under its crenellations.  The old
	# ring emitted only the merlon blocks, leaving the roof envelope visible
	# through the open top and making those blocks read as floating.  The deck
	# is also the ownership plane used to terminate the two range roofs at a
	# bend, so its top is deliberately above the range eave.
	var deck_h: float = CastleGeometry.PARAPET_RISE if spec.tower_roof == &"flat" else 0.0
	var deck_r: float = (top_r + EAVE) if spec.battlements else top_r * 1.12
	if deck_h > 0.0:
		_kit.drum(c + Vector3.UP * h, deck_r, deck_r, deck_h,
			SURF_TRIM, sides, rot)
		_log_part("tower_deck", c + Vector3.UP * (h + deck_h * 0.5),
			Vector3(deck_r * 2.0, deck_h, deck_r * 2.0), rot)
	var cover := PackedVector3Array()
	for i in range(sides):
		var angle := rot + TAU * i / sides
		cover.append(c + Vector3(cos(angle) * deck_r, h + deck_h, sin(angle) * deck_r))
	_roof_covers.append(cover)
	_log_mass(mass_name, CastleGeometry.tower_aabb(spec, r, c, vertex))
	_log_part("tower", c + Vector3(0, h / 2.0, 0), Vector3(top_r * 2.0, h, top_r * 2.0))

	var rise: float = CastleGeometry.tower_roof_rise_at(spec, r, vertex)
	match spec.tower_roof:
		&"cone":
			_kit.cone(top_r * 1.08, rise, c + Vector3(0, h, 0), SURF_ROOF, sides, rot)
		&"pyramid":
			_kit.stepped_taper(c + Vector3(0, h, 0), top_r * 2.1, rise, SURF_ROOF, 3, 0.2)
		&"tiered":
			_kit.tiered_taper(c + Vector3(0, h, 0), top_r * 2.0, rise, SURF_ROOF, 2, 0.15)
		_:
			if spec.battlements:
				var parapet_r: float = deck_r if spec.tower_shape == &"round" else deck_r * cos(PI / float(sides))
				_crenellate_ring(c, parapet_r, h + deck_h, sides, SURF_TRIM)
	total_height = maxf(total_height, h + rise)

	# Cut one slit into the actual outward facet; the tower's buried faces stay shut.
	if not slit.is_empty():
		_opening(slit.pos, slit.angle, slit.width, slit.height, &"slit", false, true, slit.depth)


## A small landing joins the tower doorway to the continuous curtain coping.
## It follows the actual floor elevation; a short rise to the coping stays
## within the same single-step contract as the castle's other stone landings.
func _mural_landing(row: Dictionary) -> void:
	var rect: Rect2 = row.walk_landing
	var plan: HousePlan = row.plan
	var door: Dictionary = plan.doors[plan.entrance()]
	var floor_y := HousePlan.record_storey(door) * plan.spec.height + HouseGeometry.FLOOR_T
	var y := minf(floor_y, float(row.walk_y))
	var size := Vector3(rect.size.x, 0.22, rect.size.y)
	var point := Vector3(rect.get_center().x, y - size.y * 0.5, rect.get_center().y)
	host(row.id)
	component_box("tower_access_landing", size, Transform3D(Basis.IDENTITY, point), SURF_TRIM)
	for span in row.get("walk_gallery", []):
		var a: Vector2 = span.a
		var b: Vector2 = span.b
		var delta := b - a
		if delta.length() < 0.03:
			continue
		var deck_width := float(span.width)
		var deck_size := Vector3(delta.length(), 0.22, deck_width)
		var mid := (a + b) * 0.5
		var walk_y := float(row.walk_y)
		var deck_point := Vector3(mid.x, walk_y - 0.11,
			(a.y + b.y) * 0.5)
		var yaw := atan2(-delta.y, delta.x)
		component_box("tower_access_gallery", deck_size,
			Transform3D(Basis(Vector3.UP, yaw), deck_point), SURF_TRIM)
		if bool(span.get("guarded", false)):
			var bounds: AABB = row.bounds
			var tower_center := Vector2(bounds.get_center().x, bounds.get_center().z)
			var support_h := walk_y - 0.22
			if support_h > 0.6 and not Rect2(bounds.position.x, bounds.position.z,
					bounds.size.x, bounds.size.z).grow(0.2).has_point(mid):
				var pier_size := Vector3(0.65, support_h, 0.65)
				component_box("tower_gallery_pier", pier_size,
					Transform3D(Basis.IDENTITY, Vector3(mid.x, support_h * 0.5, mid.y)),
					SURF_STONE)
			var side := Vector2(-delta.y, delta.x).normalized()
			if (mid + side - tower_center).length_squared() < \
					(mid - side - tower_center).length_squared():
				side = -side
			var rail_width := 0.16
			var rail_height := 0.62
			var rail_start := a + delta.normalized() * (0.8 if bool(span.get("open_start", false)) else 0.0)
			var rail_end := b - delta.normalized() * (0.8 if bool(span.get("open_end", false)) else 0.0)
			var rail_mid := (rail_start + rail_end) * 0.5
			var rail_length := rail_start.distance_to(rail_end)
			if rail_length < 0.1:
				continue
			var rail_xz := rail_mid + side * (deck_width * 0.5 - rail_width * 0.5)
			var rail_size := Vector3(rail_length, rail_height, rail_width)
			var rail_point := Vector3(rail_xz.x, walk_y + rail_height * 0.5, rail_xz.y)
			component_box("tower_gallery_parapet", rail_size,
				Transform3D(Basis(Vector3.UP, yaw), rail_point), SURF_STONE)
	host_end()
	_log_part("tower_access_landing", point, size)
	part_log.back()["host"] = row.id


## Residential towers have occupied-looking window tiers, not one defensive
## slit in a fifty-metre shaft. Cut the real tapered facets on the outward
## half only; the buried faces at the range joints remain closed.
func _palatial_tower_skin(c: Vector3, base_r: float, top_r: float, h: float,
		sides: int, rot: float, outward: Vector3) -> void:
	var levels := clampi(int(h / 5.0), 2, 12)
	var step := h / levels
	var win_h := minf(maxf(spec.window_h, 1.6), step * 0.48)
	var win_w := minf(maxf(spec.window_w, 0.85), top_r * sin(PI / sides) * 1.05)
	var st := _kit.surface(SURF_STONE)
	for side in range(sides):
		var a0 := rot + TAU * float(side) / sides
		var a1 := rot + TAU * float(side + 1) / sides
		var normal := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var cut := normal.dot(outward.normalized()) > 0.35
		var ranges: Array[Vector4] = []
		if cut:
			var cursor := 0.0
			for level in range(levels):
				var y := (level + 0.58) * step
				var low := y - win_h * 0.5
				var high := y + win_h * 0.5
				var radius := lerpf(base_r, top_r, y / h)
				var s0 := 0.5 - win_w / (4.0 * radius * sin(PI / sides))
				ranges.append(Vector4(0, 1, cursor, low))
				ranges.append(Vector4(0, s0, low, high))
				ranges.append(Vector4(1.0 - s0, 1, low, high))
				cursor = high
				var pos := c + normal * (radius * cos(PI / sides) + CastleGeometry.OPENING_EPS) + Vector3.UP * y
				_opening(pos, atan2(normal.x, normal.z), win_w, win_h,
					spec.window_style, false, true, maxf(spec.wall_thickness, 0.35))
			ranges.append(Vector4(0, 1, cursor, h))
		else:
			ranges.append(Vector4(0, 1, 0, h))
		for band in ranges:
			_kit._quad(st,
				_drum_point(c, base_r, top_r, h, a0, a1, band.x, band.z),
				_drum_point(c, base_r, top_r, h, a0, a1, band.y, band.z),
				_drum_point(c, base_r, top_r, h, a0, a1, band.y, band.w),
				_drum_point(c, base_r, top_r, h, a0, a1, band.x, band.w))
		var cap := c + Vector3.UP * h
		_kit._tri(st, cap + Vector3(cos(a0) * top_r, 0, sin(a0) * top_r),
			cap + Vector3(cos(a1) * top_r, 0, sin(a1) * top_r), cap)
	# Facet-following string courses articulate the storeys without moving
	# the tower envelope or placing bands across a window.
	host("palatial_tower_%s" % str(c))
	for level in range(1, levels + 1):
		var y := level * step - 0.12
		var radius := lerpf(base_r, top_r, y / h)
		for side in range(sides):
			var angle := rot + TAU * (float(side) + 0.5) / sides
			var normal := Vector3(cos(angle), 0, sin(angle))
			component_box("tower_string_course", Vector3(2.0 * radius * sin(PI / sides) + 0.08, 0.18, 0.18),
				Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.z)),
					c + normal * (radius * cos(PI / sides)) + Vector3.UP * y), SURF_TRIM)
	host_end()


## Merlons along a run, at `y`, each `thick` deep across the parapet.
func _crenellate(from_p: Vector3, to_p: Vector3, y: float, thick: float,
		surf: int) -> void:
	var seg: Vector3 = to_p - from_p
	var run: float = seg.length()
	var mw: float = CastleGeometry.merlon_width(spec)
	var pitch: float = mw + CastleGeometry.MERLON_GAP
	var n: int = int(run / pitch)
	if n <= 0:
		return
	var dir: Vector3 = seg / run
	var along_x: bool = absf(dir.x) > 0.5
	for i in range(n):
		var p: Vector3 = from_p + dir * (pitch * (float(i) + 0.5))
		var size := Vector3(mw if along_x else thick,
			spec.merlon_h, thick if along_x else mw)
		_emit_merlon(size, Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf)


## Merlons along a run that does not lie on an axis: same pitch, but each
## merlon is turned to sit square on the parapet it stands on.
func _crenellate_run(from_p: Vector3, to_p: Vector3, y: float, thick: float,
		yaw: float, surf: int) -> void:
	var seg: Vector3 = to_p - from_p
	var run: float = seg.length()
	var mw: float = CastleGeometry.merlon_width(spec)
	var pitch: float = mw + CastleGeometry.MERLON_GAP
	var n: int = int(run / pitch)
	if n <= 0:
		return
	var dir: Vector3 = seg / run
	for i in range(n):
		var p: Vector3 = from_p + dir * (pitch * (float(i) + 0.5))
		_emit_merlon(Vector3(mw, spec.merlon_h, thick),
			Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf, yaw)


## Merlons round the top of a block, on all four sides.
func _crenellate_rect(a: AABB, y: float, surf: int) -> void:
	if not spec.battlements:
		return
	var inset := 0.25
	var x0: float = a.position.x + inset
	var x1: float = a.position.x + a.size.x - inset
	var z0: float = a.position.z + inset
	var z1: float = a.position.z + a.size.z - inset
	var t: float = 0.35
	_crenellate(Vector3(x0, 0, z0), Vector3(x1, 0, z0), y, t, surf)
	_crenellate(Vector3(x0, 0, z1), Vector3(x1, 0, z1), y, t, surf)
	_crenellate(Vector3(x0, 0, z0), Vector3(x0, 0, z1), y, t, surf)
	_crenellate(Vector3(x1, 0, z0), Vector3(x1, 0, z1), y, t, surf)


## Merlons round a tower's parapet, one to each face of the shell.
func _crenellate_ring(c: Vector3, radius: float, y: float, sides: int,
		surf: int) -> void:
	var n: int = maxi(sides, 6)
	var mw: float = CastleGeometry.merlon_width(spec)
	for i in range(n):
		var ang: float = TAU * float(i) / n
		var p: Vector3 = c + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		_emit_merlon(Vector3(mw, spec.merlon_h, mw),
			Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf, -ang)


func _emit_merlon(size: Vector3, pos: Vector3, surf: int, yaw := 0.0) -> void:
	if spec.merlon_profile == &"spike":
		_log_part("spike", pos, size, yaw)
		_kit.spike(Vector2(size.x, size.z), size.y,
			pos - Vector3.UP * (size.y * 0.5), surf, yaw)
	else:
		box(size, pos, surf, yaw)


## An AABB emitted as a box, which is how nearly every castle mass is drawn.
func _box_aabb(a: AABB, surf: int) -> void:
	box(a.size, a.position + a.size / 2.0, surf)


## Curtains terminate at occupied tower rooms. The old complete wall boxes
## continued through their floors; logging rooms alone must not hide that.
func box(size: Vector3, pos: Vector3, surf: int, rot_y := 0.0, shear := 0.0) -> void:
	if _tag != "curtain" or not CastleGeometry.is_motte(spec):
		super.box(size, pos, surf, rot_y, shear)
		return
	var footprint := PackedVector2Array()
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	for corner in Poly.from_rect(Rect2(-Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))):
		var point := xf * Vector3(corner.x, 0.0, corner.y)
		footprint.append(Vector2(point.x, point.z))
	var pieces: Array[PackedVector2Array] = [footprint]
	var changed := false
	for row in _planned_interiors.values():
		if not bool(row.get("mural_tower", false)):
			continue
		var plan: HousePlan = row.plan
		var origin: Vector3 = row.transform.origin
		var hole := PackedVector2Array()
		for point in plan.outline_of(0):
			hole.append(point + Vector2(origin.x, origin.z))
		var cuts: Array[PackedVector2Array] = [hole]
		# The walkway's merlons may stand across a perfectly cut tower door.
		# Reserve the full authored arrival landing above its walking surface.
		if pos.y + size.y * 0.5 > float(row.walk_y) + 0.05:
			cuts.append(Poly.from_rect(row.walk_landing))
			for span in row.get("walk_gallery", []):
				var a: Vector2 = span.a
				var b: Vector2 = span.b
				var tangent := (b - a).normalized()
				var side := Vector2(-tangent.y, tangent.x) * float(span.width) * 0.5
				var gallery_cut := PackedVector2Array([a + side, b + side, b - side, a - side])
				cuts.append(gallery_cut)
		for cut in cuts:
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				if Poly.intersection_area(piece, cut) > 0.000001:
					changed = true
					remaining.append_array(RoofShape.subtract(piece, cut))
				else:
					remaining.append(piece)
			pieces = remaining
	if not changed:
		super.box(size, pos, surf, rot_y, shear)
		return
	for piece in pieces:
		var points := PackedVector3Array()
		for point in piece:
			points.append(Vector3(point.x, pos.y, point.y))
		component_slab("curtain_room_return", points, size.y, surf, true)


# ---------------------------------------------------------------- openings

## Dark recessed opening facing local +Z, rotated by `face` around Y.
##
## Same contract as the church's window(): `pos` is ON the wall face and the
## recess is pushed half its depth into the masonry, so the opening reads as cut
## into the stone rather than glued onto it. `facing` is logged because an AABB
## cannot tell a window from a window turned sideways -- the normals suite
## proves each one looks out of its wall.
func _opening(pos: Vector3, face: float, w: float, h: float, style: StringName,
		door := false, through := false, reveal_depth := 0.14) -> void:
	_log_part("window", pos, Vector3(w, h, 0.0), face,
		Basis(Vector3.UP, face) * Vector3(0, 0, 1))
	part_log.back()["door"] = door
	part_log.back()["through_opening"] = through
	var depth: float = 0.24 if door else 0.14
	var t := Transform3D(Basis(Vector3.UP, face), pos)
	var t_in: Transform3D = t.translated_local(Vector3(0, 0, -depth / 2.0))
	if not through:
		_kit.oriented_box(Vector3(w, h, depth), t_in, SURF_OPEN)
	var st: SurfaceTool = _kit.surface(SURF_OPEN)
	var face_n: Vector3 = t.basis * Vector3(0, 0, 1)
	if style == &"arched" and not through:
		var seg: int = 5
		var rr: float = w * 0.5
		for i in range(seg):
			var a0: float = TAU / seg * i
			var a1: float = TAU / seg * (i + 1)
			var c := Vector3(0, h / 2.0, 0)
			var p0 := Vector3(cos(a0) * rr, h / 2.0 + sin(a0) * rr * 0.6, 0)
			var p1 := Vector3(cos(a1) * rr, h / 2.0 + sin(a1) * rr * 0.6, 0)
			for p in [c, p1, p0]:
				st.set_normal(face_n)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(t * p)
	if style == &"mullioned" and not through:
		# the stone bar that divides a manor window into lights
		_kit.oriented_box(Vector3(0.12, h, depth + 0.04), t_in, SURF_TRIM)
	if door:
		return
	var ft: float = 0.12
	_kit.oriented_box(Vector3(w + ft * 2.0, ft, depth + 0.04),
		t_in.translated_local(Vector3(0, h / 2.0 + ft / 2.0, 0)), SURF_TRIM)
	_kit.oriented_box(Vector3(ft, h, depth + 0.04),
		t_in.translated_local(Vector3(-w / 2.0 - ft / 2.0, 0, 0)), SURF_TRIM)
	_kit.oriented_box(Vector3(ft, h, depth + 0.04),
		t_in.translated_local(Vector3(w / 2.0 + ft / 2.0, 0, 0)), SURF_TRIM)
	if through:
		_kit.oriented_box(Vector3(w + ft * 2.0, ft, depth + 0.04),
			t_in.translated_local(Vector3(0, -h / 2.0 - ft / 2.0, 0)), SURF_TRIM)
		var rt := minf(0.10, w * 0.15)
		var reveal := maxf(reveal_depth, 0.2)
		for side in [-1.0, 1.0]:
			_kit.oriented_box(Vector3(rt, h, reveal),
				t.translated_local(Vector3(side * w * 0.5, 0, -reveal * 0.5)), SURF_TRIM)
		for side in [-1.0, 1.0]:
			_kit.oriented_box(Vector3(w, rt, reveal),
				t.translated_local(Vector3(0, side * h * 0.5, -reveal * 0.5)), SURF_TRIM)


## Which way a named wall run faces.
static func _wall_outward(which: StringName) -> Vector3:
	match which:
		&"back":
			return Vector3(0, 0, 1)
		&"left":
			return Vector3(-1, 0, 0)
		&"right":
			return Vector3(1, 0, 0)
	return Vector3(0, 0, -1)
