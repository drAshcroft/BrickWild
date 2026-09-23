extends SceneTree
## Small and tall occupied mottés retain usable floors across seeded fits.

func _init() -> void:
	var checks := 0
	var failures: Array[String] = []
	for size in [Vector3(40, 14, 55), Vector3(45, 6, 55), Vector3(60, 18, 90), Vector3(90, 20, 140)]:
		for seed_value in range(12):
			var spec := CastleSpec.new()
			spec.style = &"norman"
			spec.width = size.x
			spec.height = size.y
			spec.length = size.z
			spec.plan_override = &"motte_bailey"
			CastleGenerator.generate(spec, seed_value)
			var plan := CastleMottePlan.generate(spec, false)
			var label := "%s seed=%d" % [size, seed_value]
			checks += 1
			if plan.spec == null:
				failures.append(label + ": no occupied plan fits")
				continue
			checks += 2
			for failure in CastleMottePlan.validate(plan).failures:
				failures.append(label + ": " + failure)
			for failure in HousePlanCheck.new().check(plan).failures:
				failures.append(label + ": " + failure)
			print("MOTTE ENVELOPE ", label, " rooms=", plan.rooms.size())
	for failure in failures: printerr(failure)
	print("MOTTE ENVELOPE COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
