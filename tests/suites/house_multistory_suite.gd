class_name HouseMultistorySuite
extends RefCounted
## Focused vertical-house contract.  The canonical house sweep remains
## one-storey for regression coverage; this small suite exercises the costly
## stair/elevation path explicitly.

const CASES := [
	{"style": &"cottage", "trade": &"none", "w": 8.0, "l": 10.0, "h": 2.6,
		"storeys": 2, "seed": 32101},
	{"style": &"townhouse", "trade": &"innkeeper", "w": 13.0, "l": 16.0, "h": 2.9,
		"storeys": 2, "seed": 32102},
	{"style": &"longhall", "trade": &"smith", "w": 11.0, "l": 14.0, "h": 2.7,
		"storeys": 3, "seed": 32103},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("house multistory")
	for row in CASES:
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.trade = row["trade"]
		spec.width = row["w"]
		spec.length = row["l"]
		spec.height = row["h"]
		spec.storeys = row["storeys"]
		var plan: HousePlan = HouseGenerator.generate(spec, row["seed"])
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "%s %d-storey seed=%d" % [String(row["style"]), row["storeys"], row["seed"]]
		res.checked += 1
		var rep: Dictionary = HouseQA.new().check(plan, builder)
		for f in rep["failures"]:
			res.fail("%s: %s" % [who, str(f)])
		for w in rep["warnings"]:
			res.warn("%s: %s" % [who, str(w)])
		_check_elevations(res, plan, who)
		_check_stairs(res, plan, who)
		_check_roof(res, builder, spec, who)

		# Generation and mesh emission must remain deterministic with vertical
		# records included, not merely with the old furniture positions.
		var again_spec := HouseSpec.new()
		again_spec.style = row["style"]
		again_spec.trade = row["trade"]
		again_spec.width = row["w"]
		again_spec.length = row["l"]
		again_spec.height = row["h"]
		again_spec.storeys = row["storeys"]
		var again: HousePlan = HouseGenerator.generate(again_spec, row["seed"])
		res.checked += 1
		if not _same_plan(plan, again):
			res.fail("%s: repeated generation changed vertical plan records" % who)

	# Existing defaults are intentionally one-storey and must not acquire a
	# phantom stair or elevated furniture.
	var one := HouseSpec.new()
	one.style = &"cottage"
	one.trade = &"none"
	one.width = 5.5
	one.length = 7.0
	one.height = 2.4
	var one_plan: HousePlan = HouseGenerator.generate(one, 32104)
	res.checked += 1
	if int(one.storeys) != 1 or not one_plan.stairs.is_empty():
		res.fail("one-storey default has vertical circulation")
	for p in one_plan.furniture:
		var y: float = float(p["pos"].y)
		if HousePlan.record_storey(p) != 0 or y < -0.03 or y > one.height + 0.03:
			res.fail("one-storey furniture left its ground-floor band at Y=%.2f" % y)
	return res


static func _check_elevations(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var counts := {}
	for room in plan.rooms:
		var level := HousePlan.record_storey(room)
		counts[level] = int(counts.get(level, 0)) + 1
	for level in range(int(plan.spec.storeys)):
		if not counts.has(level):
			res.fail("%s: storey %d has no rooms" % [who, level])
	for p in plan.furniture:
		var level := HousePlan.record_storey(p)
		var expected := float(level) * plan.spec.height
		if absf(float(p["pos"].y) - expected) > plan.spec.height + 0.05:
			res.fail("%s: furniture Y %.2f is outside storey %d" % [who, p["pos"].y, level])


static func _check_stairs(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var pairs := {}
	for stair in plan.stairs:
		var lo := int(stair.get("storey", 0))
		var hi := int(stair.get("to_storey", lo + 1))
		pairs[lo] = true
		if hi != lo + 1:
			res.fail("%s: stair skips from storey %d to %d" % [who, lo, hi])
	for level in range(int(plan.spec.storeys) - 1):
		if not pairs.has(level):
			res.fail("%s: no stair transition from storey %d" % [who, level])


static func _check_roof(res: SuiteResult, builder: HouseBuilder, spec: HouseSpec, who: String) -> void:
	var roofs := 0
	var top := -INF
	for m in builder.mass_log:
		if not (m["name"] as String).begins_with("roof"):
			continue
		roofs += 1
		top = maxf(top, (m["aabb"] as AABB).end.y)
	if roofs == 0:
		res.fail("%s: no logged top-storey roof" % who)
	elif top < float(spec.storeys) * spec.height - 0.15:
		res.fail("%s: roof top %.2f is below top wall band" % [who, top])


static func _same_plan(a: HousePlan, b: HousePlan) -> bool:
	return a.rooms == b.rooms and a.doors == b.doors and a.windows == b.windows \
		and a.stairs == b.stairs and a.furniture == b.furniture \
		and a.compromises == b.compromises
