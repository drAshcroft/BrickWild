extends SceneTree

## Focused negative control for HousePlan's connectivity graph. Rejected
## stair candidates remain in the plan for diagnostics, but cannot create a
## route between floors.
func _initialize() -> void:
	var plan: HousePlan = HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [
		{"kind": &"hall", "rect": Rect2(0.0, 0.0, 4.0, 4.0), "storey": 0},
		{"kind": &"bedroom", "rect": Rect2(0.0, 0.0, 4.0, 4.0), "storey": 1},
		{"kind": &"loft", "rect": Rect2(0.0, 0.0, 4.0, 4.0), "storey": 2},
	]
	plan.stairs = [{
		"a": 0, "b": 1, "storey": 0, "to_storey": 1,
		"satisfied": false, "rect": Rect2(),
		"lower_rect": Rect2(), "upper_rect": Rect2(),
	}]
	var failures: int = 0
	var rejected_graph: Dictionary = plan.door_graph()
	if rejected_graph[0].has(1) or rejected_graph[1].has(0):
		push_error("unsatisfied stair created a phantom graph edge")
		failures += 1
	if plan.reachable_rooms(0).has(1):
		push_error("unsatisfied stair created a phantom reachable room")
		failures += 1

	# Positive control: the same endpoints connect when the stair is accepted.
	plan.stairs[0]["satisfied"] = true
	plan.stairs[0]["rect"] = Rect2(1.0, 1.0, 1.0, 2.0)
	if not plan.door_graph()[0].has(1) or not plan.reachable_rooms(0).has(1):
		push_error("satisfied stair did not connect its storeys")
		failures += 1

	# Compatibility control: older/custom stair rows without the marker remain
	# accepted, as they were before satisfaction provenance was added.
	plan.stairs = [{"a": 1, "b": 2, "storey": 1, "to_storey": 2}]
	if not plan.door_graph()[1].has(2) or not plan.reachable_rooms(1).has(2):
		push_error("legacy stair without satisfied field lost connectivity")
		failures += 1

	if failures == 0:
		print("phantom stair graph fixture passed")
	quit(failures)
