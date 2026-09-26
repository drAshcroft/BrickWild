extends RefCounted
## Fine local width measurement must preserve real obstructions at every yaw.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village approach nav")
	for site_size in [120.0, 400.0]:
		for degrees in [0, 19, 45, 71, 90, 135]:
			var spec := VillageSpec.new(1)
			spec.enclosure = &"none"
			var plan := VillagePlan.new(spec)
			plan.site = Rect2(-site_size * 0.5, -site_size * 0.5, site_size, site_size)
			plan.lots.append({"poly": Poly.from_rect(Rect2(-40, -40, 80, 80))})
			var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(degrees))), Vector3(0.17, 0, 0.23))
			var building := {"placement": {"bounds": AABB(Vector3(-15, 0, -20), Vector3(30, 8, 40)),
				"approach": Rect2(-1, -21, 2, 31)}, "transform": xf}
			plan.buildings.append(building)
			var where := "site=%.0f yaw=%d" % [site_size, degrees]
			res.checked += 1
			if VillageNavCheck._approach_clearance(plan, building) < VillageNavCheck.PATH_WIDTH:
				res.fail("clear two-metre court rejected: " + where)
			building["placement"]["approach"] = Rect2(-0.55, -21, 1.1, 31)
			res.checked += 1
			if VillageNavCheck._approach_clearance(plan, building) >= VillageNavCheck.PATH_WIDTH:
				res.fail("subminimum court accepted: " + where)
			building["placement"]["approach"] = Rect2(-1, -21, 2, 31)
			var centre := xf * Vector3(0, 0, -5)
			var block := Rect2(Vector2(centre.x, centre.z) - Vector2.ONE * 2.0, Vector2.ONE * 4.0)
			plan.props.append({"key": "barrel", "built": true, "rect": block})
			res.checked += 1
			if VillageNavCheck._approach_clearance(plan, building) >= VillageNavCheck.PATH_WIDTH:
				res.fail("solid prop in court ignored: " + where)
			plan.props.clear()
			plan.water.append({"kind": &"pond", "poly": Poly.from_rect(block)})
			res.checked += 1
			if VillageNavCheck._approach_clearance(plan, building) >= VillageNavCheck.PATH_WIDTH:
				res.fail("water in court ignored: " + where)
	return res
