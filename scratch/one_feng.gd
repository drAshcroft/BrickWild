extends SceneTree
## Scratch: the one house the feng shui sweep complained about, on its own.


func _init() -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	for n in [68]:
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.trade = trades[n % trades.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan: HousePlan = HouseGenerator.generate(spec, 60000 + n)
		var rep: Dictionary = HouseFurnishCheck.new().check(plan)
		print("n=%d %s %s %.1f x %.1f storeys=%d"
			% [n, String(spec.style), String(spec.trade), spec.width,
				spec.length, spec.storeys])
		for f in rep["failures"]:
			print("  FAIL ", str(f))
		print("  failures=%d warnings=%d" % [rep["failures"].size(),
			rep["warnings"].size()])
	quit()
