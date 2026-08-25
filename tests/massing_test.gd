extends SceneTree
## Structural correctness sweep: no gaps, no overlaps, sizes match the spec.
## Run: godot --headless --script res://tests/massing_test.gd
const STYLES := [&"romanesque", &"gothic", &"byzantine", &"nordic_stave"]

func _init() -> void:
	var checked := 0
	var failed := 0
	var by_style := {}
	for style in STYLES:
		by_style[style] = 0
		for i in range(15):
			var spec := ChurchSpec.new(0)
			spec.style = style
			spec.width = 10.0 + i * 0.5
			spec.length = 18.0 + i * 2.0
			spec.height = 10.0 + (i % 5) * 1.5
			ChurchGenerator.generate(spec, 5000 + i)
			var builder := ChurchBuilder.new()
			builder.build(spec)
			var rep: Dictionary = MassingCheck.new().check(spec, builder)
			checked += 1
			if not rep["ok"]:
				failed += 1
				by_style[style] += 1
				for f in rep["failures"]:
					print("FAIL %s %s seed=%d: %s"
						% [String(style), spec.variant_name, spec.seed, f])
			for w in rep["warnings"]:
				print("WARN %s seed=%d: %s" % [String(style), spec.seed, w])
	print("")
	for style in STYLES:
		print("  %-14s %2d/15 variants with defects" % [String(style), by_style[style]])
	print("MASSING: %d/%d variants passed" % [checked - failed, checked])
	quit(1 if failed > 0 else 0)
