extends SceneTree
## Shelf_Small_Bottles has its visible bottle rows on native +Z, verified in
## the imported asset renders. House records use semantic facing; assembly
## applies the native face correction exactly once.
var failures: Array[String] = []

func _init() -> void:
	var key := "Shelf_Small_Bottles"
	for inward in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var axis := Vector2(-inward.y, inward.x)
		var wall := {"from": -axis * 2.0, "to": axis * 2.0, "normal": inward}
		var pose := HousePlanFeatures._wall_fixture_pose(key, wall, 0.0, 1.55, 1.0)
		var item := {"key": key, "pos": pose["pos"], "yaw": pose["yaw"], "scale": 1.0}
		var instance := HouseAssembler._instance(item)
		if instance == null:
			failures.append("ingredient rack did not assemble")
			continue
		if not _bottles_face_room(instance, inward):
			failures.append("actual ingredient rack shows its back to room " + str(inward))
		instance.rotation.y += PI
		if _bottles_face_room(instance, inward):
			failures.append("backward rack negative was accepted")
		instance.free()
	for failure in failures: printerr("FAIL ", failure)
	print("actual ingredient shelf fronts: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _bottles_face_room(instance: Node3D, inward: Vector2) -> bool:
	var front := (instance.basis * Vector3.BACK).normalized()
	return Vector2(front.x, front.z).dot(inward) > 0.99
