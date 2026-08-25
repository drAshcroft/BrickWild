extends SceneTree
## Blueprint QA harness. Runs every variant through BlueprintQA.
## Run: godot --headless --script res://tests/blueprint_qa_test.gd

func _init() -> void:
	var total := 0
	var failed := 0
	var styles: Array = ChurchSpec.STYLES.keys()
	for style in styles:
		for i in range(15):
			var spec := ChurchSpec.new(0)
			spec.style = style
			spec.width = 10.0 + i * 0.5
			spec.length = 18.0 + i * 2.0
			spec.height = 10.0 + (i % 5) * 1.5
			ChurchGenerator.generate(spec, 5000 + i)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var qa := BlueprintQA.new()
			var report: Dictionary = qa.check(spec, mesh, builder)
			total += 1
			if not report["ok"]:
				failed += 1
				print("FAIL %s seed=%d (%s)" % [spec.variant_name, spec.seed, style])
				for f in report["failures"]:
					print("   - " + str(f))
			for w in report["warnings"]:
				print("WARN %s seed=%d: %s" % [spec.variant_name, spec.seed, str(w)])
	print("")
	print("BLUEPRINT QA: %d/%d variants passed" % [total - failed, total])
	quit(1 if failed > 0 else 0)
