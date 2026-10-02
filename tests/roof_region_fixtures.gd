extends RefCounted
## Authored spatial contracts, independent of builder logs. All coordinates
## are metres; a region says what is occupied and what deliberately sees sky.
const Probe = preload("res://tests/roof_probe.gd")

class TempleWithoutIdol extends TempleBuilder:
	func _build_idol() -> void:
		pass # A monument cannot count its own bottom face as its support.

class TempleShortStairs extends TempleBuilder:
	func _stair_flight(rect: Rect2, top: float, name: String) -> void:
		var short := rect
		short.size.y = TempleGeometry.site_rect(spec).position.y + 0.3 - short.position.y
		super._stair_flight(short, top, name)

static func build(families: Array[String]) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	if "house" in families:
		_houses(cases)
	if "temple" in families:
		_ziggurats(cases)
	if "castle" in families:
		_castles(cases)
	if "hotel" in families:
		_hotels(cases)
	if "house" in families and "shop" in families:
		_village(cases)
	return cases


static func _case(family: String, id: String, spec: RefCounted, mesh: ArrayMesh,
		regions: Array[Dictionary], source: String) -> Dictionary:
	return {"family": family, "fixture": id, "seed": spec.seed,
		"style": String(spec.form) if spec is TempleSpec else String(spec.style),
		"width": spec.width, "length": spec.length, "height": spec.height,
		"source": source, "mesh": mesh, "regions": regions}


static func _region(name: String, poly: PackedVector2Array, top: float,
		sky := false, surface := 2, holes: Array[PackedVector2Array] = []) -> Dictionary:
	return {"region": name, "polygon": poly, "occupied_top": top,
		"expect_sky": sky, "surface": surface, "openings": holes}


static func _houses(cases: Array[Dictionary]) -> void:
	for size in [Vector2(17, 15), Vector2(25, 21)]:
		var plan := CourtSuite.courtyard(size.x, size.y, 7100, false)
		var regions: Array[Dictionary] = []
		for i in plan.rooms.size():
			regions.append(_region("court_range_%d" % i, plan.outline_of(i), plan.spec.height - 0.2))
		regions.append(_region("open_court", plan.court_outline(0), plan.spec.height - 0.2, true))
		cases.append(_case("house", "authored_court_%dx%d" % [size.x, size.y], plan.spec,
			HouseBuilder.new().build(plan), regions, "tests/suites/court_suite.gd: courtyard"))
	for sides in [8, 14]:
		var spec := HouseSpec.new(1919 + sides)
		spec.width = 12
		spec.length = 12
		spec.height = 3.0
		spec.material = &"stone"
		spec.roof_type = &"gable"
		spec.roof_pitch = 0.8
		spec.porch = false
		spec.chimney = false
		var plan := HousePlan.new()
		plan.spec = spec
		var outline := _circle(Vector2.ZERO, 5.7, sides)
		plan.rooms.append({"kind": &"hall", "storey": 0, "outline": outline, "rect": Poly.bounding_rect(outline)})
		var hole := Rect2(-0.8, -0.8, 1.6, 1.6)
		plan.roof_openings.append({"id": "polygon_oculus", "kind": &"oculus", "storey": 0, "room": 0, "rect": hole})
		# An oculus is circular, inscribed in its authoring rectangle.
		var holes: Array[PackedVector2Array] = [_circle(hole.get_center(), hole.size.x * 0.5, 24)]
		var regions: Array[Dictionary] = [_region("polygon_hall", outline, 2.8, false, 2, holes),
			_region("oculus_sky", holes[0], 2.8, true)]
		cases.append(_case("house", "authored_%dgon_oculus" % sides, spec,
			HouseBuilder.new().build(plan), regions, "tests/roof_region_fixtures.gd: _houses"))


static func _ziggurats(cases: Array[Dictionary]) -> void:
	for size in [Vector2(18, 24), Vector2(24, 30), Vector2(36, 42)]:
		var spec := TempleSpec.new(4413)
		spec.form = &"ziggurat"
		spec.width = size.x
		spec.length = size.y
		spec.height = 14
		TempleGenerator.generate(spec, spec.seed)
		var height := TempleGeometry.terrace_height(spec)
		var hall := TempleGeometry.hall_rect(spec).grow(-0.2)
		var regions: Array[Dictionary] = [_region("occupied_base_chamber", Poly.from_rect(hall), height - 0.2, false, 0)]
		# Each exposed terrace is sky, while the smaller next terrace is an
		# explicit exclusion. Coping is outside the inset sampled polygon.
		for level in range(spec.terraces - 1):
			var outer := TempleGeometry.terrace_rect(spec, level).grow(-0.5)
			var inner := TempleGeometry.terrace_rect(spec, level + 1).grow(0.5)
			var holes: Array[PackedVector2Array] = [Poly.from_rect(inner)]
			# The physically tested stairs cross the lower open terraces.
			for flight in TempleGeometry.stair_rects(spec):
				holes.append(Poly.from_rect(flight.grow(0.05)))
			regions.append(_region("open_terrace_%d" % level, Poly.from_rect(outer),
				height * (level + 1) + 0.1, true, 0, holes))
		var chamber := _case("temple", "ziggurat_chamber_%dx%d" % [size.x, size.y], spec,
			TempleBuilder.new().build(spec), regions, "src/temple/temple_geometry.gd: hall_rect/terrace_rect")
		chamber["stair_spec"] = spec
		cases.append(chamber)
		var idol := TempleGeometry.idol_center(spec)
		var half := spec.idol_width * 0.7
		var support: Array[Dictionary] = [_region("summit_under_actual_idol_base",
			Poly.from_rect(Rect2(Vector2(idol.x, idol.z) - Vector2.ONE * half, Vector2.ONE * half * 2.0)),
			idol.y - 0.02, false, 0)]
		for region in regions:
			if region["expect_sky"]:
				support.append(region)
		cases.append(_case("temple", "ziggurat_summit_support_%dx%d" % [size.x, size.y], spec,
			TempleWithoutIdol.new().build(spec), support,
			"src/temple/temple_geometry.gd: idol_center/terrace_top; host mesh excludes idol"))


static func _castles(cases: Array[Dictionary]) -> void:
	var sizes := {&"house": Vector2(14, 18), &"manor": Vector2(28, 40),
		&"castle": Vector2(65, 80), &"fortress": Vector2(130, 140)}
	for tier in sizes:
		for scale in [0.85, 1.15]:
			var size: Vector2 = sizes[tier] * scale
			var spec := CastleSpec.new(42)
			spec.style = &"edwardian"
			spec.width = size.x
			spec.length = size.y
			spec.height = 10
			spec.tier_override = tier
			spec.plan_override = &"rect"
			CastleGenerator.generate(spec, spec.seed)
			spec.battlements = true
			spec.tower_roof = &"flat"
			var regions: Array[Dictionary] = []
			var sky_holes: Array[PackedVector2Array] = []
			var tower_holes: Array[PackedVector2Array] = []
			var deck_seams: Array[Dictionary] = []
			var boxes: Array[AABB] = []
			for centre in CastleGeometry.manor_tower_centers(spec):
				var radius := CastleGeometry.tower_radius_for(spec, CastleGeometry.tower_half(spec, 0)) + CastleBuilder.EAVE
				var poly := _circle(Vector2(centre.x, centre.z), radius,
					CastleGeometry.tower_sides(spec), CastleGeometry.tower_rotation(spec))
				tower_holes.append(poly)
				sky_holes.append(poly)
				var height := CastleGeometry.tower_height(spec, 0)
				regions.append(_region("manor_tower_deck_%d" % tower_holes.size(), Poly.offset(poly, -0.05), height - 0.02, false, 1))
				deck_seams.append({"polygon": poly, "height": height, "centre": Vector2(centre.x, centre.z)})
			if tier in [&"house", &"manor"]:
				boxes.append(CastleGeometry.house_range_aabb(spec))
				for side in CastleGeometry.wing_sides(spec):
					boxes.append(CastleGeometry.manor_wing_aabb(spec, side) if tier == &"manor" else CastleGeometry.annexe_aabb(spec))
				if tier == &"manor" and spec.courtyard:
					boxes.append(CastleGeometry.manor_front_range_aabb(spec))
			else:
				boxes.append(CastleGeometry.hall_aabb(spec))
				boxes.append(CastleGeometry.chapel_aabb(spec))
				# The keep's own plan is the occupied outline, including tapered
				# tiers; its bounding box is deliberately not a roof contract.
				var keep: HousePlan = preload("res://src/castle/castle_keep_plan.gd").generate(spec, false)
				if keep.spec != null:
					var k := CastleGeometry.keep_aabb(spec)
					var xf := Transform3D(Basis.IDENTITY, Vector3(k.get_center().x, k.position.y, k.get_center().z))
					for i in keep.rooms.size():
						if keep.storey_of_room(i) == keep.spec.storeys - 1:
							regions.append(_region("keep_top_room_%d" % i, _poly_xf(keep.outline_of(i), xf), k.end.y - 0.2))
				for box in CastleGeometry.bailey_obstacles(spec):
					sky_holes.append(Poly.from_rect(box.grow(1.0)))
				for building in CastleGenerator.bailey_buildings(spec):
					sky_holes.append(Poly.from_rect(Rect2(building["rect"]).grow(1.0)))
				var well := CastleGenerator.bailey_well(spec)
				if not well.is_empty():
					var radius := float(well["radius"])
					var at: Vector2 = well["pos"]
					sky_holes.append(Poly.from_rect(Rect2(at - Vector2.ONE * radius * 1.3, Vector2.ONE * radius * 2.6)))
					regions.append(_region("covered_well", Poly.from_rect(Rect2(at - Vector2.ONE * radius * 0.8,
						Vector2.ONE * radius * 1.6)), radius * 3.15 - 0.1))
			for i in boxes.size():
				var box := boxes[i]
				if box.size.x < 1 or box.size.z < 1:
					continue
				var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
				regions.append(_region("occupied_range_%d" % i, Poly.from_rect(rect.grow(-0.3)), box.end.y - 0.2, false, 2, tower_holes))
				sky_holes.append(Poly.from_rect(rect.grow(1.0)))
			if tier != &"house":
				regions.append(_region("open_yard", Poly.from_rect(CastleGeometry.bailey_rect(spec).grow(-3.0)),
					0.5, true, 2, sky_holes))
			else:
				regions.append(_region("open_approach", Poly.from_rect(Rect2(-1, -size.y * 0.5 - 5, 2, 1)), 0.5, true))
			if CastleGeometry.is_enclosed(spec):
				var r := CastleGeometry.inner_ring(spec)
				for seg in CastleGeometry.wall_segments(spec, r):
					var normal: Vector3 = seg["outward"]
					var centre: Vector2 = (Vector2(seg["a"]) + Vector2(seg["b"])) * 0.5 - Vector2(normal.x, normal.z) * CastleGeometry.wall_thickness(spec, r) * 0.5
					regions.append(_region("open_battlement_" + String(seg["name"]),
						Poly.from_rect(Rect2(centre - Vector2.ONE * 0.12, Vector2.ONE * 0.24)),
						CastleGeometry.wall_height(spec, r) + CastleGeometry.PARAPET_RISE + 0.1, true))
			print("  Building region fixture %s %.2f" % [tier, scale])
			var row := _case("castle", "%s_tier_scale_%.2f" % [tier, scale], spec,
				CastleBuilder.new().build(spec), regions, "src/castle/castle_geometry.gd: explicit occupied ranges/keep plans/wall walks")
			row["deck_seams"] = deck_seams
			cases.append(row)


static func _hotels(cases: Array[Dictionary]) -> void:
	for style in [&"grand_budapest", &"alpine_palace"]:
		for size in [Vector2(36, 18), Vector2(64, 32)]:
			var spec := HotelSpec.new(42)
			spec.style = style
			spec.width = size.x
			spec.length = size.y
			var plan := HotelGenerator.generate(spec, spec.seed, false)
			spec.cupolas = true
			var top := HotelGeometry.wall_top(spec)
			var radius := HotelGeometry.cupola_radius(spec)
			var regions: Array[Dictionary] = []
			var seams: Array[Dictionary] = []
			for side in [-1.0, 1.0]:
				var centre := Vector2(side * HotelGeometry.tower_x(spec), HotelGeometry.front_z(spec) + 1.9)
				regions.append(_region("cupola_%d" % side, _circle(centre, radius * 0.95, 16), top + 2.18))
				seams.append({"centre": centre, "radius": radius * 1.1, "height": top + 2.2})
			regions.append(_region("open_forecourt", Poly.from_rect(Rect2(-1, -spec.length * 0.5 - 6, 2, 1)), 1.0, true))
			var row := _case("hotel", "%s_cupolas_%dx%d" % [style, size.x, size.y], spec,
				HotelBuilder.new().build(plan), regions, "src/hotel/hotel_geometry.gd: tower_x/cupola_radius; hotel_builder.gd: _build_cupola")
			row["seams"] = seams
			cases.append(row)


static func _village(cases: Array[Dictionary]) -> void:
	var spec := VillageSpec.new(18590)
	spec.population = 50
	spec.water = &"none"
	spec.generate(spec.seed)
	var site := VillageSitePlanner.plan(spec)
	var requests: Array[BuildingRequest] = [BuildingRequest.house(4412, &"cottage", &"none", 7, 9, 2.8, 2),
		BuildingRequest.shop(18550, &"bakery", &"farmhouse", 11, 14, 2.8, 1)]
	var left := VillageLotPlanner.cut_measured(site, VillageLotPlanner.measure_all(requests))
	if left > 0:
		cases.append({"family": "village", "fixture": "placed_native_buildings", "source": "src/village/lot_planner.gd", "setup_failure": "%d authored buildings unplaced" % left})
		return
	for i in site.buildings.size():
		var record: Dictionary = site.buildings[i]
		var building := BrickWild._generate(record["request"], true)
		var plan: HousePlan = building.plan
		var xf: Transform3D = record["transform"]
		var regions: Array[Dictionary] = []
		for room in plan.rooms.size():
			if plan.storey_of_room(room) == plan.spec.storeys - 1:
				regions.append(_region("placed_room_%d" % room, _poly_xf(plan.outline_of(room), xf),
					xf.origin.y + plan.spec.height * plan.spec.storeys - 0.2))
		var door: Vector3 = record["placement"]["door"]
		regions.append(_region("open_entrance_approach", _poly_xf(Poly.from_rect(
			Rect2(door.x - 0.3, door.z - 4.3, 0.6, 0.6)), xf), xf.origin.y + 1.0, true))
		var row := _case("village", "placed_%s_%d" % [record["kind"], i], plan.spec,
			_mesh_xf(BrickWild.build_mesh(building), xf), regions, "src/village/lot_planner.gd: cut_measured; native BuildingRequest")
		row["site_seed"] = spec.seed
		row["transform"] = [[xf.basis.x.x, xf.basis.x.y, xf.basis.x.z],
			[xf.basis.y.x, xf.basis.y.y, xf.basis.y.z], [xf.basis.z.x, xf.basis.z.y, xf.basis.z.z],
			[xf.origin.x, xf.origin.y, xf.origin.z]]
		cases.append(row)


static func _circle(centre: Vector2, radius: float, count: int, rotation := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		out.append(centre + Vector2(cos(rotation + TAU * i / count), sin(rotation + TAU * i / count)) * radius)
	return out


static func _poly_xf(poly: PackedVector2Array, xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		var at := xf * Vector3(p.x, 0, p.y)
		out.append(Vector2(at.x, at.z))
	return out


static func _mesh_xf(mesh: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			vertices[i] = xf * vertices[i]
			normals[i] = (xf.basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func evaluate(fixture: Dictionary) -> Dictionary:
	var row := fixture.duplicate()
	row.erase("mesh")
	row.erase("regions")
	row.erase("seams")
	row.erase("deck_seams")
	row.erase("stair_spec")
	row.merge({"type": "authored_region_contract", "checked": 0,
		"failures": [], "warnings": [], "notes": [], "samples": [], "controls": []})
	if fixture.has("setup_failure"):
		row.failures.append("fixture_setup: " + fixture["setup_failure"])
		return row
	var mesh: ArrayMesh = fixture["mesh"]
	for region in fixture["regions"]:
		var sky: bool = region["expect_sky"]
		var holes: Array[PackedVector2Array] = region["openings"]
		var check := Probe.coverage(mesh, region["polygon"], region["occupied_top"],
			holes, sky, 13, region["surface"])
		row.checked += check.checked
		row.samples.append({"region": region["region"], "polygon": _points(region["polygon"]),
			"openings": holes.map(func(poly: PackedVector2Array) -> Array: return _points(poly)),
			"occupied_top": region["occupied_top"], "surface": region["surface"],
			"expect_sky": sky, "checked": check.checked, "covered": check.covered, "misses": check.misses})
		if check.checked == 0 or not check.misses.is_empty():
			row.failures.append("%s: %s %d misses/%d samples; first=%s" % ["intentional_sky" if sky else "roof_coverage",
				region["region"], check.misses.size(), check.checked, str(check.misses[0]) if not check.misses.is_empty() else "no samples"])
		if not sky:
			var removed := _without_cover(mesh, region["surface"], region["occupied_top"])
			var negative := Probe.coverage(removed, region["polygon"], region["occupied_top"], holes, false, 13, region["surface"])
			row.checked += 1
			var detected: bool = negative.checked > 0 and not negative.misses.is_empty()
			row.controls.append({"region": region["region"], "mutation": "remove actual surface triangles above occupied_top",
				"detected": detected, "misses": negative.misses})
			if not detected:
				row.failures.append("negative_control: removed roof escaped for " + region["region"])
	if fixture.has("seams"):
		for seam in fixture["seams"]:
			var good := _cupola_seam(mesh, seam)
			row.checked += 4
			row.samples.append({"region": "cupola_bearing_seam", "targets": good["targets"],
				"tolerance": 0.02, "misses": good["misses"], "occupied_top": seam["height"]})
			if not good["misses"].is_empty():
				row.failures.append("cupola_seam: missing roof rim or wall bearing at " + str(good["misses"][0]))
			var floated := _raise_surface(mesh, 2, 0.35)
			var negative := _cupola_seam(floated, seam)
			row.checked += 1
			row.controls.append({"region": "cupola_bearing_seam", "mutation": "raise actual roof vertices 0.35m; wall/spec unchanged",
				"detected": not negative["misses"].is_empty(), "misses": negative["misses"]})
			if negative["misses"].is_empty():
				row.failures.append("negative_control: floating cupola escaped")
	for seam in fixture.get("deck_seams", []):
		var good := _deck_seam(mesh, seam)
		row.checked += good["targets"].size()
		row.samples.append({"region": "tower_deck_bearing", "targets": good["targets"], "misses": good["misses"], "tolerance": 0.02})
		if not good["misses"].is_empty():
			row.failures.append("tower_deck_bearing: floating deck at " + str(good["misses"][0]))
		var negative := _deck_seam(_raise_surface(mesh, 1, 0.125), seam)
		row.checked += 1
		row.controls.append({"region": "tower_deck_bearing", "mutation": "raise actual trim deck0.125m; stone shaft unchanged",
			"detected": not negative["misses"].is_empty(), "misses": negative["misses"]})
		if negative["misses"].is_empty():
			row.failures.append("negative_control: floating tower deck escaped")
	if fixture.has("stair_spec"):
		var spec: TempleSpec = fixture["stair_spec"]
		var good := _stair_contact(mesh, spec)
		row.checked += good["checked"]
		row.samples.append({"region": "summit_stair_treads_and_landing", "targets": good["targets"],
			"misses": good["misses"], "max_riser": 0.35, "tolerance": 0.02})
		if not good["misses"].is_empty():
			row.failures.append("summit_stair_contact: " + str(good["misses"][0]))
		var shortened := TempleShortStairs.new().build(spec)
		var negative := _stair_contact(shortened, spec)
		row.checked += 2
		row.controls.append({"region": "summit_stair_treads_and_landing", "mutation": "actual flights end at base front; spec and summit unchanged",
			"detected": not negative["misses"].is_empty(), "misses": negative["misses"]})
		if negative["misses"].is_empty():
			row.failures.append("negative_control: disconnected summit stairs escaped")
		# The repair uses the original physical toe and apron, so existing
		# measured native-building placement bounds remain exactly stable.
		if not mesh.get_aabb().is_equal_approx(shortened.get_aabb()):
			row.failures.append("summit_stair_bounds: repair changed external mesh bounds")
		var clear := _stair_chamber_clear(_stairs_only(spec), spec)
		row.checked += clear["checked"] + 1
		row.samples.append({"region": "chamber_under_summit_stairs", "targets": clear["targets"], "misses": clear["misses"]})
		if not clear["misses"].is_empty():
			row.failures.append("summit_stair_chamber: stairs fill occupied chamber at " + str(clear["misses"][0]))
		var filled := _stair_chamber_clear(_stairs_only(spec, true), spec)
		row.controls.append({"region": "chamber_under_summit_stairs", "mutation": "emit actual solid stairs to ground inside chamber",
			"detected": not filled["misses"].is_empty(), "misses": filled["misses"]})
		if filled["misses"].is_empty():
			row.failures.append("negative_control: stairs filled the chamber undetected")
	return row


static func _points(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for p in poly:
		out.append([p.x, p.y])
	return out


static func _stair_contact(mesh: ArrayMesh, spec: TempleSpec) -> Dictionary:
	var out := {"checked": 0, "targets": [], "misses": []}
	var tris := Probe.Rays._triangles(mesh, 0)
	var top := TempleGeometry.terrace_top(spec)
	var summit := TempleGeometry.terrace_rect(spec, maxi(spec.terraces - 1, 0))
	var steps := maxi(ceili(top / 0.35), 4)
	for flight in TempleGeometry.stair_rects(spec):
		var overlap := flight.intersection(summit)
		out.checked += 1
		if overlap.size.x < 0.6 or overlap.size.y < 0.45:
			out.misses.append({"reason": "landing overlap below 0.6m width / 0.45m depth", "size": [overlap.size.x, overlap.size.y]})
		var x := overlap.get_center().x
		var previous := 0.0
		for i in steps:
			var z := lerpf(flight.position.y, flight.end.y, (i + 0.5) / steps)
			var expected := top * (i + 1) / steps
			var heights := Probe.Rays._heights(tris, x, z, -0.5, top + 0.5)
			var actual: float = heights[-1] if not heights.is_empty() else -INF
			out.checked += 1
			out.targets.append([x, expected, z])
			if not is_finite(actual) or absf(actual - expected) > 0.02 or actual - previous > 0.351:
				out.misses.append({"point": [x, expected, z], "actual": actual if is_finite(actual) else null,
					"rise": actual - previous if is_finite(actual) else null})
			previous = actual
		# Both sides of the physical joint must have stone at summit height.
		for z in [summit.position.y - 0.02, summit.position.y + 0.02, overlap.end.y - 0.05]:
			var at := Vector3(x, top, z)
			out.checked += 1
			out.targets.append([at.x, at.y, at.z])
			if not Probe.Rays._intersects(tris, at - Vector3.UP * 0.02, at + Vector3.UP * 0.02):
				out.misses.append({"point": [at.x, at.y, at.z], "reason": "no landing at summit height"})
	return out


static func _stairs_only(spec: TempleSpec, solid := false) -> ArrayMesh:
	var builder := TempleBuilder.new()
	builder.spec = spec
	builder.begin(1)
	var top := TempleGeometry.terrace_top(spec)
	for flight in TempleGeometry.stair_rects(spec):
		if not solid:
			builder._stair_flight(flight, top, "stair")
			continue
		var steps := maxi(ceili(top / 0.35), 4)
		for i in steps:
			var y := top * (i + 1) / steps
			var z := lerpf(flight.position.y, flight.end.y, (i + 0.5) / steps)
			builder.box(Vector3(flight.size.x, y, flight.size.y / steps + 0.05), Vector3(flight.get_center().x, y * 0.5, z), 0)
	return builder.commit()


static func _stair_chamber_clear(mesh: ArrayMesh, spec: TempleSpec) -> Dictionary:
	var out := {"checked": 0, "targets": [], "misses": []}
	var tris := Probe.Rays._triangles(mesh, 0)
	var top := TempleGeometry.terrace_height(spec) - 0.02
	for flight in TempleGeometry.stair_rects(spec):
		var room := flight.intersection(TempleGeometry.hall_rect(spec).grow(-0.1))
		for ix in 3:
			for iz in 5:
				var p := room.position + room.size * Vector2((ix + 0.37) / 3, (iz + 0.61) / 5)
				out.checked += 1
				out.targets.append([p.x, top, p.y])
				if Probe.Rays._intersects(tris, Vector3(p.x, -0.1, p.y), Vector3(p.x, top, p.y)):
					out.misses.append([p.x, top, p.y])
	return out


static func _without_cover(mesh: ArrayMesh, surface: int, top: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		if s != surface:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var kept := 0
		for tri in Probe.Rays._triangles(mesh, surface):
			if maxf(tri[0].y, maxf(tri[1].y, tri[2].y)) >= top:
				continue
			var normal: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
			for p in tri:
				tool.set_normal(normal)
				tool.add_vertex(p)
			kept += 1
		if kept == 0:
			# Preserve the material slot while leaving the actual building empty.
			for p in [Vector3(-100, -100, -100), Vector3(-101, -100, -100), Vector3(-100, -100, -101)]:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(p)
		tool.commit(out)
	return out


static func _raise_surface(mesh: ArrayMesh, surface: int, rise: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if s == surface:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i].y += rise
			arrays[Mesh.ARRAY_VERTEX] = vertices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _cupola_seam(mesh: ArrayMesh, seam: Dictionary) -> Dictionary:
	var arrays := mesh.surface_get_arrays(2)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var wall := Probe.Rays._triangles(mesh, 0)
	var out := {"targets": [], "misses": []}
	for index in 4:
		# Diagonal rim points sit over the square tower's top face. Cardinal
		# points are deliberate eaves and cannot be required to touch a wall.
		var angle := PI * 0.25 + index * PI * 0.5
		var p: Vector2 = seam["centre"] + Vector2(cos(angle), sin(angle)) * float(seam["radius"])
		var at := Vector3(p.x, float(seam["height"]), p.y)
		var nearest := INF
		for vertex in vertices:
			nearest = minf(nearest, vertex.distance_to(at))
		var bearing := Probe.Rays._intersects(wall, at - Vector3.UP * 0.02, at + Vector3.UP * 0.02)
		out.targets.append([at.x, at.y, at.z])
		if nearest > 0.02 or not bearing:
			out.misses.append({"point": [at.x, at.y, at.z], "roof_rim_gap": nearest, "wall_bearing": bearing})
	return out


static func _deck_seam(mesh: ArrayMesh, seam: Dictionary) -> Dictionary:
	var arrays := mesh.surface_get_arrays(1)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var centre: Vector2 = seam["centre"]
	var height: float = seam["height"]
	var bearing := Probe.Rays._intersects(Probe.Rays._triangles(mesh, 0),
		Vector3(centre.x, height - 0.02, centre.y), Vector3(centre.x, height + 0.02, centre.y))
	var out := {"targets": [], "misses": []}
	for p in seam["polygon"]:
		var at := Vector3(p.x, height, p.y)
		var nearest := INF
		for vertex in vertices:
			nearest = minf(nearest, vertex.distance_to(at))
		out.targets.append([at.x, at.y, at.z])
		if nearest > 0.02 or not bearing:
			out.misses.append({"point": [at.x, at.y, at.z], "deck_lower_edge_gap": nearest, "shaft_bearing": bearing})
	return out
