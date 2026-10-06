class_name DressingSuite
extends RefCounted
## Is there anything in the churches and the castles, and can anybody move
## about in them?
##
## Sweeps the same variants the massing suites do, dresses each one, and hands
## the placements the builder logged to DressingCheck. Nothing here re-derives
## a position: it reads `builder.prop_log`, which is what the assembler will
## instantiate, so a rule that passes here is a rule the rendered building
## obeys.

## The pieces a church is not a church without.
const CHURCH_WANTS := ["altar", "pew", "light"]
## ...and a castle.
const CASTLE_WANTS := ["table", "light"]


## The bounded selector (`dressingquick`): every church style at three sizes,
## and twelve castles -- three styles across all four tiers.
const QUICK_CHURCH_INDICES := [0, 7, 14]
const QUICK_CASTLE_STYLES := [&"norman", &"edwardian", &"bavarian", &"sky"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("dressing")
	_churches(res, false)
	_castles(res, false)
	_negative_control(res)
	return res


static func run_quick() -> SuiteResult:
	var res := SuiteResult.new("dressing (quick)")
	_churches(res, true)
	_castles(res, true)
	_negative_control(res)
	return res


static func _churches(res: SuiteResult, quick: bool) -> void:
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			if quick and not i in QUICK_CHURCH_INDICES:
				continue
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var label := "church %s/%d" % [String(style), TestSweep.seed_at(i)]
			var builder := ChurchBuilder.new()
			var mesh := builder.build(spec)
			var props: Array = builder.prop_log
			var check := DressingCheck.new()
			check.check(props, _church_bounds(spec), builder.total_height, label)
			check.embedded(props, _solid_triangles(mesh), label)
			_want(check, props, CHURCH_WANTS, label)
			# the one piece of floor a church exists to be walked down
			var nave := Rect2(Vector2(-spec.width / 2.0 + 0.15, -spec.length / 2.0 + 0.15),
				Vector2(spec.width - 0.3, spec.length - 0.3))
			var altar_z: float = ChurchFurnisher.altar_z(spec)
			check.walk(props, [nave], [], Vector2(0.0, -spec.length / 2.0 + 0.6),
				Rect2(Vector2(-0.4, altar_z - 1.4), Vector2(0.8, 0.8)),
				label, "west door to the altar")
			_report(res, check)


static func _castles(res: SuiteResult, quick: bool) -> void:
	for style in CastleSweep.styles():
		if quick and not style in QUICK_CASTLE_STYLES:
			continue
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				if quick and i != 0:
					continue
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var label := "castle %s/%s/%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				var builder := CastleBuilder.new()
				var mesh := builder.build(spec)
				var props: Array = builder.prop_log
				var check := DressingCheck.new()
				# Since INT-007 the great hall and keep are furnished by planned
				# interiors, not by the shell furnisher. A table or a light in
				# either is a table or a light in the castle; a castle with
				# neither anywhere, shell or interior, still fails.
				var inside := _interior_props(builder)
				# A sky castle is dressed like the rest (EVAL-B07): braziers at the
				# foot of its turrets, a board on the rock, heraldry on the drums.
				# It owes a table and a light as every castle does; the old
				# `bare_sky` exemption is gone.
				check.check(props, CastleGeometry.plan_extent(spec),
					builder.total_height, label, inside)
				_want(check, props + inside, CASTLE_WANTS, label)
				check.embedded(props, _solid_triangles(mesh), label)
				if CastleGeometry.is_enclosed(spec):
					_walk_the_yard(check, spec, props, label)
				_report(res, check)


## From the gate, across the courtyard, to the door of everything that stands
## in it. The buildings block the floor; so does the dressing.
static func _walk_the_yard(check: DressingCheck, spec: CastleSpec, props: Array,
		label: String) -> void:
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	if bailey.size.x < 6.0 or bailey.size.y < 6.0:
		return
	var blocks: Array[Rect2] = []
	for a in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec)]:
		if a.size.x > 0.0:
			blocks.append(Rect2(Vector2(a.position.x, a.position.z),
				Vector2(a.size.x, a.size.z)))
	if CastleGeometry.is_motte(spec):
		var m: AABB = CastleGeometry.motte_aabb(spec)
		blocks.append(Rect2(Vector2(m.position.x, m.position.z),
			Vector2(m.size.x, m.size.z)))
	var from := Vector2(0.0, bailey.position.y + 0.6)
	# the middle of the yard, which everything in it opens onto
	check.walk(props, [bailey], blocks, from,
		Rect2(bailey.get_center() - Vector2(0.4, 0.4), Vector2(0.8, 0.8)),
		label, "gate to the middle of the bailey")


## The ground a church stands on: the nave and everything that grew off it.
static func _church_bounds(spec: ChurchSpec) -> Rect2:
	var out := Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))
	if spec.aisles > 0:
		var x: float = ChurchGeometry.aisle_outer_x(spec)
		out = out.merge(Rect2(Vector2(-x, -spec.length / 2.0),
			Vector2(x * 2.0, spec.length)))
	if spec.transept:
		var t: AABB = ChurchGeometry.transept_aabb(spec)
		out = out.merge(Rect2(Vector2(t.position.x, t.position.z),
			Vector2(t.size.x, t.size.z)))
	if spec.apse:
		var a: AABB = ChurchGeometry.apse_aabb(spec)
		out = out.merge(Rect2(Vector2(a.position.x, a.position.z),
			Vector2(a.size.x, a.size.z)))
	if spec.tower:
		for side in ChurchGeometry.west_tower_sides(spec):
			var tw: AABB = ChurchGeometry.tower_aabb(spec, side)
			out = out.merge(Rect2(Vector2(tw.position.x, tw.position.z),
				Vector2(tw.size.x, tw.size.z)))
	if spec.narthex:
		var n: AABB = ChurchGeometry.narthex_aabb(spec)
		out = out.merge(Rect2(Vector2(n.position.x, n.position.z),
			Vector2(n.size.x, n.size.z)))
	return out


## Counting the planned interiors must not make the wants unfailable: a castle
## with no table and no fire anywhere, shell or interior, still fails all
## three, and one whose only light is a planned interior's sconce does not.
static func _negative_control(res: SuiteResult) -> void:
	var bare := DressingCheck.new()
	_want(bare, [], CASTLE_WANTS, "control: bare castle")
	bare.check([], Rect2(Vector2(-10, -10), Vector2(20, 20)), 10.0, "control: bare castle", [])
	res.checked += 1
	if bare.failures.size() != 2 or bare.warnings.size() != 1:
		res.fail("control: a castle with no table and no fire must fail 'table' and 'light' and warn 'lit' (got %d failures, %d warnings)"
			% [bare.failures.size(), bare.warnings.size()])
	var lit := DressingCheck.new()
	lit.check([], Rect2(Vector2(-10, -10), Vector2(20, 20)), 10.0, "control: sconce",
		[{"key": "Torch_Metal", "kind": "light"}])
	res.checked += 1
	if not lit.warnings.is_empty():
		res.fail("control: an interior sconce should count as light")
	res.checked += lit.checked + bare.checked
	# A standing piece inside a block of masonry is buried; the same piece set
	# beside it, or on top of it, is not.
	var block := MassBuilder.new()
	block.begin(1)
	block.box(Vector3(2, 3, 2), Vector3(0, 1.5, 0), 0)
	var solid := _solid_triangles(block.commit())
	var cases := {"inside": [Vector3(0.3, 0.0, 0.2), true], "beside": [Vector3(2.5, 0.0, 0.0), false],
		"on top": [Vector3(0.0, 3.0, 0.0), false], "sunk": [Vector3(0.0, 2.7, 0.0), true]}
	for name in cases:
		var probe := DressingCheck.new()
		probe.embedded([PropCatalog.placement("Cauldron", cases[name][0], 0.0, 1.0, &"light")], solid, "control")
		res.checked += 1
		if probe.failures.is_empty() == bool(cases[name][1]):
			res.fail("control: a cauldron %s a block %s" % [name,
				"was not called buried" if cases[name][1] else "was called buried"])


## The solid faces of a shell: stone, trim and roof, never openings or glass.
static func _solid_triangles(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for surface in [0, 1, 2]:
		if surface < mesh.get_surface_count():
			out.append_array(HouseQA._mesh_triangles(mesh, surface))
	return out


## The furniture of the castle's planned interiors, as placements the wants
## can read: `kind` is the catalogue category, or "light" for anything the
## catalogue tags as a light. Positions are in each plan's own frame, so these
## feed only the wants and the lit rule, never the placement rules.
static func _interior_props(builder: CastleBuilder) -> Array:
	var out: Array = []
	for row in builder.interiors:
		var plan: HousePlan = row.get("plan")
		if plan == null:
			continue
		for f in plan.furniture:
			var key: String = f.key
			var kind := "light" if PropCatalog.has_tag(key, PropCatalog.LIGHT) \
				else PropCatalog.category(key)
			out.append({"key": key, "kind": kind})
	return out


## A building with none of the things that make it that kind of building has
## not been dressed, whatever else it passed.
static func _want(check: DressingCheck, props: Array, kinds: Array,
		label: String) -> void:
	for kind in kinds:
		check.checked += 1
		var found := false
		for p in props:
			if String(p.get("kind", "")) == String(kind):
				found = true
				break
		if not found:
			check.fail("%s: nothing in it is a '%s'" % [label, kind])


static func _report(res: SuiteResult, check: DressingCheck) -> void:
	res.checked += check.checked
	for f in check.failures:
		res.fail(f)
	for w in check.warnings:
		res.warn(w)
