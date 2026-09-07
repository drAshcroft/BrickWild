class_name CastleInteriorSuite
extends RefCounted
## 12b. The castle interiors -- great hall and keep -- over a wide band of
##      castles (CAS-010, CAS-011).
##
## `CastleSuite._great_hall` proves the arrangement -- dais, high table, lord's
## bench, trestle rows, hearth, screens passage -- on the twelve canonical
## castles of every style and tier. This is the other half: two hundred halls
## at sizes the sweep does not visit, judged by the house harness alone.
##
## Sizes stop at the castle tier on purpose. A fortress range is sixty metres
## across, which is not a hall but a courtyard block, and rasterising one at
## 12 cm to answer a question about a gangway costs more than it tells; the
## canonical sweep covers those twelve, and this covers the shapes.
##
## What it reports is RATES. A hall that could not fit its second row of
## trestles, or the bench behind its high table, has made a compromise and says
## so on the plan -- the same mechanism a cottage uses when it gives up a chest
## to stay walkable. So the failures below are defects, and the rates are the
## honest measure of how often the arrangement actually comes out.

const COUNT := 200
## The rates CAS-010 was accepted against, re-derived from the finished plan.
## They are not 100% on purpose: a range 3 m across can hold a high table and
## nothing else, and a generator that forced two rows of trestles into one
## would be lying about the room.
const WANT := {"dais": 1.0, "high_table": 0.98, "lord": 0.90, "rows": 0.90,
	"two_rows": 0.45, "hearth": 0.90}


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle interiors")
	var tally := {"dais": 0, "high_table": 0, "lord": 0, "rows": 0,
		"two_rows": 0, "hearth": 0}
	var halls := 0
	var skipped := 0
	var styles: Array = CastleSpec.STYLES.keys()
	var r := RandomNumberGenerator.new()
	r.seed = 20261001
	for i in range(COUNT):
		var spec := CastleSpec.new()
		spec.style = styles[i % styles.size()]
		spec.width = r.randf_range(8.0, 80.0)
		spec.length = spec.width * r.randf_range(1.0, 2.0)
		spec.height = r.randf_range(5.0, 20.0)
		var sd: int = 31000 + i
		CastleGenerator.generate(spec, sd)
		var plan: HousePlan = CastleGenerator.hall_plan(spec)
		res.checked += 1
		if plan.spec == null:
			skipped += 1
			continue
		halls += 1
		var who := "%s %.0f x %.0fm seed=%d" % [String(spec.style), spec.width,
			spec.length, sd]

		var dais: Rect2 = plan.dais_rect()
		if dais.size.x > 0.0:
			tally["dais"] += 1
		var high := -1
		var rows := {}
		var lord := 0
		var fires := 0
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			var cat: String = PropCatalog.category(String(p["key"]))
			var c: Vector2 = Rect2(p["rect"]).get_center()
			if cat == "table" and dais.has_point(c):
				high = f
			elif cat == "hearth":
				fires += 1
			elif (cat == "bench" or cat == "seat") and dais.has_point(c):
				lord += 1
			var g: String = String(p.get("row", ""))
			if g != "":
				rows[g] = int(rows.get(g, 0)) + 1
		if high >= 0:
			tally["high_table"] += 1
		if lord > 0:
			tally["lord"] += 1
		if fires > 0:
			tally["hearth"] += 1
		if not rows.is_empty():
			tally["rows"] += 1
		if rows.size() >= 2:
			tally["two_rows"] += 1

		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])

	res.note("%d halls, %d ranges too small to feast in" % [halls, skipped])
	if halls == 0:
		res.fail("not one range in %d was furnished as a hall" % COUNT)
		return res
	for key in WANT:
		var rate: float = float(int(tally[key])) / float(halls)
		res.checked += 1
		var line := "%-11s %5.1f%% (want %.0f%%)" % [key, rate * 100.0,
			float(WANT[key]) * 100.0]
		if rate < float(WANT[key]) - 0.001:
			res.fail("great hall: %s" % line)
		else:
			res.note("great hall  %s" % line)
	_keeps(res)
	return res


## The keeps of the same band of castles (CAS-011).
##
## Structure is asserted in the castle suite, on the canonical twelve of every
## style and tier. What this adds is the SHAPES the canonical set never
## visits -- and the one thing worth stating as a rate rather than a rule:
## how often a keep comes out of a castle at all.
static func _keeps(res: SuiteResult) -> void:
	var built := 0
	var levels := {}
	var styles: Array = CastleSpec.STYLES.keys()
	var r := RandomNumberGenerator.new()
	r.seed = 20261101
	for i in range(COUNT):
		var spec := CastleSpec.new()
		spec.style = styles[i % styles.size()]
		spec.width = r.randf_range(10.0, 90.0)
		spec.length = spec.width * r.randf_range(1.0, 2.0)
		spec.height = r.randf_range(6.0, 24.0)
		var sd: int = 41000 + i
		CastleGenerator.generate(spec, sd)
		var plan: HousePlan = CastleGenerator.keep_plan(spec)
		res.checked += 1
		if plan.spec == null:
			continue
		built += 1
		levels[plan.spec.storeys] = int(levels.get(plan.spec.storeys, 0)) + 1
		var who := "keep %s %.0f x %.0fm seed=%d" % [String(spec.style),
			spec.width, spec.length, sd]
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("keep        %d of %d castles have one, storeys %s"
		% [built, COUNT, str(levels)])
	res.checked += 1
	if built < COUNT / 5:
		res.fail("keep: only %d of %d castles produced one" % [built, COUNT])
