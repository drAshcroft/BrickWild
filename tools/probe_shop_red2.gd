extends SceneTree
## godot --headless --path . --script res://tools/probe_shop_red2.gd -- barracks|int013
func _init() -> void:
	var what := OS.get_cmdline_user_args()
	var res: SuiteResult
	var t := Time.get_ticks_msec()
	if what.has("barracks"):
		res = SuiteResult.new("x")
		ShopArchetypeSuite._check_barracks(res)
	else:
		res = ShopArchetypeSuite.run_int013()
	print("== %d ms fails=%d" % [Time.get_ticks_msec() - t, res.failures.size()])
	for f in res.failures:
		print("FAIL ", f)
	quit()
