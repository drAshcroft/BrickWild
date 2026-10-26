extends RefCounted
## Bounded church geometry gate. The exhaustive style, seed and landmark
## sweeps remain in the named church suites and lane:church.

const Apertures = preload("res://tests/suites/church_aperture_suite.gd")
const Roofs = preload("res://src/church/church_roofs.gd")
const RoofSuite = preload("res://tests/suites/church_roof_suite.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("church change")
	# The roof clipper is bounded for assembled domes, so the change lane
	# checks them alongside the simpler roof and tower forms.
	for style in [&"romanesque", &"gothic", &"nordic_stave",
			&"byzantine", &"renaissance", &"russian"]:
		for index in [3, 8]:
			var started := Time.get_ticks_msec()
			var spec: ChurchSpec = TestSweep.spec_at(style, index)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s seed=%d" % [String(style), TestSweep.seed_at(index)]
			_check_material_surfaces(res, mesh, style, who)
			if mesh != null:
				NormalsSuite.check_mesh(res, mesh, who)
				NormalsSuite.check_openings(res, builder, who)
			_check_massing(res, spec, builder, who)
			if style == &"byzantine" and index == 3:
				_expect(res, (mesh.surface_get_arrays(ChurchBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
					as PackedVector3Array).size() < 12000,
					"Byzantine roof clipping fragment count regressed")
				_dome_cut_control(res, spec, builder)
			var elapsed := (Time.get_ticks_msec() - started) / 1000.0
			res.note("%s %.2fs" % [who, elapsed])

	for key in ["notre_dame", "durham", "hagia_sophia", "florence_duomo", "st_basil"]:
		var started := Time.get_ticks_msec()
		var row := _landmark_row(key)
		var spec := ChurchSpec.new()
		spec.style = row["style"]
		spec.width = row["width"]
		spec.length = row["length"]
		spec.height = row["height"]
		ChurchGenerator.generate(spec, LandmarkSuite._seed_for(key, 1.0))
		LandmarkSuite._force_features(key, spec)
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		LandmarkSuite._check_required_masses(key, builder, key, res)
		LandmarkSuite._check_clerestory(spec, builder, key, res)
		if spec.hero != &"":
			# the hero emitters (octagon, tribunes, bearing, arches, tent, onions)
			# face outward and their openings look out of their walls
			NormalsSuite.check_mesh(res, mesh, "%s hero" % key)
			NormalsSuite.check_openings(res, builder, "%s hero" % key)
		_check_massing(res, spec, builder, key)
		if key == "hagia_sophia":
			_expect(res, (mesh.surface_get_arrays(ChurchBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
				as PackedVector3Array).size() < 12000,
				"Hagia Sophia roof clipping fragment count regressed")
		if key == "notre_dame":
			var clerestory := ChurchGeometry.clerestory_windows(spec)
			_expect(res, not clerestory.is_empty(), "Notre-Dame lacks clerestory fixture")
			if not clerestory.is_empty():
				var opening: Dictionary = clerestory[0]
				Apertures._check_opening(res, mesh, builder, opening.pos,
					opening.face, opening.width, opening.height, "Notre-Dame clerestory")
		var elapsed := (Time.get_ticks_msec() - started) / 1000.0
		res.note("%s %.2fs" % [key, elapsed])

	_gothic_bell_stage(res)

	var route_start := Time.get_ticks_msec()
	Apertures._entrance_routes(res)
	var route_elapsed := (Time.get_ticks_msec() - route_start) / 1000.0
	res.note("entrance routes %.2fs" % route_elapsed)
	_negative_controls(res)
	_nave_intrusion(res)
	_tower_crowns(res)
	_romanesque_large_front(res)
	_byzantine_large_dome(res)
	return res


const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"


## Roof or accent surface standing INSIDE the nave's clear interior, below the
## eaves, is a roof that holds nothing: the Russian alcove caps were stepped
## boxes laid toward +Z whatever the alcove faced, and hung over the nave as
## terracotta blocks on the walls (SACRED-RUSSIAN-FLOATING-BLOCKS).
## Returns the offending vertices, as world points.
static func nave_roof_intruders(spec: ChurchSpec, mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for surface in [ChurchBuilder.SURF_ROOF, ChurchBuilder.SURF_ACCENT]:
		if surface >= mesh.get_surface_count():
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for p in vertices:
			if p.y > 0.2 and p.y < spec.height - 0.5 and ChurchGeometry.inside_nave(spec, p):
				out.append(p)
	return out


static func _nave_intrusion(res: SuiteResult) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MATRIX))
	var built_one := false
	for c in parsed["cases"]:
		if c["family"] != "church" or c["style"] not in ["russian", "romanesque"]:
			continue
		var made := BrickWild.generate(BuildingRequest.from_dict(c["request"]))
		var spec := made.spec as ChurchSpec
		var mesh: ArrayMesh = ChurchBuilder.new().build(spec)
		var bad := nave_roof_intruders(spec, mesh)
		_expect(res, bad.is_empty(), "%s: %d roof vertices hang inside the nave, first at %s"
			% [c["id"], bad.size(), str(bad[0]) if not bad.is_empty() else ""])
		if c["id"] == "church/russian/default/1":
			built_one = true
			# negative control: the old stepped cap, laid toward +Z on the wall line
			var kit := MeshKit.new(5)
			for surface in range(5):
				kit.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
			kit.box(Vector3(2.2, 0.6, 1.1), Vector3(-spec.width / 2.0 + 0.2, 5.3, 0.0),
				ChurchBuilder.SURF_ROOF)
			_expect(res, not nave_roof_intruders(spec, kit.commit()).is_empty(),
				"floating-roof control was not detected")
	_expect(res, built_one, "matrix has no church/russian/default/1 case")


## A west tower ends in a crown: Romanesque a hipped cap, Russian an onion or
## tent on a drum, never a bare deck. The roof (or gilded accent) must reach
## the logged tower_roof_rise, and nothing may exceed it.
static func _tower_crowns(res: SuiteResult) -> void:
	var crowns := 0
	for style in [&"romanesque", &"russian"]:
		for index in [0, 1, 2, 3, 4, 5]:
			var spec: ChurchSpec = TestSweep.spec_at(style, index)
			if (not spec.tower or spec.tower_roof == &"flat" or spec.west_towers != 1
					or spec.crossing_tower_height > 0.0):
				continue
			crowns += 1
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s #%d crown" % [String(style), index]
			var rise: float = ChurchGeometry.tower_roof_rise(spec)
			var top := 0.0
			for surface in [ChurchBuilder.SURF_ROOF, ChurchBuilder.SURF_ACCENT, ChurchBuilder.SURF_TRIM]:
				if surface >= mesh.get_surface_count():
					continue
				var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for p in vertices:
					if (absf(p.x - ChurchGeometry.tower_center_x(spec, 0.0)) < spec.tower_width * 0.5 + 0.6
							and absf(p.z - ChurchGeometry.tower_center_z(spec)) < spec.tower_width * 0.5 + 0.6):
						top = maxf(top, p.y)
			var crown_top: float = spec.tower_height + rise
			_expect(res, top > crown_top - 0.5 and top < crown_top + 0.05,
				"%s tops out at %.2f, expected about %.2f (tower %.2f + rise %.2f)"
				% [who, top, crown_top, spec.tower_height, rise])
	_expect(res, crowns > 0, "no single-tower Romanesque or Russian case reached the crown check")


## Public single/twin tower builds prove paired Gothic belfry apertures on the
## three exterior faces. The attached east face remains solid at this height.
## A ray through each exposed center pier is the negative aperture probe.
static func _gothic_bell_stage(res: SuiteResult) -> void:
	for tower_count in [1, 2]:
		var spec := ChurchSpec.new()
		spec.style = &"gothic"
		ChurchGenerator.generate(spec, 7120 + tower_count)
		spec.width = 16.0
		spec.length = 82.0
		spec.height = 30.0
		spec.aisles = 1
		spec.tower = true
		spec.west_towers = tower_count
		spec.tower_width = 6.0
		spec.tower_height = 38.0
		spec.tower_roof = &"spire"
		spec.spire_pitch = 0.9
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var upper_plan_count := 0
		for side in ChurchGeometry.west_tower_sides(spec):
			var cx: float = ChurchGeometry.tower_center_x(spec, side)
			var cz: float = ChurchGeometry.tower_center_z(spec)
			var openings := builder._tower_openings(cx, cz,
				spec.tower_width, spec.tower_height)
			for opening in openings:
				if float(opening.get("y", 0.0)) <= spec.tower_height * 0.5:
					continue
				upper_plan_count += 1
				_expect(res, int(opening.face) != 0
					and opening.get("style") == &"pointed"
					and opening.get("arch") == &"gothic",
					"Gothic tower %d face %d has a non-pointed bell light"
					% [tower_count, int(opening.face)])
		_expect(res, upper_plan_count == tower_count * 6,
			"Gothic %d-tower build has %d upper plans, expected pairs on three exposed faces"
				% [tower_count, upper_plan_count])
		var upper_parts: Array[Dictionary] = []
		for part in builder.part_log:
			if part.get("kind") == "window" and part.get("tag") == "tower" \
					and float(part.pos.y) > spec.tower_height * 0.5:
				upper_parts.append(part)
		_expect(res, upper_parts.size() == tower_count * 6,
			"Gothic %d-tower public build logged %d upper lights, expected %d"
			% [tower_count, upper_parts.size(), tower_count * 6])
		for side in ChurchGeometry.west_tower_sides(spec):
			var cx: float = ChurchGeometry.tower_center_x(spec, side)
			var cz: float = ChurchGeometry.tower_center_z(spec)
			for face in range(4):
				var face_parts: Array[Dictionary] = []
				for part in upper_parts:
					var logged_face: int = posmod(roundi(float(part.rot_y) / (PI * 0.5)), 4)
					var on_tower: bool = absf(float(part.pos.x) - cx) < spec.tower_width * 0.5 + 0.2 \
						and absf(float(part.pos.z) - cz) < spec.tower_width * 0.5 + 0.2
					if logged_face == face and on_tower:
						face_parts.append(part)
				var expected_count: int = 0 if face == 0 else 2
				_expect(res, face_parts.size() == expected_count,
					"Gothic %d-tower face %d has %d emitted bell lights; expected %d"
					% [tower_count, face, face_parts.size(), expected_count])
				if face == 0 or face_parts.size() != 2:
					continue
				var u0: float = float(face_parts[0].pos.z if face % 2 == 1 else face_parts[0].pos.x)
				var u1: float = float(face_parts[1].pos.z if face % 2 == 1 else face_parts[1].pos.x)
				var expected_center: float = cz if face % 2 == 1 else cx
				_expect(res, absf((u0 + u1) * 0.5 - expected_center) < 0.01
					and absf(absf(u1 - u0) - spec.tower_width * 0.18) < 0.01,
					"Gothic %d-tower face %d lights are not mirrored around a measured pier"
					% [tower_count, face])
				var outward := Basis(Vector3.UP, face * PI * 0.5) * Vector3.BACK
				var face_mid := Vector3(cx, spec.tower_height - spec.tower_width * 0.28, cz)
				var pier_start: Vector3 = face_mid + outward * (spec.tower_width * 0.5 + 0.3)
				var pier_end: Vector3 = pier_start - outward * 0.5
				_expect(res, Apertures._blocked(mesh, pier_start, pier_end),
					"Gothic %d-tower face %d center pier ray passed through instead of hitting stone"
					% [tower_count, face])
				for part in face_parts:
					Apertures._check_opening(res, mesh, builder, part.pos,
						part.rot_y, part.size.x, part.size.y,
						"Gothic %d-tower face %d bell light" % [tower_count, face], 0.45)

	# The style branch is deliberately narrow. Romanesque keeps one square
	# opening per tower face, including its prior clear width.
	var roman := ChurchSpec.new()
	roman.style = &"romanesque"
	roman.tower_width = 6.0
	roman.tower_height = 38.0
	var roman_builder := ChurchBuilder.new()
	roman_builder.spec = roman
	var roman_openings := roman_builder._tower_openings(0.0, -10.0, 6.0, 38.0)
	_expect(res, roman_openings.size() == 4,
		"Romanesque tower opening count changed")
	for opening in roman_openings:
		_expect(res, opening.get("style") == &"square"
			and is_equal_approx(float(opening.width), 6.0 * 0.32),
			"Romanesque tower opening recipe changed")


static func _check_material_surfaces(res: SuiteResult, mesh: ArrayMesh,
		style: StringName, who: String) -> void:
	_expect(res, mesh != null, "%s emitted no mesh" % who)
	if mesh == null:
		return
	var slots: Dictionary = {}
	for surface in range(mesh.get_surface_count()):
		var slot := surface
		var surface_name: String = mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		_expect(res, not slots.has(slot) and not vertices.is_empty(),
			"%s has a duplicate or empty material slot %d" % [who, slot])
		slots[slot] = true
	for slot in [ChurchBuilder.SURF_STONE, ChurchBuilder.SURF_TRIM,
			ChurchBuilder.SURF_ROOF, ChurchBuilder.SURF_OPEN]:
		_expect(res, slots.has(slot), "%s lacks required material slot %d" % [who, slot])
	if style == &"nordic_stave":
		_expect(res, slots.has(ChurchBuilder.SURF_WOOD), "%s lacks native timber geometry" % who)
	_expect(res, mesh.get_surface_count() <= BuildingLibrary.surface_count(&"church"),
		"%s exceeds the published material surface count" % who)


static func _dome_cut_control(res: SuiteResult, spec: ChurchSpec,
		builder: ChurchBuilder) -> void:
	var cut := MeshKit.new(4)
	var uncut := MeshKit.new(4)
	for surface in range(4):
		# SurfaceTool omits empty surfaces; place these fixtures far from the
		# sample to retain the church surface indexes.
		cut.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
		uncut.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
	Roofs.emit(spec, cut, builder.mass_log, builder._roof_volumes)
	Roofs.emit(spec, uncut, builder.mass_log, [])
	var x := -0.625 * spec.dome_radius * 1.5
	var z := ChurchGeometry.crossing_center_z(spec)
	var cut_roof := RoofSuite._triangles(cut.commit(), ChurchBuilder.SURF_ROOF)
	var uncut_roof := RoofSuite._triangles(uncut.commit(), ChurchBuilder.SURF_ROOF)
	var cut_hits := RoofSuite._heights(cut_roof, x, z, 0, 100)
	var uncut_hits := RoofSuite._heights(uncut_roof, x, z, 0, 100)
	_expect(res, cut_hits.is_empty(), "Byzantine half-dome has roof inside shell")
	_expect(res, uncut_hits.size() == 2,
		"missing-volume negative control did not expose the roof inside half-dome")


static func _landmark_row(key: String) -> Dictionary:
	for row in LandmarkSuite.LANDMARKS:
		if row["key"] == key:
			return row
	return {}


static func _check_massing(res: SuiteResult, spec: ChurchSpec,
		builder: ChurchBuilder, who: String) -> void:
	var report: Dictionary = MassingCheck.new().check(spec, builder)
	_expect(res, report["ok"], "%s massing: %s" % [who, report["failures"]])
	for warning in report["warnings"]:
		res.warn("%s massing: %s" % [who, warning])


static func _negative_controls(res: SuiteResult) -> void:
	var solid := MeshKit.new(1)
	solid.box(Vector3(4.0, 4.0, 0.5), Vector3(0, 2, 0), 0)
	var solid_mesh := solid.commit()
	_expect(res, Apertures._blocked(solid_mesh, Vector3(0, 2, -1),
		Vector3(0, 2, 1)), "solid-wall aperture control was not detected")
	var arrays: Array = solid_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(normals.size()):
		normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var inverted := ArrayMesh.new()
	inverted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var normal_control := SuiteResult.new("inverted normal control")
	NormalsSuite.check_mesh(normal_control, inverted, "inverted box")
	_expect(res, not normal_control.ok(), "inverted-normal control was not detected")

	var spec: ChurchSpec = TestSweep.spec_at(&"romanesque", 3)
	var builder := ChurchBuilder.new()
	builder.build(spec)
	builder.mass_log.clear()
	var report: Dictionary = MassingCheck.new().check(spec, builder)
	_expect(res, not report["ok"], "missing-mass control was not detected")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


## SACRED-ROMANESQUE-LARGE: the frozen large Romanesque (16 x 48 x 24, seed
## 21325) was a plain gabled box from the front. It must hold a west tower or
## an apse in its mass_log, and that mass must be unoccluded from the front
## three-quarter camera of tools/render_sacred_exterior.gd (yaw -0.55). The
## test casts rays from that camera to a grid on the mass's two visible faces
## against every OTHER logged mass. A control puts a wall in front of it.
static func _romanesque_large_front(res: SuiteResult) -> void:
	for seed_v in [21325, 1, 8102, 9, 77]:
		var spec := ChurchSpec.new()
		spec.style = &"romanesque"
		spec.width = 16.0
		spec.length = 48.0
		spec.height = 24.0
		ChurchGenerator.generate(spec, seed_v)
		var builder := ChurchBuilder.new()
		builder.build(spec)
		var who := "Romanesque large seed=%d" % seed_v
		var frac := _front_visible_fraction(builder.mass_log, "tower")
		_expect(res, frac >= 0.6,
			"%s: west tower visible from the front 3/4 on %.0f%% of its faces" % [who, frac * 100.0])
		if seed_v == 21325:
			_expect(res, spec.tower and spec.west_towers == 1 and spec.width == 16.0
					and spec.length == 48.0 and spec.height == 24.0,
				"%s: tower present and the pinned dimensions unchanged" % who)
			var walled: Array = builder.mass_log.duplicate()
			var tw: AABB = _mass_aabb(builder.mass_log, "tower")
			walled.append({"name": "control_wall", "aabb": AABB(
				Vector3(tw.position.x - 30.0, 0.0, tw.position.z - 8.0),
				Vector3(60.0, 80.0, 1.0))})
			_expect(res, _front_visible_fraction(walled, "tower") < 0.05,
				"%s: occlusion control (a wall in front) must hide the tower" % who)


## SACRED-BYZANTINE-DOME: a large Byzantine church's dome crown must be in a
## clear sight line from the exterior entry eye (1.6 m, on the axis, at the
## door approach). Occluders are every logged mass except the dome's own
## pendentive and drum, plus the nave roof up to its ridge. Controls: a raised
## west gable, and the dome back over the east crossing, must both fail.
static func _byzantine_large_dome(res: SuiteResult) -> void:
	for seed_v in [21325, 1, 8102, 9, 77]:
		var spec := ChurchSpec.new()
		spec.style = &"byzantine"
		spec.width = 16.0
		spec.length = 48.0
		spec.height = 24.0
		ChurchGenerator.generate(spec, seed_v)
		var who := "Byzantine large seed=%d" % seed_v
		if not spec.dome:
			_expect(res, false, "%s: no dome" % who)
			continue
		var builder := ChurchBuilder.new()
		builder.build(spec)
		var crown := Vector3(0.0, ChurchGeometry.dome_crown_height(spec),
			ChurchGeometry.crossing_center_z(spec))
		var eye: Vector3 = ChurchGeometry.entry_eye(spec)
		var occluders := _dome_occluders(spec, builder.mass_log)
		_expect(res, not _any_hit(eye, crown, occluders),
			"%s: dome crown unobstructed from the entry eye" % who)
		if seed_v == 21325:
			_expect(res, spec.width == 16.0 and spec.length == 48.0 and spec.height == 24.0,
				"%s: pinned dimensions unchanged" % who)
			var raised: Array = occluders.duplicate()
			raised.append(AABB(Vector3(-spec.width / 2.0, 0.0, -spec.length / 2.0 - 0.5),
				Vector3(spec.width, crown.y + 4.0, 0.5)))
			_expect(res, _any_hit(eye, crown, raised),
				"%s: control (raised west gable) must hide the dome" % who)
			spec.dome_west = false
			var east := ChurchBuilder.new()
			east.build(spec)
			var east_crown := Vector3(0.0, ChurchGeometry.dome_crown_height(spec),
				ChurchGeometry.crossing_center_z(spec))
			_expect(res, _any_hit(eye, east_crown, _dome_occluders(spec, east.mass_log)),
				"%s: control (dome back over the east crossing) must hide the dome" % who)


static func _dome_occluders(spec: ChurchSpec, log: Array) -> Array:
	var out: Array = []
	for row in log:
		if String(row["name"]) in ["pendentive", "dome_drum"]:
			continue
		out.append(row["aabb"])
	out.append(AABB(Vector3(-spec.width / 2.0, spec.height, -spec.length / 2.0),
		Vector3(spec.width, ChurchGeometry.nave_ridge_height(spec) - spec.height, spec.length)))
	return out


static func _any_hit(a: Vector3, b: Vector3, boxes: Array) -> bool:
	for box in boxes:
		if _segment_hits(a, b, box):
			return true
	return false


static func _mass_aabb(log: Array, mass_name: String) -> AABB:
	for row in log:
		if String(row["name"]) == mass_name:
			return row["aabb"]
	return AABB()


static func _front_visible_fraction(log: Array, mass_name: String) -> float:
	var target: AABB = _mass_aabb(log, mass_name)
	if target.size == Vector3.ZERO:
		return 0.0
	var whole: AABB = log[0]["aabb"]
	for row in log:
		whole = whole.merge(row["aabb"])
	var c: Vector3 = whole.get_center()
	var radius: float = maxf(whole.size.length() * 0.5, 1.0)
	var yaw := -0.55
	var cam: Vector3 = c + Vector3(sin(yaw) * radius * 2.3, radius * 0.38, -cos(yaw) * radius * 2.3)
	var seen := 0
	var total := 0
	var inset := 0.05
	for face in 2:  # the west (-Z) face and the -X face face the camera
		for iu in 5:
			for iv in 5:
				var u: float = 0.1 + 0.8 * iu / 4.0
				var v: float = 0.1 + 0.8 * iv / 4.0
				var p: Vector3
				if face == 0:
					p = target.position + Vector3(target.size.x * u, target.size.y * v, -inset)
				else:
					p = target.position + Vector3(-inset, target.size.y * v, target.size.z * u)
				total += 1
				var hit := false
				for row in log:
					if String(row["name"]) == mass_name:
						continue
					if _segment_hits(cam, p, row["aabb"]):
						hit = true
						break
				if not hit:
					seen += 1
	return float(seen) / float(total)


static func _segment_hits(a: Vector3, b: Vector3, box: AABB) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d: Vector3 = b - a
	for axis in 3:
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(d[axis]) < 1e-9:
			if a[axis] < lo or a[axis] > hi:
				return false
		else:
			var ta: float = (lo - a[axis]) / d[axis]
			var tb: float = (hi - a[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return false
	return true
