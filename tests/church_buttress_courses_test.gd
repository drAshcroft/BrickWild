extends SceneTree
## Separate stone shafts and trim courses must meet without visible double faces.

func _initialize() -> void:
	var failures: Array[String] = []
	for height in [3.0, 12.0, 24.0]:
		for corner in [false, true]:
			var builder := ChurchBuilder.new()
			builder.begin_metric(6)
			builder._stepped_buttress("fixture", Vector3.ZERO, Vector3.RIGHT,
				height, 0.8, 0.5, corner)
			var mesh := builder.commit_named()
			var clashes := CoplanarCheck.visible(mesh, "buttress")
			if not clashes.is_empty():
				failures.append("height=%s corner=%s: %s" % [height, corner, clashes])
			var parity := ComponentCheck.check(builder, mesh)
			if not parity["ok"]:
				failures.append("component mesh parity: %s" % parity["failures"])
			for tier in range(3):
				var shaft: Dictionary = builder.components("shaft_%d" % tier)[0]
				var course: Dictionary = builder.components("shoulder_%d" % tier)[0]
				var shaft_box := MassBuilder.component_aabb(shaft)
				var course_box := MassBuilder.component_aabb(course)
				if absf(shaft_box.end.y - course_box.position.y) > 0.0001:
					failures.append("shaft does not meet its course")
				var point := Vector2(course_box.get_center().x, course_box.get_center().z)
				var stone := MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_STONE)
				if not MeshProbe.has_upward_support(stone, point, course_box.position.y, 0.002):
					failures.append("course has no actual shaft bearing")
				if tier > 0:
					var below := MassBuilder.component_aabb(builder.components("shoulder_%d" % (tier - 1))[0])
					if absf(below.end.y - shaft_box.position.y) > 0.0001:
						failures.append("upper shaft does not stand on preceding course")
			# Restore the old half-course embed using emitted stone geometry.
			var kit := MeshKit.new(6)
			var cap: Dictionary = builder.components("shoulder_0")[0]
			var cap_box := MassBuilder.component_aabb(cap)
			kit.box(cap_box.size, cap_box.get_center(), ChurchBuilder.SURF_STONE)
			kit.box(cap_box.size, cap_box.get_center(), ChurchBuilder.SURF_TRIM)
			if CoplanarCheck.visible(kit.commit(), "embedded course", false).is_empty():
				failures.append("actual duplicate-face negative did not detect embedded course")
	for issue in failures:
		push_error(issue)
	print("Buttress courses: 6 cases, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
