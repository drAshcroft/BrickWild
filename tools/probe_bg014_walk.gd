extends SceneTree
## BG-014: build the Wuunafu b-021 townhouse on falling ground and say which
## navigation points are non-finite.

func _init() -> void:
	var path := "res://artifacts/bg014/reqs.json"
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in all:
		print("== ", key)
		_one(all[key])
		_sources(all[key])
	quit()


func _one(req: Dictionary) -> void:
	var b: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_dict(req))
	print("ok=", b.is_ok())
	var nav: Dictionary = BrickWild.navigation(b)
	print("supported=", nav.get("supported"))
	for s in nav.get("storeys", []):
		print("storey ", s["storey"], " verts=", s["navmesh"]["vertices_m"].size(), " polys=", s["navmesh"]["polygons"].size(), " area=", s["navmesh"]["area_m2"])
	for k in ["doors", "furniture", "stairs"]:
		var bad := 0
		for r in nav.get(k, []):
			if not _finite(r):
				bad += 1
		print(k, " rows=", nav.get(k, []).size(), " nonfinite=", bad)


func _finite(v) -> bool:
	if v is float:
		return is_finite(v)
	if v is Array:
		for x in v:
			if not _finite(x):
				return false
	elif v is Dictionary:
		for k in v:
			if not _finite(v[k]):
				return false
	return true


## Which storey fails to bake, and what sits in its sources.
func _sources(req: Dictionary) -> void:
	var b: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_dict(req))
	var plan: HousePlan = b.plan
	var src: Dictionary = HouseWalkSources.sources(plan)
	for level in HouseWalkSources.levels_of(plan):
		var mesh: Dictionary = NavBake.bake(src[level]["floor"], src[level]["obstacles"], BuildingNavigation.AGENT_RADIUS)
		print("level ", level, " floors=", src[level]["floor"].size(), " obstacles=", src[level]["obstacles"].size(), " polys=", mesh["polygons"].size())
		if mesh["polygons"].is_empty():
			for p in src[level]["floor"]:
				print("  floor ", p)
			for p in src[level]["obstacles"]:
				print("  obst ", p)
