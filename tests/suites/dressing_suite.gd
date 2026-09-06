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


static func run() -> SuiteResult:
	var res := SuiteResult.new("dressing")
	_churches(res)
	_castles(res)
	return res


static func _churches(res: SuiteResult) -> void:
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var label := "church %s/%d" % [String(style), TestSweep.seed_at(i)]
			var builder := ChurchBuilder.new()
			builder.build(spec)
			var props: Array = builder.prop_log
			var check := DressingCheck.new()
			check.check(props, _church_bounds(spec), builder.total_height, label)
			_want(check, props, CHURCH_WANTS, label)
			# the one piece of floor a church exists to be walked down
			var nave := Rect2(Vector2(-spec.width / 2.0 + 0.15, -spec.length / 2.0 + 0.15),
				Vector2(spec.width - 0.3, spec.length - 0.3))
			var altar_z: float = ChurchFurnisher.altar_z(spec)
			check.walk(props, [nave], [], Vector2(0.0, -spec.length / 2.0 + 0.6),
				Rect2(Vector2(-0.4, altar_z - 1.4), Vector2(0.8, 0.8)),
				label, "west door to the altar")
			_report(res, check)


static func _castles(res: SuiteResult) -> void:
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var label := "castle %s/%s/%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				var builder := CastleBuilder.new()
				builder.build(spec)
				var props: Array = builder.prop_log
				var check := DressingCheck.new()
				check.check(props, CastleGeometry.plan_extent(spec),
					builder.total_height, label)
				_want(check, props, CASTLE_WANTS, label)
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
