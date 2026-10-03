class_name HouseRichSuite
extends RefCounted
## HOUSE-RICH: the rich house is a real house with its storeys articulated,
## and this suite holds both halves of that claim to account.
##
## The positive half builds rich dwellings across the canonical sizes, every
## role of the ornament vocabulary and both roof types, and requires each one
## to pass BOTH the ordinary house harness (`HouseQA`: plan, furnishing,
## walking, shell, bounds) and the rich check. A rich house that is merely a
## tall cottage would pass `HouseQA` and fail here.
##
## The negative half is the important one. Each rule is switched off in a
## subclass, one at a time, and the same check has to notice; a rule that only
## ever sees a building which satisfies it is not known to be a rule at all.

## Every role the vocabulary is made of. Each must be emitted by at least one
## fixture, or the vocabulary is only half implemented and the suite says so.
const WANTED_ROLES := [&"cornice_bed", &"cornice_corona", &"cornice_crown",
	&"string_course", &"pediment_cornice", &"pediment_face", &"pediment_rake",
	&"ridge_crown_plinth", &"ridge_crown"]

## Rich houses across the canonical house sizes, both roof types and both
## orientations, plus a deliberately small one and a deliberately large one.
const CASES := [
	{"w": 8.0, "l": 10.0, "h": 2.7, "storeys": 2, "seed": 61001},
	{"w": 9.0, "l": 13.0, "h": 2.9, "storeys": 2, "seed": 61002},
	{"w": 11.0, "l": 14.0, "h": 3.0, "storeys": 3, "seed": 61003},
	{"w": 14.0, "l": 18.0, "h": 3.1, "storeys": 3, "seed": 61004},
	{"w": 13.0, "l": 9.0, "h": 2.8, "storeys": 2, "seed": 61005},
]


# ------------------------------------------------------ the negative controls

## Each drops exactly one piece of the vocabulary and changes nothing else.
class NoCornice extends HouseBuilder:
	func _build_rich_cornice() -> void:
		pass


class NoBands extends HouseBuilder:
	func _build_rich_bands() -> void:
		pass


class NoPediments extends HouseBuilder:
	func _build_rich_pediments() -> void:
		pass


class NoCrown extends HouseBuilder:
	func _build_ridge_crown(_xf: Transform3D, _rise: float, _ridge: float) -> void:
		pass


## The one that is NOT a subclass: a cottage, built exactly as built before
## rich existed, offered to the rich check. This is the anti-stretch control,
## and it is the reason the check exists -- a house that is tall, or a house
## whose style is called rich, is not a rich house.
class NothingRemoved extends HouseBuilder:
	pass


static func run() -> SuiteResult:
	var res := SuiteResult.new("house rich")
	_positive(res)
	_ordinary_houses_stay_ordinary(res)
	_controls(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _spec(row: Dictionary) -> HouseSpec:
	var s := HouseSpec.new()
	s.style = &"rich"
	s.trade = &"none"
	s.width = float(row["w"])
	s.length = float(row["l"])
	s.height = float(row["h"])
	s.storeys = int(row["storeys"])
	return s


## UnFURNISHED on purpose, and the reason is worth stating.
##
## `hrich` is about ornament, and every ornament question is a geometry
## question. The full house harness -- the plan rules, the furnisher, the
## walker -- already runs rich, because `HouseSweep.styles()` now includes it
## and `harchetype` has a rich row at four scales. Paying for the furnisher
## search a second time here would have cost three minutes to re-prove it.
static func _plan(row: Dictionary) -> HousePlan:
	return HouseGenerator.generate(_spec(row), int(row["seed"]), false)


## A control fixture with every ornament switch FORCED on.
##
## A negative control that depends on a dice roll is not a control. The style
## row rolls `pediments` at 0.85, and a seed that rolls false makes the rule
## legitimately skip the house -- so `NoPediments` on that seed emits nothing,
## the rule owes nothing, and a broken emitter walks straight through.
static func _ornamented(row: Dictionary) -> HousePlan:
	var s := _spec(row)
	HouseGenerator.generate(s, int(row["seed"]), false)
	s.cornice = true
	s.string_courses = 2
	s.pediments = true
	s.ridge_finial = true
	s.rng.seed = s.seed
	return HousePlanner.plan(s)


static func _positive(res: SuiteResult) -> void:
	var seen_roles := {}
	var kinds := {}
	var heights := 0
	for row in CASES:
		var plan := _plan(row)
		var spec: HouseSpec = plan.spec
		var who := "rich %dx%d seed=%d storeys=%d" % [int(spec.width), int(spec.length),
			spec.seed, spec.storeys]
		kinds[spec.roof_type] = int(kinds.get(spec.roof_type, 0)) + 1
		res.checked += 1
		if spec.style != &"rich":
			res.fail("%s: generation did not keep the rich style" % who)
		if spec.storeys < 2:
			res.fail("%s: a rich house has %d storey; the style row asks for two"
				% [who, spec.storeys])
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		_expect(res, mesh.get_surface_count() == 4, "%s: bad mesh" % who)
		for role in WANTED_ROLES:
			if not builder.components(String(role)).is_empty():
				seen_roles[role] = true
		# the ordinary GEOMETRY harness, unrelaxed: component evidence, the
		# roof envelope, the exterior bound, and trim clear of the door
		for f in HouseQA.check_exterior_geometry(plan, builder):
			res.fail("%s: %s" % [who, str(f)])
		var rich: Dictionary = RichHouseCheck.new().check(plan, builder)
		for f2 in rich["failures"]:
			res.fail("%s: %s" % [who, str(f2)])
		for w in rich["warnings"]:
			res.warn("%s: %s" % [who, str(w)])
		# the component log is evidence, not a claim
		var evidence := ComponentCheck.check(builder, mesh)
		_expect(res, bool(evidence["ok"]),
			"%s: component log not backed by the mesh: %s" % [who,
				str(evidence["failures"])])
		if spec.ridge_finial:
			heights += 1
		# and the same seed builds the same house, ornament included
		var again := HouseBuilder.new()
		again.build(_plan(row))
		_expect(res, ComponentCheck.identities(again) == ComponentCheck.identities(builder),
			"%s: ornament identities changed on rebuild" % who)
	for role in WANTED_ROLES:
		_expect(res, seen_roles.has(role),
			"no fixture emitted a '%s' component" % String(role))
	_expect(res, kinds.size() >= 2, "the fixtures only ever produced roof types %s"
		% str(kinds.keys()))
	_expect(res, heights == CASES.size(),
		"only %d of %d fixtures carried a ridge crown" % [heights, CASES.size()])
	res.note("rich       %d houses, roof types %s, %d roles exercised"
		% [CASES.size(), str(kinds), WANTED_ROLES.size()])


## The promise that made this cheap: adding rich must not have moved a single
## vertex of the five styles that were already there. They are checked by
## their own emitted components -- zero of them -- rather than by a diff against
## a worktree, because a zero is the stronger and cheaper statement.
static func _ordinary_houses_stay_ordinary(res: SuiteResult) -> void:
	for style in [&"cottage", &"farmhouse", &"townhouse", &"longhall", &"witch_hut"]:
		for storeys in [1, 2]:
			var s := HouseSpec.new()
			s.style = style
			s.width = 11.0
			s.length = 13.0
			s.height = 2.7
			s.storeys = storeys
			var plan := HouseGenerator.generate(s, 61050 + storeys, false)
			var builder := HouseBuilder.new()
			builder.build(plan)
			var who := "%s/%d storeys seed=%d" % [String(style), storeys, s.seed]
			var ornament := RichHouseCheck.new()._ornament(builder)
			_expect(res, ornament.is_empty(),
				"%s: emitted %d rich ornament components" % [who, ornament.size()])
			_expect(res, not plan.spec.cornice and plan.spec.string_courses == 0
					and not plan.spec.pediments and not plan.spec.ridge_finial,
				"%s: the generator switched rich ornament on for an ordinary style" % who)
			var bounds := HouseGeometry.exterior_bounds(plan)
			var loose := HouseGeometry.spec_bounds(plan.spec)
			_expect(res, loose.encloses(bounds.grow(-0.0005)),
				"%s: spec_bounds no longer contains exterior_bounds" % who)


## Each rule, switched off once, and the check has to say so.
static func _controls(res: SuiteResult) -> void:
	var plan := _ornamented(CASES[1])
	var who := "control seed=%d" % int(plan.spec.seed)

	# the control itself must be clean, or the failures below mean nothing
	var honest := HouseBuilder.new()
	honest.build(plan)
	var clean: Array[String] = []
	clean.append_array(RichHouseCheck.new().check(plan, honest)["failures"])
	_expect(res, clean.is_empty(), "%s: the control house is not clean: %s"
		% [who, str(clean)])

	for pair in [[NoCornice, "cornice:"], [NoBands, "bands:"],
			[NoPediments, "pediment:"], [NoCrown, "crown:"]]:
		var b: HouseBuilder = pair[0].new()
		b.build(plan)
		var errors: Array = RichHouseCheck.new().check(plan, b)["failures"]
		_expect(res, _mentions(errors, String(pair[1])),
			"%s: removing the ornament escaped the %s rule: %s"
			% [who, String(pair[1]).trim_suffix(":"), str(errors)])

	# THE anti-stretch control. An ordinary cottage, offered to the rich check
	# with no mutation at all: it must be rejected, and the reason it is
	# rejected must be the density floor rather than an accident.
	var plain := HouseSpec.new()
	plain.style = &"cottage"
	plain.width = 9.0
	plain.length = 12.0
	plain.storeys = 2
	var cottage: HousePlan = HouseGenerator.generate(plain, 61002, false)
	var cottage_builder := HouseBuilder.new()
	cottage_builder.build(cottage)
	var cot: Array = RichHouseCheck.new().check(cottage, cottage_builder)["failures"]
	_expect(res, _mentions(cot, "density:"),
		"a two-storey cottage passed the rich check: %s" % str(cot))
	_expect(res, cottage_builder.components("cornice_corona").is_empty(),
		"an ordinary cottage acquired a cornice")

	# and the bound is measured, not decorative: a crown that oversails three
	# times as far as the geometry promised leaves the planned exterior.
	var wide := WideMouldings.new()
	wide.build(plan)
	var escaped: Array = RichHouseCheck.new().check(plan, wide)["failures"]
	_expect(res, _mentions(escaped, "bounds:"),
		"a cornice reaching %.1fm past the wall escaped the bound: %s"
		% [HouseGeometry.CORNICE_OUT * 3.0, str(escaped)])


## A crown and a band three times as deep as the geometry promised. The check
## must reject it on containment, which is only true because exterior_bounds
## grows by CORNICE_OUT rather than by a generous constant.
class WideMouldings extends HouseBuilder:
	func _moulding(run: Dictionary, y0: float, height: float, out: float,
			role: String, openings: Array = [], y_offset := 0.0) -> void:
		super._moulding(run, y0, height, out * 3.0, role, openings, y_offset)


static func _mentions(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line).contains(needle):
			return true
	return false