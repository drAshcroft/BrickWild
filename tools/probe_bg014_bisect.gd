extends SceneTree
## BG-014: which obstacle of b-019's ground storey makes the baker's convex partition fail.


func _init() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/bg014/reqs.json"))
	var b: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_dict(all["b-019"]))
	var src: Dictionary = HouseWalkSources.sources(b.plan)
	var floors: Array[PackedVector2Array] = src[0]["floor"]
	var obs: Array[PackedVector2Array] = src[0]["obstacles"]
	print("full polys=", NavBake.bake(floors, obs, BuildingNavigation.AGENT_RADIUS)["polygons"].size())
	for i in obs.size():
		var rest: Array[PackedVector2Array] = []
		for j in obs.size():
			if j != i:
				rest.append(obs[j])
		var n: int = NavBake.bake(floors, rest, BuildingNavigation.AGENT_RADIUS)["polygons"].size()
		if n > 0:
			print("dropping obstacle ", i, " ", obs[i], " -> ", n)
	var none: Array[PackedVector2Array] = []
	print("no obstacles polys=", NavBake.bake(floors, none, BuildingNavigation.AGENT_RADIUS)["polygons"].size())
	quit()
