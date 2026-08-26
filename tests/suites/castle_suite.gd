class_name CastleSuite
extends RefCounted
## 6. Contract: user inputs survive generation, the footprint picks the right
##    KIND of building, meshes are well formed, and the same seed rebuilds the
##    identical fortification.
##
## The tier assertion is the one that matters most here. "Small is a house,
## huge is a fortress" is the whole premise of this generator, so it is checked
## against CastleSpec.tier_for rather than against whatever the generator
## happened to feel like.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle")
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var row: Dictionary = CastleSweep.SIZES[tier][i]
				var sd: int = CastleSweep.seed_at(tier, i)
				var where := "style=%s tier=%s seed=%d" % [String(style), String(tier), sd]
				res.checked += 1

				if spec.style != style or not is_equal_approx(spec.width, float(row["w"])) \
						or not is_equal_approx(spec.length, float(row["l"])) \
						or not is_equal_approx(spec.height, float(row["h"])):
					res.fail("user inputs mutated, " + where)
					continue
				if spec.tier != tier:
					res.fail("%s: a %.0f x %.0fm site generated as a %s, not a %s"
						% [where, spec.width, spec.length, String(spec.tier), String(tier)])
					continue

				var builder := CastleBuilder.new()
				var before := _fingerprint(spec)
				var mesh: ArrayMesh = builder.build(spec)
				# build() must be a pure function of its spec
				if _fingerprint(spec) != before:
					res.fail("build() mutated its spec, " + where)
				if mesh == null or mesh.get_surface_count() != 4:
					res.fail("bad mesh, " + where)
					continue
				var verts := 0
				for s in range(mesh.get_surface_count()):
					verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
						as PackedVector3Array).size()
				if verts < 100:
					res.fail("too few verts (%d), %s" % [verts, where])
				if builder.mass_log.is_empty():
					res.fail("no structural masses logged, " + where)

	# determinism: same seed, same geometry
	var a := CastleSpec.new(); a.style = &"edwardian"; a.width = 60.0; a.length = 90.0
	var b := CastleSpec.new(); b.style = &"edwardian"; b.width = 60.0; b.length = 90.0
	CastleGenerator.generate(a, 4242)
	CastleGenerator.generate(b, 4242)
	res.checked += 1
	var ma: PackedVector3Array = CastleBuilder.new().build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mb: PackedVector3Array = CastleBuilder.new().build(b).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ma != mb:
		res.fail("same seed produced different geometry")

	# idempotence: building the same spec twice must not drift
	var c: CastleSpec = CastleSweep.spec_at(&"norman", &"castle", 1)
	res.checked += 1
	var bb := CastleBuilder.new()
	var m1: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var m2: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if m1 != m2:
		res.fail("rebuilding the same spec produced different geometry")

	# the tier rule itself, at the boundaries it is defined by
	res.checked += 1
	var bands := [[10.0, 10.0, &"house"], [20.0, 20.0, &"manor"],
		[50.0, 50.0, &"castle"], [120.0, 120.0, &"fortress"]]
	for band in bands:
		var got: StringName = CastleSpec.tier_for(band[0], band[1])
		if got != band[2]:
			res.fail("tier_for(%.0f, %.0f) = %s, expected %s"
				% [band[0], band[1], String(got), String(band[2])])
	return res


## Everything about a spec the builder could plausibly rewrite.
static func _fingerprint(spec: CastleSpec) -> Array:
	return [spec.tier, spec.width, spec.length, spec.height, spec.wall_thickness,
		spec.tower_size, spec.tower_height, spec.side_towers, spec.corner_towers,
		spec.gate_width, spec.gate_depth, spec.inner_ward, spec.ward_gap,
		spec.keep, spec.keep_w, spec.keep_l, spec.keep_height,
		spec.hall, spec.hall_w, spec.hall_l, spec.chapel, spec.wings,
		spec.courtyard, spec.chimneys]
