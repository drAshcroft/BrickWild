extends SceneTree
## Furnished, emitted native motte regression. The pure-plan suite stays fast.

func _init() -> void:
	var failed := false
	var report := {}
	for row in [{"name": "small", "scale": 0.5}, {"name": "compact", "scale": -1.0}, {"name": "fortress", "scale": 0.0}]:
		if not OS.get_cmdline_user_args().is_empty() and not row.name in OS.get_cmdline_user_args():
			continue
		print("NATIVE MOTTE START ", row.name)
		var spec: CastleSpec
		if row.scale == 0.0:
			spec = CastleSweep.spec_at(&"norman", &"fortress", 0)
		elif row.scale < 0.0:
			spec = CastleSpec.new()
			spec.style = &"norman"
			spec.width = 40.0
			spec.length = 55.0
			spec.height = 14.0
			spec.plan_override = &"motte_bailey"
			CastleGenerator.generate(spec, 0)
		else:
			spec = CastleSpec.new()
			spec.style = &"norman"
			spec.width = 90.0 * row.scale
			spec.length = 110.0 * row.scale
			spec.height = 12.0 * row.scale
			spec.plan_override = &"motte_bailey"
			CastleGenerator.generate(spec, 8806 + int(row.scale * 100.0))
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var qa := CastleQA.new().check(spec, mesh, builder)
		var massing := CastleMassingCheck.new().check(spec, builder)
		var components := ComponentCheck.check(builder, mesh)
		var errors: Array = qa.failures.duplicate()
		errors.append_array(massing.failures)
		errors.append_array(components.failures)
		var shell: HousePlan = builder.interiors.filter(func(item: Dictionary) -> bool: return item.id == "keep_shell")[0].plan
		if shell.furniture.is_empty(): errors.append("native shell was not furnished")
		if spec.keep_shape != &"shell": errors.append("motte oval shape was overwritten")
		report[row.name] = {"ok": errors.is_empty(), "failures": errors,
			"warnings": qa.warnings, "rooms": shell.rooms.size(), "stairs": shell.stairs.size(),
			"furniture": shell.furniture.size(), "flue": CastleMottePlan.flue(shell),
			"keep_size": Vector2(spec.keep_w, spec.keep_l), "seed": str(spec.seed)}
		FileAccess.open("res://artifacts/p1p2_api/motte_native_" + row.name + ".json", FileAccess.WRITE).store_string(JSON.stringify(report[row.name], "  "))
		print("NATIVE MOTTE FINISH ", row.name, " ", JSON.stringify(report[row.name]))
		failed = failed or not errors.is_empty()
	print("NATIVE MOTTE COMPLETE ok=", not failed)
	quit(1 if failed else 0)
