extends RefCounted
## The bridge family's contract, and the things `BridgeCheck` cannot see.
##
## Every kind, every mobile mechanism, three spans and three seeds, plus the
## two build contracts: a bridge is a pure function of its spec, and its feet
## land in the ground its own geometry describes.

## The rows. A missing name falls back silently inside the generator, so a
## sweep over the table is the only thing that notices a kind that stopped
## existing.
const KINDS: Array[StringName] = [&"stone", &"covered", &"rope", &"mobile"]
const MOTIONS: Array[StringName] = [&"lift", &"swing", &"pontoon", &"drawbridge"]

## Short enough to be a footbridge, long enough to need piers, long enough to
## be an engineering work. All three are the SAME bridge at three sizes, which
## is the only claim worth sweeping.
const SPANS := [8.0, 26.0, 140.0]
const WIDTHS := [2.0, 5.0, 9.0]
const SEEDS := 3
## Above this a bridge cannot be built by a village, and the envelope fit is
## working harder than the geometry.
const TRI_BUDGET := 90000


static func run() -> SuiteResult:
	var res := SuiteResult.new("bridges")
	for kind in KINDS:
		for i in range(SPANS.size()):
			_sweep(res, kind, SPANS[i], WIDTHS[i], i)
	for motion in MOTIONS:
		_motion(res, motion)
	_purity(res)
	_feet(res)
	_variety(res)
	return res


static func _sweep(res: SuiteResult, kind: StringName, span: float, width: float,
		i: int) -> void:
	for k in range(SEEDS):
		var spec := BridgeAssembler.showcase(kind, 5100 + k * 37)
		spec.span = span
		spec.width = width
		spec.deck_height = maxf(span * 0.09, 1.4)
		spec.bank_height = spec.deck_height
		spec.bank_run = span * 0.30
		BridgeGenerator.generate(spec, 5100 + k * 37)
		# A kind that silently fell back to another would render as something
		# that passes, which is how a suite that proves nothing is written.
		_expect(res, spec.kind == kind, "%s fell back to %s at span %.0f"
			% [kind, spec.kind, span])
		var builder := BridgeBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var report: Dictionary = BridgeCheck.new().check(spec, mesh, builder)
		if not report["ok"]:
			for f in report["failures"]:
				res.fail("%s span=%.0f seed=%d -- %s" % [kind, span, k, f])
		res.checked += 1
		for w in report["warnings"]:
			res.warn("%s span=%.0f -- %s" % [kind, span, w])
		var tris: int = int(report["stats"].get("tris", 0))
		_expect(res, tris <= TRI_BUDGET,
			"%s span=%.0f costs %d triangles; a village needs a hundred of these"
			% [kind, span, tris])
		res.note("%s span=%.0f w=%.1f: %d tris, %d supports, %d members, %.1f m of channel"
			% [kind, span, width, tris, spec.piers.size(), spec.members.size(),
				float(report["stats"].get("channel", 0.0))])


## Each mechanism on its own, at the size it makes sense at.
static func _motion(res: SuiteResult, motion: StringName) -> void:
	var spec := BridgeAssembler.showcase(&"mobile", 5300)
	spec.motion = motion
	spec.span = 52.0
	spec.deck_height = 5.0
	spec.bank_height = 5.0
	BridgeGenerator.generate(spec, 5300)
	_expect(res, spec.motion == motion, "mobile/%s fell back to %s"
		% [motion, spec.motion])
	var builder := BridgeBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var report: Dictionary = BridgeCheck.new().check(spec, mesh, builder)
	if not report["ok"]:
		for f in report["failures"]:
			res.fail("mobile/%s -- %s" % [motion, f])
	res.checked += 1
	res.note("mobile/%s: %d tris, travels %.1f m"
		% [motion, int(report["stats"].get("tris", 0)), spec.travel])


## The build contract. Two builds of one spec produce identical vertex arrays,
## and a reused builder does not accumulate between calls.
static func _purity(res: SuiteResult) -> void:
	for kind in KINDS:
		var spec := BridgeAssembler.showcase(kind, 4242)
		BridgeGenerator.generate(spec, 4242)
		var a: ArrayMesh = BridgeBuilder.new().build(spec)
		var b: ArrayMesh = BridgeBuilder.new().build(spec)
		_expect(res, a.get_surface_count() == b.get_surface_count(),
			"%s: two builds disagreed on the surface count" % kind)
		for s in range(a.get_surface_count()):
			_expect(res, a.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					== b.surface_get_arrays(s)[Mesh.ARRAY_VERTEX],
				"%s surface %d: two builds of one spec differed" % [kind, s])
		var reused := BridgeBuilder.new()
		reused.build(spec)
		var first: int = reused.deck_log.size()
		reused.build(spec)
		_expect(res, reused.deck_log.size() == first,
			"%s: a reused builder accumulated deck (%d then %d)"
			% [kind, first, reused.deck_log.size()])
		var n1: int = reused.pier_log.size()
		_expect(res, n1 > 0, "%s logged no piers" % kind)


## The one contract this family has that no other does: the feet land in the
## ground, and the ground is `bank_height_at`. An abutment whose bottom is above
## the bank it is drawn against is a bridge hovering over a river, and it is
## invisible in a render because the site is built from the same function.
static func _feet(res: SuiteResult) -> void:
	for kind in KINDS:
		for span in SPANS:
			for k in range(2):
				var spec := BridgeAssembler.showcase(kind, 6000 + k * 53)
				spec.span = span
				spec.deck_height = maxf(span * 0.09, 1.4)
				spec.bank_height = spec.deck_height
				spec.bank_run = span * 0.30
				BridgeGenerator.generate(spec, 6000 + k * 53)
				var builder := BridgeBuilder.new()
				builder.build(spec)
				var ends := 0
				for p in builder.pier_log:
					if p["kind"] != &"abutment":
						continue
					ends += 1
					var ground: float = BridgeGeometry.bank_height_at(spec, float(p["x"]))
					_expect(res, float(p["bottom"]) <= ground - 0.1,
						"%s span=%.0f: the abutment at x=%.1f stops at %.2f m and the bank is at %.2f"
						% [kind, span, float(p["x"]), float(p["bottom"]), ground])
				_expect(res, ends == 2, "%s span=%.0f has %d abutments"
					% [kind, span, ends])


## A stand of bridges is not a stamp: six seeds of one kind and size give six
## different structures. Measured on a positional CHECKSUM of the vertices, not
## on a triangle count -- a pier moved forty centimetres changes where
## everything is and changes nothing about how many triangles there are, and
## keying on counts called six seeds of a stone bridge one bridge.
##
## The bar is FOUR of six, and the reason is that two of the four kinds vary
## over a SMALL DISCRETE SET rather than continuously. A covered bridge varies
## in its bay count, and a 30 m one has four, five or six bays and no more; a
## mobile bridge varies in its mechanism, and there are four of those. Two
## seeds landing on the same one is not a stamp, it is the size of the set. The
## kind that varies CONTINUOUSLY is the stone bridge, whose pier spacing is
## jittered by the seed, and that one does give six of six.
static func _variety(res: SuiteResult) -> void:
	for kind in KINDS:
		var seen: Dictionary = {}
		for k in range(6):
			var spec := BridgeAssembler.showcase(kind, 7000 + k * 131)
			# `mobile` varies by MECHANISM, not by seed, and asking a seed sweep
			# of it for variation is asking the wrong question: a lift bridge is
			# two towers and a beam and it is the same two towers and beam at
			# every seed. Its six variants are the four motions plus the two
			# seed-driven reaches inside each, so the sweep takes both.
			if kind == &"mobile":
				spec.motion = MOTIONS[k % MOTIONS.size()]
			BridgeGenerator.generate(spec, 7000 + k * 131)
			var mesh: ArrayMesh = BridgeBuilder.new().build(spec)
			var m: Dictionary = BridgeCheck.measure(mesh)
			seen["%d/%d" % [int(m["tris"]), int(m["checksum"])]] = true
		res.checked += 1
		res.note("%s stand: %d of 6 seeds distinct" % [kind, seen.size()])
		if seen.size() < 4:
			res.fail("%s: only %d of 6 seeds built a different bridge; that is a stamp"
				% [kind, seen.size()])


static func _expect(res: SuiteResult, ok: bool, why: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(why)
