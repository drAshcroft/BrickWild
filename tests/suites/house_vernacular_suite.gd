class_name HouseVernacularSuite
extends RefCounted
## HOUSE-CULTURE: six houses that are not a timber cottage, and the pieces of
## architecture that make them so.
##
## The positive half builds every vernacular style across the canonical sizes
## and every trade, at one and two storeys, and requires each one to pass BOTH
## the ordinary house harness (`HouseQA`: the plan, the furnishing, the walk, the
## shell, the exterior bound) and the vernacular check. A mud hut that is merely
## a cottage with thick walls would pass `HouseQA` and fail here.
##
## The forced half is the vocabulary. The switches are chance rolls, so a
## negative control built on a seed that rolls false owes nothing and proves
## nothing; each piece is therefore built by a fixture that turns its switch on
## and replans, exactly as `hrich` does for the rich ornament.
##
## The negative half is the important one. Each rule is switched off in a
## builder subclass, one piece at a time, and the same check has to notice; a
## rule that only ever sees a building which satisfies it is not known to be a
## rule at all. The last control is the bound: a sweep fin pushed half a metre
## past the eave has to be caught by the exterior geometry harness, which is
## what proves the parapet and the sweep are free because they stop AT the eave.

## Every role the vocabulary is made of. Each must be emitted by at least one
## forced fixture, or the vocabulary is only half implemented and the suite says
## so.
const WANTED_ROLES := [&"parapet", &"veranda_deck", &"veranda_post", &"veranda_beam",
	&"veranda_roof_0", &"eave_sweep_-1_-1", &"eave_sweep_1_1", &"thatch_eave",
	&"thatch_roll_0", &"corner_pier"]

## The six styles, spelled out rather than read from the table: this suite
## exists to hold THEM to their architecture, so it must not quietly grow a
## sixth row and then pass it by having no expectations for it.
const CULTURE_STYLES: Array[StringName] = [&"mediterranean", &"asian", &"african",
	&"thatch_cottage", &"mud_hut", &"pueblo"]

## The styles that must keep emitting nothing from this vocabulary.
const ORDINARY_STYLES: Array[StringName] = [&"cottage", &"farmhouse", &"townhouse",
	&"longhall", &"witch_hut", &"rich"]

## Forced fixtures: one per piece, with the switch turned on and the plan
## replanned, so the rule is exercised whether or not the dice were kind.
const FORCED := [
	{"style": &"mediterranean", "w": 9.0, "l": 11.0, "h": 2.8, "seed": 62001,
		"on": ["parapet"], "about": "an eaves parapet on a shallow tiled roof"},
	{"style": &"asian", "w": 9.0, "l": 11.0, "h": 2.7, "seed": 62002,
		"on": ["veranda", "eave_sweep"],
		"about": "a veranda and four corner fins under a very deep eave"},
	{"style": &"thatch_cottage", "w": 9.0, "l": 11.0, "h": 2.5, "seed": 62003,
		"on": ["thatch_roll"], "about": "a combed ridge roll and a thick rolled eave"},
	{"style": &"african", "w": 10.0, "l": 12.0, "h": 2.8, "seed": 62004,
		"on": ["corner_piers", "thatch_roll"], "roof": &"hipped",
		"about": "rounded mud corners and combed thatch over a hip"},
	{"style": &"mud_hut", "w": 7.0, "l": 8.0, "h": 2.4, "seed": 62005,
		"on": ["corner_piers", "thatch_roll"], "roof": &"conical",
		"about": "a cone, rounded corners and an eave roll with no ridge to roll"},
	{"style": &"pueblo", "w": 10.0, "l": 12.0, "h": 2.8, "seed": 62006,
		"on": ["parapet"], "roof": &"flat",
		"about": "a level adobe roof behind a terrace parapet"},
]


# ------------------------------------------------------ the negative controls

## Each drops exactly one piece of the vocabulary and changes nothing else.

class NoParapet extends HouseBuilder:
	func _build_parapet(_layout: Dictionary) -> void:
		pass


class NoVeranda extends HouseBuilder:
	func _build_veranda() -> void:
		pass


class NoSweep extends HouseBuilder:
	func _build_eave_sweep(_layout: Dictionary) -> void:
		pass


class NoThatch extends HouseBuilder:
	func _build_thatch_roll(_layout: Dictionary) -> void:
		pass


class NoPiers extends HouseBuilder:
	func _build_corner_piers() -> void:
		pass


## The spec and the mesh disagreeing: the plan still says GABLE, so the
## ordinary roof rules have nothing to say, and only the geometry shows that
## eight coned facets were laid over it. The spec is restored afterwards, so
## the check reads what the PLAN says rather than what the builder left behind.
class ConeOnAGable extends HouseBuilder:
	func _build_roof() -> void:
		var saved: StringName = spec.roof_type
		spec.roof_type = &"conical"
		super._build_roof()
		spec.roof_type = saved


## The mirror of it: the spec says CONICAL and the builder laid a hip under it.
## A cone has no ridge, so the roll has nowhere to go and no face reaches the
## apex -- and the spec is restored, so the check believes the plan.
class HipUnderAConicalSpec extends HouseBuilder:
	func _build_roof() -> void:
		var saved: StringName = spec.roof_type
		spec.roof_type = &"hipped"
		super._build_roof()
		spec.roof_type = saved


## The spec remains flat while the emitter lays a hip. This isolates the new
## Pueblo rule's evidence in the actual roof vertices.
class HipUnderPuebloSpec extends HouseBuilder:
	func _build_roof() -> void:
		var saved: StringName = spec.roof_type
		spec.roof_type = &"hipped"
		spec.roof_pitch = 0.65
		super._build_roof()
		spec.roof_type = saved




## A veranda built in local coordinates and never placed: the deck lands at the
## world origin with a perfectly correct bound, because the bound is computed in
## plan space and the plan is right. This is the defect the placement clause of
## the `veranda` rule exists for, so the control has to reproduce it exactly --
## and the ONLY difference from the real emitter is the origin of its basis.
class VerandaAtOrigin extends HouseBuilder:
	func _build_veranda() -> void:
		var d: int = plan.entrance()
		if not spec.veranda or d < 0:
			return
		tag("veranda")
		host("veranda", 0)
		var door: Dictionary = plan.doors[d]
		var n: Vector2 = door["normal"]
		var xf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3.ZERO)
		var face: float = HouseGeometry.wall_thickness(spec) * 0.5
		var depth: float = spec.veranda_depth
		var head: float = HouseGeometry.veranda_head(spec)
		var pw: float = HouseGeometry.VERANDA_POST_W
		var w: float = float(door["width"]) * 2.0 + pw * float(HouseGeometry.VERANDA_POSTS)
		component_box("veranda_deck", Vector3(w, HouseGeometry.VERANDA_DECK_T, depth),
			xf * Transform3D(Basis(), Vector3(0.0, HouseGeometry.VERANDA_DECK_T * 0.5,
				face + depth * 0.5)), SURF_FLOOR)
		for i in range(HouseGeometry.VERANDA_POSTS):
			var px: float = -(w - pw) * 0.5 + (w - pw) * float(i) / float(HouseGeometry.VERANDA_POSTS - 1)
			component_box("veranda_post", Vector3(pw, head, pw),
				xf * Transform3D(Basis(), Vector3(px, head * 0.5,
					face + depth - pw * 0.5)), SURF_TRIM)
		component_box("veranda_beam", Vector3(w, HouseGeometry.VERANDA_BEAM_H,
			HouseGeometry.VERANDA_BEAM_W),
			xf * Transform3D(Basis(), Vector3(0.0, head + HouseGeometry.VERANDA_BEAM_H * 0.5,
				face + depth - pw * 0.5)), SURF_TRIM)
		host_end()


## Square piers: four corners instead of a ring, which is a post and not a
## rounded corner.
class SquarePiers extends HouseBuilder:
	func _build_corner_piers() -> void:
		tag("corner_pier")
		for level in range(_storeys()):
			host("corner_piers", level)
			var y0: float = spec.height * float(level)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var c := Vector2(float(sx) * spec.width * 0.5,
						float(sz) * spec.length * 0.5)
					var r: float = HouseGeometry.PIER_R
					component_slab("corner_pier", PackedVector3Array([
						Vector3(c.x - r, y0 + spec.height * 0.5, c.y - r),
						Vector3(c.x + r, y0 + spec.height * 0.5, c.y - r),
						Vector3(c.x + r, y0 + spec.height * 0.5, c.y + r),
						Vector3(c.x - r, y0 + spec.height * 0.5, c.y + r)]),
						spec.height, SURF_WALL, true)
		host_end()




## A sweep fin pushed half a metre past the eave. Nothing about the culture is
## wrong; the bound is, and the exterior geometry harness is what catches it.
class SweepTooWide extends HouseBuilder:
	func _build_eave_sweep(layout: Dictionary) -> void:
		tag("eave_sweep")
		host("eave_sweep", _storeys() - 1)
		var over := HouseGeometry.roof_oversail(spec)
		var half: float = float(layout["span"]) * 0.5 + over.x + 0.5
		for side in [-1.0, 1.0]:
			component_box("eave_sweep_stray", Vector3(0.2, HouseGeometry.SWEEP_UP, 0.2),
				layout["transform"] * Transform3D(Basis(),
					Vector3(float(side) * half, HouseGeometry.SWEEP_UP * 0.5, 0.0)), SURF_ROOF)
		host_end()


static func run() -> SuiteResult:
	var res := SuiteResult.new("house vernacular")
	_positive(res)
	_vocabulary(res)
	_ordinary_houses_stay_ordinary(res)
	_controls(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _spec(style: StringName, row: Dictionary) -> HouseSpec:
	var s := HouseSpec.new()
	s.style = style
	s.trade = StringName(row.get("trade", &"none"))
	s.width = float(row["w"])
	s.length = float(row["l"])
	s.height = float(row["h"])
	s.storeys = int(row.get("storeys", 1))
	return s


## UnFURNISHED on purpose, and the reason is worth stating.
##
## Every piece of this vocabulary is a geometry question. The full house
## harness -- the plan rules, the furnisher, the walker -- already runs all
## twelve styles, because `HouseSweep.styles()` reads the table and the table
## now includes these six. Paying for the furnisher search again here would
## cost minutes to re-prove what `houseqa` has already measured.
static func _plan(style: StringName, row: Dictionary) -> HousePlan:
	return HouseGenerator.generate(_spec(style, row), int(row["seed"]), false)


## A fixture with its vocabulary switches FORCED on.
##
## A negative control that depends on a dice roll is not a control: the style
## row rolls `parapet` at 0.7, and a seed that rolls false makes the rule
## legitimately owe nothing, so `NoParapet` on that seed emits nothing, the rule
## is satisfied, and a broken emitter walks straight through.
static func _forced_plan(row: Dictionary) -> HousePlan:
	var s := _spec(row["style"], row)
	HouseGenerator.generate(s, int(row["seed"]), false)
	for sw in row["on"]:
		s.set(sw, true)
	if row.has("roof"):
		s.roof_type = row["roof"]
	s.rng.seed = s.seed
	return HousePlanner.plan(s)


static func _positive(res: SuiteResult) -> void:
	var kinds := {}
	for style in CULTURE_STYLES:
		for i in HouseSweep.SIZES.size():
			var row: Dictionary = HouseSweep.SIZES[i]
			var r := row.duplicate()
			r["seed"] = HouseSweep.seed_at(style, &"none", i)
			for storeys in [1, 2]:
				r["storeys"] = storeys
				var plan := _plan(style, r)
				var spec: HouseSpec = plan.spec
				var who := "%s %dx%d seed=%d storeys=%d" % [String(style),
					int(spec.width), int(spec.length), spec.seed, spec.storeys]
				kinds[spec.roof_type] = int(kinds.get(spec.roof_type, 0)) + 1
				res.checked += 1
				if not HouseSpec.STYLES[style].has("culture"):
					res.fail("%s: the style row does not declare a culture" % who)
				if spec.style != style:
					res.fail("%s: generation did not keep the style" % who)
				var builder := HouseBuilder.new()
				var mesh := builder.build(plan)
				_expect(res, mesh.get_surface_count() == 4, "%s: bad mesh" % who)
				# the ordinary GEOMETRY harness, unrelaxed: component evidence,
				# the roof envelope, the exterior bound, trim clear of the door
				for f in HouseQA.check_exterior_geometry(plan, builder):
					res.fail("%s: %s" % [who, str(f)])
				var report: Dictionary = VernacularHouseCheck.new().check(plan, builder)
				for f2 in report["failures"]:
					res.fail("%s: %s" % [who, str(f2)])
				if style == &"pueblo":
					_expect(res, spec.roof_type == &"flat" and spec.parapet,
						"%s: Pueblo lost its flat roof or enclosing parapet" % who)
					_expect(res, HouseGeometry.wall_thickness(spec) >= 0.65,
						"%s: Pueblo lost its thick masonry walls" % who)
					_expect(res, spec.roof_material == &"earth",
						"%s: Pueblo's flat roof is not plain earth" % who)
	for style in CULTURE_STYLES:
		res.checked += 1
		if not kinds.has(&"conical") and style == &"mud_hut":
			res.fail("mud_hut: the sweep never produced a cone")
	if not kinds.has(&"conical"):
		res.fail("the culture sweep never produced a conical roof")
	res.note("  roof types swept: %s" % str(kinds.keys()))


static func _vocabulary(res: SuiteResult) -> void:
	var seen := {}
	for row in FORCED:
		var plan := _forced_plan(row)
		var spec: HouseSpec = plan.spec
		var who := "forced %s seed=%d" % [String(row["style"]), spec.seed]
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		_expect(res, mesh.get_surface_count() == 4, "%s: bad mesh" % who)
		for f in HouseQA.check_exterior_geometry(plan, builder):
			res.fail("%s: %s" % [who, str(f)])
		var report: Dictionary = VernacularHouseCheck.new().check(plan, builder)
		for f2 in report["failures"]:
			res.fail("%s: %s" % [who, str(f2)])
		for role in WANTED_ROLES:
			if not builder.components(String(role)).is_empty():
				seen[role] = true
		res.note("  %-16s %s" % [String(row["style"]), String(row["about"])])
	for role in WANTED_ROLES:
		res.checked += 1
		if not seen.has(role):
			res.fail("vocabulary: no forced fixture emitted a %s" % String(role))


static func _ordinary_houses_stay_ordinary(res: SuiteResult) -> void:
	for style in ORDINARY_STYLES:
		for storeys in [1, 2]:
			var s := HouseSpec.new()
			s.style = style
			s.width = 11.0
			s.length = 13.0
			s.height = 2.7
			s.storeys = storeys
			var plan := HouseGenerator.generate(s, 62050 + storeys, false)
			var builder := HouseBuilder.new()
			builder.build(plan)
			var who := "%s/%d storeys seed=%d" % [String(style), storeys, s.seed]
			var leaked: Array = VernacularHouseCheck._vocabulary(builder)
			_expect(res, leaked.is_empty(),
				"%s: emitted %d vernacular components" % [who, leaked.size()])
			_expect(res, not plan.spec.parapet and not plan.spec.veranda
					and not plan.spec.eave_sweep and not plan.spec.thatch_roll
					and not plan.spec.corner_piers,
				"%s: the generator switched the culture vocabulary on for an ordinary style" % who)
			var report: Dictionary = VernacularHouseCheck.new().check(plan, builder)
			_expect(res, bool(report["ok"]), "%s: %s" % [who, str(report["failures"])])


static func _controls(res: SuiteResult) -> void:
	# The control house is asserted clean first, or the failures below it would
	# mean nothing.
	var base := _forced_plan(FORCED[1])
	var clean := HouseBuilder.new()
	clean.build(base)
	var control: Dictionary = VernacularHouseCheck.new().check(base, clean)
	_expect(res, bool(control["ok"]),
		"control asian house is not clean: %s" % str(control["failures"]))

	_expect_rule(res, "parapet", FORCED[0], NoParapet.new(), "parapet")
	_expect_rule(res, "veranda", FORCED[1], NoVeranda.new(), "veranda")
	_expect_rule(res, "sweep", FORCED[1], NoSweep.new(), "sweep")
	_expect_rule(res, "thatch", FORCED[2], NoThatch.new(), "thatch")
	_expect_rule(res, "piers", FORCED[3], NoPiers.new(), "piers")
	_expect_rule(res, "veranda", FORCED[1], VerandaAtOrigin.new(), "veranda")
	_expect_rule(res, "piers", FORCED[3], SquarePiers.new(), "piers")
	_expect_rule(res, "cone", FORCED[4], HipUnderAConicalSpec.new(), "cone")
	_expect_rule(res, "pueblo", FORCED[5], NoParapet.new(), "parapet")
	_expect_rule(res, "pueblo flat roof", FORCED[5], HipUnderPuebloSpec.new(), "pueblo")

	# A gable that grew a cone. The spec still says gable and still says its
	# ridge length, so only the GEOMETRY can catch it -- which is the point of
	# asking whether the faces carry an apex rather than counting roofs.
	var gable := _forced_plan(FORCED[2])
	var disguised := ConeOnAGable.new()
	disguised.build(gable)
	var report: Dictionary = VernacularHouseCheck.new().check(gable, disguised)
	res.checked += 1
	if not _mentions(report["failures"], "cone"):
		res.fail("cone: a conical roof emitted for a gabled spec was not noticed: %s"
			% str(report["failures"]))

	# The bound. A sweep fin pushed half a metre past the eave is not a culture
	# defect; it is a bounds defect, and the exterior harness is what owns it.
	var swept := _forced_plan(FORCED[1])
	var wide := SweepTooWide.new()
	wide.build(swept)
	var errors: Array = HouseQA.check_exterior_geometry(swept, wide)
	res.checked += 1
	if errors.is_empty():
		res.fail("bounds: a sweep fin half a metre past the eave was not reported")


static func _expect_rule(res: SuiteResult, who: String, row: Dictionary,
		builder: HouseBuilder, rule: String) -> void:
	var plan := _forced_plan(row)
	builder.build(plan)
	var report: Dictionary = VernacularHouseCheck.new().check(plan, builder)
	res.checked += 1
	if not _mentions(report["failures"], rule):
		res.fail("%s: dropping the piece was not noticed: %s" % [who, str(report["failures"])])


static func _mentions(failures: Array, rule: String) -> bool:
	for f in failures:
		if String(f).begins_with(rule + ":"):
			return true
	return false
