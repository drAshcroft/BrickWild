extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var req := BuildingRequest.castle(int(a[1]), StringName(a[0]))
	req.width = 55.0; req.length = 50.0; req.height = 18.0
	var spec := BrickWild.generate(req).spec as CastleSpec
	print("hall=%s aabb=%s keep=%s tier=%s plan=%s enclosed=%s" % [spec.hall, CastleGeometry.hall_aabb(spec), spec.keep, spec.tier, spec.plan_kind, CastleGeometry.is_enclosed(spec)])
	var hp := CastleInteriorPlans.hall_plan(spec)
	print("hall_plan spec null=%s" % (hp.spec == null))
	quit()
