extends SceneTree
## BG-015 scratch: how long does regenerating a house/shop for placement take,
## and what does its ground outline look like?

func _init() -> void:
	var f := FileAccess.open("C:/Projects/VoxelGames/out/bw_dev_baseline/old_wuunafu_ground.site.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var total := 0.0
	var n := 0
	for b in d["buildings"]:
		if not String(b["kind"]) in ["house", "shop"]:
			continue
		var req := BuildingRequest.from_dict(b["request"])
		var t0 := Time.get_ticks_usec()
		var built: GeneratedBuilding = BrickWild._generate(req, true)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		total += dt
		n += 1
		var plan: HousePlan = built.plan
		var spec: HouseSpec = plan.spec
		var t1 := Time.get_ticks_usec()
		var fp: Rect2 = BuildingFamilyAdapter.for_building(built).footprint(built)
		print("%s %s %.0f ms  w %.2f l %.2f wall %.2f plinth %.2f fp %s site %s chim %s porch %s ver %s quoins %s shaped %s court %s storeys %d jetty %s" % [b["building_id"], b["kind"], dt,
			spec.width, spec.length, HouseGeometry.wall_thickness(spec), spec.plinth_height, fp, HouseGeometry.site_rect(spec, 0),
			HouseGeometry.chimney_rect(plan), HouseGeometry.porch_rect(plan), HouseGeometry.veranda_rect(plan),
			HouseGeometry.has_quoins(spec), HouseGeometry.is_shaped(plan), plan.has_court(), spec.storeys, spec.jetty])
	print("mean %.0f ms over %d" % [total / maxf(1, n), n])
	quit()
