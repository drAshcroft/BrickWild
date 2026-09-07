extends SceneTree
## Does the roof stay over the house?
##
## Measured HIGH UP only -- above half the roof rise -- so the porch canopy,
## which is meant to project, cannot be mistaken for the roof doing it.


func _init() -> void:
	var worst := {}
	for style in HouseSweep.styles():
		for i in range(24):
			var spec := HouseSpec.new()
			spec.style = style
			spec.width = 6.0 + float(i % 5) * 1.6
			spec.length = 7.0 + float(i % 7) * 1.5
			spec.height = 2.5
			spec.storeys = 1 + (i % 2)
			var plan: HousePlan = HouseGenerator.generate(spec, 71000 + i)
			var mesh: ArrayMesh = HouseBuilder.new().build(plan)
			var site: Rect2 = HouseGeometry.site_rect(spec)
			var wall_top: float = spec.height * mini(spec.storeys, 3)
			var rise: float = HouseGeometry.roof_rise(spec)
			var arr: Array = mesh.surface_get_arrays(2)      # SURF_ROOF
			var out := 0.0
			for p in arr[Mesh.ARRAY_VERTEX]:
				if p.y < wall_top + rise * 0.5:
					continue
				out = maxf(out, maxf(site.position.x - p.x, p.x - site.end.x))
				out = maxf(out, maxf(site.position.y - p.z, p.z - site.end.y))
			var key: String = String(spec.roof_type)
			if out > float(worst.get(key, 0.0)):
				worst[key] = out
	print("How far the roof reaches past the wall, measured above half the rise:")
	for k in worst:
		print("  %-12s %.2f m   %s" % [k, float(worst[k]),
			"(eaves and verge are 0.25-0.35 m)" if float(worst[k]) < 0.5
			else "<-- FLOATING OUTSIDE THE BUILDING"])
	quit()
