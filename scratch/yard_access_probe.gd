extends SceneTree
## THROWAWAY. Why does a mud hut's front door stop being reachable from the
## road edge? Print the walk, the yard, and the reservation meant to keep it open.

const CASES: Array = [
	{"key": "mud_hut", "w": 6.5, "l": 7.5, "h": 2.4, "style": &"mud_hut"},
	{"key": "african_compound", "w": 10.0, "l": 12.0, "h": 2.8, "style": &"african"},
	{"key": "thatched_cottage", "w": 8.0, "l": 10.0, "h": 2.5, "style": &"thatch_cottage"},
	{"key": "cottage", "w": 5.5, "l": 7.0, "h": 2.4, "style": &"cottage"},
]

const SEEDS := [21096, 21161, 21650, 21274, 21299, 21339, 21389]


func _init() -> void:
	for row in CASES:
		for i in SEEDS.size():
			var scale: float = [0.75, 1.4, 1.9, 0.75, 1.0, 1.4, 1.9][i]
			var seed_value: int = SEEDS[i]
			var s := HouseSpec.new()
			s.style = row["style"]
			s.trade = &"none"
			s.width = float(row["w"]) * scale
			s.length = float(row["l"]) * scale
			s.height = float(row["h"])
			var plan: HousePlan = HouseGenerator.generate(s, seed_value)
			HouseBuilder.new().build(plan)
			var bare := HouseExterior.reached_doors(plan, false)
			var dressed := HouseExterior.reached_doors(plan, true)
			var ok := HouseYard.access_ok(plan)
			var lost: Array = []
			for d in bare:
				if d not in dressed:
					lost.append(d)
			print("%s seed=%d scale=%.2f veranda=%d porch=%d access_ok=%s front_in=%s front_bare=%s lost=%s"
				% [String(row["key"]), seed_value, scale, int(s.veranda), int(s.porch),
					str(ok), str(plan.entrance() in dressed), str(plan.entrance() in bare), str(lost)])
			if ok:
				continue
			print("   site      ", str(HouseGeometry.site_rect(s)))
			print("   veranda   ", str(HouseGeometry.veranda_rect(plan)))
			print("   porch     ", str(HouseGeometry.porch_rect(plan)))
			print("   yard      ", str(HouseGeometry.yard_rect(plan)))
			print("   roadpoint ", str(HouseYard.road_point(plan)))
			print("   entrance  ", plan.entrance(), " door=", str(plan.doors[plan.entrance()]))
			for di in plan.doors.size():
				var d: Dictionary = plan.doors[di]
				print("   door      ", di, " ext=", str(d.get("exterior", false)), " ", str(d))
			for rect in HouseYard.obstacles(plan):
				print("   obstacle  ", str(rect))
			for p in plan.yard:
				print("   yard prop ", String(p.get("key", "?")), " host=", String(p.get("host", "?")),
					" ", str(HouseExterior.bounds_of(p)))
			for piece in plan.yard_pieces:
				print("   piece     ", String(piece.get("kind", "?")), " ", str(piece.get("rect", "")))
	quit()
