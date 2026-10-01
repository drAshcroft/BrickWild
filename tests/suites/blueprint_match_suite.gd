class_name BlueprintMatchSuite
extends RefCounted
## 3. The blueprint must be a drawing OF the mesh.
##
## BlueprintView draws from ChurchGeometry. So this suite asserts that what
## ChurchGeometry says equals what ChurchBuilder actually emitted -- for each
## structural mass, for the overall envelope, and for the mesh's real vertices.
## When the view derived its own positions instead, plan and model drifted by
## metres with nothing to catch it.

const TOL := 0.05
## Roofs legitimately overhang the masses they cover (eaves, spire flares).
const MAX_OVERHANG := 0.6


static func run() -> SuiteResult:
	var res := SuiteResult.new("blueprint")
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s seed=%d" % [String(style), TestSweep.seed_at(i)]
			res.checked += 1
			_check_masses_match_geometry(spec, builder, who, res)
			_check_envelope(spec, builder, who, res)
			_check_mesh_within_drawn_extents(spec, mesh, who, res)
			_check_finite(spec, who, res)
	return res


## Bounded VIS-010 fixture. It inspects the same geometry inventory consumed by
## the south elevation and uses one deliberate omission per structural rule.
static func run_vis010() -> SuiteResult:
	var res := SuiteResult.new("vis010")
	var cases: Array[Dictionary] = [
		{"key": "notre_dame", "style": &"gothic", "width": 12.0, "length": 127.0, "height": 33.0, "seed": 5001},
		{"key": "chartres", "style": &"gothic", "width": 16.4, "length": 130.0, "height": 37.5, "seed": 5003},
		{"key": "hagia_sophia", "style": &"byzantine", "width": 31.0, "length": 76.0, "height": 40.0, "seed": 5006},
		{"key": "florence_duomo", "style": &"renaissance", "width": 17.0, "length": 153.0, "height": 45.0, "seed": 5007},
		{"key": "st_basil", "style": &"russian", "width": 24.0, "length": 30.0, "height": 26.0, "seed": 5008},
	]
	for row in cases:
		var spec: ChurchSpec = _vis010_spec(row)
		var inventory: Dictionary = BlueprintView.south_elevation_inventory(spec)
		var key: String = row["key"]
		res.checked += 1
		match key:
			"notre_dame":
				_expect(inventory["aisles"].size() >= 2, key, "two aisle/roof tiers", res)
				_expect(not inventory["clerestory"].is_empty(), key, "clerestory windows", res)
				_expect(not inventory["buttresses"].is_empty(), key, "nave buttress bays", res)
				_expect(not inventory["flyers"].is_empty(), key, "flying buttress bays", res)
			"chartres":
				_expect(not inventory["aisles"].is_empty(), key, "aisle roof tier", res)
				_expect(not inventory["clerestory"].is_empty(), key, "clerestory windows", res)
				_expect(not inventory["flyers"].is_empty(), key, "flying buttress bays", res)
				_expect(inventory["chapels"].size() >= 5, key, "radiating chapel projections", res)
				if spec.transept:
					_expect(inventory["transept"] != AABB(), key, "transept bay", res)
			"hagia_sophia":
				_expect(inventory["dome"] and inventory["dome_shape"] == &"hemisphere", key, "main hemispherical dome", res)
				_expect(inventory["half_domes"], key, "buttressing half-domes", res)
				_expect(inventory["bearing"] != AABB(), key, "square masonry bearing", res)
				_expect(inventory["piers"].size() == 4, key, "four corner piers", res)
				_expect(not inventory["clerestory"].is_empty(), key, "clerestory arches", res)
			"florence_duomo":
				_expect(inventory["dome"] and inventory["dome_shape"] == &"octagonal", key, "octagonal dome", res)
				_expect(inventory["crossing_octagon"] != AABB(), key, "octagonal crossing", res)
				_expect(inventory["tribunes"].size() == 3, key, "three tribunes", res)
				# bays, not a picket line: two lights a side per bay
				_expect(inventory["clerestory"].size() == 4 * ChurchGeometry.hero_bay_count(spec),
					key, "clerestory lights in bays", res)
				_expect(ChurchGeometry.hero_bay_count(spec) <= 6, key, "a few huge bays", res)
				# the crossing is the widest and tallest thing, by a margin
				_expect(spec.dome_radius * 2.0 > spec.width * 2.0 and
					ChurchGeometry.total_height(spec) > spec.height * 1.8,
					key, "dome dominant over the nave", res)
			"st_basil":
				_expect(inventory["dome"] and inventory["dome_shape"] == &"onion", key, "onion dome", res)
				_expect(inventory["chapels"].size() >= 4, key, "cluster chapel projections", res)
				_expect(inventory["chapels"].size() == 8, key, "eight chapels", res)
				_expect(inventory["podium"] != AABB(), key, "podium", res)
				_expect(inventory["tent"], key, "tented core", res)
		if spec.variant_name.ends_with("Minster") or spec.variant_name.ends_with("Priory"):
			_expect(spec.variant_name.contains(" Minster") or spec.variant_name.contains(" Priory"),
				key, "spaced generated suffix", res)

	# One counterexample per optional row proves its geometry inventory is not a
	# permanent decoration list. These checks are intentionally very small.
	var no_aisles: ChurchSpec = _vis010_spec(cases[0])
	no_aisles.aisles = 0
	_expect(BlueprintView.south_elevation_inventory(no_aisles)["aisles"].is_empty(),
		"control", "aisle omission", res)
	var no_flyers: ChurchSpec = _vis010_spec(cases[0])
	no_flyers.flying_buttresses = false
	_expect(BlueprintView.south_elevation_inventory(no_flyers)["flyers"].is_empty(),
		"control", "flyer omission", res)
	var no_buttresses: ChurchSpec = _vis010_spec(cases[0])
	no_buttresses.buttresses = false
	_expect(BlueprintView.south_elevation_inventory(no_buttresses)["buttresses"].is_empty(),
		"control", "buttress omission", res)
	var no_clerestory: ChurchSpec = _vis010_spec(cases[0])
	no_clerestory.clerestory = false
	no_clerestory.flying_buttresses = false
	_expect(BlueprintView.south_elevation_inventory(no_clerestory)["clerestory"].is_empty(),
		"control", "clerestory omission", res)
	var no_transept: ChurchSpec = _copy_vis010_spec(cases[0])
	no_transept.transept = true
	no_transept.transept_len = maxf(no_transept.transept_len, no_transept.width * 2.2)
	_expect(BlueprintView.south_elevation_inventory(no_transept)["transept"] != AABB(),
		"control", "transept presence", res)
	no_transept.transept = false
	_expect(BlueprintView.south_elevation_inventory(no_transept)["transept"] == AABB(),
		"control", "transept omission", res)
	var no_chapels: ChurchSpec = _vis010_spec(cases[1])
	no_chapels.radiating_chapels = 0
	_expect(BlueprintView.south_elevation_inventory(no_chapels)["chapels"].is_empty(),
		"control", "chapel omission", res)
	var no_half_domes: ChurchSpec = _vis010_spec(cases[2])
	no_half_domes.half_domes = false
	_expect(not BlueprintView.south_elevation_inventory(no_half_domes)["half_domes"],
		"control", "half-dome omission", res)
	# the hero rows are keyed off spec.hero, so a church without it draws none
	var no_bearing: ChurchSpec = _vis010_spec(cases[2])
	no_bearing.hero = &""
	var plain: Dictionary = BlueprintView.south_elevation_inventory(no_bearing)
	_expect(plain["bearing"] == AABB() and plain["piers"].is_empty(),
		"control", "bearing and pier omission", res)
	var no_octagon: ChurchSpec = _vis010_spec(cases[3])
	no_octagon.hero = &""
	plain = BlueprintView.south_elevation_inventory(no_octagon)
	_expect(plain["crossing_octagon"] == AABB() and plain["tribunes"].is_empty(),
		"control", "octagon and tribune omission", res)
	var no_podium: ChurchSpec = _vis010_spec(cases[4])
	no_podium.hero = &""
	plain = BlueprintView.south_elevation_inventory(no_podium)
	_expect(plain["podium"] == AABB() and not plain["tent"],
		"control", "podium and tent omission", res)
	return res


static func _vis010_spec(row: Dictionary) -> ChurchSpec:
	var spec: ChurchSpec = _copy_vis010_spec(row)
	match row["key"]:
		"notre_dame":
			spec.aisles = maxi(spec.aisles, 2)
			spec.apse = true
			_force_vis_flyers(spec)
		"chartres":
			spec.apse = true
			spec.ambulatory = true
			spec.radiating_chapels = maxi(spec.radiating_chapels, 7)
			if spec.chapel_radius == 0.0:
				spec.chapel_radius = spec.apse_radius * 0.38
			_force_vis_flyers(spec)
		"hagia_sophia", "florence_duomo", "st_basil":
			ChurchGenerator.apply_landmark(spec, row["key"])
	return spec


static func _copy_vis010_spec(row: Dictionary) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = row["style"]
	spec.width = row["width"]
	spec.length = row["length"]
	spec.height = row["height"]
	ChurchGenerator.generate(spec, row["seed"])
	return spec


static func _force_vis_flyers(spec: ChurchSpec) -> void:
	spec.flying_buttresses = true
	spec.buttresses = true
	spec.buttress_count_per_side = maxi(spec.buttress_count_per_side, 4)
	if spec.buttress_depth == 0.0:
		spec.buttress_depth = 0.6


static func _expect(condition: bool, who: String, expected: String, res: SuiteResult) -> void:
	res.checked += 1
	if not condition:
		res.fail("%s: missing %s from south elevation inventory" % [who, expected])


## Every mass the builder emitted must sit exactly where ChurchGeometry says.
static func _check_masses_match_geometry(spec: ChurchSpec, builder: ChurchBuilder,
		who: String, res: SuiteResult) -> void:
	for m in builder.mass_log:
		var name: String = m["name"]
		var got: AABB = m["aabb"]
		# Flying-buttress piers and arches are structural but have no single
		# declared position function in ChurchGeometry -- they are placed from
		# per-tier spans derived at build time, not one AABB. Skip them.
		if name.begins_with("flyer_"):
			continue
		var want: AABB
		match name:
			"nave":
				want = ChurchGeometry.nave_aabb(spec)
			"tower":
				want = ChurchGeometry.tower_aabb(spec, 0.0)
			"tower_left":
				want = ChurchGeometry.tower_aabb(spec, -1.0)
			"tower_right":
				want = ChurchGeometry.tower_aabb(spec, 1.0)
			"apse":
				want = ChurchGeometry.apse_aabb(spec)
			"transept":
				want = ChurchGeometry.transept_aabb(spec)
			"ambulatory":
				want = ChurchGeometry.ambulatory_aabb(spec)
			"crossing_tower":
				want = ChurchGeometry.crossing_tower_aabb(spec)
			"pendentive":
				want = ChurchGeometry.pendentive_aabb(spec)
			"dome_drum":
				want = ChurchGeometry.dome_drum_aabb(spec)
			"narthex":
				want = ChurchGeometry.narthex_aabb(spec)
			"crossing_octagon":
				want = ChurchGeometry.octagon_aabb(spec)
			"podium":
				want = ChurchGeometry.podium_aabb(spec)
			var n when n.begins_with("tribune_"):
				want = ChurchGeometry.tribune_aabb(spec, n.get_slice("_", 1).to_int())
			var n when n.begins_with("aisle_left_"):
				want = ChurchGeometry.aisle_aabb(spec, -1.0, n.get_slice("_", 2).to_int())
			var n when n.begins_with("aisle_right_"):
				want = ChurchGeometry.aisle_aabb(spec, 1.0, n.get_slice("_", 2).to_int())
			var n when n.begins_with("chapel_"):
				want = ChurchGeometry.chapel_aabb(spec, n.get_slice("_", 1).to_int())
			_:
				res.fail("%s: mass '%s' has no ChurchGeometry counterpart" % [who, name])
				continue
		if not _aabb_close(got, want):
			res.fail("%s: %s drawn at %s but built at %s"
				% [who, name, _fmt(want), _fmt(got)])


## The drawn envelope must match the union of what was built.
static func _check_envelope(spec: ChurchSpec, builder: ChurchBuilder,
		who: String, res: SuiteResult) -> void:
	if builder.mass_log.is_empty():
		return
	var u: AABB = builder.mass_log[0]["aabb"]
	for m in builder.mass_log:
		u = u.merge(m["aabb"])
	var zext: Vector2 = ChurchGeometry.mass_length_extent(spec)
	if absf(u.position.z - zext.x) > TOL or absf(u.position.z + u.size.z - zext.y) > TOL:
		res.fail("%s: masses should span [%.2f,%.2f] but span [%.2f,%.2f]"
			% [who, zext.x, zext.y, u.position.z, u.position.z + u.size.z])
	var wext: float = ChurchGeometry.width_extent(spec)
	if u.size.x - wext > TOL:
		res.fail("%s: built width %.2f exceeds drawn width extent %.2f"
			% [who, u.size.x, wext])


## The real mesh must live inside the extents the sheet advertises, allowing
## for roof overhang, and must actually reach the height the sheet dimensions.
static func _check_mesh_within_drawn_extents(spec: ChurchSpec, mesh: ArrayMesh,
		who: String, res: SuiteResult) -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := -Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v)
			mx = mx.max(v)
	var zext: Vector2 = ChurchGeometry.length_extent(spec)
	if mn.z < zext.x - MAX_OVERHANG:
		res.fail("%s: mesh reaches z=%.2f, west of drawn extent %.2f"
			% [who, mn.z, zext.x])
	if mx.z > zext.y + MAX_OVERHANG:
		res.fail("%s: mesh reaches z=%.2f, east of drawn extent %.2f"
			% [who, mx.z, zext.y])
	var drawn_h: float = ChurchGeometry.total_height(spec)
	if mx.y > drawn_h + MAX_OVERHANG:
		res.fail("%s: mesh is %.2fm tall but the sheet dimensions %.2fm"
			% [who, mx.y, drawn_h])
	if mx.y < drawn_h - MAX_OVERHANG:
		res.warn("%s: sheet dimensions %.2fm but mesh only reaches %.2fm"
			% [who, drawn_h, mx.y])


## A blueprint that divides by zero draws nothing; catch it as data, not paint.
static func _check_finite(spec: ChurchSpec, who: String, res: SuiteResult) -> void:
	var vals := {
		"total_height": ChurchGeometry.total_height(spec),
		"width_extent": ChurchGeometry.width_extent(spec),
		"door_height": ChurchGeometry.door_height(spec),
		"transept_depth": ChurchGeometry.transept_depth(spec),
	}
	for k in vals:
		var v: float = vals[k]
		if not is_finite(v) or v <= 0.0:
			res.fail("%s: ChurchGeometry.%s is %s" % [who, k, str(v)])
	if ChurchGeometry.nave_window_count(spec) < 1:
		res.fail("%s: nave_window_count is 0, window spacing would divide by zero" % who)


static func _aabb_close(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) <= TOL and a.size.distance_to(b.size) <= TOL


static func _fmt(a: AABB) -> String:
	return "[%.2f,%.2f,%.2f]+%.2fx%.2fx%.2f" % [a.position.x, a.position.y, a.position.z,
		a.size.x, a.size.y, a.size.z]
