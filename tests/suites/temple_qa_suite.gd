class_name TempleQASuite
extends RefCounted
## 17. The temple harness over the whole sweep: does it stand up, and would a
##     rite work in it.

static func run() -> SuiteResult:
	var res := SuiteResult.new("temple rite")
	for form in TempleSweep.forms():
		var defects := 0
		var variants := 0
		for cult in TempleSweep.cults():
			for i in range(TempleSweep.COUNT):
				var spec: TempleSpec = TempleSweep.spec_at(form, cult, i)
				var builder := TempleBuilder.new()
				builder.build(spec)
				var rep: Dictionary = TempleQA.new().check(spec, builder)
				res.checked += 1
				variants += 1
				var who := "%s %s seed=%d" % [String(form), String(cult), spec.seed]
				if not rep["ok"]:
					defects += 1
					for f in rep["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in rep["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
		res.note("%-10s %2d/%d temples with defects" % [String(form), defects, variants])
	return res
