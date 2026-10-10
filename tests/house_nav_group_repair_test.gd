extends SceneTree
## Exact innkeeper regression: a hosted floor seat must be a repair candidate.
## A blocked stool must not cost the parlour its table and remaining seats.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.trade = &"innkeeper"
	spec.width = 13.0
	spec.length = 16.0
	spec.height = 2.9
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 32102)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(nav["ok"]):
		failures.append("exact innkeeper remains unreachable: %s" % [nav["failures"]])
	var table := -1
	var hosted_seat := -1
	var seating := 0
	for i in plan.furniture.size():
		var piece: Dictionary = plan.furniture[i]
		if int(piece.get("room", -1)) != 1:
			continue
		var category: String = String(PropCatalog.category(String(piece["key"])))
		if category == "table":
			table = i
		elif category in ["seat", "bench"]:
			seating += 1
			if int(piece.get("host", -1)) >= 0 and PropCatalog.blocks_floor(String(piece["key"])):
				hosted_seat = i
	if table < 0 or seating < 2:
		failures.append("parlour lost its usable dining group: table=%d seats=%d" % [table, seating])
	if hosted_seat < 0:
		failures.append("parlour has no hosted floor seat for the repair control")
	else:
		var rep := {"unreached_rooms": [], "unreachable_items": [hosted_seat]}
		if hosted_seat not in HouseFurnishRepair._candidates(plan, rep):
			failures.append("hosted floor seat was excluded from repair trials")
		var without: HousePlan = HouseFurnishRepair._without(plan, hosted_seat)
		var trial_tables := 0
		for piece in without.furniture:
			if int(piece.get("room", -1)) == 1 \
					and PropCatalog.category(String(piece["key"])) == "table":
				trial_tables += 1
		if trial_tables == 0 or without.furniture.size() != plan.furniture.size() - 1:
			failures.append("trial of one hosted seat removed its table or unrelated furniture")
	for failure in failures:
		push_error(failure)
	print("House nav group repair: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
