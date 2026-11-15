extends SceneTree
## A/B timing of the household brief (HOME-BRIEF): the same houses generated
## with HouseHousehold.enabled on and off, alternating in ONE process, so both
## halves run under the same machine load. Wall time per house, and the ratio.
##   godot --headless --path . --script res://tools/interiors/time_household.gd -- cases=townhouse:1:2,rich:1:2,cottage:1:1 reps=2


func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		if "=" in s:
			a[s.get_slice("=", 0)] = s.get_slice("=", 1)
	var reps := int(a.get("reps", "1"))
	var totals := {true: 0, false: 0}
	for c in String(a.get("cases", "townhouse:1:2,rich:1:2,cottage:1:1")).split(",", false):
		var parts := c.split(":")
		for rep in range(reps):
			for on in [false, true]:
				HouseHousehold.enabled = on
				var req := BrickWild.default_request(&"house", int(parts[1]), StringName(parts[0]))
				if parts.size() > 2:
					req.storeys = int(parts[2])
				var t := Time.get_ticks_msec()
				var b := BrickWild.generate(req)
				var ms := Time.get_ticks_msec() - t
				totals[on] += ms
				var plan := b.plan as HousePlan
				print("%-14s brief %-5s %6d ms  places %s  dining %s" % [c, str(on), ms,
					HouseFurnisher._household_seat_capacity(plan), plan.domestic_layout.get("dining_selection", "")])
	HouseHousehold.enabled = true
	print("total brief off %d ms, on %d ms, ratio %.2f" % [totals[false], totals[true],
		float(totals[true]) / maxf(float(totals[false]), 1.0)])
	quit()
