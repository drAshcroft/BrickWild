extends SceneTree
func _init() -> void:
	var req := BuildingRequest.castle(1, &"edwardian")
	req.width = 55.0; req.length = 50.0; req.height = 18.0
	var spec := BrickWild.generate(req).spec as CastleSpec
	var prim: Dictionary = preload("res://src/castle/castle_interiors.gd").primary(spec)
	var plan: HousePlan = prim["tower_1_corner_4"].plan
	for r in [Rect2(-0.9, -0.9, 1.8, 1.8), Rect2(-0.7, -0.9, 1.8, 1.8), Rect2(-1.1, -0.9, 1.8, 1.8), Rect2(-0.9,-0.7,1.8,1.8), Rect2(-0.9,-1.1,1.8,1.8)]:
		var l := CastleKeepPlan.stair_landings(plan, 0, 1, r, [], [], 540.0)
		print(r, " in ", CastleKeepPlan._inside(plan, 0, r), " door ", CastleKeepPlan._well_blocks_a_door(plan, r), " land ", not l.is_empty(), " pass ", (not l.is_empty()) and CastleKeepPlan._newel_passable(plan, 0, r, l))
	for d in plan.doors:
		print(HouseGeometry.door_clear_rect(d, -1.0), HouseGeometry.DOOR_CLEAR)
	quit()
