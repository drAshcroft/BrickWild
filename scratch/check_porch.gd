extends SceneTree
## Does a porch post stand in front of its own doorway?
##
## The post centres come from the porch mass log; the door leaf span from the
## plan. A post whose footprint overlaps the door opening is a post you would
## walk into on the way in.


func _init() -> void:
	var bad := 0
	var seen := 0
	var worst := 0.0
	for style in HouseSweep.styles():
		for i in range(24):
			var spec := HouseSpec.new()
			spec.style = style
			spec.width = 6.0 + float(i % 5) * 1.6
			spec.length = 7.0 + float(i % 7) * 1.5
			spec.height = 2.5
			spec.storeys = 1 + (i % 2)
			var plan: HousePlan = HouseGenerator.generate(spec, 71000 + i)
			var b := HouseBuilder.new()
			b.build(plan)
			var d: int = plan.entrance()
			if d < 0 or not spec.porch:
				continue
			seen += 1
			var door: Dictionary = plan.doors[d]
			var c: Vector2 = door["pos"]
			var w: float = float(door["width"])
			var along := Vector2(door["normal"].y, -door["normal"].x).abs()
			var lo: float = (c - along * w / 2.0).dot(along)
			var hi: float = (c + along * w / 2.0).dot(along)
			for m in b.mass_log:
				if not String(m["name"]).begins_with("porch_post"):
					continue
				var a: AABB = m["aabb"]
				var p_lo: float = Vector2(a.position.x, a.position.z).dot(along)
				var p_hi: float = Vector2(a.position.x + a.size.x,
					a.position.z + a.size.z).dot(along)
				var over: float = minf(hi, p_hi) - maxf(lo, p_lo)
				if over > 0.001:
					bad += 1
					worst = maxf(worst, over)
					print("%-11s seed %d: %s covers %.2fm of a %.2fm doorway"
						% [String(style), 71000 + i, String(m["name"]), over, w])
					break
	print("porches checked %d, posts in the doorway %d, worst overlap %.2f m"
		% [seen, bad, worst])
	quit()
