extends SceneTree
## THROWAWAY. Print what the five vernacular styles actually emit, so the
## check is written against measured evidence and not against my intent.

const ROLES := ["parapet", "veranda_deck", "veranda_post", "veranda_beam",
	"veranda_roof_0", "eave_sweep_-1_-1", "thatch_roll_0", "thatch_eave",
	"corner_pier", "roof_face_0", "bargeboard", "ridge_cap", "eave_tail"]


func _init() -> void:
	for style in [&"mediterranean", &"asian", &"african", &"thatch_cottage",
			&"mud_hut", &"cottage", &"rich"]:
		for i in HouseSweep.SIZES.size():
			var row: Dictionary = HouseSweep.SIZES[i]
			var s := HouseSpec.new()
			s.style = style
			s.trade = &"none"
			s.width = float(row["w"])
			s.length = float(row["l"])
			s.height = float(row["h"])
			var seed_value := HouseSweep.seed_at(style, &"none", i)
			var plan: HousePlan = HouseGenerator.generate(s, seed_value, false)
			var b := HouseBuilder.new()
			var mesh := b.build(plan)
			var aabb: AABB = mesh.get_aabb()
			var bound: AABB = HouseGeometry.exterior_bounds(plan)
			var hosts := {}
			for c in b.component_log:
				var h := String(c.get("host", ""))
				if h.is_empty():
					continue
				hosts[h] = int(hosts.get(h, 0)) + 1
			var geom: Array = HouseQA.check_exterior_geometry(plan, b)
			print("%-15s %4.1fx%-4.1f roof=%-10s mat=%-8s wt=%.2f rise=%.2f "
				% [String(style), s.width, s.length, String(s.roof_type),
					String(s.roof_material), HouseGeometry.wall_thickness(s),
					HouseGeometry.roof_rise(s)])
			print("      pp=%d vd=%d vs=%d tr=%d cp=%d sweep_out=%.2f rid=%.2f storeys=%d"
				% [int(s.parapet), int(s.veranda), int(s.eave_sweep), int(s.thatch_roll),
					int(s.corner_piers), HouseGeometry.roof_oversail(s).x,
					HouseGeometry.ridge_half(s), s.storeys])
			print("      roles=%s" % str(_roles(b)))
			print("      hosts=%s" % str(hosts))
			print("      mesh aabb=%.2f %.2f %.2f  bound=%.2f %.2f %.2f  top %.3f vs %.3f"
				% [aabb.position.x, aabb.position.y, aabb.position.z,
					bound.position.x, bound.position.y, bound.position.z,
					aabb.end.y, bound.end.y])
			if style == &"mud_hut" and i == 1:
				print("      VERANDA components:")
				for c in b.component_log:
					if String(c.get("host", "")) == "veranda":
						var body: String = str(c.get("xf", c.get("points", "")))
						print("        %s %s" % [String(c["role"]), body.substr(0, 300)])
				print("      mesh end=%.2f %.2f %.2f door=%d" % [aabb.end.x, aabb.end.y,
					aabb.end.z, plan.entrance()])
				print("      veranda_rect=%s" % str(HouseGeometry.veranda_rect(plan)))
			print("      surfaces=%d comps=%d geom_fail=%d %s"
				% [mesh.get_surface_count(), b.component_log.size(), geom.size(),
					str(geom.slice(0, 3))])
	quit()


func _roles(b: HouseBuilder) -> Array:
	var out: Array = []
	for role in ROLES:
		var n: int = b.components(StringName(role)).size()
		if n > 0:
			out.append("%s=%d" % [String(role), n])
	return out
