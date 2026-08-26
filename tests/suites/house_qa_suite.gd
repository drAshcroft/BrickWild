class_name HouseQASuite
extends RefCounted
## 12. The house harness over the whole sweep: is the plan a plan, does the
##     furnishing make sense, and can a person walk through the result.
##
## Every check reads the plan the mesh was built from, so a pass here means the
## house you would walk into is the house that was measured.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house QA")
	for style in HouseSweep.styles():
		var defects := 0
		var variants := 0
		for trade in HouseSweep.trades():
			for i in range(HouseSweep.COUNT):
				var made: Array = HouseSweep.at(style, trade, i)
				var spec: HouseSpec = made[0]
				var plan: HousePlan = made[1]
				var builder := HouseBuilder.new()
				builder.build(plan)
				var rep: Dictionary = HouseQA.new().check(plan, builder)
				res.checked += 1
				variants += 1
				var who := "%s %s seed=%d" % [String(style), String(trade), spec.seed]
				if not rep["ok"]:
					defects += 1
					for f in rep["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in rep["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
		res.note("%-11s %2d/%d houses with defects" % [String(style), defects, variants])
	return res
