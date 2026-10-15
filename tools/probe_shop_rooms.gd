extends SceneTree
## Probe: furnish check on the sarchetype shop configurations, one line per failure.
## godot --headless --path . --script res://tools/probe_shop_rooms.gd -- bakery butcher
func _initialize() -> void:
	var wanted: Array = []
	for a in OS.get_cmdline_user_args():
		wanted.append(StringName(a))
	var total := 0
	for business in ShopArchetypeSuite.REQUIRED:
		if not wanted.is_empty() and not wanted.has(business):
			continue
		var spec := ShopSpec.new()
		spec.business = business
		spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter", &"library", &"prison"] else &"townhouse"
		spec.width = 14.0
		spec.length = 18.0
		if business in [&"alchemist_laboratory", &"bathhouse", &"hospice", &"school"]:
			spec.width = 20.0; spec.length = 26.0
		if business == &"thieves_den":
			spec.width = 30.0; spec.length = 24.0
		if business == &"barracks":
			spec.width = 18.0; spec.length = 28.0
		if business == &"library":
			spec.width = 18.0; spec.length = 28.0
		if business == &"prison":
			spec.width = 15.8; spec.length = 22.0
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 33000 + absi(String(business).hash()) % 900)
		var rep: Dictionary = HouseFurnishCheck.new().check(plan)
		for f in rep["failures"]:
			if str(f).begins_with("sparse") or str(f).begins_with("lamps") or str(f).begins_with("nav"):
				print("%s: %s" % [business, f]); total += 1
		print("%s: %d pieces" % [business, plan.furniture.size()])
	print("PROBE sparse/lamps failures: ", total)
	quit()
