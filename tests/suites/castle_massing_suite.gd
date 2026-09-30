class_name CastleMassingSuite
extends RefCounted
## 7. Structural correctness of a castle: no gaps, no undesigned overlap, sizes
##    match the spec, and a walled tier is actually walled.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle massing")
	for tier in CastleSweep.tiers():
		var defects := 0
		var variants := 0
		for style in CastleSweep.styles():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var builder := CastleBuilder.new()
				builder.build(spec)
				var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
				res.checked += 1
				variants += 1
				var who := "%s %s seed=%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				if not rep["ok"]:
					defects += 1
					for f in rep["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in rep["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
		res.note("%-10s %2d/%d variants with defects" % [String(tier), defects, variants])
	_great_tower_fixture(res)
	_chapel_apse_fixture(res)
	_tower_house_fixtures(res)
	_ridge_fixture(res)
	_motte_fixture(res)
	_bailey_fixture(res)
	_fantasy_fixtures(res)
	var facade: SuiteResult = preload("res://tests/suites/castle_facade_suite.gd").run()
	res.checked += facade.checked
	res.failures.append_array(facade.failures)
	return res


## The motte rule, shown to fire (CAS-005): a motte and bailey passes, and
## the same castle with its shell keep slid off the mound fails.
static func _motte_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 90.0
	spec.length = 110.0
	spec.height = 12.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8806)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	if not CastleGeometry.is_motte(spec):
		res.fail("motte fixture: plan_override = motte_bailey did not hold")
		return
	for f in CastleMassingCheck.new().check(spec, builder)["failures"]:
		res.fail("motte fixture (should pass): %s" % str(f))
	for m in builder.mass_log:
		if m["name"] == "keep_shell":
			var a: AABB = m["aabb"]
			m["aabb"] = AABB(a.position + Vector3(CastleGeometry.motte_top_radius(spec), 0.0, 0.0), a.size)
	res.checked += 1
	var saw := false
	for f2 in CastleMassingCheck.new().check(spec, builder)["failures"]:
		if str(f2).begins_with("motte:"):
			saw = true
	if not saw:
		res.fail("motte fixture: a keep off the top of the mound was not reported")


## The ridge rule, shown to fire (CAS-007): a ridge castle passes, and the
## same castle with a tower struck from its log, or a curtain smuggled in,
## fails.
static func _ridge_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"bavarian"
	spec.width = 120.0
	spec.length = 40.0
	spec.height = 20.0
	spec.plan_override = &"ridge"
	CastleGenerator.generate(spec, 8805)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	if spec.plan_kind != &"ridge":
		res.fail("ridge fixture: plan_override = ridge did not hold (%s)" % String(spec.plan_kind))
		return
	for f in CastleMassingCheck.new().check(spec, builder)["failures"]:
		res.fail("ridge fixture (should pass): %s" % str(f))
	var kept: Array[Dictionary] = []
	for m in builder.mass_log:
		if m["name"] != "tower_0_corner_1":
			kept.append(m)
	builder.mass_log = kept
	res.checked += 1
	var saw := false
	for f2 in CastleMassingCheck.new().check(spec, builder)["failures"]:
		if str(f2).begins_with("ridge:"):
			saw = true
	if not saw:
		res.fail("ridge fixture: a spine vertex with no tower was not reported")


## The tower house rules, each shown to fire (CAS-006): a tower built as the
## generator means it passes TowerCheck and the massing check, and then its
## log is tampered with one rule at a time.
static func _tower_house_fixtures(res: SuiteResult) -> void:
	var spec := _tower_house_spec(8.0, 8.0, 45.0, 8803)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	for f in TowerCheck.new().check(spec, builder)["failures"]:
		res.fail("tower house fixture (should pass): %s" % str(f))
	for f2 in CastleMassingCheck.new().check(spec, builder)["failures"]:
		res.fail("tower house fixture (massing, should pass): %s" % str(f2))
	# slender: the shaft cut down to twice its width
	var squat := CastleBuilder.new()
	squat.build(spec)
	for m in squat.mass_log:
		if m["name"] == "hall":
			var a: AABB = m["aabb"]
			m["aabb"] = AABB(a.position, Vector3(a.size.x, a.size.x * 2.0, a.size.z))
	_expect_rule(res, "slender", TowerCheck.new().check(spec, squat))
	# lift: a window dropped to the ground storey
	var low := CastleBuilder.new()
	low.build(spec)
	var moved_window := false
	for p in low.part_log:
		# Planned tower-house openings retain their host tag rather than the
		# legacy "window" tag. TowerCheck reads both from this same part log.
		if p["kind"] == "window":
			var pos: Vector3 = p["pos"]
			p["pos"] = Vector3(pos.x, 1.0, pos.z)
			moved_window = true
			break
	res.checked += 1
	if not moved_window:
		res.fail("tower house fixture: no emitted window was available to lower")
	else:
		_expect_rule(res, "lift", TowerCheck.new().check(spec, low))
	# foot: the ground storey no wider than the top
	var thin := CastleBuilder.new()
	thin.build(spec)
	var top_w := 0.0
	for m2 in thin.mass_log:
		if String(m2["name"]).begins_with("storey_"):
			top_w = (m2["aabb"] as AABB).size.x
	for m3 in thin.mass_log:
		if m3["name"] == "storey_0":
			var a3: AABB = m3["aabb"]
			m3["aabb"] = AABB(Vector3(a3.position.x + (a3.size.x - top_w) / 2.0, a3.position.y,
				a3.position.z + (a3.size.z - top_w) / 2.0), Vector3(top_w, a3.size.y, top_w))
	_expect_rule(res, "foot", TowerCheck.new().check(spec, thin))
	# and a Scottish tower is allowed to be broader
	var broad := _tower_house_spec(14.0, 12.0, 34.0, 8804)
	var bb := CastleBuilder.new()
	bb.build(broad)
	res.checked += 1
	if broad.tower_type != &"scottish":
		res.fail("tower house fixture: a 14 x 12 x 34 tower should be the Scottish type, got %s" % String(broad.tower_type))
	for f3 in TowerCheck.new().check(broad, bb)["failures"]:
		res.fail("tower house fixture (scottish, should pass): %s" % str(f3))


static func _tower_house_spec(w: float, l: float, h: float, seed: int) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = w
	spec.length = l
	spec.height = h
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, seed)
	return spec


static func _expect_rule(res: SuiteResult, rule: String, rep: Dictionary) -> void:
	res.checked += 1
	for f in rep["failures"]:
		if str(f).begins_with(rule + ":"):
			return
	res.fail("tower house fixture: the %s rule did not fire on a tower built to break it: %s"
		% [rule, str(rep["failures"])])


## The great_tower rule, shown to fire (CAS-002): a castle with a great tower
## passes, and the same castle with its towers cut down to one height fails.
static func _great_tower_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 70.0
	spec.length = 95.0
	spec.height = 16.0
	CastleGenerator.generate(spec, 8801)
	spec.great_tower = 1
	spec.great_tower_scale = 1.8
	CastleGenerator.refit(spec)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
	for f in rep["failures"]:
		res.fail("great tower fixture (should pass): %s" % str(f))
	var plain: float = CastleGeometry.tower_height(spec, 0)
	for m in builder.mass_log:
		if String(m["name"]).begins_with("tower_0_"):
			var a: AABB = m["aabb"]
			m["aabb"] = AABB(a.position, Vector3(a.size.x, plain, a.size.z))
	res.checked += 1
	var rep2: Dictionary = CastleMassingCheck.new().check(spec, builder)
	var saw := false
	for f2 in rep2["failures"]:
		if str(f2).begins_with("great_tower:"):
			saw = true
	if not saw:
		res.fail("great tower fixture: towers all of one height were not reported")


## The chapel_apse rule, shown to fire (CAS-003): a castle with a chapel has
## its apse, and the same castle with the apse struck from the log fails.
static func _chapel_apse_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 80.0
	spec.length = 120.0
	spec.height = 16.0
	CastleGenerator.generate(spec, 8802)
	spec.hall = true
	spec.chapel = true
	CastleGenerator.refit(spec)
	if not spec.chapel:
		res.warn("chapel apse fixture: the bailey would not hold a chapel")
		return
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
	for f in rep["failures"]:
		res.fail("chapel apse fixture (should pass): %s" % str(f))
	var kept: Array[Dictionary] = []
	for m in builder.mass_log:
		if m["name"] != "apse":
			kept.append(m)
	builder.mass_log = kept
	res.checked += 1
	var rep2: Dictionary = CastleMassingCheck.new().check(spec, builder)
	if not "chapel_apse: the chapel has no apse" in rep2["failures"]:
		res.fail("chapel apse fixture: a chapel without its apse was not reported")

## The bailey_clear rule, shown to fire (CAS-012).
##
## A castle is generated properly -- the rule must be silent on it -- and then
## one yard building is shoved sideways into the curtain by hand. A rule that
## does not notice a stable built through the wall is measuring nothing.
static func _bailey_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	var yards: Array[Dictionary] = []
	for m in builder.mass_log:
		if String(m["name"]).begins_with("yard_"):
			yards.append(m)
	if yards.is_empty():
		res.fail("bailey fixture: the castle put nothing in its yard to test with")
		return
	for f in CastleMassingCheck.new().check(spec, builder)["failures"]:
		if String(f).begins_with("bailey_clear:"):
			res.fail("bailey fixture: a properly laid out bailey was reported: %s" % str(f))

	# now shove one building out through the curtain
	res.checked += 1
	var moved := CastleBuilder.new()
	moved.build(spec)
	for i in range(moved.mass_log.size()):
		if not String(moved.mass_log[i]["name"]).begins_with("yard_"):
			continue
		var a: AABB = moved.mass_log[i]["aabb"]
		var yard: Rect2 = CastleGeometry.bailey_rect(spec)
		a.position.x = yard.end.x + 1.0
		moved.mass_log[i]["aabb"] = a
		break
	var caught := false
	for f2 in CastleMassingCheck.new().check(spec, moved)["failures"]:
		if String(f2).begins_with("bailey_clear:"):
			caught = true
	if not caught:
		res.fail("bailey fixture: a yard building pushed out through the curtain was not caught")

	# and one parked across the way in from the gate
	res.checked += 1
	var blocked := CastleBuilder.new()
	blocked.build(spec)
	for j in range(blocked.mass_log.size()):
		if not String(blocked.mass_log[j]["name"]).begins_with("yard_"):
			continue
		var b: AABB = blocked.mass_log[j]["aabb"]
		b.position.x = -b.size.x / 2.0
		blocked.mass_log[j]["aabb"] = b
		break
	var caught2 := false
	for f3 in CastleMassingCheck.new().check(spec, blocked)["failures"]:
		if String(f3).begins_with("bailey_clear:") and String(f3).contains("way from the gate"):
			caught2 = true
	if not caught2:
		res.fail("bailey fixture: a yard building parked across the gate axis was not caught")


## CAS-012's three silhouettes, kept small and explicit so their defining
## geometry cannot disappear while the broad sweep still happens to be green.
static func _fantasy_fixtures(res: SuiteResult) -> void:
	var wizard := CastleSpec.new()
	wizard.style = &"wizard"
	wizard.width = 9.0
	wizard.length = 9.0
	wizard.height = 42.0
	wizard.tier_override = &"house"
	CastleGenerator.generate(wizard, 12012)
	var wb := CastleBuilder.new()
	wb.build(wizard)
	res.checked += 1
	if wizard.plan_kind != &"tower_house" or wizard.tower_storeys < 4 \
			or wizard.tower_storeys > 6 or wizard.tower_roof != &"cone":
		res.fail("fantasy wizard: not a 4-6 storey cone-capped tower house")
	var balconies: Array[AABB] = []
	for m in wb.mass_log:
		if String(m.name).begins_with("balcony_"):
			balconies.append(m.aabb)
	if balconies.size() < 3:
		res.fail("fantasy wizard: %d balcony rings, wants at least 3" % balconies.size())
	for i in range(1, balconies.size()):
		if balconies[i].position.y <= balconies[i - 1].position.y:
			res.fail("fantasy wizard: balcony rings do not rise in order")
	for f in CastleMassingCheck.new().check(wizard, wb).failures:
		res.fail("fantasy wizard: %s" % f)

	var dark := CastleSpec.new()
	dark.style = &"dark"
	dark.width = 40.0
	dark.length = 55.0
	dark.height = 14.0
	dark.tier_override = &"castle"
	CastleGenerator.generate(dark, 9249)
	var db := CastleBuilder.new()
	db.build(dark)
	res.checked += 1
	if dark.plan_kind != &"ridge" or dark.chapel or dark.keep_shape != &"spire" \
			or dark.keep_height < dark.height * 2.0:
		res.fail("fantasy dark: ridge/no-chapel/double-height spire contract failed")
	if dark.merlon_profile != &"spike" \
			or not is_equal_approx(CastleGeometry.merlon_width(dark), CastleGeometry.MERLON_W * 0.5):
		res.fail("fantasy dark: narrow spike merlon profile was not selected")
	if not db.part_log.any(func(p): return p.kind == "spike"):
		res.fail("fantasy dark: builder emitted no spike merlons")
	for f in CastleMassingCheck.new().check(dark, db).failures:
		res.fail("fantasy dark: %s" % f)

	var sky := CastleSpec.new()
	sky.style = &"sky"
	sky.width = 80.0
	sky.length = 110.0
	sky.height = 14.0
	sky.tier_override = &"castle"
	CastleGenerator.generate(sky, 12012)
	var sb := CastleBuilder.new()
	sb.build(sky)
	res.checked += 1
	var rock: AABB = sb.mass_aabb("rock")
	if sky.plan_kind != &"polygon" or rock.size.y <= 0.0:
		res.fail("fantasy sky: polygonal ring has no supporting rock")
	elif rock.size.y < maxf(sky.width, sky.length) * 0.5 \
			or not is_equal_approx(rock.end.y, CastleGeometry.sky_ground_level(sky)):
		res.fail("fantasy sky: rock does not taper deeply from its ground plane")
	var tower_bottoms: Array[float] = []
	var tower_tops: Array[float] = []
	var bridges := 0
	for m in sb.mass_log:
		if m.name != "rock" and (m.aabb as AABB).position.y <= 0.0:
			res.fail("fantasy sky: %s touches world ground" % m.name)
		if String(m.name).begins_with("sky_tower_"):
			tower_bottoms.append((m.aabb as AABB).position.y)
			tower_tops.append((m.aabb as AABB).end.y)
		elif String(m.name).begins_with("sky_bridge_"):
			bridges += 1
	if tower_bottoms.size() < 7 or tower_bottoms.min() == tower_bottoms.max() \
			or tower_tops.min() == tower_tops.max():
		res.fail("fantasy sky: tower tops and bottoms do not vary")
	if bridges < tower_bottoms.size():
		res.fail("fantasy sky: %d arched links for %d towers" % [bridges, tower_bottoms.size()])
	for f in CastleMassingCheck.new().check(sky, sb).failures:
		res.fail("fantasy sky: %s" % f)
