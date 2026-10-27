extends RefCounted
## CASTLE-STYLE-IDENTITY: norman, edwardian and elven castles must differ in
## LAYOUT, not just in colour. A short checkable list of traits per style
## (plan shape, ring count, tower form, gate towers); concept boards are
## guides, not targets. Walked at the castle default site, seeds 1..SEEDS.
##
##   norman     rect / motte-and-bailey / bergfried, never a polygon; SQUARE
##              towers; ONE ring; a bowed edge never
##   edwardian  ROUND towers; TWO rings (concentric) wherever two fit; twin-
##              towered gatehouse on most seeds
##   elven      always a bowed (curved_edges) POLYGON of 6..8 sides; ONE ring;
##              round towers; no gate towers, no battlements

const SEEDS := 8
const SITE := Vector3(55.0, 50.0, 18.0)
const RING_PLANS := [&"rect", &"polygon"]


static func run() -> SuiteResult:
	var result := SuiteResult.new("castle style identity")
	var specs := {}
	for style in [&"norman", &"edwardian", &"elven"]:
		var row: Array = []
		for sd in range(1, SEEDS + 1):
			row.append(_spec(style, sd))
		specs[style] = row
	_report(result, verdict(specs), "real castles")
	result.checked += 1
	# the seed-1 walk: three styles, three distinct layout signatures
	var sigs := {}
	for style in specs:
		sigs[style] = signature(specs[style][0])
	if sigs[&"edwardian"] == sigs[&"elven"] or sigs[&"norman"] == sigs[&"edwardian"] \
			or sigs[&"norman"] == sigs[&"elven"]:
		result.fail("seed 1 layouts collapse: %s" % [sigs])
	# negative controls: a mutated set must be refused
	var flat := _mutated(specs, &"edwardian", func(s): s.inner_ward = false)
	_expect_refused(result, flat, "edwardian with one ring")
	var straight := _mutated(specs, &"elven", func(s):
		s.curved_edges = false; s.plan_kind = &"rect")
	_expect_refused(result, straight, "elven with straight rect curtain")
	var round := _mutated(specs, &"norman", func(s): s.tower_shape = &"round")
	_expect_refused(result, round, "norman with round towers")
	return result


static func signature(spec: CastleSpec) -> String:
	return "%s|rings=%d|towers=%s|bowed=%s|gatetowers=%s" % [spec.plan_kind,
		2 if spec.inner_ward else 1, spec.tower_shape, spec.curved_edges,
		spec.gate_towers]


## The failures for a {style: [CastleSpec]} set; empty when each style shows
## its traits and no two styles share a layout.
static func verdict(specs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var concentric := 0
	var edw_ring_plans := 0
	var edw_gates := 0
	for s: CastleSpec in specs[&"norman"]:
		if s.plan_kind in [&"polygon", &"terraced"] or s.curved_edges:
			out.append("norman seed %d is a %s" % [s.seed, s.plan_kind])
		if s.tower_shape != &"square":
			out.append("norman seed %d has %s towers" % [s.seed, s.tower_shape])
		if s.inner_ward:
			out.append("norman seed %d is concentric at the castle tier" % s.seed)
	for s: CastleSpec in specs[&"edwardian"]:
		if s.tower_shape != &"round":
			out.append("edwardian seed %d has %s towers" % [s.seed, s.tower_shape])
		if s.plan_kind in RING_PLANS:
			edw_ring_plans += 1
			if s.inner_ward:
				concentric += 1
		if s.gate_towers:
			edw_gates += 1
	if edw_ring_plans > 0 and concentric < edw_ring_plans:
		out.append("edwardian is concentric on %d of %d ringed seeds"
			% [concentric, edw_ring_plans])
	if concentric == 0:
		out.append("edwardian never shows two rings")
	if edw_gates * 2 < specs[&"edwardian"].size():
		out.append("edwardian twin-towered gate on only %d seeds" % edw_gates)
	for s: CastleSpec in specs[&"elven"]:
		if s.plan_kind != &"polygon" or not s.curved_edges or s.sides < 6 or s.sides > 8:
			out.append("elven seed %d is %s/%d sides, bowed=%s"
				% [s.seed, s.plan_kind, s.sides, s.curved_edges])
		if s.inner_ward:
			out.append("elven seed %d has two rings" % s.seed)
		if s.tower_shape != &"round" or s.gate_towers or s.battlements:
			out.append("elven seed %d is fortified like a castle" % s.seed)
	return out


static func _spec(style: StringName, sd: int) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = style
	spec.width = SITE.x
	spec.length = SITE.y
	spec.height = SITE.z
	CastleGenerator.generate(spec, sd)
	return spec


static func _mutated(specs: Dictionary, style: StringName, change: Callable) -> Dictionary:
	var out := specs.duplicate()
	var row: Array = []
	for sd in range(1, SEEDS + 1):
		var s := _spec(style, sd)
		change.call(s)
		row.append(s)
	out[style] = row
	return out


static func _expect_refused(result: SuiteResult, specs: Dictionary, label: String) -> void:
	result.checked += 1
	if verdict(specs).is_empty():
		result.fail("negative control not refused: %s" % label)


static func _report(result: SuiteResult, failures: Array[String], label: String) -> void:
	result.checked += 1
	for f in failures:
		result.fail("%s: %s" % [label, f])
