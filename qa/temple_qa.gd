class_name TempleQA
extends RefCounted
## The whole temple harness in one call: does it stand up, and does it work as
## a temple.
##
## The first half is MassRules, the same three structural rules the churches
## and castles are held to, with a joint table saying which of a temple's
## masses are allowed to interpenetrate. The second half is TempleRiteCheck,
## which is where everything that makes this generator different lives.
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const FAMILIES := ["floor", "wall", "column", "dais", "altar", "idol", "cell",
	"bridge", "terrace", "stair", "pylon", "obelisk"]


## Designed interpenetration, in metres of penetration depth. INF marks a
## joint meant to pass fully through: a temple is a pile of masonry standing on
## and inside other masonry, and writing that down here is what leaves the
## check able to catch the pairs that are NOT supposed to touch -- a column
## through the altar, two columns in the same square metre.
##
## A pair absent from the table must not touch at all.
const JOINTS := {
	# things that stand on the floor, and the floor they stand on
	"altar|floor": INF, "column|floor": INF, "dais|floor": INF, "floor|idol": INF,
	"bridge|floor": INF, "cell|floor": INF, "floor|stair": INF, "floor|obelisk": INF,
	"floor|pylon": INF, "floor|wall": INF, "floor|terrace": INF, "floor|floor": INF,
	# the sanctuary group: the altar and the god stand ON the dais
	"altar|dais": INF, "dais|idol": INF,
	# a stepped mountain is terraces inside terraces, with a stair up it, and
	# the chamber inside its lowest terrace holds everything a temple holds
	"terrace|terrace": INF, "stair|terrace": INF, "stair|wall": INF,
	"column|terrace": INF, "dais|terrace": INF, "altar|terrace": INF,
	"idol|terrace": INF, "cell|terrace": INF, "bridge|terrace": INF,
	"stair|stair": 0.0,
	# an alcove is cut INTO the wall it opens off
	"cell|wall": INF, "pylon|wall": INF, "obelisk|wall": INF, "bridge|dais": INF,
	# and the pairs that must stand clear of one another
	"column|column": 0.0, "altar|column": 0.0, "column|idol": 0.0,
	"altar|idol": 0.0, "cell|cell": 0.0, "cell|column": 0.0,
	"column|dais": 0.0, "wall|wall": 0.0,
}


static func _allowance(a: String, b: String) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	return float(JOINTS.get(key, 0.0))


## `overrides` lets a family replace one of the rite's rules by name
## (RuleSet, INT-020); the report says which under "replaced".
func check(spec: TempleSpec, builder: TempleBuilder, overrides: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}
	for bad in RuleSet.unknown(overrides, [TempleRiteCheck.RULES]):
		failures.append("rules: no temple rule is called %s" % bad)

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	stats["props"] = builder.prop_log.size()
	if spec.form == &"rotunda" and not TempleGeometry.sanctum_fits(spec):
		failures.append("size_match: Rotunda altar, three-sided approach, dais, pit, and circular wall cannot all fit")
	if masses.is_empty():
		failures.append("massing: the builder logged no structural masses")
		return {"ok": false, "failures": failures, "warnings": warnings, "stats": stats}

	var rotunda_bearing_failures: Array[String] = []
	var lantern_seat_supported := false
	var pylon_lintel_supported := false
	var pylon_upper_piers_supported := false
	var pylon_spandrel_supported := false
	if spec.form == &"pylon":
		var pylon_stone: Array = MeshProbe.surface_triangles(builder, null, TempleBuilder.SURF_STONE)
		var pylon_lintel_failures: Array[String] = _pylon_lintel_bearing_failures(spec, builder, pylon_stone)
		var pylon_upper_failures: Array[String] = _pylon_upper_pier_bearing_failures(builder, pylon_stone)
		var pylon_spandrel_failures: Array[String] = _pylon_spandrel_bearing_failures(builder, pylon_stone)
		var pylon_tower_base_issues: Array[String] = _pylon_tower_base_failures(
			spec, builder, pylon_stone)
		var pylon_all_issues: Array[String] = []
		pylon_all_issues.append_array(pylon_lintel_failures)
		pylon_all_issues.append_array(pylon_upper_failures)
		pylon_all_issues.append_array(pylon_spandrel_failures)
		pylon_all_issues.append_array(pylon_tower_base_issues)
		for pylon_failure in pylon_all_issues:
			failures.append(pylon_failure)
		pylon_lintel_supported = pylon_lintel_failures.is_empty()
		pylon_upper_piers_supported = pylon_upper_failures.is_empty()
		pylon_spandrel_supported = pylon_spandrel_failures.is_empty()
	if spec.form == &"rotunda":
		var stone: Array = MeshProbe.surface_triangles(builder, null, TempleBuilder.SURF_STONE)
		var roof: Array = MeshProbe.surface_triangles(builder, null, TempleBuilder.SURF_ROOF)
		rotunda_bearing_failures = _rotunda_bearing_failures(spec, builder, stone, roof)
		lantern_seat_supported = false
		for bearing_failure in rotunda_bearing_failures:
			failures.append(bearing_failure)
	var gaps: Dictionary = _rotunda_gap_report(masses,
		spec.form == &"rotunda" and lantern_seat_supported)
	for f in gaps["failures"]:
		failures.append(str(f))
	var overlap_allowance := func(a: String, b: String) -> float:
		return _allowance(a, b)
	var over: Dictionary
	if spec.form == &"rotunda":
		over = _rotunda_non_wall_pair_overlaps(masses, overlap_allowance, builder)
	else:
		over = MassRules.overlaps(masses, overlap_allowance, FAMILIES)
	var worst_penetration: float = float(over["worst"])
	for o in over["failures"]:
		failures.append(str(o))
	if spec.form == &"rotunda":
		var wall_check: Dictionary = _rotunda_wall_pair_check(spec, builder, masses)
		for wall_failure in wall_check["failures"]:
			failures.append(str(wall_failure))
		worst_penetration = maxf(float(over["worst"]), float(wall_check["worst"]))
		for wall_failure in _rotunda_wall_continuity(spec, builder):
			failures.append(wall_failure)
	stats["worst_penetration"] = worst_penetration
	# the pit throat and the bridge deck are the only things below the floor,
	# and neither is a mass; everything else stands on the ground
	var carried: Array[String] = ["bridge"]
	if spec.form == &"pylon":
		if pylon_lintel_supported:
			carried.append("pylon_shrine_portal_lintel")
		if pylon_upper_piers_supported:
			carried.append("pylon_shrine_portal_upper_pier")
		if pylon_spandrel_supported:
			carried.append("pylon_shrine_portal_spandrel")
	if spec.form == &"rotunda":
		# The gate head is borne by the shortened jamb piers. The annular crown
		# is continuous with the outer arcade and inner colonnade; it adds no
		# detached roof mass that needs an exception in the connectivity graph.
		carried.append("wall_rotunda_gate_head")
		if spec.spire and lantern_seat_supported:
			carried.append("rotunda_lantern")
	for g in MassRules.grounded(masses, carried):
		failures.append(str(g))

	var rite: Dictionary = TempleRiteCheck.new().check(spec, builder, overrides)
	for f2 in rite["failures"]:
		failures.append(str(f2))
	for w in rite["warnings"]:
		warnings.append(str(w))
	for k in rite["stats"]:
		stats[k] = rite["stats"][k]

	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": rite.get("replaced", {})}


## A real Rotunda shell is circular, but MassRules sees each rotated tangent
## panel's large AABB. Test every emitted panel centre and both sides of every
## non-gate joint through the actual stone triangles instead of exempting wall
## geometry from validation.
static func _rotunda_wall_continuity(spec: TempleSpec, builder: TempleBuilder) -> Array[String]:
	return _rotunda_wall_continuity_triangles(spec, MeshProbe.surface_triangles(
		builder, null, TempleBuilder.SURF_STONE))


static func _rotunda_wall_continuity_triangles(spec: TempleSpec,
		triangles: Array) -> Array[String]:
	var failures: Array[String] = []
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var mid: float = (outer + inner) * 0.5
	var count: int = TempleGeometry.rotunda_wall_panel_count(spec)
	var step: float = TAU / float(count)
	var gate_half: float = TempleGeometry.rotunda_gate_panel_half_angle(spec)
	var y: float = TempleGeometry.rotunda_lower_drum_height(spec) * 0.5
	var checked := 0
	for i in range(count):
		var angle: float = -PI + (float(i) + 0.5) * step
		var rel: float = wrapf(angle + PI * 0.5 + PI, 0.0, TAU) - PI
		if absf(rel) <= gate_half:
			continue
		var ray_from := Vector3(cos(angle) * (inner - 0.08), y,
			sin(angle) * (inner - 0.08))
		var ray_to := Vector3(cos(angle) * (outer + 0.08), y,
			sin(angle) * (outer + 0.08))
		if not MeshProbe.ray_blocked(triangles, ray_from, ray_to):
			failures.append("no_overlap: rotunda drum panel has no actual wall surface at angle %.3f" % angle)
		checked += 1
	# Every seam must be covered just inside each adjacent face. Sampling on the
	# face interiors avoids relying on an engine ray's treatment of an exact edge.
	for i in range(count):
		var seam: float = -PI + float(i) * step
		var rel_seam: float = wrapf(seam + PI * 0.5 + PI, 0.0, TAU) - PI
		if absf(rel_seam) <= gate_half + step:
			continue
		for offset in [-0.01, 0.01]:
			var angle: float = seam + float(offset)
			var ray_from := Vector3(cos(angle) * (inner - 0.08), y,
				sin(angle) * (inner - 0.08))
			var ray_to := Vector3(cos(angle) * (outer + 0.08), y,
				sin(angle) * (outer + 0.08))
			if not MeshProbe.ray_blocked(triangles, ray_from, ray_to):
				failures.append("no_overlap: rotunda drum seam has a real angular gap at %.3f" % angle)
				return failures
	if checked == 0:
		failures.append("no_overlap: Rotunda has no measured wall panels outside its gate")
	return failures


## The Pylon's battered wall panels start at the top of a real ground course.
## Require the exact emitted base box and support beneath every authored face
## edge. Removing that box must remove the same upward support.
static func _pylon_tower_base_failures(spec: TempleSpec, builder: TempleBuilder,
		stone: Array) -> Array[String]:
	var failures: Array[String] = []
	var towers: Array[Rect2] = TempleGeometry.pylon_rects(spec)
	for index in range(towers.size()):
		var host_name: String = "pylon_tower_%d" % index
		var host_rows: Array[Dictionary] = builder.components_of(host_name)
		var base_rows: Array[Dictionary] = []
		var face_rows: Array[Dictionary] = []
		for row in host_rows:
			if String(row.get("role", "")) == "pylon_tower_base_course":
				base_rows.append(row)
			elif String(row.get("role", "")) == "pylon_battered_face":
				face_rows.append(row)
		if base_rows.size() != 1 or face_rows.size() != 4:
			failures.append("size_match: Pylon tower %d lacks one base course and four battered faces" % index)
			continue
		var base: Dictionary = base_rows[0]
		if not _rotunda_box_component_emitted(stone, base):
			failures.append("size_match: Pylon tower %d base-course box is absent from emitted stone" % index)
			continue
		var base_xf: Transform3D = base["xf"]
		var base_size: Vector3 = base["size"]
		var bottom: float = base_xf.origin.y - base_size.y * 0.5
		var top: float = base_xf.origin.y + base_size.y * 0.5
		var rect: Rect2 = towers[index]
		var footprint := Rect2(Vector2(base_xf.origin.x - base_size.x * 0.5,
			base_xf.origin.z - base_size.z * 0.5), Vector2(base_size.x, base_size.z))
		if absf(bottom) > 0.001 or absf(top - base_size.y) > 0.001 \
				or absf(footprint.position.x - rect.position.x) > 0.001 \
				or absf(footprint.position.y - rect.position.y) > 0.001 \
				or absf(footprint.size.x - rect.size.x) > 0.001 \
				or absf(footprint.size.y - rect.size.y) > 0.001:
			failures.append("size_match: Pylon tower %d foundation misses ground or published footprint" % index)
			continue
		var without_base: Array = _rotunda_without_box_component(stone, base)
		var checked := 0
		for face in face_rows:
			if String(face.get("form", "")) != "slab":
				failures.append("size_match: Pylon tower %d battered face is not a measured slab" % index)
				continue
			var profile: PackedVector3Array = face["points"]
			if profile.size() != 4:
				failures.append("size_match: Pylon tower %d face profile is not a quadrilateral" % index)
				continue
			var base_edge := PackedVector3Array()
			for profile_point in profile:
				if absf(profile_point.y - top) <= 0.001:
					base_edge.append(profile_point)
			if base_edge.size() != 2:
				failures.append("size_match: Pylon tower %d face does not have two vertices on the foundation top" % index)
				continue
			var expected := MeshKit.new(1)
			expected.slab_poly(profile, float(face["depth"]), 0,
				bool(face.get("vertical", true)), PackedInt32Array(face.get("open_edges", PackedInt32Array())))
			var expected_triangles: Array = MeshProbe.surface_triangles(null, expected.commit(), 0)
			if expected_triangles.is_empty() or not _pylon_slab_component_emitted(stone, face):
				failures.append("size_match: Pylon tower %d face triangles are absent from emitted stone" % index)
				continue
			var point: Vector3 = (base_edge[0] + base_edge[1]) * 0.5
			var inward := Vector2(rect.get_center().x - point.x,
				rect.get_center().y - point.z).normalized() * 0.025
			var sample := Vector2(point.x, point.z) + inward
			if not MeshProbe.has_upward_support(stone, sample, top, 0.003):
				failures.append("size_match: Pylon tower %d base course has no actual upward support below a face" % index)
				continue
			if MeshProbe.has_upward_support(without_base, sample, top, 0.003):
				failures.append("size_match: Pylon tower %d course-removal negative retained face support" % index)
				continue
			checked += 1
		if checked != 4:
			failures.append("size_match: Pylon tower %d did not prove all four foundation seats" % index)
	return failures


static func _pylon_slab_component_emitted(triangles: Array,
		row: Dictionary) -> bool:
	if String(row.get("form", "")) != "slab" \
			or int(row.get("surface", -1)) != TempleBuilder.SURF_STONE:
		return false
	var expected_kit := MeshKit.new(4)
	expected_kit.slab_poly(row["points"], float(row["depth"]),
		TempleBuilder.SURF_STONE, bool(row.get("vertical", true)),
		PackedInt32Array(row.get("open_edges", PackedInt32Array())))
	var expected: Array = MeshProbe.surface_triangles(null, expected_kit.commit(),
		TempleBuilder.SURF_STONE)
	if expected.is_empty():
		return false
	var counts := {}
	for tri in triangles:
		var key: String = ComponentCheck.triangle_key(tri[0], tri[1], tri[2])
		counts[key] = int(counts.get(key, 0)) + 1
	for tri in expected:
		var key: String = ComponentCheck.triangle_key(tri[0], tri[1], tri[2])
		var count: int = int(counts.get(key, 0))
		if count <= 0:
			return false
		counts[key] = count - 1
	return true


## The inner portal lintel is carried at its two ends by the actual screen piers.
## Require exact emitted box triangles, measured abutting end faces, and a pier
## removal control before excluding its elevated mass from grounded-mass QA.
static func _pylon_lintel_bearing_failures(spec: TempleSpec, builder: TempleBuilder,
		stone: Array) -> Array[String]:
	var failures: Array[String] = []
	var lintels: Array[Dictionary] = builder.components("pylon_shrine_portal_lintel")
	var piers: Array[Dictionary] = builder.components("pylon_shrine_portal_pier")
	if lintels.size() != 1 or piers.size() != 2:
		failures.append("size_match: Pylon shrine lintel lacks one measured member and two piers")
		return failures
	var lintel: Dictionary = lintels[0]
	if not _rotunda_box_component_emitted(stone, lintel):
		failures.append("size_match: Pylon shrine lintel is absent from emitted stone triangles")
		return failures
	# A carried member must not satisfy its own support test.
	var support_triangles: Array = _rotunda_without_box_component(stone, lintel)
	var lintel_xf: Transform3D = lintel["xf"]
	var lintel_size: Vector3 = lintel["size"]
	var lintel_left: float = lintel_xf.origin.x - lintel_size.x * 0.5
	var lintel_right: float = lintel_xf.origin.x + lintel_size.x * 0.5
	var lintel_bottom: float = lintel_xf.origin.y - lintel_size.y * 0.5
	var support_z: float = lintel_xf.origin.z
	var doorway: float = TempleGeometry.pylon_sanctum_doorway_width(spec)
	var bearing: float = clampf(spec.wall_t * 0.25, 0.18, 0.42)
	var checked_left := false
	var checked_right := false
	for pier in piers:
		if not _rotunda_box_component_emitted(stone, pier):
			failures.append("size_match: a Pylon shrine bearing pier is absent from emitted stone triangles")
			return failures
		var pier_xf: Transform3D = pier["xf"]
		var pier_size: Vector3 = pier["size"]
		var pier_left: float = pier_xf.origin.x - pier_size.x * 0.5
		var pier_right: float = pier_xf.origin.x + pier_size.x * 0.5
		var pier_top: float = pier_xf.origin.y + pier_size.y * 0.5
		var pier_front: float = pier_xf.origin.z - pier_size.z * 0.5
		var pier_back: float = pier_xf.origin.z + pier_size.z * 0.5
		var overlap: float = minf(lintel_right, pier_right) - maxf(lintel_left, pier_left)
		if absf(pier_top - lintel_bottom) > 0.01 or overlap < bearing - 0.01 \
				or pier_front > support_z - lintel_size.z * 0.5 + 0.01 \
				or pier_back < support_z + lintel_size.z * 0.5 - 0.01:
			failures.append("size_match: Pylon portal lintel lacks a measured full-depth bearing seat")
			return failures
		var side: float = -1.0 if pier_xf.origin.x < 0.0 else 1.0
		var point := Vector2(side * (doorway * 0.5 + bearing * 0.5), support_z)
		if not MeshProbe.has_upward_support(support_triangles, point, lintel_bottom, 0.03):
			failures.append("size_match: Pylon portal lintel has no actual upward pier support at x=%.3f" % point.x)
			return failures
		var without_pier: Array = _rotunda_without_box_component(support_triangles, pier)
		if MeshProbe.has_upward_support(without_pier, point, lintel_bottom, 0.03):
			failures.append("size_match: Pylon pier-removal negative retained the same lintel support point")
			return failures
		if side < 0.0:
			checked_left = true
		else:
			checked_right = true
	if not checked_left or not checked_right:
		failures.append("size_match: Pylon portal lintel is not borne at both ends")
	return failures

## Upper side masonry rests on the measured lower piers; the transom rests on
## the lintel. Remove each member itself before sampling its support surface.
static func _pylon_upper_pier_bearing_failures(builder: TempleBuilder,
		stone: Array) -> Array[String]:
	var failures: Array[String] = []
	var lower: Array[Dictionary] = builder.components("pylon_shrine_portal_pier")
	var upper: Array[Dictionary] = builder.components("pylon_shrine_portal_upper_pier")
	if lower.size() != 2 or upper.size() != 2:
		failures.append("size_match: Pylon upper screen lacks two measured pier courses")
		return failures
	for upper_row in upper:
		if not _rotunda_box_component_emitted(stone, upper_row):
			failures.append("size_match: Pylon upper-pier triangles are absent")
			return failures
		var upper_xf: Transform3D = upper_row["xf"]
		var upper_size: Vector3 = upper_row["size"]
		var support_y: float = upper_xf.origin.y - upper_size.y * 0.5
		var lower_row: Dictionary = {}
		for candidate in lower:
			var lower_xf: Transform3D = candidate["xf"]
			if upper_xf.origin.x * lower_xf.origin.x > 0.0:
				lower_row = candidate
				break
		if lower_row.is_empty() or not _rotunda_box_component_emitted(stone, lower_row):
			failures.append("size_match: Pylon upper-pier course has no matching emitted lower pier")
			return failures
		var lower_xf: Transform3D = lower_row["xf"]
		var lower_size: Vector3 = lower_row["size"]
		var lower_top: float = lower_xf.origin.y + lower_size.y * 0.5
		var upper_left: float = upper_xf.origin.x - upper_size.x * 0.5
		var upper_right: float = upper_xf.origin.x + upper_size.x * 0.5
		var lower_left: float = lower_xf.origin.x - lower_size.x * 0.5
		var lower_right: float = lower_xf.origin.x + lower_size.x * 0.5
		if absf(support_y - lower_top) > 0.01 \
				or minf(upper_right, lower_right) - maxf(upper_left, lower_left) <= 0.1:
			failures.append("size_match: Pylon upper pier does not bear on the lower course")
			return failures
		var support_triangles: Array = _rotunda_without_box_component(stone, upper_row)
		var point := Vector2(upper_xf.origin.x, upper_xf.origin.z)
		if not MeshProbe.has_upward_support(support_triangles, point, support_y, 0.03):
			failures.append("size_match: Pylon upper-pier base has no actual lower-course support")
			return failures
		var without_lower: Array = _rotunda_without_box_component(support_triangles, lower_row)
		if MeshProbe.has_upward_support(without_lower, point, support_y, 0.03):
			failures.append("size_match: Pylon lower-pier removal retained the same upper-course support")
			return failures
	return failures


static func _pylon_spandrel_bearing_failures(builder: TempleBuilder,
		stone: Array) -> Array[String]:
	var failures: Array[String] = []
	var spandrels: Array[Dictionary] = builder.components("pylon_shrine_portal_spandrel")
	var lintels: Array[Dictionary] = builder.components("pylon_shrine_portal_lintel")
	if spandrels.size() != 1 or lintels.size() != 1:
		failures.append("size_match: Pylon transom lacks a unique measured lintel seat")
		return failures
	var spandrel: Dictionary = spandrels[0]
	var lintel: Dictionary = lintels[0]
	if not _rotunda_box_component_emitted(stone, spandrel) \
			or not _rotunda_box_component_emitted(stone, lintel):
		failures.append("size_match: Pylon transom or lintel is absent from emitted stone triangles")
		return failures
	var spandrel_xf: Transform3D = spandrel["xf"]
	var spandrel_size: Vector3 = spandrel["size"]
	var lintel_xf: Transform3D = lintel["xf"]
	var lintel_size: Vector3 = lintel["size"]
	var spandrel_bottom: float = spandrel_xf.origin.y - spandrel_size.y * 0.5
	var lintel_top: float = lintel_xf.origin.y + lintel_size.y * 0.5
	if absf(spandrel_bottom - lintel_top) > 0.01 \
			or lintel_size.x < spandrel_size.x - 0.01 \
			or absf(lintel_xf.origin.z - spandrel_xf.origin.z) > 0.01:
		failures.append("size_match: Pylon transom does not sit on the full-width lintel top")
		return failures
	var support_triangles: Array = _rotunda_without_box_component(stone, spandrel)
	var point := Vector2(spandrel_xf.origin.x, spandrel_xf.origin.z)
	if not MeshProbe.has_upward_support(support_triangles, point, spandrel_bottom, 0.03):
		failures.append("size_match: Pylon transom has no actual upward lintel support")
		return failures
	var without_lintel: Array = _rotunda_without_box_component(support_triangles, lintel)
	if MeshProbe.has_upward_support(without_lintel, point, spandrel_bottom, 0.03):
		failures.append("size_match: Pylon lintel-removal negative retained the same transom support")
	return failures

## Keep the lantern out of the mass-connectivity graph only when its exact
## emitted seat predicate passed in the same QA run.
static func _rotunda_gap_report(masses: Array[Dictionary],
		lantern_seat_supported: bool) -> Dictionary:
	var free: Array[String] = []
	if lantern_seat_supported:
		free.append("rotunda_lantern")
	return MassRules.gaps(masses, "floor", free)


static func _rotunda_lantern_seat_supported(spec: TempleSpec, roof: Array) -> bool:
	if not spec.spire:
		return false
	var radius: float = TempleGeometry.rotunda_lantern_radius(spec)
	var seat_y: float = TempleGeometry.roof_height(spec)
	for ring in [0.0, 0.48, 0.92]:
		for sample in range(TempleGeometry.DOME_SEGMENTS):
			var angle: float = TAU * float(sample) / float(TempleGeometry.DOME_SEGMENTS)
			var point: Vector2 = Vector2(cos(angle), sin(angle)) * radius * float(ring)
			if not MeshProbe.has_upward_support(roof, point, seat_y, 0.03):
				return false
	return true


## Runtime bearing exceptions require actual emitted support triangles.
## Remove a member's own emitted box triangles before measuring its contacts,
## so a floating component cannot support itself.
static func _rotunda_bearing_failures(spec: TempleSpec, builder: TempleBuilder,
		stone: Array, roof: Array) -> Array[String]:
	return _rotunda_bearing_failures_for_components(spec,
		builder.components("rotunda_gate_head"),
		builder.components("rotunda_gate_return"), stone, roof)


static func _rotunda_bearing_failures_for_components(spec: TempleSpec,
		head_rows: Array[Dictionary], return_rows: Array[Dictionary],
		stone: Array, roof: Array) -> Array[String]:
	var failures: Array[String] = []
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var jamb: float = spec.wall_t * 0.35
	var gate_height: float = minf(TempleGeometry.GATE_H, spec.height - 0.6)
	if head_rows.size() != 1:
		failures.append("size_match: Rotunda gate head has no unique measured bearing member")
	elif return_rows.size() != 2:
		failures.append("size_match: Rotunda gate head lacks both jamb return bearings")
	else:
		if not _rotunda_box_component_emitted(stone, head_rows[0]):
			failures.append("size_match: Rotunda gate-head component is absent from emitted stone triangles")
		for return_row in return_rows:
			if not _rotunda_box_component_emitted(stone, return_row):
				failures.append("size_match: a Rotunda jamb return component is absent from emitted stone triangles")
		if _rotunda_box_component_emitted(stone, head_rows[0]):
			var without_head: Array = _rotunda_without_box_component(stone, head_rows[0])
			var gate_z: float = -outer + spec.wall_t * 0.5
			for side in [-1.0, 1.0]:
				var x: float = side * (TempleGeometry.GATE_W * 0.5 + jamb * 0.5)
				if not MeshProbe.has_upward_support(without_head,
						Vector2(x, gate_z), gate_height, 0.03):
					failures.append("size_match: Rotunda gate-head end at x=%.3f has no actual upward jamb bearing" % x)
	return failures


static func _rotunda_without_box_component(triangles: Array,
		row: Dictionary) -> Array:
	if String(row.get("form", "")) != "box":
		return []
	var own: Array = _rotunda_box_component_triangles(row)
	var remaining_counts := {}
	for tri in own:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var key: String = ComponentCheck.triangle_key(a, b, c)
		remaining_counts[key] = int(remaining_counts.get(key, 0)) + 1
	var out: Array = []
	for tri in triangles:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var key: String = ComponentCheck.triangle_key(a, b, c)
		var count: int = int(remaining_counts.get(key, 0))
		if count > 0:
			remaining_counts[key] = count - 1
		else:
			out.append(tri)
	return out


static func _rotunda_box_component_emitted(triangles: Array,
		row: Dictionary) -> bool:
	if String(row.get("form", "")) != "box":
		return false
	var expected: Array = _rotunda_box_component_triangles(row)
	if expected.is_empty():
		return false
	var have_counts := {}
	for tri in triangles:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var key: String = ComponentCheck.triangle_key(a, b, c)
		have_counts[key] = int(have_counts.get(key, 0)) + 1
	for tri in expected:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var key: String = ComponentCheck.triangle_key(a, b, c)
		var count: int = int(have_counts.get(key, 0))
		if count == 0:
			return false
		have_counts[key] = count - 1
	return true


static func _rotunda_box_component_triangles(row: Dictionary) -> Array:
	if String(row.get("form", "")) != "box":
		return []
	var isolated := MassBuilder.new()
	isolated.begin(1)
	var role: String = String(row["role"])
	var size: Vector3 = row["size"]
	var xf: Transform3D = row["xf"]
	isolated.component_box(role, size, xf, 0)
	return MeshProbe.surface_triangles(isolated, null, 0)


## Preserve MassRules' exact family and negative-mass behavior for every pair
## except pairs where BOTH names identify rotated Rotunda wall panels. Those
## pairs are checked by the component OBB test below; no error text is parsed.
static func _rotunda_non_wall_pair_overlaps(masses: Array[Dictionary],
		allow: Callable, builder: TempleBuilder) -> Dictionary:
	var failures: Array[String] = []
	var worst := 0.0
	var wall_components: Dictionary = _rotunda_wall_components(builder)
	var dais_steps: Array[Dictionary] = builder.components("rotunda_dais_step")
	for i in range(masses.size()):
		for j in range(i + 1, masses.size()):
			var a: Dictionary = masses[i]
			var b: Dictionary = masses[j]
			var an: String = String(a["name"])
			var bn: String = String(b["name"])
			if an.begins_with("wall_rotunda_") and bn.begins_with("wall_rotunda_"):
				continue
			var wall_name := ""
			var other_name := ""
			if an.begins_with("wall_rotunda_"):
				wall_name = an
				other_name = bn
			elif bn.begins_with("wall_rotunda_"):
				wall_name = bn
				other_name = an
			if not wall_name.is_empty() and MassRules.family(other_name, FAMILIES) == "dais":
				if not wall_components.has(wall_name) or dais_steps.is_empty():
					failures.append("no_overlap: Rotunda wall/dais AABB pair has no actual hosted geometry for exact contact measurement")
					worst = maxf(worst, MassRules.penetration(a["aabb"], b["aabb"]))
					continue
				for dais_row in dais_steps:
					var penetration: float = _rotunda_box_overlap_depth(
						wall_components[wall_name], dais_row)
					worst = maxf(worst, penetration)
					if penetration > MassRules.TOL:
						failures.append("no_overlap: %s and emitted %s interpenetrate %.2fm" % [
							wall_name, String(dais_row.get("id", dais_row.get("role", "dais step"))),
							penetration])
				continue
			var pair: Array[Dictionary] = [a, b]
			var pair_report: Dictionary = MassRules.overlaps(pair, allow, FAMILIES)
			worst = maxf(worst, float(pair_report["worst"]))
			for issue in pair_report["failures"]:
				failures.append(str(issue))
	return {"failures": failures, "worst": snappedf(worst, 0.01)}


## MassRules still checks every non-wall pair and every wall/non-wall pair with
## its original AABB rule. For the Rotunda's tangent boxes only, measure the
## actual 3-D oriented component boxes and allow only the analytically derived
## panel lap or the designed jamb bearing.
static func _rotunda_wall_pair_check(spec: TempleSpec, builder: TempleBuilder,
		masses: Array[Dictionary]) -> Dictionary:
	var failures: Array[String] = []
	var component_by_mass := _rotunda_wall_components(builder)
	var walls: Array[Dictionary] = []
	for mass in masses:
		if String(mass["name"]).begins_with("wall_rotunda_"):
			walls.append(mass)
	var worst := 0.0
	for i in range(walls.size()):
		var a_mass: Dictionary = walls[i]
		var a_name: String = String(a_mass["name"])
		if not component_by_mass.has(a_name):
			failures.append("no_overlap: %s has no exact oriented component for its logged wall mass" % a_name)
			continue
		var a: Dictionary = component_by_mass[a_name]
		for j in range(i + 1, walls.size()):
			var b_mass: Dictionary = walls[j]
			var b_name: String = String(b_mass["name"])
			if not component_by_mass.has(b_name):
				failures.append("no_overlap: %s has no exact oriented component for its logged wall mass" % b_name)
				continue
			var b: Dictionary = component_by_mass[b_name]
			var penetration: float = _rotunda_box_overlap_depth(a, b)
			worst = maxf(worst, penetration)
			var allowed: float = _rotunda_wall_pair_allowance(spec, a, b)
			if penetration > allowed + MassRules.TOL:
				failures.append("no_overlap: %s and %s interpenetrate %.2fm; actual component lap allows %.2fm" % [
					a_name, b_name, penetration, allowed])
	return {"failures": failures, "worst": snappedf(worst, 0.01)}


static func _rotunda_wall_components(builder: TempleBuilder) -> Dictionary:
	var out := {}
	for row in builder.components("rotunda_drum_panel"):
		var index_text: String = String(row.get("host", "")).get_slice("_", 3)
		if index_text.is_valid_int():
			out["wall_rotunda_%02d" % int(index_text)] = row
	for row in builder.components("rotunda_gate_return"):
		var side: String = "left" if String(row.get("host", "")).ends_with("left") else "right"
		out["wall_rotunda_gate_return_%s" % side] = row
	for row in builder.components("rotunda_gate_head"):
		out["wall_rotunda_gate_head"] = row
	return out


static func _rotunda_wall_pair_allowance(spec: TempleSpec,
		a: Dictionary, b: Dictionary) -> float:
	var a_role: String = String(a.get("role", ""))
	var b_role: String = String(b.get("role", ""))
	if a_role == "rotunda_drum_panel" and b_role == "rotunda_drum_panel":
		var axf: Transform3D = a["xf"]
		var bxf: Transform3D = b["xf"]
		var aa: float = atan2(axf.origin.z, axf.origin.x)
		var ba: float = atan2(bxf.origin.z, bxf.origin.x)
		var delta: float = absf(wrapf(aa - ba + PI, 0.0, TAU) - PI)
		var step: float = TAU / float(TempleGeometry.rotunda_wall_panel_count(spec))
		if delta > step + 0.001:
			return 0.0
		var outer: float = TempleGeometry.rotunda_outer_radius(spec)
		var thickness: float = spec.wall_t
		var middle: float = outer - thickness * 0.5
		var expected_panel_width: float = 2.0 * middle * tan(step * 0.5) + 0.025
		# Tangent panels intentionally lap by the excess of their chord over the
		# centre spacing, plus the radial thickness projected onto that axis.
		return maxf(expected_panel_width + (thickness * 0.5 - middle) * sin(step), 0.0) + 0.015
	var a_gate_member: bool = a_role in ["rotunda_gate_head", "rotunda_gate_return"]
	var b_gate_member: bool = b_role in ["rotunda_gate_head", "rotunda_gate_return"]
	if a_gate_member and b_gate_member or \
			(a_gate_member and b_role == "rotunda_drum_panel") or \
			(b_gate_member and a_role == "rotunda_drum_panel"):
		return spec.wall_t * 0.35 + 0.02
	return 0.0


## Separating-axis test for the exact oriented component boxes. The result is
## the shallowest physical penetration in metres, or zero when disjoint.
static func _rotunda_box_overlap_depth(a: Dictionary, b: Dictionary) -> float:
	return TempleGeometry.obb_overlap_depth(a, b)
