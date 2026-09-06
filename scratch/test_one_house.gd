extends SceneTree

func _init() -> void:
	print("Starting single house QA check...")
	var spec = HouseSpec.new(12345)
	spec.style = &"townhouse"
	spec.trade = &"innkeeper"
	spec.width = 13.0
	spec.length = 16.0
	spec.height = 2.9
	spec.storeys = 2
	var plan = HouseGenerator.generate(spec, 12345)
	var builder = HouseBuilder.new()
	var mesh = builder.build(plan)
	print("Mesh built. Surfaces: ", mesh.get_surface_count())
	var rep = HouseQA.new().check(plan, builder)
	print("QA Result ok: ", rep["ok"])
	if not rep["ok"]:
		for f in rep["failures"]:
			print("  FAIL: ", f)
	for w in rep["warnings"]:
		print("  WARN: ", w)
	quit(0 if rep["ok"] else 1)
