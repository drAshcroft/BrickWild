extends "res://tools/render_shots.gd"
## House yards, before and after, on the shared portrait stage (EVAL-B06).
##
## `before` is the same plan with its yard taken away (facade pieces only, which
## is all a house had); `after` is the plan as generated. Two cameras each: the
## road side three-quarter, and the rear. Written to artifacts/yard/.
##
##   godot --path . --script res://tools/render_house_yards.gd

const YARD_OUT := "res://artifacts/yard"

const ROWS := [
	{"key": "cottage", "style": &"cottage", "w": 7.0, "l": 9.0, "h": 2.5, "storeys": 1, "seed": 4412},
	{"key": "farm", "style": &"farmhouse", "w": 10.0, "l": 13.0, "h": 2.7, "storeys": 1, "seed": 4413},
	{"key": "smith", "style": &"cottage", "trade": &"smith", "w": 9.0, "l": 11.0, "h": 2.7, "storeys": 1, "seed": 4415},
	{"key": "inn", "style": &"townhouse", "trade": &"innkeeper", "w": 9.0, "l": 12.0, "h": 2.7, "storeys": 2, "seed": 4411},
	{"key": "alchemist", "style": &"witch_hut", "trade": &"alchemist", "w": 6.0, "l": 8.0, "h": 2.6, "storeys": 1, "seed": 4416},
	{"key": "hall", "style": &"longhall", "w": 12.0, "l": 16.0, "h": 2.7, "storeys": 1, "seed": 4414},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(YARD_OUT))
	_build_stage()
	await process_frame
	for row in ROWS:
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.trade = row.get("trade", &"none")
		spec.width = float(row["w"])
		spec.length = float(row["l"])
		spec.height = float(row["h"])
		spec.storeys = int(row["storeys"])
		var plan: HousePlan = HouseGenerator.generate(spec, int(row["seed"]), false)
		print("YARD %s props=%d pieces=%d omissions=%s" % [row["key"], plan.yard.size(),
			plan.yard_pieces.size(), plan.exterior_omissions])
		for state in ["before", "after"]:
			var shown := plan
			if state == "before":
				shown = HouseGenerator.generate(spec, int(row["seed"]), false)
				shown.yard = []
				shown.yard_pieces = []
				shown.spec.exterior_props = true
			# the shell is built from the plan, so the "before" mesh has no pieces
			var model := HouseAssembler.build(shown, false)
			_root3d.add_child(model)
			var env := HouseGeometry.yard_rect(plan)
			var centre := Vector3(0.0, 1.2, 0.0)
			var reach: float = maxf(env.size.x, env.size.y)
			var views := {"road": Vector3(-0.55, 0.0, -0.85), "rear": Vector3(0.55, 0.0, 0.85),
				"east": Vector3(0.95, 0.0, -0.3), "west": Vector3(-0.95, 0.0, 0.3)}
			for view in views:
				var dir: Vector3 = (views[view] as Vector3).normalized()
				_cam.position = centre + dir * reach * 0.82 + Vector3(0.0, 2.0 + reach * 0.2, 0.0)
				_cam.look_at(centre + Vector3(0.0, -0.4, 0.0), Vector3.UP)
				for frame in 3:
					await process_frame
					await RenderingServer.frame_post_draw
				var path := "%s/%s_%s_%s.jpg" % [YARD_OUT, row["key"], state, view]
				_vp.get_texture().get_image().save_jpg(path, 0.92)
				print("YARD_RENDER ", path)
			model.queue_free()
			await process_frame
	quit()
