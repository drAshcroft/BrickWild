extends RefCounted
## EVAL-B02 steps 2 and 3, EVAL-B07: the moat holds water, the ground apron is
## optional and never part of placement, and a floating fortress is lived in.

const Landmarks := preload("res://tests/suites/castle_landmark_suite.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("EVAL-B02 castle ground, moat and sky dressing")
	_moat(res)
	_apron(res)
	_sky(res)
	return res


static func _want(res: SuiteResult, ok: bool, msg: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(msg)


static func _bodiam(apron: bool) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.tier_override = &"castle"
	spec.width = 55.0
	spec.length = 50.0
	spec.height = 18.0
	CastleGenerator.generate(spec, Landmarks._seed_for("bodiam", 1.0))
	Landmarks._force_features("bodiam", spec)
	spec.ground_apron = apron
	return spec


static func _count(builder: CastleBuilder, prefix: String) -> int:
	var n := 0
	for m in builder.mass_log:
		if String(m["name"]).begins_with(prefix):
			n += 1
	return n


## Water at its level, a bank, a revetment, a causeway on piers; all logged.
static func _moat(res: SuiteResult) -> void:
	var spec := _bodiam(false)
	var b := CastleBuilder.new()
	var mesh: ArrayMesh = b.build(spec)
	_want(res, spec.plan_kind == &"water", "bodiam is not a water plan")
	_want(res, _count(b, "bank_") >= 3, "moat: fewer than three logged bank masses")
	_want(res, _count(b, "revetment_") >= 2, "moat: fewer than two logged revetment pieces")
	_want(res, b.has_mass("causeway"), "moat: no logged causeway deck")
	_want(res, _count(b, "causeway_pier_") >= 4, "moat: causeway is a slab, it has no piers")
	_want(res, _count(b, "causeway_parapet_") == 2, "moat: causeway has no parapets")
	_want(res, mesh.get_surface_count() >= 5, "moat: no ground skin surface for the water")
	# the water is a skin with depth colour: more than one tone in its vertices
	var tones := {}
	var arrays: Array = mesh.surface_get_arrays(CastleBuilder.SURF_GROUND)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for c in cols:
		tones[c.to_html()] = true
	_want(res, tones.size() >= 4, "moat: water and bank carry fewer than four tones (%d)" % tones.size())
	# the deck is narrower than the lane the road reserves: water either side
	var road: AABB = CastleGeometry.causeway_aabb(spec)
	var deck: AABB = b.mass_aabb("causeway")
	_want(res, deck.size.x < road.size.x - 0.5, "moat: causeway deck fills the whole reserved lane")
	var report: Dictionary = CastleMassingCheck.new().check(spec, b)
	for f in report["failures"]:
		res.fail("bodiam massing: %s" % str(f))
	res.checked += 1


## Optional, off by default, outside the plan, never in placement.
static func _apron(res: SuiteResult) -> void:
	var bare := _bodiam(false)
	var bare_b := CastleBuilder.new()
	var bare_mesh: ArrayMesh = bare_b.build(bare)
	_want(res, _count(bare_b, "ground_apron") == 0, "apron: a bare castle logged apron masses")

	var spec := _bodiam(true)
	var b := CastleBuilder.new()
	var mesh: ArrayMesh = b.build(spec)
	_want(res, _count(b, "ground_apron_") == 6, "apron: %d ring and track masses, wanted 6" % _count(b, "ground_apron_"))
	# every other mass is exactly what it was without the apron
	_want(res, b.mass_log.size() == bare_b.mass_log.size() + 6, "apron: it changed the other logged masses")
	_want(res, mesh.get_surface_count() == bare_mesh.get_surface_count(), "apron: it changed the surface slots")
	var extent: Rect2 = CastleGeometry.plan_extent(spec)
	var track: AABB = b.mass_aabb("ground_apron_track")
	_want(res, absf(track.get_center().x) < 0.01, "apron: the track is off the gate axis")
	_want(res, track.position.z < extent.position.y - CastleApron.WIDTH, "apron: the track does not leave the ring")
	for m in b.mass_log:
		var nm := String(m["name"])
		if not nm.begins_with("ground_apron"):
			continue
		var a: AABB = m["aabb"]
		var foot := Rect2(a.position.x, a.position.z, a.size.x, a.size.z)
		_want(res, not foot.intersects(extent.grow(-0.01)), "apron: %s lies inside the plan extent" % nm)
		for other in b.mass_log:
			var on := String(other["name"])
			if on == nm or on.begins_with("ground_apron") or (other["aabb"] as AABB).size.y <= 0.0:
				continue
			_want(res, not a.grow(-0.001).intersects(other["aabb"]), "apron: %s overlaps %s" % [nm, on])
	var report: Dictionary = CastleMassingCheck.new().check(spec, b)
	for f in report["failures"]:
		res.fail("apron massing: %s" % str(f))
	res.checked += 1
	var qa: Dictionary = CastleQA.new().check(spec, mesh, b)
	for f in qa["failures"]:
		res.fail("apron voxel QA: %s" % str(f))
	res.checked += 1

	# placement: bounds and footprint are the architecture's, the apron is beside them
	var request := BuildingRequest.castle(Landmarks._seed_for("bodiam", 1.0), &"edwardian", 55.0, 50.0, 18.0)
	var building: GeneratedBuilding = BrickWild.generate(request)
	_want(res, building != null and building.is_ok(), "apron: placement fixture did not generate")
	if building == null or not building.is_ok():
		return
	var without: Dictionary = BrickWild.placement(building)
	(building.spec as CastleSpec).ground_apron = true
	var with_apron: Dictionary = BrickWild.placement(building)
	_want(res, (with_apron["bounds"] as AABB).is_equal_approx(without["bounds"]),
		"apron: placement bounds grew with the apron")
	_want(res, (with_apron["footprint"] as Rect2).is_equal_approx(without["footprint"]),
		"apron: placement footprint grew with the apron")
	_want(res, with_apron.has("ground_apron") and not without.has("ground_apron"),
		"apron: placement does not report the apron beside the bounds")
	_want(res, (building.spec as CastleSpec).ground_apron, "apron: placement left the flag cleared")


## A sky castle logs braziers at every turret, a feast board and heraldry.
static func _sky(res: SuiteResult) -> void:
	for seed in [8001, 8002]:
		var spec := CastleSpec.new()
		spec.style = &"sky"
		spec.width = 80.0
		spec.length = 110.0
		spec.height = 14.0
		CastleGenerator.generate(spec, seed)
		var b := CastleBuilder.new()
		b.build(spec)
		var towers: Array[Dictionary] = CastleGeometry.sky_towers(spec)
		var braziers := 0
		var tables := 0
		var banners := 0
		var lights := 0
		for p in b.prop_log:
			var kind := String(p["kind"])
			braziers += 1 if String(p["key"]) == CastleFurnisher.BRAZIER else 0
			tables += 1 if kind == "table" else 0
			banners += 1 if kind == "banner" else 0
			lights += 1 if kind == "light" else 0
		_want(res, braziers >= towers.size(), "sky %d: %d braziers for %d turret islands" % [seed, braziers, towers.size()])
		_want(res, tables >= 1, "sky %d: no table on the rock" % seed)
		_want(res, banners >= 2, "sky %d: fewer than two banners" % seed)
		_want(res, lights >= towers.size() + 1, "sky %d: not enough light" % seed)
