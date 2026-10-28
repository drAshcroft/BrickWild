extends SceneTree
## Runs the sarchetype sweep one business at a time and prints as it goes.
## godot --headless --path . --script res://tools/probe_sarchetype.gd -- [business ...]
func _init() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		only.append(StringName(a))
	for business in ShopArchetypeSuite.REQUIRED:
		if not only.is_empty() and not only.has(business):
			continue
		var res := SuiteResult.new("x")
		var t := Time.get_ticks_msec()
		ShopArchetypeSuite._check_business(res, business)
		print("== %s %d ms fails=%d" % [business, Time.get_ticks_msec() - t, res.failures.size()])
		for f in res.failures:
			print("FAIL ", f)
	quit()
