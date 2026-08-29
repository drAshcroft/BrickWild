class_name ShopPlanner
extends RefCounted
## Adapts the domestic subdivision engine to a public-first workplace plan.


static func plan(spec: ShopSpec) -> HousePlan:
	var out: HousePlan = HousePlanner.plan(spec)
	# HousePlanner needs a hall while it establishes the entrance and stair
	# spine. Once that topology is fixed, the public room takes its real role.
	for room in out.rooms:
		if room["kind"] == &"hall":
			room["kind"] = spec.front_room()
	return out
